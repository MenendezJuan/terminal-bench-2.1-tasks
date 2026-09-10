# Agent operating guide

Read `AUDIT_2026-09-09.md` and the supplied guideline before authoring a task.
The private delivery contract is still unresolved; do not invent a hybrid schema.

## Discovery order

1. Run `codegraph status`. If the index is current, use `codegraph context`,
   `explore`, `node`, `callers`, `callees`, and `impact` for code relationships.
2. Use `rg --files` for repository inventory and non-code formats that CodeGraph
   did not index. Use `rg` for exact literals, identifiers, secrets, and policy
   wording.
3. Read the small set of source files selected by those tools. Treat a
   low-confidence semantic match as a lead, never as complete evidence.

CodeGraph currently indexes Python only in this scaffold. Markdown, DOCX, XLSX,
TOML, shell, and Docker contract checks still require format-aware inspection.

## Model and effort routing

- **Luna, low/medium:** read-only scouting, file inventories, symbol maps,
  metadata extraction, and bounded classification. It may shortlist evidence;
  it does not decide solvability, causal validity, or release readiness.
- **Terra, medium/high:** routine implementation with a clear contract and
  localized tests; documentation and mechanical refactors.
- **Sol, high/xhigh:** cross-file implementation, verifier design, debugging
  non-local failures, and tasks with several interacting constraints.
- **Astra, high/xhigh:** architecture, adversarial review, contract conflicts,
  security, causal run classification, and final release integration. Reserve
  `max` or `ultra` for unusually novel or release-critical ambiguity.

Escalate one level when the task crosses subsystems, the acceptance contract is
ambiguous, evidence conflicts, or a failed attempt lacks a clear causal chain.
Lower effort after the problem is localized and the next action is mechanical.

## Multi-agent protocol

Use multiple agents only when the work can be divided without conflicting
writes. The normal sequence is:

1. Coordinator states the acceptance criteria and protected paths.
2. Luna scout returns a read-only evidence packet.
3. Terra or Sol implements one bounded change set.
4. Astra independently reviews the final diff and validation evidence for a
   high-risk or release-bound change.

Parallel writers use separate git worktrees. A scout may run beside one writer
because it is read-only. Every handoff must include: objective, paths inspected,
symbols or contract clauses involved, commands/evidence, unresolved risks, and
the recommended next action.

Do not count infrastructure-invalid model attempts. Replace them privately and
publish only consecutively numbered, valid, comparable attempts. Preserve the
raw-to-public alias map outside the client package.

