#!/bin/bash
# Verifier: grade the agent's working tree in place.
#
# THE REWARD IS NEVER THE EXIT CODE. go test exits non-zero on any test
# failure. Parse the -json event stream, assert a floor, and assert each
# graded test by name.
set -uo pipefail
cd /app
mkdir -p /logs/verifier
OUT=/logs/verifier

fail() {
  echo "$1" > "$OUT/error.txt"
  echo 0 > "$OUT/reward.txt"
  exit 0
}

BASE_COMMIT=cdf07d58fb29b69ac6c916eb027669e00e2318ad
DEST1=agent/consul/catalog_endpoint_test.go
DEST2=agent/consul/txn_endpoint_test.go

# Capture what the agent wrote BEFORE anything is restored, so a tampered
# suite is recorded rather than silently erased.
git status --porcelain -- "$DEST1" "$DEST2" > "$OUT/agent-test-edits.log" 2>&1 || true
git diff "$BASE_COMMIT" -- . ":(exclude)$DEST1" ":(exclude)$DEST2" > "$OUT/model.patch" 2>/dev/null || true

[ -f /tests/catalog_endpoint_test.go ] || fail "graded test file was not uploaded: catalog_endpoint_test.go"
[ -f /tests/txn_endpoint_test.go ] || fail "graded test file was not uploaded: txn_endpoint_test.go"

# The graded files are COPIED over whatever the agent left, not patched, so
# an agent edit to either file cannot conflict with installing them.
cp /tests/catalog_endpoint_test.go "$DEST1" || fail "could not install graded test file: $DEST1"
cp /tests/txn_endpoint_test.go "$DEST2" || fail "could not install graded test file: $DEST2"

rm -f "$OUT/go-test.json"
timeout 300 go test ./agent/consul/ \
  -run "TestCatalog_Register_NodeIDCrossNodeTakeover|TestTxn_Apply_NodeSetRejectsCrossNodeTakeoverByID" \
  -json > "$OUT/go-test.json" 2> "$OUT/go-test-stderr.txt"
RC=$?

[ -s "$OUT/go-test.json" ] || fail "go test produced no JSON output (build/compile likely failed): see go-test-stderr.txt"

# Only the two tests named in the -run pattern above can appear here; an
# unrelated test name showing up would mean the -run pattern matched more
# than intended, which the floor below also guards against.
FLOOR=2

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
        if not test or "/" in test:
            # Skip package-level events and subtests; both graded tests are
            # top-level, non-table-driven tests.
            continue
        if action in ("pass", "fail"):
            results[test] = action

with open(out_path, "w") as f:
    json.dump(results, f)
PYEOF

TOTAL=$(python3 -c "import json; print(len(json.load(open('$OUT/summary.json'))))")
[ "$TOTAL" -lt "$FLOOR" ] && fail "collected $TOTAL graded test results, below the floor of $FLOOR"

F2P_NAMES="TestCatalog_Register_NodeIDCrossNodeTakeover"
P2P_NAMES="TestTxn_Apply_NodeSetRejectsCrossNodeTakeoverByID"

F2P_REMAINING=$(python3 -c "
import json
r = json.load(open('$OUT/summary.json'))
names = '''$F2P_NAMES'''.split()
print(sum(1 for n in names if r.get(n) != 'pass'))
")
F2P_TOTAL=1

P2P_FAILURES=$(python3 -c "
import json
r = json.load(open('$OUT/summary.json'))
names = '''$P2P_NAMES'''.split()
print(sum(1 for n in names if r.get(n) != 'pass'))
")

printf '{"tests":%s,"floor":%s,"exit_code":%s,"f2p_total":%s,"f2p_remaining":%s,"p2p_failures":%s}\n' \
  "$TOTAL" "$FLOOR" "$RC" "$F2P_TOTAL" "$F2P_REMAINING" "$P2P_FAILURES" > "$OUT/summary-graded.json"

[ "$P2P_FAILURES" -gt 0 ] && fail "$P2P_FAILURES PASS_TO_PASS regression(s), see summary.json"
# Private contract: fails if AT LEAST 50%% of FAIL_TO_PASS still fail. With
# F2P_TOTAL=1, the single test failing already crosses the threshold.
[ $((F2P_REMAINING * 2)) -ge "$F2P_TOTAL" ] && fail "$F2P_REMAINING of $F2P_TOTAL FAIL_TO_PASS test(s) remain (>=50%)"

echo 1 > "$OUT/reward.txt"
exit 0
