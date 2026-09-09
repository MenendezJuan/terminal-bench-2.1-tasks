# oracle evidence (TEMPLATE)

A full Harbor trial directory from `--agent oracle`. Copy it whole; do not curate.

Must contain `verifier/reward.txt` = `1`, plus `verifier/summary.txt` and the
runner's own logs.

reward 1 is what proves the task is SOLVABLE. Anything else and the task is
broken: its own reference solution does not pass it.

Read the test COUNT as well as the reward. A run that collected nothing and
exited 0 also reports success.
