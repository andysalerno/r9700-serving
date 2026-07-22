| model                |            test |             t/s |     peak t/s |        ttfr (ms) |     est_ppt (ms) |    e2e_ttft (ms) |
|:---------------------|----------------:|----------------:|-------------:|-----------------:|-----------------:|-----------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 | 2369.27 ± 84.48 |              |   873.21 ± 31.59 |   865.81 ± 31.59 |   873.21 ± 31.59 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |    39.94 ± 2.27 | 41.25 ± 2.34 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 | 2494.09 ± 15.59 |              |   1239.43 ± 7.86 |   1232.03 ± 7.86 |   1242.99 ± 7.96 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |    41.62 ± 0.36 | 42.98 ± 0.38 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 |  2390.06 ± 9.12 |              |   1721.61 ± 6.56 |   1714.21 ± 6.56 |   1721.61 ± 6.56 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |    40.26 ± 1.97 | 41.57 ± 2.03 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 |  2452.67 ± 4.91 |              |   2512.71 ± 5.20 |   2505.30 ± 5.20 |   2512.71 ± 5.20 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |    36.60 ± 1.39 | 37.79 ± 1.44 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 | 2339.78 ± 10.49 |              |  4384.40 ± 19.57 |  4377.00 ± 19.57 |  4384.40 ± 19.57 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |    35.25 ± 1.58 | 36.39 ± 1.63 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 | 2222.05 ± 12.48 |              |  8303.17 ± 46.73 |  8295.77 ± 46.73 |  8303.17 ± 46.73 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |    31.69 ± 1.47 | 32.29 ± 1.82 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |  2014.85 ± 6.59 |              | 16906.46 ± 55.37 | 16899.06 ± 55.37 | 16906.46 ± 55.37 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |    24.39 ± 0.19 | 27.00 ± 0.00 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |  1663.42 ± 1.73 |              | 39714.06 ± 41.65 | 39706.66 ± 41.65 | 39714.06 ± 41.65 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |    15.62 ± 0.35 | 19.33 ± 0.47 |                  |                  |                  |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-05-23 18:14:55 | latency mode: api

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
      --speculative-config '{"method": "mtp", "num_speculative_tokens": 2}'

      --otlp-traces-endpoint http://aspire-dashboard:18890/v1/traces
      --collect-detailed-traces=all
      --enable-log-requests
      --enable-logging-iteration-details

      --host 0.0.0.0
      --port 8000