#!/bin/bash
set -euo pipefail

# UserPromptSubmit hook: injects additional context before each user prompt.
#
# Pattern: fast-exit when there's nothing to report, emit JSON when there is.
#
# Replace the condition and message below with your own logic.
# Common use cases:
#   - Remind the agent about a config/database it should query
#   - Warn about environment state (missing deps, wrong branch)
#   - Inject project-specific guidelines

# ── Fast exit: check your condition ──────────────────────────────────
# Example: exit early if a required file doesn't exist.
ROOT=""
if command -v git >/dev/null 2>&1; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
fi

if [ -z "$ROOT" ]; then
  exit 0
fi

# TODO: Replace with your own condition
# if [ ! -f "$ROOT/.your-config" ]; then
#   exit 0
# fi

# ── Emit context ─────────────────────────────────────────────────────
# Uncomment and customize the JSON below to inject context.
# cat <<EOF
# {
#   "additionalContext": "{{PLUGIN_NAME}} is active. Remember to check .your-config before making changes."
# }
# EOF

exit 0
