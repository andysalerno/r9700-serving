| model                |            test |              t/s |        peak t/s |         ttfr (ms) |      est_ppt (ms) |     e2e_ttft (ms) |
|:---------------------|----------------:|-----------------:|----------------:|------------------:|------------------:|------------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 | 2793.63 ± 276.45 |                 |    751.14 ± 78.40 |    741.21 ± 78.40 |    751.14 ± 78.40 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |    81.51 ± 24.32 |   84.19 ± 25.14 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 | 2764.81 ± 285.42 |                 |  1133.72 ± 121.79 |  1123.78 ± 121.79 |  1133.72 ± 121.79 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |     92.61 ± 2.26 |    95.64 ± 2.34 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 |  2951.10 ± 31.17 |                 |   1398.39 ± 14.67 |   1388.45 ± 14.67 |   1398.39 ± 14.67 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |     85.54 ± 7.20 |    88.34 ± 7.44 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 |  2993.93 ± 36.80 |                 |   2062.73 ± 25.05 |   2052.79 ± 25.05 |   2062.73 ± 25.05 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |     89.90 ± 8.12 |    92.84 ± 8.39 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 |  2696.97 ± 88.83 |                 |  3811.08 ± 122.97 |  3801.15 ± 122.97 |  3812.16 ± 123.99 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |  773.88 ± 645.73 | 804.01 ± 672.59 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |  2597.64 ± 10.90 |                 |   7105.99 ± 29.63 |   7096.05 ± 29.63 |   7105.99 ± 29.63 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |     81.91 ± 4.06 |    84.59 ± 4.19 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |  2184.32 ± 16.53 |                 | 15598.29 ± 118.29 | 15588.35 ± 118.29 | 15598.29 ± 118.29 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |  402.44 ± 435.74 | 417.31 ± 452.40 |                   |                   |                   |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |   1673.88 ± 3.62 |                 |  39468.45 ± 85.55 |  39458.51 ± 85.55 |  39468.45 ± 85.55 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |   123.78 ± 48.03 |  127.86 ± 49.63 |                   |                   |                   |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-05-22 20:06:26 | latency mode: api


  vllm-qwen36-27b-fp8-aml731:
    image: aml731/vllm-aiter:v0.20.2
    profiles: ["vllm-aml"]
    container_name: vllm-qwen36-27b-fp8-aml731
    group_add:
      - video
    ports:
      - "8000:8000"
    ipc: host
    cap_add:
      - SYS_PTRACE
    security_opt:
      - seccomp:unconfined
    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
    volumes:
      - ${HOME}/.cache/huggingface:/root/.cache/huggingface:Z
      - ./chat-templates/:/app/chat-templates:Z
      - ${HOME}/.cache/vllm:/root/.cache/vllm:Z
    networks:
      default:
        aliases:
          - llm-backend
    environment:
      - VLLM_ROCM_USE_AITER=1
      - VLLM_ROCM_ALLOW_RDNA4_AITER_ATTENTION=1
      - VLLM_ROCM_USE_AITER_UNIFIED_ATTENTION=1
      # - VLLM_V1_USE_PREFILL_DECODE_ATTENTION=0 # adding seems to slow down tg at 60000
      - VLLM_ROCM_USE_AITER_MHA=1
      - VLLM_ROCM_USE_AITER_PAGED_ATTN=0
      - VLLM_ROCM_USE_AITER_MOE=0
      - VLLM_ROCM_USE_AITER_LINEAR=0
      - FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
      - PYTORCH_ALLOC_CONF=expandable_segments:True
    command: >
      python3 -m vllm.entrypoints.openai.api_server
      --model Qwen/Qwen3.6-27B-FP8
      --served-model-name qwen3.6-27b
      -tp 2
      --dtype auto
      --speculative-config '{"method":"mtp","num_speculative_tokens":3}'
      --attention-backend ROCM_AITER_UNIFIED_ATTN
      --compilation-config '{"pass_config":{"fuse_norm_quant":false}}'
      --max-model-len 128000
      --gpu-memory-utilization 0.95
      --enable-chunked-prefill
      --max-num-batched-tokens 8192
      --enable-prefix-caching
      --trust-remote-code
      --quantization fp8
      --max-num-seqs 4
      --enable-auto-tool-choice
      --tool-call-parser qwen3_coder
      --reasoning-parser qwen3
      --host 0.0.0.0
      --port 8000
      --override-generation-config '{"temperature": 1.0, "top_p": 0.95, "top_k": 20, "min_p": 0.0, "presence_penalty": 0.0, "repetition_penalty": 1.0}'