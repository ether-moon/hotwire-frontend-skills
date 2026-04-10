---
title: "Outlets API"
---

> For API reference, see `handbook/stimulus-outlets-api.md`. This file covers practical patterns beyond the API spec.

# Outlets API

## Table of Contents

- [Implementation](#implementation)
  - [Outlet Lifecycle Patterns](#outlet-lifecycle-patterns)
  - [Bidirectional Communication](#bidirectional-communication)
  - [Outlets vs Events vs Globals](#outlets-vs-events-vs-globals)
- [Pattern Card](#pattern-card)

## Implementation

### Outlet Lifecycle Patterns

Outlet callbacks fire when outlet controllers connect or disconnect. This is useful for initialization that depends on another controller being ready.

Each declared outlet generates five properties: `has[Name]Outlet` (existence check), `[name]Outlet` (first controller instance), `[name]Outlets` (all controller instances), `[name]OutletElement` (first outlet element), and `[name]OutletElements` (all outlet elements). The element properties provide direct access to the DOM elements without going through the controller instance.

**Namespaced controllers:** For outlets referencing namespaced controllers (e.g., `admin--user-status`), the property name omits the namespace separator: use `this.adminUserStatusOutlet`, not `this.admin__UserStatusOutlet`.

```javascript
// app/javascript/controllers/form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["validation"]

  validationOutletConnected(controller, element) {
    // The validation controller is now ready
    controller.configure({
      rules: this.validationRules(),
      onValid: () => this.enableSubmit(),
      onInvalid: () => this.disableSubmit()
    })
  }

  validationOutletDisconnected(controller, element) {
    this.disableSubmit()
  }

  validationRules() {
    return {
      email: { required: true, format: "email" },
      name: { required: true, minLength: 2 }
    }
  }

  enableSubmit() {
    this.element.querySelector("[type=submit]").disabled = false
  }

  disableSubmit() {
    this.element.querySelector("[type=submit]").disabled = true
  }
}
```

### Bidirectional Communication

Two controllers can reference each other via outlets. This creates a tight, explicit coupling:

```javascript
// app/javascript/controllers/sidebar_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["main-content"]
  static values = { open: { type: Boolean, default: true } }

  openValueChanged() {
    this.element.classList.toggle("sidebar--collapsed", !this.openValue)

    if (this.hasMainContentOutlet) {
      this.mainContentOutlet.sidebarToggled(this.openValue)
    }
  }

  toggle() {
    this.openValue = !this.openValue
  }
}
```

```javascript
// app/javascript/controllers/main_content_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["sidebar"]

  sidebarToggled(isOpen) {
    this.element.classList.toggle("main-content--full", !isOpen)
  }

  expandSidebar() {
    if (this.hasSidebarOutlet) {
      this.sidebarOutlet.openValue = true
    }
  }
}
```

```html
<div data-controller="sidebar"
     data-sidebar-main-content-outlet="#main"
     data-sidebar-open-value="true">
  <button data-action="sidebar#toggle">Toggle Sidebar</button>
  <!-- sidebar content -->
</div>

<div data-controller="main-content"
     data-main-content-sidebar-outlet="[data-controller='sidebar']"
     id="main">
  <!-- main content -->
</div>
```

**Caution:** Bidirectional outlets create tight coupling. Prefer unidirectional outlets or events when the relationship does not require direct method calls in both directions.

### Outlets vs Events vs Globals

| Approach | Coupling | Type Safety | Use When |
|----------|----------|-------------|----------|
| **Outlets** | Explicit, declared | Yes (controller instances) | Known, direct relationship between two controllers |
| **Custom events** (`this.dispatch()`) | Loose | No (event.detail) | Broadcasting to unknown listeners |
| **Global state** (window, document) | None | No | Never in Stimulus (use outlets or events) |

```javascript
// Outlets: direct method call
this.searchResultsOutlet.update(query)

// Events: broadcast, anyone can listen
this.dispatch("searched", { detail: { query } })
// Listener: data-action="search:searched->results#handleSearch"

// Global: DO NOT DO THIS
window.searchQuery = query
```

**Choose outlets when:**
- You know exactly which controller needs to respond.
- You need to call specific methods with arguments.
- The relationship is visible in the HTML.

**Choose events when:**
- Multiple controllers might respond.
- The responding controllers are not known at authoring time.
- You want the loosest possible coupling.

## Pattern Card

### GOOD: Outlet-based coordination

```javascript
// Dropdown controller tells the tooltip controller to hide
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["tooltip"]
  static values = { open: { type: Boolean, default: false } }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    // Direct, typed communication
    if (this.openValue && this.hasTooltipOutlet) {
      this.tooltipOutlet.hide()
    }
  }
}
```

```html
<div data-controller="dropdown"
     data-dropdown-tooltip-outlet="#user-tooltip">
  <button data-action="dropdown#toggle">Menu</button>
</div>

<div data-controller="tooltip" id="user-tooltip">
  Helpful tooltip
</div>
```

The relationship is explicit in HTML, type-safe in JavaScript, and easy to trace during debugging.

### BAD: Global event bus or window variables

```javascript
// DO NOT DO THIS
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle() {
    this.open = !this.open

    // Globals are untraceable and pollute the shared namespace
    window.dropdownState = { open: this.open }

    // Event bus with no clear consumer
    document.dispatchEvent(
      new CustomEvent("dropdown:toggled", { detail: { open: this.open } })
    )
  }
}
```

Global variables create hidden dependencies. Custom events on `document` make it impossible to trace who is listening. The relationship between controllers is invisible in the HTML and requires reading every controller's source to understand.
