# no-op evidence

A real Harbor trial directory (`harbor run -p tasks/kirocrew-dirty-tree-ratchet
--agent nop -e docker --force-build`), 2026-09-10.

`verifier/reward.txt` = `0`. `verifier/error.txt` = "4 of 4 FAIL_TO_PASS
assertions remain" -- a named test-failure count, not an infrastructure
error. `verifier/summary.json`: 81 tests collected, same as the oracle trial,
so the environment is not what's broken, only the fix is missing.
