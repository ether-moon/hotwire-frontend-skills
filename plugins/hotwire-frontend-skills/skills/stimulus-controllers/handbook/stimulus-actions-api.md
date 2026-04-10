---
title: "Actions"
---

# Actions

Actions connect controller methods to DOM event listeners.

```html
<div data-controller="gallery">
  <button data-action="click->gallery#next">...</button>
</div>
```

## Descriptors

Format: `event->controller#method` (e.g., `click->gallery#next`).

### Event Shorthand

Omit the event name for common element/event pairs:

Element           | Default Event
----------------- | -------------
a                 | click
button            | click
details           | toggle
form              | submit
input             | input
input type=submit | click
select            | change
textarea          | input

### KeyboardEvent Filter

Add key filters to the event name (e.g., `keydown.esc->modal#close`).

Filter    | Key Name
--------  | --------
enter     | Enter
tab       | Tab
esc       | Escape
space     | " "
up        | ArrowUp
down      | ArrowDown
left      | ArrowLeft
right     | ArrowRight
home      | Home
end       | End
page_up   | PageUp
page_down | PageDown
[a-z]     | [a-z]
[0-9]     | [0-9]

Custom key mappings:

```javascript
import { Application, defaultSchema } from "@hotwired/stimulus"

const customSchema = {
  ...defaultSchema,
  keyMappings: { ...defaultSchema.keyMappings, at: "@" },
}
const app = Application.start(document.documentElement, customSchema)
```

Compound filters with modifier keys use `+` syntax (e.g., `keydown.ctrl+a->listbox#selectAll`).

| Modifier | Notes              |
| -------- | ------------------ |
| `alt`    | `option` on MacOS  |
| `ctrl`   |                    |
| `meta`   | Command key on MacOS |
| `shift`  |                    |

### Global Events

Append `@window` or `@document` to listen on global objects:

```html
<div data-controller="gallery"
     data-action="resize@window->gallery#layout">
</div>
```

### Options

Append action options after a colon:

```html
<div data-controller="gallery"
     data-action="scroll->gallery#layout:!passive">
  <img data-action="click->gallery#open:capture">
```

**DOM event listener options:**

Action option | DOM event listener option
------------- | -------------------------
`:capture`    | `{ capture: true }`
`:once`       | `{ once: true }`
`:passive`    | `{ passive: true }`
`:!passive`   | `{ passive: false }`

**Custom Stimulus options:**

Custom action option | Description
-------------------- | -----------
`:stop`              | calls `.stopPropagation()` before invoking the method
`:prevent`           | calls `.preventDefault()` before invoking the method
`:self`              | only invokes the method if the event was fired by the element itself

### Registering Custom Action Options

```javascript
application.registerActionOption("open", ({ event, value }) => {
  if (event.type == "toggle") {
    return event.target.open == value
  }
  return true
})
```

Return `false` to prevent routing to the controller action. Callback argument keys:

| Name       | Description                                                                           |
| ---------- | ------------------------------------------------------------------------------------- |
| name       | String: The option's name                                                             |
| value      | Boolean: `:open` yields `true`, `:!open` yields `false`                              |
| event      | Event: The event instance, including `params` on the submitter element                |
| element    | Element: The element where the action descriptor is declared                          |
| controller | The `Controller` instance which would receive the method call                         |

## Event Objects

Action methods receive the DOM event as their first argument.

Event Property      | Value
------------------- | -----
event.type          | The name of the event (e.g. `"click"`)
event.target        | The target that dispatched the event (innermost clicked element)
event.currentTarget | The element with `data-action`, or `document`/`window`
event.params        | Action params passed by the submitter element

Event Method            | Result
----------------------- | ------
event.preventDefault()  | Cancels the event's default behavior
event.stopPropagation() | Stops the event before it bubbles up to parent elements

## Multiple Actions

Space-separated list of descriptors. Invoked left to right. Stop the chain with `event.stopImmediatePropagation()`.

```html
<input type="text" data-action="focus->field#highlight input->search#update">
```

## Naming Conventions

Use camelCase. Name methods by behavior, not event:

```html
<!-- Avoid --> <button data-action="click->profile#click">
<!-- Prefer --> <button data-action="click->profile#showDialog">
```

## Action Parameters

Format: `data-[identifier]-[param-name]-param` on the same element as the action.

Auto-typecast rules:

Data attribute                                  | Param                | Type
----------------------------------------------- | -------------------- | --------
`data-item-id-param="12345"`                    | `12345`              | Number
`data-item-url-param="/votes"`                  | `"/votes"`           | String
`data-item-payload-param='{"value":"1234567"}'` | `{ value: 1234567 }` | Object
`data-item-active-param="true"`                 | `true`               | Boolean

Parameters are scoped to their controller's identifier:

```html
<div data-controller="item spinner">
  <button data-action="item#upvote spinner#start"
    data-item-id-param="12345"
    data-item-url-param="/votes"
    data-item-payload-param='{"value":"1234567"}'
    data-item-active-param="true">...</button>
</div>
```

```js
// ItemController - receives params
upvote({ params: { id, url } }) {
  console.log(id)  // 12345
  console.log(url) // "/votes"
}

// SpinnerController - params is empty {}
start(event) {
  console.log(event.params) // {}
}
```
