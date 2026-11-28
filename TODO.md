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
