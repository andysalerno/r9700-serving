# vLLM on Radeon AI PRO R9700

Build and run vLLM from source for AMD Radeon AI PRO R9700 GPUs. The default
configuration targets two R9700s (`gfx1201`) and serves a model through vLLM's
OpenAI-compatible API.

## Requirements

- Docker with the Compose plugin (`docker compose`), or Podman (`podman
  compose`); `just` recipes default to Docker
- [`just`](https://just.systems/)
- SELinux hosts need no special relabeling: bind mounts mount unlabeled because
  the container runs with `label=disable`
- One or more R9700 GPUs; the included configuration assumes two

## Quick start

The `justfile` provides the complete workflow:

```sh
# Build localhost/vllm-fullbuild:latest.
just build

# Start vLLM in the background.
just up

# Follow service logs.
just logs

# Stop and remove the containers.
just down
```

To use Podman instead of Docker, set the runtime for a single invocation:

```sh
just --set runtime podman build
RUNTIME=podman just up
```

The vLLM OpenAI-compatible API is available at
`http://localhost:8180/v1`.

Run `just --list` to see all available recipes.

## Configuration

Build versions and source revisions are pinned in `env/env.fullbuild`. The
build uses `Dockerfile.fullbuild` to install the pinned PyTorch/ROCm stack and
compile Flash Attention, AITER, and vLLM for `gfx1201`.

Pinned software stack (all at/near head as of 2026-08):

| component    | version                                                              |
|:-------------|:---------------------------------------------------------------------|
| ROCm         | 7.14.0 (`rocm/dev-ubuntu-24.04:7.14.0-full`, HIP 7.14.60850)         |
| PyTorch      | 2.12.0+rocm7.14.0 (torchvision 0.27.0+rocm7.14.0)                    |
| vLLM         | 0.26.2.dev0+g0406ba22c431, built from `vllm-project/vllm` main @ 0406ba22c431 (2026-08-07) |
| AITER        | v0.1.19.post2 @ a63ede724b                                           |
| Flash Attention | @ 1cc7ff67                                                         |

Notes:

- ROCm 7.14.0 is on the "TheRock" Core SDK technology-preview stream (7.9/7.13/7.14,
  new 6-week cadence, no upgrade path from the production 7.2.x line). The current
  production stream is 7.2.4. The preview stream is required for RDNA4/`gfx1201`
  support and torch 2.11.
- AITER `v0.1.19.post2` is the latest tagged release (a hotfix on `v0.1.19`).
- vLLM `0.26.2.dev0` is a dev build ahead of the latest stable release (0.26.0),
  since `gfx1201` support requires a custom ROCm build from source.

Runtime settings are in `compose.yaml`, including the model, vLLM command-line
arguments, GPU count, ports, and mounted caches. Two Qwen3.6 models are
supported; the active one is uncommented in the service and the other is kept
as a comment for easy switching:

- `Qwen/Qwen3.6-35B-A3B-FP8` (MoE, 35B total / 3B active) — fastest
  throughput; the current active default
- `Qwen/Qwen3.6-27B-FP8` (dense, all 27B active) — more capable reasoning
  model, slower on both prefill and decode

The runtime environment is split between:

- `env/2xr9700.vllm.common` for the two-GPU ROCm configuration
- `env/aiter-unified-attention.env` for the AITER unified-attention baseline
  (the active configuration)
- `env/aiter-moe-unified-attention.env` enables AITER MoE/FP8 kernels in
  addition, but AITER's FP8 MoE backend does not yet support `gfx1201`
  (vLLM aborts at startup), so it is not used by default

The two GPUs sit on separate PCIe 5.0 x8 root ports routed through the CPU, and
P2P is disabled (`NCCL_P2P_DISABLE=1`), so all TP-2 traffic bounces through
host memory (SHM). NCCL channel count is pinned to 4
(`NCCL_MIN_NCHANNELS`/`NCCL_MAX_NCHANNELS` in `env/2xr9700.vllm.common`):
`all_reduce_perf` measured 4 channels as the bandwidth sweet spot across
message sizes (see [`BENCHMARKS.md`](BENCHMARKS.md)), and a serving A/B
improved tg128 decode by ~12-19% over the old 112-channel setting.

The gated-delta (Mamba-style) layers of the MoE `Qwen/Qwen3.6-35B-A3B-FP8`
config force an attention block size of 2112 tokens (2176 with MTP), so
`--max-num-batched-tokens 4096` is required for that model (the default of
2048 fails with a Mamba cache align assertion). The dense 27B has no such
constraint; 4096 is retained as a latency-friendly middle ground.

Edit these files and `compose.yaml` to match your hardware and model before
building or starting the services.

To remove the generated host-side vLLM, Triton, TorchInductor, AITER, COMGR,
and TVM FFI caches, run:

```sh
just clear-vllm-caches
```

The Hugging Face model cache is intentionally preserved.

## Archived approach

The older multi-profile, patched-image approach remains in [`archive/`](archive/)
for reference.

## Abandoned explorations

**W8A8 Block FP8 dense-linear tuning** (2026-08-09). A micro-benchmark harness
(`tools/tune_w8a8_fp8.py`) swept 49 viable block configurations (BM ∈ {16,32,64,128},
BK=128, BN=128; νw ∈ {4,8}, stages ∈ {2,3}) across 5 projection shapes
(N×K = 2048×2048, 2048×256, 512×2048, 4608×2048, 6144×2048) on GPU0 to select
per-M optimal configs. The full 512-config space was filtered early — 90% of
candidates overflow the R9700's 64 KB LDS and were removed. A persistent Triton
cache on the host enabled fast re-runs, and the LDS filter avoided GPU hangs
(ROCm timeout on oversize launches).

Tuned configs were deployed via bind mount into the vLLM configs directory and
A/B tested against stock defaults with `llama-benchy` (pp2048/tg32, Qwen3.6
35B-A3B). **Result: no measurable gain** (11038 vs 11019 t/s pp2048, 187 vs 186
t/s tg32 — within noise). The default configs already saturate the dense linear
kernel. Why did the MoE `fused_moe` tuning succeed (+5-11%) while this one
failed? The LDS limit hits the two kernels differently:

| parameter           | dense W8A8    | MoE `fused_moe` |
|:--------------------|:-------------|:----------------|
| viable BM           | 16,32,64,128 | 16,32,64,128    |
| viable BN           | **128 only** | 128, 256, 512   |
| viable BK           | **128 only** | 128, 256        |
| tile-shape combos   | 4×1×1 = 4    | 4×3×2 = 24      |

The dense kernel has N ≥ 512 but the block limit cares about BN, not N —
BN=256 overflows 64 KB LDS regardless of the matrix dimension. The MoE kernel's
per-expert N of 256 or 512 keeps BN within range, giving it a much larger search
space (BK=256 halves inner-loop trips, BN=256 halves thread blocks along N).
Dense W8A8, with its four viable tile shapes, has nothing left to tune — the
default configs already pick the optimal BM for each M. Abandoned.

## Performance vs upstream fork

All changes in this repo are additive to
[andysalerno/r9700-serving](https://github.com/andysalerno/r9700-serving),
which provided the base Docker build for `gfx1201`, AITER unified
attention, MTP3 speculative decoding, and the default Qwen3.6-27B
config. The deltas below are measured on the same 2× R9700 hardware.

### Qwen3.6 27B (dense) — downstream additions

| change                               | pp2048 (t/s) | tg32 (t/s) | delta |
|:-------------------------------------|-------------:|-----------:|------:|
| andysalerno baseline (MTP3, fp8 KV) |         2750 |       81.9 | — |
| + MTP4 + bf16 KV                     |         2993 |       80.8 | +9% prefill, decode flat |

### Qwen3.6 35B-A3B (MoE) — all downstream additions

| change                               | pp2048 (t/s) | tg32 (t/s) | delta |
|:-------------------------------------|-------------:|-----------:|------:|
| andysalerno baseline (27B only)     |          n/a |        n/a | — |
| + switch to 35B-A3B + MTP4 + bf16 KV |       10162 |      172.5 | MoE model added |
| + NCCL channel tuning (112→4 ch)     |          —  |        —   | +12-19% tg128 |
| + tuned fused_moe configs            |      ~11000 |      ~187  | +5-11% prefill & decode |

### What each change does

| change | mechanism | impact |
|:-------|:----------|:-------|
| **35B-A3B model support** | Switched default model; added MTP4, `--max-num-batched-tokens 4096`, served-model-name aliasing | 3.4× faster prefill and 2× faster decode than the 27B; active-expert MOE trades capacity for speed |
| **MTP4** | Increased draft tokens from 3→4 (72.3% acceptance rate on 35B-A3B) | +9% prefill on 27B; part of the MoE decode uplift |
| **bf16 KV cache** | Patches AITER's TILE_SIZE from 64→32 to fit 64 KB LDS with bf16 KV (upstream used fp8 KV which already fit); ~2× KV memory cost but zero perf regression | Better model quality; zero perf cost |
| **NCCL 4-channel** | Replaced auto-tuned 112-channel NCCL with pinned 4-channel config; `all_reduce_perf` confirmed 4 is the bandwidth sweet spot across all message sizes | +12-19% tg128 decode on 35B |
| **tuned fused_moe configs** | Triton kernel tile-size sweep for the MoE gate+gemm kernel; deployed via `VLLM_TUNED_CONFIG_FOLDER` | +5-11% prefill and decode on 35B |
| **Docker support** | Added `just --set runtime docker` support alongside existing Podman; removed SELinux `:Z` labels for non-SELinux hosts | Zero performance difference; broader compatibility |
| **comprehensive benchmarks** | Moved per-run tables to `benchmarks/`, built `BENCHMARKS.md` with depth sweeps, concurrency scaling, NCCL tuning, long context | Documented the performance envelope |
| **W8A8 dense tuning** (abandoned) | Same approach as fused_moe for dense linear W8A8; only 4 tile shapes fit 64 KB LDS vs 24 for MoE | No gain; defaults already optimal |

## Benchmark

Current per-model bests (single request, 2026-08-09, MTP4, bf16 KV):

| model                     | pp2048 t/s | ttfr (ms) | tg32 t/s | tg128 t/s |
|:--------------------------|-----------:|----------:|---------:|----------:|
| Qwen/Qwen3.6-27B-FP8      |  ~2965.4   |    ~692.6 |   ~83.9  |   ~70.9   |
| Qwen/Qwen3.6-35B-A3B-FP8  |     ~11000 |      ~187 |     ~187 |     ~153   |

The MoE 35B-A3B is ~2x faster on decode and ~3.4x faster on prefill/TTFT than
the dense 27B. Full tables, tuning sweeps, and findings are in
[`BENCHMARKS.md`](BENCHMARKS.md).
