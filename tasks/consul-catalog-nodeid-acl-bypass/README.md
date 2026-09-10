# Catalog Node-ID ACL Bypass, Cross-Node Takeover

## Overview

`hashicorp/consul`'s `Catalog.Register` RPC authorizes a node-registration
request by checking write permission on the request's OWN node name only.
Separately, in the state-store layer, a request carrying a node ID that
already belongs to a DIFFERENT node is treated as a rename: the existing
node (and everything under it) is deleted, and a fresh node is created
under the request's name. The RPC-layer authorization was never extended
to cover this rename side effect, so a caller with write access to only
their own node name can destroy and replace any other node by supplying
its ID. Mined from `hashicorp/consul` PR #23899, base `cdf07d58`.

## Skills Tested

- Recognizing that an authorization check that looks locally complete
  (it does check something, and the check itself is correct as far as it
  goes) can still be insufficient, because the code that actually acts on
  the authorized request has a side effect the check never accounted for.
- Tracing an effect across a package boundary: the authorization check
  lives in the RPC endpoint layer (`agent/consul`); the rename-on-ID-match
  logic that makes the gap exploitable lives in the state-store layer
  (`agent/consul/state`), a separate Go package. Reading the endpoint code
  in isolation gives no hint that anything is missing.
- Authorizing against the correct target: the fix must check permission
  on the EXISTING node's real name, not the request's own name (the two
  are easy to swap, and swapping them silently reopens the exploit -- see
  Mutation Testing below).
- Leaving the legitimate rename behavior itself intact; the fix is an
  additional authorization gate, not a removal of the rename feature.

## Environment

- Base image: `golang:1.26-bookworm` (Go 1.26.7)
- Repository sealed at `base_commit`, git remote severed
- Local Go module cache warmed at build time (`go mod download`) so `go
  test` runs fully offline during the agent and verifier phases
- Resources: 2 CPUs, 4096 MB, 10240 MB storage
- Internet disabled during the agent phase
- Working directory: `/app`

## Difficulty

Estimated hard until calibration runs are complete. This is candidate 7,
mined after two failed mining passes and following a teammate's
independently-confirmed pattern (see `research/PRE_SPEND_ACCEPTANCE_GATE.md`
and the vault note "Dead-check bugs vs message-branch bugs"): a small,
surgical FAIL_TO_PASS set targeting a genuine structural mechanism, not an
enumerated taxonomy. Two candidates were rejected before this one:
`pgvector/pgvector` #1010 (no test file in the PR at all, only an
out-of-tree GDB lockstep repro script) and `moby/moby` #53524 (a single
missing OR-condition in one function, the same localized-fix shape that
had already beaten this delivery 6 times); two more, `go-git/go-git`
#2269 and #2127, were rejected for declared AI assistance in the PR body.

Unlike the other 6 candidates in this delivery, this bug and its tests
involve zero concurrency or timing -- the exploit and its fix are both
fully deterministic authorization logic, exercised through real RPC calls
against a real (single-process) Consul test agent.

## Solution

`solution/solve.sh` applies `solution/patch.diff` (fetched verbatim via
`gh pr diff`, not retyped) to `agent/consul/catalog_endpoint.go`. The
test-file portion of the PR's own diff is intentionally excluded from the
patch; the verifier installs the graded test files separately (see
Verification).

## Verification

`tests/catalog_endpoint_test.go` and `tests/txn_endpoint_test.go` are the
PR's own post-fix versions of two files that already existed at
`base_commit`. Both use only pre-existing Consul test helpers already
exercised by neighboring tests in the same files (`testServerWithConfig`,
`rpcClient`, `createToken`, `msgpackrpc.CallWithCodec`) -- no private test
seams the fix itself introduces, so copying the PR's own files verbatim is
safe here (unlike candidate 6, floci-kinesis-concurrent-append-race, whose
tests depended on hooks the fix introduced and had to be authored
independently). The verifier copies both files over whatever the agent
leaves rather than patching.

Graded: 1 FAIL_TO_PASS
(`TestCatalog_Register_NodeIDCrossNodeTakeover`, measured empirically --
fails at base because the exploit succeeds, passes at gold), 1
PASS_TO_PASS (`TestTxn_Apply_NodeSetRejectsCrossNodeTakeoverByID`, which
already passes at base because the `Txn.Apply` code path already had this
protection before this PR -- confirmed against the PR's own changelog
text). Both runs repeated once to rule out flakes; fully stable.

## Mutation Testing

Before any model run, a hand-written plausible incomplete repair was
tested (per `PRE_SPEND_ACCEPTANCE_GATE.md`): the real gold patch, with the
authorization target flipped from the existing node's real name to the
request's own name -- an easy mistake, since the request's own name is
the more "obvious" field to reach for. `TestCatalog_Register_NodeIDCross-
NodeTakeover` correctly fails under this mutation (the attacker always has
write on their own name, so the check never actually blocks anything).
With only one FAIL_TO_PASS test, this candidate does not carry the
coarse-bucket grading risk candidate 6 had with a larger F2P set; no gate
restructuring was needed.

## Relevant experience

Anyone who has reviewed an authorization check and confirmed "yes, it
checks something real" without asking "does it check the right thing,
given everything that happens once this request is allowed through" will
recognize this bug. The check itself is not wrong in isolation; it is
incomplete relative to a side effect implemented in a different part of
the codebase that the reviewer (and the original author) never had in
view at the same time.
