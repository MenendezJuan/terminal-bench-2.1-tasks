# TSDB mmapHeadChunksInStripe / gcSeries Lock-Order Deadlock

## Overview

`prometheus/prometheus`'s TSDB head held a stripe's RLock in
`Head.mmapHeadChunksInStripe` for its entire body while also locking each
individual series inside that critical section. `stripeSeries.gcSeries`,
invoked during eviction, locks a series first and then, under some
conditions, also needs the stripe lock -- the exact inverse order. Two
real, frequently-invoked code paths, a genuine deadlock. Mined from
`prometheus/prometheus` PR #19460, base `d71c96030250`.

## Skills Tested

- Recognizing an inverted lock-order deadlock between two independently
  reasonable-looking pieces of locking code, and fixing the ordering
  without breaking either path's own correctness (no series may be
  silently skipped from mmapping, even one that becomes eligible mid-scan).
- Understanding that closing a lock-ordering hazard changes timing, not
  just removes a symptom: once the stripe lock no longer serializes
  mmap against eviction, a previously-impossible race (mmapping a
  since-evicted series) becomes possible and must be handled separately.
- Not stopping at the more visible half of the fix: a model that only
  fixes the lock ordering leaves a real orphaned-mmap-file bug on a
  genuine eviction race that was invisible before this ordering fix.
- Working correctly with Go's `sync.RWMutex`, `TryLock`, and per-stripe /
  per-series locking schemes.

## Verification

`tests/head_test.go` is the PR's own post-fix version of `tsdb/head_test.go`,
spliced in at its original location inside `TestHead_mmapHeadChunks`. At
`base_commit` the `tsdb` package fails to COMPILE, since the test calls
`mmapHeadChunksInStripe` with a second argument the base signature does not
accept -- this correctly takes the whole package down, scored as a no-op
via the verifier's collected-test floor rather than the exit code.

Graded: 2 FAIL_TO_PASS (`TestHead_mmapHeadChunks/mmapHeadChunksInStripe_releases_the_stripe_lock_before_locking_a_series`,
`TestHead_mmapHeadChunks/gcSeries_clears_headChunks_so_a_stale_mmap_is_a_no-op`),
1 PASS_TO_PASS sample (`TestHead_mmapHeadChunks/ooo_does_not_inflate_count`).
The verifier scopes the run to `go test ./tsdb/... -run TestHead_mmapHeadChunks -v -json`.
Oracle run repeated 5 times to rule out flakiness in the lock-ordering
test's timing-based safety-net wait (the actual assertion is a `TryLock`,
not timing, per the PR's own test comment); all 5 stable.

## Mutation Testing

Before any model run, two independent mutations were tested, since the PR
combines two genuinely separate invariants:

1. Real gold patch, with only the `gcSeries` `setHeadChunks(nil, 0)` line
   reverted (lock-ordering fix kept intact). Correctly fails: the
   lock-ordering subtest passes, the gcSeries subtest fails.
2. Real gold patch, with only `mmapHeadChunksInStripe` reverted to its
   base-commit body (gcSeries fix kept intact, call site still compiles).
   Correctly fails: the gcSeries subtest passes, the lock-ordering subtest
   fails via its `TryLock` assertion.

Both independently trigger the zero-tolerance/50% FAIL_TO_PASS failure
rule, confirming the two fixes are graded as genuinely separable.

## Relevant experience

Anyone who has coordinated locking across two independently-written code
paths touching the same resource will recognize this: each path's locking
looks locally correct, and the deadlock only exists in the *combination*,
visible only by reasoning about both call paths' lock orders together, not
by reading either one in isolation.
