# AGENTS.md

{{PLUGIN_NAME}} — {{PLUGIN_DESCRIPTION}}

## Plugin Structure

- `plugins/{{PLUGIN_NAME}}/skills/` — Skill definitions (SKILL.md files)
- `plugins/{{PLUGIN_NAME}}/hooks/` — Lifecycle hooks (hooks.json + shell scripts)
- `plugins/{{PLUGIN_NAME}}/scripts/` — Bundled CLI tools
- `plugins/{{PLUGIN_NAME}}/schema/` — Asset files (SQL, config templates, etc.)

## Skill Format

Every skill is a `SKILL.md` with YAML frontmatter:

```yaml
---
name: skill-name
description: "One-line description"
argument-hint: "[optional args]"
---
```

Followed by markdown sections: When This Skill Runs, Prerequisites, Allowed Tools, Input, Output, Execution Steps, Error Handling, Constraints.

## Testing

```bash
bash tests/all.sh
```
