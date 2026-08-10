# Benchmarks

All benchmarks use `llama-benchy` (0.4.0, via `uvx`) against
`http://localhost:8180/v1`. Per-run tables live in [`benchmarks/`](benchmarks/).

## Setup

`--max-num-batched-tokens 4096`, `--max-num-seqs 4`, `--gpu-memory-utilization
0.9`, `-tp 2`, MTP4, `--kv-cache-dtype auto` (bf16), `GPU_MAX_HW_QUEUES=1`.

bf16 KV cache requires patching AITER: the Triton unified-attention kernel
overflows the R9700's 64 KiB LDS at `TILE_SIZE=64` with bf16 K/V tiles. The fix
caps `TILE_SIZE` to 32 and `num_stages` to 1. Applied via
[`patches/aiter/unified-attention-bf16-kv.patch`](patches/aiter/).

## Current (2026-08-10, vLLM 0.27.0rc2, MTP4, bf16 KV, tuned MoE, NCCL 4-ch)

Single-run data; averages across 3 benchmark sets are in the comparison table.

| model                     |   test |       t/s |
|:--------------------------|-------:|----------:|
| Qwen/Qwen3.6-27B-FP8      | pp2048 | 2924.03 ± 19.96 |
| Qwen/Qwen3.6-27B-FP8      |   tg32 |    87.42 ± 0.09 |
| Qwen/Qwen3.6-27B-FP8      |  tg128 |    76.34 ± 6.50 |
| Qwen/Qwen3.6-35B-A3B-FP8  | pp2048 | 11287.33 ± 367.56 |
| Qwen/Qwen3.6-35B-A3B-FP8  |   tg32 |   188.80 ± 13.15 |
| Qwen/Qwen3.6-35B-A3B-FP8  |  tg128 |   150.74 ± 11.28 |

### v0.26 → v0.27 upgrade

| model          | metric  | v0.26.2.dev0 | v0.27.0rc2 | delta |
|:---------------|:--------|-------------:|-----------:|------:|
| 27B            | pp2048  |      ~2927   |    ~2916   | flat  |
| 27B            | tg32    |        ~75   |      ~87   | **+16%** |
| 27B            | tg128   |        ~66   |      ~76   | **+15%** |
| 35B-A3B        | pp2048  |     ~10864   |   ~11143   | +2.6%  |
| 35B-A3B        | tg32    |       ~182   |     ~189   | +3.8%  |
| 35B-A3B        | tg128   |       ~144   |     ~151   | +4.9%  |

The dense 27B benefits most from v0.27's spec-decode improvements and
multi-layer MTP refactor. Both models show consistent gains with no regressions.

## Baseline comparisons

| description                      | pp2048 t/s | tg32 t/s | vLLM  |
|:---------------------------------|-----------:|---------:|------:|
| 27B andy upstream (MTP3, fp8 KV) |     2750   |   81.9   | v0.25 |
| 35B-A3B no MTP, stock config     |   ~10075   |    ~83   | v0.26 |
| 27B (MTP4, bf16 KV, all opts)    |    ~2916   |    ~87   | v0.27 |
| 35B (MTP4, bf16 KV, all opts)    |   ~11143   |   ~189   | v0.27 |

The 35B-A3B MoE model is 3.8× faster on prefill and 2.2× faster on decode than
the dense 27B. MTP4 + tuned MoE configs + NCCL tuning + v0.27 deliver 2.3×
decode throughput over the no-MTP baseline.

## MTP impact (35B-A3B)

Enabling MTP roughly doubles decode speed. Draft-token count was tuned on the
35B-A3B; both models now run MTP4.

| MTP | pp2048 (t/s) | tg32 (t/s) | acceptance |
|:----|-------------:|-----------:|-----------:|
| off |        10075 |       82.9 |         -  |
| 2   |   8000 ± 527 | 145.54 ± 6.51 | 59.8% |
| 3   | 9354 ± 171.64 | 143.80 ± 6.85 | **72.3%** |

## NCCL channels

Two R9700s on separate PCIe 5.0 x8 root ports, P2P disabled
(`NCCL_P2P_DISABLE=1`). `all_reduce_perf` (rccl-tests, out-of-place busbw GB/s):

| channels |     1M |    4M |     8M |    32M |    64M |
|:---------|-------:|------:|-------:|-------:|-------:|
| 1        |   8.04 |  9.51 |  11.09 |  11.81 |  11.94 |
| 2        |   8.88 | 11.19 |  12.15 |  12.54 |  12.61 |
| **4**    | **9.21** | 11.50 | 11.86 | **12.80** | **12.91** |
| 8        |   8.88 | 11.50 |  11.79 |  12.72 |  12.87 |
| 16       |   8.20 | 11.67 |  12.10 |  12.76 |  12.89 |
| 32       |   7.52 | 10.75 |  11.70 |  12.51 |  12.74 |
| 112      |   9.13 | 11.07 |  12.16 |  12.52 |  12.60 |

4 channels is fastest or near-fastest at every size. Serving A/B confirms
+12-19% tg128 decode on 4-ch vs 112-ch. Recommendation: pin both
`NCCL_MIN_NCHANNELS` and `NCCL_MAX_NCHANNELS` to 4.

## Concurrency

35B-A3B, MTP3. `total` = aggregate across all concurrent requests, `req` = per
request.

| test                | c1 (t/s) | c4 total (t/s) | c4 req (t/s) | scaling |
|:--------------------|---------:|---------------:|-------------:|--------:|
| pp2048 / tg128      |  157.73 ± 9.18 |  279.00 ± 7.90 |   91.20 ± 13.65 | 1.77x |
| pp2048 / tg512      |  140.69 ± 6.98 |  326.72 ± 8.35 |   89.91 ± 5.00 | **2.32x** |
| pp8192 / tg256      |  136.03 ± 1.74 |  187.88 ± 5.21 |   67.76 ± 15.30 | 1.38x |

Single-request decode is flat ~140-158 t/s regardless of generation length.
Longer generations scale best at concurrency 4 (2.32× for tg512). Longer prompts
cut scaling (prefill competes with decode for the `max_num_batched_tokens`
budget).

## Depth sweep (35B-A3B, MTP3)

Single-request speeds at increasing prompt depth (d = prefix tokens before the
2048-token prompt).

| test            |               t/s |       ttfr (ms) |
|:----------------|------------------:|----------------:|
| pp2048 @ d0     | 9354.47 ± 171.64 |   220.16 ± 3.97 |
| tg32 @ d0       |    143.80 ± 6.85 |                 |
| pp2048 @ d1024  | 10109.29 ± 156.51 |   305.97 ± 4.66 |
| tg32 @ d1024    |    165.34 ± 7.46 |                 |
| pp2048 @ d4096  | 10043.61 ± 24.73 |   613.59 ± 1.55 |
| tg32 @ d4096    |    171.18 ± 15.47 |                 |
| pp2048 @ d8192  |  9614.95 ± 5.76 |  1066.97 ± 0.61 |
| tg32 @ d8192    |    145.08 ± 6.21 |                 |
| pp2048 @ d16384 |  8983.63 ± 14.97 |  2053.60 ± 3.40 |
| tg32 @ d16384   |    154.68 ± 6.95 |                 |
| pp2048 @ d32000 |  8167.36 ± 6.58 |  4170.78 ± 3.33 |
| tg32 @ d32000   |    147.70 ± 6.55 |                 |
| pp2048 @ d64000 |  6774.85 ± 1.69 |  9750.82 ± 2.38 |
| tg32 @ d64000   |    139.17 ± 7.54 |                 |

Decode holds flat ~139-171 t/s across all depths. TTFT scales linearly with
context length.
