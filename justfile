_default:
    @just --list

build-images-rocm713:
    podman compose --env-file env.rocm713 --profile vllm-rocm-wheel-nightly build
    podman compose --env-file env.rocm713 --profile vllm-rocm-wheel-gfx12x-patched build

build-images-rocm713-aiter-latest:
    podman compose --env-file env.rocm713 --profile vllm-rocm-wheel-nightly build
    podman compose --env-file env.rocm713 --env-file .env/aiter-latest.env --profile vllm-rocm-wheel-gfx12x-patched build

build-images-rocm714:
    podman compose --env-file env.rocm714 --profile vllm-rocm-wheel-nightly build
    podman compose --env-file env.rocm714 --profile vllm-rocm-wheel-gfx12x-patched build

build-images-rocm714-aiter-latest:
    podman compose --env-file env.rocm714 --profile vllm-rocm-wheel-nightly build
    podman compose --env-file env.rocm714 --env-file .env/aiter-latest.env --profile vllm-rocm-wheel-gfx12x-patched build

build-patched:
    podman compose --profile vllm-rocm-wheel-gfx12x-patched build

build-patched-aiter-latest:
    podman compose --env-file .env/aiter-latest.env --profile vllm-rocm-wheel-gfx12x-patched build

up:
    podman compose --profile vllm-rocm-wheel-gfx12x-patched up

up-aiter-latest:
    podman compose --env-file .env/aiter-latest.env --profile vllm-rocm-wheel-gfx12x-patched up --build

down:
    podman compose --profile vllm-rocm-wheel-gfx12x-patched down
