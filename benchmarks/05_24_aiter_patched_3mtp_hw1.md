| model                |            test |              t/s |     peak t/s |         ttfr (ms) |      est_ppt (ms) |     e2e_ttft (ms) |
|:---------------------|----------------:|-----------------:|-------------:|------------------:|------------------:|------------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 | 2127.41 ± 743.50 |              |  1151.53 ± 531.42 |  1149.04 ± 531.42 |  1151.53 ± 531.42 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |     60.29 ± 0.96 | 62.25 ± 1.00 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 |  2970.36 ± 14.11 |              |    1036.96 ± 5.06 |    1034.46 ± 5.06 |    1037.27 ± 5.31 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |     62.78 ± 3.37 | 64.83 ± 3.48 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 |  2976.45 ± 10.09 |              |    1378.87 ± 4.81 |    1376.38 ± 4.81 |    1378.87 ± 4.81 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |     57.58 ± 3.34 | 59.46 ± 3.45 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 |  2989.14 ± 14.15 |              |    2058.09 ± 9.88 |    2055.60 ± 9.88 |    2058.09 ± 9.88 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |     54.75 ± 2.72 | 56.54 ± 2.81 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 |  2874.83 ± 19.24 |              |   3564.72 ± 23.86 |   3562.23 ± 23.86 |   3564.72 ± 23.86 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |     40.45 ± 2.01 | 41.77 ± 2.07 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |   2663.92 ± 1.31 |              |    6921.87 ± 3.54 |    6919.38 ± 3.54 |    6921.87 ± 3.54 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |     37.69 ± 0.04 | 38.91 ± 0.04 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |   2310.98 ± 4.64 |              |  14736.14 ± 29.51 |  14733.65 ± 29.51 |  14736.14 ± 29.51 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |     25.59 ± 1.43 | 26.33 ± 0.94 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |   1815.35 ± 5.49 |              | 36386.18 ± 110.10 | 36383.69 ± 110.10 | 36386.18 ± 110.10 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |     15.54 ± 1.60 | 18.00 ± 0.00 |                   |                   |                   |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-05-24 14:13:48 | latency mode: api

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
    depends_on:
      - aspire-dashboard
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

      --otlp-traces-endpoint http://aspire-dashboard:18890/v1/traces
      --collect-detailed-traces=all

      --dtype auto
      --max-num-seqs 4
      --kv-cache-dtype fp8
      -tp 2
      --speculative-config '{"method": "mtp", "num_speculative_tokens": 3}'
      --attention-backend ROCM_AITER_UNIFIED_ATTN