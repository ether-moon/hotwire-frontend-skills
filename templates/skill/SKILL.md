---
name: hello
description: "Greets the user and confirms the plugin is installed correctly. A starter skill — replace with your own."
argument-hint: "[name]"
---

# hello

A diagnostic skill that confirms {{PLUGIN_NAME}} is installed and working.

## When This Skill Runs

Invoke via `/{{PLUGIN_NAME}}:hello` or `/{{PLUGIN_NAME}}:hello Alice`.

## Prerequisites

None.

## Allowed Tools

`Bash` (read-only commands only).

## Input

| Parameter | Source | Required |
|---|---|---|
| `name` | Skill argument | No (default: `"World"`) |

## Execution Steps

### Step 1: Parse argument

Extract the name from the skill argument. If empty, use `"World"`.

### Step 2: Greet

Print: `Hello, {name}! {{PLUGIN_NAME}} is working.`

### Step 3: List available skills

```bash
ls -d "${CLAUDE_PLUGIN_ROOT}/skills/"*/ 2>/dev/null | xargs -I{} basename {} | sort
```

## Error Handling

- If `CLAUDE_PLUGIN_ROOT` is unset, inform the user the plugin may not be installed correctly.

## Constraints

- MUST NOT modify any files.
- MUST NOT make network requests.
