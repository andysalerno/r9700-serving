| model                |            test |              t/s |     peak t/s |        ttfr (ms) |     est_ppt (ms) |    e2e_ttft (ms) |
|:---------------------|----------------:|-----------------:|-------------:|-----------------:|-----------------:|-----------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 | 3038.89 ± 237.09 |              |   685.97 ± 55.29 |   678.57 ± 55.29 |   685.97 ± 55.29 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |     32.78 ± 2.03 | 33.53 ± 2.40 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 |  3417.41 ± 31.86 |              |    906.79 ± 8.28 |    899.39 ± 8.28 |    912.61 ± 3.48 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |     31.74 ± 0.10 | 32.77 ± 0.10 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 |  3413.06 ± 32.69 |              |  1207.90 ± 11.45 |  1200.50 ± 11.45 |  1207.90 ± 11.45 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |     31.56 ± 0.33 | 32.58 ± 0.34 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 |  3395.86 ± 11.70 |              |   1817.07 ± 6.29 |   1809.68 ± 6.29 |   1817.07 ± 6.29 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |     31.92 ± 0.39 | 32.95 ± 0.40 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 |  3304.74 ± 47.29 |              |  3106.92 ± 44.68 |  3099.52 ± 44.68 |  3106.92 ± 44.68 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |     32.92 ± 1.64 | 33.99 ± 1.69 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |  3180.33 ± 30.07 |              |  5803.86 ± 54.54 |  5796.46 ± 54.54 |  5803.86 ± 54.54 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |     33.74 ± 1.87 | 34.84 ± 1.93 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |   2953.29 ± 2.30 |              |  11536.68 ± 8.83 |  11529.28 ± 8.83 |  11536.68 ± 8.83 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |     31.53 ± 0.18 | 32.55 ± 0.18 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |   2529.74 ± 6.16 |              | 26116.72 ± 63.33 | 26109.32 ± 63.33 | 26116.72 ± 63.33 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |     33.17 ± 1.56 | 34.25 ± 1.61 |                  |                  |                  |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-05-23 11:24:21 | latency mode: api


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

      --otlp-traces-endpoint http://aspire-dashboard:18890/v1/traces
      --collect-detailed-traces=all
      --enable-log-requests
      --enable-logging-iteration-details

      --host 0.0.0.0
      --port 8000