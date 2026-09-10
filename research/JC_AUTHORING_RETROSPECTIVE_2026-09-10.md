# JC Terminal-Bench 2.1 authoring retrospective — 2026-09-10

## Decision

The fifth candidate, `kirocrew-autonudge-stopped-arm-deadlock`, is the first candidate that survives pass@1. Its comparable GPT-5.6 run scored 0 with 6 of 10 FAIL_TO_PASS tests still failing and no PASS_TO_PASS regressions. The model implemented the four replacement paths and missed the six preservation paths. This is a genuine partial solution, not a harness, environment, or grading failure.

Do not describe this as five failed model attempts. Four earlier candidates were each solved on their first valid GPT-5.6 attempt and were correctly dropped as too easy. Candidate 5 required an authoring correction before its counted pass@1: the first probe used a semantically valid but differently named keyword parameter because the prompt had not specified the exact public identifier. That probe is not part of the calibrated cohort.

## Root cause of the four drops

The first candidates exposed most of their solution structure in the instruction: schema traversal named the keyword families and invariants; diff endpoint selection reduced to a localized conceptual repair; message branching enumerated the branches; filesystem safety enumerated the required properties after an initial prompt omission. GPT-5.6 could map the stated cases directly to code. Changing bug shape alone did not add enough discovery work.

The teammate's successful task has a stronger difficulty shape: the visible symptom invites a plausible partial fix, while the actual cause is a check rendered ineffective by an upstream transformation. Five attempts converged on the same superficial repair. That convergence, plus partial progress and intact PASS_TO_PASS tests, is stronger evidence of difficulty than a total score alone.

## What changed with candidate 5

Candidate 5 crosses four call layers and two callers with opposing policies over retained state. Even though its instruction enumerates the classification, the first comparable model run still confused fields from two record types and omitted the forward-version guard. Its longer trajectory and higher cost are supporting signals; the causal test breakdown is the deciding evidence.

## Freeze and next gate

Keep the current instruction, tests, verifier, environment, model, scaffold, timeouts, resources, and no-internet setting unchanged for the next two attempts. Editing the long instruction now would create a new task version and invalidate direct pass@3 comparability.

After two more valid attempts: if either passes, stop at the observed pass@3 stage and record the exact count; if both fail, inspect whether failures converge on the same preservation/classification boundary before proceeding to pass@5; exclude and privately replace only true provider or harness voids.

For the next task, prefer symptom-level prompts backed by tests over a prose enumeration of the internal taxonomy. Every asserted behavior still needs prompt support, but the prompt can state the invariant and observable cases without naming the implementation partition, helper, or full internal decision table.

## Audit notes

- The verifier implements the private threshold correctly: an attempt fails when `F2P_REMAINING * 2 >= F2P_TOTAL`, or when any PASS_TO_PASS test regresses.
- Oracle and no-op controls remain valid after the threshold correction because they sit at 0% and 100% F2P remaining.
- The current F2P derivation text says the TypeError tests could not be “collected into a meaningful pass/fail.” Pytest did collect and grade them; the intended point is that they measured the missing keyword interface before deeper behavior. Correct this wording only in a later documentation/package revision, without changing the frozen pass@3 cohort.
- The tracker previously still pointed at the dropped Docker Agent candidate and needed correction.

## Superseding audit result

The initial candidate-5 genuine-failure conclusion was superseded after replaying all five saved patches without seven unstated exact-message constraints. All five pass the contractual threshold. See [KIROCREW_8515_BEHAVIORAL_REGRADE_2026-09-10.md](KIROCREW_8515_BEHAVIORAL_REGRADE_2026-09-10.md).
