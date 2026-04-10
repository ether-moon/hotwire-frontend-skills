---
title: "Dashboard with Lazy-Loaded Widgets"
---

Dashboard that loads instantly with critical content, then lazily loads secondary widgets as the user scrolls. Uses Turbo 8 morph refresh for real-time updates.

**Patterns combined:** Lazy loading, Turbo 8 morph refresh, Turbo Drive caching

### Routes

```ruby
# config/routes.rb
resource :dashboard, only: [:show] do
  member do
    get :recent_projects
    get :activity_feed
    get :team_stats
    get :upcoming_deadlines
  end
end
```

### Controller

```ruby
# app/controllers/dashboards_controller.rb
class DashboardsController < ApplicationController
  def show
    @greeting = greeting_for(Current.user)
    @notifications_count = Current.user.notifications.unread.count
    @quick_actions = Current.user.pending_approvals.limit(5)
  end

  def recent_projects
    @projects = Current.user.projects
      .includes(:last_activity)
      .order(updated_at: :desc)
      .limit(6)
  end

  def activity_feed
    @activities = Current.user.team.activities
      .includes(:user, :trackable)
      .order(created_at: :desc)
      .limit(15)
  end

  def team_stats
    @stats = TeamStatsQuery.new(Current.user.team).call
  end

  def upcoming_deadlines
    @deadlines = Current.user.assigned_tasks
      .incomplete
      .where(due_date: Date.today..14.days.from_now)
      .order(:due_date)
      .limit(10)
  end
end
```

### Dashboard View

Key layout: critical content inline, secondary widgets in lazy-loaded frames with skeleton placeholders.

```erb
<%# app/views/dashboards/show.html.erb %>
<%= turbo_stream_from "dashboard_#{Current.user.id}" %>

<div class="dashboard">
  <%# Critical content loads with the page -- no lazy loading %>
  <section class="dashboard-header">
    <h1><%= @greeting %></h1>
    <div class="quick-stats">
      <span class="stat">
        <strong><%= @notifications_count %></strong> unread notifications
      </span>
    </div>
  </section>

  <% if @quick_actions.any? %>
    <section class="quick-actions">
      <h2>Pending Approvals</h2>
      <ul class="action-list">
        <% @quick_actions.each do |approval| %>
          <li>
            <%= link_to approval.title, approval_path(approval), data: { turbo_frame: "_top" } %>
          </li>
        <% end %>
      </ul>
    </section>
  <% end %>

  <%# Secondary content loads lazily as user scrolls %>
  <section class="dashboard-widgets">
    <%= turbo_frame_tag "recent_projects",
      src: recent_projects_dashboard_path,
      loading: :lazy do %>
      <div class="widget">
        <h3>Recent Projects</h3>
        <div class="widget-skeleton">
          <% 3.times do %><div class="skeleton-card"></div><% end %>
        </div>
      </div>
    <% end %>

    <%= turbo_frame_tag "team_stats",
      src: team_stats_dashboard_path,
      loading: :lazy do %>
      <div class="widget">
        <h3>Team Stats</h3>
        <div class="skeleton-block h-48"></div>
      </div>
    <% end %>

    <%= turbo_frame_tag "activity_feed",
      src: activity_feed_dashboard_path,
      loading: :lazy do %>
      <div class="widget widget--wide">
        <h3>Activity Feed</h3>
        <% 5.times do %><div class="skeleton-activity"></div><% end %>
      </div>
    <% end %>

    <%= turbo_frame_tag "upcoming_deadlines",
      src: upcoming_deadlines_dashboard_path,
      loading: :lazy do %>
      <div class="widget">
        <h3>Upcoming Deadlines</h3>
        <% 4.times do %><div class="skeleton-line w-full"></div><% end %>
      </div>
    <% end %>
  </section>
</div>
```

### Widget Partial (representative example)

```erb
<%# app/views/dashboards/recent_projects.html.erb %>
<%= turbo_frame_tag "recent_projects" do %>
  <div class="widget">
    <h3>Recent Projects</h3>
    <div class="project-cards">
      <% @projects.each do |project| %>
        <div class="project-card" id="<%= dom_id(project) %>">
          <h4><%= link_to project.name, project_path(project), data: { turbo_frame: "_top" } %></h4>
          <p class="text-sm text-gray-500">
            Updated <%= time_ago_in_words(project.updated_at) %> ago
          </p>
        </div>
      <% end %>
    </div>
  </div>
<% end %>
```

### Layout Configuration

Enable morph refresh to keep widgets updated in real time:

```erb
<%# app/views/layouts/application.html.erb — in <head> %>
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>
```

### Why This Works

- **Instant first paint.** Critical content (greeting, notifications, approvals) loads synchronously. Slow queries (projects, stats, feed, deadlines) are deferred to lazy frames.
- **Skeleton placeholders.** Each lazy frame wraps a skeleton UI that displays until the frame `src` resolves, avoiding layout shift.
- **Morph refresh for real-time.** `turbo_stream_from` combined with `turbo_refreshes_with method: :morph` lets broadcasted updates morph the page without disrupting scroll or focus.
- **Links break out of frames.** All widget links use `data: { turbo_frame: "_top" }` to navigate the full page, not the widget frame.
