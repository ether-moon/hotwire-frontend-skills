# Hotwire Frontend Skills

A Claude Code plugin that teaches Claude how to build Rails frontends with Hotwire. 7 skills — 1 gateway that triages requests and 6 specialists covering Turbo, Stimulus, forms, media, and native bridge — each backed by curated reference articles, official handbook chapters, and troubleshooting cookbooks.

## Skills

| Skill | Domain | Knowledge |
|---|---|---|
| `frontend-craft` | Gateway — triage, routing, common principles | SKILL.md only |
| `turbo-navigation-rendering` | Drive, Frames, rendering lifecycle, view transitions | 7 refs, 7 handbook, 4 examples |
| `turbo-streams` | Streams, broadcasting, morphing, optimistic state | 8 refs, 2 handbook, 1 example |
| `stimulus-controllers` | Controller design, lifecycle, DOM, browser APIs | 9 refs, 11 handbook, 1 example |
| `hotwire-forms` | Form submission, validation, autosave, submit UX | 7 refs, 3 examples |
| `media-content` | Media playback, gallery, preview, rich content | 7 refs |
| `hotwire-native` | Native bridge, web/native boundary | 7 refs, 4 handbook, 1 example |

## How It Works

Ask Claude anything about Hotwire frontend development. The `frontend-craft` gateway skill classifies the problem, applies cross-cutting principles, and routes to the right specialist. Each specialist follows a 5-step workflow with GOOD/BAD code guardrails, loading only the references it needs.

```
User request
  → frontend-craft (classify, apply principles)
    → specialist skill (references + handbook + examples)
      → code with guardrails
```

## Install

Add to your `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": []
  },
  "extraKnownMarketplaces": {
    "hotwire-frontend-skills": {
      "source": { "source": "github", "repo": "ether-moon/hotwire-frontend-skills" }
    }
  },
  "enabledPlugins": {
    "hotwire-frontend-skills@hotwire-frontend-skills": true
  }
}
```

## Plugin Structure

```
plugins/hotwire-frontend-skills/
├── .claude-plugin/
│   └── plugin.json           # Plugin metadata (name, version, author)
├── skills/
│   ├── frontend-craft/       # Gateway skill
│   │   └── SKILL.md
│   ├── turbo-navigation-rendering/
│   │   ├── SKILL.md
│   │   ├── references/       # Pattern articles with GOOD/BAD examples
│   │   ├── handbook/         # Official Turbo documentation chapters
│   │   └── examples/         # Cookbooks and troubleshooting guides
│   ├── turbo-streams/
│   ├── stimulus-controllers/
│   ├── hotwire-forms/
│   ├── media-content/
│   └── hotwire-native/
├── hooks/
│   ├── hooks.json
│   └── on-prompt.sh
├── scripts/
└── schema/
```

### Knowledge Layers

Each specialist skill draws from up to three knowledge layers:

- **references/** — Curated pattern articles with concrete GOOD/BAD code examples
- **handbook/** — Official documentation chapters (Turbo, Stimulus, Hotwire Native)
- **examples/** — Cookbooks and troubleshooting guides for common scenarios

## Testing

```bash
bash tests/all.sh
```

Validates JSON syntax, plugin.json fields, skill frontmatter, and structural integrity.

CI runs automatically on push and PR to `main`.

## License

MIT
