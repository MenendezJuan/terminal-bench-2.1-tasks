# Refresh-Token Double-Redemption via Storage-Row Identity Mismatch

## Overview

`stacklok/toolhive`'s upstream-token refresher deduplicates concurrent
refresh attempts using Go's `singleflight`, keyed on a caller-synthesized
`sessionID + ":" + providerID` string. That key does not reliably
correspond to the storage layer's own notion of which record is being
refreshed: two different-looking (session, provider) pairs can resolve to
the same underlying storage row, or vice versa, depending on the backend.
When the two disagree, a stale concurrent caller can redeem the same
rotating refresh token a second time, which the identity provider detects
as a replay and revokes the entire credential family. Mined from
`stacklok/toolhive` PR #6361, base `72ffb454`.

## Skills Tested

- Recognizing that a coordination key synthesized from caller inputs is
  not the same thing as the storage layer's own identity for a record,
  and that the two can silently diverge depending on backend
  implementation details the caller has no visibility into.
- Not stopping at "fix the coordination key": a caller that joins a
  coordinated refresh late, after another caller already wrote a fresh
  token, must re-check storage before redeeming its own stale copy --
  fixing the key alone still leaves this window open.
- Result isolation: every waiting caller must receive an independent
  copy of the refreshed token, not a shared pointer one caller can
  corrupt for the others.
- Working correctly with Go's `singleflight` package and `gomock`-based
  storage test doubles.

## Environment

- Base image: `golang:1.26-bookworm`
- Repository sealed at `base_commit`, git remote severed
- Go module cache warmed, and the relevant packages pre-built and
  `go vet`-checked at build time so the agent and verifier phases run
  fully offline
- Resources: 2 CPUs, 4096 MB, 10240 MB storage
- Internet disabled during the agent phase
- Working directory: `/app`

## Difficulty

Estimated hard until calibration runs are complete. This is candidate 9,
mined from a repo (`stacklok/toolhive`) a colleague using `claude-opus-5`
independently recommended for this delivery; the specific claims about the
repo's test setup were verified directly rather than trusted (confirmed
via `Taskfile.yml` that `task test` excludes e2e and the repo targets Go
1.26). Two other repo-mate candidates from the same colleague's list were
set aside after inspection: PR #6432 (OAuth callback-port ordering) was
real but smaller; PR #6455 (OIDC discovery SSRF guard missing on a
fallback path, a real security advisory) was structurally identical to
the "thread a boolean guard through a sibling call path" shape already
used, and solved cleanly by GPT 5.6, in both `hashicorp/consul` #23899
and `tokio-rs/tokio` #8424 (candidates 7 and 8 in this delivery).

This candidate combines three genuinely separate invariants (coordination
key correctness, re-read-before-redeem staleness handling, and result
isolation) rather than a single flag threaded through call sites, a
deliberately different shape from the last two candidates.

## Solution

`solution/solve.sh` applies `solution/patch.diff` (fetched verbatim via
`gh pr diff`, not retyped) to the 6 real source files the PR touches
(`refresher.go`, `service.go`, `server_impl.go`, the storage
`memory`/`redis`/`types` files) plus the regenerated `gomock` mock file
and an architecture doc. The test-file portion of the PR's own diff is
intentionally excluded; the verifier installs the graded test files
separately (see Verification).

## Verification

`tests/refresher_test.go` and `tests/types_test.go` are the PR's own
post-fix versions of files that already existed at `base_commit`. Both
packages containing these files fail to COMPILE at base, since the test
files reference symbols the fix must add -- this correctly takes down two
genuinely-unrelated pre-existing tests that share the same files
(`TestUpstreamTokenRefresher_SingleflightDedup`,
`TestUpstreamTokenRefresher_RefreshAndStore`), which is graded as a no-op
scoring 0 (every one of the 4 named tests absent from the pass results).
Graded: 2 FAIL_TO_PASS (`TestUpstreamTokenRefresher_RowIdentity`,
`TestUpstreamTokenRowIDResolution`), a representative PASS_TO_PASS sample
of the 2 pre-existing tests above. The verifier scopes runs to `go test
./pkg/authserver/...` rather than the repo's own `task test`, since the
PR's own test-plan notes the full monorepo suite is blocked by an
unrelated flaky Docker networking test. No live Redis server is required
for grading; the new row-identity test's `redis` subtest exercises the
identity-derivation logic directly. Both base and gold runs repeated once
to rule out flakes; fully stable.

## Mutation Testing

Before any model run, a hand-written plausible incomplete repair was
tested: applied the real gold patch, then replaced the singleflight
critical section with a version that resolves and keys on the new row
identity (so deduplication itself looks correctly wired) but never
re-reads the authoritative storage row before redeeming -- it just calls
the refresh directly with the original, possibly-stale expired token the
caller passed in. `TestUpstreamTokenRefresher_RowIdentity` (FAIL_TO_PASS)
and `TestUpstreamTokenRefresher_SingleflightDedup` (PASS_TO_PASS) both
correctly fail under this mutation.

## Relevant experience

Anyone who has coordinated concurrent access to a resource by a key
derived from the request rather than from the resource's own identity
will recognize this class of bug: the coordination looks correct because
it deduplicates SOMETHING, but what it deduplicates on is a proxy for
identity, not identity itself, and the two only diverge in cases the
original author's mental model did not include.
