---
title: "External Form Controls with Turbo Frames"
---

# External Form Controls with Turbo Frames

## Table of Contents

- [Overview](#overview)
- [Two Patterns for External Form Controls](#two-patterns-for-external-form-controls)
- [Implementation](#implementation)
  - [Pattern 1: External Submit Button (form attribute)](#pattern-1-external-submit-button-form-attribute)
  - [Pattern 2: Form Targeting a Different Frame (data-turbo-frame)](#pattern-2-form-targeting-a-different-frame-data-turbo-frame)
  - [Combining Both Patterns](#combining-both-patterns)
  - [External Reset and Cancel Buttons](#external-reset-and-cancel-buttons)
- [Split Layout: Sidebar Form, Main Content Results](#split-layout-sidebar-form-main-content-results)
- [Toolbar Actions Targeting a Content Frame](#toolbar-actions-targeting-a-content-frame)
- [Pattern Card](#pattern-card)

## Overview

Sometimes a form's submit button, or the form itself, cannot live in the same DOM location as the content it updates. Common scenarios include:

- A toolbar with a "Save" button that submits a form in the main content area
- A sidebar filter form that updates a results frame in the main content
- A sticky footer with action buttons for a form rendered in a scrollable area
- Split-pane layouts where controls and content are in separate containers

HTML provides the `form` attribute to associate any button with a form by ID, regardless of DOM position. Turbo provides `data-turbo-frame` to direct a form's response into a specific frame. Together, these solve every external form control scenario without JavaScript.

## Two Patterns for External Form Controls

| Scenario | Solution | Mechanism |
|----------|----------|-----------|
| Button outside the form needs to submit it | `form` attribute on the button | Native HTML |
| Form's response should render in a different frame | `data-turbo-frame` on the form | Turbo |

## Implementation

### Pattern 1: External Submit Button (form attribute)

The HTML `form` attribute associates a `<button>` or `<input>` with a `<form>` by the form's `id`. The button does not need to be a descendant of the form.

```erb
<%# The form in the main content area %>
<%= form_with model: @task, id: "task_form" do |f| %>
  <div class="space-y-4">
    <%= f.label :title %>
    <%= f.text_field :title, class: "w-full rounded-md border-gray-300" %>

    <%= f.label :description %>
    <%= f.text_area :description, rows: 5, class: "w-full rounded-md border-gray-300" %>
  </div>
  <%# No submit button here -- it lives in the toolbar %>
<% end %>

<%# Sticky toolbar at the bottom of the page %>
<div class="fixed bottom-0 inset-x-0 bg-white border-t border-gray-200 p-4 flex justify-end gap-3">
  <%= link_to "Cancel", tasks_path, class: "px-4 py-2 text-gray-700" %>
  <button type="submit"
          form="task_form"
          class="px-4 py-2 bg-blue-600 text-white rounded-md"
          data-turbo-submits-with="Saving...">
    Save Task
  </button>
</div>
```

The `form="task_form"` attribute connects the external button to the form. When clicked, it submits the form exactly as if the button were inside it. Turbo intercepts the submission normally.

### Pattern 2: Form Targeting a Different Frame (data-turbo-frame)

When a form should render its response into a Turbo Frame that the form is not inside of, use `data-turbo-frame` on the form element.

```erb
<%# Sidebar: filter form lives here %>
<aside class="w-64 border-r border-gray-200 p-4">
  <%= form_with url: tasks_path,
        method: :get,
        data: { turbo_frame: "tasks_content" } do |f| %>
    <h3 class="font-semibold mb-3">Filters</h3>

    <div class="space-y-3">
      <%= f.label :status, class: "block text-sm font-medium" %>
      <%= f.select :status,
            options_for_select(["All", "Open", "Closed"], params[:status]),
            {},
            { class: "w-full rounded-md border-gray-300" } %>

      <%= f.label :priority, class: "block text-sm font-medium" %>
      <%= f.select :priority,
            options_for_select(["All", "High", "Medium", "Low"], params[:priority]),
            {},
            { class: "w-full rounded-md border-gray-300" } %>

      <%= f.submit "Apply Filters",
            class: "w-full px-4 py-2 bg-blue-600 text-white rounded-md text-sm" %>
    </div>
  <% end %>
</aside>

<%# Main content: results frame lives here %>
<main class="flex-1 p-6">
  <%= turbo_frame_tag "tasks_content" do %>
    <%= render @tasks %>
  <% end %>
</main>
```

The form is in the sidebar, but `data-turbo-frame="tasks_content"` directs Turbo to render the response into the main content frame. The sidebar form itself is not replaced.

### Combining Both Patterns

You can combine an external submit button with frame targeting for complex layouts:

```erb
<%# Form in the main content area, targeting a results frame %>
<%= form_with model: @report,
      id: "report_form",
      data: { turbo_frame: "report_results" } do |f| %>
  <%= f.label :start_date %>
  <%= f.date_field :start_date %>

  <%= f.label :end_date %>
  <%= f.date_field :end_date %>
<% end %>

<%# Results frame (below the form) %>
<%= turbo_frame_tag "report_results" do %>
  <% if @results %>
    <%= render partial: "report_row", collection: @results %>
  <% else %>
    <p class="text-gray-500">Configure dates above and click Generate.</p>
  <% end %>
<% end %>

<%# External submit button in a fixed header %>
<header class="sticky top-0 bg-white border-b p-4 flex justify-between">
  <h1>Report Builder</h1>
  <button type="submit"
          form="report_form"
          class="px-4 py-2 bg-green-600 text-white rounded-md"
          data-turbo-submits-with="Generating...">
    Generate Report
  </button>
</header>
```

### External Reset and Cancel Buttons

The `form` attribute also works with `type="reset"` buttons:

```erb
<button type="reset"
        form="task_form"
        class="px-4 py-2 text-gray-600">
  Reset
</button>
```

For a cancel action that navigates away, use a regular link rather than a form button:

```erb
<%= link_to "Cancel", tasks_path,
      class: "px-4 py-2 text-gray-600",
      data: { turbo_frame: "_top" } %>
```

## Split Layout: Sidebar Form, Main Content Results

A complete split-layout example where the sidebar contains controls and the main area shows results:

```erb
<%# app/views/tasks/index.html.erb %>
<div class="flex h-screen">
  <%# Sidebar with filter form %>
  <aside class="w-72 border-r overflow-y-auto p-4">
    <%= form_with url: tasks_path,
          method: :get,
          data: {
            turbo_frame: "tasks_list",
            controller: "auto-submit"
          } do |f| %>
      <%= f.search_field :q,
            value: params[:q],
            placeholder: "Search...",
            data: { action: "input->auto-submit#submit" },
            class: "w-full rounded-md border-gray-300 mb-4" %>

      <%= f.select :status,
            options_for_select(Task.statuses.keys, params[:status]),
            { include_blank: "All Statuses" },
            { data: { action: "change->auto-submit#submit" },
              class: "w-full rounded-md border-gray-300" } %>
    <% end %>
  </aside>

  <%# Main content with results frame %>
  <main class="flex-1 overflow-y-auto p-6">
    <%= turbo_frame_tag "tasks_list" do %>
      <%= render partial: "task", collection: @tasks %>
    <% end %>
  </main>
</div>
```

## Toolbar Actions Targeting a Content Frame

For toolbars with multiple actions that all operate on a content frame:

```erb
<%# Toolbar %>
<div class="border-b border-gray-200 p-3 flex gap-2">
  <%# Each button submits the bulk action form with different actions %>
  <button type="submit"
          form="bulk_actions_form"
          name="bulk_action"
          value="archive"
          class="px-3 py-1 text-sm bg-yellow-100 text-yellow-800 rounded">
    Archive Selected
  </button>
  <button type="submit"
          form="bulk_actions_form"
          name="bulk_action"
          value="delete"
          class="px-3 py-1 text-sm bg-red-100 text-red-800 rounded"
          data-turbo-confirm="Delete selected tasks?">
    Delete Selected
  </button>
</div>

<%# The form wraps the list with checkboxes %>
<%= form_with url: bulk_tasks_path,
      method: :post,
      id: "bulk_actions_form",
      data: { turbo_frame: "tasks_list" } do |f| %>
  <%= turbo_frame_tag "tasks_list" do %>
    <% @tasks.each do |task| %>
      <div class="flex items-center gap-3 py-2">
        <%= check_box_tag "task_ids[]", task.id, false, class: "rounded" %>
        <span><%= task.title %></span>
      </div>
    <% end %>
  <% end %>
<% end %>
```

## Pattern Card

### GOOD: External Submit with Frame Targeting

```erb
<%# Form with explicit ID %>
<%= form_with model: @task, id: "task_form" do |f| %>
  <%= f.text_field :title %>
  <%= f.text_area :description %>
<% end %>

<%# External button using form attribute %>
<div class="sticky bottom-0 bg-white border-t p-4">
  <button type="submit"
          form="task_form"
          data-turbo-submits-with="Saving...">
    Save
  </button>
</div>

<%# Sidebar form targeting content frame %>
<%= form_with url: tasks_path,
      method: :get,
      data: { turbo_frame: "results" } do |f| %>
  <%= f.search_field :q %>
  <%= f.submit "Search" %>
<% end %>

<%= turbo_frame_tag "results" do %>
  <%= render @tasks %>
<% end %>
```

This approach uses the native HTML `form` attribute for external buttons (no JavaScript), `data-turbo-frame` for cross-frame form targeting, proper separation of controls and content in split layouts, and works with Turbo's loading states and submit button management.

### BAD: JavaScript Form Submission

```javascript
// Manual form submission from external button
document.querySelector("#external-save-btn").addEventListener("click", () => {
  const form = document.querySelector("#task-form")
  const formData = new FormData(form)

  fetch(form.action, {
    method: form.method,
    body: formData,
    headers: {
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
    }
  }).then(response => {
    if (response.ok) {
      document.querySelector("#results").innerHTML = response.text()
    }
  })
})
```

This approach bypasses Turbo entirely, requires manual CSRF token handling, uses `innerHTML` which breaks Turbo's DOM management, provides no loading states or submit button management, and reimplements what HTML's `form` attribute provides natively.
