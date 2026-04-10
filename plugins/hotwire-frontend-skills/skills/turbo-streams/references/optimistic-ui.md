---
title: "Optimistic UI Patterns with Turbo"
---

# Optimistic UI Patterns with Turbo

> Show the expected result of a user action immediately before server confirmation. Stimulus handles the optimistic update; the server's Turbo Stream confirms or corrects.

## Decision

Use optimistic UI for **high-success-rate actions** (likes, toggles, simple CRUD) where eliminating 200-500ms perceived latency matters. The pattern requires: (1) Stimulus controller saves state and updates DOM instantly, (2) form submits via Turbo in background, (3) server responds with canonical Turbo Stream that either matches (no flicker) or corrects (rollback). Always escape user-generated content in optimistic HTML.

## Pattern

### Three-Step Flow

1. **Stimulus controller** intercepts action, updates DOM immediately
2. **Form submits** to server in background via Turbo
3. **Server responds** with Turbo Stream -- confirms or corrects

### Optimistic Like Button

```javascript
// optimistic_toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "count"]
  static classes = ["active"]
  static values = { count: Number }

  toggle(event) {
    this.previousCount = this.countValue
    this.wasActive = this.element.classList.contains(this.activeClass)

    if (this.wasActive) {
      this.element.classList.remove(this.activeClass)
      this.countValue -= 1
    } else {
      this.element.classList.add(this.activeClass)
      this.countValue += 1
    }
    this.countTarget.textContent = this.countValue
  }

  rollback() {
    this.countValue = this.previousCount
    this.countTarget.textContent = this.countValue
    this.element.classList.toggle(this.activeClass, this.wasActive)
  }
}
```

Server always renders the truth:

```erb
<%= turbo_stream.replace dom_id(@post, :like) do %>
  <%= render "posts/like_button", post: @post %>
<% end %>
```

### Optimistic List Append

```javascript
// optimistic_append_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = { target: String }

  appendOptimistic(event) {
    const title = this.inputTarget.value.trim()
    if (!title) return

    const id = `optimistic-${Date.now()}`
    const container = document.getElementById(this.targetValue)
    container.insertAdjacentHTML("beforeend",
      `<div id="${id}" class="todo-item todo-item--pending">
        <span>${this.escapeHtml(title)}</span>
        <span class="todo-status">Saving...</span>
      </div>`)
    this.optimisticElement = document.getElementById(id)
    this.inputTarget.value = ""
  }

  cleanup(event) {
    if (this.optimisticElement)
      setTimeout(() => this.optimisticElement?.remove(), 100)
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
```

Wire with Turbo events:

```erb
<%= form_with model: Todo.new, url: todos_path,
    data: { controller: "optimistic-append",
            action: "turbo:submit-start->optimistic-append#appendOptimistic turbo:submit-end->optimistic-append#cleanup",
            optimistic_append_target_value: "todos" } do |f| %>
  <%= f.text_field :title, data: { optimistic_append_target: "input" } %>
  <%= f.submit "Add" %>
<% end %>
```

### Failure Handling and Rollback

```javascript
// optimistic_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { rollbackHtml: String }

  connect() {
    this.element.addEventListener("turbo:submit-end", this.handleResponse.bind(this))
  }

  saveState() { this.rollbackHtmlValue = this.element.innerHTML }

  handleResponse(event) {
    if (!event.detail.success) { this.rollback(); this.showError() }
  }

  rollback() {
    if (this.rollbackHtmlValue) {
      this.element.innerHTML = this.rollbackHtmlValue
      this.rollbackHtmlValue = ""
    }
  }

  showError() {
    document.getElementById("flash_messages")?.insertAdjacentHTML("beforeend",
      `<div class="flash flash--error" data-controller="auto-dismiss">
         Something went wrong. Please try again.
       </div>`)
  }
}
```

Global network error handler:

```javascript
document.addEventListener("turbo:fetch-request-error", (event) => {
  const target = event.target.closest("[data-controller*='optimistic']")
  if (target) {
    window.Stimulus.getControllerForElementAndIdentifier(target, "optimistic")?.rollback()
  }
})
```

### Optimistic Delete with Undo

```javascript
// optimistic_delete_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { undoDuration: { type: Number, default: 5000 } }

  delete(event) {
    event.preventDefault()
    this.element.style.opacity = "0"
    this.element.style.transition = "opacity 0.3s ease"

    this.undoTimeout = setTimeout(() => {
      this.element.querySelector("form[method='post'] input[name='_method'][value='delete']")
        ?.closest("form")?.requestSubmit()
    }, this.undoDurationValue)

    this.showUndoToast()
  }

  undo() {
    clearTimeout(this.undoTimeout)
    this.element.style.opacity = "1"
    document.getElementById("undo-toast")?.remove()
  }

  showUndoToast() {
    const toast = document.createElement("div")
    toast.id = "undo-toast"
    toast.className = "toast toast--undo"
    toast.innerHTML = `Item will be deleted.
      <button data-action="optimistic-delete#undo">Undo</button>`
    document.getElementById("flash_messages")?.appendChild(toast)
  }
}
```

### ULID-Based Optimistic Identity

Generate client-side ULIDs so the optimistic element uses the same ID the server will persist -- no DOM swap needed when the server confirms.

```html
<form method="post" action="/" data-optimistic-form>
  <template data-optimistic-template>
    <turbo-stream action="append" target="todos">
      <template><li id="todo-${id}">${title} (ulid: ${id})</li></template>
    </turbo-stream>
  </template>
  <input type="text" name="todo[title]" placeholder="What needs to be done?" />
  <input type="submit" value="Add" />
</form>
```

On `turbo:submit-start`: generate ULID, inject into form data, render template into DOM. Turbo executes the stream action automatically. Server accepts the ULID and uses it as the record ID.

## Pitfalls

**GOOD**: Stimulus toggles class + count immediately, server confirms via Turbo Stream
**BAD**: Blocking UI with spinner for every like/toggle -- 200-500ms feels sluggish

**GOOD**: Listen to `turbo:submit-end` + check `event.detail.success` for rollback
**BAD**: No rollback handling -- optimistic state sticks even when server rejects

**GOOD**: `escapeHtml()` on user input before `insertAdjacentHTML`
**BAD**: Template literals with raw user input -- XSS vulnerability

**GOOD**: Server always sends canonical state via Turbo Stream (single source of truth)
**BAD**: Client and server maintaining separate state without reconciliation
