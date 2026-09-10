# Adaptive multi-agent routing

This workflow chooses the cheapest model that can safely own the next decision.
It is a routing policy, not a promise that every task needs several agents.

| Work shape | Owner | Effort | Preferred discovery |
|---|---|---:|---|
| Exact inventory or bounded repository reconnaissance | Luna | low-medium | `codegraph files/status`, then `rg --files` for uncovered formats |
| Local change with explicit tests and one subsystem | Terra | medium | graph context plus direct reads |
| Cross-file implementation or verifier/debugging work | Sol | high-xhigh | graph impact/call paths, focused execution |
| Contract conflict, adversarial audit, security, release decision | Astra | high-xhigh | primary sources, independent verification |

## Routing signals

The local router in `scripts/route_agent.py` uses five signals: work kind,
number of subsystems, ambiguity, consequence of error, and whether a code graph
is available. It deliberately routes release, security, and causal evaluation
decisions to Astra. A large file count alone does not imply a stronger model.

Examples:

```powershell
python scripts/route_agent.py --kind discovery --risk low --ambiguity low --graph
python scripts/route_agent.py --kind implementation --subsystems 2 --risk medium --ambiguity medium --graph
python scripts/route_agent.py --kind release --risk high --ambiguity high
```

The output is a recommendation for the coordinator. Runtime system policy and
the models available in the current client remain authoritative.

## Tool boundary

CodeGraph is best for symbol definitions, callers, callees, dependency impact,
and affected tests. Exact text search remains better for secrets, canary text,
version strings, schema fields, filenames, Markdown, Office packages, and other
formats absent from the index. Run `codegraph sync` after branch switches or
bulk changes if `status` is stale.

Graphify can add document-level semantic relationships when installed and
benchmarked locally. It is not installed on this machine today, so this repo
uses the already working CodeGraph index rather than depending on an unverified
tool.

## Claude Code implementation of this policy

The role names above (Luna/Terra/Sol/Astra) come from the Codex-side router in
`scripts/route_agent.py`. Claude Code has no equivalent CLI, but the same
routing policy maps onto real Claude Code primitives:

| Role | Claude Code mechanism | Model | Effort |
|---|---|---|---|
| Luna (scout) | `.claude/agents/luna-scout.md` | haiku | low |
| Terra (local build) | primary session | sonnet | default |
| Sol (cross-file build) | `Agent` tool, general-purpose, `model: "sonnet"` | sonnet | high (via prompt) |
| Astra (independent review) | `.claude/agents/astra-reviewer.md` | opus | xhigh |

Custom subagent frontmatter supports an `effort` field directly (`low` /
`medium` / `high` / `xhigh` / `max`), so the effort column is not just a
convention here, it is set on the agent definition itself. See `CLAUDE.md` for
the invocation table.

