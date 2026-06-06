| model                |            test |             t/s |      peak t/s |        ttfr (ms) |     est_ppt (ms) |    e2e_ttft (ms) |
|:---------------------|----------------:|----------------:|--------------:|-----------------:|-----------------:|-----------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 | 2724.83 ± 15.01 |               |    759.06 ± 3.85 |    751.99 ± 3.85 |    759.06 ± 3.85 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |    74.63 ± 3.80 |  77.06 ± 3.93 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 | 3036.70 ± 15.05 |               |   1019.15 ± 4.95 |   1012.09 ± 4.95 |   1023.37 ± 5.98 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |    70.84 ± 6.53 |  73.14 ± 6.74 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 | 3023.46 ± 84.59 |               |  1363.00 ± 38.69 |  1355.93 ± 38.69 |  1363.00 ± 38.69 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |   75.18 ± 15.73 | 77.64 ± 16.25 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 | 3038.79 ± 47.76 |               |  2029.75 ± 31.44 |  2022.68 ± 31.44 |  2029.75 ± 31.44 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |   87.75 ± 12.54 | 90.62 ± 12.96 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 | 3056.19 ± 10.13 |               |  3358.00 ± 11.09 |  3350.94 ± 11.09 |  3358.00 ± 11.09 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |    76.03 ± 9.39 |  78.51 ± 9.70 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |  2963.40 ± 1.35 |               |   6227.28 ± 2.84 |   6220.22 ± 2.84 |   6227.28 ± 2.84 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |    79.51 ± 0.74 |  82.10 ± 0.76 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |  2729.11 ± 7.02 |               | 12483.64 ± 32.08 | 12476.58 ± 32.08 | 12483.64 ± 32.08 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |    84.65 ± 6.56 |  87.42 ± 6.78 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |  2358.86 ± 0.66 |               |  28007.58 ± 7.68 |  28000.51 ± 7.68 |  28007.58 ± 7.68 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |   77.07 ± 10.53 | 79.59 ± 10.88 |                  |                  |                  |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-06-06 12:02:52 | latency mode: api

  vllm-rocm-wheel-gfx12x-patched:
    profiles: ["vllm-rocm-wheel-gfx12x-patched"]
    image: localhost/vllm-rocm-wheel-gfx12x-patched
    build:
      context: .
      dockerfile: docker/Dockerfile.wheel-gfx12x-patched
      args:
        BASE_IMAGE: localhost/vllm-rocm-wheel-nightly
    container_name: vllm-rocm-wheel-gfx12x-patched
    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
    group_add:
      - "video"
    cap_add:
      - SYS_PTRACE
    security_opt:
      - label=disable
    ipc: host
    ports:
      - "8000:8000"
    # depends_on:
    #   - aspire-dashboard
    networks:
      default:
        aliases:
          - llm-backend
    volumes:
      - ${HOME}/.cache/huggingface:/root/.cache/huggingface:Z
      - ./chat-templates/:/app/chat-templates:Z
      - ${HOME}/.cache/vllm:/root/.cache/vllm:Z

    env_file:
      - .env/2xr9700.vllm.common
      - .env/otel.common
    environment:
      - VLLM_ROCM_USE_AITER=1
      - VLLM_ROCM_USE_AITER_MHA=0
      - VLLM_ROCM_USE_AITER_MLA=0
      - VLLM_ROCM_USE_AITER_MOE=0
      - VLLM_ROCM_USE_AITER_LINEAR=0
      - VLLM_ROCM_USE_AITER_FP8BMM=0
      - VLLM_ROCM_USE_AITER_FP4BMM=0
      - VLLM_ROCM_USE_AITER_TRITON_GEMM=0
      - VLLM_ROCM_USE_AITER_RMSNORM=0
      - VLLM_ROCM_USE_AITER_UNIFIED_ATTENTION=1
      - VLLM_ROCM_SHUFFLE_KV_CACHE_LAYOUT=0
      - ROCM_PATH=/opt/vllm/lib/python3.12/site-packages/_rocm_sdk_devel
      - ROCM_HOME=/opt/vllm/lib/python3.12/site-packages/_rocm_sdk_devel
      - HIP_PATH=/opt/vllm/lib/python3.12/site-packages/_rocm_sdk_devel
      - HIP_HOME=/opt/vllm/lib/python3.12/site-packages/_rocm_sdk_devel
      - HIP_DEVICE_LIB_PATH=/opt/vllm/lib/python3.12/site-packages/_rocm_sdk_devel/lib/llvm/amdgcn/bitcode
      - DEVICE_LIB_PATH=/opt/vllm/lib/python3.12/site-packages/_rocm_sdk_devel/lib/llvm/amdgcn/bitcode
      - CPATH=/opt/vllm/lib/python3.12/site-packages/_rocm_sdk_devel/include
      - LIBRARY_PATH=/opt/vllm/lib/python3.12/site-packages/_rocm_sdk_devel/lib
      - GPU_MAX_HW_QUEUES=1
      # - VLLM_LOGGING_LEVEL=DEBUG
      # - VLLM_USE_NCCL_SYMM_MEM=1
      # - VLLM_DISABLE_PYNCCL=1
    command: >
      Qwen/Qwen3.6-27B-FP8
      --tokenizer Qwen/Qwen3.6-27B
      --served-model-name qwen3.6-27b
      --chat-template /app/chat-templates/qwen36.jinja
      --limit-mm-per-prompt '{"image": 99, "audio": 0, "video": 0}'
      --enable-auto-tool-choice --tool-call-parser qwen3_coder --reasoning-parser qwen3
      --max-model-len 128000
      --enable-prefix-caching
      --override-generation-config '{"temperature": 1.0, "top_p": 0.95, "top_k": 20, "min_p": 0.0, "presence_penalty": 0.0, "repetition_penalty": 1.0}'
      --gpu-memory-utilization 0.93
      --host 0.0.0.0
      --port 8000


      --dtype auto
      --max-num-seqs 4
      --kv-cache-dtype fp8
      -tp 2
      --speculative-config '{"method": "mtp", "num_speculative_tokens": 3, "attention_backend": "ROCM_AITER_UNIFIED_ATTN"}'
      --attention-backend ROCM_AITER_UNIFIED_ATTN
    # --otlp-traces-endpoint http://aspire-dashboard:18890/v1/traces
    # --collect-detailed-traces=all