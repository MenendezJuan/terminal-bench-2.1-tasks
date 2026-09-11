# Results: semantic-router-eval-integrity

## Independent re-audit — cohort is not valid for delivery

The raw Harbor output is GPT-5.6 reward 0 in five completed attempts and claude-opus-5 reward 0 in three completed attempts. Those raw rewards must not be reported as pass@5/pass@3 difficulty results because the shared failing F2P contract is implementation-biased.

Four of five GPT attempts and all three completed Opus attempts first fail on this assertion:

```python
self.assertEqual(manifest["heldout_row_indices"], [9, 3])
```

Each model recorded the same row identities as `[3, 9]`. The task asks `build_manifest` to record the indices; it does not require preservation of caller order. The nearby sorting sentence can reasonably be read as favoring sorted indices. In the real pipeline, `reserve_heldout` already returns sorted indices, so both implementations produce identical delivered evidence. The artificial unsorted fixture distinguishes the gold's internal passthrough from an equivalent canonicalizing implementation.

Removing only that order-sensitive assertion exposes further gold-specific assumptions in the same top-level test. It monkeypatches `create_mmlu_dataset` with the gold's private tuple shape and call convention. Attempts 1, 2 and 5 use different internal tuple shapes or optional keywords; attempt 4 integrates through the dataset class instead. None of those private interfaces is declared in the instruction. The test therefore cannot establish that these four attempts violate the requested end-to-end behavior.

Attempt 3 is a genuine failure independently of those issues: it keeps five copies of a repeated question in held-out where the instruction requires one, and it uses a fact-check checkpoint name that does not exist in the runtime/download declarations.

## Defensible classification

| model | completed runs | raw reward failures | genuine failures established | inconclusive due to grader bias |
|---|---:|---:|---:|---:|
| GPT-5.6 | 5 | 5 | 1 | 4 |
| claude-opus-5 | 3 | 3 | 0 | 3 |

Infrastructure-invalid attempts remain void and are not included in this table.

The prior statements “GPT pass@5 = 0/5,” “first hard result,” and “Opus pass@3 = 0/3” are withdrawn. This candidate is **REWORK_REQUIRED**. A replacement verifier must split natural behavioral leaves and exercise the public/end-to-end pipeline without imposing the gold's private decomposition. Any changed verifier creates a new task version and requires a fresh cohort; the existing runs cannot be relabeled as results for that version.
