---
title: "Turbo Frames Tabbed Navigation"
---

# Turbo Frames Tabbed Navigation

## Table of Contents

- [Overview](#overview)
- [Implementation](#implementation)
  - [Basic Tabbed Navigation](#basic-tabbed-navigation)
  - [Controller and Routes](#controller-and-routes)
  - [Tab Content Views](#tab-content-views)
  - [Active Tab Styling with Stimulus](#active-tab-styling-with-stimulus)
  - [Preserving Tab State on Back Navigation](#preserving-tab-state-on-back-navigation)
- [Pattern Card](#pattern-card)

## Overview

Tabbed navigation is one of the most natural fits for Turbo Frames. Each tab click loads new content into a shared frame region without replacing the entire page. The tab bar stays in place, the URL can optionally update, and the experience feels instant.

The key insight is that tab links live **outside** the frame they target. The links use `data-turbo-frame` to point at the content frame. When clicked, Turbo fetches the new URL and extracts the matching frame from the response, replacing only the content area.

This approach has several advantages over JavaScript-based tab switching:
- Each tab has a real URL and can be bookmarked or shared.
- The server renders the tab content, so there is no client-side state management.
- Content loads on demand rather than eagerly loading all tabs.
- The pattern degrades gracefully to full-page navigation without JavaScript.

## Implementation

### Basic Tabbed Navigation

```erb
<%# app/views/projects/show.html.erb %>
<h1><%= @project.name %></h1>

<nav class="tabs" data-controller="tabs" data-tabs-active-class="tab--active">
  <%= link_to "Overview",
    project_path(@project, tab: "overview"),
    class: "tab",
    data: {
      turbo_frame: dom_id(@project, :tab_content),
      tabs_target: "tab",
      action: "tabs#activate"
    } %>

  <%= link_to "Tasks",
    project_tasks_path(@project),
    class: "tab",
    data: {
      turbo_frame: dom_id(@project, :tab_content),
      tabs_target: "tab",
      action: "tabs#activate"
    } %>

  <%= link_to "Files",
    project_files_path(@project),
    class: "tab",
    data: {
      turbo_frame: dom_id(@project, :tab_content),
      tabs_target: "tab",
      action: "tabs#activate"
    } %>

  <%= link_to "Settings",
    edit_project_path(@project),
    class: "tab",
    data: {
      turbo_frame: dom_id(@project, :tab_content),
      tabs_target: "tab",
      action: "tabs#activate"
    } %>
</nav>

<%= turbo_frame_tag dom_id(@project, :tab_content) do %>
  <%# Default tab content renders here %>
  <%= render "projects/overview", project: @project %>
<% end %>
```

### Controller and Routes

Each tab corresponds to a controller action that responds with a view containing a matching `turbo_frame_tag`. For Turbo Frame requests, only the frame content matters. For full-page requests (no JS, direct URL visit), the complete page renders.

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :projects do
    resources :tasks, only: [:index]
    resources :files, only: [:index]
  end
end
```

```ruby
# app/controllers/projects_controller.rb
class ProjectsController < ApplicationController
  def show
    @project = Project.find(params[:id])
  end

  def edit
    @project = Project.find(params[:id])
  end
end
```

```ruby
# app/controllers/tasks_controller.rb
class TasksController < ApplicationController
  def index
    @project = Project.find(params[:project_id])
    @tasks = @project.tasks.order(created_at: :desc)
  end
end
```

### Tab Content Views

Each tab view wraps its content in the same `turbo_frame_tag` with the matching ID. When Turbo fetches the page, it extracts just the frame content.

```erb
<%# app/views/tasks/index.html.erb %>
<%= turbo_frame_tag dom_id(@project, :tab_content) do %>
  <div class="tasks-list">
    <% @tasks.each do |task| %>
      <div class="task-item" id="<%= dom_id(task) %>">
        <h3><%= link_to task.title, project_task_path(@project, task), data: { turbo_frame: "_top" } %></h3>
        <p><%= task.status %></p>
      </div>
    <% end %>

    <% if @tasks.empty? %>
      <p class="empty-state">No tasks yet.</p>
    <% end %>
  </div>
<% end %>
```

```erb
<%# app/views/files/index.html.erb %>
<%= turbo_frame_tag dom_id(@project, :tab_content) do %>
  <div class="files-grid">
    <% @files.each do |file| %>
      <div class="file-card" id="<%= dom_id(file) %>">
        <span class="file-icon"><%= file.icon %></span>
        <span class="file-name"><%= file.name %></span>
      </div>
    <% end %>

    <% if @files.empty? %>
      <p class="empty-state">No files uploaded.</p>
    <% end %>
  </div>
<% end %>
```

Note the `data: { turbo_frame: "_top" }` on links within tab content that should navigate to a full page (like viewing a single task). Without this, Turbo would try to load the task show page inside the tab content frame.

### Active Tab Styling with Stimulus

Use a lightweight Stimulus controller to manage the active tab class. This keeps the tab highlighting logic on the client without requiring the server to track which tab is active.

```javascript
// app/javascript/controllers/tabs_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab"]
  static classes = ["active"]

  activate(event) {
    this.tabTargets.forEach(tab => {
      tab.classList.remove(...this.activeClasses)
    })
    event.currentTarget.classList.add(...this.activeClasses)
  }

  // Set initial active tab based on current URL
  connect() {
    const currentPath = window.location.pathname
    this.tabTargets.forEach(tab => {
      if (tab.getAttribute("href") === currentPath) {
        tab.classList.add(...this.activeClasses)
      }
    })
  }
}
```

```css
/* app/assets/stylesheets/components/tabs.css */
.tabs {
  display: flex;
  gap: 0;
  border-bottom: 1px solid #e5e7eb;
  margin-bottom: 1.5rem;
}

.tab {
  padding: 0.75rem 1.25rem;
  color: #6b7280;
  text-decoration: none;
  border-bottom: 2px solid transparent;
  transition: color 0.15s, border-color 0.15s;
}

.tab:hover {
  color: #374151;
}

.tab--active {
  color: #1d4ed8;
  border-bottom-color: #1d4ed8;
}

/* Show loading state while frame is fetching */
turbo-frame[aria-busy="true"] {
  opacity: 0.6;
  pointer-events: none;
}
```

### Preserving Tab State on Back Navigation

When the user navigates away from the tabbed page and comes back, Turbo Drive restores the cached snapshot, which includes the last active tab content. However, the active tab class might not match if it was set via Stimulus.

Two strategies to handle this:

**Strategy 1: URL-based tab state (recommended)**

Include the tab identifier in the URL so the server renders the correct active state.

```erb
<%# app/views/projects/show.html.erb %>
<nav class="tabs">
  <% %w[overview tasks files settings].each do |tab_name| %>
    <%= link_to tab_name.titleize,
      project_path(@project, tab: tab_name),
      class: "tab #{tab_name == @active_tab ? 'tab--active' : ''}",
      data: { turbo_frame: dom_id(@project, :tab_content) } %>
  <% end %>
</nav>
```

```ruby
# app/controllers/projects_controller.rb
def show
  @project = Project.find(params[:id])
  @active_tab = params[:tab] || "overview"
end
```

**Strategy 2: Turbo permanent elements**

Mark the tab bar as permanent so Turbo preserves it during Drive navigations.

```erb
<nav class="tabs" id="project-tabs" data-turbo-permanent>
  <%# Tab links here %>
</nav>
```

This prevents Turbo from replacing the tab bar on cache restore, keeping the active class intact. Use this sparingly -- permanent elements are not updated on navigation, which can lead to stale content.

## Pattern Card

### GOOD: Frame-Based Tabs with Proper IDs and Graceful Degradation

```erb
<%# Tab links target the content frame %>
<nav class="tabs" data-controller="tabs" data-tabs-active-class="tab--active">
  <%= link_to "Details", project_path(@project, tab: "details"),
    class: "tab tab--active",
    data: { turbo_frame: dom_id(@project, :tab_content), tabs_target: "tab", action: "tabs#activate" } %>
  <%= link_to "Activity", project_activity_index_path(@project),
    class: "tab",
    data: { turbo_frame: dom_id(@project, :tab_content), tabs_target: "tab", action: "tabs#activate" } %>
</nav>

<%# Content frame with default content %>
<%= turbo_frame_tag dom_id(@project, :tab_content) do %>
  <%= render "projects/details", project: @project %>
<% end %>
```

Each tab is a real URL. The server renders the frame content. Without JavaScript, tabs work as full-page links. The frame ID uses `dom_id` for uniqueness.

### BAD: JavaScript Tab Switching with Hidden Panels

```erb
<%# All tab content is eagerly loaded and hidden with CSS %>
<nav class="tabs">
  <button onclick="showTab('details')">Details</button>
  <button onclick="showTab('activity')">Activity</button>
</nav>

<div id="details-panel">
  <%= render "projects/details", project: @project %>
</div>

<div id="activity-panel" style="display: none;">
  <%= render "projects/activity", project: @project %>
</div>

<script>
  function showTab(name) {
    document.querySelectorAll('[id$="-panel"]').forEach(p => p.style.display = 'none');
    document.getElementById(name + '-panel').style.display = 'block';
  }
</script>
```

This approach eagerly loads all tab content on initial page load, increasing page weight and database queries. Tabs have no URLs so they cannot be bookmarked or shared. The pattern requires custom JavaScript and breaks entirely without it. It also bypasses Turbo entirely, defeating the purpose of the framework.
