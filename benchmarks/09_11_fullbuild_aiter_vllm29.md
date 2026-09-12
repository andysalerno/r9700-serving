| model                |            test |             t/s |     peak t/s |        ttfr (ms) |     est_ppt (ms) |    e2e_ttft (ms) |
|:---------------------|----------------:|----------------:|-------------:|-----------------:|-----------------:|-----------------:|
| Qwen/Qwen3.8-27B-FP8 |          pp2048 | 3155.50 ± 99.71 |              |   655.00 ± 19.97 |   649.87 ± 19.97 |   655.00 ± 19.97 |
| Qwen/Qwen3.8-27B-FP8 |            tg32 |    57.71 ± 4.62 | 59.59 ± 4.77 |                  |                  |                  |
| Qwen/Qwen3.8-27B-FP8 |  pp2048 @ d1024 | 3360.05 ± 54.31 |              |   919.94 ± 14.98 |   914.81 ± 14.98 |   923.83 ± 14.72 |
| Qwen/Qwen3.8-27B-FP8 |    tg32 @ d1024 |    54.39 ± 2.03 | 56.17 ± 2.10 |                  |                  |                  |
| Qwen/Qwen3.8-27B-FP8 |  pp2048 @ d2048 |  3261.27 ± 1.79 |              |   1261.39 ± 0.69 |   1256.26 ± 0.69 |   1261.39 ± 0.69 |
| Qwen/Qwen3.8-27B-FP8 |    tg32 @ d2048 |    53.46 ± 3.91 | 55.20 ± 4.03 |                  |                  |                  |
| Qwen/Qwen3.8-27B-FP8 |  pp2048 @ d4096 | 3283.44 ± 21.83 |              |  1876.73 ± 12.48 |  1871.60 ± 12.48 |  1876.73 ± 12.48 |
| Qwen/Qwen3.8-27B-FP8 |    tg32 @ d4096 |    60.89 ± 4.78 | 62.87 ± 4.94 |                  |                  |                  |
| Qwen/Qwen3.8-27B-FP8 |  pp2048 @ d8192 |  3226.93 ± 6.03 |              |   3178.75 ± 5.92 |   3173.62 ± 5.92 |   3178.75 ± 5.92 |
| Qwen/Qwen3.8-27B-FP8 |    tg32 @ d8192 |    54.29 ± 3.65 | 56.07 ± 3.77 |                  |                  |                  |
| Qwen/Qwen3.8-27B-FP8 | pp2048 @ d16384 |  3125.18 ± 1.65 |              |   5903.35 ± 3.11 |   5898.22 ± 3.11 |   5903.35 ± 3.11 |
| Qwen/Qwen3.8-27B-FP8 |   tg32 @ d16384 |    51.37 ± 4.17 | 53.04 ± 4.31 |                  |                  |                  |
| Qwen/Qwen3.8-27B-FP8 | pp2048 @ d32000 |  2925.70 ± 1.47 |              |  11642.69 ± 5.84 |  11637.56 ± 5.84 |  11642.69 ± 5.84 |
| Qwen/Qwen3.8-27B-FP8 |   tg32 @ d32000 |    55.95 ± 5.38 | 57.77 ± 5.55 |                  |                  |                  |
| Qwen/Qwen3.8-27B-FP8 | pp2048 @ d64000 |  2574.77 ± 1.80 |              | 25657.40 ± 18.08 | 25652.27 ± 18.08 | 25657.40 ± 18.08 |
| Qwen/Qwen3.8-27B-FP8 |   tg32 @ d64000 |    42.55 ± 3.70 | 43.94 ± 3.82 |                  |                  |                  |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-09-11 20:39:01 | latency mode: api

commit: `e087451c744b10f5b59da885938794d943e88ece` (`Upgrade custom vLLM stack to 0.29.0`)

## Repository and running service

Results supplied by the user. The repository worktree was clean before adding
this record. Configuration and installed package versions below were captured
from the running `vllm` Podman container after the benchmark; the service was not
restarted and the benchmark was not rerun.

| Setting | Value |
|---|---|
| Container image | `localhost/vllm-fullbuild:0.29.0` |
| Image ID | `sha256:3f94447970ea127e29dcccdc663ebb76424cf7f462b56f05012816102d60d115` |
| Container started | `2026-09-11T20:30:09.586644706-07:00` |
| Model | `Qwen/Qwen3.8-27B-FP8` |
| Tokenizer | `Qwen/Qwen3.8-27B` |
| Served model name | `qwen3.8-27b` |
| GPU configuration | `gfx1201`, devices `0,1`, tensor parallelism `2` |
| Attention backend | `ROCM_AITER_UNIFIED_ATTN` |
| Speculative decoding | MTP, `3` speculative tokens, `ROCM_AITER_UNIFIED_ATTN` draft attention |
| KV cache dtype / model dtype | `fp8` / `auto` |
| Maximum model length / sequences | `128000` / `4` |
| GPU memory utilization | `0.93` |
| Prefix caching | Enabled |
| GPU / communication overrides | `GPU_MAX_HW_QUEUES=1`, `NCCL_P2P_DISABLE=1`, `NCCL_MIN_NCHANNELS=112` |

Full runtime arguments and environment are recorded in
[`compose.yaml`](https://github.com/andysalerno/r9700-serving/blob/e087451c744b10f5b59da885938794d943e88ece/compose.yaml),
[`env/2xr9700.vllm.common`](https://github.com/andysalerno/r9700-serving/blob/e087451c744b10f5b59da885938794d943e88ece/env/2xr9700.vllm.common),
and [`env/aiter-unified-attention.env`](https://github.com/andysalerno/r9700-serving/blob/e087451c744b10f5b59da885938794d943e88ece/env/aiter-unified-attention.env)
at the recorded commit.

## Software stack

Installed versions were read from the running container's package metadata.
Source revisions and the ROCm base image are the repository's build pins in
[`env/env.fullbuild`](https://github.com/andysalerno/r9700-serving/blob/e087451c744b10f5b59da885938794d943e88ece/env/env.fullbuild).

| Component | Installed version | Repository source pin |
|---|---|---|
| vLLM | `0.29.0+rocm100.gfx1201` | `98dff2a81d747d1dba01a47f939f48c3526d4206` (`v0.29.0`) |
| PyTorch | `2.13.0+rocm10.0.0` | |
| torchvision | `0.28.0+rocm10.0.0` | |
| torchaudio | `2.11.0.2+rocm10.0.0` | |
| Triton | `3.8.0+git4cff872c.rocm10.0.0` | |
| AITER (`amd-aiter`) | `0.1.1.dev1+gf361bd39b` | `f361bd39ba4196ce29391c628d4ebf72e7929ab8` |
| Flash Attention (`flash_attn`) | `2.8.4` | `a369df707e1980fb328abcc1733e3457ec10155f` |

ROCm base image:
`docker.io/rocm/dev-ubuntu-24.04:10.0.0-full@sha256:a90cf047f615abe70fbef83c64def0a2d549ef37a39c8ea545430aba4981b374`.
