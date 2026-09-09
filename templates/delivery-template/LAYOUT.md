# Delivery layout, Terminal-Bench 2.1

This zip is a TEMPLATE. Every file here is a placeholder that describes what
belongs in its place. Nothing in it is runnable.

Produce a real delivery with the packaging tool, which assembles this shape,
runs the gates, and refuses to package a task that fails one. Do not assemble a
delivery by hand: the gates are the point.

```
<task>-<YYYYMMDD>.zip
  harbor-task/                          the runnable task, exactly the seven 2.1 files
    task.toml                           schema_version = "1.1", eight sections
    instruction.md                      the prompt, plus the canary comment
    README.md                           human-facing, four required sections
    environment/Dockerfile              the image, and nothing else in this directory
    solution/solve.sh                   the oracle
    solution/patch.diff                 what the oracle applies, if it applies a patch
    tests/test.sh                       the verifier
    tests/test_patch.diff               the hidden tests, if the task restores them
  evidence/
    oracle/                             a full trial directory: reward 1
    nop/                                a full trial directory: reward 0
    attempts/<model>/attempt-N/         one directory per model run, or NO-ATTEMPTS.md
  README.md                             copy of harbor-task/README.md, for the reader
```

## What each piece of evidence proves

`evidence/oracle/` scoring 1 proves the task is SOLVABLE. A task whose own
reference solution does not pass is broken, and every downstream number from it
is meaningless.

`evidence/nop/` scoring 0 proves the verifier MEASURES THE BUG. Read its
`error.txt`: it must name a test-failure count. If it reports an infrastructure
error, or if oracle and nop produce identical output, the environment is broken
and the task measures nothing. This is a known failure mode: an image
missing a native library makes both controls fail identically.

`evidence/attempts/` carries the difficulty claim. With no attempts there is NO
difficulty label, and `difficulty` in `task.toml` is an estimate. Say so rather
than let a reader quote a guess as a measurement.

## Gates enforced before packaging

Structure: the seven files, `schema_version = "1.1"`, `memory_mb`/`storage_mb`
rather than the 2.0 spelling.

Prompt: names an absolute path, contains no em dash, carries the canary.

README: sections for Difficulty, Solution, Verification and Relevant experience.

Isolation: `environment/` holds only the Dockerfile, so no verifier data reaches
the agent image; the Dockerfile severs the git remote and asserts
`HEAD == BASE_COMMIT`.

Verifier: writes `/logs/verifier/reward.txt` AND asserts a collection floor. A
runner that matches no files exits 0 having collected nothing and would score a
false 1.0; the floor is the only thing standing between that and a shipped lie.

Controls: oracle scores 1 and nop scores 0, both present.

The zip itself: no project name, no API keys, no host paths, oracle and nop
rewards present, and a runnable task inside.
