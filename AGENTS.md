# AGENTS.md

hotwire-frontend-skills — 7 skills (1 gateway + 6 specialists) for building Rails frontend with Hotwire.

## Architecture

**Gateway**: `frontend-craft` triages broad/ambiguous requests, applies common principles, and routes to specialist skills.

**Specialists**: Each owns a domain with three knowledge layers:
- `references/` — Pattern articles with GOOD/BAD code examples
- `handbook/` — Official documentation chapters (Turbo, Stimulus, Hotwire Native)
- `examples/` — Cookbooks and troubleshooting guides

## Skills

| Skill | Role | Knowledge |
|---|---|---|
| `frontend-craft` | Gateway — triage, routing, common principles | SKILL.md only (no refs) |
| `turbo-navigation-rendering` | Drive, Frames, rendering lifecycle, view transitions | 7 refs, 7 handbook, 4 examples |
| `turbo-streams` | Streams, broadcasting, morphing, optimistic state | 8 refs, 2 handbook, 1 example |
| `stimulus-controllers` | Controller design, lifecycle, DOM, browser APIs | 9 refs, 11 handbook, 1 example |
| `hotwire-forms` | Form submission, validation, autosave, submit UX | 7 refs, 3 examples |
| `media-content` | Media playback, gallery, preview, rich content | 7 refs |
| `hotwire-native` | Native bridge, web/native boundary | 7 refs, 4 handbook, 1 example |

## Plugin Structure

- `plugins/hotwire-frontend-skills/skills/` — Skill definitions (SKILL.md + knowledge layers)
- `plugins/hotwire-frontend-skills/hooks/` — Lifecycle hooks (hooks.json + shell scripts)
- `plugins/hotwire-frontend-skills/scripts/` — Bundled CLI tools
- `plugins/hotwire-frontend-skills/schema/` — Asset files

## Skill Format

Every skill is a `SKILL.md` with YAML frontmatter:

```yaml
---
name: skill-name
description: "Concise description with cross-references"
allowed-tools: Read, Grep, Glob, Task
---
```

Body structure:
- **Gateway** (frontend-craft): Role → Routing Table → Common Principles → Overlap Resolution → Escalation
- **Specialists**: Role → Core Workflow (5 steps) → Guardrails (GOOD/BAD code) → References table → Escalation

## Testing

```bash
bash tests/all.sh
```
