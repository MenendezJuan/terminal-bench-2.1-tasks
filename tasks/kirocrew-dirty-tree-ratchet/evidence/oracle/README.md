# oracle evidence

A real Harbor trial directory (`harbor run -p tasks/kirocrew-dirty-tree-ratchet
--agent oracle -e docker --force-build`), 2026-09-10.

`verifier/reward.txt` = `1`. `verifier/summary.json`: 81 tests collected
(floor 78), 0 of 4 FAIL_TO_PASS remaining, 0 PASS_TO_PASS regressions, exit 0.

Note: the first attempt without `--force-build` failed with `cd: /app: No
such file or directory` -- a stale cached image from the prior task's build,
not a defect here. Always `--force-build` the first run of a new task on this
machine; see the Harbor-on-Windows note in the vault.
