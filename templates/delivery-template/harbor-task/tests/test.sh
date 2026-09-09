#!/bin/bash
# TEMPLATE verifier. Grade the agent's working tree in place.
#
# THE REWARD IS NEVER THE EXIT CODE. Every runner in use here exits 0 when it
# matches no files, so a renamed path scores a FALSE 1.0. Parse the report and
# assert a floor. Zero tests plus a clean exit is a STOP, never a clean sweep.
set -uo pipefail
cd /app
mkdir -p /logs/verifier
OUT=/logs/verifier

fail() { echo "$1" > $OUT/error.txt; echo 0 > $OUT/reward.txt; exit 0; }



# Capture what the agent wrote BEFORE restoring anything, so a tampered suite is
# recorded rather than silently erased.
git status --porcelain -- <test-dir> > $OUT/agent-test-edits.log 2>&1 || true
git diff -- . ':(exclude)<test-dir>' > $OUT/model.patch 2>/dev/null || true

# TAMPER GUARD. `git apply --check` detects conflicts, not edits that survive
# alongside the patch. Restore graded tests to base, then apply the hidden patch.
for f in $GRADED; do git checkout -- "$f" 2>/dev/null || true; done
git clean -fdq -- <test-dir> 2>/dev/null || true

[ -f /tests/test_outputs.py ] || fail "graded tests were not uploaded to /tests"

<run the graded tests, writing a machine-readable report>

# Parse, then assert BEFORE writing a reward:
#   collected >= <floor>, errors == 0, every expected test file present.
<parse; on shortfall or error call fail; else echo 1 > $OUT/reward.txt>
exit 0
