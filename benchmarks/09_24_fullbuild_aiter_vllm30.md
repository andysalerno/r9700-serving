| model                |            test |              t/s |      peak t/s |         ttfr (ms) |      est_ppt (ms) |     e2e_ttft (ms) |
|:---------------------|----------------:|-----------------:|--------------:|------------------:|------------------:|------------------:|
| Qwen/Qwen3.8-27B-FP8 |          pp2048 | 3015.04 ± 274.62 |               |    691.86 ± 65.70 |    685.57 ± 65.70 |    691.86 ± 65.70 |
| Qwen/Qwen3.8-27B-FP8 |            tg32 |    77.86 ± 10.73 | 80.41 ± 11.08 |                   |                   |                   |
| Qwen/Qwen3.8-27B-FP8 |  pp2048 @ d1024 | 3134.51 ± 127.56 |               |    988.29 ± 40.09 |    982.01 ± 40.09 |    988.29 ± 40.09 |
| Qwen/Qwen3.8-27B-FP8 |    tg32 @ d1024 |     65.86 ± 5.57 |  68.02 ± 5.75 |                   |                   |                   |
| Qwen/Qwen3.8-27B-FP8 |  pp2048 @ d2048 | 3066.06 ± 267.68 |               |  1353.30 ± 122.27 |  1347.01 ± 122.27 |  1353.30 ± 122.27 |
| Qwen/Qwen3.8-27B-FP8 |    tg32 @ d2048 |    96.06 ± 27.79 | 99.22 ± 28.72 |                   |                   |                   |
| Qwen/Qwen3.8-27B-FP8 |  pp2048 @ d4096 | 3121.74 ± 118.01 |               |   1977.81 ± 75.65 |   1971.52 ± 75.65 |   1977.81 ± 75.65 |
| Qwen/Qwen3.8-27B-FP8 |    tg32 @ d4096 |    80.22 ± 19.39 | 82.84 ± 20.03 |                   |                   |                   |
| Qwen/Qwen3.8-27B-FP8 |  pp2048 @ d8192 |  3196.05 ± 24.78 |               |   3210.74 ± 24.98 |   3204.46 ± 24.98 |   3210.74 ± 24.98 |
| Qwen/Qwen3.8-27B-FP8 |    tg32 @ d8192 |    67.93 ± 10.59 | 70.14 ± 10.93 |                   |                   |                   |
| Qwen/Qwen3.8-27B-FP8 | pp2048 @ d16384 |  3092.97 ± 40.10 |               |   5966.93 ± 77.98 |   5960.65 ± 77.98 |   5966.93 ± 77.98 |
| Qwen/Qwen3.8-27B-FP8 |   tg32 @ d16384 |     60.59 ± 6.40 |  62.57 ± 6.61 |                   |                   |                   |
| Qwen/Qwen3.8-27B-FP8 | pp2048 @ d32000 |   2908.79 ± 2.66 |               |  11711.85 ± 10.68 |  11705.57 ± 10.68 |  11711.85 ± 10.68 |
| Qwen/Qwen3.8-27B-FP8 |   tg32 @ d32000 |     55.10 ± 1.34 |  56.89 ± 1.39 |                   |                   |                   |
| Qwen/Qwen3.8-27B-FP8 | pp2048 @ d64000 |  2558.24 ± 12.20 |               | 25825.00 ± 123.43 | 25818.72 ± 123.43 | 25825.00 ± 123.43 |
| Qwen/Qwen3.8-27B-FP8 |   tg32 @ d64000 |    68.03 ± 32.71 | 70.26 ± 33.79 |                   |                   |                   |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-09-24 23:16:48 | latency mode: api

commit: `1d3ce0ef22ffc4a778fd832779d6dbd3d98d1fdb` (`Update fullbuild to vLLM 0.30.0 and fix ROCm startup`)

## Repository and running service

Results supplied by the user. The repository worktree was clean before adding
this record. Configuration and installed package versions below were captured
from the running `vllm` Podman container after the benchmark; the service was not
restarted and the benchmark was not rerun.

| Setting | Value |
|---|---|
| Container image | `localhost/vllm-fullbuild:0.30.0` |
| Image ID | `sha256:363b1d546094ac18745f8d6a9cd85a2d924638d5a45d0df6c415bd228b015ac5` |
| Container started | `2026-09-24T23:10:38.738398229-07:00` |
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
[`compose.yaml`](https://github.com/andysalerno/r9700-serving/blob/1d3ce0ef22ffc4a778fd832779d6dbd3d98d1fdb/compose.yaml),
[`env/2xr9700.vllm.common`](https://github.com/andysalerno/r9700-serving/blob/1d3ce0ef22ffc4a778fd832779d6dbd3d98d1fdb/env/2xr9700.vllm.common),
and [`env/aiter-unified-attention.env`](https://github.com/andysalerno/r9700-serving/blob/1d3ce0ef22ffc4a778fd832779d6dbd3d98d1fdb/env/aiter-unified-attention.env)
at the recorded commit.

## Software stack

Installed versions were read from the running container's package metadata.
Source revisions and the ROCm base image are the repository's build pins in
[`env/env.fullbuild`](https://github.com/andysalerno/r9700-serving/blob/1d3ce0ef22ffc4a778fd832779d6dbd3d98d1fdb/env/env.fullbuild).

| Component | Installed version | Repository source pin |
|---|---|---|
| vLLM | `0.30.0+rocm100.gfx1201` | `ced6857afa0ea7b2e3f0846a62e1394e90f15607` (`v0.30.0`) |
| PyTorch | `2.13.0+rocm10.0.0` | |
| torchvision | `0.28.0+rocm10.0.0` | |
| torchaudio | `2.11.0.2+rocm10.0.0` | |
| Triton | `3.8.0+git4cff872c.rocm10.0.0` | |
| AITER (`amd-aiter`) | `0.1.1.dev1+gb4d9154d1` | `b4d9154d125e09efbe098d986e40fea3549c1244` (`v0.1.22.post1` source) |
| Flash Attention (`flash_attn`) | `2.8.4` | `a369df707e1980fb328abcc1733e3457ec10155f` |

ROCm base image:
`docker.io/rocm/dev-ubuntu-24.04:10.0.0-full@sha256:a90cf047f615abe70fbef83c64def0a2d549ef37a39c8ea545430aba4981b374`.
