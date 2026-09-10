# oracle evidence

**Not a Harbor trial directory.** No Harbor runner is available in this
environment; this is a manual reproduction: `docker run` on the image built
from `environment/Dockerfile`, with `solution/solve.sh` applied before
`tests/test.sh`. It exercises the exact same verifier script a real Harbor
trial would, but skips Harbor's own orchestration/logging layer. Do not present
this as harness-produced evidence — regenerate through Harbor before a real
delivery.

Reproduced 2026-09-10 by an independent audit (astra-reviewer) and again after
fixing the floor margin and PASS_TO_PASS whitelist gap it found.

`verifier/reward.txt` = `1`. `verifier/summary.json`: 398 tests collected
across 2 packages (floor 395), 0 of 2 FAIL_TO_PASS remaining, 0 PASS_TO_PASS
failures, exit code 0.

Command:
```
docker run --rm --network none \
  -v <repo>/tasks/docker-agent-strict-schema/tests:/verifier-src:ro \
  -v <repo>/tasks/docker-agent-strict-schema/solution:/solution-src:ro \
  tb21-docker-agent-strict-schema \
  bash -c "mkdir -p /tests && cp /verifier-src/*.go /tests/ && bash /solution-src/solve.sh && bash /verifier-src/test.sh"
```
