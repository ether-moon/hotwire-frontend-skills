---
title: "Turbo Drive Cache Lifecycle"
---

# Turbo Drive Cache Lifecycle

## Table of Contents

- [Overview](#overview)
- [How Turbo Drive Navigation Works](#how-turbo-drive-navigation-works)
- [Cache Snapshot Lifecycle](#cache-snapshot-lifecycle)
- [Implementation](#implementation)
  - [Cache-Control Headers](#cache-control-headers)
  - [Disabling Cache Per Page](#disabling-cache-per-page)
  - [Cleaning Up Before Caching](#cleaning-up-before-caching)
  - [Clearing the Cache Programmatically](#clearing-the-cache-programmatically)
- [Handling Stale Data](#handling-stale-data)
- [Pattern Card](#pattern-card)
- [Conditional Instant Click (Prefetch Control)](#conditional-instant-click-prefetch-control)

## Overview

Turbo Drive intercepts every link click and form submission within your application, fetching the new page via `fetch()` and swapping the `<body>` content without a full browser reload. To make back/forward navigation feel instant, Turbo Drive caches a snapshot of each page before navigating away. When the user navigates back, the cached snapshot is shown immediately as a "preview" while a fresh copy is fetched in the background.

This caching behavior is powerful but requires careful management. Stale data, leftover flash messages, open modals, and ephemeral UI state can all leak into cache snapshots and confuse users when they navigate back.

## How Turbo Drive Navigation Works

1. User clicks a link or submits a form.
2. Turbo Drive fires `turbo:before-visit` -- you can cancel navigation here.
3. Turbo Drive fires `turbo:visit` -- navigation begins.
4. The Turbo progress bar appears (if the response takes > 500ms).
5. Turbo Drive fetches the new page via `fetch()`.
6. Turbo Drive saves a snapshot of the current page just before rendering the new one.
7. The response `<body>` replaces the current `<body>`.
8. Turbo Drive fires `turbo:load` -- the new page is ready.

On back/forward navigation:
1. Turbo Drive restores the cached snapshot immediately (preview visit).
2. Turbo Drive fetches a fresh copy from the server in the background.
3. When the fresh copy arrives, it replaces the preview.

## Cache Snapshot Lifecycle

```
User clicks link
       |
       v
turbo:before-visit  (cancelable)
       |
       v
turbo:visit  (navigation begins)
       |
       v
Fetch new page via fetch()
       |
       v
turbo:before-cache  (clean up ephemeral UI here)
       |
       v
Snapshot of current page stored in cache
       |
       v
turbo:before-render  (new page about to render)
       |
       v
turbo:render  (new page rendered)
       |
       v
turbo:load  (navigation complete)
```

## Implementation

### Cache-Control Headers

Turbo Drive's internal snapshot cache is separate from the browser's HTTP cache. HTTP `Cache-Control` headers do **not** control Turbo's snapshot cache. Instead, use `<meta name="turbo-cache-control">` with `no-cache` (never show a preview) or `no-preview` (cache but skip preview on restoration) to control snapshot caching behavior.

To disable snapshot caching for a specific page, add the meta tag in your view:

```erb
<%# app/views/checkout/show.html.erb %>
<% content_for :head do %>
  <meta name="turbo-cache-control" content="no-cache">
<% end %>
```

### Disabling Cache Per Page

Use a `<meta>` tag to tell Turbo Drive not to cache a specific page. This is useful when the page contains sensitive or highly dynamic content.

```erb
<%# app/views/admin/dashboard/show.html.erb %>
<% content_for :head do %>
  <meta name="turbo-cache-control" content="no-cache">
<% end %>

<h1>Admin Dashboard</h1>
<%# ... real-time stats that should always be fresh ... %>
```

Or use the `data-turbo-temporary` attribute on individual elements so Turbo Drive automatically removes them before caching:

```erb
<div data-turbo-temporary>
  <%# This entire subtree will be automatically removed before the page is cached %>
  <div class="flash-messages">
    <% flash.each do |type, message| %>
      <div class="flash flash-<%= type %>"><%= message %></div>
    <% end %>
  </div>
</div>
```

### Cleaning Up Before Caching

The `turbo:before-cache` event fires just before Turbo Drive takes the page snapshot. Use it to remove ephemeral UI elements that should not appear when the user navigates back.

```javascript
// app/javascript/application.js
document.addEventListener("turbo:before-cache", () => {
  // Remove flash messages so they don't reappear on back navigation
  document.querySelectorAll(".flash").forEach(el => el.remove())

  // Close any open modals
  document.querySelectorAll("[data-modal].open").forEach(modal => {
    modal.classList.remove("open")
  })

  // Reset form states
  document.querySelectorAll("form").forEach(form => form.reset())
})
```

### Clearing the Cache Programmatically

When data changes significantly (e.g., after a bulk action), you may want to clear the Turbo Drive cache entirely so stale previews are never shown.

```javascript
// Clear the entire Turbo Drive page cache
Turbo.cache.clear()
```

You can trigger this from a Stimulus controller after an action completes:

```javascript
// app/javascript/controllers/bulk_action_controller.js
import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"  // Rails-specific; for non-Rails use: import * as Turbo from "@hotwired/turbo"

export default class extends Controller {
  afterComplete() {
    Turbo.cache.clear()
    Turbo.visit(window.location.href, { action: "replace" })
  }
}
```

## Handling Stale Data

The most common source of confusion with Turbo Drive caching is stale data appearing briefly during preview visits. Here are strategies to mitigate this:

1. **Mark volatile sections with `data-turbo-temporary`.** Content that changes frequently (notification counts, real-time data) will be automatically removed before caching.

2. **Use `turbo:before-cache` to clean up.** Remove flash messages, close modals, reset forms.

3. **Add a visual indicator during preview visits.** Turbo adds `data-turbo-preview` to the `<html>` element during preview visits. Use CSS to show a subtle loading indicator:

```css
/* app/assets/stylesheets/turbo.css */
html[data-turbo-preview] {
  opacity: 0.9;
  pointer-events: none;
}

html[data-turbo-preview] .turbo-preview-indicator {
  display: block;
}
```

4. **Disable caching for pages with forms or sensitive data.** Checkout flows, admin dashboards, and multi-step wizards should use `no-cache`.

## Pattern Card

### GOOD: Preview with Loading Indicator and Cache Cleanup

```erb
<%# app/views/layouts/application.html.erb %>
<html>
<head>
  <meta name="turbo-cache-control" content="no-preview">
  <%# Or allow preview but clean up: %>
</head>
<body>
  <div data-turbo-temporary>
    <% flash.each do |type, message| %>
      <div class="flash flash-<%= type %>"><%= message %></div>
    <% end %>
  </div>

  <div class="turbo-preview-indicator" style="display: none;">
    Loading fresh data...
  </div>

  <%= yield %>
</body>
</html>
```

```javascript
// Clean up before caching
document.addEventListener("turbo:before-cache", () => {
  document.querySelectorAll(".tooltip, .dropdown.open").forEach(el => el.remove())
})
```

This approach ensures cached previews never show stale flash messages or ephemeral UI, and the user sees a subtle indicator that fresh data is loading.

### BAD: No Cache Cleanup Leads to Stale Data

```erb
<%# app/views/layouts/application.html.erb %>
<body>
  <%# Flash messages will reappear on back navigation %>
  <% flash.each do |type, message| %>
    <div class="flash flash-<%= type %>"><%= message %></div>
  <% end %>

  <%# Open modals will be cached in their open state %>
  <div id="confirm-modal" class="modal open">
    <p>Are you sure?</p>
  </div>

  <%= yield %>
</body>
```

Without cache cleanup, users navigating back see stale flash messages ("Item saved!") that are no longer relevant, and modals frozen in their open state. This creates a confusing and broken-feeling experience.

## Conditional Instant Click (Prefetch Control)

Turbo 8 introduces InstantClick behavior, which is enabled by default on all navigations. While this speeds up navigation, it can cause stress on app servers. You can opt out globally or per-element using `data-turbo-prefetch="false"`, but this requires declaring it on each link individually or managing opt-out on parent elements.

For implicit opt-out scenarios such as sub-routes (e.g., `/admin` namespace) or links that trigger interactions, use the `turbo:before-prefetch` event to conditionally prevent prefetching.

### Basic Prefetch Control

Listen for the `turbo:before-prefetch` event and prevent its default action when conditions are met:

```js
document.addEventListener('turbo:before-prefetch', (event) => {
  if (
    event.target.href.match(/.*authors\//) ||
    'turboCommand' in event.target.dataset
  ) {
    event.preventDefault();
  }
});
```

### Strategy Pattern for Multiple Conditions

For extensibility with multiple conditions, use the Strategy pattern:

```js
class PrefetchCondition {
  constructor() {
    this.conditionStrategies = [];
  }

  addStrategy(strategy) {
    this.conditionStrategies.push(strategy);
  }

  shouldPreventDefault(event) {
    return this.conditionStrategies.some((strategy) => strategy(event));
  }
}

// Define strategies
const matchAuthorsStrategy = (event) =>
  event.target.href && event.target.href.match(/.*authors\//);
const turboCommandStrategy = (event) => 'turboCommand' in event.target.dataset;

const prefetchCondition = new PrefetchCondition();
prefetchCondition.addStrategy(matchAuthorsStrategy);
prefetchCondition.addStrategy(turboCommandStrategy);

document.addEventListener('turbo:before-prefetch', (event) => {
  if (prefetchCondition.shouldPreventDefault(event)) {
    event.preventDefault();
  }
});
```

The `PrefetchCondition` class maintains an array of strategy functions. The `shouldPreventDefault` method uses `Array.some` to check if any strategy matches the event. Strategies can be added dynamically, making the pattern extensible for multiple conditions.
