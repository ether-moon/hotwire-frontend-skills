---
title: Morphing Troubleshooting Guide
---

## Table of Contents

- [Overview](#overview)
- [Problem / Solution Table](#problem--solution-table)
- [Solutions with Code Examples](#solutions-with-code-examples)
  - [Timers Not Updating](#timers-not-updating)
  - [Forms Resetting on Morph](#forms-resetting-on-morph)
  - [Pagination Breaking with Morph](#pagination-breaking-with-morph)
  - [Flickering on Replace](#flickering-on-replace)
  - [localStorage State Loss](#localstorage-state-loss)
  - [Dropdowns Closing on Morph](#dropdowns-closing-on-morph)

## Overview

Turbo 8 morphing (powered by Idiomorph) preserves most DOM state automatically, but certain patterns can cause unexpected behavior. This guide catalogs the most common issues developers encounter when adopting morphing and provides tested solutions.

## Problem / Solution Table

| Problem | Solution |
|---------|----------|
| Timers not updating | Clear and restart the timer in a `turbo:morph-element` listener |
| Forms resetting | Wrap form sections in Turbo Frames with `refresh: :morph` |
| Pagination breaking | Use Turbo Frames with `refresh: :morph` for the paginated container |
| Flickering on replace | Switch from `turbo_stream.replace` to `turbo_stream.replace ..., method: :morph` |
| localStorage state loss | Listen to `turbo:morph-element`, save and restore state around the morph |
| Dropdown closing | Use `data-turbo-permanent` on the dropdown container element |

## Solutions with Code Examples

### Timers Not Updating

**Problem**: A countdown timer or auto-refresh interval stops working after a morph because the Stimulus controller's internal `setInterval` reference becomes stale, even though the DOM element persists.

**Solution**: Listen for `turbo:morph-element` and restart the timer when the controller's element is morphed.

```javascript
// app/javascript/controllers/countdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { endsAt: String }

  connect() {
    this.startTimer()

    // Listen for morphs on this element
    this.morphHandler = this.handleMorph.bind(this)
    document.addEventListener("turbo:morph-element", this.morphHandler)
  }

  disconnect() {
    this.stopTimer()
    document.removeEventListener("turbo:morph-element", this.morphHandler)
  }

  handleMorph(event) {
    // Check if our element was morphed
    if (event.target === this.element || this.element.contains(event.target)) {
      this.stopTimer()
      this.startTimer()
    }
  }

  startTimer() {
    this.interval = setInterval(() => {
      const remaining = new Date(this.endsAtValue) - new Date()
      if (remaining <= 0) {
        this.element.textContent = "Expired"
        this.stopTimer()
      } else {
        const minutes = Math.floor(remaining / 60000)
        const seconds = Math.floor((remaining % 60000) / 1000)
        this.element.textContent = `${minutes}:${seconds.toString().padStart(2, "0")}`
      }
    }, 1000)
  }

  stopTimer() {
    if (this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
  }
}
```

### Forms Resetting on Morph

**Problem**: A user is typing in a form field. A page-level morph (triggered by a broadcast or page refresh) resets the form to its server-rendered state, losing the user's input.

**Solution**: Wrap the form in a Turbo Frame with `refresh: :morph`. Frame morphing preserves form element values because Idiomorph matches inputs by `name` and `id` and keeps their current values.

```erb
<%# app/views/tasks/edit.html.erb %>

<%# The frame boundary tells Turbo to morph only within this frame %>
<%= turbo_frame_tag "task_form", refresh: :morph do %>
  <%= form_with model: @task, data: { turbo_frame: "_top" } do |f| %>
    <div class="field">
      <%= f.label :title %>
      <%= f.text_field :title, id: "task_title" %>
    </div>

    <div class="field">
      <%= f.label :description %>
      <%= f.text_area :description, id: "task_description" %>
    </div>

    <%= f.submit "Save" %>
  <% end %>
<% end %>
```

Alternatively, if you cannot use frames, prevent morphing on specific elements:

```javascript
document.addEventListener("turbo:before-morph-element", (event) => {
  // Skip morphing elements that have user focus
  if (event.target === document.activeElement) {
    event.preventDefault()
  }

  // Skip morphing elements inside an active form
  if (event.target.closest("form")?.contains(document.activeElement)) {
    event.preventDefault()
  }
})
```

### Pagination Breaking with Morph

**Problem**: A paginated list uses "Load More" to append items. When a page-level morph occurs, the DOM reverts to showing only the first page because the server renders the initial page state.

**Solution**: Wrap the paginated list in a Turbo Frame with `refresh: :morph`. The frame acts as a boundary that Idiomorph morphs independently, and since the frame content was loaded client-side, it persists through page morphs.

```erb
<%# app/views/tasks/index.html.erb %>

<%= turbo_frame_tag "task_list", refresh: :morph do %>
  <div id="tasks">
    <%= render @tasks %>
  </div>

  <% if @tasks.next_page? %>
    <%= turbo_frame_tag "load_more_tasks",
          src: tasks_path(page: @tasks.next_page),
          loading: :lazy do %>
      <p>Loading more...</p>
    <% end %>
  <% end %>
<% end %>
```

Alternatively, use `data-turbo-permanent` on the container if it should never be morphed:

```erb
<div id="tasks" data-turbo-permanent>
  <%= render @tasks %>
</div>
```

Note: `data-turbo-permanent` prevents all updates to the element, including intentional ones. The frame approach with `refresh: :morph` is usually preferable because it still allows targeted updates.

### Flickering on Replace

**Problem**: Using `turbo_stream.replace` on a complex element (a card with images, nested components) causes a visible flicker as the old element is removed and the new one is inserted.

**Solution**: Switch from `replace` to the `morph` stream action. Morph updates attributes and text in place without removing and re-inserting the element, eliminating the flicker.

```erb
<%# BEFORE: causes flicker %>
<%= turbo_stream.replace dom_id(@task) do %>
  <%= render partial: "tasks/task", locals: { task: @task } %>
<% end %>

<%# AFTER: smooth update without flicker %>
<%= turbo_stream.replace dom_id(@task), method: :morph, partial: "tasks/task", locals: { task: @task } %>
```

You can also use `update` with morph to replace only the inner content:

```erb
<%= turbo_stream.update dom_id(@task), method: :morph, partial: "tasks/task", locals: { task: @task } %>
```

Morph is especially beneficial when the element contains:
- Images (avoids re-triggering load)
- CSS animations (preserves animation state)
- Nested Stimulus controllers (avoids disconnect/reconnect cycle)
- iframes (avoids reloading iframe content)

### localStorage State Loss

**Problem**: A Stimulus controller reads from `localStorage` on `connect()` to restore UI state (sidebar collapsed, theme preference, etc.). After a morph, the controller may not re-run `connect()` because the element was updated in place rather than replaced. The `localStorage` state is still there, but the DOM does not reflect it.

**Solution**: Listen to `turbo:morph-element` and re-apply `localStorage` state after the morph.

```javascript
// app/javascript/controllers/sidebar_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = ["collapsed"]

  connect() {
    this.restoreState()

    this.morphHandler = this.handleMorph.bind(this)
    document.addEventListener("turbo:morph-element", this.morphHandler)
  }

  disconnect() {
    document.removeEventListener("turbo:morph-element", this.morphHandler)
  }

  handleMorph(event) {
    if (event.target === this.element || this.element.contains(event.target)) {
      this.restoreState()
    }
  }

  toggle() {
    this.element.classList.toggle(this.collapsedClass)
    this.saveState()
  }

  restoreState() {
    const collapsed = localStorage.getItem("sidebar-collapsed") === "true"
    this.element.classList.toggle(this.collapsedClass, collapsed)
  }

  saveState() {
    const collapsed = this.element.classList.contains(this.collapsedClass)
    localStorage.setItem("sidebar-collapsed", collapsed.toString())
  }
}
```

Alternatively, use the global `turbo:morph` event to restore all localStorage-dependent state at once:

```javascript
document.addEventListener("turbo:morph", () => {
  // Re-apply all localStorage-driven UI state after any morph
  document.querySelectorAll("[data-restore-from-storage]").forEach(el => {
    const key = el.dataset.restoreFromStorage
    const value = localStorage.getItem(key)
    if (value !== null) {
      el.dataset.storageValue = value
      el.dispatchEvent(new CustomEvent("storage:restored", { detail: { value } }))
    }
  })
})
```

### Dropdowns Closing on Morph

**Problem**: A dropdown menu (custom select, popover, tooltip) is open when a page morph occurs. The morph updates the dropdown's DOM, causing it to lose its open state and close.

**Solution**: Add `data-turbo-permanent` to the dropdown container so it is excluded from morphing entirely.

```erb
<%# app/views/shared/_user_menu.html.erb %>
<div id="user-menu-dropdown" data-turbo-permanent>
  <button data-controller="dropdown" data-action="dropdown#toggle">
    <%= Current.user.name %>
  </button>

  <div data-dropdown-target="menu" class="dropdown-menu hidden">
    <%= link_to "Profile", profile_path %>
    <%= link_to "Settings", settings_path %>
    <%= button_to "Sign out", session_path, method: :delete %>
  </div>
</div>
```

Important requirements for `data-turbo-permanent`:
- The element **must** have a unique `id`
- The element must exist in both the old and new page DOM
- If the element is absent from the new page, it will be removed despite the permanent attribute

For dropdown libraries that manage their own DOM (like Tippy.js or Floating UI), you may also need to exclude the popover overlay element:

```javascript
document.addEventListener("turbo:before-morph-element", (event) => {
  // Skip morphing any floating UI popover that is currently open
  if (event.target.closest("[data-floating-ui-portal]")) {
    event.preventDefault()
  }

  // Skip morphing any element with an open popover
  if (event.target.matches("[popover]:popover-open")) {
    event.preventDefault()
  }
})
```

If the dropdown content itself needs to update (for example, showing an unread count), use `turbo:morph` to manually update just the data:

```javascript
document.addEventListener("turbo:morph", () => {
  // After morph, update any data attributes on permanent elements
  // that may have changed on the server
  const menu = document.getElementById("user-menu-dropdown")
  if (menu) {
    const serverMenu = document.querySelector("[data-morph-source='user-menu']")
    if (serverMenu) {
      const badge = menu.querySelector(".notification-badge")
      const newCount = serverMenu.dataset.unreadCount
      if (badge) badge.textContent = newCount
    }
  }
})
```
