---
title: "Stimulus Action Parameters in Forms"
---

# Stimulus Action Parameters in Forms

> Pass per-element data from HTML to Stimulus actions declaratively via `data-<controller>-<name>-param` attributes -- no manual dataset parsing needed.

## Decision

| Feature | When to Use | Scope |
|---------|------------|-------|
| Action Parameters | Data varies per element that triggers the action | Per-element |
| Stimulus Values | Configuration for the controller instance | Per-controller |
| Data Attributes (manual) | Avoid -- use action params or values instead | -- |

Action parameters are ideal for: different buttons triggering the same action with different config, conditional field visibility, multi-submit-button forms.

## How It Works

```
HTML element with action + params        Stimulus action method
+--------------------------------------+  +---------------------------+
| <button                              |  | toggle(event) {           |
|   data-action="form#toggle"          |  |   const { section } =    |
|   data-form-section-param="billing"  |  |     event.params         |
| >                                    |->|   // section = "billing" |
+--------------------------------------+  +---------------------------+
```

The attribute `data-form-section-param` becomes `event.params.section`. The `form` part matches the controller name.

### Type coercion

| Attribute Value | JS Type | Result |
|----------------|---------|--------|
| `"hello"` | String | `"hello"` |
| `"42"` | Number | `42` |
| `"true"` | Boolean | `true` |
| `"{\"a\":1}"` | Object | `{ a: 1 }` |

Stimulus auto-coerces. Array parsing via `JSON.parse` works internally but is not part of the official spec.

## Pattern

### Per-button actions (e.g., shipping speed selection)

```erb
<%= form_with model: @order, data: { controller: "order-form" } do |f| %>
  <% %w[standard express overnight].each do |speed| %>
    <button type="button"
            data-action="order-form#selectShipping"
            data-order-form-speed-param="<%= speed %>"
            data-order-form-price-param="<%= shipping_price(speed) %>">
      <%= speed.capitalize %>
    </button>
  <% end %>

  <%= f.hidden_field :shipping_speed, data: { order_form_target: "shippingInput" } %>
<% end %>
```

```javascript
export default class extends Controller {
  static targets = ["shippingInput", "summary"]

  selectShipping(event) {
    const { speed, price } = event.params
    this.shippingInputTarget.value = speed
    this.summaryTarget.textContent = `${speed} shipping: $${price}`
  }
}
```

### Conditional field visibility

```erb
<%= form_with model: @contact, data: { controller: "conditional-fields" } do |f| %>
  <%= f.select :contact_type,
        [["Individual", "individual"], ["Company", "company"]],
        {}, { data: { action: "conditional-fields#toggle" } } %>

  <div data-conditional-fields-target="section" data-section="individual">
    <%= f.text_field :first_name %>
    <%= f.text_field :last_name %>
  </div>

  <div data-conditional-fields-target="section" data-section="company" class="hidden">
    <%= f.text_field :company_name %>
    <%= f.text_field :tax_id %>
  </div>
<% end %>
```

```javascript
export default class extends Controller {
  static targets = ["section"]

  toggle(event) {
    const selectedValue = event.currentTarget.value
    this.sectionTargets.forEach(section => {
      const shouldShow = section.dataset.section === selectedValue
      section.classList.toggle("hidden", !shouldShow)
      // Disable hidden inputs so they are not submitted
      section.querySelectorAll("input, select, textarea").forEach(input => {
        input.disabled = !shouldShow
      })
    })
  }
}
```

### Multi-submit buttons (draft vs publish)

```erb
<%= form_with model: @article, data: { controller: "article-form" } do |f| %>
  <%= f.text_field :title %>
  <%= f.text_area :body %>

  <button type="submit"
          data-action="article-form#submitWithStatus"
          data-article-form-status-param="draft"
          data-turbo-submits-with="Saving Draft...">
    Save Draft
  </button>
  <button type="submit"
          data-action="article-form#submitWithStatus"
          data-article-form-status-param="published"
          data-turbo-submits-with="Publishing...">
    Publish
  </button>
<% end %>
```

```javascript
export default class extends Controller {
  submitWithStatus(event) {
    const { status } = event.params
    let hiddenField = this.element.querySelector("input[name='article[status]']")
    if (!hiddenField) {
      hiddenField = document.createElement("input")
      hiddenField.type = "hidden"
      hiddenField.name = "article[status]"
      this.element.appendChild(hiddenField)
    }
    hiddenField.value = status
  }
}
```

## Pitfalls

### Manual dataset parsing instead of action params

```erb
<%# BAD -- attribute names disconnected from controller %>
<button data-action="task-form#setPriority"
        data-priority-level="high">
```

```javascript
// BAD -- manual parsing, no type coercion, must use currentTarget
setPriority(event) {
  const level = event.currentTarget.dataset.priorityLevel
}

// GOOD -- declarative, auto-coerced, controller-namespaced
setPriority(event) {
  const { level } = event.params
}
```

### Forgetting to disable hidden inputs

```javascript
// BAD -- hidden section's inputs still submit with the form
section.classList.add("hidden")

// GOOD -- disable inputs in hidden sections
section.classList.toggle("hidden", !shouldShow)
section.querySelectorAll("input, select, textarea").forEach(input => {
  input.disabled = !shouldShow
})
```

### Using event.target instead of event.currentTarget

Action params are attached to the element with the `data-action` attribute. If the click lands on a child element, `event.target` is the child, not the element with params. Stimulus handles this for you when you use `event.params` -- but manual `dataset` access requires `event.currentTarget`.
