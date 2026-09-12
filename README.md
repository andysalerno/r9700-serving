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
# Optionally build localhost/vllm-fullbuild:0.29.0 ahead of time.
just build

# Build the pinned image, start vLLM and Chat UI, and wait for readiness.
just up

# Follow service logs.
just logs

# Stop and remove the containers.
just down
```

The vLLM OpenAI-compatible API is available at
`http://localhost:8000/v1`, and Chat UI is available at
`http://localhost:8001`.

`just up` always builds with the current pins (reusing unchanged build layers)
instead of reusing an old `latest` image. The custom vLLM image is tagged with
`VLLM_VERSION` and is never pulled from a registry.

Chat UI starts only after vLLM's healthcheck passes because it fetches the model
list during startup. `just up` waits for vLLM to finish loading and warming up
before starting Chat UI, then waits for both services to be running, with a
30-minute readiness timeout. Image building happens before that timeout;
a cold build or startup can take several minutes.

Run `just --list` to see all available recipes.

## Configuration

Build versions and source revisions are pinned in `env/env.fullbuild`. The
build uses `Dockerfile.fullbuild` to install the pinned PyTorch/ROCm stack and
compile Flash Attention, AITER, and vLLM for `gfx1201`.

The dependency pins were reviewed on 2026-09-11:

| Component | Pin |
|---|---|
| ROCm | `10.0.0-full` (latest available ROCm 10 image), pinned by digest `sha256:a90cf047f615abe70fbef83c64def0a2d549ef37a39c8ea545430aba4981b374` |
| PyTorch / torchvision / torchaudio | `2.13.0` / `0.28.0` / `2.11.0.2`, all `+rocm10.0.0`, from [AMD's stable wheel index](https://stable.repo.amd.com/rocm/whl-next/) |
| Triton | AMD's `3.8.0+git4cff872c.rocm10.0.0`, explicitly pinned to the build required by PyTorch |
| AITER | [`f361bd39ba41`](https://github.com/ROCm/aiter/commit/f361bd39ba4196ce29391c628d4ebf72e7929ab8), latest `main` revision |
| Flash Attention | [`a369df707e19`](https://github.com/ROCm/flash-attention/commit/a369df707e1980fb328abcc1733e3457ec10155f), from ROCm's `tridao` branch using the Triton AMD backend, not the CK-only release tags |
| vLLM | Exact [`v0.29.0` source](https://github.com/vllm-project/vllm/commit/98dff2a81d747d1dba01a47f939f48c3526d4206), packaged as `0.29.0+rocm100.gfx1201` |
| Chat UI | Latest `ghcr.io/huggingface/chat-ui-db` image, pinned by digest `sha256:e5cf682821859f5141905d0b1da515f75add6e54e98befbdcf7b00120ae63167` |

PyTorch 2.13 matches vLLM v0.29.0's
[`CMakeLists.txt`](https://github.com/vllm-project/vllm/blob/v0.29.0/CMakeLists.txt)
and [`pyproject.toml`](https://github.com/vllm-project/vllm/blob/v0.29.0/pyproject.toml).
Its ROCm Dockerfile still defaults to the older 2.12 line; this build uses the
source's expected version and AMD's matching `gfx1201` device wheels instead.
Pip constraints retain the pinned PyTorch/Triton stack throughout the build and
runtime installation, including nested Flash Attention/AITER installers.
`AITER_USE_SYSTEM_TRITON=1` prevents those installers from replacing AMD Triton.
Flash Attention's bundled AITER is moved to `AITER_REF` before building, so its
nested installer does not pull an older AITER with unavailable dependencies.
The native Rust components use vLLM's pinned toolchain and `build_rust.sh`;
v0.29.0 generates protobuf code in Rust and no longer uses `install_protoc.sh`.

`VLLM_REF` selects the source; `VLLM_VERSION` sets the package version and local
image tag. Keep them aligned when upgrading releases. The historical
configurations under `archive/` are not updated.

Runtime settings are in `compose.yaml`, including the model, vLLM command-line
arguments, GPU count, ports, and mounted caches. The default model is
`Qwen/Qwen3.8-27B-FP8` with tensor parallelism set to two GPUs, FP8 KV cache,
AITER unified attention, and three-token MTP speculative decoding.

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