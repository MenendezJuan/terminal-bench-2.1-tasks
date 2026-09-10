#!/bin/bash
set -uo pipefail
export PATH="/usr/local/go/bin:$PATH"
cd /app
mkdir -p /logs/verifier
OUT=/logs/verifier

fail() {
  echo "$1" > "$OUT/error.txt"
  echo 0 > "$OUT/reward.txt"
  exit 0
}

BASE_COMMIT=1650e9977af21a07974a5bc406dc7ec20c4c0809
git status --porcelain -- pkg/model/provider/openai pkg/tools > "$OUT/agent-test-edits.log" 2>&1 || true
git diff "$BASE_COMMIT" -- . > "$OUT/model.patch" 2>/dev/null || true

# Restore every tracked native test in the graded packages before installing
# task-owned tests. Production edits remain in place; test tampering cannot
# erase a regression or manufacture a pass.
git clean -f -- 'pkg/model/provider/openai/*_test.go' 'pkg/tools/*_test.go' >/dev/null || \
  fail "could not remove untracked package tests"
git ls-files -z 'pkg/model/provider/openai/*_test.go' 'pkg/tools/*_test.go' | \
  xargs -0 -r git checkout "$BASE_COMMIT" -- || fail "could not restore native package tests from base"

[ -f /tests/openai_strict_schema_task_test.go ] || fail "OpenAI graded test file was not uploaded"
[ -f /tests/tools_strict_schema_task_test.go ] || fail "tools graded test file was not uploaded"
cp /tests/openai_strict_schema_task_test.go pkg/model/provider/openai/task_strict_schema_test.go || fail "could not install OpenAI graded tests"
cp /tests/tools_strict_schema_task_test.go pkg/tools/task_strict_schema_test.go || fail "could not install tools graded tests"

go test -json -count=1 ./pkg/model/provider/openai ./pkg/tools > "$OUT/go-test.jsonl" 2> "$OUT/go-test.stderr"
RC=$?

TOTAL=$(jq -r 'select((.Action == "pass" or .Action == "fail") and .Test != null) | .Package + "::" + .Test' "$OUT/go-test.jsonl" | sort -u | wc -l | tr -d ' ')
PACKAGES=$(jq -r 'select((.Action == "pass" or .Action == "fail") and .Test == null) | .Package' "$OUT/go-test.jsonl" | sort -u | wc -l | tr -d ' ')
# Margin of 3 below the 398 measured at base/gold (astra-reviewer finding,
# 2026-09-10): a zero-margin floor makes one flaky/skipped test read
# identically to a broken environment. 395 still catches real under-collection
# (a missing package, a renamed test) while tolerating incidental flake.
FLOOR=395

[ "$TOTAL" -lt "$FLOOR" ] && fail "collected $TOTAL tests, below the floor of $FLOOR"
[ "$PACKAGES" -lt 2 ] && fail "fewer than two graded packages reported a terminal result"

MISSING=""
while IFS= read -r name; do
  jq -s -e --arg name "$name" 'any(.[]; .Test == $name)' "$OUT/go-test.jsonl" >/dev/null || MISSING="$MISSING $name"
done <<'NAMES'
TestTaskOpenAIRequiredStrictSchemaBehavior
TestTaskConversionTerminatesForSelfReference
TestTaskStrictCompatibilityKeepsSupportedAnyOf
TestTaskConversionPreservesOrdinarySchemas
TestTaskSchemaToMapLeavesReferencesUntouched
NAMES
[ -n "$MISSING" ] && fail "graded tests missing from report:$MISSING"

cat > "$OUT/f2p-names.txt" <<'F2P'
TestTaskOpenAIRequiredStrictSchemaBehavior
TestTaskSchemaToMapLeavesReferencesUntouched
F2P

jq -r 'select(.Action == "fail" and .Test != null) | .Test' "$OUT/go-test.jsonl" | sort -u > "$OUT/failed-tests.txt"
F2P_REMAINING=0
grep -Fxq 'TestTaskOpenAIRequiredStrictSchemaBehavior' "$OUT/failed-tests.txt" && F2P_REMAINING=$((F2P_REMAINING + 1))
grep -Fxq 'TestTaskSchemaToMapLeavesReferencesUntouched' "$OUT/failed-tests.txt" && F2P_REMAINING=$((F2P_REMAINING + 1))
P2P_FAILURES=0
while IFS= read -r name; do
  case "$name" in
    TestTaskOpenAIRequiredStrictSchemaBehavior|TestTaskOpenAIRequiredStrictSchemaBehavior/*|TestTaskSchemaToMapLeavesReferencesUntouched|TestTaskSchemaToMapLeavesReferencesUntouched/*) ;;
    *) P2P_FAILURES=$((P2P_FAILURES + 1)) ;;
  esac
done < "$OUT/failed-tests.txt"
F2P_TOTAL=2

printf '{"tests":%s,"packages":%s,"floor":%s,"exit_code":%s,"f2p_total":%s,"f2p_remaining":%s,"p2p_failures":%s}\n' \
  "$TOTAL" "$PACKAGES" "$FLOOR" "$RC" "$F2P_TOTAL" "$F2P_REMAINING" "$P2P_FAILURES" > "$OUT/summary.json"

[ "$P2P_FAILURES" -gt 0 ] && fail "$P2P_FAILURES PASS_TO_PASS regression(s)"
# Both top-level requirements are essential. With two assertions, leaving one
# unresolved is exactly 50 percent and therefore fails the private contract.
[ "$F2P_REMAINING" -gt 0 ] && fail "$F2P_REMAINING of $F2P_TOTAL FAIL_TO_PASS assertions remain"
[ "$RC" -ne 0 ] && fail "go test exited with code $RC without a classified test failure"

echo 1 > "$OUT/reward.txt"
exit 0
