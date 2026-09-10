# No attempts yet

Controls (oracle, no-op) are reproduced and pass in `evidence/oracle/` and
`evidence/nop/`. No paid model attempts have been run against this task yet.

`difficulty = "hard"` in `task.toml` is an estimate (see its comment and
`README.md`'s Difficulty section), not a measurement. It becomes a real label
only after pass@1/3/5 per `CLAUDE.md`'s evaluation stages, using an
OpenRouter credential the user provides interactively (not stored in this
repo or entered by an agent).
