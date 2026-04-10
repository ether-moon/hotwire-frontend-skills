#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }

echo "=== Plugin Structure Tests ==="

# ── marketplace.json ─────────────────────────────────────────────────
if [ -f "$ROOT/.claude-plugin/marketplace.json" ]; then
  if python3 -c "import json; json.load(open('$ROOT/.claude-plugin/marketplace.json'))" 2>/dev/null; then
    pass "marketplace.json is valid JSON"
  else
    fail "marketplace.json is invalid JSON"
  fi
else
  fail "marketplace.json not found"
fi

# ── plugin.json ──────────────────────────────────────────────────────
PLUGIN_DIR=$(find "$ROOT/plugins" -name "plugin.json" -path "*/.claude-plugin/*" 2>/dev/null | head -1)
if [ -n "$PLUGIN_DIR" ]; then
  if python3 -c "import json; d=json.load(open('$PLUGIN_DIR')); assert 'name' in d; assert 'version' in d" 2>/dev/null; then
    pass "plugin.json has name and version"
  else
    fail "plugin.json missing required fields"
  fi
else
  fail "plugin.json not found under plugins/"
fi

# ── hooks.json ───────────────────────────────────────────────────────
HOOKS_FILE=$(find "$ROOT/plugins" -name "hooks.json" 2>/dev/null | head -1)
if [ -n "$HOOKS_FILE" ]; then
  if python3 -c "import json; json.load(open('$HOOKS_FILE'))" 2>/dev/null; then
    pass "hooks.json is valid JSON"
  else
    fail "hooks.json is invalid JSON"
  fi
else
  fail "hooks.json not found"
fi

# ── Skills frontmatter ───────────────────────────────────────────────
SKILLS=$(find "$ROOT/plugins" -name "SKILL.md" 2>/dev/null)
if [ -n "$SKILLS" ]; then
  while IFS= read -r skill; do
    rel=$(echo "$skill" | sed "s|$ROOT/||")
    # Check YAML frontmatter exists
    if head -1 "$skill" | grep -q "^---"; then
      # Check required fields
      header=$(sed -n '1,/^---$/p' "$skill" | tail -n +2)
      if echo "$header" | grep -q "^name:"; then
        if echo "$header" | grep -q "^description:"; then
          pass "$rel has valid frontmatter"
        else
          fail "$rel missing 'description' in frontmatter"
        fi
      else
        fail "$rel missing 'name' in frontmatter"
      fi
    else
      fail "$rel missing YAML frontmatter"
    fi
  done <<< "$SKILLS"
else
  fail "No SKILL.md files found"
fi

# ── Skill count ──────────────────────────────────────────────────────
SKILL_COUNT=$(echo "$SKILLS" | wc -l | tr -d ' ')
if [ "$SKILL_COUNT" -eq 7 ]; then
  pass "Skill count is 7"
else
  fail "Expected 7 skills, found $SKILL_COUNT"
fi

# ── references/INDEX.md per specialist ───────────────────────────────
SKILLS_DIR="$ROOT/plugins/hotwire-frontend-skills/skills"
SPECIALISTS=("turbo-navigation-rendering" "turbo-streams" "stimulus-controllers" "hotwire-forms" "media-content" "hotwire-native")
for specialist in "${SPECIALISTS[@]}"; do
  if [ -f "$SKILLS_DIR/$specialist/references/INDEX.md" ]; then
    pass "$specialist has references/INDEX.md"
  else
    fail "$specialist missing references/INDEX.md"
  fi
done

# ── frontend-craft has NO references or handbook ─────────────────────
if [ -d "$SKILLS_DIR/frontend-craft/references" ]; then
  fail "frontend-craft should NOT have references/ directory"
else
  pass "frontend-craft has no references/"
fi
if [ -d "$SKILLS_DIR/frontend-craft/handbook" ]; then
  fail "frontend-craft should NOT have handbook/ directory"
else
  pass "frontend-craft has no handbook/"
fi

# ── handbook/INDEX.md for skills that have handbooks ─────────────────
HANDBOOK_SKILLS=("turbo-navigation-rendering" "turbo-streams" "stimulus-controllers" "hotwire-native")
for skill in "${HANDBOOK_SKILLS[@]}"; do
  if [ -f "$SKILLS_DIR/$skill/handbook/INDEX.md" ]; then
    pass "$skill has handbook/INDEX.md"
  else
    fail "$skill missing handbook/INDEX.md"
  fi
done

# ── CLI script ───────────────────────────────────────────────────────
CLI=$(find "$ROOT/plugins" -path "*/scripts/*" -type f -perm +111 2>/dev/null | head -1)
if [ -n "$CLI" ]; then
  if "$CLI" version >/dev/null 2>&1; then
    pass "CLI script responds to 'version' command"
  else
    fail "CLI script failed on 'version' command"
  fi
else
  echo "  SKIP: No executable CLI script found"
fi

# ── No old naming references ─────────────────────────────────────────
if grep -r "hwc-" "$SKILLS_DIR" --include="*.md" -l 2>/dev/null | head -1 | grep -q .; then
  fail "Found references to old hwc- prefixed names in skills/"
else
  pass "No hwc- prefixed name references in skills/"
fi

if grep -r "rails-architecture" "$SKILLS_DIR" --include="*.md" -l 2>/dev/null | head -1 | grep -q .; then
  fail "Found references to rails-architecture in skills/"
else
  pass "No rails-architecture references in skills/"
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
