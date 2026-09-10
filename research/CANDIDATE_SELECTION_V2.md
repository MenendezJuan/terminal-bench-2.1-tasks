# Candidate selection v2: hard-core density

## Finding

The first nine built candidates did not fail because GPT-5.6 is unbeatable. We repeatedly selected tasks with a hard-looking mechanism surrounded by many straightforward requirements. Under the contractual rule, an attempt passes when fewer than half of the F2P tests remain. Easy peripheral leaves dilute the one behavior the model actually misses.

Toolhive #6361 is the clearest example. After correcting the verifier to grade eight leaf subtests, GPT-5.6 passed seven and missed only the expired-row-without-`ErrExpired` case. The result is 1/8 F2P remaining and therefore a valid pass. The previous 1/2 score came from grouping multiple independent behaviors under two top-level Go tests.

## Peer comparison

- OMP read-omitted-lines is valid evidence under our rule: both F2P tests are end-to-end variants of the same hard core, and all five attempts leave both failing.
- Omnigent's published 0/5 uses all-or-nothing reward. Its own report says GPT-5.6 would be 3/5 and Opus 5/5 under the >=50% F2P rule. It is not a hard task under this engagement's contract.
- Valkey also uses all-or-nothing over three bugs. Attempts fixing two of three would pass under the >=50% rule. Its stated 0/5 is not directly comparable.

## New admission gate

A candidate may reach paid calibration only when all conditions hold:

1. At least half of its natural F2P leaves exercise the same unresolved causal core, without duplicating equivalent assertions solely to change weight.
2. Two independently plausible incomplete implementations each leave at least half of F2P failing for the predicted behavioral reason.
3. Failure does not depend on P2P regression. P2P remains a safety veto, not evidence that the bug is difficult.
4. Every F2P identifier is a leaf behavior. Top-level test containers are not scoring units when they contain independent subtests.
5. The verifier follows the operation through to its final externally observable effect. A local check, message, return value, or helper call is insufficient when downstream behavior can still be wrong.
6. Base and gold run the same test identities. A compile-only base failure may be a separate interface gate, but it cannot substitute for behavioral F2P classification.

## Candidate shape to prioritize

Prefer one causal defect that reproduces through multiple natural execution paths or backends. Good examples are snapshot/lifetime violations, state reconciliation where a later benign event overwrites failure, recovery advice that loops when executed, transactional rollback across layers, and serialization/deserialization mismatches whose local fix leaves the final artifact wrong.

Avoid collections of independent subrequirements, even when the aggregate PR is large. A six-file patch with seven routine leaves and one hard leaf is easier under the contract than a two-file patch with two end-to-end witnesses of the same structural mistake.

## Tool and model routing

- Luna, low or medium: inventory recent PRs, ownership conflicts, dates, dependency churn, and test files.
- CodeGraph in the candidate's sealed source clone: trace the symptom to downstream effects, inspect callers/callees, and identify independent execution paths. Check coverage before trusting it.
- Sol, high: implement the task environment and mechanism-neutral verifier in a separate worktree.
- Astra, high or xhigh: adversarially audit contract traceability, hard-core density, mutations, scoring, and release freeze.
- Target models: used only after the task version is frozen. Earlier target-model attempts are authoring probes and never enter pass@k.

The authoring repository's graph is useful for verifier code, but it cannot replace a graph built over the upstream source tree.
