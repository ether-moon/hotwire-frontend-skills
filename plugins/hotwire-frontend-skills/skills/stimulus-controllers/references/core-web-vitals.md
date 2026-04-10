---
title: "Core Web Vitals"
---

# Core Web Vitals

## Table of Contents

- [Overview](#overview)
- [Implementation](#implementation)
  - [How Stimulus Impacts Each Metric](#how-stimulus-impacts-each-metric)
  - [Lazy Controller Loading](#lazy-controller-loading)
  - [Async Initialization in connect()](#async-initialization-in-connect)
  - [Turbo Load vs DOMContentLoaded](#turbo-load-vs-domcontentloaded)
  - [Avoiding Layout Shifts From Controllers](#avoiding-layout-shifts-from-controllers)
  - [Profiling Stimulus Performance](#profiling-stimulus-performance)
- [Pattern Card](#pattern-card)

## Overview

Stimulus is lightweight by design, but controller initialization can still impact Core Web Vitals if not managed carefully.

| Metric | What It Measures | How Stimulus Can Help/Hurt |
|--------|-----------------|---------------------------|
| **LCP** (Largest Contentful Paint) | Time to render the largest visible element | Large JS bundles delay parsing; many controllers connecting at once block the main thread |
| **INP** (Interaction to Next Paint) | Responsiveness to user interactions | Heavy `connect()` logic or synchronous operations in action handlers increase latency |
| **CLS** (Cumulative Layout Shift) | Visual stability during load | Controllers that modify layout (add/remove elements, change sizes) after initial paint cause shifts |

**Key principle:** Stimulus controllers should enhance already-rendered HTML. If the page looks correct before JavaScript loads, Stimulus cannot negatively impact LCP or CLS. Problems arise when controllers create, move, or resize content.

## Implementation

### How Stimulus Impacts Each Metric

**LCP: Largest Contentful Paint**

Stimulus itself is small (~15 KB minified + gzipped). The risk comes from:

- Importing heavy dependencies inside controllers (charting libraries, rich text editors).
- Registering many controllers that all connect on page load.
- Running expensive DOM operations in `connect()` that block rendering.

**INP: Interaction to Next Paint**

Action handlers run on the main thread. If a handler takes more than 200ms, the user perceives lag. Risks:

- Synchronous computation in action handlers.
- DOM manipulation that triggers forced layout/reflow.
- Network requests that block the handler from completing.

**CLS: Cumulative Layout Shift**

Controllers that modify the visible layout after the page renders cause CLS. Risks:

- `connect()` methods that add/remove elements or change dimensions.
- Image/content loading that changes container sizes.
- Toggling visibility of elements above the fold.

### Lazy Controller Loading

Instead of registering all controllers upfront, load them on demand:

```javascript
// app/javascript/controllers/index.js

// GOOD: Lazy registration for heavy controllers
import { application } from "./application"

// Always register lightweight controllers eagerly
import ClipboardController from "./clipboard_controller"
import ToggleController from "./toggle_controller"
application.register("clipboard", ClipboardController)
application.register("toggle", ToggleController)

// Lazy-load heavy controllers only when their elements appear
const lazyControllers = {
  "chart": () => import("./chart_controller"),
  "rich-text": () => import("./rich_text_controller"),
  "map": () => import("./map_controller")
}

// Use a MutationObserver to detect when lazy controller elements appear
const observer = new MutationObserver((mutations) => {
  for (const mutation of mutations) {
    for (const node of mutation.addedNodes) {
      if (node.nodeType !== Node.ELEMENT_NODE) continue

      const controllerElements = node.matches("[data-controller]")
        ? [node]
        : [...node.querySelectorAll("[data-controller]")]

      for (const element of controllerElements) {
        const names = element.dataset.controller.split(" ")
        for (const name of names) {
          if (lazyControllers[name]) {
            lazyControllers[name]().then(module => {
              application.register(name, module.default)
            })
            delete lazyControllers[name] // Only load once
          }
        }
      }
    }
  }
})

observer.observe(document.body, { childList: true, subtree: true })

// Also check elements already in the DOM
document.querySelectorAll("[data-controller]").forEach(element => {
  const names = element.dataset.controller.split(" ")
  for (const name of names) {
    if (lazyControllers[name]) {
      lazyControllers[name]().then(module => {
        application.register(name, module.default)
      })
      delete lazyControllers[name]
    }
  }
})
```

**Simpler approach with Stimulus's built-in lazy loading (stimulus-loading):**

```javascript
// If using @hotwired/stimulus with importmap or esbuild
// The stimulus-loading library provides autoloading:
import { application } from "./application"
import { eagerLoadControllersFrom, lazyLoadControllersFrom } from "@hotwired/stimulus-loading"

// Eager load controllers in the controllers directory
eagerLoadControllersFrom("controllers", application)

// Or lazy load them (registers when element with data-controller appears)
lazyLoadControllersFrom("controllers", application)
```

### Async Initialization in connect()

When `connect()` must perform expensive work, defer it to avoid blocking the main thread:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { initialized: { type: Boolean, default: false } }

  connect() {
    if (!this.initializedValue) {
      // Defer heavy initialization to the next idle period
      if ("requestIdleCallback" in window) {
        this.idleCallbackId = requestIdleCallback(() => this.heavyInit())
      } else {
        this.timeoutId = setTimeout(() => this.heavyInit(), 0)
      }
    }
  }

  disconnect() {
    if (this.idleCallbackId) {
      cancelIdleCallback(this.idleCallbackId)
    }
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
    }
  }

  heavyInit() {
    // Expensive computation or third-party library setup
    this.initializedValue = true
  }
}
```

For controllers that fetch data on connect, use `AbortController` for cleanup:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    this.abortController = new AbortController()
    this.loadContent()
  }

  disconnect() {
    this.abortController.abort()
  }

  async loadContent() {
    try {
      const response = await fetch(this.element.dataset.url, {
        signal: this.abortController.signal
      })
      const html = await response.text()
      this.contentTarget.innerHTML = html
    } catch (error) {
      if (error.name !== "AbortError") {
        console.error("Failed to load content:", error)
      }
    }
  }
}
```

### Turbo Load vs DOMContentLoaded

When using Turbo Drive, never listen for `DOMContentLoaded`. It only fires on the initial page load, not on subsequent Turbo navigations.

```javascript
// BAD: Only runs on the first page load
document.addEventListener("DOMContentLoaded", () => {
  // This code never runs again after Turbo navigations
})

// BAD: turbo:load fires on every navigation including cache restores
document.addEventListener("turbo:load", () => {
  // This runs on every navigation, potentially re-initializing things
})

// GOOD: Use Stimulus lifecycle hooks -- they handle everything
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Runs on initial load AND after Turbo navigations
    // Runs when the element appears in a Turbo Frame
    // Runs when a Turbo Stream adds the element
    // Automatically cleans up in disconnect()
  }
}
```

**Exception:** Some global setup (analytics, error tracking) legitimately needs to run once and listen to navigation events. For these, use `turbo:load` at the application level, outside of Stimulus:

```javascript
// app/javascript/application.js
document.addEventListener("turbo:load", () => {
  // Track page view in analytics
  if (window.analytics) {
    window.analytics.page()
  }
})
```

### Avoiding Layout Shifts From Controllers

Controllers should not cause visible layout changes after the page renders:

```javascript
import { Controller } from "@hotwired/stimulus"

// GOOD: Controller enhances existing content without layout shifts
export default class extends Controller {
  static targets = ["time"]

  connect() {
    // Replacing text content does not cause layout shift
    // because the element already occupies space
    this.timeTargets.forEach(target => {
      const date = new Date(target.dateTime)
      target.textContent = date.toLocaleDateString()
    })
  }
}
```

```html
<!-- The <time> element already has content, so replacing it causes no shift -->
<time data-local-target="time" datetime="2025-01-15T10:00:00Z">
  January 15, 2025
</time>
```

**Avoid:**

```javascript
import { Controller } from "@hotwired/stimulus"

// BAD: Adding elements in connect() causes layout shift
export default class extends Controller {
  connect() {
    // This inserts a new element, pushing content down = CLS
    const banner = document.createElement("div")
    banner.textContent = "Special offer!"
    banner.style.height = "60px"
    this.element.prepend(banner)
  }
}
```

**Mitigation strategies:**

1. **Reserve space in HTML.** Render placeholder elements server-side that the controller fills in.
2. **Use CSS `contain: layout`.** Prevents the controller's DOM changes from affecting elements outside its boundary.
3. **Use `content-visibility: auto`.** Lets the browser skip rendering off-screen controller elements.
4. **Animate with `transform` and `opacity`.** These properties do not cause layout shifts.

### Profiling Stimulus Performance

Use the browser Performance tab to identify slow controllers:

```javascript
// Temporary profiling wrapper for development
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const start = performance.now()
    this.doSetup()
    const duration = performance.now() - start

    if (duration > 16) { // longer than one frame (60fps)
      console.warn(
        `${this.identifier} controller connect() took ${duration.toFixed(1)}ms`
      )
    }
  }

  doSetup() {
    // actual setup logic
  }
}
```

**Key thresholds:**

| Duration | Impact | Action |
|----------|--------|--------|
| < 1ms | Invisible | Ship it |
| 1-16ms | Within one frame budget | Acceptable |
| 16-50ms | May cause jank during navigation | Optimize or defer |
| > 50ms | Visible delay, fails INP | Must defer with requestIdleCallback |

## Pattern Card

### GOOD: Lazy-loaded controller with deferred initialization

```javascript
// Only loaded when a data-controller="chart" element appears in the DOM
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    type: { type: String, default: "line" }
  }

  connect() {
    // Defer heavy chart library initialization
    if ("requestIdleCallback" in window) {
      this.idleId = requestIdleCallback(() => this.initChart())
    } else {
      this.timeoutId = setTimeout(() => this.initChart(), 0)
    }
  }

  disconnect() {
    if (this.idleId) cancelIdleCallback(this.idleId)
    if (this.timeoutId) clearTimeout(this.timeoutId)
    if (this.chart) this.chart.destroy()
  }

  async initChart() {
    const { Chart } = await import("chart.js")
    const response = await fetch(this.urlValue)
    const data = await response.json()

    this.chart = new Chart(this.element, {
      type: this.typeValue,
      data: data
    })
  }
}
```

The controller is lazy-loaded (only imported when its element exists), defers initialization to an idle callback, dynamically imports the heavy chart library, and cleans up in disconnect.

### BAD: Eager loading all controllers

```javascript
// DO NOT DO THIS
// app/javascript/controllers/index.js
import ChartController from "./chart_controller"      // 200KB
import RichTextController from "./rich_text_controller" // 150KB
import MapController from "./map_controller"            // 300KB
import VideoController from "./video_controller"        // 100KB

// All controllers loaded on every page, even if not used
application.register("chart", ChartController)
application.register("rich-text", RichTextController)
application.register("map", MapController)
application.register("video", VideoController)
```

Every page downloads and parses 750KB+ of JavaScript even if none of these controllers are present on the page. This directly increases LCP and Time to Interactive.
