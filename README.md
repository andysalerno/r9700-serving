# vLLM on Radeon AI PRO R9700

Build and run vLLM from source for AMD Radeon AI PRO R9700 GPUs. The default
configuration targets two R9700s (`gfx1201`) and serves a model through vLLM's
OpenAI-compatible API.

## Requirements

- Podman with the Compose plugin (`podman compose`), or Docker (`docker
  compose`); `just` recipes default to Podman
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

To use Docker instead of Podman, set the runtime for a single invocation:

```sh
just --set runtime docker build
RUNTIME=docker just up
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

## Benchmark

Current per-model bests (single request, 2026-08-07, MTP4, bf16 KV):

| model                     | pp2048 t/s | ttfr (ms) | tg32 t/s | tg128 t/s |
|:--------------------------|-----------:|----------:|---------:|----------:|
| Qwen/Qwen3.6-27B-FP8      |     2965.4 |      692.6 |     83.9 |      70.9 |
| Qwen/Qwen3.6-35B-A3B-FP8  |    10161.6 |      202.9 |    172.5 |     153.7 |

The MoE 35B-A3B is ~2x faster on decode and ~3.4x faster on prefill/TTFT than
the dense 27B. Full tables, tuning sweeps, and findings are in
[`BENCHMARKS.md`](BENCHMARKS.md).
