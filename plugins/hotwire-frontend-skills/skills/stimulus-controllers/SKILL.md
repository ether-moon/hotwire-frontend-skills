---
name: stimulus-controllers
description: >-
  Implements robust Stimulus controllers: lifecycle hooks, values and valueChanged callbacks,
  targets and target callbacks, outlets API, action parameters, keyboard events,
  MutationObserver patterns, and production-ready controller design.
  Use when building Stimulus controllers, adding JavaScript behavior, wiring up interactivity,
  implementing toggles, dropdowns, or client-side DOM interactions.
  Cross-references: hotwire-forms for form controllers, turbo-streams for stream orchestration,
  turbo-navigation-rendering for navigation controllers.
allowed-tools: Read, Grep, Glob, Task, mcp__context7__resolve-library-id, mcp__context7__query-docs
---

# Stimulus Controllers

Implement lightweight, composable Stimulus controllers that enhance server-rendered HTML without reinventing a client-side framework.

## Core Workflow

### Step 1: Define the Controller Contract

Before writing code, declare the full public surface:

| Element | Purpose | Declaration |
|---|---|---|
| Targets | DOM elements the controller reads or mutates | `static targets = ["name"]` |
| Values | Reactive state with type checking and defaults | `static values = { open: Boolean }` |
| Outlets | References to other controllers on the page | `static outlets = ["other-controller"]` |
| Actions | Event handlers wired from HTML | `data-action="click->controller#method"` |
| CSS Classes | Logical class names mapped to real CSS classes | `static classes = ["active"]` |

Define all of these in static properties before writing methods. This makes the controller self-documenting.

### Step 2: Keep State in Values With valueChanged Callbacks

Never store state in instance variables. Use the Values API — declare typed values with defaults and react via `valueChanged` callbacks. See `references/values-changed-callbacks.md` for full patterns and type tables.

### Step 3: Use connect/disconnect for Setup/Teardown Symmetry

Everything set up in `connect()` must be cleaned up in `disconnect()`. Guard callbacks that can run before `connect()` completes. See `references/lifecycle-connect-disconnect.md` for setup/teardown patterns.

### Step 4: Isolate DOM Handling From Business Logic

Controllers should only bridge HTML and behavior. Extract complex logic into plain JavaScript modules — import utilities and call them from callbacks.

### Step 5: Keep Controllers Composable and Under 50 Lines

| Size | Action |
|---|---|
| Under 50 lines | Ship it |
| 50–100 lines | Review for extraction opportunities |
| Over 100 lines | Split into composable controllers |

Compose via outlets, custom events (`this.dispatch()`), or shared values through the DOM.

## Guardrails

1. **Prefer declarative action parameters over manual dataset parsing.**
   ```html
   <!-- GOOD -->
   <button data-action="cart#add" data-cart-id-param="42" data-cart-quantity-param="1">Add</button>

   <!-- BAD -->
   <button data-action="cart#add" data-id="42" data-quantity="1">Add</button>
   ```

2. **Use outlets for controller-to-controller communication.**
   ```javascript
   // GOOD: Outlet provides direct access
   static outlets = ["search-results"]
   filter() { this.searchResultsOutlet.update(this.queryValue) }

   // BAD: querySelector is fragile
   filter() { document.querySelector("[data-controller='search-results']").update() }
   ```

3. **Keep target callbacks idempotent.** They may fire multiple times (Turbo morphing, reconnection).
   ```javascript
   // GOOD: Idempotent — sets state
   itemTargetConnected(target) {
     this.countValue = this.itemTargets.length
   }

   // BAD: Non-idempotent — appends
   itemTargetConnected(target) {
     this.countValue += 1
   }
   ```

4. **Feature-detect browser APIs before exposing UI.** Hide elements in `connect()` when the required API is unavailable.

5. **Clean up in disconnect() everything set up in connect().** No exceptions.

6. **Use `this.dispatch()` for custom events, not `new CustomEvent()`.**
   `dispatch()` returns a `CustomEvent` and supports options: `detail`, `target`, `prefix`, `bubbles`, and `cancelable`. Check `event.defaultPrevented` to see if a listener cancelled the event.
   ```javascript
   // GOOD
   const event = this.dispatch("selected", { detail: { id: this.idValue } })
   if (event.defaultPrevented) return // a listener called preventDefault()

   // BAD
   this.element.dispatchEvent(new CustomEvent("selected", { detail: { id: this.idValue } }))
   ```

7. **Use MutationObserver only when DOM-driven reactivity is required.** Guard against infinite loops.

8. **Separate browser event concerns from Turbo lifecycle concerns.** DOM events (click, input, resize) and Turbo events (turbo:load, turbo:before-cache) serve different purposes.

## References

| Topic | File |
|---|---|
| Lifecycle (connect/disconnect, Turbo re-entry) | `references/lifecycle-connect-disconnect.md` |
| Values + valueChanged callbacks | `references/values-changed-callbacks.md` |
| Target callbacks (dynamic content) | `references/targets-target-callbacks.md` |
| Outlets API (controller communication) | `references/outlets-api.md` |
| Action parameters + keyboard filters | `references/action-parameters-keyboard.md` |
| Production-ready patterns | `references/production-controllers.md` |
| Core Web Vitals / performance | `references/core-web-vitals.md` |
| MutationObserver sorting | `references/auto-sorting-mutation-observer.md` |
| Web Share API | `references/web-share-api.md` |
| Anti-patterns | `examples/anti-patterns.md` |

Full catalog: `references/INDEX.md`. API details: `handbook/INDEX.md`.

Out-of-scope requests: route back to `frontend-craft` for triage.
