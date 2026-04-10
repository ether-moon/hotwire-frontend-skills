---
title: "Inline Editing with Turbo Frames"
---

# Inline Editing with Turbo Frames

## Table of Contents

- [Overview](#overview)
- [How Frame Swapping Works for Inline Edit](#how-frame-swapping-works-for-inline-edit)
- [Implementation](#implementation)
  - [Display View (Show State)](#display-view-show-state)
  - [Edit View (Edit State)](#edit-view-edit-state)
  - [Controller Actions](#controller-actions)
  - [Auto-Focus on Frame Load](#auto-focus-on-frame-load)
  - [Submit on Blur](#submit-on-blur)
  - [State Persistence with turbo:frame-render](#state-persistence-with-turboframe-render)
- [Cancelling an Edit](#cancelling-an-edit)
- [Inline Edit in a List](#inline-edit-in-a-list)
- [Pattern Card](#pattern-card)

## Overview

Inline editing lets users click on a piece of content to transform it into an editable form, make their change, and save -- all without leaving the page. With Turbo Frames, this is achieved by wrapping both the display state and the edit form in a frame with the same ID. Clicking "edit" navigates within the frame, swapping the display content for the form. Submitting the form swaps back to the updated display content.

This pattern is ideal for:
- Editable table cells or list items
- Title and description fields that toggle between display and edit
- Settings pages where each field is independently editable
- Any content where navigating to a full edit page feels heavyweight

## How Frame Swapping Works for Inline Edit

```
Display State                    Edit State
+---------------------------+    +---------------------------+
| turbo_frame "task_1"      |    | turbo_frame "task_1"      |
|                           |    |                           |
|  "Buy groceries"  [Edit]  | -> |  [input: Buy groceries]   |
|                           |    |  [Save] [Cancel]          |
+---------------------------+    +---------------------------+
        click Edit                      submit form
             |                               |
             v                               v
    GET /tasks/1/edit              PATCH /tasks/1
    (returns edit frame)           422 -> re-render form
                                   303 -> redirect to show
                                   (returns display frame)
```

Both the show and edit responses include a `turbo_frame_tag` with the same ID. Turbo extracts the matching frame from the response and swaps it in place.

## Implementation

### Display View (Show State)

The show partial renders the content with an edit link. The edit link navigates within the frame because it is inside the `turbo_frame_tag`.

```erb
<%# app/views/tasks/_task.html.erb %>
<%= turbo_frame_tag dom_id(task) do %>
  <div class="flex items-center justify-between group">
    <span class="text-gray-900"><%= task.title %></span>
    <%= link_to "Edit",
          edit_task_path(task),
          class: "text-sm text-blue-600 opacity-0 group-hover:opacity-100 transition" %>
  </div>
<% end %>
```

### Edit View (Edit State)

The edit partial renders the form inside a frame with the same ID. On successful submit, the controller redirects to the show action, which returns the display partial inside the same frame.

```erb
<%# app/views/tasks/edit.html.erb %>
<%= turbo_frame_tag dom_id(@task) do %>
  <%= form_with model: @task, class: "flex items-center gap-2" do |f| %>
    <div class="flex-1">
      <%= f.text_field :title,
            class: "w-full rounded border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500",
            autofocus: true %>
      <% if @task.errors[:title].any? %>
        <p class="mt-1 text-sm text-red-600"><%= @task.errors[:title].first %></p>
      <% end %>
    </div>
    <%= f.submit "Save",
          class: "px-3 py-1 bg-blue-600 text-white rounded text-sm",
          data: { turbo_submits_with: "Saving..." } %>
    <%= link_to "Cancel", task_path(@task), class: "px-3 py-1 text-sm text-gray-600" %>
  <% end %>
<% end %>
```

### Controller Actions

The controller handles the standard edit/update cycle with proper status codes for Turbo.

```ruby
# app/controllers/tasks_controller.rb
class TasksController < ApplicationController
  before_action :set_task, only: %i[ show edit update ]

  def show
    # Renders the display partial inside the frame
  end

  def edit
    # Renders the edit form inside the frame
  end

  def update
    if @task.update(task_params)
      redirect_to @task, status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_task
      @task = Task.find(params[:id])
    end

    def task_params
      params.require(:task).permit(:title)
    end
end
```

The show view must also wrap content in the same frame so the redirect response includes the frame Turbo is looking for:

```erb
<%# app/views/tasks/show.html.erb %>
<%= render @task %>
```

### Auto-Focus on Frame Load

The `autofocus` attribute on the text field works when the frame loads. For cases where you need more control, use a Stimulus controller:

```javascript
// app/javascript/controllers/autofocus_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.inputTarget.focus()
    // Place cursor at end of text
    const length = this.inputTarget.value.length
    this.inputTarget.setSelectionRange(length, length)
  }
}
```

```erb
<%= form_with model: @task, data: { controller: "autofocus" } do |f| %>
  <%= f.text_field :title, data: { autofocus_target: "input" } %>
<% end %>
```

### Submit on Blur

For a seamless editing experience, submit the form when the user clicks away from the input field. This uses a small Stimulus controller.

```javascript
// app/javascript/controllers/submit_on_blur_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
```

```erb
<%= form_with model: @task,
      data: { controller: "submit-on-blur" } do |f| %>
  <%= f.text_field :title,
        data: { action: "blur->submit-on-blur#submit" },
        autofocus: true %>
<% end %>
```

Note: Use `requestSubmit()` instead of `submit()` so that Turbo intercepts the submission. The native `submit()` bypasses event listeners.

### State Persistence with turbo:frame-render

When an inline edit frame re-renders (after save or cancel), you may need to restore surrounding state. The `turbo:frame-render` event fires after the frame content is swapped.

```javascript
// app/javascript/controllers/inline_edit_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("turbo:frame-render", this.afterRender.bind(this))
  }

  afterRender() {
    // Restore highlight or focus to the parent row
    this.element.closest("tr")?.classList.add("just-updated")
    setTimeout(() => {
      this.element.closest("tr")?.classList.remove("just-updated")
    }, 2000)
  }
}
```

## Cancelling an Edit

The "Cancel" link navigates back to the show action within the frame:

```erb
<%= link_to "Cancel", task_path(@task), class: "text-sm text-gray-600" %>
```

Because this link is inside the frame, Turbo fetches the show page and extracts the matching frame, swapping the edit form back to the display state. No JavaScript needed.

## Inline Edit in a List

When editing items in a list, each item gets its own frame. This ensures editing one item does not affect others.

```erb
<%# app/views/tasks/index.html.erb %>
<ul>
  <% @tasks.each do |task| %>
    <li><%= render task %></li>
  <% end %>
</ul>
```

Each `_task.html.erb` partial is wrapped in its own frame with `dom_id(task)`, so clicking "Edit" on task #3 only swaps that one list item.

## Pattern Card

### GOOD: Frame Swap with Autofocus and Blur-Submit

```erb
<%# Display state %>
<%= turbo_frame_tag dom_id(task) do %>
  <span><%= task.title %></span>
  <%= link_to "Edit", edit_task_path(task) %>
<% end %>

<%# Edit state (same frame ID) %>
<%= turbo_frame_tag dom_id(task) do %>
  <%= form_with model: task,
        data: { controller: "submit-on-blur" } do |f| %>
    <%= f.text_field :title,
          autofocus: true,
          data: { action: "blur->submit-on-blur#submit" } %>
    <%= f.submit "Save", data: { turbo_submits_with: "Saving..." } %>
    <%= link_to "Cancel", task_path(task) %>
  <% end %>
<% end %>
```

```ruby
def update
  if @task.update(task_params)
    redirect_to @task, status: :see_other
  else
    render :edit, status: :unprocessable_entity
  end
end
```

This approach uses frame-scoped swaps for seamless inline editing, autofocus for immediate input readiness, blur-to-submit for a fluid experience, proper 422/303 status codes for Turbo compatibility, and a cancel link that restores display state without JavaScript.

### BAD: Inline Edit Without Focus Management or Proper Status Codes

```erb
<%# No frame wrapping -- replaces entire page %>
<%= form_with model: task do |f| %>
  <%= f.text_field :title %>
  <%= f.submit "Save" %>
<% end %>
```

```ruby
def update
  @task.update(task_params)
  if @task.valid?
    redirect_to tasks_path
  else
    # Missing status: :unprocessable_entity -- Turbo will not re-render the form
    render :edit
  end
end
```

Without Turbo Frames, the entire page reloads for each edit. Without autofocus, the user must click into the field manually. Without `status: :unprocessable_entity`, validation errors silently fail in Turbo. Without a cancel mechanism, the user is stuck in edit mode.
