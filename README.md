# vLLM on Radeon AI PRO R9700

Build and run vLLM from source for AMD Radeon AI PRO R9700 GPUs. The default
configuration targets two R9700s (`gfx1201`) and serves a model through vLLM's
OpenAI-compatible API, with Hugging Face Chat UI as a frontend.

## Requirements

- Podman with `podman compose` (`docker compose` may work, but is untested)
- [`just`](https://just.systems/)
- One or more R9700 GPUs; the included configuration assumes two

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
