---
title: "Production-Ready Controllers"
---

# Production-Ready Controllers

> Six small, composable controllers extracted from production Rails apps (37signals). Each under 50 lines, single responsibility, copy-and-adapt patterns.

## Decision

Build many small controllers (7-45 lines each) instead of one monolithic controller. Each uses Values API for state, connect/disconnect symmetry for cleanup, and feature detection where needed. Patterns to adapt, not libraries to install.

## Patterns

### 1. Clipboard Controller (25 lines)

Copies text to clipboard with visual feedback. Feature-detects Clipboard API.

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]
  static values = { successDuration: { type: Number, default: 2000 } }

  connect() {
    if (!navigator.clipboard) this.buttonTarget.hidden = true
  }

  async copy() {
    const text = this.sourceTarget.value || this.sourceTarget.textContent
    await navigator.clipboard.writeText(text.trim())
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = "Copied!"
    this.buttonTarget.disabled = true
    setTimeout(() => {
      this.buttonTarget.textContent = original
      this.buttonTarget.disabled = false
    }, this.successDurationValue)
  }
}
```

```html
<div data-controller="clipboard" data-clipboard-success-duration-value="1500">
  <input data-clipboard-target="source" value="https://example.com/invite/abc123" readonly>
  <button data-clipboard-target="button" data-action="clipboard#copy">Copy Link</button>
</div>
```

### 2. Auto-Click Controller (7 lines)

Clicks its element on connect. Trigger actions on page load (open modal from redirect, SSO submit).

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() { this.element.click() }
}
```

```html
<% if flash[:open_modal] %>
  <button data-controller="auto-click" data-action="click->modal#open" hidden>Open</button>
<% end %>
```

### 3. Toggle-Class Controller (31 lines)

Boolean value drives class toggling via CSS Classes API (framework-agnostic).

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleable"]
  static classes = ["toggle"]
  static values = { open: { type: Boolean, default: false } }

  openValueChanged() {
    const targets = this.hasToggleableTarget ? this.toggleableTargets : [this.element]
    targets.forEach(t => t.classList.toggle(this.toggleClass, this.openValue))
  }
  toggle() { this.openValue = !this.openValue }
  show()   { this.openValue = true }
  hide()   { this.openValue = false }
}
```

```html
<div data-controller="toggle-class" data-toggle-class-toggle-class="hidden"
     data-toggle-class-open-value="false">
  <button data-action="toggle-class#toggle">Menu</button>
  <ul data-toggle-class-target="toggleable" class="hidden">...</ul>
</div>
```

### 4. Auto-Submit Controller (28 lines)

Debounced form auto-submission. `submit()` for selects, `debouncedSubmit()` for text inputs.

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  connect()    { this.timeout = null }
  disconnect() { this.cancelPending() }

  submit() {
    this.cancelPending()
    this.element.requestSubmit()
  }

  debouncedSubmit() {
    this.cancelPending()
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  cancelPending() {
    if (this.timeout) { clearTimeout(this.timeout); this.timeout = null }
  }
}
```

```erb
<%= form_with url: search_path, method: :get,
    data: { controller: "auto-submit", auto_submit_delay_value: 500 } do |f| %>
  <%= f.search_field :q, data: { action: "input->auto-submit#debouncedSubmit" } %>
<% end %>

<%= f.select :category, ["All", "Books"],
    {}, data: { action: "change->auto-submit#submit" } %>
```

### 5. Dialog Controller (45 lines)

Wraps native `<dialog>` with modal/non-modal, backdrop click dismiss, auto-open support.

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = {
    open: { type: Boolean, default: false },
    modal: { type: Boolean, default: true }
  }

  connect() {
    this.boundBackdrop = this.handleBackdropClick.bind(this)
    this.dialogTarget.addEventListener("click", this.boundBackdrop)
    if (this.openValue) this.show()
  }

  disconnect() {
    this.dialogTarget.removeEventListener("click", this.boundBackdrop)
  }

  show() {
    this.modalValue ? this.dialogTarget.showModal() : this.dialogTarget.show()
    this.openValue = true
  }

  close() { this.dialogTarget.close(); this.openValue = false }

  handleBackdropClick(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
```

```html
<div data-controller="dialog">
  <button data-action="dialog#show">Open</button>
  <dialog data-dialog-target="dialog">
    <h2>Confirm Delete</h2>
    <button data-action="dialog#close">Cancel</button>
    <%= button_to "Delete", item_path(@item), method: :delete %>
  </dialog>
</div>
```

### 6. Local-Time Controller (40 lines)

Converts UTC server timestamps to local timezone. Relative times auto-refresh.

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    datetime: String,
    format: { type: String, default: "relative" },
    refreshInterval: { type: Number, default: 60000 }
  }

  connect() {
    this.update()
    if (this.formatValue === "relative")
      this.interval = setInterval(() => this.update(), this.refreshIntervalValue)
  }

  disconnect() { if (this.interval) clearInterval(this.interval) }

  update() {
    const date = new Date(this.datetimeValue)
    this.element.textContent = this.formatValue === "relative"
      ? this.relativeTime(date)
      : date.toLocaleString(undefined, this.formatOptions())
    this.element.title = date.toLocaleString()
  }

  relativeTime(date) {
    const s = Math.floor((new Date() - date) / 1000)
    if (s < 60) return "just now"
    if (s < 3600) return `${Math.floor(s / 60)}m ago`
    if (s < 86400) return `${Math.floor(s / 3600)}h ago`
    if (s < 604800) return `${Math.floor(s / 86400)}d ago`
    return date.toLocaleDateString()
  }

  formatOptions() {
    const formats = { short: { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" },
      long: { weekday: "long", year: "numeric", month: "long", day: "numeric" },
      date: { year: "numeric", month: "short", day: "numeric" },
      time: { hour: "numeric", minute: "2-digit" } }
    return formats[this.formatValue] || formats.short
  }
}
```

```erb
<span data-controller="local-time"
      data-local-time-datetime-value="<%= post.created_at.iso8601 %>">
  <%= post.created_at.strftime("%B %d, %Y") %>
</span>
```

## Pitfalls

**GOOD**: Six focused controllers (7-45 lines each), each doing one thing well
**BAD**: One 200+ line controller with `initClipboard()`, `initDialogs()`, `initTooltips()` -- untestable, unreusable

**GOOD**: `requestSubmit()` for programmatic submission (triggers Turbo + HTML validation)
**BAD**: `submit()` bypasses Turbo interception and validation
**GOOD**: Cleanup in `disconnect()` (clear timeouts, remove listeners)
**BAD**: Leaking intervals/listeners when elements leave DOM
