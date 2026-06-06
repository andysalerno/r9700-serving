| model                |            test |              t/s |       peak t/s |        ttfr (ms) |     est_ppt (ms) |    e2e_ttft (ms) |
|:---------------------|----------------:|-----------------:|---------------:|-----------------:|-----------------:|-----------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 | 2623.77 ± 158.17 |                |   789.02 ± 47.53 |   783.80 ± 47.53 |   789.02 ± 47.53 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |    90.72 ± 27.87 |  93.68 ± 28.79 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 |  2931.91 ± 78.42 |                |  1054.08 ± 27.70 |  1048.86 ± 27.70 |  1054.95 ± 26.53 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |     87.40 ± 6.21 |   90.26 ± 6.41 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 |  3044.76 ± 13.28 |                |   1350.72 ± 6.00 |   1345.51 ± 6.00 |   1350.72 ± 6.00 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |    76.98 ± 10.04 |  79.50 ± 10.38 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 |  3014.68 ± 49.33 |                |  2044.12 ± 33.21 |  2038.90 ± 33.21 |  2044.12 ± 33.21 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |     89.43 ± 7.59 |   92.36 ± 7.83 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 |  3003.51 ± 69.62 |                |  3416.75 ± 80.25 |  3411.53 ± 80.25 |  3416.75 ± 80.25 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |    94.86 ± 15.11 |  97.98 ± 15.63 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |  2944.76 ± 18.30 |                |  6265.04 ± 38.73 |  6259.83 ± 38.73 |  6266.72 ± 36.37 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |    77.62 ± 16.12 |  80.15 ± 16.66 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |  2721.43 ± 11.94 |                | 12516.79 ± 55.13 | 12511.57 ± 55.13 | 12516.79 ± 55.13 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |   121.67 ± 25.08 | 125.67 ± 25.93 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |   2361.75 ± 1.75 |                | 27971.38 ± 20.57 | 27966.17 ± 20.57 | 27971.38 ± 20.57 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |     79.62 ± 2.65 |   82.22 ± 2.73 |                  |                  |                  |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-06-06 12:56:58 | latency mode: api

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
        VLLM_WHEEL_URL: https://wheels.vllm.ai/rocm/nightly/rocm723
        VLLM_VERSION: 0.22.1rc1.dev237+gfa27d4e9c.rocm723
        ROCM_WHEEL_INDEX_URL: https://rocm.nightlies.amd.com/whl-multi-arch/
        # ROCM_WHEEL_INDEX_URL: https://repo.amd.com/rocm/whl/gfx120X-all/
        ROCM_SDK_CORE_VERSION: 7.14.0a20260606
        # ROCM_SDK_CORE_VERSION: 7.13.0
        ROCM_SDK_LIBRARIES_VERSION: 7.14.0a20260606
        # ROCM_SDK_LIBRARIES_VERSION: 7.13.0
        ROCM_SDK_LIBRARIES_PACKAGE: rocm-sdk-libraries
        # ROCM_SDK_LIBRARIES_PACKAGE: rocm-sdk-libraries-gfx120X-all
        ROCM_SDK_DEVICE_PACKAGE: rocm-sdk-device-gfx1201
        # ROCM_SDK_DEVICE_PACKAGE: ""
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

      --dtype auto
      --max-num-seqs 4
      --kv-cache-dtype fp8
      -tp 2
      --speculative-config '{"method": "mtp", "num_speculative_tokens": 3}'
      --attention-backend TRITON_ATTN
    # --otlp-traces-endpoint http://aspire-dashboard:18890/v1/traces
    # --collect-detailed-traces=all

  vllm-rocm-wheel-gfx12x-patched:
    profiles: ["vllm-rocm-wheel-gfx12x-patched"]
    image: localhost/vllm-rocm-wheel-gfx12x-patched
    build:
      context: .
      dockerfile: docker/Dockerfile.wheel-gfx12x-patched
      args:
        BASE_IMAGE: localhost/vllm-rocm-wheel-nightly
        ROCM_WHEEL_INDEX_URL: https://rocm.nightlies.amd.com/whl-multi-arch/
        # ROCM_WHEEL_INDEX_URL: https://repo.amd.com/rocm/whl/gfx120X-all/
        ROCM_SDK_DEVEL_VERSION: 7.14.0a20260606
        # ROCM_SDK_DEVEL_VERSION: 7.13.0
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
      - HIPBLASLT_TENSILE_LIBPATH=/opt/vllm/lib/python3.12/site-packages/_rocm_sdk_libraries/lib/hipblaslt/library
      - ROCBLAS_TENSILE_LIBPATH=/opt/vllm/lib/python3.12/site-packages/_rocm_sdk_libraries/lib/rocblas/library
      - GPU_MAX_HW_QUEUES=1
      # - VLLM_LOGGING_LEVEL=DEBUG
      # - VLLM_USE_NCCL_SYMM_MEM=1
      # - VLLM_DISABLE_PYNCCL=1
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