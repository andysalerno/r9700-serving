# vLLM on Radeon AI PRO R9700

Build and run vLLM from source for AMD Radeon AI PRO R9700 GPUs on ROCm 10. The
default configuration targets two R9700s (`gfx1201`) and serves a model through
vLLM's OpenAI-compatible API, with Hugging Face Chat UI as a frontend.

## Requirements

- Podman with `podman compose` (`docker compose` may work, but is untested)
- [`just`](https://just.systems/)
- One or more R9700 GPUs; the included configuration assumes two
- A ROCm 10-compatible host AMDGPU driver; see AMD's
  [ROCm compatibility matrix](https://rocm.docs.amd.com/en/docs-10.0.0/compatibility/compatibility-matrix.html)

## Build and run

The `justfile` provides the complete workflow:

```sh
# Build localhost/vllm-fullbuild:latest.
just build

# Start vLLM and Chat UI in the background.
just up

# Follow service logs.
just logs

# Stop and remove the containers.
just down
```

The vLLM OpenAI-compatible API is available at
`http://localhost:8000/v1`, and Chat UI is available at
`http://localhost:8001`.

Run `just --list` to see all available recipes.

## Configuration

Build versions and source revisions are pinned in `env/env.fullbuild`. The
build uses `Dockerfile.fullbuild` to install the pinned PyTorch/ROCm stack and
compile Flash Attention, AITER, and vLLM for `gfx1201`.

Runtime settings are in `compose.yaml`, including the model, vLLM command-line
arguments, GPU count, ports, and mounted caches. The default model is
`Qwen/Qwen3.6-27B-FP8` with tensor parallelism set to two GPUs.

The runtime environment is split between:

- `env/2xr9700.vllm.common` for the two-GPU ROCm configuration
- `env/aiter-unified-attention.env` for AITER unified attention

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

The versions of VLLM/ROCm/AITER pinned in the current commit (the one adding this benchmark to the readme) saw these speeds:

(note that this is a single request speed, no concurrent requests)

| model                |            test |              t/s |       peak t/s |         ttfr (ms) |      est_ppt (ms) |     e2e_ttft (ms) |
|:---------------------|----------------:|-----------------:|---------------:|------------------:|------------------:|------------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 | 2385.71 ± 330.07 |                |   880.24 ± 112.31 |   874.79 ± 112.31 |   880.24 ± 112.31 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |   105.10 ± 29.82 | 108.55 ± 30.82 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 |   2935.75 ± 9.05 |                |    1052.21 ± 3.22 |    1046.76 ± 3.22 |    1054.72 ± 3.10 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |     76.51 ± 4.68 |   79.00 ± 4.84 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 | 2692.73 ± 214.37 |                |  1536.21 ± 119.54 |  1530.76 ± 119.54 |  1536.21 ± 119.54 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |   109.08 ± 31.38 | 112.68 ± 32.43 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 |  2844.92 ± 85.41 |                |   2167.18 ± 65.82 |   2161.73 ± 65.82 |   2167.18 ± 65.82 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |   127.89 ± 68.65 | 132.13 ± 70.98 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 |  2775.16 ± 96.64 |                |  3700.08 ± 125.89 |  3694.63 ± 125.89 |  3700.08 ± 125.89 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |   156.02 ± 66.06 | 161.26 ± 68.33 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |  2864.09 ± 28.21 |                |   6442.09 ± 63.74 |   6436.64 ± 63.74 |   6442.09 ± 63.74 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |    92.89 ± 16.83 |  95.94 ± 17.39 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |  2667.29 ± 29.15 |                | 12772.24 ± 140.57 | 12766.79 ± 140.57 | 12772.24 ± 140.57 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |   112.20 ± 66.73 | 115.93 ± 69.02 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |   2307.39 ± 3.96 |                |  28630.69 ± 48.97 |  28625.24 ± 48.97 |  28630.69 ± 48.97 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |   117.57 ± 23.28 | 121.43 ± 24.07 |                   |                   |                   |