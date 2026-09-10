# Candidate claims

One line per repo/PR as soon as you start real research on it — before deep verification, not after. First claim wins; if you find your candidate already claimed here, drop it and pick another (see `CLAUDE.md` → "Trabajo en paralelo").

Format: `- <repo> #<PR> — <team member> — <agent: codex|claude-code> — <status: researching|building|done|dropped> — <date>`

- `docker/docker-agent` #4155 — JC — codex+claude-code — DROPPED, too easy — 2026-09-10 (pass@1 with openrouter/openai/gpt-5.6 via real Harbor terminus-2: reward=1.0, $0.62, 5m37s, real full fix (not a void, not a shortcut — correct walkSchema/$ref handling). Guideline rule: a pass@1 pass ends evaluation, kill or harden; not hardening this one, moving to the next candidate instead. Controls/environment work (evidence/, WSL2 kernel fix, --force-build) stays valid infra knowledge even though this specific candidate is dropped.)
- `kirodotdev/KiroCrew` #9734 — JC — claude-code — researching — 2026-09-10 (candidate to promote next now that docker-agent-strict-schema was dropped; pending user go-ahead to start building)
