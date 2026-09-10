# Terminal-Bench pre-spend acceptance gate

Complete this checklist before any paid model run.

## Source, contract, and causal hypothesis

- Claim an unused repository and PR before deep work.
- Record the exact sealed pre-merge parent and gold commit.
- Confirm human authorship, bounded scope, tests in the PR, and no dependency churn.
- Map every scored behavior to a prompt clause or an existing public contract.
- State outcomes and preservation requirements without requiring exact prose, private helper names, or the gold implementation.
- Trace the state path, name the central invariant, and pre-register a plausible incomplete repair plus the behavior it still violates.

## Deterministic empirical classification

- Run the same tests on base and gold and preserve every test ID and status.
- Define F2P only as base-failing and gold-passing; P2P only as passing in both.
- Repeat enough times to exclude scheduler, clock, network, platform, and ordering flakes.
- Reject unexplained skips and collection differences.

## Fairness and mutation matrix

- Gold/oracle passes and no-op fails.
- A legitimate alternative implementation passes.
- Equivalent wording and refactoring variants pass.
- Expected phrases with wrong behavior fail.
- The plausible local repair and a one-layer repair fail for the predicted causal reason.
- A real P2P regression fails.

## Hard-core density

- At least half of the natural F2P leaf tests must exercise the pre-registered causal core.
- Two plausible incomplete fixes must each leave at least half of F2P failing for behavioral reasons.
- Do not use a P2P regression as evidence that the candidate is difficult.
- Score leaf test identities, not top-level containers that bundle independent behaviors.
- Base and gold must expose the same graded identities; keep compile/interface checks separate from behavioral F2P when necessary.

Semantic groups may be used only when fixed before observation and when each group is one natural user-facing behavior. Keep diagnostic leaf cases visible. Never regroup after seeing a model result.

## Verifier integrity

- Require every exact graded test ID once.
- Treat skips, missing tests, duplicates, unknown terminal states, unexplained nonzero exits, and malformed reports as verifier failure.
- Capture the complete model patch and raw result.

## Freeze, ownership, and calibration

- Hash prompt, tests, scoring, base image/dependencies, and run configuration.
- Pin model ID, scaffold, resources, network policy, and `max_turns=60`.
- Load only the dedicated Terminal-Bench OpenRouter credential source; never reuse the AA key.
- Assign one run owner before starting Harbor.
- Run pass@1 first and inspect every failure cause and trajectory before continuing.
- Keep every valid attempt and replace only demonstrated provider or harness voids.
- Derive tracker and reports from one canonical attempt ledger.

Passing this gate proves that an observed result will be interpretable and fair. It does not predict that a model will fail.
