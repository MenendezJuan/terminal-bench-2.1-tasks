# no-op evidence

A real Harbor trial directory (`harbor run -p tasks/docker-agent-strict-schema
--agent nop -e docker --force-build`), 2026-09-10, same conditions as the
oracle trial in `evidence/oracle/README.md`.

`verifier/reward.txt` = `0`. `verifier/error.txt` = "2 of 2 FAIL_TO_PASS
assertions remain" — a named test-failure count, not an infrastructure
error. Matches the oracle trial's test collection, so the environment is not
what's broken, only the fix is missing (the failure mode LAYOUT.md warns
about does not apply here).
