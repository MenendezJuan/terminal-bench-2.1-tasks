#!/bin/bash
# Verifier: grade the agent's working tree in place.
#
# THE REWARD IS NEVER THE EXIT CODE. Maven exits non-zero on any test
# failure. Parse the surefire XML report, assert a floor, and assert each
# graded test method by name.
set -uo pipefail
cd /app
mkdir -p /logs/verifier
OUT=/logs/verifier

fail() {
  echo "$1" > "$OUT/error.txt"
  echo 0 > "$OUT/reward.txt"
  exit 0
}

BASE_COMMIT=1f87f7c48238a5adbaa278a575eb215bab25769d
DEST=src/test/java/io/github/hectorvent/floci/services/kinesis/KinesisConcurrencyBehaviorTest.java

# Capture what the agent wrote BEFORE anything is restored, so a tampered
# suite is recorded rather than silently erased.
git status --porcelain -- "$DEST" > "$OUT/agent-test-edits.log" 2>&1 || true
git diff "$BASE_COMMIT" -- . ":(exclude)$DEST" > "$OUT/model.patch" 2>/dev/null || true

[ -f /tests/KinesisConcurrencyBehaviorTest.java ] || fail "graded test file was not uploaded: KinesisConcurrencyBehaviorTest.java"

# The graded file is COPIED into place, not patched, so an agent edit to
# this exact path cannot conflict with installing it.
mkdir -p "$(dirname "$DEST")"
cp /tests/KinesisConcurrencyBehaviorTest.java "$DEST" || fail "could not install graded test file: $DEST"

rm -rf target/surefire-reports
timeout 600 mvn -q -B -o -Dtest=KinesisConcurrencyBehaviorTest -DfailIfNoTests=true test \
  > "$OUT/mvn-stdout.txt" 2>&1
RC=$?

REPORT="target/surefire-reports/TEST-io.github.hectorvent.floci.services.kinesis.KinesisConcurrencyBehaviorTest.xml"
[ -f "$REPORT" ] || fail "surefire produced no report for KinesisConcurrencyBehaviorTest (build/compile likely failed): see mvn-stdout.txt"
cp "$REPORT" "$OUT/junit.xml"

# Two semantic gates, each a single @Test method that internally runs
# several sub-checks and fails if ANY of them fails. This grouping was
# fixed BEFORE any model was run against this task (see PROVENANCE.json):
# durability/order and lifecycle/topology are the two natural user-facing
# contracts, and a fix that satisfies one invariant in a contract while
# leaving a sibling invariant broken (e.g. locking append but not delete)
# must fail that whole gate rather than surviving as one failing leaf out
# of many. Floor is 2 collected test methods, both required.
FLOOR=2

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
                f.write(f'{case.get("name")}\n')
PYEOF

F2P_NAMES="durabilityAndOrderGate
lifecycleAndTopologyGate"

F2P_REMAINING=0
while IFS= read -r name; do
  grep -Fxq "$name" "$OUT/failed-tests.txt" && F2P_REMAINING=$((F2P_REMAINING + 1))
done <<< "$F2P_NAMES"
F2P_TOTAL=2

P2P_FAILURES=0
while IFS= read -r name; do
  [ -z "$name" ] && continue
  echo "$F2P_NAMES" | grep -Fxq "$name" || P2P_FAILURES=$((P2P_FAILURES + 1))
done < "$OUT/failed-tests.txt"

printf '{"tests":%s,"floor":%s,"exit_code":%s,"f2p_total":%s,"f2p_remaining":%s,"p2p_failures":%s}\n' \
  "$TOTAL" "$FLOOR" "$RC" "$F2P_TOTAL" "$F2P_REMAINING" "$P2P_FAILURES" > "$OUT/summary.json"

[ "$P2P_FAILURES" -gt 0 ] && fail "$P2P_FAILURES PASS_TO_PASS regression(s), see failed-tests.txt"
# Private contract: fails if AT LEAST 50%% of FAIL_TO_PASS still fail. With
# only 2 gates, a single gate failing (1 of 2 = 50%) correctly fails the
# whole attempt -- verified against a hand-written partial-repair mutation
# before any model was run; see PROVENANCE.json.
[ $((F2P_REMAINING * 2)) -ge "$F2P_TOTAL" ] && fail "$F2P_REMAINING of $F2P_TOTAL FAIL_TO_PASS gates remain (>=50%)"

echo 1 > "$OUT/reward.txt"
exit 0
