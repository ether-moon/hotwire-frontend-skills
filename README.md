# Claude Code Plugin Template

A project scaffold generator for Claude Code plugins and marketplaces.

## Quick Start

```bash
git clone <this-repo> cc-plugin-template
cd cc-plugin-template
bash init.sh
```

The script will ask for:

| Prompt | Example | Used for |
|---|---|---|
| Marketplace name | `my-tools` | Top-level directory, marketplace.json, settings.json |
| Plugin name | `my-plugin` | Plugin directory, plugin.json, CLI script, skill prefix |
| Plugin description | `A helpful plugin` | marketplace.json, plugin.json |
| Author name | `your-name` | plugin.json, LICENSE |
| GitHub owner | `your-github` | settings.json (marketplace source) |

## What Gets Generated

```
my-tools/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace manifest
├── plugins/
│   └── my-plugin/
│       ├── .claude-plugin/
│       │   └── plugin.json       # Plugin metadata (name, version, author)
│       ├── skills/
│       │   └── hello/
│       │       └── SKILL.md      # Example skill (replace with your own)
│       ├── hooks/
│       │   ├── hooks.json        # Hook registrations
│       │   └── on-prompt.sh      # Example UserPromptSubmit hook
│       ├── scripts/
│       │   └── my-plugin         # CLI tool (bash)
│       └── schema/               # Asset files (SQL, configs, etc.)
├── tests/
│   └── all.sh                    # Validates plugin structure
├── .github/workflows/
│   └── ci.yml                    # Runs tests on push/PR
├── .claude/settings.json         # Self-registers marketplace for dogfooding
├── CLAUDE.md                     # Agent directives
├── CHANGELOG.md
├── LICENSE (MIT)
└── .gitignore
```

## Adding a Skill

Create a directory under `plugins/<name>/skills/` with a `SKILL.md`:

```bash
mkdir plugins/my-plugin/skills/greet
```

```markdown
---
name: greet
description: "Greets the user by name"
argument-hint: "[name]"
---

# greet

## When This Skill Runs
Invoke via `/my-plugin:greet Alice`.

## Allowed Tools
`Bash` (read-only).

## Execution Steps
1. Parse the name argument (default: "World")
2. Print "Hello, {name}!"

## Constraints
- MUST NOT modify files.
```

### Skill Frontmatter Fields

| Field | Required | Description |
|---|---|---|
| `name` | Yes | Kebab-case identifier. Used as `/plugin:name` |
| `description` | Yes | One-line description. Shown in skill lists |
| `argument-hint` | No | Syntax hint (e.g. `[file-path]`) |
| `user-invocable` | No | Default `true`. Set `false` for internal-only skills |

## Adding a Hook

Edit `plugins/<name>/hooks/hooks.json` to register new hooks:

```json
{
  "hooks": {
    "UserPromptSubmit": [...],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/my-hook.sh"
          }
        ]
      }
    ]
  }
}
```

Available hook points: `UserPromptSubmit`, `PreToolUse`, `PostToolUse`.

Hook scripts emit JSON to inject context:

```json
{ "additionalContext": "Your message here" }
```

## Adding a CLI Command

Add subcommands to `plugins/<name>/scripts/<plugin-name>`:

```bash
cmd_my_command() {
  echo "Running my command with args: $*"
}

# Add to the case dispatch:
case "$COMMAND" in
  my-command)  cmd_my_command "$@" ;;
  ...
esac
```

Reference from skills via `${CLAUDE_PLUGIN_ROOT}/scripts/<plugin-name> my-command`.

## Testing

```bash
cd my-tools
bash tests/all.sh
```

Tests validate: JSON syntax, plugin.json fields, skill frontmatter, CLI responsiveness.

## Publishing

1. Push to GitHub
2. Users install via `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "my-tools": {
      "source": { "source": "github", "repo": "your-github/my-tools" }
    }
  },
  "enabledPlugins": {
    "my-plugin@my-tools": true
  }
}
```

## Variables Available in Hooks & Skills

| Variable | Description |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to the installed plugin directory |
| `${CLAUDE_PLUGIN_DATA}` | Persistent data directory (survives plugin updates) |

## License

MIT
