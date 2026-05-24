| model                |            test |              t/s |     peak t/s |       ttfr (ms) |    est_ppt (ms) |   e2e_ttft (ms) |
|:---------------------|----------------:|-----------------:|-------------:|----------------:|----------------:|----------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 | 2680.65 ± 166.09 |              |  769.96 ± 48.84 |  767.14 ± 48.84 |  769.96 ± 48.84 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |     69.02 ± 0.04 | 71.27 ± 0.04 |                 |                 |                 |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 |  3016.59 ± 27.46 |              |  1021.71 ± 9.26 |  1018.89 ± 9.26 |  1022.69 ± 9.50 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |     77.95 ± 0.05 | 80.50 ± 0.05 |                 |                 |                 |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 |   3062.04 ± 6.56 |              |  1340.82 ± 2.87 |  1338.00 ± 2.87 |  1340.82 ± 2.87 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |     72.45 ± 7.45 | 74.82 ± 7.70 |                 |                 |                 |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 |   3144.06 ± 3.89 |              |  1956.98 ± 2.42 |  1954.16 ± 2.42 |  1956.98 ± 2.42 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |     72.19 ± 4.49 | 74.55 ± 4.64 |                 |                 |                 |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 |   3066.71 ± 2.21 |              |  3342.23 ± 2.41 |  3339.41 ± 2.41 |  3342.23 ± 2.41 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |     72.57 ± 7.02 | 74.95 ± 7.25 |                 |                 |                 |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |   2969.93 ± 1.24 |              |  6209.37 ± 2.58 |  6206.55 ± 2.58 |  6209.37 ± 2.58 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |     69.21 ± 6.53 | 71.47 ± 6.74 |                 |                 |                 |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |   2742.06 ± 1.84 |              | 12420.13 ± 8.33 | 12417.31 ± 8.33 | 12420.13 ± 8.33 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |     71.57 ± 4.25 | 73.90 ± 4.39 |                 |                 |                 |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |   2362.50 ± 0.23 |              | 27960.10 ± 2.75 | 27957.28 ± 2.75 | 27960.10 ± 2.75 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |     68.64 ± 6.69 | 70.88 ± 6.91 |                 |                 |                 |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-05-24 14:41:38 | latency mode: api


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
      --speculative-config '{"method": "mtp", "num_speculative_tokens": 3, "attention_backend": "ROCM_AITER_UNIFIED_ATTN"}'
      --attention-backend ROCM_AITER_UNIFIED_ATTN