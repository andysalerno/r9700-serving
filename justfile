_default:
    @just --list

build-images-rocm713:
    podman compose --env-file env.rocm713 --profile vllm-rocm-wheel-nightly build
    podman compose --env-file env.rocm713 --profile vllm-rocm-wheel-gfx12x-patched build

build-images-rocm714:
    podman compose --env-file env.rocm714 --profile vllm-rocm-wheel-nightly build
    podman compose --env-file env.rocm714 --profile vllm-rocm-wheel-gfx12x-patched build

up:
    podman compose --profile vllm-rocm-wheel-gfx12x-patched up

down:
    podman compose --profile vllm-rocm-wheel-gfx12x-patched down
