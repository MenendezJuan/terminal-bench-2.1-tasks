#!/bin/bash
# Verifier: grade the agent's working tree in place.
#
# THE REWARD IS NEVER THE EXIT CODE. pytest exits non-zero on collection
# errors too. Parse the JUnit XML report, assert a floor, and assert each
# graded test by name.
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

BASE_COMMIT=ba83f33a89cd7653208833abeb5841e5d6987ce0
DEST=test/test_autonudge.py

# Capture what the agent wrote BEFORE anything is restored, so a tampered
# suite is recorded rather than silently erased.
git status --porcelain -- "$DEST" > "$OUT/agent-test-edits.log" 2>&1 || true
git diff "$BASE_COMMIT" -- . ":(exclude)$DEST" > "$OUT/model.patch" 2>/dev/null || true

[ -f /tests/test_autonudge.py ] || fail "graded test file was not uploaded: test_autonudge.py"

# The graded file is COPIED OVER whatever the agent left, not patched onto
# it. A diff can conflict with an agent's edit and then fail to apply, which
# grades the environment instead of the work; an overwrite cannot.
cp /tests/test_autonudge.py "$DEST" || fail "could not install graded test file: $DEST"

rm -f "$OUT/junit.xml"
timeout 300 pytest -p no:cacheprovider -q "$DEST" --junitxml="$OUT/junit.xml" > "$OUT/pytest-stdout.txt" 2>&1
RC=$?

[ -f "$OUT/junit.xml" ] || fail "pytest produced no JUnit report (collection likely failed or timed out): see pytest-stdout.txt"

# Measured 2026-09-10 at base_commit with the graded file installed: 194
# collected, 10 failed (the FAIL_TO_PASS set below), 184 passed. At the
# oracle: 194 collected, 0 failed. See PROVENANCE.json / F2P.json.
FLOOR=194

TOTAL=$(grep -oE 'tests="[0-9]+"' "$OUT/junit.xml" | head -1 | grep -oE '[0-9]+')
[ -z "$TOTAL" ] && fail "could not parse test count from junit.xml"
[ "$TOTAL" -lt "$FLOOR" ] && fail "collected $TOTAL tests, below the floor of $FLOOR"

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

F2P_NAMES="test.test_autonudge::test_create_only_add_replaces_an_inactive_approval_stalled_loop
test.test_autonudge::test_create_only_add_still_refuses_an_active_legacy_loop
test.test_autonudge::test_replace_stopped_never_deletes_a_future_version_monitor
test.test_autonudge::test_create_only_add_monitor_replaces_a_merged_subject_monitor
test.test_autonudge::test_replace_stopped_preserves_a_quarantined_monitor_record
test.test_autonudge::test_create_only_add_replaces_a_target_unavailable_monitor
test.test_autonudge::test_replace_stopped_preserves_a_user_stopped_monitor
test.test_autonudge::test_replace_stopped_preserves_a_research_tombstone
test.test_autonudge::test_replace_stopped_preserves_a_manual_pause
test.test_autonudge::test_create_only_add_still_refuses_a_terminal_row_with_an_inflight_wake"

F2P_REMAINING=0
while IFS= read -r name; do
  grep -Fxq "$name" "$OUT/failed-tests.txt" && F2P_REMAINING=$((F2P_REMAINING + 1))
done <<< "$F2P_NAMES"
F2P_TOTAL=10

P2P_FAILURES=0
while IFS= read -r name; do
  [ -z "$name" ] && continue
  echo "$F2P_NAMES" | grep -Fxq "$name" || P2P_FAILURES=$((P2P_FAILURES + 1))
done < "$OUT/failed-tests.txt"

printf '{"tests":%s,"floor":%s,"exit_code":%s,"f2p_total":%s,"f2p_remaining":%s,"p2p_failures":%s}\n' \
  "$TOTAL" "$FLOOR" "$RC" "$F2P_TOTAL" "$F2P_REMAINING" "$P2P_FAILURES" > "$OUT/summary.json"

[ "$P2P_FAILURES" -gt 0 ] && fail "$P2P_FAILURES PASS_TO_PASS regression(s), see failed-tests.txt"
# Private contract: fails if AT LEAST 50%% of FAIL_TO_PASS still fail (not
# "any remain" -- integer form of remaining*2 >= total avoids float math).
[ $((F2P_REMAINING * 2)) -ge "$F2P_TOTAL" ] && fail "$F2P_REMAINING of $F2P_TOTAL FAIL_TO_PASS assertions remain (>=50%)"

echo 1 > "$OUT/reward.txt"
exit 0
