---
title: "Modal Forms with Validation"
---

# Modal Forms with Validation

## Table of Contents

- [Overview](#overview)
- [Architecture: Dialog + Turbo Frame + Stimulus](#architecture-dialog--turbo-frame--stimulus)
- [Implementation](#implementation)
  - [The Modal Trigger Link](#the-modal-trigger-link)
  - [The Modal Frame and Dialog](#the-modal-frame-and-dialog)
  - [The Form Inside the Modal](#the-form-inside-the-modal)
  - [The Dialog Stimulus Controller](#the-dialog-stimulus-controller)
  - [Controller: Handling 422 and 303](#controller-handling-422-and-303)
  - [Closing the Modal on Success](#closing-the-modal-on-success)
- [Appending the New Record to a List](#appending-the-new-record-to-a-list)
- [Nested Modal Validation Errors](#nested-modal-validation-errors)
- [Pattern Card](#pattern-card)

## Overview

Modal forms are one of the most common interactive patterns in web applications. A user clicks "New Task," a dialog appears with a form, they fill it out, and either see validation errors re-rendered inside the modal or the modal closes on success and the page updates.

With Hotwire, this pattern uses three cooperating pieces:

1. **Native HTML `<dialog>` element** -- provides accessibility, backdrop, focus trapping, and Escape-to-close for free.
2. **Turbo Frame** -- scopes the form loading and response rendering to the modal content area.
3. **Stimulus controller** -- opens/closes the dialog and handles the lifecycle.

No custom overlay divs, no z-index battles, no manual focus trapping.

## Architecture: Dialog + Turbo Frame + Stimulus

```
Page with trigger link          Modal dialog
+---------------------------+   +---------------------------+
| [+ New Task]              |   | <dialog>                  |
|                           |   |   turbo_frame "modal" do  |
| turbo_frame "modal" (empty)|->|     form_with @task       |
|                           |   |       title: [________]   |
+---------------------------+   |       [Save] [Cancel]     |
                                |   end                     |
       click "+ New Task"       | </dialog>                 |
       GET /tasks/new           +---------------------------+
       -> fills frame                    |
       -> opens dialog            submit form
                                  PATCH /tasks
                                         |
                              +---------+---------+
                              |                   |
                          422 (errors)      303 (success)
                          re-render form    close modal
                          inside dialog     update page
```

## Implementation

### The Modal Trigger Link

The link targets the modal's Turbo Frame. When clicked, Turbo fetches the `new` action and extracts the matching frame from the response.

```erb
<%# app/views/tasks/index.html.erb %>
<%= link_to "New Task",
      new_task_path,
      data: { turbo_frame: "modal" },
      class: "btn btn-primary" %>
```

### The Modal Frame and Dialog

Place an empty Turbo Frame and dialog in your layout or the page that hosts the modal. The Stimulus controller manages the dialog lifecycle.

```erb
<%# app/views/layouts/application.html.erb (or a shared partial) %>
<dialog data-controller="modal"
        data-modal-target="dialog"
        data-action="close->modal#disconnect"
        class="backdrop:bg-black/50 rounded-lg shadow-xl p-0 max-w-lg w-full">
  <%= turbo_frame_tag "modal",
        target: "_top",
        data: { action: "turbo:frame-load->modal#open" } do %>
  <% end %>
</dialog>
```

Key details:
- `turbo_frame_tag "modal"` is the target frame the trigger link loads into.
- `data-action="turbo:frame-load->modal#open"` opens the dialog when frame content arrives.
- `target: "_top"` ensures links inside the modal (like cancel) that break out of the frame navigate the full page.
- The `close` event on `<dialog>` fires when the user presses Escape or clicks the backdrop.

### The Form Inside the Modal

The `new` action renders the form inside a matching `turbo_frame_tag "modal"`:

```erb
<%# app/views/tasks/new.html.erb %>
<%= turbo_frame_tag "modal" do %>
  <div class="p-6">
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-semibold">New Task</h2>
      <button data-action="modal#close" class="text-gray-400 hover:text-gray-600">
        &times;
      </button>
    </div>

    <%= form_with model: @task do |f| %>
      <div class="space-y-4">
        <div>
          <%= f.label :title, class: "block text-sm font-medium text-gray-700" %>
          <%= f.text_field :title,
                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500",
                autofocus: true %>
          <% if @task.errors[:title].any? %>
            <p class="mt-1 text-sm text-red-600"><%= @task.errors[:title].first %></p>
          <% end %>
        </div>

        <div>
          <%= f.label :description, class: "block text-sm font-medium text-gray-700" %>
          <%= f.text_area :description,
                rows: 3,
                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500" %>
        </div>
      </div>

      <div class="mt-6 flex justify-end gap-3">
        <button type="button"
                data-action="modal#close"
                class="px-4 py-2 text-sm text-gray-700 hover:text-gray-900">
          Cancel
        </button>
        <%= f.submit "Create Task",
              class: "px-4 py-2 bg-blue-600 text-white rounded-md text-sm hover:bg-blue-700",
              data: { turbo_submits_with: "Creating..." } %>
      </div>
    <% end %>
  </div>
<% end %>
```

### The Dialog Stimulus Controller

This controller manages the `<dialog>` element lifecycle: opening, closing, and cleanup.

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

  // Called when the dialog's close event fires (Escape key or backdrop click)
  disconnect() {
    // Clear the turbo frame content so the next modal open starts fresh
    const frame = this.dialogTarget.querySelector("turbo-frame")
    if (frame) {
      frame.innerHTML = ""
      frame.removeAttribute("src")
    }
  }

  // Close on backdrop click (click outside the dialog content)
  clickOutside(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }
}
```

Add backdrop click handling:

```erb
<dialog data-controller="modal"
        data-modal-target="dialog"
        data-action="close->modal#disconnect click->modal#clickOutside">
```

### Controller: Handling 422 and 303

The controller must return the correct status codes for Turbo to handle the response properly.

```ruby
# app/controllers/tasks_controller.rb
class TasksController < ApplicationController
  def new
    @task = Task.new
  end

  def create
    @task = @project.tasks.build(task_params)
    if @task.save
      redirect_to project_tasks_path(@project), status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def task_params
      params.require(:task).permit(:title, :description)
    end
end
```

- **422 (`:unprocessable_entity`)**: Turbo re-renders the response inside the `"modal"` frame. The dialog stays open and shows validation errors.
- **303 (`:see_other`)**: Turbo follows the redirect. Since the redirect response is a full page (not scoped to the frame), Turbo navigates the full page, effectively closing the modal.

### Closing the Modal on Success

When the controller redirects with `303`, Turbo follows the redirect and performs a full page navigation (because the redirect response will not contain a matching `"modal"` frame with content). The dialog naturally disappears because the page re-renders.

For a smoother experience where the page does not fully reload, use a Turbo Stream response instead:

```ruby
def create
  @task = @project.tasks.build(task_params)
  if @task.save
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_tasks_path(@project), status: :see_other }
    end
  else
    render :new, status: :unprocessable_entity
  end
end
```

```erb
<%# app/views/tasks/create.turbo_stream.erb %>
<%= turbo_stream.append "tasks_list", partial: "tasks/task", locals: { task: @task } %>
<%= turbo_stream.update "modal", "" %>
```

The second stream action clears the modal frame, and the Stimulus controller detects the empty frame and closes the dialog.

## Appending the New Record to a List

When using the Turbo Stream approach above, the new task appears at the bottom of the list without a page reload. Ensure the list has a matching ID:

```erb
<%# app/views/tasks/index.html.erb %>
<div id="tasks_list">
  <%= render @tasks %>
</div>
```

## Nested Modal Validation Errors

When a modal form has nested attributes or complex validation, the 422 response re-renders the entire form inside the modal frame. All error messages and field states are preserved because Turbo replaces the full frame content.

```erb
<%# Errors render naturally inside the re-rendered form %>
<% if @task.errors.any? %>
  <div class="rounded-md bg-red-50 p-4 mb-4">
    <ul class="list-disc list-inside text-sm text-red-700">
      <% @task.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

## Pattern Card

### GOOD: Modal Frame with Native Dialog and Proper Status Codes

```erb
<%# Trigger %>
<%= link_to "New Task", new_task_path, data: { turbo_frame: "modal" } %>

<%# Dialog in layout %>
<dialog data-controller="modal" data-modal-target="dialog"
        data-action="close->modal#disconnect click->modal#clickOutside">
  <%= turbo_frame_tag "modal",
        data: { action: "turbo:frame-load->modal#open" } do %>
  <% end %>
</dialog>

<%# Form response (new.html.erb) %>
<%= turbo_frame_tag "modal" do %>
  <%= form_with model: @task do |f| %>
    <%= f.text_field :title, autofocus: true %>
    <%= f.submit "Create", data: { turbo_submits_with: "Creating..." } %>
  <% end %>
<% end %>
```

```ruby
# 422 re-renders form in modal, 303 closes modal via redirect
def create
  @task = Task.new(task_params)
  if @task.save
    redirect_to tasks_path, status: :see_other
  else
    render :new, status: :unprocessable_entity
  end
end
```

This approach uses the native `<dialog>` for accessibility (focus trapping, Escape key, backdrop), Turbo Frames for scoped form rendering, proper 422/303 status codes for error re-rendering and success navigation, and minimal Stimulus only for dialog lifecycle management.

### BAD: Modal with Custom AJAX Handling

```erb
<%# Custom overlay div instead of dialog %>
<div id="modal-overlay" class="hidden fixed inset-0 z-50 bg-black/50">
  <div id="modal-content" class="bg-white rounded-lg p-6">
    <%# Content injected via JavaScript %>
  </div>
</div>
```

```javascript
// Custom fetch, manual DOM manipulation, no Turbo integration
document.querySelector("#new-task-btn").addEventListener("click", async () => {
  const response = await fetch("/tasks/new")
  const html = await response.text()
  document.querySelector("#modal-content").innerHTML = html
  document.querySelector("#modal-overlay").classList.remove("hidden")

  document.querySelector("#modal-content form").addEventListener("submit", async (e) => {
    e.preventDefault()
    const formData = new FormData(e.target)
    const response = await fetch("/tasks", { method: "POST", body: formData })
    if (response.ok) {
      document.querySelector("#modal-overlay").classList.add("hidden")
      window.location.reload()
    } else {
      const html = await response.text()
      document.querySelector("#modal-content").innerHTML = html
    }
  })
})
```

This approach bypasses Turbo entirely, requires manual CSRF token handling, has no focus trapping or accessibility, requires custom z-index and overlay management, and uses `window.location.reload()` which defeats the purpose of Turbo.
