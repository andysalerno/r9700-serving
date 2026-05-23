| model                |            test |             t/s |     peak t/s |          ttfr (ms) |       est_ppt (ms) |      e2e_ttft (ms) |
|:---------------------|----------------:|----------------:|-------------:|-------------------:|-------------------:|-------------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 | 2383.51 ± 88.35 |              |     875.67 ± 32.60 |     860.73 ± 32.60 |     875.67 ± 32.60 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |    37.61 ± 3.22 | 38.83 ± 3.33 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 | 2119.10 ± 18.24 |              |    1465.35 ± 12.68 |    1450.41 ± 12.68 |     1470.23 ± 7.50 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |    38.36 ± 1.81 | 39.61 ± 1.87 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 |  1894.56 ± 9.39 |              |    2177.50 ± 10.69 |    2162.56 ± 10.69 |    2177.50 ± 10.69 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |    35.74 ± 1.88 | 36.91 ± 1.95 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 | 1613.21 ± 42.14 |              |   3826.76 ± 101.37 |   3811.82 ± 101.37 |   3826.76 ± 101.37 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |    30.89 ± 0.22 | 31.38 ± 0.54 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 |  1244.40 ± 3.82 |              |    8244.41 ± 24.91 |    8229.47 ± 24.91 |    8244.41 ± 24.91 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |    22.44 ± 1.32 | 24.33 ± 0.94 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |   840.40 ± 1.34 |              |   21948.69 ± 35.03 |   21933.75 ± 35.03 |   21948.69 ± 35.03 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |    14.70 ± 0.82 | 16.67 ± 0.47 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |   511.34 ± 0.82 |              |  66603.19 ± 107.43 |  66588.25 ± 107.43 |  66603.19 ± 107.43 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |     9.17 ± 0.10 | 10.67 ± 0.47 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |   279.69 ± 0.47 |              | 236171.03 ± 399.96 | 236156.09 ± 399.96 | 236171.03 ± 399.96 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |     4.50 ± 0.51 |  6.33 ± 0.47 |                    |                    |                    |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-05-22 19:22:05 | latency mode: api

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
      FLASH_ATTENTION_TRITON_AMD_ENABLE: "TRUE"
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
      --attention-backend TRITON_ATTN

      --otlp-traces-endpoint http://aspire-dashboard:18890/v1/traces
      --collect-detailed-traces=all

      --host 0.0.0.0
      --port 8000