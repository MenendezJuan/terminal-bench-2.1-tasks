# Corrected retrospective and next steps

Candidate 15 (`semantic-router-eval-integrity`) did not establish the first hard JC task. Its raw results were GPT-5.6 reward 0 in five completed attempts and claude-opus-5 reward 0 in three, but an implementation-neutral replay invalidated seven of those adjudications. The canonical evidence is in `CANDIDATE_15_INDEPENDENT_REGRADE_2026-09-11.md` and the task's `RESULTS.md`.

## What the cohort actually established

- GPT attempt 3 has two independent contractual defects: duplicate-question isolation and fact-check artifact parity.
- The other four GPT attempts and all three Opus attempts first fail an unstated order-preservation rule for manifest indices.
- Relaxing that assertion exposes mocks coupled to the gold's private `create_mmlu_dataset` tuple and call shape.
- Defensible classification: GPT 1 genuine failure and 4 inconclusive; Opus 3 inconclusive. No pass@k is reportable.

## Why the pre-spend gate produced false confidence

The oracle, no-op, repeated oracle, and four partial mutations all behaved as predicted. Every mutation was nevertheless derived from the gold's structure. None represented a correct alternative implementation with a different internal decomposition. The gate proved sensitivity to anticipated omissions, not implementation neutrality.

The first top-level F2P test also bundled determinism, stratification, duplicate isolation, supplement filtering, manifest fields, and trainer integration. An arbitrary order assertion therefore sank half of the nominal F2P denominator and prevented the grader from reaching later behavior.

## Revised gate before another paid cohort

1. Derive leaf-level F2P IDs from distinct observable behaviors; never use a top-level test container as the scoring unit.
2. Build an independent correct implementation that deliberately differs from the gold's internal structure.
3. Avoid mocks that prescribe private helper signatures, tuple shapes, or call conventions not declared by the task.
4. Regrade the first model failure by temporarily removing each disputed assertion and continuing to the next observable defect.
5. Archive the full changed workspace. A normal model patch omits untracked files, so use `git add -N` or a workspace snapshot.
6. If any verifier behavior changes after model exposure, issue a new task version and start a fresh cohort. Do not relabel old attempts.

## Selection direction

Continue mining for a hard core that appears through multiple natural behavioral leaves: lifecycle state across restart/reload, partial-failure recovery, memory ownership under sanitizer, or nontrivial numerical/tensor semantics. Multiple PRs or many tests help only when at least half of the natural F2P leaves exercise that same difficult causal boundary.

Candidate 15 is marked `Skipped / REWORK_REQUIRED` in the tracker. It should not be delivered or used as a reference win.
