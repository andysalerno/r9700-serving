# TODO

## Inkling 2 Mini (vLLM)

Correctness checks not yet done on the current build. Greedy output with
DSpark, prefix-cache hits (chat follow-ups and prompts sharing only their
start) and the hit-vs-no-cache quality have been verified.

- [ ] **Sampling with DSpark at temperature > 0.** Check statistically that
  DSpark's probabilistic accept/reject keeps the target model's output
  distribution (for example, compare token frequencies over many samples with
  and without speculative decoding). Needs a restart without DSpark.
- [ ] **Outputs under concurrency.** At 2-4 concurrent requests, compare
  outputs (with prefix-cache hits and DSpark) against the same requests run
  alone; expect identical greedy text or only batch-shape rounding differences.
- [ ] **Images with prefix-cache hits.** Check that a cached prefix containing
  an image gives the same output as recomputing it, and that a different image
  at the same position doesn't hit the cache.
- [ ] **Perplexity on the current build.** Rerun the Wikitext-2 perplexity
  check (last measured at 7.438, vs 7.437 for the Hugging Face bf16
  reference) after the conv-state cache changes. Needs the service stopped.

Performance:

- [ ] **Decode alternates between two speeds.** The same greedy request
  (same text, same DSpark acceptance) takes 23.6 ms per step in one mode and
  37.5 ms in the other (87 vs 55 tok/s for one chat request). The service
  stayed in the slow mode for hours, and was slow for ~25 s after a restart
  before switching. Clocks (sclk ~3.3 GHz, mclk 1258 MHz, fclk 2016 MHz),
  CPU use and RCCL all-reduce latency (20 us) are the same in both modes;
  GPU1's PCIe link sits at 16 GT/s in both. Next: try
  `power_dpm_force_performance_level=high` or the COMPUTE power profile on
  both GPUs (needs root), then profile a slow step against a fast one.
