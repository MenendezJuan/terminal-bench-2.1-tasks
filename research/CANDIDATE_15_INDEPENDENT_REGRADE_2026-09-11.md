# Independent regrade: semantic-router-eval-integrity

Date: 2026-09-11  
Decision: **REWORK_REQUIRED — no pass@k result is reportable**

## Scope

This review replays the completed GPT-5.6 and claude-opus-5 attempts against the written contract instead of accepting Harbor's binary reward. The frozen oracle/no-op and mutation controls remain useful verifier-development evidence, but they do not prove that the verifier fairly adjudicates independently authored implementations.

## Blocking verifier bias

Four of five GPT attempts and all three completed Opus attempts first stop at:

```python
self.assertEqual(manifest["heldout_row_indices"], [9, 3])
```

They record `[3, 9]`: the same row identities in canonical order. The instruction requires the returned indices from `reserve_heldout` to be sorted and requires `build_manifest` to record the indices. It does not say that `build_manifest` must preserve an artificially unsorted caller sequence. The real producer already supplies sorted indices, so this fixture distinguishes the gold's private passthrough implementation without distinguishing delivered behavior.

After replacing only that equality with an order-insensitive comparison during the audit, the same top-level test exposes further gold-specific assumptions. Its monkeypatched `create_mmlu_dataset` returns the gold's private four-value tuple and accepts the gold's call shape. Independently authored attempts use a five-value return, optional `include_heldout` or `return_heldout` keywords, or the dataset-class integration path. Those private interfaces are absent from `instruction.md`. The resulting `ValueError`, `TypeError`, and stub-driven `AttributeError` do not establish a contractual defect.

## Per-cohort conclusion

| Model | Completed | Raw reward 0 | Established genuine failures | Inconclusive |
|---|---:|---:|---:|---:|
| GPT-5.6 | 5 | 5 | 1 | 4 |
| claude-opus-5 | 3 | 3 | 0 | 3 |

GPT attempt 3 remains a genuine failure independent of the biased seams. It reserves every copy of a repeated question instead of keeping one held-out copy and excluding the remaining copies from training, and it points the fact-check role to a checkpoint name that does not match the runtime/download artifacts.

## Reproducibility limitation

Several attempts created `heldout_split.py` as an untracked file. Harbor's captured `verifier/model.patch` does not contain untracked files, so a patch-only replay is incomplete. The audit reconstructed those files from the exact shell commands in each `agent/trajectory.json`. Future evidence capture must archive the full changed workspace, including untracked files, or stage intent with `git add -N` before producing the patch.

## Why the pre-spend controls missed it

The mutation matrix only tested incomplete variants derived from the gold. It proved that those known mutations fail, not that alternative implementations pass. One top-level F2P test also bundles determinism, stratification, duplicate isolation, supplemental filtering, manifest serialization, and trainer integration. A single non-contractual assertion therefore counts as half of the entire F2P denominator and masks later failures.

## Required disposition

1. Withdraw the earlier GPT `0/5`, Opus `0/3`, and “first hard result” claims.
2. Mark this frozen candidate skipped/rework-required; do not relabel its runs.
3. If salvaged, create a new task version whose F2P IDs are natural behavioral leaves, accept equivalent index ordering, and exercise public/end-to-end behavior without mocking a private gold decomposition.
4. Run new oracle, no-op, alternative-implementation and mutation controls, then start a completely fresh paid cohort.

