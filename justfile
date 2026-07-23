set positional-arguments

_default:
    @just --list

# Remove host cache directories mounted into vLLM containers.
clear-vllm-caches:
    #!/usr/bin/env bash
    set -euo pipefail

    cache_dirs=(
        # "$HOME/.cache/huggingface"
        "$HOME/.cache/vllm"
        "$HOME/.cache/triton"
        "$HOME/.cache/torchinductor"
        "$HOME/.cache/aiter"
        "$HOME/.cache/comgr"
        "$HOME/.cache/tvm-ffi"
    )

    printf 'Removing vLLM host cache directories:\n'
    for dir in "${cache_dirs[@]}"; do
        printf '  %s\n' "$dir"
        rm -rf -- "$dir"
    done

fullbuild:
    #!/usr/bin/env bash
    set -euo pipefail

    set -a
    source .env/env.fullbuild
    set +a

    podman build \
        --build-arg ROCM_IMAGE \
        --build-arg GPU_ARCH \
        --build-arg MAX_JOBS \
        --build-arg TORCH_VERSION \
        --build-arg TORCHVISION_VERSION \
        --build-arg TORCHAUDIO_VERSION \
        --build-arg VLLM_REF \
        --build-arg VLLM_VERSION \
        --build-arg AITER_REF \
        --build-arg FLASH_ATTN_REF \
        --target runtime \
        --tag localhost/vllm-fullbuild:review \
        --file docker/Dockerfile.fullbuild .