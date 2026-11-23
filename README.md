# Inkling 2 Mini on Radeon AI PRO R9700

This branch serves [Inkling 2 Mini](https://huggingface.co/thinkingmachines/Inkling-2-Mini)
as fast as possible on two AMD Radeon AI PRO R9700 GPUs (`gfx1201`), at the
model's full 1M-token context, with Hugging Face Chat UI as a frontend. The
`main` branch tracks the latest vLLM for the same hardware.

vLLM cannot serve Inkling 2 Mini on ROCm yet (see [Why not vLLM](#why-not-vllm)),
so this branch uses llama.cpp. It should move to vLLM once vLLM supports the
model on RDNA4.

## Requirements

- Podman with `podman compose` (`docker compose` may work, but is untested)
- [`just`](https://just.systems/)
- The [`hf`](https://huggingface.co/docs/huggingface_hub/guides/cli) CLI, to download the model
- Two R9700 GPUs
- A ROCm 10-compatible host AMDGPU driver; see AMD's
  [ROCm compatibility matrix](https://rocm.docs.amd.com/en/docs-10.2.0/compatibility/compatibility-matrix.html)

## Build and run

```sh
# Download the pinned GGUFs (about 23.5 GB) and verify their checksums.
just download

# Optionally build localhost/llama-cpp-inkling ahead of time.
just build

# Download, build, start llama.cpp and Chat UI, and wait for readiness.
just up

# Follow service logs.
just logs

# Stop and remove the containers.
just down
```

The OpenAI-compatible API is available at `http://localhost:8000/v1` (model
`inkling-2-mini`), and Chat UI at `http://localhost:8001`. Chat, reasoning
(`reasoning_effort`), tool calls, and image input work. The model files are
stored under `~/.cache/llama.cpp/inkling-2-mini/<revision>/` and mounted
read-only.

## How it is served

`Dockerfile.inkling` builds llama.cpp for `gfx1201` (HIP) from pinned sources
on the same ROCm 10.2 image as the vLLM fullbuild:

- Upstream llama.cpp tag `b12645`, plus the 42 pinned PR commits in
  [`inkling/llama-cpp-pins.txt`](inkling/llama-cpp-pins.txt), merged in order.
- The pins are Unsloth's prebuilt pin set (`scripts/unsloth/pr-set.json` at
  `unslothai/llama.cpp` `ff43f5ef`), which carries Inkling 2 support that
  mainline llama.cpp lacks, with one change: #385 is dropped and #386 is
  replaced by [unslothai/llama.cpp#406](https://github.com/unslothai/llama.cpp/pull/406),
  banded relative-bias attention on AMD WMMA (stacked on #386 and #385).
- Pure add/add conflicts between pins are resolved with Unsloth's
  `additive_merge.py`, as their CI does; any other conflict fails the build.
  The build then checks that the merged source tree hashes to `LLAMA_CPP_TREE`
  in `env/env.inkling`.

PR #406 is what makes long contexts fast on RDNA4. Without it, Inkling 2's
relative-position bias forces a dense attention path that falls to 136 tok/s
prefill at 64K tokens. #406 changes only the attention kernel's accumulation
order; its output differs from the dense path by a mean KL divergence of
0.0018 (98.7% same top token), the same as the difference between llama.cpp's
Vulkan and HIP backends (0.0018, 98.5%). It retrieves a passphrase planted at
10%, 50% and 90% depth of 64K and 128K-token prompts.

### Model files and precision

The weights come from one pinned revision of
[`unsloth/Inkling-2-Mini-GGUF`](https://huggingface.co/unsloth/Inkling-2-Mini-GGUF),
listed with their SHA-256 checksums in `env/env.inkling`:

- `Mainline_Support/Inkling-2-Mini-UD-Q8_K_XL.gguf_file`, the model in the
  layout mainline llama.cpp reads
- `mmproj-BF16.gguf`, the vision projector

Both were checked tensor by tensor against
[`thinkingmachines/Inkling-2-Mini`](https://huggingface.co/thinkingmachines/Inkling-2-Mini)
at `b85c3cfa`. Every tensor decodes bit-exactly to the original weights: the
NVFP4 experts keep their original 4-bit values and scales, and the MXFP8
experts and all other weights are lossless BF16. The smaller Unsloth quants,
and the `F16` projector, are lossy.

### Configuration

Runtime settings are in `compose.yaml`:

- `--split-mode layer --tensor-split 14,10`: layers are split across both
  GPUs, which also splits the KV cache. The last GPU also holds the output
  layer and the largest compute buffers, so it gets fewer layers. Row and tensor
  split are not supported for this architecture.
- `--ctx-size 1048576 --parallel 1`: the model's full context, in one slot.
  Prompt caching reuses earlier turns, so a follow-up to a 63K-token
  conversation processes only its new tokens.
- `--ubatch-size 1024 --batch-size 4096`: the fastest prefill that still fits
  1M tokens; `--ubatch-size 2048` runs out of memory at that context.
- `--flash-attn on`, F16 KV cache.
- Sampling `--temp 1.0 --top-p 1.0 --top-k 0 --min-p 0.0`, as Thinking
  Machines and Unsloth recommend.
- `HIP_VISIBLE_DEVICES=0,1`, which excludes the CPU's integrated GPU.

The DSpark speculative drafter that ships with the model
(`dspark/dspark-Inkling-2-Mini-BF16.gguf`, `--spec-type draft-dspark`) is not
enabled: it adds about 10% decode speed at short contexts and none at 64K, and
its draft KV cache does not fit alongside a 1M-token context.

### Performance

Measured 2026-11-23 on 2x R9700, single request, with the configuration above:

| Context | Prefill | Decode |
|---|---|---|
| Short (≤ 4K) | 1,640 tok/s | 39.5 tok/s |
| 64K | 1,585 tok/s | 34.5 tok/s |
| 128K | 1,295 tok/s | 30.5 tok/s |
| 256K | 959 tok/s | 23.8 tok/s |
| 512K | 621 tok/s | 17.3 tok/s |
| 1,026K | 365 tok/s | 11.4 tok/s |

Peak VRAM at a full 1M context is 32.7 and 33.0 GB of 34.2 GB.

The alternatives measured with the same model files (two GPUs, 64K prompt):

| Backend | Prefill | Decode |
|---|---|---|
| llama.cpp HIP + #406 (this branch) | 1,585 tok/s | 34.5 tok/s |
| Unsloth prebuilt `b12631-mix-acc0843`, Vulkan | 416 tok/s | 18.8 tok/s |
| Unsloth pin set without #406, HIP | 136 tok/s | 33.2 tok/s |

Mainline llama.cpp images (`server-rocm`, `server-vulkan` at `b12627`) are
slower still, and do not load the DSpark drafter.

### Why not vLLM

vLLM supports Inkling 2 Mini only on `main` (expected in v0.35.0), and only
on NVIDIA GPUs. On ROCm it refuses the checkpoint ("inkling2 quantization is
currently not supported in rocm"), and its kernels use NVIDIA-only PTX, Gluon,
FlashInfer and FP4 tensor-core instructions. An AMD port for Inkling 2 Small on
MI355X is open as [vllm-project/vllm#67685](https://github.com/vllm-project/vllm/pull/67685);
it covers neither the looped Mini nor RDNA4.

### Updating the llama.cpp pins

To take a newer Unsloth pin set or a newer #406:

1. Rebuild the pin list from the new `pr-set.json`, keeping the #385/#386
   to #406 swap if #406 is still unmerged, and pick an upstream `b####` base.
2. Merge it locally the same way the Dockerfile does, and set
   `LLAMA_CPP_BASE_COMMIT`, `LLAMA_CPP_TREE`, `LLAMA_CPP_VERSION`,
   `UNSLOTH_LLAMA_CPP_COMMIT` and `ADDITIVE_MERGE_SHA256` in `env/env.inkling`.
3. Rebuild and re-measure prefill at 64K and 128K, and the 1M-token fit.

## vLLM fullbuild (reference)

`Dockerfile.fullbuild` and `env/env.fullbuild` are kept from `main`, unused on
this branch, for the eventual move to vLLM. Their documentation follows.

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
| vLLM | Exact [`v0.34.0` source](https://github.com/vllm-project/vllm/commit/62d4bc3c7e33b1b6c906e233e6af2d3506c482ca), packaged as `0.34.0+rocm102.gfx1201` |
| Chat UI | Latest `ghcr.io/huggingface/chat-ui-db` image, pinned by digest `sha256:3cb93a2a3f53aacf0927f4bfd3114a2eccfefb8e417a6b042f755b42253d2c30` |

#### Updating the fullbuild pins

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
  with the same release. Chat UI is a separate service and can be updated
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

`VLLM_REF` selects the source; `VLLM_VERSION` sets the package version and local
image tag. Keep them aligned when upgrading releases. The historical
configurations under `archive/` are not updated.

On `main`, `compose.yaml` runs this image as the `vllm` service, serving
`Qwen/Qwen3.8-27B-FP8` with tensor parallelism set to two GPUs, FP8 KV cache,
AITER unified attention, and three-token MTP speculative decoding. On this
branch that service is replaced by `inkling`, and `just` uses `env/env.inkling`.

The runtime environment is split between:

- `env/2xr9700.vllm.common` for the two-GPU ROCm configuration
- `env/aiter-unified-attention.env` for AITER unified attention

Edit these files to match your hardware and model before building or starting
the vLLM service.

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