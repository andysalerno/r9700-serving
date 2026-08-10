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

```sh
just build       # Build localhost/vllm-fullbuild:latest
just up          # Start vLLM in the background
just logs        # Follow service logs
just down        # Stop and remove containers
```

To use Podman: `just --set runtime podman build` or `RUNTIME=podman just up`.

The vLLM OpenAI-compatible API is available at `http://localhost:8180/v1`.

## Configuration

Build versions are pinned in `env/env.fullbuild`.

| component    | version |
|:-------------|:--------|
| ROCm         | 7.14.0 (`rocm/dev-ubuntu-24.04:7.14.0-full`) |
| PyTorch      | 2.12.0+rocm7.14.0 |
| vLLM         | 0.26.2.dev0+g0406ba22c431 |
| AITER        | v0.1.19.post2 |
| Flash Attention | @ 1cc7ff67 |

Runtime settings are in `compose.yaml`. The active model is
`Qwen/Qwen3.6-35B-A3B-FP8` (MoE, 35B total / 3B active); the dense
`Qwen/Qwen3.6-27B-FP8` is available as a commented alternative.

Runtime environment is split across three files:
- `env/2xr9700.vllm.common` — two-GPU ROCm config (arch, NCCL, HSA)
- `env/aiter-unified-attention.env` — enables AITER unified attention only
- `env/aiter-moe-unified-attention.env` — also enables AITER MoE/FP8 kernels
  (not active: AITER's FP8 MoE backend does not yet support `gfx1201`)

Key tuning decisions:
- **`GPU_MAX_HW_QUEUES=1`** is required. Multiple queues cause a 55-63% decode
  throughput regression on RDNA4 — one queue per process avoids kernel launch
  scheduling overhead.
- **NCCL channels pinned to 4** (`NCCL_MIN_NCHANNELS=NCCL_MAX_NCHANNELS=4`):
  the bandwidth sweet spot for two GPUs on separate PCIe 5.0 x8 root ports with
  P2P disabled.
- **bf16 KV cache**: requires patching AITER's `TILE_SIZE` from 64→32 to stay
  within the R9700's 64 KiB LDS limit. ~2× KV memory cost vs fp8, zero perf
  regression.
- **`--max-num-batched-tokens 4096`** is required for the MoE model (its
  gated-delta layers force an attention block size of 2112 tokens).

## Dead ends

- **W8A8 dense-linear tuning**: only 4 tile shapes fit the 64 KiB LDS limit,
  defaults already optimal — no gain. The MoE kernel succeeded because its
  per-expert N=256/512 allows 24 viable shapes vs 4 for dense.
- **AITER MoE/FP8 backend on gfx1201**: vLLM aborts at startup. Enable once
  upstream AITER adds RDNA4 support.

## Performance

Measured on 2× R9700, MTP4, bf16 KV, single request.

| model                     | pp2048 t/s | tg32 t/s | tg128 t/s |
|:--------------------------|-----------:|---------:|----------:|
| Qwen3.6-27B (andy baseline) |     2750 |    81.9 |    —     |
| Qwen3.6-35B-A3B (no MTP)   |   ~10075 |     ~83 |    —     |
| Qwen3.6-27B-FP8 (current)  |    ~2927 |     ~75 |    ~66   |
| Qwen3.6-35B-A3B-FP8 (current) | ~10864 |    ~182 |   ~144   |

Full methodology, depth sweeps, and tuning history in
[`BENCHMARKS.md`](BENCHMARKS.md).
