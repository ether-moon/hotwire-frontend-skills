#!/usr/bin/env bash
set -euo pipefail

# {{PLUGIN_NAME}} CLI
# Accessible from skills and hooks via:
#   ${CLAUDE_PLUGIN_ROOT}/scripts/{{PLUGIN_NAME}} <command> [args]

VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Commands ─────────────────────────────────────────────────────────

cmd_help() {
  cat <<EOF
{{PLUGIN_NAME}} v${VERSION}

Usage: {{PLUGIN_NAME}} <command> [args]

Commands:
  version     Print version
  status      Check plugin installation status
  help        Show this help message
EOF
}

cmd_version() {
  echo "$VERSION"
}

cmd_status() {
  echo "Plugin root: ${PLUGIN_ROOT}"

  if [ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
    echo "Manifest:    OK"
  else
    echo "Manifest:    MISSING" >&2
  fi

  local skill_count
  skill_count=$(find "$PLUGIN_ROOT/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
  echo "Skills:      ${skill_count} found"

  if [ -f "$PLUGIN_ROOT/hooks/hooks.json" ]; then
    echo "Hooks:       OK"
  else
    echo "Hooks:       MISSING" >&2
  fi
}

# ── Dispatch ─────────────────────────────────────────────────────────

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  help|--help|-h)  cmd_help ;;
  version|--version|-v)  cmd_version ;;
  status)  cmd_status ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Run '{{PLUGIN_NAME}} help' for usage." >&2
    exit 1
    ;;
esac
