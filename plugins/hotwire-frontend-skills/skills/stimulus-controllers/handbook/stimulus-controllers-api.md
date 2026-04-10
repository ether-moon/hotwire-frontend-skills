---
title: "Controllers"
---

# Controllers

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // ...
}
```

## Properties

* `this.application` -- the Stimulus `Application` instance
* `this.element` -- the controller's HTML element
* `this.identifier` -- the controller's identifier string

## Modules

One controller per file in `controllers/`. Export as default. Name files `[identifier]_controller.js`.

## Identifiers

The `data-controller` attribute value maps to a controller class:

```html
<div data-controller="reference"></div>
```

Filename-to-identifier mapping:

If your controller file is named...  | its identifier will be...
------------------------------------ | -----------------------
clipboard_controller.js              | clipboard
date_picker_controller.js            | date-picker
users/list_item_controller.js        | users\-\-list-item
local-time-controller.js             | local-time

## Scopes

The controller's element and all its children form the controller's scope. Nested controllers are only aware of their own scope, excluding nested controller scopes.

```html
<ul data-controller="list">
  <li data-list-target="item">One</li>  <!-- in scope -->
  <li>
    <ul data-controller="list">
      <li data-list-target="item">Nested</li>  <!-- NOT in parent scope -->
    </ul>
  </li>
</ul>
```

## Multiple Controllers

Space-separated identifiers on one element. Multiple elements can reference the same controller class (each gets its own instance).

```html
<div data-controller="clipboard list-item"></div>
```

## Naming Conventions

- Methods/properties: camelCase
- Identifiers: kebab-case (`date-picker`, `list-item`)
- Filenames: snake_case or kebab-case (`date_picker_controller.js` or `date-picker-controller.js`)

## Registration

Auto-registered with Stimulus for Rails (import map) or `@hotwired/stimulus-webpack-helpers`.

### Manual Registration

```js
import ReferenceController from "./controllers/reference_controller"
application.register("reference", ReferenceController)
```

Inline registration:

```js
application.register("reference", class extends Controller {
  // ...
})
```

### Conditional Loading with `shouldLoad`

```js
class UnloadableController extends ApplicationController {
  static get shouldLoad() {
    return false
  }
}
```

### Post-Registration Hook with `afterLoad`

Called immediately when registered (DOM may not be loaded yet). Bound to the controller constructor with `(identifier, application)` arguments.

```js
class SpinnerButton extends Controller {
  static afterLoad(identifier, application) {
    const { controllerAttribute } = application.schema
    const update = () => {
      document.querySelector(".legacy-spinner-button")?.forEach((el) => {
        el.setAttribute(controllerAttribute, identifier)
      })
    }
    document.readyState == "loading"
      ? document.addEventListener("DOMContentLoaded", update)
      : update()
  }
}
```

## Cross-Controller Coordination With Events

Use `this.dispatch()` to emit custom events prefixed with the controller identifier:

```js
class ClipboardController extends Controller {
  static targets = [ "source" ]

  copy() {
    this.dispatch("copy", { detail: { content: this.sourceTarget.value } })
    navigator.clipboard.writeText(this.sourceTarget.value)
  }
}
```

Route to another controller's action:

```html
<div data-controller="clipboard effects" data-action="clipboard:copy->effects#flash">
  PIN: <input data-clipboard-target="source" type="text" value="1234" readonly>
  <button data-action="clipboard#copy">Copy to Clipboard</button>
</div>
```

```js
class EffectsController extends Controller {
  flash({ detail: { content } }) {
    console.log(content) // 1234
  }
}
```

If the receiving controller is not a parent/same element as the emitter, use `@window`:

```html
<div data-action="clipboard:copy@window->effects#flash">
```

### `dispatch` Options

option       | default            | notes
-------------|--------------------|------------------------------
`detail`     | `{}` empty object  | [CustomEvent.detail](https://developer.mozilla.org/en-US/docs/Web/API/CustomEvent/detail)
`target`     | `this.element`     | [Event.target](https://developer.mozilla.org/en-US/docs/Web/API/Event/target)
`prefix`     | `this.identifier`  | Falsey value uses only `eventName`; string value prepends with colon
`bubbles`    | `true`             | [Event.bubbles](https://developer.mozilla.org/en-US/docs/Web/API/Event/bubbles)
`cancelable` | `true`             | [Event.cancelable](https://developer.mozilla.org/en-US/docs/Web/API/Event/cancelable)

### Cancellable Events

`dispatch` returns the `CustomEvent`. Check `defaultPrevented` to allow listeners to cancel:

```js
copy() {
  const event = this.dispatch("copy", { cancelable: true })
  if (event.defaultPrevented) return
  navigator.clipboard.writeText(this.sourceTarget.value)
}
```

## Directly Invoking Other Controllers

Use only when events are not possible:

```js
const other = this.application.getControllerForElementAndIdentifier(this.otherTarget, 'other')
other.otherMethod()
```
