| model                |            test |              t/s |     peak t/s |        ttfr (ms) |     est_ppt (ms) |    e2e_ttft (ms) |
|:---------------------|----------------:|-----------------:|-------------:|-----------------:|-----------------:|-----------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 | 2587.54 ± 233.51 |              |   800.54 ± 75.02 |   798.38 ± 75.02 |   800.54 ± 75.02 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |     53.56 ± 5.35 | 55.31 ± 5.52 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 |  2947.97 ± 27.05 |              |   1044.55 ± 9.71 |   1042.39 ± 9.71 |   1045.54 ± 9.52 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |     49.35 ± 4.48 | 50.96 ± 4.63 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 |  2935.76 ± 10.37 |              |   1397.62 ± 5.08 |   1395.46 ± 5.08 |   1397.62 ± 5.08 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |     51.01 ± 2.76 | 52.67 ± 2.86 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 |   2961.17 ± 3.65 |              |   2077.58 ± 2.62 |   2075.42 ± 2.62 |   2077.58 ± 2.62 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |     47.40 ± 2.70 | 48.95 ± 2.79 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 |  2849.15 ± 19.89 |              |  3596.75 ± 25.22 |  3594.58 ± 25.22 |  3596.75 ± 25.22 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |     40.05 ± 4.09 | 41.35 ± 4.23 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |   2636.26 ± 1.31 |              |   6994.27 ± 3.46 |   6992.11 ± 3.46 |   6994.27 ± 3.46 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |     33.06 ± 1.81 | 33.97 ± 2.10 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |   2285.87 ± 0.81 |              |  14897.72 ± 5.19 |  14895.56 ± 5.19 |  14897.72 ± 5.19 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |     23.26 ± 2.36 | 25.33 ± 0.94 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |   1798.61 ± 3.23 |              | 36724.50 ± 66.02 | 36722.33 ± 66.02 | 36724.50 ± 66.02 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |     13.93 ± 1.53 | 17.00 ± 0.00 |                  |                  |                  |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-05-24 13:46:35 | latency mode: api
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
      # - GPU_MAX_HW_QUEUES=1
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