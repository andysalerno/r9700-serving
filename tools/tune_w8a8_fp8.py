import argparse
import itertools
import json
import os
import time
from concurrent.futures import ProcessPoolExecutor
from concurrent.futures.process import BrokenProcessPool

import torch

import vllm.model_executor.layers.quantization.utils.fp8_utils as fpu

BLOCK = [128, 128]


def make_tensors(M, N, K, device="cuda"):
    torch.manual_seed(0)
    A = (torch.randn(M, K, device=device) * 0.01).to(torch.float8_e4m3fn)
    B = (torch.randn(N, K, device=device) * 0.01).to(torch.float8_e4m3fn)
    As = torch.rand(M, (K + BLOCK[1] - 1) // BLOCK[1], device=device)
    Bs = torch.rand((N + BLOCK[0] - 1) // BLOCK[0], (K + BLOCK[1] - 1) // BLOCK[1],
                    device=device)
    return A, B, As, Bs


def _fake_config_factory(M, cfg):
    def fake(n, k, bn, bk):
        return {M: cfg}
    return fake


def warm_one(payload):
    M, N, K, cfg, _ = payload
    A, B, As, Bs = make_tensors(M, N, K)
    orig = fpu.get_w8a8_block_fp8_configs
    fpu.get_w8a8_block_fp8_configs = _fake_config_factory(M, cfg)
    try:
        fpu.w8a8_triton_block_scaled_mm(A, B, As, Bs, BLOCK)
        torch.cuda.synchronize()
        return True
    except Exception:
        return False
    finally:
        fpu.get_w8a8_block_fp8_configs = orig


def bench_one(payload):
    M, N, K, cfg, reps = payload
    A, B, As, Bs = make_tensors(M, N, K)
    orig = fpu.get_w8a8_block_fp8_configs
    fpu.get_w8a8_block_fp8_configs = _fake_config_factory(M, cfg)
    try:
        for _ in range(3):
            fpu.w8a8_triton_block_scaled_mm(A, B, As, Bs, BLOCK)
        torch.cuda.synchronize()
        times = []
        for _ in range(reps):
            torch.cuda.synchronize()
            t0 = time.perf_counter()
            fpu.w8a8_triton_block_scaled_mm(A, B, As, Bs, BLOCK)
            torch.cuda.synchronize()
            times.append(time.perf_counter() - t0)
        med = sorted(times)[len(times) // 2]
        return (M, cfg, med)
    except Exception:
        return (M, cfg, None)
    finally:
        fpu.get_w8a8_block_fp8_configs = orig


def candidate_configs(base):
    """Generate only configs that fit the Radeon R9700's 64KB LDS.
    BN and BK are pinned to 128; larger would overflow.
    BM=128,S=2 and BM=32,S=3 are borderline — warm decides empirically."""
    gm = [8, 16, 32, 64]
    nw = [4, 8]

    def make_cfg(bm, bn, bk, g, w, s):
        return {"BLOCK_SIZE_M": bm, "BLOCK_SIZE_N": bn,
                "BLOCK_SIZE_K": bk, "GROUP_SIZE_M": g,
                "num_warps": w, "num_stages": s}

    out = [base]
    for g, w in itertools.product(gm, nw):
        out.append(make_cfg(16, 128, 128, g, w, 2))
        out.append(make_cfg(16, 128, 128, g, w, 3))
        out.append(make_cfg(32, 128, 128, g, w, 2))
        out.append(make_cfg(32, 128, 128, g, w, 3))
        out.append(make_cfg(64, 128, 128, g, w, 2))
        out.append(make_cfg(128, 128, 128, g, w, 2))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shapes", type=str,
                    default="2048,2048:2048,256:512,2048:4608,2048:6144,2048")
    ap.add_argument("--M", type=str,
                    default="1,2,4,8,16,32,64,128,256,512,1024,2048,4096")
    ap.add_argument("--reps", type=int, default=50)
    ap.add_argument("--warmers", type=int, default=1)
    ap.add_argument("--out", type=str, default="/tmp/w8a8_cfgs")
    args = ap.parse_args()

    Ms = [int(x) for x in args.M.split(",")]
    shapes = [(int(s.split(",")[0]), int(s.split(",")[1]))
              for s in args.shapes.split(":")]
    os.makedirs(args.out, exist_ok=True)

    base = {"BLOCK_SIZE_M": 64, "BLOCK_SIZE_N": 128, "BLOCK_SIZE_K": 128,
            "GROUP_SIZE_M": 32, "num_warps": 4, "num_stages": 2}
    configs = candidate_configs(base)

    # Warm/compile every unique kernel config in parallel across all cores.
    # The Triton cache key is the config dict (N/K are runtime args), so this
    # covers every (shape, M) combination below. Configs that overflow the
    # GPU's shared memory (LDS) fail at load time and are dropped here.
    print(f"### warming {len(configs)} kernels across {args.warmers} workers",
          flush=True)
    warm_tasks = [(1, 2048, 2048, cfg, 1) for cfg in configs]
    good_configs = []
    try:
        with ProcessPoolExecutor(max_workers=args.warmers) as ex:
            for cfg, ok in zip(configs, ex.map(warm_one, warm_tasks, chunksize=1)):
                if ok:
                    good_configs.append(cfg)
    except BrokenProcessPool as e:
        print(f"  pool crashed ({e}), falling back to serial warm", flush=True)
        good_configs.clear()
        for cfg in configs:
            if warm_one((1, 2048, 2048, cfg, 1)):
                good_configs.append(cfg)
    print(f"  warm done: {len(good_configs)}/{len(configs)} kernels usable",
          flush=True)

    for N, K in shapes:
        print(f"### N={N},K={K}: benching {len(good_configs)} configs x "
              f"{len(Ms)} M", flush=True)

        # Bench serially in one process (cache hits, no GPU contention).
        scored = {M: [] for M in Ms}
        for ci, cfg in enumerate(good_configs):
            for M in Ms:
                M2, cfg2, t = bench_one((M, N, K, cfg, args.reps))
                if t is not None:
                    scored[M].append((t, cfg))
            if (ci + 1) % 20 == 0 or ci == len(good_configs) - 1:
                print(f"  bench {ci+1}/{len(good_configs)} configs done",
                      flush=True)
        final = {}
        for M in Ms:
            s = sorted(scored[M], key=lambda x: x[0])
            if not s:
                continue
            best = s[0][1]
            final[M] = best
            print(f"  M={M}: {best['BLOCK_SIZE_M']}/{best['BLOCK_SIZE_N']}/"
                  f"{best['BLOCK_SIZE_K']} g{best['GROUP_SIZE_M']} "
                  f"w{best['num_warps']} s{best['num_stages']}: "
                  f"{s[0][0]*1e6:.0f} us", flush=True)
        fname = (f"/tmp/w8a8_cfgs/N={N},K={K},device_name="
                 f"AMD_Radeon_R9700,dtype=fp8_w8a8,block_shape=[128,128].json")
        with open(fname, "w") as f:
            json.dump({str(k): v for k, v in final.items()}, f, indent=4)
        print(f"  wrote {fname}", flush=True)


if __name__ == "__main__":
    main()
