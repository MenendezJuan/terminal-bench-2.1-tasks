# Autonudge Stopped-Arm Deadlock, Two-Caller Policy Split

## Overview

`src/kiro_crew/autonudge.py` in `kirodotdev/KiroCrew` gates a session's
automation slot with a create-only occupancy check that reads ANY retained
record (active or stopped) as an occupant. That deadlocks the product's own
documented recovery: an approval-stalled automation is deactivated and
retained for inspection, `monitor_update` refuses to revive it and names
`monitor_start` as the remedy, and `monitor_start` then refuses too, because
the retained inactive row still occupies the slot. Mined from
`kirodotdev/KiroCrew` PR #8515, base `ba83f33a`.

## Skills Tested

- Threading a new opt-in parameter (`replace_stopped`) correctly through 4
  call layers (`add`/`add_monitor` down to the locked, unserialized body)
  without widening the refusal for the caller that must NOT get it.
- Applying one shared classification correctly from two different policy
  contexts: dashboard REST creates keep the old any-record refusal, while
  session-directive re-arms narrow it to active-only, and both must call the
  SAME underlying predicate rather than diverging logic that could drift.
- Correctly sorting many stop reasons and monitor outcomes into two buckets
  (system-imposed, re-armable, versus consumer-recorded, retained as
  evidence) rather than a single boolean toggle; getting the bucket wrong in
  either direction either re-creates the deadlock or causes silent data loss
  of a stopped record a consumer still needs to read.
- Not breaking two independent guards that must still fire regardless of
  which caller asks: a future-gateway-version record (this version cannot
  safely interpret or discard it) and a terminal record still awaiting
  completion evidence for an in-flight wake (replacing it would orphan the
  correlation).

## Environment

- Base image: `python:3.12-bookworm`
- Repository sealed at `base_commit`, git remote severed
- Backend only: `KIROCREW_SKIP_FRONTEND=1 pip install --prefer-binary -e ".[dev]"` in a
  venv at `/app/.venv`, no npm/vite build
- Resources: 2 CPUs, 4096 MB, 10240 MB storage
- Internet disabled during the agent phase
- Working directory: `/app`

## Difficulty

DROPPED, too easy. Final result after fully correcting two rounds of unfair
grading gates (see PROVENANCE.json for the full derivation): 6 real Harbor
attempts against GPT 5.6, F2P-remaining 0, 1, 2, 1, 0, 1 out of 10, all under
the project's 50% failure threshold. Two confirmed real defects survived
below that threshold in some attempts (a quarantined-record replacement bug
in 3 of 6, an unrelated AttributeError referencing a nonexistent enum value
in 1 of 6) -- legitimate partial-credit gaps, but not sufficient under the
current binary F2P-count contract to fail an attempt. A v2 with explicit
semantic F2P gates (e.g. a dedicated "preservation and safety" bucket where
any data-loss case fails the whole bucket) could meaningfully grade this
distinction, but that needs a new test design evaluated on fresh cohorts,
not a reweighting of already-observed responses.

This is candidate 5,
picked deliberately after four single-PR-shaped candidates
(`docker/docker-agent` #4155, `kirodotdev/KiroCrew` #9734, #9825, #9752) were
all solved by GPT 5.6 on pass@1, per the guideline's own push toward bugs
with real cross-cutting state rather than another self-contained fix. This
candidate is "cross-cutting state" in the shared-multi-entry-point sense
(two call paths through one classification predicate that must apply
different policies without drifting into either data loss or a re-created
deadlock), not a literal thread race. A first pick for this slot,
`kirodotdev/KiroCrew` #9662 (a genuine event-loop/SQLite race with a
deterministic, non-timing-dependent guard), was claimed then dropped for
scope: its diff spans roughly 24 dashboard API endpoints, well past the 2-6
file budget this delivery works under. See `research/CLAIMS.md` for both
entries.

## Solution

`solution/solve.sh` applies `solution/patch.diff` (fetched verbatim via
`gh pr diff`, not retyped) to `src/kiro_crew/autonudge.py`,
`src/kiro_crew/autonudge_authz.py`,
`src/kiro_crew/dashboard/session_directive_apply.py`,
`src/kiro_crew/mcp_tools/control.py`, and
`docs/system-specs/modules/learn-cron-dashboard.md`. The test-file portion of
the PR's own diff is intentionally excluded from the patch; the verifier
installs the graded test file separately (see Verification).

## Verification

`tests/test_autonudge.py` is the PR's own post-fix version of a file that
already existed at `base_commit` (194 tests total; the PR adds 10 new test
functions to a large existing file, does not add a new file). The verifier
copies it over whatever the agent leaves rather than patching, since a patch
can conflict with an agent's edit and then fail to apply. Graded: 10
FAIL_TO_PASS (measured, not guessed: at base_commit every one of the 10 new
tests fails with a `TypeError` because the `replace_stopped` parameter does
not exist yet, not merely a wrong assertion; passing at gold), 194 tests
collected at both base and gold (floor 194, no margin since collection is
fully deterministic here), 0 PASS_TO_PASS regressions tolerated. Two new
tests that verify the OLD dashboard-create behavior is unchanged
(`test_dashboard_create_only_add_preserves_a_stopped_row`,
`test_dashboard_create_only_add_monitor_preserves_a_terminal_record`) already
pass at base, confirmed PASS_TO_PASS by measurement, not assumed from reading
the diff. See `F2P.json` for the full derivation. All tests are
asyncio-mocked service-layer calls with no sleep-based or wall-clock timing
dependence, unlike `kirodotdev/KiroCrew` #9711, rejected earlier in this
delivery for exactly that flakiness risk.

## Relevant experience

Anyone who has fixed a create-only guard by widening a single boolean will
recognize the trap here: a refusal check with two callers is really two
different contracts wearing one function, and a fix that satisfies the
caller in the bug report while forgetting the other caller's contract either
reopens the original deadlock for someone else or, worse, silently discards
a retained record another part of the system depends on to distinguish
deliberate completion from a crash.
