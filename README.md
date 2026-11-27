# vLLM on Radeon AI PRO R9700

Build and run vLLM from source for AMD Radeon AI PRO R9700 GPUs on ROCm 10. The
default configuration targets two R9700s (`gfx1201`) and serves
[Inkling 2 Mini](https://huggingface.co/thinkingmachines/Inkling-2-Mini) through
vLLM's OpenAI-compatible API, with Hugging Face Chat UI as a frontend.

## Requirements

- Podman with `podman compose` (`docker compose` may work, but is untested)
- [`just`](https://just.systems/)
- One or more R9700 GPUs; the included configuration assumes two
- A ROCm 10-compatible host AMDGPU driver; see AMD's
  [ROCm compatibility matrix](https://rocm.docs.amd.com/en/docs-10.2.0/compatibility/compatibility-matrix.html)

## Build and run

The `justfile` provides the complete workflow:

```sh
# Optionally build localhost/vllm-fullbuild:$VLLM_IMAGE_TAG ahead of time.
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
`VLLM_IMAGE_TAG` and is never pulled from a registry.

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

The dependency pins were reviewed on 2026-11-22:

| Component | Pin |
|---|---|
| ROCm | `10.2.0-full` (latest available ROCm 10 image), pinned by digest `sha256:21801c0ba1bc4aba31f81ab11fe576c43daa7f2c7f42bac7baaa4d2f75273f86` |
| PyTorch / torchvision / torchaudio | `2.14.0` / `0.29.2` / `2.11.1`, all `+rocm10.2.0`, from [AMD's stable wheel index](https://stable.repo.amd.com/rocm/whl-next/) |
| Triton | AMD's `3.9.0+git0a6e13e6.rocm10.2.0`, explicitly pinned to the build required by PyTorch |
| AITER | [`v0.1.30`](https://github.com/ROCm/aiter/commit/77ba72b7061a3c76c4f726a50e8edfd2fe2a80e7), the latest release and tip of the `release/v0.1.30` line |
| Flash Attention | [`aae6770da7df`](https://github.com/ROCm/flash-attention/commit/aae6770da7dfd2bafd57d2d0ee3d1428b62f4334), the tip of ROCm's `tridao` branch using the Triton AMD backend, not the CK-only release tags |
| vLLM | [`bb6ea4e1a55c`](https://github.com/andysalerno/vllm/commit/bb6ea4e1a55cdbc5acbab59ed0051d672980b4a6) on `andysalerno/vllm` branch `inkling2-rdna4`, packaged as `0.35.0.dev0+gbb6ea4e1a55c.rocm102.gfx1201` (see [Inkling 2 Mini](#inkling-2-mini)) |
| Chat UI | Latest `ghcr.io/huggingface/chat-ui-db` image, pinned by digest `sha256:3cb93a2a3f53aacf0927f4bfd3114a2eccfefb8e417a6b042f755b42253d2c30` |

### Updating the fullbuild pins

The versions in `env/env.fullbuild` form two different kinds of constraints:

- **Move together:** The ROCm base image, AMD PyTorch, torchvision, torchaudio,
  and Triton wheels form one native stack. Use the matching versions published
  in [AMD's ROCm wheel index](https://stable.repo.amd.com/rocm/whl-next/),
  including the `gfx1201` device wheel, rather than bumping any wheel alone.
  vLLM v0.34.0 declares PyTorch 2.14 in
  [`CMakeLists.txt`](https://github.com/vllm-project/vllm/blob/v0.34.0/CMakeLists.txt)
  and requires exactly `torch == 2.14.0` in
  [`pyproject.toml`](https://github.com/vllm-project/vllm/blob/v0.34.0/pyproject.toml),
  so keep PyTorch on 2.14.0 even though AMD also publishes 2.15 wheels.
  CMake warns rather than failing on a ROCm PyTorch version mismatch; the
  declared version is nevertheless the right starting point for this build.
  AMD publishes torch 2.14.0 for ROCm 10.2, so the stack moves to the newer
  ROCm 10.2 image and wheels. torchvision `0.29.2` and torchaudio `2.11.1` are
  AMD's newest ROCm 10.2 builds; both are Python-version-independent wheels
  that accept this PyTorch (`torch>=2.14.0` and `torch>=2.11`).
  Upstream's [ROCm base Dockerfile](https://github.com/vllm-project/vllm/blob/v0.34.0/docker/Dockerfile.rocm_base)
  still uses PyTorch 2.13 on ROCm 10.0, and its
  [TheRock build requirements](https://github.com/vllm-project/vllm/blob/v0.34.0/requirements/build/rock.txt)
  an older PyTorch 2.12 stack. Do not mix individual pins from those paths with
  this ROCm 10.2 wheel stack. PyTorch's wheel metadata requires its exact Triton
  build: torch 2.14.0 on ROCm 10.2 requires Triton 3.9 (`0a6e13e6`), whereas
  upstream's ROCm base images still use the 3.8 commit (`669b31ac`).
- **Review and rebuild independently:** AITER and Flash Attention are built
  from source against that installed PyTorch/Triton stack. Their upstream
  revisions need not match vLLM's ROCm Dockerfile pins exactly, but newer
  revisions are *not* guaranteed compatible: check their build requirements
  and GPU support, then rebuild the image and test inference before adopting
  them. AITER tracks its `release/*` branches rather than `main`; the current
  pin is the published `v0.1.30` release. vLLM v0.34.0's ROCm base Dockerfile
  pins `v0.1.28.post1`, and vLLM `main` has since moved to `v0.1.29.post1`;
  `v0.1.30` is newer than either.
  vLLM's [ROCm runtime requirements](https://github.com/vllm-project/vllm/blob/v0.34.0/requirements/rocm.txt)
  are copied from the selected vLLM source and installed at build time;
  preserve their own exact pins and paired-package constraints rather than
  overriding them independently.
- **Release and unrelated UI:** Keep `VLLM_REF` and `VLLM_VERSION` aligned
  with the same release (or, for a development commit, the version its tree
  declares). Chat UI is a separate service and can be updated
  independently after checking its image and configuration.

Pip constraints retain the pinned PyTorch/Triton stack throughout the build and
runtime installation, including nested AITER installers.
`AITER_USE_SYSTEM_TRITON=1` prevents those installers from replacing AMD Triton.
Flash Attention's Triton backend runs AITER's kernels. The build sets
`FLASH_ATTENTION_USE_SYSTEM_AITER=TRUE` and installs the pinned AITER wheel
first, so Flash Attention neither builds nor installs its bundled
`third_party/aiter`; the image contains only the `AITER_REF` build.
The native Rust frontend (`vllm-rs`) uses vLLM's pinned toolchain and
`tools/build_rust.sh`.
The runtime preloads ROCm PyTorch via `sitecustomize.py` in every Python process,
including vLLM's model-inspection subprocesses. v0.30.0 added, and v0.34.0
retains, a ROCm GPU profiling helper in `vllm/env_override.py` that loads
`libtorch_cpu.so` before PyTorch; with this wheel stack that order registers
LLVM's `spirv-expand-step` option twice and aborts at startup. Loading PyTorch first avoids the crash,
but may bypass that helper's early GPU profiling setup. Keep this ordering
when changing the runtime until the underlying incompatibility is resolved.

ROCm 10.1 also changed two runtime details, and ROCm 10.2 retains both.
`/opt/rocm/share/amd_smi` is no longer a pip project, so the runtime imports
that relocatable `amdsmi` tree in place through a `.pth` file; PyPI's older
`amdsmi` does not match ROCm 10.1+'s `libamd_smi.so.27`. The pip SDK's
`hipcc` now forces `--rocm-path` to its own tree, which lacks device
libraries, so AITER's runtime JIT failed. The runtime
puts the base image's complete `/opt/rocm` toolchain first on `PATH`; it uses
the same clang and HIP versions, and a build-time HIP compile checks it.

`VLLM_REPO` and `VLLM_REF` select the source; `VLLM_VERSION` sets the package
version and `VLLM_IMAGE_TAG` the local image tag. Keep them aligned when
upgrading releases. The historical
configurations under `archive/` are not updated.

Runtime settings are in `compose.yaml`, including the model, vLLM command-line
arguments, GPU count, ports, and mounted caches. The default model is
`thinkingmachines/Inkling-2-Mini`; see [Inkling 2 Mini](#inkling-2-mini).

The runtime environment is split between:

- `env/2xr9700.vllm.common` for the two-GPU ROCm configuration
- `env/aiter-unified-attention.env` for AITER unified attention (used by
  models served through vLLM's attention backends; Inkling 2 brings its own
  kernels and does not use it)

Edit these files and `compose.yaml` to match your hardware and model before
building or starting the services.

To remove the generated host-side vLLM, Triton, TorchInductor, AITER, COMGR,
and TVM FFI caches, run:

```sh
just clear-vllm-caches
```

The Hugging Face model cache is intentionally preserved.

## Inkling 2 Mini

vLLM releases run Inkling 2 Mini on NVIDIA only. The image builds vLLM from
[`andysalerno/vllm` branch `inkling2-rdna4`](https://github.com/andysalerno/vllm/tree/inkling2-rdna4):
vLLM main of 2026-11-25 with the open ROCm Inkling 2 port
([vllm-project/vllm#67685](https://github.com/vllm-project/vllm/pull/67685),
written for MI300/MI355), extended to RDNA4, the looped layers of Inkling 2 Mini,
its NVFP4 experts, and its bundled DSpark draft. The changes are Python and
Triton only. It serves Thinking Machines' checkpoint as published (NVFP4 and
MXFP8 experts); the expert GEMMs decode those weights exactly and keep the
activations in bf16.

The service runs tensor parallelism over both GPUs with a 589,824-token
context and DSpark speculative decoding with three draft tokens.

| Measurement (2x R9700, TP=2) | Result |
|---|---|
| Wikitext-2 perplexity (32x1024 windows) | 7.438 (top-1 agreement 0.976), vs 7.437 for a Hugging Face bf16 reference |
| Needle retrieval | passes at 553,873 tokens (30% and 80% depth) |
| Prefill | ~3,500 tok/s at 64K, ~3,000 tok/s at 128K |
| Decode, chat, 1 / 2 / 4 requests | ~87 / 142 / 210 tok/s (aggregate) |
| Decode without DSpark, 1 / 2 / 4 requests | ~64 / 111 / 172 tok/s |
| 261,386-token prompt, 1 request | prefill 2,148 tok/s (122 s to first token), decode ~50-59 tok/s |
| 523,405-token prompt, 1 request | prefill 1,464 tok/s (358 s to first token), decode ~35 tok/s |

The long-context rows use real source code as the prompt with a request to
explain it; decode includes DSpark (about 2.2 tokens accepted per step).

Settings that matter on these GPUs:

- `NCCL_CUMEM_ENABLE=1` and `NCCL_GRAPH_REGISTER=0` replace
  `NCCL_P2P_DISABLE=1`. Legacy HIP IPC handles fail between the two R9700s,
  which is why P2P was disabled; RCCL's cuMem path gives PCIe peer-to-peer
  instead, and graph buffer registration must be off for CUDA graph capture.
- `--max-num-batched-tokens 2048`: with 4096 the activation reserve leaves
  room for only ~350K tokens of context with DSpark; 1024 fits ~713K. Without
  DSpark (drop `--speculative-config`), 2048 fits ~785K and 1024 ~905K.
- Three DSpark draft tokens beat the checkpoint's seven (~50 tok/s for one
  request): later block positions are rarely accepted, and each verified token
  reads more experts.
- `TORCHINDUCTOR_CACHE_DIR` puts the compiled Triton kernels in the mounted
  `~/.cache/torchinductor` (vLLM points Triton at the inductor cache, which
  is otherwise under `/tmp` in the container and lost on restart). The first
  requests of a new image compile a bounded set of kernels (up to a few
  seconds each); later restarts reuse them.
- `cpuset: "0-5,12-17"` keeps vLLM on the Ryzen 9 9900X3D's V-cache CCD of
  this host. Unpinned, decode at four requests drops to ~160 tok/s; adjust or
  remove it on other CPUs.

Decode runs slower (~35 tok/s for one request) for the first 20-60 s of
generation after the GPUs have been idle, then reaches full speed; benchmark
after a warmup.

## Archived approach

The older multi-profile, patched-image approach remains in [`archive/`](archive/)
for reference.

## Benchmark

The latest results are the [2026-09-24 Qwen3.8-27B-FP8 benchmark](benchmarks/09_24_fullbuild_aiter_vllm30.md),
including the repository revision and running vLLM 0.30.0 service configuration.
The [2026-09-11 vLLM 0.29.0 results](benchmarks/09_11_fullbuild_aiter_vllm29.md)
are preserved for comparison.

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