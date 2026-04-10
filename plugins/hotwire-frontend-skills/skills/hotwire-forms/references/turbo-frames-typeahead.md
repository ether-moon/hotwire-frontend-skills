---
title: "Typeahead Search with Turbo Frames"
---

# Typeahead Search with Turbo Frames

> Use a GET form targeting a Turbo Frame with a debounced Stimulus controller for instant search-as-you-type without custom fetch logic.

## Decision

- GET form (not POST) so search results are bookmarkable
- Form lives **outside** the results frame so it is not replaced on update
- Stimulus controller handles debounced auto-submit via `requestSubmit()`
- `data-turbo-action="advance"` pushes query params to browser history
- Same controller action serves initial page load and search requests

Debounce guidelines:
| Dataset | Delay |
|---------|-------|
| Small / local filtering | 150-200ms |
| Server-side search (default) | 300ms |
| Heavy queries / rate-limited APIs | 500ms |

## Architecture

```
Search form (GET)              Server
+---------------------------+  +---------------------------+
| [Search: "buy gro____"]  |  | TasksController#index     |
|   data-turbo-frame=       |  |   @tasks = Task.search(q) |
|     "tasks_results"       |  |   render partial results  |
|                           |  +---------------------------+
| turbo_frame "tasks_results"|         |
|   Task 1: Buy groceries   |  <------+
|   Task 3: Buy grout       |  HTML response with
+---------------------------+  matching turbo_frame
```

## Pattern

### Search form + results frame

```erb
<%= form_with url: tasks_path,
      method: :get,
      data: {
        turbo_frame: "tasks_results",
        turbo_action: "advance",
        controller: "auto-submit",
        auto_submit_delay_value: 300
      } do |f| %>
  <%= f.search_field :q,
        value: params[:q],
        placeholder: "Search tasks...",
        autocomplete: "off",
        data: { action: "input->auto-submit#submit" } %>
<% end %>

<%= turbo_frame_tag "tasks_results" do %>
  <%= render @tasks %>
<% end %>
```

### Auto-submit Stimulus controller

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()  // Must use requestSubmit(), not submit()
    }, this.delayValue)
  }

  disconnect() { clearTimeout(this.timeout) }
}
```

`requestSubmit()` fires the `submit` event that Turbo listens for. `submit()` bypasses Turbo entirely.

### Controller action + model scope

```ruby
# Controller
def index
  @tasks = Task.all
  @tasks = @tasks.search(params[:q]) if params[:q].present?
end

# Model
scope :search, ->(query) {
  where("title ILIKE :q OR description ILIKE :q", q: "%#{sanitize_sql_like(query)}%")
}
```

### Combining search with filters

Put all filter fields in the same form. Text input triggers on `input` (debounced); selects trigger on `change` (immediate):

```erb
<%= form_with url: tasks_path, method: :get,
      data: { turbo_frame: "tasks_results", controller: "auto-submit" } do |f| %>
  <%= f.search_field :q, value: params[:q],
        data: { action: "input->auto-submit#submit" } %>
  <%= f.select :status,
        options_for_select([["All", ""], "Open", "Closed"], params[:status]),
        {}, { data: { action: "change->auto-submit#submit" } } %>
<% end %>
```

### CSS-only loading state

Turbo Frames automatically set `aria-busy="true"` while loading -- no JS needed:

```css
turbo-frame[aria-busy="true"] {
  opacity: 0.6;
  pointer-events: none;
}
```

## Typeahead Validation (Focus Preservation)

For real-time field validation via Turbo Frames, the challenge is preserving input focus and caret position during frame updates.

### Capture/restore pattern

```javascript
let activeElementId = '', selectionStart = 0, selectionEnd = 0;

document.addEventListener('turbo:submit-start', () => {
  const input = document.activeElement;
  if (input?.tagName === 'INPUT') {
    activeElementId = input.id;
    selectionStart = input.selectionStart ?? 0;
    selectionEnd = input.selectionEnd ?? selectionStart;
  }
});

document.addEventListener('turbo:before-fetch-request', (event) => {
  if (activeElementId) {
    event.detail.fetchOptions.headers['X-Validation-Only'] = 'true';
  }
});

document.addEventListener('turbo:frame-render', () => {
  if (activeElementId) {
    const input = document.querySelector(`#${activeElementId}`);
    input?.focus();
    input?.setSelectionRange(selectionStart, selectionEnd);
  }
});
```

### Alternative: Idiomorph

```javascript
document.addEventListener('turbo:before-frame-render', (e) => {
  e.detail.render = (currentElement, newElement) => {
    Idiomorph.morph(currentElement, newElement);
  };
});
```

Idiomorph handles focus/selection preservation automatically.

## Pitfalls

### Bypassing Turbo with manual fetch

```javascript
// BAD -- no Turbo, no debounce, no loading state, breaks back/forward nav
searchInput.addEventListener("input", async (e) => {
  const response = await fetch(`/tasks/search?q=${e.target.value}`)
  document.querySelector("#results").innerHTML = await response.text()
})

// GOOD -- use the form + frame + auto-submit pattern above
```

### Using submit() instead of requestSubmit()

```javascript
// BAD -- bypasses Turbo
this.element.submit()

// GOOD -- fires the submit event Turbo listens for
this.element.requestSubmit()
```

### Non-bookmarkable search

```erb
<%# BAD -- POST form, results are not bookmarkable %>
<%= form_with url: search_path, method: :post %>

<%# GOOD -- GET form with turbo_action="advance" %>
<%= form_with url: search_path, method: :get,
      data: { turbo_action: "advance" } %>
```

### Validation without focus preservation

When doing typeahead validation inside a Turbo Frame, always capture `activeElement` ID and selection range on `turbo:submit-start` and restore on `turbo:frame-render`. Element IDs are required since DOM nodes are replaced.
