| model                |            test |              t/s |     peak t/s |          ttfr (ms) |       est_ppt (ms) |      e2e_ttft (ms) |
|:---------------------|----------------:|-----------------:|-------------:|-------------------:|-------------------:|-------------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 | 2429.06 ± 166.67 |              |     860.75 ± 61.13 |     847.73 ± 61.13 |     860.75 ± 61.13 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |     38.97 ± 6.81 | 40.24 ± 7.03 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 |  2631.62 ± 19.89 |              |     1180.68 ± 8.68 |     1167.66 ± 8.68 |     1183.61 ± 6.98 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |     36.98 ± 2.44 | 38.18 ± 2.52 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 | 2316.16 ± 210.89 |              |   1797.45 ± 172.47 |   1784.43 ± 172.47 |   1797.45 ± 172.47 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |     36.59 ± 1.14 | 37.78 ± 1.18 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 | 2087.18 ± 176.95 |              |   2979.61 ± 266.51 |   2966.59 ± 266.51 |   2979.61 ± 266.51 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |     33.07 ± 3.03 | 34.28 ± 2.97 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 |  1853.30 ± 16.29 |              |    5539.28 ± 48.86 |    5526.26 ± 48.86 |    5539.28 ± 48.86 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |     21.40 ± 2.92 | 23.67 ± 1.70 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |   1404.53 ± 4.22 |              |   13137.12 ± 39.31 |   13124.10 ± 39.31 |   13137.12 ± 39.31 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |     14.31 ± 0.60 | 16.33 ± 0.47 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |   884.30 ± 57.62 |              | 38685.52 ± 2594.34 | 38672.50 ± 2594.34 | 38685.52 ± 2594.34 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |      7.87 ± 0.46 | 10.33 ± 0.47 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |    555.47 ± 2.87 |              | 118923.88 ± 613.71 | 118910.86 ± 613.71 | 118923.88 ± 613.71 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |      4.65 ± 0.55 |  7.67 ± 1.25 |                    |                    |                    |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-05-22 18:44:42 | latency mode: api

  vllm-rocm-wheel-nightly:
    profiles: ["vllm-rocm-wheel-nightly"]
    # image: docker.io/vllm/vllm-openai-rocm:nightly
    image: localhost/vllm-rocm-wheel-nightly
    build:
      context: .
      dockerfile: docker/Dockerfile.wheel
      args:
        GFX_TARGET: gfx120X-all
        GFX_ARCH: gfx1201
        PYTHON: python3.12
        VLLM_WHEEL_URL: https://wheels.vllm.ai/rocm/nightly/rocm722
        VLLM_VERSION: 0.21.1rc1.dev236+g552bbe6f4.rocm722
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

    environment:
      # https://rocm.docs.amd.com/en/latest/how-to/rocm-for-ai/inference-optimization/vllm-optimization.html
      HIP_VISIBLE_DEVICES: "0,1"
      ROCR_VISIBLE_DEVICES: "0,1"
      CUDA_VISIBLE_DEVICES: "0,1"
      HIP_PLATFORM: "amd"
      VLLM_TARGET_DEVICE: "rocm"
      VLLM_ROCM_GCN_ARCH: "gfx1201"
      PYTORCH_ROCM_ARCH: "gfx1201"
      HIP_ARCHITECTURES: "gfx1201"
      AMDGPU_TARGETS: "gfx1201"
      GPU_ARCHS: "gfx1201"
      # NCCL_SOCKET_IFNAME: "lo"
      # NCCL_PROTO: "Simple"
      # NCCL_P2P_DISABLE: "1"
      # NCCL_SHM_DISABLE: "0"
      # VLLM_ROCM_USE_AITER: "1"
      # VLLM_ROCM_SHUFFLE_KV_CACHE_LAYOUT: "0"
      # VLLM_ROCM_ALLOW_RDNA4_AITER_ATTENTION: "1"
      # VLLM_ROCM_USE_AITER_UNIFIED_ATTENTION: "1"
      # FLASH_ATTENTION_TRITON_AMD_ENABLE: "TRUE"
      # FLASH_ATTENTION_TRITON_AMD_AUTOTUNE: "TRUE"
      # VLLM_LOGGING_LEVEL: DEBUG
      OTEL_SERVICE_NAME: "vllm-rocm-wheel"
      OTEL_EXPORTER_OTLP_TRACES_PROTOCOL: "http/protobuf"
      OTEL_EXPORTER_OTLP_TRACES_INSECURE: "true"
      OTEL_RESOURCE_ATTRIBUTES: "service.namespace=llmhost,deployment.environment=local,host.name=hirose"
    # --compilation-config '{"pass_config":{"fuse_norm_quant":false}}'
    # --enable-chunked-prefill
    # --max-num-batched-tokens 8192
    # --speculative-config '{"method": "mtp", "num_speculative_tokens": 3}'
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

      --dtype auto
      --max-num-seqs 4
      --kv-cache-dtype fp8
      -tp 2
      --speculative-config '{"method": "mtp", "num_speculative_tokens": 3}'
      --attention-backend ROCM_ATTN

      --otlp-traces-endpoint http://aspire-dashboard:18890/v1/traces
      --collect-detailed-traces=all

      --host 0.0.0.0
      --port 8000