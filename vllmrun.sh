podman run --rm -it \
  --name vllm-qwen36-r9700 \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add keep-groups \
  --security-opt=label=disable \
  --ipc=host \
  --network=host \
  -v ~/.cache/huggingface:/root/.cache/huggingface:Z \
  -v ~/.cache/vllm:/root/.cache/vllm:Z \
  -v ~/.cache/triton:/root/.cache/triton:Z \
  -v ~/.cache/torch:/root/.cache/torch:Z \
  -e HIP_VISIBLE_DEVICES=0,1 \
  -e ROCR_VISIBLE_DEVICES=0,1 \
  -e CUDA_VISIBLE_DEVICES=0,1 \
  -e NCCL_SOCKET_IFNAME=lo \
  -e NCCL_PROTO=Simple \
  -e NCCL_P2P_DISABLE=1 \
  -e NCCL_SHM_DISABLE=0 \
  -e TRITON_CACHE_DIR=/root/.cache/triton \
  -e TORCHINDUCTOR_CACHE_DIR=/root/.cache/torch/inductor \
  docker.io/vllm/vllm-openai-rocm:v0.20.2 \
  Qwen/Qwen3.6-35B-A3B-FP8 \
  --served-model-name qwen3.6-35b-a3b-fp8 \
  --tensor-parallel-size 2 \
  --distributed-executor-backend mp \
  --gpu-memory-utilization 0.93 \
  --max-model-len 128000 \
  --host 0.0.0.0 \
  --port 8000
