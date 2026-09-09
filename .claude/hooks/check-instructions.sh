#!/usr/bin/env bash
# PreToolUse hook (Bash, filtered to `git commit *`): blocks the commit if any
# staged instruction.md is missing the terminal-bench canary string or
# contains an em dash (0 of 89 published TB2.1 instructions have one).
set -u
cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || true

FILES=$(git diff --cached --name-only --diff-filter=ACM -- '*instruction.md' 2>/dev/null)
[ -z "$FILES" ] && exit 0

PROBLEMS=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if ! grep -q "terminal-bench-canary GUID" "$f"; then
    PROBLEMS="${PROBLEMS}${f}: missing terminal-bench canary string"$'\n'
  fi
  if grep -q $'\xe2\x80\x94' "$f"; then
    PROBLEMS="${PROBLEMS}${f}: contains an em dash (not allowed in instruction.md)"$'\n'
  fi
done <<< "$FILES"

if [ -n "$PROBLEMS" ]; then
  REASON_JSON=$(printf '%s' "$PROBLEMS" | python -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$REASON_JSON"
fi
