---
name: turbo-navigation-rendering
description: >-
  Implements Turbo Drive and Turbo Frames navigation: Drive cache lifecycle, tabbed navigation,
  pagination, infinite scroll, lazy loading, faceted search, Turbo 8 page refresh, render interception,
  view transitions, scroll restoration, partial page updates, and frame loading states.
  Use when building navigation, tabs, pagination, lazy-loaded content, SPA-like page transitions,
  infinite scroll, or rendering lifecycle.
  Cross-references: turbo-streams for real-time updates, hotwire-forms for form navigation,
  stimulus-controllers for client-side behavior, frontend-craft for triage.
allowed-tools: Read, Grep, Glob, Task, mcp__context7__resolve-library-id, mcp__context7__query-docs
---

# Turbo Navigation & Rendering

Implement navigation and rendering behavior with Turbo Drive and Turbo Frames. This skill covers request/response navigation, browser history, caching, rendering lifecycle, view transitions, and frame loading states.

## Core Workflow

### Step 1: Identify the Navigation Pattern

| Requirement | Pattern | Ref |
|---|---|---|
| Full page transitions with caching | Turbo Drive | `references/turbo-drive-cache-lifecycle.md` |
| Tabbed content sections | Turbo Frames tabs | `references/turbo-frames-tabbed-navigation.md` |
| Paginated lists | Turbo Frames pagination | `references/turbo-frames-pagination.md` |
| Deferred/below-fold content | Turbo Frames lazy loading | `references/turbo-frames-lazy-loading.md` |
| Filter/search interfaces | Turbo Frames faceted search | `references/turbo-frames-faceted-search.md` |
| Custom render/transition behavior | Render interception | `references/render-interception.md` |
| Scroll position after navigation | Scroll restoration | `references/scroll-position-restoration.md` |
| Dashboard with lazy-loaded widgets | Multiple | `examples/dashboard-lazy-widgets.md` |
| Search with faceted filters + pagination | Multiple | `examples/search-faceted-paginated.md` |
| Tabbed settings page | Multiple | `examples/settings-tabbed.md` |
| Live preview editor | Multiple | `examples/markdown-live-preview.md` |

Full catalog: `references/INDEX.md`. API details: `handbook/INDEX.md`.

### Step 2: Decide URL and History Ownership

Every navigation pattern must declare who owns the URL and history:

- **Turbo Drive**: Owns the full URL. Use for page-to-page navigation where the URL should change and the user expects a "new page."
- **Turbo Frames**: Scoped replacement. Use when only a section updates and context remains. Frame navigations do not change the browser URL unless `data-turbo-action` promotes them.

Rule of thumb: if the URL should change and the user expects a "new page," use Drive. If only a section updates, use Frames.

Decide `data-turbo-action` usage early:
- Omit for frame-only updates (no URL change)
- Use `"advance"` when the frame change should create a history entry
- Use `"replace"` when the frame change should update the current entry

### Step 3: Configure Caching and Rendering

- Use `<meta name="turbo-cache-control">` with `no-cache` or `no-preview` to control Turbo's snapshot cache per page.
- Use `data-turbo-cache="false"` on elements or pages that should never be cached.
- Clean transient UI (flash messages, modals, tooltips) in `turbo:before-cache`.
- For custom rendering, intercept `turbo:before-render` to gate transitions or animate between old and new snapshots.
- Use View Transitions API by adding `<meta name="view-transition" content="same-origin">` to the page `<head>` for cross-page animations.

### Step 4: Add Loading States and Fallbacks

- Turbo Frames set `[aria-busy="true"]` while loading — use CSS to show spinners or skeleton screens.
- Lazy-loaded frames should include placeholder content that displays until `src` loads. See `references/turbo-frames-lazy-loading.md`.
- For Drive navigations, use the Turbo progress bar or custom loading indicators.
- Apply a 200ms delay before showing spinners to avoid flash on fast loads.

### Step 5: Validate Back/Forward/Refresh Behavior

Every navigation pattern must be tested against:
- Browser back button
- Browser forward button
- Page refresh (F5/Cmd+R)
- Cache restore (back/forward cache)

Ensure URL state is canonical for filters and pagination. Verify that transient UI does not leak into cached snapshots.

## Guardrails

1. **Update active/tab state on load/render events, not click events.** Click fires before navigation completes — the response may fail or redirect.
   ```javascript
   // GOOD: React to turbo:frame-load
   document.addEventListener("turbo:frame-load", (event) => {
     updateActiveTab(event.target)
   })

   // BAD: React to click
   tab.addEventListener("click", () => { setActive(tab) })
   ```

2. **Keep URL state canonical for filters and pagination.** Reflect filter/page state in query parameters so bookmarks and back/forward work correctly.

3. **Use `turbo_frame_tag` helper, not raw HTML.** The helper generates correct attributes, handles `dom_id`, and avoids hand-typed string IDs.

4. **Set explicit frame IDs using `dom_id`.** Avoid hand-typed string IDs that can collide or become stale.

5. **Use `data-turbo-frame="_top"` to break out of frames.** Links that should navigate the full page must target `_top`.

6. **Never nest frames that target each other.** Frame targeting must be unidirectional.

7. **Avoid leaving transient UI artifacts in cache snapshots.** Clean up modals, tooltips, flash messages in `turbo:before-cache`.

8. **Use lazy loading deliberately.** Verify loading boundaries and IntersectionObserver behavior.

9. **Gate animations for preview/cache restores.** Do not re-animate content from cache.

10. **Prefer conditional Instant Click over disabling it globally.** Use `data-turbo-prefetch="false"` on specific links rather than turning off prefetch site-wide.

11. **Handle frame load failures gracefully.** Listen for `turbo:frame-missing` when a response lacks the expected frame ID. Provide fallback content or redirect.
    ```javascript
    // GOOD: Handle missing frame by visiting the response URL
    document.addEventListener("turbo:frame-missing", (event) => {
      event.preventDefault()
      event.detail.visit(event.detail.response.url)
    })
    ```


Out-of-scope requests: route back to `frontend-craft` for triage.
