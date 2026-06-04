| model                |            test |              t/s |      peak t/s |        ttfr (ms) |     est_ppt (ms) |    e2e_ttft (ms) |
|:---------------------|----------------:|-----------------:|--------------:|-----------------:|-----------------:|-----------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 | 2236.77 ± 633.52 |               | 1020.94 ± 353.45 | 1015.82 ± 353.45 | 1020.94 ± 353.45 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |    89.29 ± 14.19 | 92.22 ± 14.67 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 | 2871.61 ± 114.44 |               |  1076.91 ± 41.64 |  1071.79 ± 41.64 |  1078.09 ± 39.98 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |    88.52 ± 17.58 | 91.42 ± 18.16 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 |  2960.28 ± 86.89 |               |  1390.29 ± 40.16 |  1385.17 ± 40.16 |  1390.29 ± 40.16 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |    93.47 ± 10.56 | 96.54 ± 10.91 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 |  3042.95 ± 22.62 |               |  2024.43 ± 15.06 |  2019.31 ± 15.06 |  2024.43 ± 15.06 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |     84.36 ± 7.21 |  87.12 ± 7.46 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 |  2997.78 ± 26.94 |               |  3421.48 ± 30.87 |  3416.36 ± 30.87 |  3421.48 ± 30.87 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |    96.40 ± 13.08 | 99.57 ± 13.52 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |   2951.56 ± 8.29 |               |  6250.34 ± 17.56 |  6245.22 ± 17.56 |  6250.34 ± 17.56 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |     83.43 ± 6.34 |  86.15 ± 6.55 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |   2737.89 ± 6.78 |               | 12441.15 ± 30.94 | 12436.03 ± 30.94 | 12441.15 ± 30.94 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |     78.90 ± 9.98 | 81.48 ± 10.31 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |   2356.32 ± 6.99 |               | 28035.86 ± 83.61 | 28030.74 ± 83.61 | 28035.86 ± 83.61 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |     85.41 ± 6.20 |  88.20 ± 6.40 |                  |                  |                  |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-06-03 19:31:27 | latency mode: api

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