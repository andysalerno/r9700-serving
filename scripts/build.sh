#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-vllm-r9700-aiter:rocm713-current}"
BASE_IMAGE="${BASE_IMAGE:-rocm/vllm:rocm7.13.0_gfx120X-all_ubuntu24.04_py3.13_pytorch_2.10.0_vllm_0.19.1}"
VLLM_REF="${VLLM_REF:-main}"
AITER_REF="${AITER_REF:-main}"
GFX_ARCH="${GFX_ARCH:-gfx1201}"
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"
PREBUILD_AITER_KERNELS="${PREBUILD_AITER_KERNELS:-0}"
PODMAN="${PODMAN:-podman}"

"${PODMAN}" build \
  -f Dockerfile.r9700-vllm-aiter \
  -t "${IMAGE_NAME}" \
  --build-arg BASE_IMAGE="${BASE_IMAGE}" \
  --build-arg VLLM_REF="${VLLM_REF}" \
  --build-arg AITER_REF="${AITER_REF}" \
  --build-arg GFX_ARCH="${GFX_ARCH}" \
  --build-arg BUILD_JOBS="${BUILD_JOBS}" \
  --build-arg PREBUILD_AITER_KERNELS="${PREBUILD_AITER_KERNELS}" \
  .