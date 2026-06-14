_default:
    @just --list

build-images-rocm713:
    podman compose --env-file .env/env.rocm713 --profile vllm-rocm-wheel-nightly build
    podman compose --env-file .env/env.rocm713 --profile vllm-rocm-wheel-gfx12x-patched build

build-images-rocm713-aiter-latest:
    podman compose --env-file .env/env.rocm713 --profile vllm-rocm-wheel-nightly build
    podman compose --env-file .env/env.rocm713 --env-file .env/aiter-latest.env --profile vllm-rocm-wheel-gfx12x-patched build

build-images-rocm714:
    podman compose --env-file .env/env.rocm714 --profile vllm-rocm-wheel-nightly build
    podman compose --env-file .env/env.rocm714 --profile vllm-rocm-wheel-gfx12x-patched build

build-images-rocm714-aiter-latest:
    podman compose --env-file .env/env.rocm714 --profile vllm-rocm-wheel-nightly build
    podman compose --env-file .env/env.rocm714 --env-file .env/aiter-latest.env --profile vllm-rocm-wheel-gfx12x-patched build

build-patched:
    podman compose --env-file .env/env.rocm714 --profile vllm-rocm-wheel-gfx12x-patched build

build-patched-aiter-latest:
    podman compose --env-file .env/env.rocm714 --env-file .env/aiter-latest.env --profile vllm-rocm-wheel-gfx12x-patched build

check-versions:
    podman run --rm --entrypoint python localhost/vllm-rocm-wheel-gfx12x-patched -c 'import importlib.metadata as md, os, torch; versions = {d.metadata["Name"].lower(): d.version for d in md.distributions()}; [print(f"{name}:", versions.get(name, "not installed")) for name in ("vllm", "amd-aiter", "flydsl", "torch", "triton", "flash-attn", "rocm-sdk-core", "rocm-sdk-devel", "rocm-sdk-libraries", "rocm-sdk-device-gfx1201")]; print("torch.version.hip:", torch.version.hip); [print(f"{key}:", os.environ.get(key)) for key in ("ROCM_PATH", "HIP_PATH", "HIPBLASLT_TENSILE_LIBPATH", "ROCBLAS_TENSILE_LIBPATH")]'

up:
    podman compose --env-file .env/env.rocm714 --profile vllm-rocm-wheel-gfx12x-patched up

up-aiter-latest:
    podman compose --env-file .env/env.rocm714 --env-file .env/aiter-latest.env --profile vllm-rocm-wheel-gfx12x-patched up --build

down:
    podman compose --env-file .env/env.rocm714 --profile vllm-rocm-wheel-gfx12x-patched down
