# Stimulus Controllers References

Controller design patterns for Stimulus.js in Rails applications.

## Hotwire Focus

- Stimulus.js
- Controller lifecycle
- Values API
- Targets API
- Outlets API
- Action descriptors

## Articles

- [Lifecycle: connect and disconnect](lifecycle-connect-disconnect.md) — Practical lifecycle patterns beyond the API spec: Turbo re-entry handling, MutationObserver guards, third-party library integration, and setup/teardown gotchas.
- [Values and valueChanged Callbacks](values-changed-callbacks.md) — Reactive UI patterns with valueChanged callbacks: keeping DOM in sync with state, Turbo cache interaction, and complex Array/Object state management.
- [Targets and Target Callbacks](targets-target-callbacks.md) — Target callback patterns for dynamic content: targetConnected/targetDisconnected with Turbo Streams, dynamic list management, and nested controller scoping.
- [Outlets API](outlets-api.md) — Outlet communication patterns: lifecycle callbacks, bidirectional coordination, and when to choose outlets vs events vs globals.
- [Action Parameters and Keyboard Events](action-parameters-keyboard.md) — Passing typed data from HTML to action handlers with action parameters. Covers keyboard event filters, action options, and descriptor syntax.
- [Production-Ready Controllers](production-controllers.md) — Six battle-tested controller patterns from 37signals: clipboard, auto-click, toggle-class, auto-submit, dialog, and local-time. Each under 50 lines.
- [Core Web Vitals](core-web-vitals.md) — How Stimulus impacts LCP, FID/INP, and CLS. Covers lazy controller loading, async initialization, and performance-conscious patterns.
- [Auto-Sorting with MutationObserver](auto-sorting-mutation-observer.md) — Using MutationObserver in Stimulus to automatically sort DOM elements when new items arrive via WebSocket or Turbo Streams.
- [Web Share API](web-share-api.md) — Integrating the native browser Web Share API with Stimulus for platform-aware sharing functionality.

## Examples

- [Anti-Patterns](../examples/anti-patterns.md) — Common Stimulus anti-patterns and their fixes.
