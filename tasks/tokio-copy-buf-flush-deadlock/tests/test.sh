#!/bin/bash
# Verifier: grade the agent's working tree in place.
#
# THE REWARD IS NEVER THE EXIT CODE. cargo test exits non-zero on any
# failure, and a hung test never lets cargo exit at all -- that is why this
# script wraps the whole run in an external timeout and checks for the
# graded test's own "ok" line in the captured output, rather than trusting
# the process exit code.
set -uo pipefail
cd /app
mkdir -p /logs/verifier
OUT=/logs/verifier

fail() {
  echo "$1" > "$OUT/error.txt"
  echo 0 > "$OUT/reward.txt"
  exit 0
}

BASE_COMMIT=dde3f869229cce400fb36bbaeffcd59ee528c332
DEST=tokio/tests/io_copy.rs

# Capture what the agent wrote BEFORE anything is restored, so a tampered
# suite is recorded rather than silently erased.
git status --porcelain -- "$DEST" > "$OUT/agent-test-edits.log" 2>&1 || true
git diff "$BASE_COMMIT" -- . ":(exclude)$DEST" > "$OUT/model.patch" 2>/dev/null || true

[ -f /tests/io_copy.rs ] || fail "graded test file was not uploaded: io_copy.rs"

# The graded file is COPIED over whatever the agent left, not patched, so
# an agent edit to this exact path cannot conflict with installing it.
cp /tests/io_copy.rs "$DEST" || fail "could not install graded test file: $DEST"

cd tokio
# 90s is generous for a debug-profile compile-and-run of one small test
# binary; a genuinely unfixed copy_buf hangs forever on proxy_buf, so this
# bound is what turns that hang into a graded failure instead of stalling
# the whole verifier job.
timeout 90 cargo test --features full,test-util --test io_copy \
  > "$OUT/cargo-test-stdout.txt" 2>&1
RC=$?
cd ..

[ -s "$OUT/cargo-test-stdout.txt" ] || fail "cargo test produced no output (build likely failed): see cargo-test-stdout.txt"

# A compile error means none of the four "test <name> ..." lines below can
# ever appear; catch it explicitly with a clearer message than a floor miss.
grep -q "^error\[" "$OUT/cargo-test-stdout.txt" && fail "cargo test reported a compile error: see cargo-test-stdout.txt"

FLOOR=4
COLLECTED=$(grep -cE "^test [a-zA-Z_0-9]+ \.\.\. " "$OUT/cargo-test-stdout.txt")
[ "$COLLECTED" -lt "$FLOOR" ] && fail "collected $COLLECTED test result lines, below the floor of $FLOOR (a hung or crashed test never prints its own line)"

F2P_NAMES="proxy_buf"
P2P_NAMES="copy
proxy
copy_is_cooperative"

F2P_REMAINING=0
while IFS= read -r name; do
  grep -qE "^test $name \.\.\. ok$" "$OUT/cargo-test-stdout.txt" || F2P_REMAINING=$((F2P_REMAINING + 1))
done <<< "$F2P_NAMES"
F2P_TOTAL=1

P2P_FAILURES=0
while IFS= read -r name; do
  grep -qE "^test $name \.\.\. ok$" "$OUT/cargo-test-stdout.txt" || P2P_FAILURES=$((P2P_FAILURES + 1))
done <<< "$P2P_NAMES"

printf '{"tests":%s,"floor":%s,"exit_code":%s,"f2p_total":%s,"f2p_remaining":%s,"p2p_failures":%s}\n' \
  "$COLLECTED" "$FLOOR" "$RC" "$F2P_TOTAL" "$F2P_REMAINING" "$P2P_FAILURES" > "$OUT/summary.json"

[ "$P2P_FAILURES" -gt 0 ] && fail "$P2P_FAILURES PASS_TO_PASS regression(s), see cargo-test-stdout.txt"
# Private contract: fails if AT LEAST 50%% of FAIL_TO_PASS still fail. With
# F2P_TOTAL=1, the single test failing (or hanging past the timeout, which
# reads identically here: its "ok" line never appears) already crosses the
# threshold.
[ $((F2P_REMAINING * 2)) -ge "$F2P_TOTAL" ] && fail "$F2P_REMAINING of $F2P_TOTAL FAIL_TO_PASS test(s) remain (>=50%)"

echo 1 > "$OUT/reward.txt"
exit 0
