# Semantic Router evaluation integrity

This candidate combines two independent, human-authored repairs from the same exact repository base: a disjoint held-out MMLU-Pro evaluation path and alignment between the evaluation registry and the 32K checkpoints served at runtime.

## Pre-spend verification

- The sealed base passes 112 dependency-light upstream tests.
- Harbor no-op returns reward 0; both F2P contracts remain.
- Harbor oracle returns reward 1 with no P2P regression.
- The oracle also passed six direct repetitions.
- Four incomplete-repair mutations each return reward 0. Every mutation leaves exactly one of two F2P contracts failing, which is 50% and therefore a failed attempt under the program rule.
- No GPT-5.6 or Opus result has been counted for this task yet.

The first F2P contract checks both the dependency-light split behavior and its real integration into the trainer. The second checks all five model roles against the runtime and download declarations. The two top-level tests are intentional causal units rather than containers for unrelated subtests.

Evidence from the Harbor controls and mutation executions is under `evidence/`. The source chain is recorded in `PROVENANCE.json`.
