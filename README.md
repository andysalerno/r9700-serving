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
# Optionally build localhost/vllm-fullbuild:0.30.0 ahead of time.
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

The dependency pins were reviewed on 2026-09-24:

| Component | Pin |
|---|---|
| ROCm | `10.0.0-full` (latest available ROCm 10 image), pinned by digest `sha256:a90cf047f615abe70fbef83c64def0a2d549ef37a39c8ea545430aba4981b374` |
| PyTorch / torchvision / torchaudio | `2.13.0` / `0.28.0` / `2.11.0.2`, all `+rocm10.0.0`, from [AMD's stable wheel index](https://stable.repo.amd.com/rocm/whl-next/) |
| Triton | AMD's `3.8.0+git4cff872c.rocm10.0.0`, explicitly pinned to the build required by PyTorch |
| AITER | [`v0.1.22.post1`](https://github.com/ROCm/aiter/commit/b4d9154d125e09efbe098d986e40fea3549c1244), pinned to the release commit |
| Flash Attention | [`a369df707e19`](https://github.com/ROCm/flash-attention/commit/a369df707e1980fb328abcc1733e3457ec10155f), from ROCm's `tridao` branch using the Triton AMD backend, not the CK-only release tags |
| vLLM | Exact [`v0.30.0` source](https://github.com/vllm-project/vllm/commit/ced6857afa0ea7b2e3f0846a62e1394e90f15607), packaged as `0.30.0+rocm100.gfx1201` |
| Chat UI | Latest `ghcr.io/huggingface/chat-ui-db` image, pinned by digest `sha256:36ebe494d7cc5c703274575ee4bb056e541f3395aa3bb716d60906a18952066c` |

### Updating the fullbuild pins

The versions in `env/env.fullbuild` form two different kinds of constraints:

- **Move together:** The ROCm base image, AMD PyTorch, torchvision, torchaudio,
  and Triton wheels form one native stack. Use the matching versions published
  in [AMD's ROCm wheel index](https://stable.repo.amd.com/rocm/whl-next/),
  including the `gfx1201` device wheel, rather than bumping any wheel alone.
  vLLM v0.30.0 declares PyTorch 2.13 in
  [`CMakeLists.txt`](https://github.com/vllm-project/vllm/blob/v0.30.0/CMakeLists.txt)
  and [`pyproject.toml`](https://github.com/vllm-project/vllm/blob/v0.30.0/pyproject.toml).
  CMake warns rather than failing on a ROCm PyTorch version mismatch; the
  declared version is nevertheless the right starting point for this build.
  Upstream's [ROCm base Dockerfile](https://github.com/vllm-project/vllm/blob/v0.30.0/docker/Dockerfile.rocm_base)
  and [ROCm build requirements](https://github.com/vllm-project/vllm/blob/v0.30.0/requirements/build/rocm.txt)
  still use a different, older PyTorch 2.12 / ROCm stack. Do not mix individual
  pins from those paths with this ROCm 10 wheel stack.
- **Review and rebuild independently:** AITER and Flash Attention are built
  from source against that installed PyTorch/Triton stack. Their upstream
  revisions need not match vLLM's ROCm Dockerfile pins exactly, but newer
  revisions are *not* guaranteed compatible: check their build requirements
  and GPU support, then rebuild the image and test inference before adopting
  them. The Flash Attention `tridao` branch has not moved since its current
  pin. Keep its bundled AITER submodule on the same `AITER_REF` as the
  separately built wheel. vLLM's [ROCm runtime requirements](https://github.com/vllm-project/vllm/blob/v0.30.0/requirements/rocm.txt)
  are copied from the selected vLLM source and installed at build time;
  preserve their own exact pins and paired-package constraints rather than
  overriding them independently.
- **Release and unrelated UI:** Keep `VLLM_REF` and `VLLM_VERSION` aligned
  with the same release. Chat UI is a separate service and can be updated
  independently after checking its image and configuration.

Pip constraints retain the pinned PyTorch/Triton stack throughout the build and
runtime installation, including nested Flash Attention/AITER installers.
`AITER_USE_SYSTEM_TRITON=1` prevents those installers from replacing AMD Triton.
Flash Attention's bundled AITER is moved to `AITER_REF` before building, so its
nested installer does not pull an older AITER with unavailable dependencies.
The native Rust components use vLLM's pinned toolchain and `build_rust.sh`;
v0.30.0 generates protobuf code in Rust and no longer uses `install_protoc.sh`.
The runtime preloads ROCm PyTorch via `sitecustomize.py` in every Python process,
including vLLM's model-inspection subprocesses. v0.30.0 added a ROCm GPU
profiling helper in `vllm/env_override.py` that loads `libtorch_cpu.so` before
PyTorch; with this wheel stack that order registers LLVM's `spirv-expand-step`
option twice and aborts at startup. Loading PyTorch first avoids the crash,
but may bypass that helper's early GPU profiling setup. Keep this ordering
when changing the runtime until the underlying incompatibility is resolved.

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

The latest results are the [2026-09-11 Qwen3.8-27B-FP8 benchmark](benchmarks/09_11_fullbuild_aiter_vllm29.md),
including the repository revision and running vLLM 0.29.0 service configuration.

The historical [2026-07-22 Qwen3.6-27B-FP8 results](benchmarks/07_22_fullbuild_aiter.md)
are preserved below:

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