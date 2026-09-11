# Peer task pattern audit, 2026-09-10

## Scope

This review reads the runnable tasks and per-attempt evidence in
`Tasks-20260911T001935Z-1-001.zip` and applies the local Terminal-Bench 2.1
guideline, especially the rule that an attempt fails when at least 50% of its
natural FAIL_TO_PASS leaves remain or when any PASS_TO_PASS test regresses.
Published top-line rewards were not trusted without the leaf breakdown.

## Comparable results

| Task | GPT-5.6 result | Shape under the official rule | What carries the difficulty |
|---|---:|---|---|
| `omp-read-omitted-lines` | 0/5 | Directly comparable: 2 F2P, both remain in every attempt | One dead size check reached through two end-to-end read paths. Models add warning/recovery text but leave the check in the wrong control-flow position. |
| `apm-cache-prune-recency` | 0/5 | Directly comparable: 14-16 of 28 F2P remain in every attempt | The 12-case warning-and-continue error contract plus the real CLI stderr route form 13 leaves that every attempt misses. The parameter matrix makes the hard core visible across full/sparse and hit/write-dedup paths. |
| `olmo-dropout-diverge` | 1/5 | Directly comparable: 3 of 5 F2P cover the subtle dropout defect | Models fix the forwarding and checkpoint flags but usually miss that the mask must sample per element rather than per token. The hard mathematical core owns 60% of F2P. |
| `valkey-forkless-save-safety` | 0/5 | The binary grader wording is imprecise, but the verdict survives the official leaf rule | Four F2P leaves are distributed 2/1/1. Attempts that fix primary-write plus swapdb leave both rename triggers failing: 2/4 = 50%, still a failure. ASan exposes lifetime defects hidden by the normal allocator. |
| `omnigent-runner-failure-visibility` | GPT 3/5, Opus 5/5 under the official rule | Not a hard result for this engagement | Its stricter published reward masks that most attempts cross the official F2P threshold. |

## What the successful tasks actually share

They do not merely have three bugs or many tests. OMP has one causal defect and
two tests. The common property is that at least half of the natural F2P leaves
exercise behavior a plausible local repair still misses:

- a downstream effect rather than a helper call;
- state or ownership that crosses a lifecycle boundary;
- numerical or tensor semantics that look superficially plausible;
- recovery behavior under a real failure mode;
- a second execution path or configuration that invalidates the obvious fix.

The best tasks also let the model make visible progress. OLMo attempts solve two
of three requirements, APM attempts solve every stateless requirement, and
Valkey attempts solve different subsets. That is the guideline's expected
20-40% progress signal, not random breakage.

## What our dropped candidates share

The eleven valid GPT-5.6 passes were not one repeated language bias. They covered
Go, Python, Java, Rust and C. The repeated authoring shape was more important:

1. The prompt enumerated the implementation taxonomy or named the exact helper,
   branch, lock, field or error behavior needed.
2. Each requirement mapped to a small local code change, so the model could
   solve the task as a checklist.
3. Concurrency candidates exposed their synchronization mechanism directly,
   rather than grading a coherent final state after restart/reload/serialization.
4. Some early verifiers asserted wording or gold-specific signatures. Once those
   unfair constraints were removed, the model's alternative implementation was
   correct and passed.
5. Mutation tests proved grading fairness but were treated as predictions of
   model difficulty. They are not. A model can simply implement the full fix.
6. Several candidates had one hard leaf diluted by routine leaves. Leaf count
   matters only through causal distribution, not volume.

## Selection policy from here

Before a scaffold is built, require all of the following:

- New regression tests must be additive, or the correct production fix must
  remain coherent with the agent-visible base suite. A hidden test overlay must
  not silently reverse visible expectations.
- At least two natural end-to-end F2P leaves must traverse the hard core.
- A mechanism-only partial repair and a one-layer-only repair must each leave at
  least half of F2P failing.
- The prompt names the interface, symptom, observable contract and test command,
  while leaving the implementation path for the agent to discover.
- The same semantic outcomes are checked at base and gold; helper-name and exact
  wording assertions are excluded.
- The candidate is rejected before a paid call if its gold is a short checklist
  directly recoverable from the prompt and local error message.

## Candidate 13 decision

`nearai/ironclaw#7962` has a real durable recovery invariant, and CodeGraph
confirmed the recovery state reaches checkpointed loop state. It is still
rejected before spend because the PR replaces existing tests that require the
old observation-assisted retry. A correct fix would make the visible base suite
red until hidden tests overwrite those expectations. That feedback loop is not
fair enough for this lane.

## Candidates 14 and 15

Candidate 14, `vllm-project/semantic-router#3390`, was dropped at the
difficulty gate. It is a valid bug but collapses to one small helper and
adjacent usage-propagation edits, the same self-contained single-PR shape
GPT-5.6 solved eleven times for JC.

Candidate 15 combines `vllm-project/semantic-router#3628` and `#3651`, which
share exact base `ce271702...` and add their regression coverage instead of
reversing visible expectations. The two natural leaves are evaluation
integrity incidents: training/evaluation leakage across duplicate question
text, and an evaluation registry that scores legacy 8K checkpoints instead of
the 32K artifacts production serves. Either partial repair must leave exactly
1/2 failing. It remains RESEARCHING until an executable integration test proves
the held-out slice reaches final evaluation and its manifest; helper-only or
source-shape assertions are insufficient.
