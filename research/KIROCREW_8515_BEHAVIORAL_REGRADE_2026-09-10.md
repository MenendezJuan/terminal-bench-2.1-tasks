# KiroCrew #8515 behavioral regrade — 2026-09-10

## Verdict

The apparent 0/5 cohort is invalid as a difficulty result. Seven hidden-test assertions required exact exception-message phrases that instruction.md never required. The implementations raised the required MonitorUpdateConflict and usually preserved the required state, but the tests stopped at the message mismatch before reaching their state assertions.

Five completed post-instruction-fix patches were replayed offline in fresh sealed containers with network disabled. The replay removed only the seven unstated match= constraints and preserved exception-class checks and all later state assertions. Controls remained valid: oracle reward 1; no-op reward 0 with 10/10 F2P remaining.

| Trial | Original F2P remaining | Behavior-only F2P remaining | P2P | Contract reward |
|---|---:|---:|---:|---:|
| ifDNs9x | 6/10 | 0/10 | 0 | 1 |
| axGBpGB | 6/10 | 1/10 | 0 | 1 |
| mw2m28p | 8/10 | 2/10 | 0 | 1 |
| PbadsYo | 6/10 | 1/10 | 0 | 1 |
| Q9uTsDv | 6/10 | 0/10 | 0 | 1 |

Under the project rule, a model attempt fails only when at least 50% of F2P remain or any P2P regresses. Every saved patch therefore passes. The candidate is too easy: observed regrade 1/1, 3/3 and 5/5.

Real residual defects existed in three patches but stayed below the failure threshold: two replaced a quarantined malformed monitor; one referenced nonexistent MonitorOutcome.MERGED and lost two replacement paths. These are partial defects, not task failures under the agreed binary rule.

The earlier pre-fix probe that used replace_system_stopped belongs to a different task digest and remains excluded because the exact public parameter name was unstated at that time. Incomplete siblings are not counted. Further paid runs were stopped.

## Process correction

Do not infer causality from failed test names alone. Read the full assertion traceback and replay whenever an early assertion prevents later behavioral checks from executing. Hidden tests should assert observable behavior and state. Exact prose belongs in the prompt only when wording itself is the interface.
