# R9700 vLLM ROCm + AITER container

This image starts from AMD's recent `rocm/vllm` `gfx120X-all` image, keeps the ROCm/PyTorch/Triton/Python userspace stack, removes AMD's pinned vLLM, then builds current upstream vLLM and AITER from source for `gfx1201`.

The Dockerfile intentionally pins inherited ROCm-sensitive packages as pip constraints. It also restores AMD's base Triton wheel after the vLLM/AITER source builds, because current upstream build dependencies may temporarily install PyPI Triton under the same package name. Final validation verifies that PyTorch, TorchVision, TorchAudio, and Triton still match the AMD base constraints.

## Build

```bash
./scripts/build.sh
```

Highest-probability first build:

```bash
IMAGE_NAME=vllm-r9700-aiter:rocm713-vllm-main \
VLLM_REF=main \
PREBUILD_AITER_KERNELS=0 \
./scripts/build.sh
```

Useful variants:

```bash
VLLM_REF=v0.20.2 ./scripts/build.sh
VLLM_REF=main ./scripts/build.sh
PREBUILD_AITER_KERNELS=1 IMAGE_NAME=vllm-r9700-aiter:rocm713-aiter-prebuilt ./scripts/build.sh
```

If Python 3.13 or PyTorch 2.10 compatibility blocks the build, try the ROCm 7.12 / Python 3.12 base:

```bash
BASE_IMAGE=rocm/vllm:rocm7.12.0_gfx120X-all_ubuntu24.04_py3.12_pytorch_2.9.1_vllm_0.16.0 \
VLLM_REF=v0.20.2 \
IMAGE_NAME=vllm-r9700-aiter:rocm712-vllm0202 \
./scripts/build.sh
```

## Smoke Test

```bash
./scripts/smoke-test.sh
```

The smoke test runs both checks expected from the image:

```bash
python3 - <<'PY'
import torch, vllm, aiter
print("torch:", torch.__version__)
print("hip:", torch.version.hip)
print("device:", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "NO GPU")
print("vllm:", vllm.__version__)
print("aiter: ok")
PY
```

and:

```bash
python3 -m vllm.entrypoints.openai.api_server --help
```

## First Runtime Test

Start with one GPU and a small model before trying tensor parallelism, FP8, the target model, or more AITER flags:

```bash
podman run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add keep-groups \
  --security-opt=label=disable \
  --ipc=host \
  --network=host \
  -v "${HOME}/.cache/huggingface:/root/.cache/huggingface:Z" \
  -v "${HOME}/.cache/vllm:/root/.cache/vllm:Z" \
  -v "${HOME}/.cache/triton:/root/.cache/triton:Z" \
  -e HIP_VISIBLE_DEVICES=0 \
  -e ROCR_VISIBLE_DEVICES=0 \
  -e CUDA_VISIBLE_DEVICES=0 \
  -e PYTORCH_ROCM_ARCH=gfx1201 \
  -e GPU_ARCHS=gfx1201 \
  -e VLLM_ROCM_USE_AITER=0 \
  vllm-r9700-aiter:rocm713-current \
    --model Qwen/Qwen2.5-0.5B-Instruct \
    --host 0.0.0.0 \
    --port 8000 \
    --tensor-parallel-size 1 \
    --gpu-memory-utilization 0.70 \
    --max-model-len 4096
```

Then test the server from another shell:

```bash
curl http://127.0.0.1:8000/v1/models
```

## Run Qwen 3.6 35B FP8

After the import check, API help, and single-GPU small-model test pass:

```bash
./scripts/run-qwen36-35b.sh
```

The Qwen script uses two visible GPUs, `NCCL_PROTO=Simple`, `NCCL_P2P_DISABLE=1`, shared memory enabled, and the local `chat-templates/qwen36.jinja` file.

## Debug Logs

```bash
podman logs vllm-rocm-wheel-nightly 2>&1 | grep -Ei 'aiter|attention backend|rocm|triton|flash|nccl|rccl'
```

If AITER attention fails, first keep AITER enabled but disable AITER attention:

```bash
VLLM_ROCM_USE_AITER=1
VLLM_ROCM_USE_AITER_MHA=0
VLLM_USE_AITER_UNIFIED_ATTENTION=0
VLLM_ROCM_USE_AITER_UNIFIED_ATTENTION=0
```

Then fall back fully only if needed:

```bash
VLLM_ROCM_USE_AITER=0
```

## Notes

* `PREBUILD_AITER_KERNELS=0` is the starting point. Test `PREBUILD_AITER_KERNELS=1` later as a separate image tag.
* `AITER_ROCM_ARCH`, `GPU_ARCHS`, `PYTORCH_ROCM_ARCH`, `HIP_ARCHITECTURES`, and `AMDGPU_TARGETS` are set to `gfx1201` for the build.
* `NCCL_PROTO=Simple` and `NCCL_P2P_DISABLE=1` are intentional for dual R9700 tensor parallelism.
* `NCCL_SHM_DISABLE=0` is intentionally kept enabled.
* Do not let pip replace AMD's ROCm PyTorch/Triton stack unless deliberately debugging compatibility.