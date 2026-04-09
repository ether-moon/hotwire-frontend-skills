#!/usr/bin/env bash
set -euo pipefail

# ── Claude Code Plugin Initializer ───────────────────────────────────
# Creates a complete plugin project from templates.
# Run from the cc-plugin-template directory.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Error: templates/ directory not found. Run this script from the cc-plugin-template directory." >&2
  exit 1
fi

# ── Collect input ────────────────────────────────────────────────────

echo "Claude Code Plugin Initializer"
echo "=============================="
echo ""

read -rp "Marketplace name (kebab-case, e.g. my-tools): " MARKETPLACE_NAME
read -rp "Plugin name (kebab-case, e.g. my-plugin): " PLUGIN_NAME
read -rp "Plugin description: " PLUGIN_DESCRIPTION
read -rp "Author name: " AUTHOR_NAME
read -rp "GitHub owner (user or org): " GITHUB_OWNER

# Defaults
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)

# ── Determine output directory ───────────────────────────────────────

OUTPUT_DIR="$(pwd)"

echo ""
echo "Will create plugin in: ${OUTPUT_DIR}"
echo ""

# ── Helper: render a template file ───────────────────────────────────

render() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"
  sed \
    -e "s|{{MARKETPLACE_NAME}}|${MARKETPLACE_NAME}|g" \
    -e "s|{{PLUGIN_NAME}}|${PLUGIN_NAME}|g" \
    -e "s|{{PLUGIN_DESCRIPTION}}|${PLUGIN_DESCRIPTION}|g" \
    -e "s|{{AUTHOR_NAME}}|${AUTHOR_NAME}|g" \
    -e "s|{{GITHUB_OWNER}}|${GITHUB_OWNER}|g" \
    -e "s|{{YEAR}}|${YEAR}|g" \
    -e "s|{{MONTH}}|${MONTH}|g" \
    -e "s|{{DAY}}|${DAY}|g" \
    "$src" > "$dst"
}

# ── Create directory structure ───────────────────────────────────────

PLUGIN_DIR="${OUTPUT_DIR}/plugins/${PLUGIN_NAME}"

mkdir -p "${OUTPUT_DIR}/.claude-plugin"
mkdir -p "${OUTPUT_DIR}/.claude"
mkdir -p "${OUTPUT_DIR}/.github/workflows"
mkdir -p "${OUTPUT_DIR}/tests"
mkdir -p "${PLUGIN_DIR}/.claude-plugin"
mkdir -p "${PLUGIN_DIR}/skills/hello"
mkdir -p "${PLUGIN_DIR}/hooks"
mkdir -p "${PLUGIN_DIR}/scripts"
mkdir -p "${PLUGIN_DIR}/schema"
touch "${PLUGIN_DIR}/schema/.gitkeep"

# ── Render templates ─────────────────────────────────────────────────

# Marketplace & plugin manifests
render "$TEMPLATE_DIR/plugin/marketplace.json"  "${OUTPUT_DIR}/.claude-plugin/marketplace.json"
render "$TEMPLATE_DIR/plugin/plugin.json"       "${PLUGIN_DIR}/.claude-plugin/plugin.json"

# Skill
render "$TEMPLATE_DIR/skill/SKILL.md"           "${PLUGIN_DIR}/skills/hello/SKILL.md"

# Hooks
render "$TEMPLATE_DIR/plugin/hooks.json"        "${PLUGIN_DIR}/hooks/hooks.json"
render "$TEMPLATE_DIR/hook/on-prompt.sh"         "${PLUGIN_DIR}/hooks/on-prompt.sh"
chmod +x "${PLUGIN_DIR}/hooks/on-prompt.sh"

# CLI script
render "$TEMPLATE_DIR/script/cli.sh"            "${PLUGIN_DIR}/scripts/${PLUGIN_NAME}"
chmod +x "${PLUGIN_DIR}/scripts/${PLUGIN_NAME}"

# Tests
render "$TEMPLATE_DIR/tests/all.sh"             "${OUTPUT_DIR}/tests/all.sh"
chmod +x "${OUTPUT_DIR}/tests/all.sh"

# CI
render "$TEMPLATE_DIR/ci/ci.yml"                "${OUTPUT_DIR}/.github/workflows/ci.yml"

# Project files
render "$TEMPLATE_DIR/project/settings.json"    "${OUTPUT_DIR}/.claude/settings.json"
render "$TEMPLATE_DIR/project/gitignore"        "${OUTPUT_DIR}/.gitignore"
render "$TEMPLATE_DIR/project/CHANGELOG.md"     "${OUTPUT_DIR}/CHANGELOG.md"
render "$TEMPLATE_DIR/project/CLAUDE.md"        "${OUTPUT_DIR}/CLAUDE.md"
render "$TEMPLATE_DIR/project/AGENTS.md"       "${OUTPUT_DIR}/AGENTS.md"
render "$TEMPLATE_DIR/project/LICENSE"           "${OUTPUT_DIR}/LICENSE"

# ── Summary ──────────────────────────────────────────────────────────

echo "Done! Created plugin project at: ${OUTPUT_DIR}"
echo ""
echo "Structure:"
echo "  ./"
echo "  ├── .claude-plugin/marketplace.json"
echo "  ├── plugins/${PLUGIN_NAME}/"
echo "  │   ├── .claude-plugin/plugin.json"
echo "  │   ├── skills/hello/SKILL.md"
echo "  │   ├── hooks/{hooks.json, on-prompt.sh}"
echo "  │   ├── scripts/${PLUGIN_NAME}"
echo "  │   └── schema/"
echo "  ├── tests/all.sh"
echo "  ├── .github/workflows/ci.yml"
echo "  ├── .claude/settings.json"
echo "  ├── CLAUDE.md, AGENTS.md, CHANGELOG.md, LICENSE, .gitignore"
echo ""
echo "Next steps:"
echo "  git init && git add -A && git commit -m 'Initial plugin scaffold'"
echo "  bash tests/all.sh"
echo ""
echo "To add a new skill:"
echo "  mkdir plugins/${PLUGIN_NAME}/skills/my-skill"
echo "  # Create plugins/${PLUGIN_NAME}/skills/my-skill/SKILL.md"
echo ""
echo "To test locally with Claude Code:"
echo "  claude --plugin-dir plugins/${PLUGIN_NAME}"

# ── Cleanup: remove init.sh and templates ────────────────────────────
rm -rf "${SCRIPT_DIR}/templates"
rm -f "${SCRIPT_DIR}/init.sh"
