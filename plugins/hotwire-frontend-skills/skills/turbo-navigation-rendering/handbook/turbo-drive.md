---
title: "Navigate with Turbo Drive"
---

# Navigate with Turbo Drive

> Turbo Drive intercepts link clicks and form submissions, fetches in the background, and swaps `<body>` without full page reloads -- the successor to Turbolinks.

## Decision

Turbo Drive is **on by default** for all same-origin links and forms. Decide per-element with `data-turbo="false"` (opt-out) or flip globally with `Turbo.session.drive = false` then `data-turbo="true"` (opt-in). Form submissions must return **303 redirect** (POST) or use `data-turbo-frame` (GET).

## Visit Types

**Application visits** (advance / replace) -- triggered by link clicks or `Turbo.visit(url)`. Always issue a network request; may show a cache preview first.

- **advance** (default): pushes `history.pushState`
- **replace**: uses `history.replaceState` -- `<a href="/edit" data-turbo-action="replace">`

**Restoration visits** (restore) -- triggered by browser Back/Forward. Renders from cache if possible; restores scroll position. Cannot be canceled.

## Pattern

### Custom Rendering (morphing)

```javascript
addEventListener("turbo:before-render", (event) => {
  event.detail.render = (currentElement, newElement) => {
    Idiomorph.morph(currentElement, newElement)
  }
})
```

### Pausing Rendering (exit animations)

```javascript
document.addEventListener("turbo:before-render", async (event) => {
  event.preventDefault()
  await animateOut()
  event.detail.resume()
})
```

### Pausing Requests (auth headers)

```javascript
document.addEventListener("turbo:before-fetch-request", async (event) => {
  event.preventDefault()
  const token = await getSessionToken(window.app)
  event.detail.fetchOptions.headers["Authorization"] = `Bearer ${token}`
  event.detail.resume()
})
```

### Cancel a Visit Before It Starts

Listen for `turbo:before-visit`, check `event.detail.url`, call `event.preventDefault()`.
Restoration visits cannot be canceled.

### Non-GET Links and Confirmation

```html
<a href="/articles/54" data-turbo-method="delete"
   data-turbo-confirm="Are you sure?">Delete</a>
```

Prefer actual forms/buttons over `data-turbo-method` for accessibility.

### Disabling Turbo Drive

```html
<a href="/" data-turbo="false">Disabled</a>
<div data-turbo="false">
  <a href="/" data-turbo="true">Re-enabled</a>
</div>
```

### View Transitions

Both current and next page need: `<meta name="view-transition" content="same-origin" />`

Turbo adds `data-turbo-visit-direction` to `<html>`: `forward`, `back`, or `none`.

```css
html[data-turbo-visit-direction="forward"]::view-transition-old(sidebar):only-child {
  animation: slide-to-right 0.5s ease-out;
}
```

### Progress Bar

Appears after 500ms by default. Customize delay: `Turbo.setProgressBarDelay(200)`.

```css
.turbo-progress-bar { height: 5px; background-color: green; }
/* or hide: */ .turbo-progress-bar { visibility: hidden; }
```

Turbo also toggles `[aria-busy]` on `<html>` during navigation.

### Asset Tracking

```html
<link rel="stylesheet" href="/app-258e88d.css" data-turbo-track="reload">
<script src="/app-cbd3cd4.js" data-turbo-track="reload"></script>
```

- `reload` -- triggers full page reload when asset fingerprint changes
- `dynamic` -- removes `<link>`/`<style>` elements absent from the response (no reload)

### Force Full Reload

```html
<meta name="turbo-visit-control" content="reload">
```

### Scope to Root Path

```html
<meta name="turbo-root" content="/app">
```

## Form Submissions

Turbo Drive handles forms like link clicks but supports stateful POST requests.

**Event sequence**: `turbo:submit-start` -> `turbo:before-fetch-request` -> `turbo:before-fetch-response` -> `turbo:submit-end`

The submitter element is auto-disabled during submission. Disable all fields:

```js
addEventListener("turbo:submit-start", ({ target }) => {
  for (const field of target.elements) { field.disabled = true }
})
```

**After POST**: server must return **303 redirect**. Exceptions: 4xx/5xx render directly (validation errors, server errors). GET forms can render directly with `data-turbo-frame`.

**Streaming response**: server can return `Content-Type: text/vnd.turbo-stream.html` with `<turbo-stream>` elements instead of redirect.

## Prefetching

Enabled by default (Turbo v8+). Fires on `mouseenter` after 100ms delay.

```html
<!-- Disable globally -->
<meta name="turbo-prefetch" content="false">

<!-- Disable per-element -->
<a href="/expensive" data-turbo-prefetch="false">Slow page</a>
```

Disable conditionally:

```javascript
document.addEventListener("turbo:before-prefetch", (event) => {
  if (navigator.connection?.saveData || navigator.connection?.effectiveType === "2g") {
    event.preventDefault()
  }
})
```

### Preloading Into Cache

```html
<a href="/dashboard" data-turbo-preload>Dashboard</a>
```

Does not work on cross-origin links, framed links, `data-turbo="false"`, or `data-turbo-stream` links.

Distinguish preload requests via `X-Sec-Purpose: prefetch` header.

## Pitfalls

**GOOD**: POST form returns 303 redirect
**BAD**: POST form returns 200 with rendered HTML -- causes reload/URL issues

**GOOD**: `data-turbo-track="reload"` on versioned asset URLs
**BAD**: Deploying new CSS/JS without track attributes -- stale assets conflict

**GOOD**: `data-turbo="false"` on links to non-Turbo pages
**BAD**: Letting Turbo intercept links to third-party JS-heavy pages

**GOOD**: Use `requestSubmit()` for programmatic form submission (triggers Turbo + validation)
**BAD**: Use `submit()` -- bypasses Turbo interception and HTML validation

## Ignored Paths

URLs with a `.` in the last path segment (e.g., `/messages.67`) are ignored by Turbo unless they end in `.htm`, `.html`, `.xhtml`, or `.php`. Append `/` to force handling.
