# vLLM on Radeon AI PRO R9700

Build and run vLLM from source for AMD Radeon AI PRO R9700 GPUs. The default
configuration targets two R9700s (`gfx1201`) and serves a model through vLLM's
OpenAI-compatible API, with Hugging Face Chat UI as a frontend.

## Requirements

- Podman with `podman compose` (the default), or Docker with the Compose
  plugin (`docker compose`); `just` recipes default to Podman
- [`just`](https://just.systems/)
- SELinux hosts need no special relabeling: bind mounts mount unlabeled because
  the container runs with `label=disable`
- One or more R9700 GPUs; the included configuration assumes two

## Build and run

The `justfile` provides the complete workflow:

```sh
# Build localhost/vllm-fullbuild:latest.
just build

# Start vLLM and Chat UI in the background.
just up

# Follow service logs.
just logs

# Stop and remove the containers.
just down
```

To use Docker instead of Podman, set the runtime for a single invocation:

```sh
just --set runtime docker build
RUNTIME=docker just up
```

The vLLM OpenAI-compatible API is available at
`http://localhost:8000/v1`, and the Hugging Face Chat UI at
`http://localhost:8001`.

Run `just --list` to see all available recipes.

## Configuration

Build versions and source revisions are pinned in `env/env.fullbuild`. The
build uses `Dockerfile.fullbuild` to install the pinned PyTorch/ROCm stack and
compile Flash Attention, AITER, and vLLM for `gfx1201`.

Pinned software stack (all at/near head as of 2026-08):

| component    | version                                                              |
|:-------------|:---------------------------------------------------------------------|
| ROCm         | 7.14.0 (`rocm/dev-ubuntu-24.04:7.14.0-full`, HIP 7.14.60850)         |
| PyTorch      | 2.12.0+rocm7.14.0 (torchvision 0.27.0+rocm7.14.0)                    |
| vLLM         | 0.26.2.dev0+g0406ba22c431, built from `vllm-project/vllm` main @ 0406ba22c431 (2026-08-07) |
| AITER        | v0.1.19.post2 @ a63ede724b                                           |
| Flash Attention | @ 1cc7ff67                                                         |

Notes:

- ROCm 7.14.0 is on the "TheRock" Core SDK technology-preview stream (7.9/7.13/7.14,
  new 6-week cadence, no upgrade path from the production 7.2.x line). The current
  production stream is 7.2.4. The preview stream is required for RDNA4/`gfx1201`
  support and torch 2.11.
- AITER `v0.1.19.post2` is the latest tagged release (a hotfix on `v0.1.19`).
- vLLM `0.26.2.dev0` is a dev build ahead of the latest stable release (0.26.0),
  since `gfx1201` support requires a custom ROCm build from source.

Runtime settings are in `compose.yaml`, including the model, vLLM command-line
arguments, GPU count, ports, and mounted caches. The default model is
`Qwen/Qwen3.6-27B-FP8` (dense) with tensor parallelism set to two GPUs. The
previous default, `Qwen/Qwen3.6-35B-A3B-FP8` (MoE, 35B total / 3B active),
is preserved as a comment in the service.

The runtime environment is split between:

- `env/2xr9700.vllm.common` for the two-GPU ROCm configuration
- `env/aiter-unified-attention.env` for the AITER unified-attention baseline
  (the active configuration)
- `env/aiter-moe-unified-attention.env` enables AITER MoE/FP8 kernels in
  addition, but AITER's FP8 MoE backend does not yet support `gfx1201`
  (vLLM aborts at startup), so it is not used by default

The gated-delta (Mamba-style) layers of the MoE `Qwen/Qwen3.6-35B-A3B-FP8`
config force an attention block size of 2112 tokens (2176 with MTP), so
`--max-num-batched-tokens 4096` is required for that model (the default of
2048 fails with a Mamba cache align assertion). The dense 27B default has no
such constraint; 4096 is retained as a latency-friendly middle ground.

Edit these files and `compose.yaml` to match your hardware and model before
building or starting the services.

To remove the generated host-side vLLM, Triton, TorchInductor, AITER, COMGR,
and TVM FFI caches, run:

```sh
just clear-vllm-caches
```

The Hugging Face model cache is intentionally preserved.

## Archived approach

The older multi-profile, patched-image approach remains in [`archive/`](archive/)
for reference.

## Benchmark

All runs use `llama-benchy` (0.4.0, via `uvx`) against the OpenAI-compatible
API. The tuning is `--max-num-batched-tokens 4096`, `--max-num-seqs 4`,
`--gpu-memory-utilization 0.9`, `-tp 2`. The default dense 27B runs MTP with
4 draft tokens (marginally better than 3); the 35B-A3B tables below were
measured at MTP3. Full per-run tables are kept in [`benchmarks/`](benchmarks/).

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

Single-request speeds with the `Qwen/Qwen3.6-35B-A3B-FP8` (MoE) model (MTP3):

| model                      |            test |               t/s |       peak t/s |       ttfr (ms) |    est_ppt (ms) |   e2e_ttft (ms) |
|:---------------------------|----------------:|------------------:|---------------:|----------------:|----------------:|----------------:|
| Qwen/Qwen3.6-35B-A3B-FP8 |          pp2048 | 9354.47 ± 171.64 |                |   220.16 ± 3.97 |   219.11 ± 3.97 |   220.16 ± 3.97 |
| Qwen/Qwen3.6-35B-A3B-FP8 |            tg32 |    143.80 ± 6.85 |  148.43 ± 7.07 |                 |                 |                 |
| Qwen/Qwen3.6-35B-A3B-FP8 |  pp2048 @ d1024 | 10109.29 ± 156.51 |               |   305.97 ± 4.66 |   304.15 ± 4.66 |   305.97 ± 4.66 |
| Qwen/Qwen3.6-35B-A3B-FP8 |    tg32 @ d1024 |     165.34 ± 7.46 |  170.67 ± 7.70 |                 |                 |                 |
| Qwen/Qwen3.6-35B-A3B-FP8 |  pp2048 @ d2048 | 8723.00 ± 2074.47 |               |  505.38 ± 142.82 |  503.56 ± 142.82 |  505.38 ± 142.82 |
| Qwen/Qwen3.6-35B-A3B-FP8 |    tg32 @ d2048 |     163.38 ± 8.56 |  168.65 ± 8.84 |                 |                 |                 |
| Qwen/Qwen3.6-35B-A3B-FP8 |  pp2048 @ d4096 | 10043.61 ± 24.73 |               |   613.59 ± 1.55 |   611.77 ± 1.55 |   613.59 ± 1.55 |
| Qwen/Qwen3.6-35B-A3B-FP8 |    tg32 @ d4096 |     171.18 ± 15.47 | 176.70 ± 15.97 |                 |                 |                 |
| Qwen/Qwen3.6-35B-A3B-FP8 |  pp2048 @ d8192 |  9614.95 ± 5.76 |               |  1066.97 ± 0.61 |  1065.15 ± 0.61 |  1066.97 ± 0.61 |
| Qwen/Qwen3.6-35B-A3B-FP8 |    tg32 @ d8192 |     145.08 ± 6.21 |  149.76 ± 6.41 |                 |                 |                 |
| Qwen/Qwen3.6-35B-A3B-FP8 | pp2048 @ d16384 |  8983.63 ± 14.97 |               |  2053.60 ± 3.40 |  2051.78 ± 3.40 |  2053.84 ± 3.23 |
| Qwen/Qwen3.6-35B-A3B-FP8 |   tg32 @ d16384 |     154.68 ± 6.95 |  159.67 ± 7.17 |                 |                 |                 |
| Qwen/Qwen3.6-35B-A3B-FP8 | pp2048 @ d32000 |  8167.36 ± 6.58 |               |  4170.78 ± 3.33 |  4168.95 ± 3.33 |  4172.11 ± 3.47 |
| Qwen/Qwen3.6-35B-A3B-FP8 |   tg32 @ d32000 |     147.70 ± 6.55 |  152.46 ± 6.76 |                 |                 |                 |
| Qwen/Qwen3.6-35B-A3B-FP8 | pp2048 @ d64000 |  6774.85 ± 1.69 |               |  9750.82 ± 2.38 |  9748.99 ± 2.38 |  9753.25 ± 2.53 |
| Qwen/Qwen3.6-35B-A3B-FP8 |   tg32 @ d64000 |     139.17 ± 7.54 |  143.66 ± 7.78 |                 |                 |                 |

### 27B vs 35B-A3B (MTP3)

The dense default `Qwen/Qwen3.6-27B-FP8` is ~2.2-2.4x slower on decode and ~4x
slower on prefill/TTFT than the MoE `Qwen/Qwen3.6-35B-A3B-FP8` (all 27B params
active per token vs ~3B active for the MoE). Side by side, same tuning:

| test                | 27B-FP8 | 35B-A3B (MoE) | ratio |
|:--------------------|--------:|--------------:|------:|
| pp2048 t/s          |  2390.6 ± 5.4 |  9354.5 ± 171.6 | ~4x |
| pp2048 ttfr (ms)    |    858.3 ± 1.9 |     220.2 ± 4.0 | 3.9x |
| tg32 t/s            |     70.2 ± 3.4 |     143.8 ± 6.9 | 2.0x |
| tg128 t/s           |     66.6 ± 5.9 |     157.7 ± 9.2 | 2.4x |
| tg256 t/s           |     62.8 ± 2.7 |     141.1 ± 9.7 | 2.2x |
| tg512 t/s           |     59.8 ± 0.9 |     140.7 ± 7.0 | 2.4x |
| c4 tg128 (total)    |    105.3 ± 3.0 |     279.0 ± 7.9 | 2.6x |
| c4 tg512 (total)    |    165.1 ± 1.0 |     326.7 ± 8.4 | 2.0x |
| pp8192 ttfr (ms)    |   3263.6 ± 10.7 |     836.6 ± 1.7 | 3.9x |
| d64000 ttfr (ms)    |  32314.9 ± 6.4 |    9750.8 ± 2.4 | 3.3x |
| d64000 tg32 t/s     |     63.5 ± 3.6 |     139.2 ± 7.5 | 2.2x |

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

### MTP draft tokens

Enabling MTP (multi-token prediction) roughly doubles decode speed. Two draft
tokens were tried before settling on three:

| MTP | pp2048 (t/s) | ttfr (ms) | tg32 (t/s) | acceptance |
|:----|-------------:|----------:|-----------:|-----------:|
| off |        10075 |       204 |       82.9 |         -  |
| 2    |      8000 ± 527 |   259 |  145.54 ± 6.51 | 59.8% |
| 3    |  9354 ± 171.64 |   220 |  143.80 ± 6.85 | **72.3%** |

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