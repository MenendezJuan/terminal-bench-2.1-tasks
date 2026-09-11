# Delivery review: semantic-router-eval-integrity

> **Superseded on 2026-09-11.** A later implementation-neutral replay found that the flat-zero conclusion below is not valid: seven attempts first fail on an unstated order-preservation requirement and then encounter mocks tied to the gold's private `create_mmlu_dataset` decomposition. Only one GPT attempt has an independently established contractual failure. This candidate is `REWORK_REQUIRED`, and no pass@k result is reportable. See `CANDIDATE_15_INDEPENDENT_REGRADE_2026-09-11.md`.

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

## harbor_surface.py

Run with Harbor's own isolated interpreter (`uv tool` installs Harbor into its own venv; the
script imports `harbor.models.task.config`, which is not on this session's normal Python path).
Found via `.../uv/tools/harbor/Scripts/python.exe`.

`RED=1 AMBER=2`.

**RED, real finding, project-wide: `agent.kwargs` is silently discarded.** `task.toml` declares
`[agent.kwargs]` with `max_turns = 60`, following the same pattern used across every task in this
delivery. Checked Harbor's own `AgentConfig` schema directly (`AgentConfig.model_json_schema()`):
it has no `kwargs` field at all in this Harbor version. The declared value has zero effect on a
run; the turn cap only takes effect via the `--ak max_turns=N` CLI flag passed at invocation time.
Every real pass@k run in this delivery, including all attempts recorded here, explicitly passed
`--ak max_turns=60` (GPT 5.6) or `--ak max_turns=100` (claude-opus-5) on the command line, so this
does not invalidate any result already recorded -- the actual cap used matches what is reported.
But `[agent.kwargs]` in `task.toml` is decorative and misleading as written: a future run that
relies on the file alone, without the CLI flag, would get no cap at all. Worth fixing across every
task in this delivery, not just this one; flagging here rather than silently patching every
task.toml, since that is a cross-cutting change outside this task's own scope.

AMBER findings (declared-but-empty `artifacts`, and `F2P.json` as an out-of-spec entry in the task
directory) are both intentional and match every other task in this delivery: `F2P.json` is this
project's own pre-spend-gate bookkeeping file, not something Harbor reads.

## Not checked

- `build_delivery.py` was not run: it expects a fixed `tasks/_raw/<delivery>` input layout
  designed for a different assembly workflow than this delivery's. This delivery was assembled by
  hand following the checklist's own layout guidance (section 8) instead.
- The two remaining claude-opus-5 attempts needed to complete a pass@5 cohort have not been run.
  Do not cite an Opus pass@5 for this task from the current evidence.
