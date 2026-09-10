#!/bin/bash
# Verifier: grade the agent's working tree in place.
#
# THE REWARD IS NEVER THE EXIT CODE. pytest exits non-zero on collection
# errors too, and a renamed/skipped test can still leave exit 0. Parse the
# JUnit XML report, assert a floor, and assert each graded test by name.
set -uo pipefail
export PATH="/app/.venv/bin:$PATH"
cd /app
mkdir -p /logs/verifier
OUT=/logs/verifier

fail() {
  echo "$1" > "$OUT/error.txt"
  echo 0 > "$OUT/reward.txt"
  exit 0
}

BASE_COMMIT=faf30c18e749613ce704a0fd28c692c0b1c96e10
DEST_A=test/test_ratchet_scope.py
DEST_B=test/test_check_comment_history.py

# Capture what the agent wrote BEFORE anything is restored, so a tampered
# suite is recorded rather than silently erased.
git status --porcelain -- "$DEST_A" "$DEST_B" > "$OUT/agent-test-edits.log" 2>&1 || true
git diff "$BASE_COMMIT" -- . ":(exclude)$DEST_A" ":(exclude)$DEST_B" > "$OUT/model.patch" 2>/dev/null || true

[ -f /tests/test_ratchet_scope.py ] || fail "graded test file was not uploaded: test_ratchet_scope.py"
[ -f /tests/test_check_comment_history.py ] || fail "graded test file was not uploaded: test_check_comment_history.py"

# Graded files are COPIED OVER whatever the agent left, not patched onto it.
# A diff can conflict with an agent edit and then fail to apply, which grades
# the environment instead of the work; an overwrite cannot.
cp /tests/test_ratchet_scope.py "$DEST_A" || fail "could not install graded test file: $DEST_A"
cp /tests/test_check_comment_history.py "$DEST_B" || fail "could not install graded test file: $DEST_B"

rm -f "$OUT/junit.xml"
pytest -p no:cacheprovider -q "$DEST_A" "$DEST_B" --junitxml="$OUT/junit.xml" > "$OUT/pytest-stdout.txt" 2>&1
RC=$?

[ -f "$OUT/junit.xml" ] || fail "pytest produced no JUnit report (collection likely failed): see pytest-stdout.txt"

# Measured 2026-09-10 at base_commit with these graded files installed:
# 81 collected, 4 failed (the FAIL_TO_PASS set below), 77 passed. At the
# oracle: 81 collected, 0 failed. See PROVENANCE.json / F2P.json.
FLOOR=78

TOTAL=$(grep -oE 'tests="[0-9]+"' "$OUT/junit.xml" | head -1 | grep -oE '[0-9]+')
[ -z "$TOTAL" ] && fail "could not parse test count from junit.xml"
[ "$TOTAL" -lt "$FLOOR" ] && fail "collected $TOTAL tests, below the floor of $FLOOR"

# Failing test names, as classname::name pairs pulled straight from the XML
# (one <testcase> per test; failed ones contain <failure> or <error>).
python3 - "$OUT/junit.xml" "$OUT/failed-tests.txt" <<'PYEOF'
import sys
import xml.etree.ElementTree as ET

report_path, out_path = sys.argv[1], sys.argv[2]
root = ET.parse(report_path).getroot()
suites = [root] if root.tag == "testsuite" else list(root)
with open(out_path, "w") as f:
    for suite in suites:
        for case in suite.findall("testcase"):
            if case.find("failure") is not None or case.find("error") is not None:
                f.write(f'{case.get("classname")}::{case.get("name")}\n')
PYEOF

F2P_NAMES="test.test_ratchet_scope.TestDirtyTree::test_uncommitted_edits_are_in_the_added_set
test.test_ratchet_scope.TestDirtyTree::test_the_base_is_the_merge_base_not_the_base_tip
test.test_ratchet_scope.TestDirtyTree::test_a_shifted_preexisting_line_is_not_counted_as_added
test.test_check_comment_history.TestDirtyTreeScope::test_a_shifted_baselined_marker_is_not_flagged"

MISSING=""
while IFS= read -r name; do
  grep -Fxq "$name" "$OUT/failed-tests.txt" 2>/dev/null || true
done <<< "$F2P_NAMES"

F2P_REMAINING=0
while IFS= read -r name; do
  grep -Fxq "$name" "$OUT/failed-tests.txt" && F2P_REMAINING=$((F2P_REMAINING + 1))
done <<< "$F2P_NAMES"
F2P_TOTAL=4

P2P_FAILURES=0
while IFS= read -r name; do
  [ -z "$name" ] && continue
  echo "$F2P_NAMES" | grep -Fxq "$name" || P2P_FAILURES=$((P2P_FAILURES + 1))
done < "$OUT/failed-tests.txt"

printf '{"tests":%s,"floor":%s,"exit_code":%s,"f2p_total":%s,"f2p_remaining":%s,"p2p_failures":%s}\n' \
  "$TOTAL" "$FLOOR" "$RC" "$F2P_TOTAL" "$F2P_REMAINING" "$P2P_FAILURES" > "$OUT/summary.json"

[ "$P2P_FAILURES" -gt 0 ] && fail "$P2P_FAILURES PASS_TO_PASS regression(s), see failed-tests.txt"
[ "$F2P_REMAINING" -gt 0 ] && fail "$F2P_REMAINING of $F2P_TOTAL FAIL_TO_PASS assertions remain"

echo 1 > "$OUT/reward.txt"
exit 0
