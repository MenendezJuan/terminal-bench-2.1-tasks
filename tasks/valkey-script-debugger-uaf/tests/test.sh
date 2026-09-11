#!/bin/bash
# Verifier: grade the agent's working tree in place.
#
# Builds twice (normal jemalloc, then AddressSanitizer) and requires each
# bug's regression test to pass cleanly in BOTH builds. A normal build can
# hide either bug: a use-after-free into freed-but-still-mapped memory
# rarely faults, and a double-free frequently succeeds silently depending on
# allocator internals. THE REWARD IS NEVER THE EXIT CODE: this script parses
# the TCL test runner's own [ok]/[err]/[exception] lines.
set -uo pipefail

OUT=/logs/verifier
mkdir -p "$OUT"
echo 0 > "$OUT/reward.txt"

infra_fail() { echo "infra: $1" > "$OUT/error.txt"; exit 2; }
fail() { echo "$1" > "$OUT/error.txt"; echo 0 > "$OUT/reward.txt"; exit 0; }

cd /app || infra_fail "no /app tree"

git diff > "$OUT/model.patch" 2>/dev/null || true
[ -f /tests/scripting-debugger-uaf.tcl ] || infra_fail "graded test file was not uploaded"
cp /tests/scripting-debugger-uaf.tcl tests/unit/scripting-debugger-uaf.tcl || infra_fail "cannot stage graded test"

strip() { sed -r 's/\x1b\[[0-9;]*m//g'; }

build_and_run() {
  local label="$1"; shift
  echo "== build [$label]: make $*"
  if ! make -j"${MAKE_JOBS:-4}" "$@" > "$OUT/build.$label.log" 2>&1; then
    fail "agent build failed [$label], see build.$label.log"
  fi
  [ -x src/valkey-server ] || infra_fail "no server binary after build [$label]"
  echo "== F2P [$label]: unit/scripting-debugger-uaf"
  ./runtest --single unit/scripting-debugger-uaf --clients 1 --timeout 600 > "$OUT/f2p.$label.log" 2>&1 || true
}

make distclean > /dev/null 2>&1 || true
build_and_run normal MALLOC=jemalloc
echo "== P2P [normal]: existing scripting regression suite"
./runtest --single unit/scripting --clients 4 --timeout 900 > "$OUT/p2p.log" 2>&1 || true

make distclean > /dev/null 2>&1 || true
build_and_run asan SANITIZER=address MALLOC=libc

okcount() { strip < "$1" | grep -cE "^\[ok\]: .*$2"; }
errcount() { strip < "$1" | grep -cE "^\[(err|exception)\]: .*$2"; }

bug_passed() {
  local pat="$1"
  local on oe an ae
  on=$(okcount "$OUT/f2p.normal.log" "$pat"); oe=$(errcount "$OUT/f2p.normal.log" "$pat")
  an=$(okcount "$OUT/f2p.asan.log" "$pat");   ae=$(errcount "$OUT/f2p.asan.log" "$pat")
  [ "$on" -eq 1 ] && [ "$oe" -eq 0 ] && [ "$an" -eq 1 ] && [ "$ae" -eq 0 ]
}

BUGS="uaf-stale-lua-state:survives SCRIPT FLUSH ASYNC that recreates the Lua state
double-free-print:print does not use-after-free the logged value"

F2P_TOTAL=2
f2p_ok=0
bug_status=""
while IFS=: read -r name pat; do
  [ -z "$name" ] && continue
  if bug_passed "$pat"; then
    f2p_ok=$((f2p_ok + 1)); bug_status="$bug_status  [pass] $name"$'\n'
  else
    bug_status="$bug_status  [FAIL] $name"$'\n'
  fi
done <<< "$BUGS"
f2p_remaining=$((F2P_TOTAL - f2p_ok))

p2p_ok=$(strip < "$OUT/p2p.log" | grep -c '^\[ok\]')
p2p_err=$(strip < "$OUT/p2p.log" | grep -cE '^\[(err|exception)\]')
if ! strip < "$OUT/p2p.log" | grep -q 'All tests passed without errors'; then
  [ "$p2p_err" -gt 0 ] || p2p_err=1
fi

{
  echo "F2P: $f2p_ok of $F2P_TOTAL bugs fixed (each must pass in both builds)"
  printf '%s' "$bug_status"
  echo "P2P (scripting suite, normal build): $p2p_ok ok, $p2p_err err/exception"
} > "$OUT/summary.txt"
printf '{"f2p_total":%s,"f2p_remaining":%s,"p2p_ok":%s,"p2p_err":%s}\n' \
  "$F2P_TOTAL" "$f2p_remaining" "$p2p_ok" "$p2p_err" > "$OUT/summary-graded.json"

[ "$p2p_err" -gt 0 ] && fail "PASS_TO_PASS regression(s) in the scripting suite, see p2p.log"
[ $((f2p_remaining * 2)) -ge "$F2P_TOTAL" ] && fail "$f2p_remaining of $F2P_TOTAL FAIL_TO_PASS bug(s) remain (>=50%), see summary.txt"

echo 1 > "$OUT/reward.txt"
exit 0
