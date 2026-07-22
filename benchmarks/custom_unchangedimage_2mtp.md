| model                |            test |            t/s |     peak t/s |          ttfr (ms) |       est_ppt (ms) |      e2e_ttft (ms) |
|:---------------------|----------------:|---------------:|-------------:|-------------------:|-------------------:|-------------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 |  750.86 ± 1.62 |              |     2738.06 ± 5.93 |     2728.00 ± 5.93 |     2738.06 ± 5.93 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |   22.20 ± 0.09 | 25.00 ± 0.82 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 | 747.61 ± 11.23 |              |    4122.30 ± 61.23 |    4112.24 ± 61.23 |    4124.27 ± 58.84 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |   23.25 ± 1.83 | 27.00 ± 0.82 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 |  737.36 ± 6.66 |              |    5566.82 ± 50.37 |    5556.76 ± 50.37 |    5566.82 ± 50.37 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |   22.34 ± 1.98 | 26.33 ± 0.94 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 |  751.22 ± 2.76 |              |    8189.70 ± 30.07 |    8179.64 ± 30.07 |    8189.70 ± 30.07 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |   23.19 ± 0.31 | 25.33 ± 0.47 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 |  741.00 ± 4.07 |              |   13831.01 ± 76.95 |   13820.96 ± 76.95 |   13831.01 ± 76.95 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |   22.62 ± 0.70 | 24.33 ± 0.47 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |  731.13 ± 1.26 |              |   25221.49 ± 43.96 |   25211.43 ± 43.96 |   25221.49 ± 43.96 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |   19.86 ± 0.85 | 23.00 ± 0.82 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |  707.09 ± 1.50 |              |  48163.78 ± 102.76 |  48153.72 ± 102.76 |  48163.78 ± 102.76 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |   16.66 ± 0.75 | 19.00 ± 0.00 |                    |                    |                    |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |  658.85 ± 0.99 |              | 100258.50 ± 152.50 | 100248.44 ± 152.50 | 100258.50 ± 152.50 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |   12.06 ± 0.39 | 14.67 ± 0.47 |                    |                    |                    |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-05-23 18:46:58 | latency mode: api

  vllm-rocm-wheel-gfx12x-patched:
    profiles: ["vllm-rocm-wheel-gfx12x-patched"]
    # image: localhost/vllm-rocm-wheel-gfx12x-patched
    image: localhost/vllm-rocm-wheel-nightly
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

    environment:
      HIP_VISIBLE_DEVICES: "0,1"
      ROCR_VISIBLE_DEVICES: "0,1"
      HIP_PLATFORM: "amd"
      VLLM_TARGET_DEVICE: "rocm"
      VLLM_ROCM_GCN_ARCH: "gfx1201"
      PYTORCH_ROCM_ARCH: "gfx1201"
      HIP_ARCHITECTURES: "gfx1201"
      AMDGPU_TARGETS: "gfx1201"
      GPU_ARCHS: "gfx1201"
      VLLM_ROCM_USE_AITER: "1"
      VLLM_ROCM_USE_AITER_MHA: "0"
      VLLM_ROCM_USE_AITER_MLA: "0"
      VLLM_ROCM_USE_AITER_MOE: "0"
      VLLM_ROCM_USE_AITER_LINEAR: "0"
      VLLM_ROCM_USE_AITER_FP8BMM: "0"
      VLLM_ROCM_USE_AITER_FP4BMM: "0"
      VLLM_ROCM_USE_AITER_TRITON_GEMM: "0"
      VLLM_ROCM_USE_AITER_RMSNORM: "0"
      VLLM_ROCM_USE_AITER_UNIFIED_ATTENTION: "1"
      VLLM_ROCM_SHUFFLE_KV_CACHE_LAYOUT: "0"
      OTEL_SERVICE_NAME: "vllm-rocm-wheel-gfx12x-patched"
      OTEL_EXPORTER_OTLP_TRACES_PROTOCOL: "http/protobuf"
      OTEL_EXPORTER_OTLP_TRACES_INSECURE: "true"
      OTEL_RESOURCE_ATTRIBUTES: "service.namespace=llmhost,deployment.environment=local,host.name=hirose"

    command: >
      Qwen/Qwen3.6-27B-FP8
      --tokenizer Qwen/Qwen3.6-27B
      --served-model-name qwen3.6-27b
      --chat-template /app/chat-templates/qwen36.jinja
      --limit-mm-per-prompt '{"image": 0, "audio": 0, "video": 0}'
      --enable-auto-tool-choice --tool-call-parser qwen3_coder --reasoning-parser qwen3
      --max-model-len 128000
      --enable-prefix-caching
      --dtype auto
      --max-num-seqs 4
      --kv-cache-dtype fp8
      -tp 2
      --override-generation-config '{"temperature": 1.0, "top_p": 0.95, "top_k": 20, "min_p": 0.0, "presence_penalty": 0.0, "repetition_penalty": 1.0}'
      --gpu-memory-utilization 0.93

      --attention-backend ROCM_AITER_UNIFIED_ATTN
      --compilation-config '{"pass_config":{"fuse_norm_quant":false,"fuse_act_quant":false,"fuse_allreduce_rms":false,"fuse_mla_dual_rms_norm":false}}'
      --speculative-config '{"method": "mtp", "num_speculative_tokens": 2}'

      --otlp-traces-endpoint http://aspire-dashboard:18890/v1/traces
      --collect-detailed-traces=all
      --enable-log-requests
      --enable-logging-iteration-details

      --host 0.0.0.0
      --port 8000