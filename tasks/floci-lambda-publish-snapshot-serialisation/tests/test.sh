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

BASE_COMMIT=1b1252505b41be283c9249e27f78b2c8ff158514
DEST=src/test/java/io/github/hectorvent/floci/services/lambda/LambdaSnapshotSerialisationBehaviorTest.java

# Capture what the agent wrote BEFORE anything is restored, so a tampered
# suite is recorded rather than silently erased.
git status --porcelain -- "$DEST" > "$OUT/agent-test-edits.log" 2>&1 || true
git diff "$BASE_COMMIT" -- . ":(exclude)$DEST" > "$OUT/model.patch" 2>/dev/null || true

# The prompt forbids editing existing tests. Restore the pre-existing test
# tree so a weakened or deleted upstream test cannot buy a pass, and record
# that it happened.
git status --porcelain -- src/test > "$OUT/agent-existing-test-edits.log" 2>&1 || true
git checkout "$BASE_COMMIT" -- src/test 2>/dev/null || true

[ -f /tests/LambdaSnapshotSerialisationBehaviorTest.java ] \
  || fail "graded test file was not uploaded: LambdaSnapshotSerialisationBehaviorTest.java"

# The graded file is COPIED into place, not patched, so an agent edit to
# this exact path cannot conflict with installing it.
mkdir -p "$(dirname "$DEST")"
cp /tests/LambdaSnapshotSerialisationBehaviorTest.java "$DEST" \
  || fail "could not install graded test file: $DEST"

rm -rf target/surefire-reports
timeout 900 mvn -q -B -o -Dtest=LambdaSnapshotSerialisationBehaviorTest -DfailIfNoTests=true test \
  > "$OUT/mvn-stdout.txt" 2>&1
RC=$?

REPORT="target/surefire-reports/TEST-io.github.hectorvent.floci.services.lambda.LambdaSnapshotSerialisationBehaviorTest.xml"
[ -f "$REPORT" ] \
  || fail "surefire produced no report for LambdaSnapshotSerialisationBehaviorTest (build/compile likely failed): see mvn-stdout.txt"
cp "$REPORT" "$OUT/junit.xml"

# 2 FAIL_TO_PASS leaves + 5 PASS_TO_PASS leaves. Leaves, not containers:
# each @Test is one natural user-facing behaviour and is scored by name.
FLOOR=7

TOTAL=$(grep -oE 'tests="[0-9]+"' "$OUT/junit.xml" | head -1 | grep -oE '[0-9]+')
[ -z "$TOTAL" ] && fail "could not parse test count from junit.xml"
[ "$TOTAL" -lt "$FLOOR" ] && fail "collected $TOTAL tests, below the floor of $FLOOR"

SKIPPED=$(grep -oE 'skipped="[0-9]+"' "$OUT/junit.xml" | head -1 | grep -oE '[0-9]+')
[ -n "$SKIPPED" ] && [ "$SKIPPED" -gt 0 ] && fail "$SKIPPED graded test(s) were skipped"

python3 - "$OUT/junit.xml" "$OUT/failed-tests.txt" "$OUT/all-tests.txt" <<'PYEOF'
import sys
import xml.etree.ElementTree as ET

report_path, failed_path, all_path = sys.argv[1], sys.argv[2], sys.argv[3]
root = ET.parse(report_path).getroot()
suites = [root] if root.tag == "testsuite" else list(root)
with open(failed_path, "w") as failed, open(all_path, "w") as seen:
    for suite in suites:
        for case in suite.findall("testcase"):
            name = case.get("name")
            seen.write(f"{name}\n")
            if case.find("failure") is not None or case.find("error") is not None:
                failed.write(f"{name}\n")
PYEOF

F2P_NAMES="updateFunctionCodeSerialisesAgainstTheFunctionsConcurrencyLock
updateFunctionConfigurationSerialisesAgainstTheFunctionsConcurrencyLock"

P2P_NAMES="updateFunctionConfigurationRejectsScalarStructureMembersOnAnUnknownFunction
updateFunctionConfigurationStillReportsNotFoundForAWellFormedRequest
publishVersionStillSucceedsAfterAConfigurationUpdate
updateFunctionCodeStillSucceedsOnAnExistingFunction
distinctFunctionsDoNotShareAConcurrencyLock"

# Every graded identity must be present exactly once.
while IFS= read -r name; do
  [ -z "$name" ] && continue
  COUNT=$(grep -Fxc "$name" "$OUT/all-tests.txt" || true)
  [ "$COUNT" = "1" ] || fail "graded test '$name' was collected $COUNT time(s), expected exactly 1"
done <<< "$F2P_NAMES
$P2P_NAMES"

F2P_REMAINING=0
while IFS= read -r name; do
  [ -z "$name" ] && continue
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
# Private contract: fails if AT LEAST 50% of FAIL_TO_PASS still fail. With
# two leaves, locking only one of the two updaters leaves 1 of 2 = 50% and
# correctly fails the whole attempt. This grouping is fixed before any model
# run; see PROVENANCE.json.
[ $((F2P_REMAINING * 2)) -ge "$F2P_TOTAL" ] && fail "$F2P_REMAINING of $F2P_TOTAL FAIL_TO_PASS tests remain (>=50%)"

echo 1 > "$OUT/reward.txt"
exit 0
