# CI Ratchet Dirty-Tree Diff Endpoint

## Overview

`scripts/ratchet_scope.py` in `kirodotdev/KiroCrew` computes the set of lines a
change added, and several CI gates use that set together with a scan of the
current working tree to decide what is new. The three-dot scope label diffed
to HEAD instead of the working tree, so on a dirty tree the two data sources
described different states of the same file: a pre-existing line, shifted by
an uncommitted edit onto a line number the committed diff happened to add,
read as a false violation. Mined from `kirodotdev/KiroCrew` PR #9734, base
`faf30c18`.

## Skills Tested

- Reading two related functions in the same module (`added_lines` and its
  correct per-path sibling `added_lines_at`) to find which one has the bug
  by comparing their diff endpoints, not their line count.
- Distinguishing "the diff endpoint is wrong" from "the violation scanner is
  wrong" when both operate on the same reported line number.
- Preserving three-dot semantics (merge-base, not base tip) while changing
  the other endpoint from HEAD to the working tree.
- Not touching the two merge-shape labels, which are CI-only, clean-tree
  paths that must keep their existing committed endpoints.

## Environment

- Base image: `python:3.12-bookworm`
- Repository sealed at `base_commit`, git remote severed
- Backend only: `KIROCREW_SKIP_FRONTEND=1 pip install --prefer-binary -e ".[dev]"` in a
  venv at `/app/.venv`, no npm/vite build
- Resources: 2 CPUs, 4096 MB, 10240 MB storage
- Internet disabled during the agent phase
- Working directory: `/app`

## Difficulty

Estimated hard until calibration runs are complete. The visible fix looks
like "diff to the working tree instead of HEAD," but a diff that also moves
off the merge base breaks three-dot semantics on the CI-merge-ref shape (a
later commit on the base branch would count as this change's own addition).
A correct fix must keep the merge-base endpoint while only swapping HEAD for
the working tree, and must leave the two merge-shape labels (already
correct, already working-tree-based in their own way) untouched.

## Solution

`solution/solve.sh` applies the merged fix byte for byte to
`scripts/ratchet_scope.py`: the three-dot branch now resolves
`merge-base(base, HEAD)` and diffs from there to the working tree, instead of
running `git diff --unified=0 <scope_label>` (which stopped at HEAD).

## Verification

`tests/test_ratchet_scope.py` and `tests/test_check_comment_history.py` are
the PR's own post-fix versions of two files that already existed at
`base_commit` (the PR modifies them, does not add new ones). The verifier
copies them over whatever the agent leaves rather than patching, since a
patch can conflict with an agent's edit and then fail to apply. Graded:
4 FAIL_TO_PASS (measured, not guessed: failing at base, passing at gold),
81 tests collected at both base and gold (floor 78, margin 3), 0
PASS_TO_PASS regressions tolerated.

## Relevant experience

Anyone who has debugged a CI check that is green in CI and red locally (or
vice versa) on the identical code will recognize the shape immediately: two
computations that are supposed to describe the same thing, silently reading
two different snapshots of it. Transferable beyond git tooling to anything
comparing a live/dirty state against a diff computed from committed history.
