| model                |            test |              t/s |     peak t/s |        ttfr (ms) |     est_ppt (ms) |    e2e_ttft (ms) |
|:---------------------|----------------:|-----------------:|-------------:|-----------------:|-----------------:|-----------------:|
| Qwen/Qwen3.6-27B-FP8 |          pp2048 | 2616.40 ± 105.64 |              |   789.99 ± 31.32 |   784.40 ± 31.32 |   789.99 ± 31.32 |
| Qwen/Qwen3.6-27B-FP8 |            tg32 |     71.01 ± 6.38 | 73.33 ± 6.59 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d1024 |   2841.13 ± 5.23 |              |   1087.33 ± 2.09 |   1081.73 ± 2.09 |   1090.74 ± 2.52 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d1024 |     69.33 ± 8.96 | 71.60 ± 9.26 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d2048 |   2876.81 ± 9.60 |              |   1429.99 ± 4.72 |   1424.39 ± 4.72 |   1429.99 ± 4.72 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d2048 |     76.92 ± 3.67 | 79.43 ± 3.79 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d4096 |   2951.59 ± 5.16 |              |   2087.41 ± 3.79 |   2081.82 ± 3.79 |   2087.41 ± 3.79 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d4096 |     70.98 ± 6.58 | 73.30 ± 6.80 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 |  pp2048 @ d8192 |   2841.97 ± 8.79 |              |  3609.11 ± 11.17 |  3603.52 ± 11.17 |  3609.11 ± 11.17 |
| Qwen/Qwen3.6-27B-FP8 |    tg32 @ d8192 |     74.30 ± 4.00 | 76.73 ± 4.12 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d16384 |   2822.74 ± 3.19 |              |   6535.89 ± 7.68 |   6530.30 ± 7.68 |   6535.89 ± 7.68 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d16384 |     72.69 ± 4.26 | 75.08 ± 4.40 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d32000 |   2627.97 ± 4.33 |              | 12961.91 ± 21.52 | 12956.32 ± 21.52 | 12961.91 ± 21.52 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d32000 |     69.06 ± 4.31 | 71.32 ± 4.46 |                  |                  |                  |
| Qwen/Qwen3.6-27B-FP8 | pp2048 @ d64000 |   2277.78 ± 1.80 |              | 29002.58 ± 23.15 | 28996.99 ± 23.15 | 29002.58 ± 23.15 |
| Qwen/Qwen3.6-27B-FP8 |   tg32 @ d64000 |     60.62 ± 6.45 | 62.61 ± 6.67 |                  |                  |                  |

llama-benchy (0.3.8.dev2+gff162bcfc)
date: 2026-07-21 22:56:29 | latency mode: api

commit: current (45b5cd8a60297b4b0b8d6140456a7063d80f02a7)
command: just fullbuild; podman compose --env-file .env/env.rocm714 --env-file .env/env.vllm.latest --env-file .env/env.aiter.bundled   --profile vllm-mainline up -d

ignore the --env-files, they aren't actually applying values, just necessary so podman doesn't think we're missing values