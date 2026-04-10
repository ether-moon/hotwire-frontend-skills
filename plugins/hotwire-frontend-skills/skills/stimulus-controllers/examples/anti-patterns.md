---
title: "Common Stimulus Anti-Patterns"
---

# Common Stimulus Anti-Patterns

## 1. Fat Controllers

**Problem:** A single controller handles multiple unrelated responsibilities.

**Bad:**

```javascript
export default class extends Controller {
  static targets = ["tab", "tabPanel", "searchInput", "searchResults", "notification", "tooltip"]
  selectTab(event) { /* ... */ }
  search(event) { /* ... */ }
  dismissNotification(event) { /* ... */ }
  showTooltip(event) { /* ... */ }
  // ... 150+ lines handling 4 unrelated concerns
}
```

**Corrected:** Split into focused controllers that compose through HTML.

```javascript
// tabs_controller.js (~20 lines each)
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { index: { type: Number, default: 0 } }
  indexValueChanged() {
    this.tabTargets.forEach((tab, i) => tab.classList.toggle("active", i === this.indexValue))
    this.panelTargets.forEach((panel, i) => panel.hidden = i !== this.indexValue)
  }
  select(event) { this.indexValue = this.tabTargets.indexOf(event.currentTarget) }
}
// + search_controller.js, notifications_controller.js, tooltip_controller.js
```

---

## 2. Direct DOM Manipulation Instead of Values

**Problem:** Using instance variables and manually updating DOM instead of the Values API with reactive `valueChanged` callbacks.

**Bad:**

```javascript
export default class extends Controller {
  connect() { this.count = 0 }
  increment() {
    this.count++
    this.element.querySelector(".count").textContent = this.count
  }
}
```

**Corrected:**

```javascript
export default class extends Controller {
  static targets = ["count"]
  static values = { count: { type: Number, default: 0 } }

  countValueChanged() { this.countTarget.textContent = this.countValue }
  increment() { this.countValue++ }
}
```

---

## 3. Missing disconnect Cleanup

**Problem:** Listeners, timers, or observers created in `connect()` are never cleaned up. Each Turbo navigation leaks another listener.

**Bad:**

```javascript
export default class extends Controller {
  connect() {
    window.addEventListener("scroll", () => this.handleScroll()) // anonymous -- can't remove
    setInterval(() => this.refresh(), 5000)                      // never cleared
  }
}
```

**Corrected:** Bind in `initialize()`, store references, clean up symmetrically.

```javascript
export default class extends Controller {
  initialize() { this.handleScroll = this.handleScroll.bind(this) }
  connect() {
    window.addEventListener("scroll", this.handleScroll)
    this.refreshInterval = setInterval(() => this.refresh(), 5000)
  }
  disconnect() {
    window.removeEventListener("scroll", this.handleScroll)
    clearInterval(this.refreshInterval)
  }
}
```

---

## 4. Using querySelector Instead of Targets

**Problem:** Querying elements by CSS selectors instead of targets -- fragile, unscoped, breaks when classes change.

**Bad:**

```javascript
export default class extends Controller {
  submit() {
    const input = this.element.querySelector(".form-input")
    const button = document.querySelector("#submit-btn") // global query!
  }
}
```

**Corrected:** Targets are scoped to the controller and survive CSS refactors.

```javascript
export default class extends Controller {
  static targets = ["input", "error", "submit"]

  submit() {
    if (this.inputTarget.value.length < 3) {
      this.errorTarget.textContent = "Too short"
      this.errorTarget.hidden = false
    }
  }
}
```

---

## 5. Hardcoded Selectors

**Problem:** Hardcoding CSS classes in JavaScript. When classes change, the controller breaks silently.

**Bad:**

```javascript
export default class extends Controller {
  toggle() {
    this.element.querySelector(".dropdown-menu").classList.toggle("is-open")
    this.element.querySelector(".dropdown-icon").classList.toggle("rotate-180")
  }
}
```

**Corrected:** Use targets, classes API, and values. Class names configured in HTML via `data-[identifier]-[name]-class`.

```javascript
export default class extends Controller {
  static targets = ["menu", "icon"]
  static classes = ["open", "rotated"]
  static values = { open: { type: Boolean, default: false } }

  openValueChanged() {
    this.menuTarget.classList.toggle(this.openClass, this.openValue)
    this.iconTarget.classList.toggle(this.rotatedClass, this.openValue)
  }
  toggle() { this.openValue = !this.openValue }
}
```

---

## 6. Business Logic in Controllers

**Problem:** Putting validation, calculations, or transformations directly in the controller instead of extracting to utility modules.

**Bad:**

```javascript
export default class extends Controller {
  calculate() {
    const subtotal = this.itemTargets.reduce((sum, item) =>
      sum + parseFloat(item.dataset.price) * parseInt(item.querySelector("input").value, 10), 0)
    const taxRate = this.element.dataset.state === "CA" ? 0.0725 : 0
    const discount = subtotal > 100 ? subtotal * 0.1 : 0
    this.totalTarget.textContent = `$${(subtotal + subtotal * taxRate - discount).toFixed(2)}`
  }
}
```

**Corrected:** Extract to a testable utility; controller only bridges DOM.

```javascript
// utils/pricing.js -- testable without DOM
export function calculateTotal({ subtotal, state }) { /* tax/discount logic */ }

// cart_controller.js
import { calculateTotal } from "../utils/pricing"
export default class extends Controller {
  static targets = ["item", "total"]
  static values = { state: String }
  calculate() {
    const subtotal = this.itemTargets.reduce((sum, el) => sum + parseFloat(el.dataset.lineTotal), 0)
    this.totalTarget.textContent = `$${calculateTotal({ subtotal, state: this.stateValue }).toFixed(2)}`
  }
}
```

---

## 7. Tightly Coupled Controllers

**Problem:** Controllers query the DOM for other controllers, creating invisible dependencies.

**Bad:**

```javascript
export default class extends Controller {
  submit() {
    const el = document.querySelector("[data-controller='notification']")
    const ctrl = this.application.getControllerForElementAndIdentifier(el, "notification")
    ctrl.show("Form submitted!")
  }
}
```

**Corrected (outlets):**

```javascript
export default class extends Controller {
  static outlets = ["notification"]
  submit() {
    if (this.hasNotificationOutlet) this.notificationOutlet.show("Form submitted!")
  }
}
```

**Corrected (events for loose coupling):**

```javascript
// form_controller.js
submit() { this.dispatch("submitted", { detail: { message: "Form submitted!" } }) }

// notification_controller.js
show(event) { this.element.textContent = event.detail.message; this.element.hidden = false }
```

Wire via `data-action="form:submitted->notification#show"` in HTML.

---

## 8. Ignoring Action Parameters

**Problem:** Manually parsing `data-*` attributes instead of using Stimulus action parameters.

**Bad:**

```javascript
export default class extends Controller {
  remove(event) {
    const id = parseInt(event.target.closest("button").dataset.id, 10)
    const name = event.target.closest("button").dataset.name
  }
}
```

**Corrected:**

```javascript
export default class extends Controller {
  remove(event) {
    const { id, name, confirm: needsConfirm } = event.params
    if (!needsConfirm || confirm(`Delete ${name}?`)) this.deleteItem(id)
  }
}
```

Use `data-[identifier]-[name]-param` in HTML. Parameters are automatically typed (42 becomes Number, false becomes Boolean) and scoped to the controller.

---

## 9. Not Using CSS Classes API

**Problem:** Hardcoding CSS class names in JavaScript. When the design system changes, the controller breaks.

**Bad:**

```javascript
export default class extends Controller {
  activate(event) {
    this.element.querySelectorAll(".tab").forEach(tab =>
      tab.classList.remove("bg-blue-500", "text-white", "font-bold"))
    event.currentTarget.classList.add("bg-blue-500", "text-white", "font-bold")
  }
}
```

**Corrected:**

```javascript
export default class extends Controller {
  static targets = ["tab"]
  static classes = ["active", "inactive"]
  static values = { index: { type: Number, default: 0 } }

  indexValueChanged() {
    this.tabTargets.forEach((tab, i) => {
      tab.classList.toggle(...this.activeClasses, i === this.indexValue)
      tab.classList.toggle(...this.inactiveClasses, i !== this.indexValue)
    })
  }
  select(event) { this.indexValue = this.tabTargets.indexOf(event.currentTarget) }
}
```

Configure via `data-tabs-active-class="bg-blue-500 text-white font-bold"` in HTML. Use `...this.activeClasses` (plural, spread) for multi-class values.

---

## 10. Synchronous Heavy Operations in connect

**Problem:** Running expensive synchronous operations in `connect()` that block the main thread.

**Bad:**

```javascript
export default class extends Controller {
  connect() {
    this.element.querySelectorAll("pre code").forEach(block => {
      hljs.highlightElement(block) // 50-200ms per block
    })
  }
}
```

**Corrected:** Chunk across animation frames and dynamically import heavy libraries.

```javascript
export default class extends Controller {
  static targets = ["code"]
  connect() { this.queue = [...this.codeTargets]; this.processNext() }
  disconnect() { this.queue = []; if (this.frameId) cancelAnimationFrame(this.frameId) }

  processNext() {
    if (this.queue.length === 0) return
    const block = this.queue.shift()
    this.frameId = requestAnimationFrame(async () => {
      const hljs = await import("highlight.js")
      hljs.default.highlightElement(block)
      this.processNext()
    })
  }
}
```
