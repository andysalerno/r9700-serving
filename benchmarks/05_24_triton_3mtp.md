| model                |            test |             t/s |     peak t/s |          ttfr (ms) |       est_ppt (ms) |      e2e_ttft (ms) |
|:---------------------|----------------:|----------------:|-------------:|-------------------:|-------------------:|-------------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 |  2225.01 ± 8.98 |              |      924.14 ± 3.72 |      920.91 ± 3.72 |      924.14 ± 3.72 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |    40.60 ± 0.13 | 41.92 ± 0.13 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 | 2108.46 ± 10.06 |              |     1460.88 ± 7.18 |     1457.65 ± 7.18 |     1461.55 ± 7.56 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |    39.21 ± 2.12 | 40.48 ± 2.19 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 | 1886.69 ± 17.21 |              |    2174.94 ± 20.04 |    2171.71 ± 20.04 |    2174.94 ± 20.04 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |    36.53 ± 0.01 | 37.71 ± 0.01 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 | 1582.78 ± 17.28 |              |    3886.11 ± 42.66 |    3882.88 ± 42.66 |    3886.11 ± 42.66 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |    29.32 ± 1.60 | 30.00 ± 1.41 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 |  1197.28 ± 7.42 |              |    8557.37 ± 52.95 |    8554.15 ± 52.95 |    8557.37 ± 52.95 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |    21.94 ± 1.19 | 24.00 ± 0.00 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |   801.81 ± 2.17 |              |   22992.13 ± 62.70 |   22988.91 ± 62.70 |   22992.13 ± 62.70 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |    15.19 ± 0.02 | 16.00 ± 0.00 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |   493.52 ± 1.13 |              |  68993.74 ± 159.18 |  68990.52 ± 159.18 |  68993.74 ± 159.18 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |     8.63 ± 0.87 | 10.00 ± 0.00 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |   275.05 ± 0.44 |              | 240140.20 ± 382.95 | 240136.98 ± 382.95 | 240140.20 ± 382.95 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |     4.96 ± 0.27 |  6.00 ± 0.00 |                    |                    |                    |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-05-24 11:44:58 | latency mode: api

  vllm-rocm-wheel-nightly:
    profiles: ["vllm-rocm-wheel-nightly"]
    image: localhost/vllm-rocm-wheel-nightly
    # image: docker.io/vllm/vllm-openai-rocm:nightly
    build:
      context: .
      dockerfile: docker/Dockerfile.wheel
      args:
        GFX_TARGET: gfx120X-all
        GFX_ARCH: gfx1201
        PYTHON: python3.12
        VLLM_WHEEL_URL: https://wheels.vllm.ai/rocm/nightly/rocm722
        VLLM_VERSION: 0.21.1rc1.dev267+gd56285c74.rocm722
        ROCM_SDK_CORE_VERSION: 7.13.0
        ROCM_SDK_LIBRARIES_VERSION: 7.13.0
        FLASH_ATTN_VERSION: 2.8.3
    container_name: vllm-rocm-wheel-nightly
    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
    group_add:
      - "video"
      # - "render"
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
      - FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
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
      --attention-backend TRITON_ATTN