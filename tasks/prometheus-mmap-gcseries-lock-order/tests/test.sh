#!/bin/bash
# Verifier: grade the agent's working tree in place.
#
# THE REWARD IS NEVER THE EXIT CODE. go test exits non-zero on any test
# failure OR a compile error in the package. At base_commit the graded test
# file calls mmapHeadChunksInStripe with a second argument that does not
# exist yet, so an unimplemented fix means the tsdb package fails to
# compile at all, taking every test in the package down with it. That is
# graded as every target test failing, via the JSON event stream, not via
# the exit code.
set -uo pipefail
cd /app
mkdir -p /logs/verifier
OUT=/logs/verifier

fail() {
  echo "$1" > "$OUT/error.txt"
  echo 0 > "$OUT/reward.txt"
  exit 0
}

BASE_COMMIT=d71c960302501ed81f908f546577b2c3570cc8f1
DEST=tsdb/head_test.go

# Capture what the agent wrote BEFORE anything is restored, so a tampered
# suite is recorded rather than silently erased.
git status --porcelain -- "$DEST" > "$OUT/agent-test-edits.log" 2>&1 || true
git diff "$BASE_COMMIT" -- . ":(exclude)$DEST" > "$OUT/model.patch" 2>/dev/null || true

[ -f /tests/head_test.go ] || fail "graded test file was not uploaded: head_test.go"

# The graded file is COPIED over whatever the agent left, not patched, so
# an agent edit to it cannot conflict with installing it.
cp /tests/head_test.go "$DEST" || fail "could not install graded test file: $DEST"

rm -f "$OUT/go-test.json"
timeout 600 go test ./tsdb/... -run 'TestHead_mmapHeadChunks' -v -json > "$OUT/go-test.json" 2> "$OUT/go-test-stderr.txt"
RC=$?

[ -s "$OUT/go-test.json" ] || fail "go test produced no JSON output at all: see go-test-stderr.txt"

python3 - "$OUT/go-test.json" "$OUT/summary.json" "$OUT/summary-all.json" <<'PYEOF'
import json
import sys

in_path, top_out_path, all_out_path = sys.argv[1], sys.argv[2], sys.argv[3]
top_results = {}
all_results = {}
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
        if not test or action not in ("pass", "fail"):
            continue
        all_results[test] = action
        if "/" not in test:
            top_results[test] = action

with open(top_out_path, "w") as f:
    json.dump(top_results, f)
with open(all_out_path, "w") as f:
    json.dump(all_results, f)
PYEOF

TOTAL=$(python3 -c "import json; print(len(json.load(open('$OUT/summary-all.json'))))")
FLOOR=3
[ "$TOTAL" -lt "$FLOOR" ] && fail "collected $TOTAL test results, below the floor of $FLOOR (a package that fails to compile never reports any)"

# Both graded top-level subtests of TestHead_mmapHeadChunks are scored at
# leaf granularity (they are themselves top-level t.Run subtests of the
# larger TestHead_mmapHeadChunks, with no further nesting), one for each of
# the two independent invariants the fix must satisfy.
F2P_NAMES="TestHead_mmapHeadChunks/mmapHeadChunksInStripe_releases_the_stripe_lock_before_locking_a_series
TestHead_mmapHeadChunks/gcSeries_clears_headChunks_so_a_stale_mmap_is_a_no-op"
P2P_NAMES="TestHead_mmapHeadChunks/ooo_does_not_inflate_count"

F2P_REMAINING=$(python3 -c "
import json
r = json.load(open('$OUT/summary-all.json'))
names = '''$F2P_NAMES'''.split()
print(sum(1 for n in names if r.get(n) != 'pass'))
")
F2P_TOTAL=$(echo "$F2P_NAMES" | wc -l)

P2P_FAILURES=$(python3 -c "
import json
r = json.load(open('$OUT/summary-all.json'))
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
