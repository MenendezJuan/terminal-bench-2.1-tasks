# Terminal-Bench 2.1 task-authoring guidelines

> Readable transcript of the supplied DOCX. The DOCX remains the source of truth.

TERMINAL-BENCH 2.1

TERMINAL-BENCH 2.1

Task authoring guidelines

How to build a task that a strong coding agent fails five times out of five, and how to package it so a reviewer can check that claim without taking your word for it.

1.  THE GOAL

The target is pass@5 <= 1. Five independent attempts by the same model under one scaffold, with AT MOST ONE passing. Target models: claude-opus-5 and GPT 5.6

What separates a hard task from a broken one

| SIGNAL | HARD TASK | BROKEN TASK |
| --- | --- | --- |
| Oracle (reference solution) | scores 1 | scores 0, or there is no oracle |
| No-op agent | fails on the tests | fails on the environment |
| Model attempts | fix a real subset, 20 to 40% | fix nothing, or error out |
| Failures across attempts | converge on the same subset | random, or infrastructural |
| Requirements | every test traces to a sentence | tests assert unstated things |

The tasks worth keeping usually have an easy surface and a hard core. The agent gets somewhere visible, sometimes quite far, and still misses the part that matters. Two from this project:

A stale-process bug. Every attempt fixed unit-name matching, which was the easy half. None of the eight attempts went near process identity, which was the actual bug.

A read-tool bug. Every attempt added the missing warning message. None of them moved the size check that made the warning necessary in the first place.

Both scored 0 of 5. What showed they were hard rather than unclear was the per-test breakdown, not the total.

How an attempt is graded

An attempt fails if either condition holds:

At least 50% of the FAIL_TO_PASS tests still fail. The denominator is FAIL_TO_PASS only, never the whole suite. A percentage over every collected test is dominated by tests the bug never touched, and would score a do-nothing agent as passing.

Any PASS_TO_PASS test regresses. No threshold applies here. Fixing the bug does not buy back breaking something that already worked.

The 50% threshold is for model attempts only. The oracle has to pass 100% of both sets. If it does not, the task is broken and nothing measured on top of it means anything.

| LABEL | MEANING |
| --- | --- |
| hard | 0/1 of 5 attempts passed. Re-check solvability first, since an unsolvable task also scores 0 |
| borderline | 1 to 3 of 5. Usually the most informative band |
| easy | 5 of 5. On a pre-cutoff commit, suspect contamination |
| void | Harness or provider fault. Excluded from pass@k, it is not a model result |
| ungraded | The task ran, but no graded test set exists yet. Never file this as hard |

2.  THE WORKFLOW

Budget roughly a day per task. Most of it goes to steps 1 and 6.

STEP 1. FIND A CANDIDATE

Mine merged pull requests from a repository that is still actively developed. A good candidate has:

A linked issue with real reproduction detail, ideally 800 characters or more. Issue detail is the best single predictor we have of a task that works out.

A fix touching 2 to 6 source files. One file is usually too small to be interesting; past ten, the task is too diffuse to scope.

Tests added or modified in the same PR, so the PR carries its own adjudication.

No dependency churn. A fix that also bumps lockfiles is hard to isolate.

A merge date after the model training cutoff, so the answer is not sitting in the weights.

STEP 2. WRITE THE TESTS FIRST

The tests are the specification and the prompt is a description of them. Write the prose first and you end up asserting things the prompt never asked for, which the agent has no way to infer.

STEP 3. WRITE THE PROMPT FROM THE TESTS

Every test should earn a sentence, and every sentence should be bound by at least one test. A sentence with no test behind it is decoration. A test with no sentence behind it makes the task unsolvable.

STEP 4. BUILD THE ENVIRONMENT

Seal the repository at the pre-fix commit, sever the git remote, and assert both in the build. Hidden tests must not exist anywhere in the agent image.

STEP 5. RUN THE CONTROLS BEFORE SPENDING ANYTHING

The oracle must score 1. Read the test count as well as the reward.

The no-op must score 0, and its error has to name a test-failure count.

Repeat the oracle to catch flakes.

STEP 6. PROBE IT

Five attempts, same model, same scaffold, same everything. Then read what the attempts actually did. The scores on their own will not tell you whether the task worked.

3  THE DELIVERY ZIP

Template link

Filename: <task-name>-<YYYYMMDD>.zip. The layout:

What each piece of evidence proves

| DIRECTORY | PROVES | READ THIS FILE |
| --- | --- | --- |
| evidence/oracle/ | the task is solvable | reward.txt = 1, and the test count |
| evidence/nop/ | the verifier measures the bug | error.txt names a failure count |
| evidence/attempts/ | the difficulty claim | the agent log, before you trust a score |

A delivery with no attempts is legitimate. The controls on their own show the task is sound. It just does not carry a difficulty label, and whatever goes in the difficulty field is an estimate. Mark it as one, or someone downstream will quote it as a measurement.

The gates

terminal-bench/tools/package-delivery.sh enforces 24 gates and refuses to package a task that fails one. The gate that has caught the most real problems is the one checking that the no-op fails on the tests rather than on the environment. On one task an image was missing a native library, so the oracle and the no-op failed in exactly the same way, and no structural check would have flagged it.

Gates run on the zip as well as on the folder, because the zip is what leaves the machine: no internal project names, no API keys, no host paths.

4  HARNESS AND RUN CONFIGURATION

Harness to use

Terminus-2 is the reference harness.

The 60-turn cap

We use 60 turns because that is what the run data supported:

At a 5-turn cap the agent has not finished orienting, which manufactures fake hard labels.

Measured pace: the first edit lands at turn 8 to 19 on a well-specified task, and at turn 35 to 53 on a poorly located one.

At 60 turns, a model that reaches source by turn 20 still has 40 turns to implement, which is enough for a real attempt.

Check turns-to-first-edit before you call a task hard. An agent that spent 40 of its 60 turns reading and never edited measured navigation, not capability.

Timeouts

| SETTING | TYPICAL | NOTE |
| --- | --- | --- |
| [agent] timeout_sec | 2400 | Wall clock. Raise it when the model is slow per turn, not to hand it more turns |
| [verifier] timeout_sec | 900 | Must cover the full graded suite with headroom |
| [environment] build_timeout_sec | 3600 | Large repositories with native builds need this |

Resources and network

Published tasks are small. 1 to 2 CPUs and 2 GB is typical. If you need six CPUs and 12 GB, the task is probably the wrong shape.

allow_internet always as false. For a task mined from a public repository, set it to false. The fix is already upstream and one fetch away.

Voids

A harness or provider fault produces numbers that look identical to a model that tried and failed. The agent never edits, the verifier grades an untouched tree, and the report reads exactly like the no-op control. Only the agent log tells them apart.

Three came up on this project, all excluded from pass@k: an invalid API key, a provider stream that ended without a finish reason, and a key exported under the wrong variable name. The cheap tell is cost and duration. A real turn-capped attempt burns money and minutes, so a run that finishes in one to three minutes for under a dollar is a void.

5  WRITING THE PROMPT

Analysis of prompt’s structure from TB 2.1.

Measured over the 89 published instructions: median 715 characters, with the middle half between 470 and 1263.

| CONVENTION | SHARE OF CORPUS | RULE |
| --- | --- | --- |
| Absolute paths | 86% | Always name where the work is |
| Em dashes | 0% | Never use one |
| Bullets | 40% | Fine |
| Numbered lists | 22% | Fine |
| First person | 37% | Optional |
| Headings | 2% | Avoid |
| Bold | 3% | Avoid |
| Tables | 1% | Avoid |

Name the interface and withhold the approach. If the agent cannot locate where the work happens, you have built a guessing game rather than a hard problem.

Give the agent a feedback loop, and say what it costs to run. In a controlled comparison on one task, adding a test command changed nothing on its own: the agent assumed a 15-second timeout against a suite that takes 35, gave up after one try, then edited blind for 40 turns and regressed 7 tests. Three more words in the prompt, "allow 60s", took the same model to five test runs and no regressions, with the fix count unchanged. The regressions came from the missing feedback loop, not from a limit on what the model could do.

Common ways to get it wrong

Vagueness. It produces unsolvable tasks, and those grade as hard for the wrong reason.

Leaking the fix. Mined issues are often source-audited down to line numbers. State the requirement and leave out the diagnosis.

Asserting the unstated. Any test the prompt never asked for makes the task unsolvable.

Stale external dependencies. Nine tasks in 2.0 broke because they pulled images that later changed. Pin everything.

5  Evaluation

PASS@1, PASS@3, PASS@5

pass@k here is a count, not a rate: k independent attempts, n of them passed, written n of k. We run exactly k and count them. No sampling estimator, no averaging, no best-of. An attempt only counts toward k if it produced a real result, so a void is replaced and the count carries on.

The three stages

Stage 1, pass@1. One attempt. A pass ends the evaluation: the model solved it on the first try and the candidate will not hold at five. Kill it, or make it harder. A single failure buys nothing on its own, since one miss is well inside the noise for a task the model solves half the time.

Stage 2, pass@3. Two more attempts under identical config, giving three. A pass here makes the task borderline, bounded at 1 or 2 of 3. Stop and record the count.

Stage 3, pass@5. Two more, giving five. 0 of 5 is the target. Before writing it down, re-apply the solvability gate from step 1, because an unsolvable task also scores 0 of 5.
