---
name: turbo-streams
description: >-
  Builds real-time features with Turbo Streams: inline stream tags, custom stream actions,
  broadcasting over WebSocket, Turbo 8 morphing, optimistic UI with reconciliation,
  ULID-based optimistic identity, cross-tab synchronization, and list animations.
  Use when adding real-time updates, broadcasting, morphing, optimistic state, live notifications,
  or server-pushed content changes.
  Cross-references: stimulus-controllers for client-side orchestration,
  turbo-navigation-rendering for frame navigation, hotwire-native for mobile broadcasting.
allowed-tools: Read, Grep, Glob, Task, mcp__context7__resolve-library-id, mcp__context7__query-docs
---

# Turbo Streams

Build real-time, push-driven features using Turbo Streams with Rails. This skill covers stream delivery, custom actions, broadcasting, morphing, optimistic UI, cross-tab sync, and list animations.

## Core Workflow

### Step 1: Identify What Needs Real-Time Updates

Look for lists, counters, notifications, status indicators, collaborative editing surfaces, and any UI that should reflect server-side changes without a full page reload.

### Step 2: Choose Delivery Method

- **HTTP response streams** (`.turbo_stream.erb` templates): For request/response cycles — form submissions, AJAX actions.
- **WebSocket broadcasts** (`broadcasts_to`, `turbo_stream_from`): For pushing updates to other users or tabs without a request.
- **Inline stream tags**: For client-side-only stream operations embedded in ERB.

### Step 3: Select the Stream Action

Pick the most precise action:

| Action | Use When |
|---|---|
| `append` / `prepend` | Adding to lists |
| `replace` | Swapping an entire element |
| `update` | Changing inner content only |
| `remove` | Deleting an element |
| `before` / `after` | Positional insertion |
| `morph` (method modifier on replace/update) | Preserving DOM state during complex updates |
| `refresh` | Full page morph refresh (Turbo 8) |
| Custom action | When built-in actions are insufficient |

Prefer default actions first. Add custom actions only when defaults cannot express the intent.

### Step 4: Implement With Proper Targets and Partials

- Use `dom_id` for target IDs.
- Extract reusable partials — render the same partial for initial load and stream updates.
- Scope broadcasts by tenant: `[Current.account, resource]` to prevent cross-account data leaks.
- Keep stream payloads small — send targeted partial updates, not entire page sections.

### Step 5: Verify Ordering, Idempotency, and Multi-Tab Behavior

- Test that out-of-order stream deliveries do not corrupt the UI.
- Ensure stream actions are idempotent — replaying the same action must not duplicate content.
- Verify behavior across multiple browser tabs with `BroadcastChannel` or `localStorage` for cross-tab sync.
- Validate failure modes for delayed or dropped messages.

## Guardrails

1. **Prefer `turbo_stream` response format over inline stream tags** when the update originates from a form submission or controller action.

2. **Scope broadcasts by tenant.** Prevent data leaking across accounts.
   ```ruby
   # GOOD: Scoped to account
   broadcasts_to [Current.account, :notifications]

   # BAD: Global broadcast
   broadcasts_to :notifications
   ```

3. **Use `morph` for complex updates** that need to preserve DOM state (form inputs, scroll position, focus).

4. **Always provide an HTML fallback** for non-Turbo clients using `respond_to` with both `format.turbo_stream` and `format.html`.

5. **Keep stream payloads small.** Send targeted partial updates, not entire page sections.

6. **Avoid embedding `<script>` tags inside stream templates.** Use custom stream actions instead.

7. **Do not use fixed timeouts as a proxy for stream delivery.** Listen for stream render events instead of `setTimeout`.

8. **Keep cross-tab sync explicit** using `BroadcastChannel` or `localStorage` — scope it to same-device semantics.

9. **Use view transitions only where animation meaningfully improves state-change clarity.**

10. **For optimistic UI, always have a reconciliation strategy.** The server response must correct any incorrect optimistic state. Use ULID-based identity when creating records optimistically.

11. **Handle ActionCable disconnects explicitly.** Listen for connection state changes and show a reconnection indicator. Do not silently drop updates.

## References

| Topic | File |
|---|---|
| Inline stream tags | `references/inline-stream-tags.md` |
| Custom stream actions | `references/custom-stream-actions.md` |
| Broadcasting (ActionCable/Solid Cable) | `references/broadcasting-patterns.md` |
| Turbo 8 morphing | `references/turbo-8-morphing.md` |
| Optimistic UI / ULID identity | `references/optimistic-ui.md` |
| List animations / View Transitions | `references/list-animations-view-transitions.md` |
| Video playlist custom actions | `references/custom-stream-actions-video-playlist.md` |
| Inter-tab communication | `references/inter-tab-communication.md` |
| Morphing troubleshooting | `examples/morphing-troubleshooting.md` |

Full catalog: `references/INDEX.md`. API details: `handbook/INDEX.md`.

Out-of-scope requests: route back to `frontend-craft` for triage.
