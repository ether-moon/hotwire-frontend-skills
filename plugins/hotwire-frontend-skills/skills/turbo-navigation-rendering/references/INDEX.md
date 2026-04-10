# Turbo Navigation & Rendering References

Navigation and rendering patterns with Turbo Drive and Turbo Frames.

## Hotwire Focus

- Turbo Drive
- Turbo Frames
- View Transitions API

## Articles

- [Turbo Drive Cache Lifecycle](turbo-drive-cache-lifecycle.md) — How Turbo Drive intercepts links, caches page snapshots, and restores them for instant preview navigations. Covers Cache-Control headers, snapshot cleanup, stale data prevention, and conditional Instant Click prefetch control.
- [Turbo Frames Tabbed Navigation](turbo-frames-tabbed-navigation.md) — Implementing tabbed content sections where each tab loads its content into a shared Turbo Frame without full page navigation. Covers active state management and back button behavior.
- [Turbo Frames Pagination](turbo-frames-pagination.md) — Frame-scoped pagination that updates only the list content without reloading the entire page. Includes infinite scroll alternative using IntersectionObserver.
- [Turbo Frames Lazy Loading](turbo-frames-lazy-loading.md) — Deferred content loading with `loading: :lazy` on Turbo Frames. Covers placeholder content, lifecycle events, and performance optimization.
- [Turbo Frames Faceted Search](turbo-frames-faceted-search.md) — Building filter and search interfaces where controls update a results frame without page reload. Covers auto-submit, URL parameter preservation, and combined filter logic.
- [Render Interception](render-interception.md) — Intercepting Turbo Drive's rendering pipeline with `turbo:before-render` for custom page transitions, animations, and custom render functions. Covers pausing rendering, replacing the render function, and cache/preview handling.
- [Scroll Position Restoration](scroll-position-restoration.md) — Preserving and restoring scroll position across Turbo Frame navigations and back/forward cache restores.
