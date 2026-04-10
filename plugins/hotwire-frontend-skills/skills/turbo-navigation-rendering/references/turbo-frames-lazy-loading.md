---
title: "Turbo Frames Lazy Loading"
---

# Turbo Frames Lazy Loading

## Table of Contents

- [Overview](#overview)
- [Implementation](#implementation)
  - [Basic Lazy Loading](#basic-lazy-loading)
  - [Controller Endpoint for Lazy Content](#controller-endpoint-for-lazy-content)
  - [Placeholder Content and Loading States](#placeholder-content-and-loading-states)
  - [Lifecycle Events](#lifecycle-events)
  - [Eager vs Lazy Loading Decision](#eager-vs-lazy-loading-decision)
- [Pattern Card](#pattern-card)

## Overview

Turbo Frames with the `loading: :lazy` attribute defer fetching their content until the frame scrolls into the viewport. This is a powerful tool for improving initial page load performance by splitting expensive content into separate requests that load on demand.

A lazy-loaded Turbo Frame works as follows:

1. The frame renders on the initial page with its placeholder content (whatever is inside the `turbo_frame_tag` block).
2. When the frame enters the viewport (using IntersectionObserver internally), Turbo fetches the URL specified in the `src` attribute.
3. The response is parsed and the matching frame content replaces the placeholder.
4. The `turbo:frame-load` event fires, signaling the content is ready.

Without the `loading: :lazy` attribute, frames with a `src` attribute load immediately when the page renders (`loading: :eager` is the default). Use lazy loading for content that is below the fold, secondary in importance, or computationally expensive to generate.

## Implementation

### Basic Lazy Loading

```erb
<%# app/views/dashboards/show.html.erb %>
<h1>Dashboard</h1>

<%# This content loads immediately with the page %>
<section class="dashboard-summary">
  <h2>Welcome back, <%= Current.user.first_name %></h2>
  <p>You have <%= @unread_count %> unread notifications.</p>
</section>

<%# These frames load only when scrolled into view %>
<section class="dashboard-widgets">
  <%= turbo_frame_tag "recent_activity",
    src: dashboard_recent_activity_path,
    loading: :lazy do %>
    <div class="widget-placeholder">
      <div class="skeleton-line w-3/4"></div>
      <div class="skeleton-line w-1/2"></div>
      <div class="skeleton-line w-2/3"></div>
    </div>
  <% end %>

  <%= turbo_frame_tag "team_stats",
    src: dashboard_team_stats_path,
    loading: :lazy do %>
    <div class="widget-placeholder">
      <div class="skeleton-block h-48"></div>
    </div>
  <% end %>

  <%= turbo_frame_tag "upcoming_deadlines",
    src: dashboard_upcoming_deadlines_path,
    loading: :lazy do %>
    <div class="widget-placeholder">
      <p class="text-gray-400">Loading deadlines...</p>
    </div>
  <% end %>
</section>
```

### Controller Endpoint for Lazy Content

Each lazy frame's `src` points to a controller action that renders the frame content. The action should be fast and focused -- it only renders what goes inside the frame.

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resource :dashboard, only: [:show] do
    get :recent_activity, on: :member
    get :team_stats, on: :member
    get :upcoming_deadlines, on: :member
  end
end
```

```ruby
# app/controllers/dashboards_controller.rb
class DashboardsController < ApplicationController
  def show
    @unread_count = Current.user.notifications.unread.count
  end

  def recent_activity
    @activities = Current.user.team
      .activities
      .includes(:user, :trackable)
      .order(created_at: :desc)
      .limit(10)
  end

  def team_stats
    @stats = TeamStatsQuery.new(Current.user.team).call
  end

  def upcoming_deadlines
    @deadlines = Current.user.assigned_tasks
      .where(due_date: Date.today..30.days.from_now)
      .order(:due_date)
  end
end
```

```erb
<%# app/views/dashboards/recent_activity.html.erb %>
<%= turbo_frame_tag "recent_activity" do %>
  <div class="widget">
    <h3>Recent Activity</h3>
    <ul class="activity-list">
      <% @activities.each do |activity| %>
        <li class="activity-item">
          <span class="activity-user"><%= activity.user.name %></span>
          <span class="activity-action"><%= activity.description %></span>
          <time class="activity-time"><%= time_ago_in_words(activity.created_at) %> ago</time>
        </li>
      <% end %>
    </ul>
  </div>
<% end %>
```

Note that the view wraps its content in a `turbo_frame_tag` with the same ID as the source frame. Turbo matches frames by ID, so these must correspond exactly.

### Placeholder Content and Loading States

The content inside the `turbo_frame_tag` block is the placeholder. It displays immediately and is replaced when the lazy content loads. Use this to show skeleton screens, spinners, or meaningful loading messages.

**Skeleton screen placeholder:**

```erb
<%= turbo_frame_tag "recent_activity",
  src: dashboard_recent_activity_path,
  loading: :lazy do %>
  <div class="widget">
    <h3>Recent Activity</h3>
    <ul class="activity-list">
      <% 5.times do %>
        <li class="activity-item skeleton">
          <div class="skeleton-circle w-8 h-8"></div>
          <div class="skeleton-lines flex-1">
            <div class="skeleton-line w-2/3"></div>
            <div class="skeleton-line w-1/3"></div>
          </div>
        </li>
      <% end %>
    </ul>
  </div>
<% end %>
```

**CSS for skeleton screens:**

```css
/* app/assets/stylesheets/components/skeleton.css */
.skeleton-line {
  height: 0.75rem;
  background: linear-gradient(90deg, #e5e7eb 25%, #f3f4f6 50%, #e5e7eb 75%);
  background-size: 200% 100%;
  animation: skeleton-shimmer 1.5s infinite;
  border-radius: 0.25rem;
  margin-bottom: 0.5rem;
}

.skeleton-circle {
  border-radius: 50%;
  background: #e5e7eb;
}

.skeleton-block {
  background: linear-gradient(90deg, #e5e7eb 25%, #f3f4f6 50%, #e5e7eb 75%);
  background-size: 200% 100%;
  animation: skeleton-shimmer 1.5s infinite;
  border-radius: 0.5rem;
}

@keyframes skeleton-shimmer {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}

/* Turbo Frame loading state via aria-busy */
turbo-frame[aria-busy="true"] {
  opacity: 0.6;
  transition: opacity 0.2s;
}
```

**Spinner placeholder:**

```erb
<%= turbo_frame_tag "team_stats",
  src: dashboard_team_stats_path,
  loading: :lazy do %>
  <div class="widget widget--loading">
    <div class="spinner" aria-label="Loading team stats"></div>
  </div>
<% end %>
```

### Lifecycle Events

Turbo Frames fire several events during the loading lifecycle that you can use for custom behavior:

| Event | When it fires | Target |
|-------|---------------|--------|
| `turbo:before-fetch-request` | Before the frame sends a fetch request | `<turbo-frame>` |
| `turbo:before-fetch-response` | After fetch completes, before processing | `<turbo-frame>` |
| `turbo:frame-render` | After new content is rendered into the frame | `<turbo-frame>` |
| `turbo:frame-load` | After the frame has fully loaded and rendered | `<turbo-frame>` |
| `turbo:frame-missing` | When the response does not contain the expected frame | `<turbo-frame>` |

```javascript
// app/javascript/controllers/lazy_widget_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("turbo:frame-load", this.onLoad.bind(this))
    this.element.addEventListener("turbo:frame-missing", this.onMissing.bind(this))
  }

  onLoad(event) {
    // Content loaded successfully -- initialize any JS that depends on the content
    this.element.classList.add("widget--loaded")
  }

  onMissing(event) {
    // Frame content was not found in the response
    event.preventDefault()
    this.element.innerHTML = `
      <div class="widget widget--error">
        <p>Could not load this content. <a href="${this.element.src}">Try again</a></p>
      </div>
    `
  }
}
```

```erb
<%= turbo_frame_tag "recent_activity",
  src: dashboard_recent_activity_path,
  loading: :lazy,
  data: { controller: "lazy-widget" } do %>
  <div class="widget-placeholder">Loading...</div>
<% end %>
```

### Eager vs Lazy Loading Decision

Use this decision guide:

| Scenario | Loading Strategy |
|----------|-----------------|
| Content is above the fold | `loading: :eager` (or no `loading` attribute) |
| Content is below the fold | `loading: :lazy` |
| Content is expensive to compute | `loading: :lazy` |
| Content is critical for the page's purpose | `loading: :eager` |
| Content is supplementary (widgets, stats) | `loading: :lazy` |
| Content is in a hidden tab | `loading: :lazy` (via tab navigation pattern) |
| Content is a modal body | No `src` until modal opens, then set dynamically |

## Pattern Card

### GOOD: Lazy Frame with Skeleton Placeholder

```erb
<%# Dashboard loads instantly with primary content %>
<h1>Dashboard</h1>
<section class="primary-content">
  <%= render "projects/summary", projects: @projects %>
</section>

<%# Secondary widgets load lazily when scrolled into view %>
<section class="widgets">
  <%= turbo_frame_tag "recent_activity",
    src: dashboard_recent_activity_path,
    loading: :lazy do %>
    <div class="widget">
      <h3>Recent Activity</h3>
      <% 3.times do %>
        <div class="skeleton-line"></div>
      <% end %>
    </div>
  <% end %>

  <%= turbo_frame_tag "team_performance",
    src: dashboard_team_performance_path,
    loading: :lazy do %>
    <div class="widget">
      <h3>Team Performance</h3>
      <div class="skeleton-block h-48"></div>
    </div>
  <% end %>
</section>
```

The initial page load is fast because only the primary content renders. The dashboard summary is immediately visible. Secondary widgets load on demand as the user scrolls, each showing a meaningful skeleton placeholder that matches the eventual content shape. The page feels complete from the start.

### BAD: Eager Loading Everything on Page Load

```erb
<%# Everything loads on the initial request -- slow page load %>
<h1>Dashboard</h1>

<section class="primary-content">
  <%= render "projects/summary", projects: @projects %>
</section>

<section class="widgets">
  <%# These all fire requests immediately, even if below the fold %>
  <%= turbo_frame_tag "recent_activity",
    src: dashboard_recent_activity_path do %>
  <% end %>

  <%= turbo_frame_tag "team_performance",
    src: dashboard_team_performance_path do %>
  <% end %>

  <%# No placeholder content -- user sees empty space while loading %>
  <%= turbo_frame_tag "upcoming_deadlines",
    src: dashboard_upcoming_deadlines_path do %>
  <% end %>
</section>
```

Without `loading: :lazy`, all three frames fire fetch requests immediately when the page loads, competing for bandwidth and server resources even though the user may never scroll down to see them. The empty `turbo_frame_tag` blocks have no placeholder content, so users see blank gaps in the page while content loads. This defeats the purpose of deferred loading and results in a slower, more jarring experience.
