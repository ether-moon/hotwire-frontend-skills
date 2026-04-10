---
title: "Action Parameters and Keyboard Events"
---

# Action Parameters and Keyboard Events

> For form-specific action parameter patterns, see `hotwire-forms/references/action-parameters-forms.md`.

Stimulus action descriptors support three features beyond basic event binding: **action parameters** (typed data from HTML to handler via `event.params`), **keyboard event filters** (restrict to specific keys), and **action options** (prevent default, stop propagation, etc.). These eliminate manual `event.key` checking, `event.preventDefault()` calls, and `dataset` parsing.

## Action Parameters

Parameters are declared as `data-[controller]-[name]-param` attributes on the element with the action:

```html
<div data-controller="cart">
  <button data-action="cart#add"
          data-cart-id-param="42"
          data-cart-quantity-param="1"
          data-cart-name-param="Widget">
    Add to Cart
  </button>
</div>
```

```javascript
// Parameters available on event.params, scoped to the controller
add(event) {
  const { id, quantity, name } = event.params
}
```

### Type Coercion

Stimulus automatically coerces action parameters based on the value:

| HTML Value | Coerced Type | JavaScript Value |
|-----------|-------------|-----------------|
| `"42"` | Number | `42` |
| `"3.14"` | Number | `3.14` |
| `"true"` | Boolean | `true` |
| `"false"` | Boolean | `false` |
| `'{"a":1}'` | Object | `{ a: 1 }` |
| `'[1,2,3]'` | Array | `[1, 2, 3]` |
| `"hello"` | String | `"hello"` |

**Note:** Official docs list four types: Number, String, Object, Boolean. Arrays work via `JSON.parse` but are not officially documented.

## Keyboard Event Filters

Add the key name after the event type, separated by a dot:

```html
<input data-action="keydown.enter->search#submit">
<div data-action="keydown.esc->modal#close">
<input data-action="keydown.down->autocomplete#next">
```

**Available key filters:**

| Filter | Key |
|--------|-----|
| `.enter` | Enter |
| `.tab` | Tab |
| `.esc` | Escape |
| `.space` | `" "` (space character) |
| `.up` | ArrowUp |
| `.down` | ArrowDown |
| `.left` | ArrowLeft |
| `.right` | ArrowRight |
| `.home` | Home |
| `.end` | End |
| `.page_up` | PageUp |
| `.page_down` | PageDown |
| `.[key]` | Any `KeyboardEvent.key` value |

**Modifier key combinations:** Combine modifiers with `+`, e.g. `keydown.ctrl+a`. Available modifiers: `alt`, `ctrl`, `meta`, `shift`.

You can also use exact `KeyboardEvent.key` values (e.g. `keydown.Enter`, `keydown.k`, `keydown./`).

## Action Options

Append options to the action descriptor with a colon:

| Option | Effect | Equivalent To |
|--------|--------|---------------|
| `:prevent` | Calls `event.preventDefault()` | `event.preventDefault()` in handler |
| `:stop` | Calls `event.stopPropagation()` | `event.stopPropagation()` in handler |
| `:self` | Only fires if `event.target` is the element itself | `if (event.target !== this.element) return` |
| `:once` | Removes listener after first invocation | `{ once: true }` option |
| `:capture` | Uses capture phase | `{ capture: true }` option |
| `:passive` | Marks listener as passive | `{ passive: true }` option |
| `:!passive` | Marks listener as not passive | `{ passive: false }` option |

```html
<form data-action="submit->checkout#process:prevent">
<button data-action="click->dropdown#toggle:stop">Menu</button>
<div data-action="click->modal#close:self" class="modal-backdrop">
<button data-action="click->analytics#trackFirstClick:once">
<form data-action="submit->form#save:prevent:stop">
```

## Action Descriptor Syntax Reference

Full syntax:

```
event->controller#method:option1:option2
event.key->controller#method:option1:option2
```

**Global event targets:** Append `@window` or `@document` to listen on those targets:

```html
<div data-action="keydown@window->shortcuts#handle">
<div data-action="click@document->overlay#close">
```

**Default events** -- Stimulus infers the event for common elements:

| Element | Default Event |
|---------|--------------|
| `<a>` | `click` |
| `<button>` | `click` |
| `<details>` | `toggle` |
| `<form>` | `submit` |
| `<input>` | `input` |
| `<input type="submit">` | `click` |
| `<select>` | `change` |
| `<textarea>` | `input` |
| Everything else | `click` |

```html
<!-- These pairs are equivalent -->
<form data-action="submit->form#save">
<form data-action="form#save">

<input data-action="input->search#filter">
<input data-action="search#filter">
```

## Combining Parameters, Filters, and Options

All three features work together. Practical autocomplete example:

```html
<div data-controller="autocomplete">
  <input data-autocomplete-target="input"
         data-action="
           input->autocomplete#search
           keydown.down->autocomplete#next:prevent
           keydown.up->autocomplete#previous:prevent
           keydown.enter->autocomplete#select:prevent
           keydown.esc->autocomplete#dismiss
         ">
  <ul data-autocomplete-target="results" hidden></ul>
</div>
```

Navigation with parameters, filter, and options:

```html
<div data-controller="nav">
  <input data-action="keydown.enter->nav#navigate:prevent:stop"
         data-nav-url-param="/dashboard"
         data-nav-method-param="turbo"
         placeholder="Press Enter to go to Dashboard">
</div>
```

```javascript
navigate(event) {
  const { url, method } = event.params
  // :prevent already called preventDefault()
  // .enter filter ensures only Enter key fires this
  method === "turbo" ? Turbo.visit(url) : window.location.href = url
}
```
