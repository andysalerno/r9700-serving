Dockerfiles, compose files, and vLLM patches for running local LLM backends on 2x Radeon AI PRO R9700 GPUs.

The selected vllm profile serves on port `8000`. `chatui` is exposed on port `8001`, and the Aspire dashboard is exposed on port `8002` for traced vLLM profiles.

## Requirements

- Podman with `podman compose` (`docker` should work, but is untested)
- 1 or more R9700 (default compose files assume 2 with `-tp 2`, cause that's what I have)

## Compose profiles

Main profiles in `compose.yaml`:

| Profile | What it runs |
| --- | --- |
| `vllm-rocm-wheel-nightly` | Nightly vllm in a container with latest ROCm (currently 7.13). Uses Triton, update `--attention-backend` to try ROCM_ATTN. |
| `vllm-rocm-wheel-gfx12x-patched` | Builds from the nightly image, applies the custom gfx12x/R9700 patch, and runs AITER unified attention. |
| `vllm-rocm-wheel` | Builds a pinned non-nightly vLLM ROCm wheel image. |
| `vllm-aml` | Runs the external `aml731/vllm-aiter` image. Note: I can't vet the contents of this container, as it's not mine, but it indeed is very fast and also enables unified attention |
| `llamacpp-rocm` | Runs llama.cpp's ROCm server image. |
| `llamacpp-vulkan` | Runs llama.cpp's Vulkan server image. |
| `atom` | Runs the ROCm Atom dev image. (doesn't work but keeping as a reference) |

## How to run

Replace `PROFILE` with one of the profile names above.

```sh
podman compose --profile PROFILE build
podman compose --profile PROFILE up
podman compose --profile PROFILE up --build
podman compose --profile PROFILE up -d
podman compose --profile PROFILE down
```

Example:

```sh
podman compose --profile vllm-rocm-wheel-nightly up --build
```

The patched profile uses `localhost/vllm-rocm-wheel-nightly` as its base image, so build the nightly profile first:

```sh
podman compose --profile vllm-rocm-wheel-nightly build
podman compose --profile vllm-rocm-wheel-gfx12x-patched build
podman compose --profile vllm-rocm-wheel-gfx12x-patched up
```

To stop the stack:

```sh
podman compose --profile vllm-rocm-wheel-gfx12x-patched down
```

## Updating nightly vLLM wheels

Nightly wheels rotate frequently. If the nightly build fails because the pinned wheel no longer exists, update `compose.yaml`.

For the nightly service, visit the vLLM wheel directory, for example:

```text
https://wheels.vllm.ai/rocm/nightly/rocm722/vllm
```

Copy the current vLLM version from that directory and paste it into the `VLLM_VERSION` build arg for `vllm-rocm-wheel-nightly` in `compose.yaml`.

## Custom gfx12x/R9700 patch

Patch file:

```text
docker/patches/GFX12x_R9700_RUNTIME.patch
```

Patch image:

```text
docker/Dockerfile.wheel-gfx12x-patched
```

The patched Dockerfile starts from `localhost/vllm-rocm-wheel-nightly`, installs the ROCm SDK development files needed at runtime, copies the patch into the image, applies it inside Python `site-packages` with `git apply`, and then `py_compile`s the touched vLLM files. The apply step is idempotent: it applies the patch when possible and reports when the patch is already present.

Use it with the `vllm-rocm-wheel-gfx12x-patched` profile:

```sh
podman compose --profile vllm-rocm-wheel-nightly build
podman compose --profile vllm-rocm-wheel-gfx12x-patched up --build
```

What it does, briefly:

- Treats gfx12x/R9700 as an AITER-supported ROCm architecture in vLLM runtime checks.
- Allows gfx12x through FP8 fused MoE support checks.
- Allows the ROCm AITER attention backend on gfx12x.
- Forces the AITER flash-attention path to use unified attention on gfx12x.

The patch is a local runtime patch against the installed vLLM wheel. When the nightly wheel changes, the patch will need to be refreshed if upstream files move or change.