# Benchmarks

Single-request and concurrency benchmarks for the Qwen3.6 models served by this
stack, run with `llama-benchy` (0.4.0, via `uvx`) against the OpenAI-compatible
API. Full per-run tables are kept in [`benchmarks/`](benchmarks/). Both models
share the same stack, so the tables here are directly comparable for picking
one.

## Setup

Tuning: `--max-num-batched-tokens 4096`, `--max-num-seqs 4`,
`--gpu-memory-utilization 0.9`, `-tp 2`, MTP4, `--kv-cache-dtype auto` (bf16).

`--kv-cache-dtype` currently uses `auto` (bf16). This required patching AITER:
on gfx1201 the Triton unified-attention kernel staged K/V tiles in the 64 KiB
workgroup shared-memory limit (block_size 64 × head_dim 256) so that bf16 KV
overran it (`out of resource: shared memory, Required: 65792, Hardware limit:
65536`) and the engine crash-looped at startup, while fp8 KV fit. The fix caps
`TILE_SIZE` to 32 (and `num_stages` to 1 in the 3D kernel) when the KV cache is
bf16. Applied via [`patches/aiter/unified-attention-bf16-kv.patch`](patches/aiter/),
which the aiter-builder stage in `Dockerfile.fullbuild` applies at build time.
(Verified 2026-08-07; fp8 KV was the pre-patch default since `d67a63c`
2026-05-22. Note bf16 KV uses ~2x the KV memory of fp8: ~240k vs ~485k tokens
of context.)

## Latest: 2026-08-07, MTP4, bf16 KV

Single-request speeds, same tuning for both models:

| model                     |   test |               t/s |      peak t/s |      ttfr (ms) |   est_ppt (ms) |   e2e_ttft (ms) |
|:--------------------------|-------:|------------------:|--------------:|---------------:|---------------:|----------------:|
| Qwen/Qwen3.6-27B-FP8      | pp2048 | 2965.39 ± 83.75  |               |  692.64 ± 19.15 |  691.51 ± 19.15 |   692.64 ± 19.15 |
| Qwen/Qwen3.6-27B-FP8      |   tg32 |     83.86 ± 5.08  | 86.56 ± 5.25  |                |                |                 |
| Qwen/Qwen3.6-27B-FP8      |   tg128|     70.88 ± 3.28  | 76.67 ± 2.62  |                |                |                 |
| Qwen/Qwen3.6-35B-A3B-FP8  | pp2048 | 10161.59 ± 197.40 |               |  202.86 ± 3.90 |  201.72 ± 3.90 |   202.86 ± 3.90 |
| Qwen/Qwen3.6-35B-A3B-FP8  |   tg32 |     172.53 ± 0.75 | 178.10 ± 0.78 |                |                |                 |
| Qwen/Qwen3.6-35B-A3B-FP8  |   tg128|     153.73 ± 8.97 | 154.94 ± 9.04 |                |                |                 |

Sources: `benchmarks/08_07_qwen3.6-27b_mtp4_bf16kv.md`,
`benchmarks/08_07_qwen3.6-35b-a3b_mtp4_bf16kv.md`. The MoE 35B-A3B is ~2x
faster on decode and ~3.4x faster on prefill/TTFT than the dense 27B.

## 27B vs 35B-A3B (MTP3)

The dense `Qwen/Qwen3.6-27B-FP8` is ~2.2-2.4x slower on decode and ~4x
slower on prefill/TTFT than the MoE `Qwen/Qwen3.6-35B-A3B-FP8` (all 27B params
active per token vs ~3B active for the MoE). Side by side, same tuning:

| test                | Qwen/Qwen3.6-27B-FP8 | Qwen/Qwen3.6-35B-A3B-FP8 | ratio |
|:--------------------|--------------------:|--------------------------:|------:|
| pp2048 t/s          |            2390.6 ± 5.4 |              9354.5 ± 171.6 | ~4x |
| pp2048 ttfr (ms)    |              858.3 ± 1.9 |               220.2 ± 4.0 | 3.9x |
| tg32 t/s            |               70.2 ± 3.4 |               143.8 ± 6.9 | 2.0x |
| tg128 t/s           |               66.6 ± 5.9 |               157.7 ± 9.2 | 2.4x |
| tg256 t/s           |               62.8 ± 2.7 |               141.1 ± 9.7 | 2.2x |
| tg512 t/s           |               59.8 ± 0.9 |               140.7 ± 7.0 | 2.4x |
| c4 tg128 (total)    |              105.3 ± 3.0 |               279.0 ± 7.9 | 2.6x |
| c4 tg512 (total)    |              165.1 ± 1.0 |               326.7 ± 8.4 | 2.0x |
| pp8192 ttfr (ms)    |           3263.6 ± 10.7 |               836.6 ± 1.7 | 3.9x |
| d64000 ttfr (ms)    |         32314.9 ± 6.4 |              9750.8 ± 2.4 | 3.3x |
| d64000 tg32 t/s     |               63.5 ± 3.6 |               139.2 ± 7.5 | 2.2x |

Both models scale at concurrency 4: 27B reaches 165 t/s aggregate (2.8x over
single), 35B reaches 327 t/s (2.3x over single). Decode stays flat across
generation lengths and depths for both (27B ~60-71 t/s, 35B ~139-158 t/s).
Full 27B per-run tables are in
`benchmarks/08_03_qwen3.6-27b_mtp3_{longtg_c1,longtg_c4,pp8192,depth}.md`.

Dense-model tuning notes (27B, measured):

- `--max-num-batched-tokens` is not sensitive for the dense model: 8192 gave no
  improvement over 4096 (c1 decode, TTFT, and pp8192 all unchanged). Keep 4096.
- MTP4 is a small net win over MTP3 on the dense model (tg32 76.6 vs 70.2 t/s,
  c4 tg128 120.5 vs 105.3 t/s) and is the active setting
  (`benchmarks/08_03_qwen3.6-27b_mtp4_*.md`).

## Findings

### NCCL channels (2026-08-09)

The two R9700s sit on separate PCIe 5.0 x8 root ports routed through the CPU,
with P2P disabled (`NCCL_P2P_DISABLE=1`), so TP-2 traffic bounces through host
memory. RCCL auto-detects this as a SHM path and auto-tunes to 2 channels;
the previous config forced `NCCL_MIN_NCHANNELS=112` (with no max), which was
pure overhead on a single x8 link.

`all_reduce_perf` (rccl-tests, 2 GPUs, out-of-place busbw in GB/s):

| channels |     1M |    4M |     8M |    32M |    64M |
|:---------|-------:|------:|-------:|-------:|-------:|
| 1        |   8.04 |  9.51 |  11.09 |  11.81 |  11.94 |
| 2        |   8.88 | 11.19 |  12.15 |  12.54 |  12.61 |
| **4**    | **9.21** | 11.50 | 11.86 | **12.80** | **12.91** |
| 8        |   8.88 | 11.50 |  11.79 |  12.72 |  12.87 |
| 16       |   8.20 | 11.67 |  12.10 |  12.76 |  12.89 |
| 32       |   7.52 | 10.75 |  11.70 |  12.51 |  12.74 |
| 64       |   8.99 | 11.10 |  12.15 |  12.53 |  12.59 |
| 112      |   9.13 | 11.07 |  12.16 |  12.52 |  12.60 |

4 channels is fastest or near-fastest at every size and never below the pack;
112 is never the best. Serving A/B (`llama-benchy`, 35B-A3B MTP4, 3 runs each)
confirms:

| config | tg32 (t/s) | tg128 (t/s) |
|:-------|-----------:|------------:|
| 112 (old) | 174.5 | 133.3 |
| **4 (active)** | 160-183 | 146-159 |

tg128 decode improved ~12-19% on 4 channels; tg32 and prefill are a wash.
2 channels regressed vs 4. Recommendation: keep `NCCL_MIN_NCHANNELS` and
`NCCL_MAX_NCHANNELS` both at 4 on this platform.



Enabling MTP (multi-token prediction) roughly doubles decode speed. Draft-token
count was tuned on the 35B-A3B model (off/2/3 below); both models now run MTP4,
which is a further small win on the dense 27B (tg32 76.6 vs 70.2 t/s at MTP3).

| MTP | pp2048 (t/s) | ttfr (ms) | tg32 (t/s) | acceptance |
|:----|-------------:|----------:|-----------:|-----------:|
| off |        10075 |       204 |       82.9 |         -  |
| 2   |   8000 ± 527 |       259 |  145.54 ± 6.51 | 59.8% |
| 3   | 9354 ± 171.64 |       220 |  143.80 ± 6.85 | **72.3%** |

### Concurrency and generation length

An early concurrency test with short generations (`tg32`, concurrency 4) showed
no scaling (~145 t/s, flat). With longer generations, concurrency 4 scales
well. `total` is aggregate across all concurrent requests, `req` is per request.

| test                | c1 (t/s) | c4 total (t/s) | c4 req (t/s) | scaling |
|:--------------------|---------:|---------------:|-------------:|--------:|
| pp2048 / tg128      |  157.73 ± 9.18 |  279.00 ± 7.90 |   91.20 ± 13.65 | 1.77x |
| pp2048 / tg512      |  140.69 ± 6.98 |  326.72 ± 8.35 |   89.91 ± 5.00 | **2.32x** |
| pp8192 / tg256      |  136.03 ± 1.74 |  187.88 ± 5.21 |   67.76 ± 15.30 | 1.38x |

Key findings:

- Single-request decode is flat ~140-158 t/s regardless of generation length
  (`tg32`-`tg512`).
- The earlier `tg32`/c4 flatness was an artifact of tiny generations (prefill
  dominated); longer generations scale well, reaching **326.7 t/s aggregate at
  concurrency 4** for `tg512`.
- Longer prompts (pp8192) cut concurrent scaling (1.38x vs 2.32x): prefill
  competes with decode for the same `max_num_batched_tokens` budget.
- Longer prompts also raise ttfr a lot (pp8192: 837ms c1 / 2109ms c4).
- MTP speculative decoding constrains `max_num_scheduled_tokens`, which limits
  how far the batch can grow; keep `--max-num-batched-tokens`/`--max-num-seqs`
  at the tuned 4096/4 (raising them showed no benefit).
- MTP acceptance at 3 draft tokens is 72.3% (mean acceptance length 3.17).

### 35B-A3B (MoE) — depth sweep (MTP3, 2026-08-01)

Single-request speeds with the `Qwen/Qwen3.6-35B-A3B-FP8` model at increasing
prompt depth:

| test            |               t/s |       peak t/s |       ttfr (ms) |    est_ppt (ms) |   e2e_ttft (ms) |
|:----------------|------------------:|---------------:|----------------:|----------------:|----------------:|
| pp2048          | 9354.47 ± 171.64 |                |   220.16 ± 3.97 |   219.11 ± 3.97 |   220.16 ± 3.97 |
| tg32            |    143.80 ± 6.85 |  148.43 ± 7.07 |                 |                 |                 |
| pp2048 @ d1024  | 10109.29 ± 156.51 |               |   305.97 ± 4.66 |   304.15 ± 4.66 |   305.97 ± 4.66 |
| tg32 @ d1024    |    165.34 ± 7.46 |  170.67 ± 7.70 |                 |                 |                 |
| pp2048 @ d2048  | 8723.00 ± 2074.47 |               |  505.38 ± 142.82 |  503.56 ± 142.82 |  505.38 ± 142.82 |
| tg32 @ d2048    |    163.38 ± 8.56 |  168.65 ± 8.84 |                 |                 |                 |
| pp2048 @ d4096  | 10043.61 ± 24.73 |               |   613.59 ± 1.55 |   611.77 ± 1.55 |   613.59 ± 1.55 |
| tg32 @ d4096    |    171.18 ± 15.47 | 176.70 ± 15.97 |                 |                 |                 |
| pp2048 @ d8192  |  9614.95 ± 5.76 |               |  1066.97 ± 0.61 |  1065.15 ± 0.61 |  1066.97 ± 0.61 |
| tg32 @ d8192    |    145.08 ± 6.21 |  149.76 ± 6.41 |                 |                 |                 |
| pp2048 @ d16384 |  8983.63 ± 14.97 |               |  2053.60 ± 3.40 |  2051.78 ± 3.40 |  2053.84 ± 3.23 |
| tg32 @ d16384   |    154.68 ± 6.95 |  159.67 ± 7.17 |                 |                 |                 |
| pp2048 @ d32000 |  8167.36 ± 6.58 |               |  4170.78 ± 3.33 |  4168.95 ± 3.33 |  4172.11 ± 3.47 |
| tg32 @ d32000   |    147.70 ± 6.55 |  152.46 ± 6.76 |                 |                 |                 |
| pp2048 @ d64000 |  6774.85 ± 1.69 |               |  9750.82 ± 2.38 |  9748.99 ± 2.38 |  9753.25 ± 2.53 |
| tg32 @ d64000   |    139.17 ± 7.54 |  143.66 ± 7.78 |                 |                 |                 |
