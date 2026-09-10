# JC Terminal-Bench 2.1 authoring retrospective — 2026-09-10

## Corrected outcome

Five built candidates were too easy for GPT-5.6 after fair behavioral grading. Two other candidates were rejected before implementation. KiroCrew #8515 did not survive calibration: six saved patches leave 0, 1, 2, 1, 0, and 1 of 10 F2P tests failing after removing unstated exact-message constraints, with no P2P regressions. Every attempt passes the contractual threshold.

This document replaces the earlier conclusion that candidate 5 was a genuine hard-task result. The canonical replay evidence is in `KIROCREW_8515_BEHAVIORAL_REGRADE_2026-09-10.md`.

## What failed in the selection method

We treated labels such as concurrency, stateful, cross-file, and number of branches as evidence of difficulty. They are only hypotheses. The built tasks still reduced to familiar repairs once the prompt and local code were read:

1. Docker Agent #4155 was a standard recursive schema transformation.
2. KiroCrew #9734 nearly stated the required Git operation.
3. KiroCrew #9825 was a small set of message branches; its first failure was an unfair casing assertion.
4. KiroCrew #9752 was a localized atomic-write pattern; its first failure relied on unstated idempotence.
5. KiroCrew #8515 exposed many cases, but most shared one parameter-threading repair. Exact-message checks inflated failure counts.

The stronger discriminator is causal: identify a plausible incomplete repair before observing model output, then prove with deterministic end-to-end tests that it leaves a central user-visible invariant broken.

## Correction about the teammate sample

The teammate task did not conceal its structural cause. Its prompt explicitly told the solver to evaluate the requested line rather than the leading context line. The transferable strength was the verifier: it parsed the recovery advice, executed it, and confirmed that the omitted content became accessible across both backends. A cosmetic notice could not pass.

Therefore we must not claim that symptom-only wording caused its 0/5 result. Prompt prescription may affect difficulty, but the evidence here supports end-to-end behavioral verification as the primary distinction.

## Process failures

- We inferred convergence from failed test names and partial tracebacks instead of reviewing every attempt.
- Two agents launched overlapping runs, creating six attempts where the ledger expected five.
- Oracle and no-op validated endpoints but did not prove fairness to alternative correct implementations.
- Some F2P tests failed at an absent parameter boundary rather than exercising their intended behavior.
- `max_turns=60` was not explicitly pinned. Future Harbor invocations must set it.
- Corrections were appended after stale conclusions. Canonical documents must be rewritten so only the current decision remains.

## Candidate 6 hypothesis

Floci #3000 is under offline review. It concerns silent Kinesis record loss and inconsistent stream state under concurrent producers, deletion, persistence, and resharding. Four behavior groups were registered before model observation: accepted-record durability and ordering, lifecycle non-resurrection, reshard read consistency, and forwarding-failure semantics.

The upstream tests are discovery evidence, not a verifier to transplant. Several use gold-only hooks or helpers and some use probabilistic stress loops. The task is acceptable only if mechanism-neutral tests can reproduce the defects through existing interfaces with deterministic barriers, and if an alternative correct implementation passes.

## Required pre-spend gate

See `PRE_SPEND_ACCEPTANCE_GATE.md`. A candidate cannot reach a paid run until its observable contract, base/gold classification, deterministic repetition, mutation matrix, verifier-integrity checks, freeze record, isolated Terminal-Bench credential source, one run owner, and explicit `max_turns=60` all pass.
