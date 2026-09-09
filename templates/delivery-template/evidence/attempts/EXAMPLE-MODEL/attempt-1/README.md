# attempt evidence (TEMPLATE)

One directory per model, `attempt-N` in the order run. Copy the whole trial:
`agent/trajectory.json`, `agent/vibe.txt` or the agent's own log, the entire
`verifier/` directory, and `result.json`.

Name the directory after the model, not after the job name used to run it.

## Before recording an attempt as a result, rule out a VOID

A harness or provider fault produces numbers IDENTICAL to a model that tried and
failed: the agent never edits, the verifier grades an untouched tree, and the
report reads like the no-op control. Only the agent log distinguishes them.

Three known causes, all excluded from pass@k:

- `Error: API error ... Invalid API key`, 0 turns
- `Error: Model stream ... ended without a finish reason`, 10 turns then 2
- a wrong env var name, so the agent never authenticated

Cheap tells: a real turn-capped attempt costs real money and takes real turns. A
run that finishes in 1 to 3 minutes for under a dollar is a void, not a result.

## What to record with every label

model, harness and version, turn cap, agent timeout, date, and the image. A
label measures one model, one scaffold, one date, never the task.

Check turns-to-first-edit before calling a task hard. An agent that spent 40 of
60 turns reading and never edited measured navigation, not capability.
