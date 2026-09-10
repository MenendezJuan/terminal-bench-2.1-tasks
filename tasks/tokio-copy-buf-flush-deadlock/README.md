# copy_buf Stalled-Reader Flush Deadlock

## Overview

`tokio-rs/tokio`'s `copy_buf` (the async utility copying an `AsyncBufRead`
reader into a writer without an extra allocation) can hang forever when the
reader stalls (returns `Pending`) while the writer is still holding
buffered, unflushed data the reader's own progress depends on -- the
canonical case is proxying a request/response protocol through a buffering
writer. Mined from `tokio-rs/tokio` PR #8424, base `dde3f869`.

## Skills Tested

- Diagnosing a genuine deadlock from first principles: two sides of an
  async pipe each waiting on the other, with nothing forcing progress.
- Recognizing that a fix must be conditional (flush only when there is
  actually unflushed data) rather than a blanket flush on every stall,
  which would silently defeat the point of buffering.
- Working correctly with hand-written `Future::poll`/`Pin` state machines
  in Rust, tracking a small piece of state (whether a write has happened
  since the last flush) across repeated poll calls.
- Fixing the actual reachable code path without touching or duplicating
  logic in a related, already-correct sibling function elsewhere in the
  same crate.

## Environment

- Base image: `rust:1.90-bookworm`
- Repository sealed at `base_commit`, git remote severed
- Cargo registry warmed and the tokio crate's tests pre-compiled (not run)
  at build time so `cargo test` runs fully offline during the agent and
  verifier phases
- Resources: 2 CPUs, 4096 MB, 10240 MB storage
- Internet disabled during the agent phase
- Working directory: `/app`

## Difficulty

Estimated hard until calibration runs are complete. This is candidate 8,
mined after the user redirected away from multi-PR combination: three
mining passes for genuine mutual tension between two related PRs all
failed to turn up a real interaction (see `research/CLAIMS.md` for the
full account of `kirodotdev/KiroCrew` #9788+#9845, a simple sequel, and
`prometheus/prometheus` #19664+#19666, verified via full diff read to
touch genuinely separate, non-interacting eviction pathways). Redirected
back to single-PR with greater domain complexity instead.

The real fix that landed upstream had already fixed this exact deadlock
once before, in a different but related function (`copy`, under an
earlier PR, #4001) -- the guard was simply never propagated to `copy_buf`'s
own, independent state machine when it was written. Reading `copy_buf` in
isolation gives no hint that anything is missing; the gap is only visible
by understanding the deadlock mechanism well enough to notice it applies
here too, not by comparing source files directly (`instruction.md`
deliberately does not point at the sibling function or its fix).

New language and domain for this delivery: async Rust with hand-written
`Future::poll`/`Pin` state machines, distinct from every prior candidate's
language (Python, Go x2, Java, Go again).

## Solution

`solution/solve.sh` applies `solution/patch.diff` (fetched verbatim via
`gh pr diff`, not retyped) to `tokio/src/io/util/copy_buf.rs`. The
test-file portion of the PR's own diff is intentionally excluded from the
patch; the verifier installs the graded test file separately (see
Verification).

## Verification

`tests/io_copy.rs` is the PR's own post-fix version of a file that already
existed at `base_commit` (4 tests total; the PR adds one new test,
`proxy_buf`, does not add a new file). The verifier copies it over
whatever the agent leaves rather than patching.

This bug is a genuine deterministic deadlock, not a probabilistic race:
`#[tokio::test]` carries no default per-test timeout, so an unfixed
`proxy_buf` run never returns on its own. The verifier wraps the whole
`cargo test` invocation in an external 90-second shell timeout and grades
by whether each test's own `ok` line appears in the captured output,
rather than trusting the process exit code -- a hung test is silent rather
than failing loudly, so its absence from the output is the failure signal.
Graded: 1 FAIL_TO_PASS (`proxy_buf`, measured empirically: never prints a
result line at base, prints `ok` at gold), 3 PASS_TO_PASS (`copy`,
`proxy`, `copy_is_cooperative`, all already passing at base). Both base
and gold runs repeated once to rule out flakes; fully stable.

## Mutation Testing

Before any model run, a hand-written plausible incomplete repair was
tested: applied the real gold patch, then removed only the `if
me.need_flush { ... }` check inside the stalled-reader branch, leaving the
tracking field itself declared and set elsewhere -- a model might add
state that mirrors the shape of a correct fix without actually wiring it
into the branch that matters. `proxy_buf` correctly hangs again under this
mutation (identical failure signature to the base case), confirming the
graded test requires the flush to actually be wired in, not just tracked.
With F2P_TOTAL=1, any single failure or hang already crosses the 50%
threshold; no coarse-bucket grading risk.

## Relevant experience

Anyone who has debugged a "sometimes hangs" async pipeline has likely hit
exactly this shape of bug: a buffered writer and a reader whose progress
secretly depends on that buffer being flushed, with nothing in the code
making that dependency explicit until it deadlocks in production. The
fix here is small once found; the difficulty is entirely in recognizing
the deadlock mechanism at all from the reported symptom, since the
function's own code reads as complete and correct in isolation.
