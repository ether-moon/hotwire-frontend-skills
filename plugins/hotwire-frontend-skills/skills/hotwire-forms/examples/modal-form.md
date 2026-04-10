---
title: "Modal New Record Form"
---

# Modal New Record Form

A "New Task" button opens a modal dialog containing a form. Validation errors re-render inside the modal. On success, the modal closes and the new record appends to the list via Turbo Stream -- no full page reload.

## Controller

`new` renders the form inside the modal's Turbo Frame. `create` either appends via Turbo Stream (success) or re-renders the form with errors (422):

```ruby
class TasksController < ApplicationController
  before_action :set_project

  def new
    @task = @project.tasks.build
  end

  def create
    @task = @project.tasks.build(task_params)
    if @task.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @project, status: :see_other }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :priority)
  end
end
```

## Modal Trigger and Dialog Shell

The trigger link targets the `"modal"` frame. The `<dialog>` element contains that frame and opens when content loads:

```erb
<%# In the parent page (e.g., projects/show.html.erb) %>
<%= link_to "New Task",
      new_project_task_path(@project),
      data: { turbo_frame: "modal" } %>

<div id="tasks_list">
  <%= render @project.tasks %>
</div>

<dialog data-controller="modal"
        data-modal-target="dialog"
        data-action="close->modal#cleanup click->modal#clickOutside">
  <%= turbo_frame_tag "modal",
        data: { action: "turbo:frame-load->modal#open" } do %>
  <% end %>
</dialog>
```

Key detail: `turbo:frame-load->modal#open` opens the dialog automatically when the frame loads content. The empty frame block means the dialog starts hidden with no content.

## Form Inside the Modal Frame

The form wraps in `turbo_frame_tag "modal"` to match the target:

```erb
<%# app/views/tasks/new.html.erb %>
<%= turbo_frame_tag "modal" do %>
  <div class="p-6">
    <h2>New Task</h2>
    <button type="button" data-action="modal#close">&times;</button>

    <% if @task.errors.any? %>
      <ul>
        <% @task.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    <% end %>

    <%= form_with model: [@project, @task] do |f| %>
      <%= f.label :title %>
      <%= f.text_field :title, autofocus: true %>

      <%= f.label :description %>
      <%= f.text_area :description, rows: 3 %>

      <%= f.label :priority %>
      <%= f.select :priority, %w[low medium high] %>

      <button type="button" data-action="modal#close">Cancel</button>
      <%= f.submit "Create Task",
            data: { turbo_submits_with: "Creating..." } %>
    <% end %>
  </div>
<% end %>
```

## Turbo Stream Response (Success Path)

On successful create, two stream actions: append the new task to the list and clear the modal frame to trigger close:

```erb
<%# app/views/tasks/create.turbo_stream.erb %>
<%= turbo_stream.append "tasks_list", partial: "tasks/task", locals: { task: @task } %>
<%= turbo_stream.update "modal", "" %>
```

Clearing the modal frame content triggers the dialog's `close` event via the Stimulus controller.

## Modal Stimulus Controller

Uses the native `<dialog>` API. `cleanup` clears the frame so the next modal open starts fresh:

```javascript
// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  cleanup() {
    const frame = this.dialogTarget.querySelector("turbo-frame")
    if (frame) {
      frame.innerHTML = ""
      frame.removeAttribute("src")
    }
  }

  clickOutside(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }
}
```

## Why This Works

- **Frame-based modal loading**: The `"modal"` Turbo Frame inside the `<dialog>` loads form content lazily. The trigger link's `data-turbo-frame="modal"` targets this frame without JavaScript.
- **Native `<dialog>`**: `showModal()` handles backdrop, focus trapping, and Escape-to-close for free. No custom overlay logic needed.
- **Validation stays in the modal**: Returning 422 re-renders `new.html.erb` inside the same frame. The modal stays open because only the frame content updates.
- **Turbo Stream for success**: `turbo_stream.append` adds the task to the list, and `turbo_stream.update "modal", ""` clears the frame. The `cleanup` callback on the dialog's `close` event removes stale content.
- **HTML fallback**: `format.html { redirect_to @project }` works if JavaScript is disabled or the request is not a Turbo Stream request.
- **Reusable dialog shell**: The `<dialog>` + `"modal"` frame pattern can be placed in the layout and shared across any page that needs a modal form.
