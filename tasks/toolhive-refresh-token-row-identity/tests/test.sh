#!/bin/bash
# Verifier: grade the agent's working tree in place.
#
# THE REWARD IS NEVER THE EXIT CODE. go test exits non-zero on any test
# failure OR a compile error in the package, which is expected here: an
# unimplemented fix means the graded test files (which reference symbols
# the fix must add) fail to compile at all, taking every test in the
# package down with them. That is graded as every target test failing,
# via the JSON event stream, not via the exit code.
set -uo pipefail
cd /app
mkdir -p /logs/verifier
OUT=/logs/verifier

fail() {
  echo "$1" > "$OUT/error.txt"
  echo 0 > "$OUT/reward.txt"
  exit 0
}

BASE_COMMIT=72ffb454c730eb5477f40c8be973e1047a39e5ea
DEST1=pkg/authserver/refresher_test.go
DEST2=pkg/authserver/storage/types_test.go

# Capture what the agent wrote BEFORE anything is restored, so a tampered
# suite is recorded rather than silently erased.
git status --porcelain -- "$DEST1" "$DEST2" > "$OUT/agent-test-edits.log" 2>&1 || true
git diff "$BASE_COMMIT" -- . ":(exclude)$DEST1" ":(exclude)$DEST2" > "$OUT/model.patch" 2>/dev/null || true

[ -f /tests/refresher_test.go ] || fail "graded test file was not uploaded: refresher_test.go"
[ -f /tests/types_test.go ] || fail "graded test file was not uploaded: types_test.go"

# The graded files are COPIED over whatever the agent left, not patched, so
# an agent edit to either file cannot conflict with installing them.
cp /tests/refresher_test.go "$DEST1" || fail "could not install graded test file: $DEST1"
cp /tests/types_test.go "$DEST2" || fail "could not install graded test file: $DEST2"

rm -f "$OUT/go-test.json"
timeout 300 go test ./pkg/authserver/... -json > "$OUT/go-test.json" 2> "$OUT/go-test-stderr.txt"
RC=$?

[ -s "$OUT/go-test.json" ] || fail "go test produced no JSON output at all: see go-test-stderr.txt"

python3 - "$OUT/go-test.json" "$OUT/summary.json" <<'PYEOF'
import json
import sys

in_path, out_path = sys.argv[1], sys.argv[2]
results = {}
with open(in_path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        test = ev.get("Test")
        action = ev.get("Action")
        # Only top-level test results (no "/", i.e. not a subtest); a
        # top-level test is reported pass/fail only after all its subtests
        # finish, so this alone reflects the whole test's outcome.
        if not test or "/" in test:
            continue
        if action in ("pass", "fail"):
            results[test] = action

with open(out_path, "w") as f:
    json.dump(results, f)
PYEOF

TOTAL=$(python3 -c "import json; print(len(json.load(open('$OUT/summary.json'))))")
FLOOR=4
[ "$TOTAL" -lt "$FLOOR" ] && fail "collected $TOTAL top-level test results, below the floor of $FLOOR (a package that fails to compile never reports any)"

F2P_NAMES="TestUpstreamTokenRefresher_RowIdentity
TestUpstreamTokenRowIDResolution"
P2P_NAMES="TestUpstreamTokenRefresher_SingleflightDedup
TestUpstreamTokenRefresher_RefreshAndStore"

F2P_REMAINING=$(python3 -c "
import json
r = json.load(open('$OUT/summary.json'))
names = '''$F2P_NAMES'''.split()
print(sum(1 for n in names if r.get(n) != 'pass'))
")
F2P_TOTAL=2

P2P_FAILURES=$(python3 -c "
import json
r = json.load(open('$OUT/summary.json'))
names = '''$P2P_NAMES'''.split()
print(sum(1 for n in names if r.get(n) != 'pass'))
")

printf '{"tests":%s,"floor":%s,"exit_code":%s,"f2p_total":%s,"f2p_remaining":%s,"p2p_failures":%s}\n' \
  "$TOTAL" "$FLOOR" "$RC" "$F2P_TOTAL" "$F2P_REMAINING" "$P2P_FAILURES" > "$OUT/summary-graded.json"

[ "$P2P_FAILURES" -gt 0 ] && fail "$P2P_FAILURES PASS_TO_PASS regression(s), see go-test.json"
# Private contract: fails if AT LEAST 50%% of FAIL_TO_PASS still fail.
[ $((F2P_REMAINING * 2)) -ge "$F2P_TOTAL" ] && fail "$F2P_REMAINING of $F2P_TOTAL FAIL_TO_PASS test(s) remain (>=50%)"

echo 1 > "$OUT/reward.txt"
exit 0
