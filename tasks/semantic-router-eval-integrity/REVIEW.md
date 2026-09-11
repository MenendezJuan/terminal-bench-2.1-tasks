# Delivery review: semantic-router-eval-integrity

Reviewed with the `harbor-delivery-review` checklist (inventory.py, runs_audit.py) against the
assembled delivery, plus manual checks for the items the scripts cannot verify. Harbor version in
these runs: 0.21.0.

## inventory.py

`RED=1 AMBER=3`. All four findings trace to one cause, not a content defect: the delivery ships
the task once (per the checklist's own "ship the task once, with runs per model" guidance) rather
than one copy per model, so the script's cross-delivery comparison has nothing to pair against
and misreads the `evidence/` folder as a second, incomplete task delivery. The task itself
reports complete: 8 required files, nothing missing.

## runs_audit.py

`RED=2 AMBER=1`.

**"8 trials span 8 different content checksums" -- investigated, false positive.** Checked
whether this reflects real task-content drift between attempts, which would be a genuine defect.
It does not: all 5 GPT 5.6 trials carry the identical `task_id` (`{'path': '.'}`) while each has a
*different* `task_checksum`, despite running against the same frozen `instruction.md` and test
files across the whole cohort (verified against this task's own commit history: no edits between
attempt 1 and attempt 5). `task_checksum` in this Harbor version therefore does not behave as a
pure declared-content hash the way the checklist assumes -- most likely because each trial's
`--force-build` produced a distinct Docker image digest (base image patch drift, apt package
versions, or similar build-time variance), and that is folded into the checksum. This is a
property of this Harbor version's checksum computation, not evidence that any trial ran against
different task content. Flagging this discrepancy for the guideline maintainers since it is
exactly the class of false positive the checklist itself warns about (mixing checksum sources),
just from a source neither of its two named traps covers.

**"no hay resultados de corridas" under `task/`** -- expected. The runnable task copy under
`task/` is not itself a scored trial; results live only under `evidence/`. Not a finding.

**AMBER, "8 trials give the same reward 0.0 (flat signal)"** -- this is the reported result, not
a defect. The grader is binary (`echo 1/0 > reward.txt`), and every one of the 8 model attempts
(5 GPT 5.6, 3 claude-opus-5) failed at least one of the two independent F2P contracts. A flat 0.0
across a genuinely hard task's failing attempts is the expected shape for a binary grader; it
would only be a concern if partial-credit or plateau behavior were expected and never observed.
Oracle (1.0) and no-op (0.0) are excluded from this count and are correctly non-flat relative to
each other.

## Manual checks (not covered by the two scripts run)

- **Identifier leakage**: broad scan (`C:\Users\<name>`, `/home/<name>/`) across the full
  assembled delivery. Clean, zero matches, after the sanitization pass already applied.
- **Reward semantics**: binary, read directly from `tests/test.sh` (`echo 1/0 >
  reward.txt`), no implicit floor from a smoke-test-inclusive denominator.
- **Controls reproduction**: oracle=1.0 (verified 6 times independently before any paid run),
  no-op=0.0, both via real Docker builds through the actual verifier, not asserted.
- **Self-containment**: README.md/RESULTS.md/PROVENANCE.json reference only paths inside the
  delivery.

## Not checked

- `harbor_surface.py` was not run: it imports the `harbor` package directly, which is not on this
  session's Python path (Harbor is installed as a standalone `uv tool`, not a library dependency
  here). Running it would need that separate environment's interpreter.
- `build_delivery.py` was not run; this delivery was assembled by hand following the checklist's
  layout guidance rather than through the script.
- The two remaining claude-opus-5 attempts needed to complete a pass@5 cohort have not been run.
  Do not cite an Opus pass@5 for this task from the current evidence.
