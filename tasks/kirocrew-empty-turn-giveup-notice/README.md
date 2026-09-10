# Empty-Turn Give-Up Notice, Cause-Aware Wording

## Overview

`src/kiro_crew/dashboard/chat_runner.py` in `kirodotdev/KiroCrew` shows a
fixed notice card when the empty-turn recovery ladder gives up, regardless
of whether the turn was productive or how much recovery budget was actually
spent. The card is read by both the user and the model (via the transcript),
so a wrong claim on a productive turn invites a redo of side effects that
already landed. Mined from `kirodotdev/KiroCrew` PR #9825, base `16034349`.

## Skills Tested

- Distinguishing three mutually exclusive outcome branches from state that
  already exists (`_empty_activity.productive`, the recovery-attempt
  counter) without changing the classification logic itself.
- Matching literal UI copy requirements precisely: each branch has words
  that must appear and words that must not, and getting two of three
  branches right is not enough (three FAIL_TO_PASS tests cover the three
  branches individually, a fourth covers a boundary case of branch three).
- Not touching the two other branches while fixing one; a plausible partial
  fix nails one or two branches and breaks or leaves wrong the others.

## Environment

- Base image: `python:3.12-bookworm`
- Repository sealed at `base_commit`, git remote severed
- Backend only: `KIROCREW_SKIP_FRONTEND=1 pip install --prefer-binary -e ".[dev]"` in a
  venv at `/app/.venv`, no npm/vite build
- Resources: 2 CPUs, 4096 MB, 10240 MB storage
- Internet disabled during the agent phase
- Working directory: `/app`

## Difficulty

Estimated hard until calibration runs are complete. Two prior candidates for
this slot (`docker/docker-agent` #4155, `kirodotdev/KiroCrew` #9734) were
both single-conceptual-fix bugs and both solved by GPT 5.6 on pass@1. This
one requires getting three mutually exclusive message branches right at
once, where a fix that nails the most obvious branch (the productive-turn
case, which the issue explains in the most detail) can still get the other
two wrong -- particularly branch three, which requires NOT naming the
specific recovery mechanism even though recovery did happen, a subtler
under-claim than the over-claim the issue leads with.

## Solution

`solution/solve.sh` applies `solution/patch.diff` (fetched verbatim via
`gh pr diff`, not retyped, to avoid a transcription error breaking `git
apply`'s context matching) to `src/kiro_crew/dashboard/chat_runner.py` and
`docs/system-specs/modules/session.md`. The test-file portion of the PR's
own diff is intentionally excluded from the patch; the verifier installs
the graded test file separately (see Verification).

## Verification

`tests/test_dashboard_chat.py` is the PR's own post-fix version of a file
that already existed at `base_commit` (779 tests; the PR modifies one
existing test and adds three new ones, does not add a new file). The
verifier copies it over whatever the agent leaves rather than patching,
since a patch can conflict with an agent's edit and then fail to apply.
Graded: 4 FAIL_TO_PASS (measured, not guessed: failing at base, passing at
gold), 779 tests collected at both base and gold (floor 776, margin 3), 0
PASS_TO_PASS regressions tolerated.

## Relevant experience

Anyone who has written a user-facing status message that has to stay
accurate across several outcome branches of the same code path will
recognize this: it is easy to fix the branch the bug report quotes and
leave the other branches wrong, especially when fixing one requires making
a claim weaker (branch three) rather than the more intuitive stronger
claim the bug report's headline case suggests.
