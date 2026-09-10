# Kinesis Concurrent Append Race, Two-Gate Concurrency Fix

## Overview

`floci-io/floci` (a local AWS emulator) loses roughly 1-3% of DynamoDB CDC
records forwarded to Kinesis under concurrent `PutItem`, because
`KinesisShard`'s record log was a plain, unsynchronized `ArrayList`. Two
related races compound the problem: a stream deleted while a producer is
mid-write can be resurrected, and a shard split can expose a half-published
topology (or throw) to a lock-free reader. Mined from `floci-io/floci` PR
#3000, base `1f87f7c4`.

## Skills Tested

- Diagnosing and fixing real concurrent data loss under load, not from a
  code-review reading but from an actual failing concurrent test.
- Correctly scoping a per-resource critical section: serializing shard
  selection, sequence allocation, append, and persistence together, and
  extending the SAME critical section to delete and every metadata write
  on that stream, not just to appends.
- Making a shared, mutated collection (a stream's shard list) safe for a
  lock-free reader concurrent with a structural mutation (a split), and
  publishing a multi-step change (two new child shards) atomically rather
  than as two separately-visible steps.
- Not fixing only the most visible symptom (silent write loss) while
  leaving a related invariant (safe deletion, safe resharding) broken.

## Environment

- Base image: `eclipse-temurin:25-jdk` (Java 25, Maven, Quarkus 3.39)
- Repository sealed at `base_commit`, git remote severed
- Local Maven repository (including the surefire-junit-platform test
  provider) warmed at build time so `mvn -o` works fully offline during
  the agent and verifier phases
- Resources: 4 CPUs, 8192 MB, 20480 MB storage
- Internet disabled during the agent phase
- Working directory: `/app`

## Difficulty

Estimated hard until calibration runs are complete. This is candidate 6,
mined by a collaborator (Codex) under a formal pre-spend acceptance gate
(see `research/PRE_SPEND_ACCEPTANCE_GATE.md`) written specifically to stop
an easy result from being rationalized as hard after the fact, following
five prior candidates in this delivery that were all too easy or out of
scope for GPT 5.6.

## Solution

`solution/solve.sh` applies `solution/patch.diff` (fetched verbatim via
`gh pr diff`, not retyped) to the 6 production files the real PR touches.
The PR's own test files are intentionally NOT used; see Verification.

## Verification

`tests/KinesisConcurrencyBehaviorTest.java` was authored from scratch for
this task, not copied from the PR. The PR's own tests use package-private
test seams the fix itself introduces (`putRecordAppendHook`,
`putRecordBeforeLockHook`) to deterministically win specific race windows;
copying them verbatim would require an agent's fix to expose those exact
method names to even compile, which leaks implementation shape rather than
testing behavior. Every call in this file is a stable public entry point
that exists unchanged on both `base_commit` and gold, so the file compiles
against either without modification.

Graded as 2 semantic gates rather than 4 separate leaf tests, both required
(the private ≥50%-failing threshold means 1 of 2 gates failing already
fails the attempt):

- `durabilityAndOrderGate`: no silent record loss under 24×50 concurrent
  writes, strictly increasing sequence numbers, and durability across a
  real WAL reload cycle (16×40 writes, fresh process, replay).
- `lifecycleAndTopologyGate`: a stream deleted mid-flight against 8
  concurrent producers never resurrects, across 40 independent trials; a
  reader hammering a live shard list against up to 2000 concurrent splits
  never throws and never observes a half-published pair of children,
  across 3 independent trials.

This 2-gate grouping was a test-design correction made BEFORE any model was
run: a hand-written plausible partial repair (apply the real fix, then
revert only `deleteStream`'s locking, leaving every other fix in place)
broke exactly 1 of an original 4 separate leaf tests -- 25%, under the
50% threshold, which would have scored that broken repair as a pass. Two
semantic gates make any single broken invariant cross the threshold. See
`F2P.json` for the full mutation-testing derivation.

F2P measured empirically: 2 collected at both base and gold, both gates
fail at base (a real 21-record loss out of 1200 on one run, and a real
stream resurrection on trial 0), 0 fail at gold, repeated once to rule out
flakes. No PASS_TO_PASS set beyond the 2 graded gates themselves.

## Relevant experience

Anyone who has protected a hot write path with a lock and called the
concurrency bug fixed will recognize the trap this task's mutation testing
caught in our own verifier first: the SAME resource has other mutation
paths (delete, in this case) that need the identical lock, and a partial
fix that only locks the path the bug report led with can look complete
while leaving a sibling operation just as unsafe.
