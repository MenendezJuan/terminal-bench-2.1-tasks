# Results: semantic-router-eval-integrity

Harness `terminus-2`, Harbor CLI, model runs 2026-09-10. Task digest frozen before any paid run
(see PROVENANCE.json / README.md for the pre-spend gate: oracle x6, no-op, four pre-registered
partial-repair mutations, all as predicted, before any model was tried).

A small number of void runs are excluded below: the sealed image built without
`tmux`/`asciinema` on a stale Docker cache mid-session, which failed Terminus-2's own agent
setup before the model ever saw the task. Fixed (`--force-build`), re-verified oracle=1/no-op=0
on the corrected image, then re-ran. A further two Opus attempts also failed before the model
produced any output and are excluded as void, not as model failures.

## GPT 5.6 -- pass@5 = 0 of 5 (complete cohort)

| attempt | turns | cost | F2P failing (of 2) | which contract failed |
|---|---|---|---|---|
| 1 | 33 | $1.05 | 1 | disjoint-heldout/manifest (added an unrequested sort to `build_manifest`) |
| 2 | 36 | $1.06 | 1 | same as attempt 1 |
| 3 | 33 | $1.09 | 2 | both: manifest ordering **and** registry parity (legacy 8K names not replaced) |
| 4 | 35 | $1.24 | 1 | same as attempt 1 |
| 5 | 43 | $1.60 | 1 | same as attempt 1 |

Zero P2P regressions in any attempt. No attempt was turn-capped (all finished well under the
60-turn budget). **pass@5 = 0/5.**

Four of five attempts fail the same way: `build_manifest` is specified as a plain recorder (it
must store `heldout_row_indices` exactly as given), and the gold implementation is a bare
`list(heldout_indices)` passthrough. Every failing attempt instead sorted the list before
storing it -- a transformation the instruction never asks for and the gold code never performs.
This was checked against the actual instruction wording before being counted as genuine
difficulty (not an unstated requirement on our side): the sentence requiring sorted output
describes `reserve_heldout`'s own return value in isolation; the following sentence describing
`build_manifest`'s job says nothing about sorting. The one attempt (3) that also missed the
second, independent registry-parity contract confirms both bundled incidents are individually
hard, not just one narrow model habit repeating five times.

## claude-opus-5 -- pass@3 = 0 of 3 (incomplete cohort, stopped at 3 of the planned 5)

| attempt | turns | cost | F2P failing (of 2) | which contract failed |
|---|---|---|---|---|
| 1 | 56 | $4.02 | 1 | disjoint-heldout/manifest (same sort mistake as GPT) |
| 2 | 72 | $5.39 | 1 | same |
| 3 | 52 | $4.98 | 1 | same |

Zero P2P regressions in any attempt. No attempt was turn-capped (all finished well under the
100-turn budget; turns 52-72 of 100). **The remaining two attempts to complete a pass@5 cohort
have not yet been run.** This is reported as an incomplete cohort, not as `0/5` -- do not cite
Opus pass@5 for this task without running the two missing attempts first.

All three completed Opus attempts converged on the exact same mistake as GPT: an unrequested
sort added to `build_manifest`. Two independently-trained models making the identical error
independently is itself informative -- it suggests the instruction's proximity of the sorting
requirement (for `reserve_heldout`) to the `build_manifest` description invites this specific
slip, even though a careful reading does not require it. This is noted as a real property of the
task, not hidden.

## Reading these numbers

- GPT 5.6: a genuine, reproducible 0/5. The first candidate in this delivery (after fifteen
  mined) to survive full staged evaluation without a grading-bug explanation.
- Opus: 0/3 so far, same failure mode as GPT in all three. Treat as a strong partial signal
  pointing the same direction as GPT, not as a completed pass@5 verdict.
- Both bundled incidents (manifest fidelity, registry parity) independently produced failures
  across the cohort, supporting the task's two-leaf design (fixing only one leaves exactly 50%
  F2P failing, which is why a single-incident partial fix cannot pass under the program's own
  >=50%-remaining rule).
