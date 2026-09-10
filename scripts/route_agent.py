"""Recommend a Codex sub-agent model and reasoning effort for a bounded task."""

from __future__ import annotations

import argparse
import json


def route(kind: str, subsystems: int, risk: str, ambiguity: str, graph: bool) -> dict[str, object]:
    if kind in {"release", "security", "causal-review", "architecture"}:
        model, effort = "gpt-6-astra", "xhigh" if risk == "high" or ambiguity == "high" else "high"
        role = "independent reviewer/coordinator"
    elif kind in {"implementation", "debugging", "verifier"} and (
        subsystems > 1 or risk == "high" or ambiguity == "high"
    ):
        model, effort, role = "gpt-5.6-sol", "xhigh" if ambiguity == "high" else "high", "builder"
    elif kind in {"implementation", "debugging", "documentation"}:
        model, effort, role = "gpt-5.6-terra", "high" if subsystems > 1 else "medium", "builder"
    else:
        model = "gpt-5.6-luna"
        effort = "medium" if ambiguity == "medium" or subsystems > 1 else "low"
        role = "read-only scout"

    discovery = ["codegraph status"]
    if graph:
        discovery += ["codegraph context/explore", "codegraph impact for edits"]
    discovery += ["rg --files for inventory/unindexed formats", "rg for exact literals only"]
    return {
        "model": model,
        "reasoning_effort": effort,
        "role": role,
        "discovery_order": discovery,
        "requires_independent_release_review": kind in {"release", "security", "causal-review"} or risk == "high",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kind", required=True, choices=[
        "discovery", "implementation", "debugging", "verifier", "documentation",
        "causal-review", "architecture", "security", "release",
    ])
    parser.add_argument("--subsystems", type=int, default=1)
    parser.add_argument("--risk", choices=["low", "medium", "high"], default="medium")
    parser.add_argument("--ambiguity", choices=["low", "medium", "high"], default="medium")
    parser.add_argument("--graph", action="store_true")
    args = parser.parse_args()
    if args.subsystems < 1:
        parser.error("--subsystems must be at least 1")
    print(json.dumps(route(args.kind, args.subsystems, args.risk, args.ambiguity, args.graph), indent=2))


if __name__ == "__main__":
    main()

