set positional-arguments

# Container runtime: "podman" (default) or "docker". Override with
# `just --set runtime docker <recipe>` or `RUNTIME=docker just <recipe>`.
runtime := env_var_or_default('RUNTIME', 'podman')

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

build:
    {{runtime}} compose --env-file env/env.fullbuild build


up:
    {{runtime}} compose up -d

logs:
    {{runtime}} compose logs -f

down:
    {{runtime}} compose down
