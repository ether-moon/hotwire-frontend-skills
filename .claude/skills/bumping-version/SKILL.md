---
name: bumping-version
description: Bump the cc-plugin-template version with changelog update. Use when user asks to bump, version up, or release.
---

# Bumping Version

Bump the cc-plugin-template version: analyze changes, suggest semver level, get user confirmation, update files, and commit.

## Files

- **Changelog**: `CHANGELOG.md` → prepend new entry at top (after header)

## Workflow

### 1. Analyze changes since last bump

Run two separate Bash calls (no command substitution — Claude Code blocks `$(...)` patterns):

```bash
# Call 1: Find the last bump commit SHA
git log --oneline --grep="bump version" -1 --format="%H"
```

Read the SHA from the output, then use it in a second call:

```bash
# Call 2: Show commits since the last bump (replace <SHA> with output from Call 1)
git log --oneline <SHA>..HEAD
```

### 2. Suggest semver level

Based on the commits, suggest one of:
- **patch**: Bug fixes, template tweaks, doc improvements
- **minor**: New template files, new init.sh features
- **major**: Breaking changes to template structure or init.sh interface

Present the suggestion with rationale, then ask the user to choose:

```
[In user's language]

Changes since last bump:
- [commit summary 1]
- [commit summary 2]

Suggested: patch (reason)

Which level?
- [1] patch
- [2] minor
- [3] major
```

### 3. Update files

**Read current version** from `CHANGELOG.md` (extract from the latest `## [X.Y.Z]` header).

**Increment** the chosen semver component (reset lower components to 0 for minor/major).

**Update CHANGELOG.md**: Add new entry after the header block, before the first existing version entry. Follow the existing format:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added/Improved/Fixed

- **component**: Description of change
```

Use the appropriate changelog category:
- `Added` for new templates/features
- `Improved` for enhancements/refactors
- `Fixed` for bug fixes

### 4. Commit

```bash
git add CHANGELOG.md
git commit -m "chore: bump version to X.Y.Z"
```

## Rules

- Always create a **separate commit** for the bump (no mixing with feature commits)
- Use today's date for the changelog entry
- Keep changelog entries concise (one line per change)
