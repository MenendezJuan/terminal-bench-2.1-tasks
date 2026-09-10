# no-op evidence

**Not a Harbor trial directory.** Same caveat as `evidence/oracle/README.md`:
manual `docker run` reproduction of the verifier, not a Harbor-orchestrated
trial. Regenerate through Harbor before a real delivery.

Reproduced 2026-09-10, same conditions as the oracle run but without applying
`solution/solve.sh` (unmodified base commit).

`verifier/reward.txt` = `0`. `verifier/error.txt` = "2 of 2 FAIL_TO_PASS
assertions remain" — a named test-failure count, not an infrastructure error.
`verifier/summary.json`: 398 tests collected across 2 packages (same count as
oracle — the environment is not broken, only the fix is missing), floor 395,
0 PASS_TO_PASS failures, exit code 1.

Oracle and no-op collected the identical test count (398) but disagree on
outcome for exactly the 2 FAIL_TO_PASS tests — the failure mode LAYOUT.md
warns about (both controls failing identically from a broken environment)
does not apply here.

Command: identical to `evidence/oracle/README.md` minus the `solve.sh` step.
