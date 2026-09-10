# Candidate claims

One line per repo/PR as soon as you start real research on it — before deep verification, not after. First claim wins; if you find your candidate already claimed here, drop it and pick another (see `CLAUDE.md` → "Trabajo en paralelo").

Format: `- <repo> #<PR> — <team member> — <agent: codex|claude-code> — <status: researching|building|done|dropped> — <date>`

- `docker/docker-agent` #4155 — JC — codex+claude-code — controls verified with real Harbor, ready for paid runs pending user go-ahead — 2026-09-10 (oracle=1.0/no-op=0.0 confirmed via real `harbor run -e docker` trials, not a manual reproduction. Needed two env fixes first: WSL2 kernel lacked nftables fib support for network isolation, `--force-build` was needed because a cached image from an interrupted earlier build had an empty /app. Full real trial dirs in evidence/. Next: pass@1 with a user-supplied OpenRouter key.)
- `kirodotdev/KiroCrew` #9734 — JC — claude-code — researching — 2026-09-10 (pending user confirmation before building; alternates #9709/#9739 scouted, dropped in favor of this one)
