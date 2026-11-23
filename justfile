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

# Download the pinned Inkling 2 Mini GGUFs and verify their SHA-256 checksums.
download:
    #!/usr/bin/env bash
    set -euo pipefail
    set -a; source env/env.inkling; set +a
    dir="$HOME/.cache/llama.cpp/inkling-2-mini/${INKLING_GGUF_REVISION}"
    hf download "$INKLING_GGUF_REPO" --revision "$INKLING_GGUF_REVISION" --local-dir "$dir" \
        "$INKLING_MODEL_FILE" "$INKLING_MMPROJ_FILE"
    (
        cd "$dir"
        printf '%s  %s\n' \
            "$INKLING_MODEL_SHA256" "$INKLING_MODEL_FILE" \
            "$INKLING_MMPROJ_SHA256" "$INKLING_MMPROJ_FILE" \
            | sha256sum -c -
    )

build:
    podman compose --env-file env/env.inkling build


up: download
    podman compose --env-file env/env.inkling up --build -d --wait --wait-timeout 1800

logs:
    podman compose --env-file env/env.inkling logs -f

down:
    podman compose --env-file env/env.inkling down