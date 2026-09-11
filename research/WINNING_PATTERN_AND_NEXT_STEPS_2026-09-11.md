# Post-mortem: what finally worked, and the plan from here

Fifteen candidates mined, fourteen fell to GPT 5.6 on pass@1 or after a real grading-bug fix.
One survived full staged evaluation: `vllm-project/semantic-router` #3628+#3651
(`semantic-router-eval-integrity`). GPT 5.6 pass@5 = 0/5. claude-opus-5 pass@3 = 0/3 (cohort
incomplete, stopped for API credit, not by choice). This document names precisely what was
different about it, then lays out where to look next.

## 1. What actually made this one hard (read the causal shape, not the buzzwords)

Do not repeat "combine three bugs" or "add more tests" as the lesson. Those were our own
hypotheses mid-session and both turned out to be wrong in isolation — the real teammate examples
that worked (valkey, apm, olmo) and the one we built do NOT share a headline count. What they
share, checked directly against the failing model patches, not inferred from task descriptions:

- **Two (or more) repairs with genuinely different root causes, in the same feature/module,
  each independently gate-worthy.** Not two symmetric variants of one mechanism (a lock/boolean
  threaded through one extra call path — this is what candidates 5, 7-14 all were, and all fell).
  In candidate 15: (a) a data-recorder function must not silently transform its input, an
  ownership/fidelity contract; (b) a registry must resolve every role to one specific artifact
  version, a consistency contract. Different failure classes, not the same idea applied twice.
- **A repair to one incident does not make the other easier to guess.** Fixing the registry
  parity contract gives zero information about the manifest-fidelity contract. This is what
  actually produces a real >=50%-F2P failure spread across a cohort, not the raw count of bugs.
- **The failure mode is a plausible, easy-to-miss engineering habit, not an obscure trick.**
  GPT 5.6 (4 of 5 attempts) and claude-opus-5 (3 of 3 attempts) converged on the *identical*
  mistake: adding an unrequested `sorted()` call. That convergence across two independently
  trained models is itself the signal that this is a genuine blind spot, not noise. A good
  candidate should produce this kind of convergent, explainable failure — not a scattered mix of
  unrelated mistakes (that usually means the task is just ambiguous, which is a grading bug, not
  difficulty).
- **The instruction states the contract, not the mechanism, and was checked against exactly
  this failure before being trusted.** Before counting the first 0.0 as real, the actual
  instruction wording was re-read line by line to rule out an unstated requirement on our side.
  It survived that check because the sentence the model over-generalized from was, on a careful
  reading, scoped to a different function. Do this check on every candidate 0.0 before it goes in
  a report — see research/PRE_SPEND_ACCEPTANCE_GATE.md, this is not new, but it is the step this
  session skipped fastest under time pressure and had to redo twice (prometheus, valkey).

## 2. Immediate next step: mine inside vllm-project/semantic-router before going anywhere else

This repo already produced a real hard candidate once, in a training/eval-integrity area. That is
a much stronger prior than any fresh repo, and we already carry real infrastructure for it: the
sealed base commit, a working Dockerfile pattern (python:3.12-slim, dependency-light unit tests,
no model downloads needed), and a CodeGraph index if one was built against this checkout.

**Where to look, in order:**

1. **Same module family, later commits.** `git log --oneline src/training/ src/training/model_classifier/ src/training/model_eval/` past the frozen base commit, filtered the same way as before (human-authored, no AI-assistance markers, tests in the same PR, post-cutoff). The training/eval pipeline is exactly the kind of code that accumulates more of this shape: config drift between what's declared and what's served, silent data transformations, registry/manifest fidelity.
2. **Sibling integrity boundaries in the same repo.** Look for other places where two artifacts must agree (routing config vs. served models, cache vs. source of truth, declared vs. actual schema) — the registry-parity half of candidate 15 is one instance of a pattern (`declared X must match served X`) that a large ML-serving repo like this one likely has more than once.
3. **PRs that touch the same files candidate 15 touched**, even if not overlapping in line ranges — `git log --follow` on `heldout_split.py`'s neighbors and on the registry/download-manifest code, for later fixes in the same area that might combine with what's already gold here into a still-larger, still-fair task.

**Stop condition for this repo:** if two mining passes here find nothing that clears the
pre-spend gate (real distinct root causes, human-authored, no rewritten agent-visible tests, F2P
count in the double digits if the shape allows it like `apm-cache-prune-recency` did), move to
step 3 rather than force a third pass on the same repo.

## 3. Fallback: broader search, same criteria, explicit reference set

If semantic-router runs dry, mine broadly again, but scope every candidate against the
teammates' three proven hard examples and candidate 15 as reference shapes — not against our
own eleven failed guesses. Concretely, before claiming a candidate, answer in writing:

- Name the two-plus root causes. If they can be described as "the same fix in two places," reject
  before scaffolding.
- Would fixing incident A give a model any real information toward incident B? If yes, reject —
  that is a hint chain, not independent difficulty.
- Is there a detection mechanism the sealed environment must carry (ASan, a second build variant,
  a registry-cross-check) rather than a single straightforward assertion? Tasks with only "did
  the number match" checks have fallen every time this session; tasks needing a second build
  variant (valkey) or an end-to-end integration check spanning training-into-eval (candidate 15,
  apm) have not.

Repos worth a scouting pass on this basis, not yet claimed: `lerd-env/lerd`,
`Tracer-Cloud/opensre`, other ML-serving/training repos in the vllm-project org besides
semantic-router, and any repo a teammate's next delivery names (check `research/CLAIMS.md` before
starting, every time, not just at session start).

## 4. Process fixes for this delivery, effective immediately

Real, avoidable mistakes made across the last three candidates (prometheus, valkey, candidate 15),
each cost real time or money:

- **Always pass `--force-build` on every paid `harbor run`, no exceptions.** This session hit the
  same void three separate times (tmux/asciinema missing from a stale cached image) because a
  run was launched without it. A working image from one run is not proof the next run reuses it.
- **`[agent.kwargs]` in `task.toml` is decorative in this Harbor version (0.21.0) — it has no
  effect.** `max_turns` must be passed via `--ak max_turns=N` on every invocation. Audit every
  existing task's `task.toml` for this and either remove the misleading section or add a comment
  explaining the CLI requirement, matching the fix already applied to candidate 15.
  `harbor_surface.py` (from the `harbor-delivery-review` checklist, run with Harbor's own `uv
  tool` interpreter, not the system Python) catches this in one pass — run it on every task
  before it ships.
- **When a test file is installed by `cp` over a whole directory (not a single named file), check
  whether that directory also holds the production code the fix is supposed to touch.** The
  prometheus task's `git checkout $BASE_COMMIT -- tsdb` bug (reverting the agent's own production
  fix along with test files, because Go keeps source and tests in one directory) cost a full
  false "oracle failed" cycle. Go/Rust/C tasks need this checked explicitly; the Java/Python
  tasks in this delivery never had the problem because their test trees are physically separate.
- **A test that calls an internal function by its exact private signature is testing the
  mechanism, not the contract**, and will fail a model that solved the problem correctly by a
  different internal decomposition — exactly what happened on the first prometheus pass@1. Prefer
  driving the graded behavior through the same public entry point every implementation must
  expose, and reserve internal-symbol assertions for cases where the instruction itself names
  that symbol as part of the required interface (as candidate 15's `build_manifest` legitimately
  does, since the instruction section 11 names the exact function signature as the interface
  contract).
- **Before accepting any 0.0 as genuine difficulty, read the model's own patch, not just the
  failed-test name.** This alone caught four real grading bugs this session (kirocrew x2, consul,
  toolhive, prometheus) and one real non-bug (candidate 15's actual first pass@1) in roughly equal
  measure — it is the single highest-value check in the whole workflow and the one most tempting
  to skip when a result looks clean.
- **Delivery zip format**: the written guideline (`guidelines/guidelines-extracted-text.md` §3)
  specifies one zip per task, `evidence/{oracle,nop,attempts}/`, not separate zips per model.
  Teammates' recent deliveries split by model instead. This is now a known discrepancy, not an
  oversight — confirm with the team which convention the client actually wants before the next
  delivery, and note it explicitly in `research/CLAIMS.md` once settled so it does not have to be
  re-litigated per task.

## 5. What "done" looks like for the next candidate

Same staged-evaluation bar as candidate 15, not a lighter one because we already have one win:
pre-spend gate (build, no-op, oracle x5+, pre-registered mutation per root cause) before any paid
run; pass@1 kills the candidate on a clean pass; pass@3 then pass@5 only on a genuine fail,
re-verified against the model's real patch at every step; both target models run in parallel once
the pre-spend gate is clean, not staged one after the other, since compute cost is now a real
constraint (see the OpenRouter credit exhaustion on this exact candidate — check remaining
balance before committing to a five-run cohort on both models).
