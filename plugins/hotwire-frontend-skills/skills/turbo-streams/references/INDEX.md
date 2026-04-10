# Turbo Streams References

Real-time features with Turbo Streams in Rails applications.

## Hotwire Focus

- Turbo Streams
- ActionCable / Solid Cable
- View Transitions API

## Articles

- [Inline Stream Tags](inline-stream-tags.md) — Use `turbo_stream` helper methods in `.turbo_stream.erb` templates for multi-action HTTP responses. Covers append, prepend, replace, remove, update, before, and after actions.
- [Custom Stream Actions](custom-stream-actions.md) — Extend Turbo with custom actions beyond the 8 built-in ones by assigning functions to `StreamActions` properties (e.g., `StreamActions.myAction = function() { ... }`) and adding server-side helpers. Covers console_log, redirect, dispatch_event, set_cookie patterns, and localStorage-backed stream actions for persisting ephemeral client state.
- [Broadcasting Patterns](broadcasting-patterns.md) — Push real-time updates over WebSocket using `broadcasts_to`, `after_create_commit` callbacks, and `turbo_stream_from` in views. Covers tenant-scoped broadcasting, Solid Cable configuration, and real-time combobox updates via WebSocket outlets.
- [Turbo 8 Morphing](turbo-8-morphing.md) — Use DOM morphing to preserve form state, scroll position, and focus during page updates. Covers `turbo_refreshes_with`, permanent elements, and frame morphing.
- [Optimistic UI](optimistic-ui.md) — Show expected results before server confirmation using Stimulus controllers that update the DOM optimistically and handle rollback on failure. Includes ULID-based optimistic identity for client-generated IDs with server reconciliation.
- [List Animations with View Transitions](list-animations-view-transitions.md) — Animate stream insertions and removals using CSS `@starting-style`, the View Transitions API, and `turbo:before-stream-render` event hooks.
- [Custom Stream Actions: Video Playlist](custom-stream-actions-video-playlist.md) — Advanced custom stream action example for managing video playlist operations via Turbo Streams.
- [Inter-Tab Communication](inter-tab-communication.md) — Cross-tab state synchronization using BroadcastChannel API and localStorage events with Stimulus.

## Examples

- [Morphing Troubleshooting](../examples/morphing-troubleshooting.md) — Common morphing problems and their solutions.
