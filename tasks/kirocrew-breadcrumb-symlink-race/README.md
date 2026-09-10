# Breadcrumb Symlink/FIFO Race, TOCTOU Fix

## Overview

`src/kiro_crew/config/paths.py` in `kirodotdev/KiroCrew` writes a startup
recovery-breadcrumb pointer file using path-based `write_text`/`read_text`,
which trusts whatever inode the breadcrumb path resolves to at call time. A
planted symlink at that path redirects the write onto the symlink's target;
a non-regular file (FIFO) swapped in can hang the read forever. Mined from
`kirodotdev/KiroCrew` PR #9752, base `cafe05409`.

## Skills Tested

- Closing a write-side symlink-following hole (switching to an atomic,
  rename-based write) without stopping there.
- Independently closing a read-side check-then-read race: the idempotence
  check that runs before the write has its own TOCTOU window, exploitable
  with a symlink or a FIFO, that the write-side fix alone does not touch.
- Setting file permissions on the descriptor (not the path) so a symlink
  cannot redirect a permission change either.
- Getting all three requirements (no symlink-follow, private mode, no hang
  on a non-regular file) right at once; a plausible partial fix nails one
  or two and misses the third.

## Environment

- Base image: `python:3.12-bookworm`
- Repository sealed at `base_commit`, git remote severed
- Backend only: `KIROCREW_SKIP_FRONTEND=1 pip install --prefer-binary -e ".[dev]"` in a
  venv at `/app/.venv`, no npm/vite build
- Resources: 2 CPUs, 4096 MB, 10240 MB storage
- Internet disabled during the agent phase
- Working directory: `/app`

## Difficulty

Estimated hard until calibration runs are complete. This is candidate 4 for
this delivery, picked deliberately after three prior candidates
(`docker/docker-agent` #4155, `kirodotdev/KiroCrew` #9734, `kirodotdev/KiroCrew`
#9825) were all "message with several branches" bugs a strong model solved on
pass@1 by translating the issue text mechanically. This candidate instead has
a genuine partial-credit trap: the tempting superficial fix, "switch
`write_text` to the repo's `atomic_write` helper", closes the write-side hole
and would pass the symlink and permission tests, while leaving the read-side
check-then-read race (the idempotence check that runs before the write) wide
open, which only the FIFO-hang test catches. A first pick for this slot,
`kirodotdev/KiroCrew` #9711, was claimed then dropped after reading the full
diff: its fix depends on live CPU-scheduling behavior sampled via
`/proc/<tid>/syscall`, with the PR's own tests skipping when scheduling noise
prevents a stable sample, which is not safe for a sealed verifier that has to
grade deterministically. See `research/CLAIMS.md` for both entries.

## Solution

`solution/solve.sh` applies `solution/patch.diff` (fetched verbatim via
`gh pr diff`, not retyped) to `src/kiro_crew/config/paths.py` and
`docs/system-specs/modules/config.md`. The test-file portion of the PR's own
diff is intentionally excluded from the patch; the verifier installs the
graded test file separately (see Verification).

## Verification

`tests/test_lazy_data_home_paths.py` is the PR's own post-fix version of a
file that already existed at `base_commit` (23 tests total; the PR adds a
new `TestRecoveryBreadcrumb` class, does not add a new file). The verifier
copies it over whatever the agent leaves rather than patching, since a
patch can conflict with an agent's edit and then fail to apply. Graded: 3
FAIL_TO_PASS (measured, not guessed: failing or timing out at base, passing
at gold), 23 tests collected at both base and gold (floor 23, no margin
since collection is fully deterministic here), 0 PASS_TO_PASS regressions
tolerated. Two tests that looked like plausible FAIL_TO_PASS candidates on a
first read of the diff (`test_existing_breadcrumb_that_contains_the_data_home_is_unchanged`,
`test_without_o_nofollow_the_read_is_skipped_and_write_still_lands`) turned
out to already pass at base on empirical measurement, since neither
exercises a symlink or FIFO; both are PASS_TO_PASS. See `F2P.json` for the
full derivation.

## Relevant experience

Anyone who has fixed a TOCTOU bug by reaching for the nearest "atomic"
helper will recognize the trap here: an atomic *write* only protects the
write half of the function. The read half, the idempotence check that runs
immediately before deciding whether to write at all, has its own
check-then-open gap that a completely different technique (an `O_NOFOLLOW`,
non-blocking, `S_ISREG`-gated read, not an atomic write) is needed to close.
