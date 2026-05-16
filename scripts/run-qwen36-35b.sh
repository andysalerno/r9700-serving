#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-vllm-r9700-aiter:rocm713-current}"
MODEL="${MODEL:-Qwen/Qwen3.6-35B-A3B-FP8}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-qwen3.6-35b-a3b-fp8}"
PODMAN="${PODMAN:-podman}"

"${PODMAN}" run --rm -it \
  --name vllm-qwen36-r9700 \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add keep-groups \
  --security-opt=label=disable \
  --ipc=host \
  --network=host \
  -v "${HOME}/.cache/huggingface:/root/.cache/huggingface:Z" \
  -v "${HOME}/.cache/vllm:/root/.cache/vllm:Z" \
  -v "${HOME}/.cache/triton:/root/.cache/triton:Z" \
  -v "${HOME}/.cache/torch:/root/.cache/torch:Z" \
  -v "${PWD}/chat-templates:/app/chat-templates:Z" \
  -e HIP_VISIBLE_DEVICES=0,1 \
  -e ROCR_VISIBLE_DEVICES=0,1 \
  -e CUDA_VISIBLE_DEVICES=0,1 \
  -e NCCL_SOCKET_IFNAME=lo \
  -e NCCL_PROTO=Simple \
  -e NCCL_P2P_DISABLE=1 \
  -e NCCL_SHM_DISABLE=0 \
  -e PYTORCH_ROCM_ARCH=gfx1201 \
  -e GPU_ARCHS=gfx1201 \
  -e HIP_FORCE_DEV_KERNARG=1 \
  -e TORCH_BLAS_PREFER_HIPBLASLT=1 \
  -e ROCBLAS_USE_HIPBLASLT=1 \
  -e HSA_NO_SCRATCH_RECLAIM=1 \
  -e RAY_EXPERIMENTAL_NOSET_ROCR_VISIBLE_DEVICES=1 \
  -e VLLM_ROCM_USE_AITER=1 \
  -e VLLM_ROCM_USE_AITER_MHA=0 \
  -e VLLM_USE_AITER_UNIFIED_ATTENTION=1 \
  -e VLLM_ROCM_USE_AITER_UNIFIED_ATTENTION=1 \
  -e VLLM_V1_USE_PREFILL_DECODE_ATTENTION=0 \
  -e VLLM_LOGGING_LEVEL=DEBUG \
  -e TRITON_CACHE_DIR=/root/.cache/triton \
  -e TORCHINDUCTOR_CACHE_DIR=/root/.cache/torch/inductor \
  "${IMAGE_NAME}" \
    --model "${MODEL}" \
    --served-model-name "${SERVED_MODEL_NAME}" \
    --chat-template /app/chat-templates/qwen36.jinja \
    --host 0.0.0.0 \
    --port 8000 \
    --tensor-parallel-size 2 \
    --gpu-memory-utilization 0.80 \
    --max-model-len 16384