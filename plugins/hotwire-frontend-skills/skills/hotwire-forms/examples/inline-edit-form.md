---
title: "Inline Editable Table Row"
---

# Inline Editable Table Row

A task list table where each row can be clicked to edit inline. The edit form replaces the row via a Turbo Frame swap. Blur-to-save and Escape-to-cancel provide a fluid editing experience.

## Controller

Only `show`, `edit`, and `update` matter for inline edit. `show` renders the display partial back into the frame after save; `edit` renders the form partial.

```ruby
class TasksController < ApplicationController
  before_action :set_task, only: %i[show edit update]

  def edit
    # Renders the edit form inside the Turbo Frame
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
    params.require(:task).permit(:title, :due_date, :priority)
  end
end
```

## Display Partial (Read State)

The `turbo_frame_tag` wraps the `<tr>` so only this row swaps when editing:

```erb
<%# app/views/tasks/_task.html.erb %>
<%= turbo_frame_tag dom_id(task), tag: "tr" do %>
  <td><%= task.title %></td>
  <td><%= task.due_date.strftime("%b %d, %Y") %></td>
  <td><%= task.priority %></td>
  <td>
    <%= link_to "Edit", edit_task_path(task) %>
  </td>
<% end %>
```

Key detail: `tag: "tr"` makes the Turbo Frame render as a table row instead of a `<turbo-frame>` element, which would break table layout.

## Edit View (Write State)

The edit form uses `class: "contents"` so the `<form>` element does not break the table row structure:

```erb
<%# app/views/tasks/edit.html.erb %>
<%= turbo_frame_tag dom_id(@task), tag: "tr" do %>
  <%= form_with model: @task,
        class: "contents",
        data: { controller: "inline-edit" } do |f| %>
    <td>
      <%= f.text_field :title,
            autofocus: true,
            data: { action: "blur->inline-edit#save keydown.escape->inline-edit#cancel" } %>
      <% if @task.errors[:title].any? %>
        <p class="text-xs text-red-600"><%= @task.errors[:title].first %></p>
      <% end %>
    </td>
    <td>
      <%= f.date_field :due_date,
            data: { action: "change->inline-edit#save" } %>
    </td>
    <td>
      <%= f.select :priority, %w[low medium high], {},
            data: { action: "change->inline-edit#save" } %>
    </td>
    <td>
      <%= link_to "Cancel", task_path(@task) %>
    </td>
  <% end %>
<% end %>
```

## Stimulus Controller

Minimal controller -- `save` submits the form, `cancel` clicks the cancel link to navigate back to display state:

```javascript
// app/javascript/controllers/inline_edit_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  save() {
    this.element.requestSubmit()
  }

  cancel(event) {
    event.preventDefault()
    this.element.querySelector("a[href]")?.click()
  }
}
```

## Why This Works

- **Turbo Frame scoping**: Each row is its own frame (`dom_id(task)`), so editing one row does not affect others.
- **`class: "contents"`**: The `<form>` element participates in the table layout without adding an extra box. This avoids the common bug where a `<form>` inside a `<tr>` breaks column alignment.
- **Blur-to-save**: `blur->inline-edit#save` on the text field submits automatically when the user tabs or clicks away. `change->inline-edit#save` on select/date fields submits on value change.
- **Escape-to-cancel**: `keydown.escape->inline-edit#cancel` navigates back to the display partial without saving.
- **422/303 lifecycle**: Failed validation re-renders the edit form (422). Successful update redirects to the show action (303), which renders the display partial back into the frame.
- **`show` renders the partial**: After update, `redirect_to @task` hits the `show` action. The show template just renders the `_task` partial, so the display row reappears inside the frame.
