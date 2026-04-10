---
title: "Turbo Frames Pagination"
---

# Turbo Frames Pagination

## Table of Contents

- [Overview](#overview)
- [Implementation](#implementation)
  - [Basic Frame-Wrapped Pagination](#basic-frame-wrapped-pagination)
  - [Controller Setup](#controller-setup)
  - [Pagination Gem Integration](#pagination-gem-integration)
  - [Infinite Scroll Alternative](#infinite-scroll-alternative)
- [Pattern Card](#pattern-card)

## Overview

Pagination is a natural fit for Turbo Frames. By wrapping both the list content and the pagination controls inside a single Turbo Frame, clicking "Next" or a page number replaces only the list section -- the rest of the page (sidebar, header, filters) stays untouched.

This provides a much faster navigation experience than full-page reloads for paginated content. The URL updates naturally through the frame, and without JavaScript the pagination links simply work as normal full-page navigations.

Key principles:
- Wrap both the list **and** the pagination controls inside the same `turbo_frame_tag`.
- Pagination links automatically target their enclosing frame -- no extra `data-turbo-frame` needed.
- The controller responds with the same view; Turbo extracts the matching frame.
- For long lists, consider infinite scroll as an alternative to numbered pagination.

## Implementation

### Basic Frame-Wrapped Pagination

```erb
<%# app/views/projects/index.html.erb %>
<h1>Projects</h1>

<div class="projects-page">
  <%# Sidebar stays outside the frame so it never re-renders %>
  <aside class="sidebar">
    <%= render "projects/filters" %>
  </aside>

  <main>
    <%= turbo_frame_tag "projects_list" do %>
      <div class="projects-grid">
        <%= render @projects %>
      </div>

      <nav class="pagination-controls" aria-label="Pagination">
        <%== pagy_nav(@pagy) %>
      </nav>
    <% end %>
  </main>
</div>
```

The `turbo_frame_tag "projects_list"` wraps everything that should update on page change: the project cards and the pagination controls. When the user clicks a page link, Turbo fetches the new page URL and extracts the `projects_list` frame from the response.

### Controller Setup

```ruby
# app/controllers/projects_controller.rb
class ProjectsController < ApplicationController
  include Pagy::Backend

  def index
    @pagy, @projects = pagy(
      Project.visible_to(Current.user).order(updated_at: :desc),
      items: 12
    )
  end
end
```

The controller does not need any special Turbo Frame logic. It renders the same view for both full-page requests and frame requests. Turbo handles extracting the correct frame content from the response.

### Pagination Gem Integration

**With Pagy (recommended):**

Pagy generates plain HTML links that work naturally inside Turbo Frames. No special configuration is needed.

```ruby
# config/initializers/pagy.rb
Pagy::DEFAULT[:items] = 12
Pagy::DEFAULT[:size] = 7  # Number of page links shown
```

```erb
<%# Pagy links work inside frames automatically %>
<%= turbo_frame_tag "projects_list" do %>
  <%= render @projects %>
  <%== pagy_nav(@pagy) %>
<% end %>
```

**With Kaminari:**

Kaminari also works inside Turbo Frames without modification. Its pagination links are standard `<a>` tags.

```erb
<%= turbo_frame_tag "projects_list" do %>
  <%= render @projects %>
  <%= paginate @projects %>
<% end %>
```

**With will_paginate:**

```erb
<%= turbo_frame_tag "projects_list" do %>
  <%= render @projects %>
  <%= will_paginate @projects %>
<% end %>
```

### Infinite Scroll Alternative

For feeds, activity logs, or content-heavy pages, infinite scroll can be a better fit than numbered pagination. This approach uses a Turbo Frame at the bottom of the list that lazy-loads the next page when it becomes visible.

```erb
<%# app/views/activities/index.html.erb %>
<%= turbo_frame_tag "activities" do %>
  <div class="activity-feed">
    <% @activities.each do |activity| %>
      <div class="activity-item" id="<%= dom_id(activity) %>">
        <%= render activity %>
      </div>
    <% end %>
  </div>

  <% if @pagy.next %>
    <%= turbo_frame_tag "activities_page_#{@pagy.next}",
      src: activities_path(page: @pagy.next),
      loading: :lazy do %>
      <div class="loading-more">
        <span class="spinner"></span>
        Loading more...
      </div>
    <% end %>
  <% end %>
<% end %>
```

Each subsequent page response includes its own lazy-loading frame for the next page, creating a chain:

```erb
<%# app/views/activities/index.html.erb (also used for page 2, 3, ...) %>
<%= turbo_frame_tag "activities_page_#{@pagy.page}" do %>
  <% @activities.each do |activity| %>
    <div class="activity-item" id="<%= dom_id(activity) %>">
      <%= render activity %>
    </div>
  <% end %>

  <% if @pagy.next %>
    <%= turbo_frame_tag "activities_page_#{@pagy.next}",
      src: activities_path(page: @pagy.next),
      loading: :lazy do %>
      <div class="loading-more">
        <span class="spinner"></span>
        Loading more...
      </div>
    <% end %>
  <% end %>
<% end %>
```

This technique uses `loading: :lazy` to trigger fetching only when the frame scrolls into view. Each page response contains the items for that page and a lazy frame for the next page (if one exists). The chain terminates when there are no more pages.

**Stimulus-based infinite scroll with IntersectionObserver:**

For more control over when loading triggers, use a Stimulus controller with IntersectionObserver:

```javascript
// app/javascript/controllers/infinite_scroll_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sentinel"]
  static values = { url: String }

  connect() {
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            this.loadMore()
          }
        })
      },
      { rootMargin: "200px" } // Start loading 200px before the sentinel is visible
    )

    if (this.hasSentinelTarget) {
      this.observer.observe(this.sentinelTarget)
    }
  }

  disconnect() {
    this.observer?.disconnect()
  }

  loadMore() {
    if (this.loading) return
    this.loading = true

    // The lazy turbo frame handles the actual loading.
    // This controller just ensures it triggers at the right time.
    const frame = this.sentinelTarget.querySelector("turbo-frame")
    if (frame && frame.src) {
      frame.loading = "eager"
    }
  }
}
```

```erb
<div data-controller="infinite-scroll">
  <%= turbo_frame_tag "activities" do %>
    <%= render @activities %>
  <% end %>

  <% if @pagy.next %>
    <div data-infinite-scroll-target="sentinel">
      <%= turbo_frame_tag "next_page",
        src: activities_path(page: @pagy.next),
        loading: :lazy do %>
        <div class="loading-indicator">Loading...</div>
      <% end %>
    </div>
  <% end %>
</div>
```

## Pattern Card

### GOOD: Frame-Wrapped Pagination

```erb
<%= turbo_frame_tag "projects_list" do %>
  <div class="projects-grid">
    <%= render @projects %>
  </div>

  <% if @projects.empty? %>
    <div class="empty-state">
      <p>No projects found.</p>
    </div>
  <% end %>

  <nav class="pagination" aria-label="Pagination">
    <%== pagy_nav(@pagy) %>
  </nav>
<% end %>
```

Both the list and pagination controls are inside the frame. Clicking a page number replaces only this section. The sidebar, header, and any other page elements remain untouched. Without JavaScript, pagination links navigate to the full page normally.

### BAD: Full Page Reload Pagination

```erb
<%# Everything outside a frame -- clicking pagination reloads the entire page %>
<div class="projects-grid">
  <%= render @projects %>
</div>

<nav class="pagination" aria-label="Pagination">
  <%== pagy_nav(@pagy) %>
</nav>
```

Without a Turbo Frame wrapper, every pagination click triggers a full Turbo Drive visit that replaces the entire `<body>`. This re-renders the sidebar, header, and all other page sections unnecessarily. It also resets any client-side state (scroll position within the list, open dropdowns, active filters) and feels sluggish compared to frame-scoped updates.
