---
title: "Lifecycle: connect and disconnect"
---

> For API reference, see `handbook/stimulus-lifecycle-api.md`. This file covers practical patterns beyond the API spec.

# Lifecycle: connect and disconnect

## Table of Contents

- [Implementation](#implementation)
  - [Re-entry Handling During Turbo Navigations](#re-entry-handling-during-turbo-navigations)
  - [MutationObserver Patterns for DOM-Driven Reactivity](#mutationobserver-patterns-for-dom-driven-reactivity)
  - [Third-Party Library Integration](#third-party-library-integration)
- [Pattern Card](#pattern-card)

## Implementation

### Re-entry Handling During Turbo Navigations

When a user navigates away and then presses the back button, Turbo restores the page from cache. This means `connect()` fires again on a controller that previously had `disconnect()` called. Controllers must handle this gracefully.

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { loaded: Boolean }

  connect() {
    // Guard against re-initialization of expensive operations
    if (!this.loadedValue) {
      this.performExpensiveSetup()
      this.loadedValue = true
    }

    // Always re-attach event listeners (they were removed in disconnect)
    this.handleClick = this.handleClick.bind(this)
    this.element.addEventListener("click", this.handleClick)
  }

  disconnect() {
    this.element.removeEventListener("click", this.handleClick)
    // Note: we do NOT reset loadedValue here, so the expensive
    // setup is skipped on re-entry from Turbo cache.
  }

  performExpensiveSetup() {
    // One-time setup that should not repeat on back-navigation
  }

  handleClick() {
    // ...
  }
}
```

### MutationObserver Patterns for DOM-Driven Reactivity

Use MutationObserver when you need to react to DOM changes outside your controller's direct control (e.g., Turbo Stream updates adding content).

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list"]

  connect() {
    this.mutationObserver = new MutationObserver(
      (mutations) => this.handleMutations(mutations)
    )
    this.mutationObserver.observe(this.listTarget, {
      childList: true,
      subtree: false
    })
  }

  disconnect() {
    this.mutationObserver.disconnect()
  }

  handleMutations(mutations) {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType === Node.ELEMENT_NODE) {
          this.animateIn(node)
        }
      }
    }
  }

  animateIn(element) {
    element.animate(
      [{ opacity: 0, transform: "translateY(-10px)" }, { opacity: 1, transform: "translateY(0)" }],
      { duration: 200, easing: "ease-out" }
    )
  }
}
```

**Prefer target callbacks over MutationObserver when possible.** Target callbacks (`itemTargetConnected`) are cleaner and more idiomatic. Use MutationObserver only when the changing elements are not Stimulus targets.

### Third-Party Library Integration

When wrapping a third-party library, create the instance in `connect()` and destroy it in `disconnect()`:

```javascript
import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  static values = {
    enableTime: { type: Boolean, default: false },
    dateFormat: { type: String, default: "Y-m-d" }
  }

  connect() {
    this.picker = flatpickr(this.element, {
      enableTime: this.enableTimeValue,
      dateFormat: this.dateFormatValue
    })
  }

  disconnect() {
    this.picker.destroy()
  }
}
```

```html
<input type="text"
       data-controller="datepicker"
       data-datepicker-enable-time-value="true"
       data-datepicker-date-format-value="Y-m-d H:i">
```

## Pattern Card

### GOOD: Symmetric setup and teardown

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  initialize() {
    this.handleResize = this.handleResize.bind(this)
  }

  connect() {
    this.observer = new ResizeObserver(() => this.handleResize())
    this.observer.observe(this.element)

    this.interval = setInterval(() => this.poll(), 5000)
  }

  disconnect() {
    this.observer.disconnect()
    clearInterval(this.interval)
  }

  handleResize() { /* ... */ }
  poll() { /* ... */ }
}
```

Every resource created in `connect()` is destroyed in `disconnect()`. The controller survives multiple connect/disconnect cycles without leaks.

### BAD: Setup without cleanup causing leaks

```javascript
import { Controller } from "@hotwired/stimulus"

// DO NOT DO THIS
export default class extends Controller {
  connect() {
    // Leak: new ResizeObserver on every connect, never disconnected
    new ResizeObserver(() => this.handleResize()).observe(this.element)

    // Leak: interval never cleared
    setInterval(() => this.poll(), 5000)

    // Leak: event listener added but never removed
    window.addEventListener("resize", () => this.handleResize())
  }

  handleResize() { /* ... */ }
  poll() { /* ... */ }
}
```

Each Turbo navigation creates another observer, another interval, and another event listener. After 10 navigations, there are 10 intervals polling simultaneously and 10 resize listeners firing on every resize.
