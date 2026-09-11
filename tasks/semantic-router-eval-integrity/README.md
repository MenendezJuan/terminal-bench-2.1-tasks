# Semantic Router evaluation integrity

This candidate combines two independent, human-authored repairs from the same exact repository base: a disjoint held-out MMLU-Pro evaluation path and alignment between the evaluation registry and the 32K checkpoints served at runtime.

## Current status: REWORK_REQUIRED

An independent post-cohort audit found that the combined F2P test rejects equivalent index ordering and then assumes the gold's private `create_mmlu_dataset` decomposition. The raw rewards therefore do not establish pass@k. One GPT attempt has independent contractual defects; the other four GPT attempts and three completed Opus attempts are inconclusive. See `RESULTS.md` before using any run evidence.

## Pre-spend verification

- The sealed base passes 112 dependency-light upstream tests.
- Harbor no-op returns reward 0; both F2P contracts remain.
- Harbor oracle returns reward 1 with no P2P regression.
- The oracle also passed six direct repetitions.
- Four incomplete-repair mutations each return reward 0. Every mutation leaves exactly one of two F2P contracts failing, which is 50% and therefore a failed attempt under the program rule.
- Model runs exist, but none form a valid pass@k cohort under the current verifier.

The first top-level F2P test bundles several distinct behaviors and private integration assumptions; the cohort re-audit showed that it is too coarse to serve as one causal scoring leaf. The registry contract is independently observable, but the full verifier must be redesigned before further calibration.

Evidence from the Harbor controls and mutation executions is under `evidence/`. The source chain is recorded in `PROVENANCE.json`.
