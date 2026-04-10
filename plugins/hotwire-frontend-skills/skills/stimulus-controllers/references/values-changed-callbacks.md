---
title: "Values and valueChanged Callbacks"
---

> For API reference, see `handbook/stimulus-values-api.md`. This file covers practical patterns beyond the API spec.

# Values and valueChanged Callbacks

## Table of Contents

- [Implementation](#implementation)
  - [Reactive UI Updates](#reactive-ui-updates)
  - [Values and Turbo Cache](#values-and-turbo-cache)
  - [Complex State With Object and Array Values](#complex-state-with-object-and-array-values)
- [Pattern Card](#pattern-card)

## Implementation

### Reactive UI Updates

`valueChanged` fires after `initialize()` (before `connect()`) with the initial value, whenever the value actually changes, and when the HTML attribute is modified externally (e.g., by Turbo morph). Stimulus compares previous and new decoded values and only invokes the callback when they differ. The callback receives two arguments: the current decoded value and the previous decoded value (e.g., `countValueChanged(value, previousValue)`). Use this to keep the DOM in sync with state:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count", "items", "emptyState"]
  static values = {
    count: { type: Number, default: 0 },
    filter: { type: String, default: "" }
  }

  // React to count changes — receives (currentValue, previousValue)
  countValueChanged(value, previousValue) {
    this.countTarget.textContent = value
    this.emptyStateTarget.hidden = value > 0
  }

  // React to filter changes
  filterValueChanged() {
    this.itemTargets.forEach(item => {
      const text = item.textContent.toLowerCase()
      item.hidden = !text.includes(this.filterValue.toLowerCase())
    })
  }

  add() {
    this.countValue++
  }

  search(event) {
    this.filterValue = event.target.value
  }
}
```

```html
<div data-controller="list" data-list-count-value="3">
  <span data-list-target="count">3</span> items

  <input type="search"
         data-action="input->list#search"
         placeholder="Filter...">

  <div data-list-target="emptyState" hidden>No items found</div>

  <ul>
    <li data-list-target="items">Item 1</li>
    <li data-list-target="items">Item 2</li>
    <li data-list-target="items">Item 3</li>
  </ul>

  <button data-action="list#add">Add item</button>
</div>
```

### Values and Turbo Cache

Values are stored as HTML attributes, which means they are included in Turbo's page cache snapshots. When a user navigates back, the cached page includes the last-set values.

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    page: { type: Number, default: 1 },
    loaded: { type: Boolean, default: false }
  }

  connect() {
    // On cache restore, loadedValue is true from the cached HTML.
    // Only fetch if this is a fresh page load.
    if (!this.loadedValue) {
      this.fetchPage()
    }
  }

  async fetchPage() {
    const response = await fetch(`/items?page=${this.pageValue}`)
    // ... update DOM
    this.loadedValue = true
  }

  nextPage() {
    this.pageValue++
    this.loadedValue = false
    this.fetchPage()
  }
}
```

**Caveat:** If you need to reset values when navigating away, clean them up in `disconnect()` or in a `turbo:before-cache` listener.

### Complex State With Object and Array Values

Array and Object values enable richer state, but use them sparingly. Stimulus detects changes by comparing JSON-serialized strings (via `JSON.stringify()` encoding and `JSON.parse()` decoding). Note that key order differences in objects will be detected as changes, even if the logical content is the same.

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["badge", "list"]
  static values = {
    selected: { type: Array, default: [] }
  }

  selectedValueChanged() {
    this.badgeTarget.textContent = this.selectedValue.length
    this.updateSelectionUI()
  }

  toggle(event) {
    const id = event.params.id
    const selected = [...this.selectedValue]

    const index = selected.indexOf(id)
    if (index === -1) {
      selected.push(id)
    } else {
      selected.splice(index, 1)
    }

    // Must assign a new array for change detection
    this.selectedValue = selected
  }

  updateSelectionUI() {
    this.listTarget.querySelectorAll("[data-id]").forEach(item => {
      const id = parseInt(item.dataset.id, 10)
      item.classList.toggle("selected", this.selectedValue.includes(id))
    })
  }
}
```

**Important:** Mutating an Array or Object in place does not trigger `valueChanged`. You must assign a new reference:

```javascript
// GOOD: New array triggers change detection
this.selectedValue = [...this.selectedValue, newItem]

// BAD: Mutation is invisible to Stimulus
this.selectedValue.push(newItem) // valueChanged will NOT fire
```

## Pattern Card

### GOOD: State in values with reactive callback

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "submitButton"]
  static values = {
    dirty: { type: Boolean, default: false },
    charCount: { type: Number, default: 0 }
  }

  dirtyValueChanged() {
    this.submitButtonTarget.disabled = !this.dirtyValue
  }

  charCountValueChanged() {
    this.outputTarget.textContent = `${this.charCountValue} characters`
  }

  input(event) {
    this.dirtyValue = true
    this.charCountValue = event.target.value.length
  }

  save() {
    this.dirtyValue = false
  }
}
```

State is declared, typed, and reactive. The UI updates automatically when values change. State is inspectable in the DOM via data attributes.

### BAD: State in instance variables

```javascript
import { Controller } from "@hotwired/stimulus"

// DO NOT DO THIS
export default class extends Controller {
  connect() {
    this.dirty = false
    this.charCount = 0
  }

  input(event) {
    this.dirty = true
    this.charCount = event.target.value.length
    // Must manually update DOM everywhere state is used
    this.element.querySelector(".submit-btn").disabled = !this.dirty
    this.element.querySelector(".char-count").textContent = `${this.charCount} characters`
  }

  save() {
    this.dirty = false
    this.element.querySelector(".submit-btn").disabled = true
  }
}
```

State is invisible, not typed, lost on Turbo cache restore, and requires manual DOM updates scattered throughout the controller. Every place that reads state must know where to update it.
