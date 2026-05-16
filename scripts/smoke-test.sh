#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-vllm-r9700-aiter:rocm713-current}"
PODMAN="${PODMAN:-podman}"
HIP_VISIBLE_DEVICES="${HIP_VISIBLE_DEVICES:-0}"

COMMON_ARGS=(
  --rm
  --device=/dev/kfd
  --device=/dev/dri
  --group-add keep-groups
  --security-opt=label=disable
  --ipc=host
  --network=host
  -e "HIP_VISIBLE_DEVICES=${HIP_VISIBLE_DEVICES}"
  -e PYTORCH_ROCM_ARCH=gfx1201
  -e GPU_ARCHS=gfx1201
)

"${PODMAN}" run "${COMMON_ARGS[@]}" \
  --entrypoint /bin/bash \
  "${IMAGE_NAME}" \
  -lc 'python3 - <<'"'"'PY'"'"'
import torch, vllm, aiter
print("torch:", torch.__version__)
print("hip:", torch.version.hip)
print("available:", torch.cuda.is_available())
print("device:", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "NO GPU")
print("vllm:", vllm.__version__)
print("aiter: ok")
PY'

"${PODMAN}" run "${COMMON_ARGS[@]}" \
  "${IMAGE_NAME}" \
  --help