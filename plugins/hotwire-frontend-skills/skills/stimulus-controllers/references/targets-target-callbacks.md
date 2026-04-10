---
title: "Targets and Target Callbacks"
---

> For API reference, see `handbook/stimulus-targets-api.md`. This file covers practical patterns beyond the API spec.

# Targets and Target Callbacks

## Table of Contents

- [Implementation](#implementation)
  - [Target Callbacks for Dynamic Content](#target-callbacks-for-dynamic-content)
  - [Targets With Turbo Streams](#targets-with-turbo-streams)
  - [Nested Controllers and Target Scope](#nested-controllers-and-target-scope)
- [Pattern Card](#pattern-card)

## Implementation

### Target Callbacks for Dynamic Content

Target callbacks fire when target elements are added to or removed from the DOM. This is ideal for responding to Turbo Stream updates, lazy-loaded content, or user actions that add/remove elements.

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["notification"]
  static values = { count: { type: Number, default: 0 } }

  // Fires when a notification target is added to the DOM
  notificationTargetConnected(element) {
    // Idempotent: always recount from the DOM
    this.countValue = this.notificationTargets.length
    this.animateIn(element)
  }

  // Fires when a notification target is removed from the DOM
  notificationTargetDisconnected(element) {
    this.countValue = this.notificationTargets.length
  }

  countValueChanged() {
    this.element.querySelector("[data-badge]").textContent = this.countValue
  }

  animateIn(element) {
    element.animate(
      [{ opacity: 0 }, { opacity: 1 }],
      { duration: 300, easing: "ease-out" }
    )
  }

  dismiss(event) {
    const notification = event.target.closest("[data-notifications-target='notification']")
    notification.remove()
  }
}
```

```html
<div data-controller="notifications" data-notifications-count-value="2">
  <span data-badge>2</span> notifications

  <div data-notifications-target="notification">
    <p>You have a new message</p>
    <button data-action="notifications#dismiss">Dismiss</button>
  </div>

  <div data-notifications-target="notification">
    <p>Your export is ready</p>
    <button data-action="notifications#dismiss">Dismiss</button>
  </div>

  <!-- Turbo Stream can append new notifications here, and
       notificationTargetConnected will fire automatically -->
</div>
```

**Key rules for target callbacks:**

1. Callbacks must be **idempotent**. They may fire multiple times (e.g., when Turbo morphs the page).
2. Use `this.nameTargets.length` to recount rather than incrementing/decrementing a counter.
3. The element is fully connected when `targetConnected` fires -- targets, values, and actions on the element are available.
4. When `targetDisconnected` fires, the element may or may not still be in the DOM. If the element was removed via `remove()` or `removeChild()`, the MutationObserver fires asynchronously after removal, so the element is already detached. If only the `data-*-target` attribute was changed, the element remains in the DOM. Do not assume the element is connected when handling disconnection.
5. During `targetConnected` and `targetDisconnected` callbacks, Stimulus pauses its MutationObserver instances. This means adding or removing a target with a matching name inside a callback will not trigger the callback recursively.

### Targets With Turbo Streams

Target callbacks pair perfectly with Turbo Streams. When a stream appends, prepends, or replaces an element, the target callbacks fire automatically:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]
  static values = { autoScroll: { type: Boolean, default: true } }

  messageTargetConnected(element) {
    if (this.autoScrollValue) {
      element.scrollIntoView({ behavior: "smooth", block: "end" })
    }
  }
}
```

```erb
<%# app/views/messages/_message.html.erb %>
<div data-chat-target="message" id="<%= dom_id(message) %>">
  <strong><%= message.user.name %></strong>
  <p><%= message.body %></p>
</div>

<%# Turbo Stream broadcast %>
<%# When a new message is appended, messageTargetConnected fires automatically %>
<%= turbo_stream.append "messages", partial: "messages/message", locals: { message: message } %>
```

### Nested Controllers and Target Scope

Targets are scoped to their nearest controller element. A target in a nested controller does not appear in the parent controller's targets:

```html
<div data-controller="parent">
  <!-- This item target belongs to parent -->
  <div data-parent-target="item">
    <div data-controller="child">
      <!-- This item target belongs to child, NOT parent -->
      <div data-child-target="item">...</div>
    </div>
  </div>
</div>
```

```javascript
// In the parent controller:
this.itemTargets // => [outer div only]

// In the child controller:
this.itemTargets // => [inner div only]
```

If you need the parent to access elements inside a nested controller, use **outlets** instead of targets.

## Pattern Card

### GOOD: Target callback for dynamic list

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "count", "empty"]

  itemTargetConnected() {
    this.updateUI()
  }

  itemTargetDisconnected() {
    this.updateUI()
  }

  updateUI() {
    const count = this.itemTargets.length
    this.countTarget.textContent = count
    this.emptyTarget.hidden = count > 0
  }
}
```

The controller automatically reacts to items being added or removed by Turbo Streams, DOM manipulation, or user actions. The `updateUI` method is idempotent and safe to call from either callback.

### BAD: Manual querySelector after mutation

```javascript
import { Controller } from "@hotwired/stimulus"

// DO NOT DO THIS
export default class extends Controller {
  connect() {
    this.mutationObserver = new MutationObserver(() => {
      // Fragile: querying by CSS class instead of targets
      const items = this.element.querySelectorAll(".list-item")
      this.element.querySelector(".count").textContent = items.length
      this.element.querySelector(".empty").hidden = items.length > 0
    })
    this.mutationObserver.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    this.mutationObserver.disconnect()
  }
}
```

MutationObserver is overkill here and fires for every DOM change (attribute changes, text changes), not just target additions. The querySelector calls are fragile and coupled to CSS class names rather than semantic targets.
