---
title: Inline Turbo Stream Tags
---

## Table of Contents

- [Overview](#overview)
- [Implementation](#implementation)
  - [The Built-in Actions](#the-built-in-actions)
  - [Single Action Responses](#single-action-responses)
  - [Multi-Action Responses](#multi-action-responses)
  - [Targeting with dom_id](#targeting-with-dom_id)
  - [Controller Setup](#controller-setup)
  - [HTML Fallback](#html-fallback)
- [Key Points](#key-points)
- [Pattern Card: Multi-Action Stream Responses](#pattern-card-multi-action-stream-responses)

## Overview

Turbo Stream `.turbo_stream.erb` templates are the primary way to send stream actions in response to form submissions and controller actions over HTTP. Each template can contain multiple `turbo_stream` helper calls, allowing a single response to update several parts of the page simultaneously. This is more maintainable than replacing a large page section because each action targets a specific DOM element.

## Implementation

### The Built-in Actions

Turbo provides 8 built-in stream actions, each with a corresponding Rails helper:

| Action | Helper | Behavior |
|--------|--------|----------|
| `append` | `turbo_stream.append` | Add content to the end of a target element |
| `prepend` | `turbo_stream.prepend` | Add content to the beginning of a target element |
| `replace` | `turbo_stream.replace` | Replace the entire target element (including the element itself) |
| `update` | `turbo_stream.update` | Replace only the inner content of the target element |
| `remove` | `turbo_stream.remove` | Remove the target element from the DOM |
| `before` | `turbo_stream.before` | Insert content before the target element |
| `after` | `turbo_stream.after` | Insert content after the target element |
| `refresh` | `turbo_stream.refresh` | Trigger a full page refresh (added in Turbo 8) |

### Single Action Responses

The simplest stream response performs one action:

```erb
<%# app/views/comments/create.turbo_stream.erb %>
<%= turbo_stream.append "comments", partial: "comments/comment", locals: { comment: @comment } %>
```

This appends the rendered `_comment.html.erb` partial to the element with `id="comments"`.

### Multi-Action Responses

A single response can perform multiple actions to update different parts of the page:

```erb
<%# app/views/comments/create.turbo_stream.erb %>

<%# 1. Append the new comment to the list %>
<%= turbo_stream.append "comments", partial: "comments/comment", locals: { comment: @comment } %>

<%# 2. Update the comment count in the header %>
<%= turbo_stream.update "comment_count" do %>
  <%= @post.comments.count %> comments
<% end %>

<%# 3. Clear the form %>
<%= turbo_stream.replace "new_comment_form" do %>
  <%= render "comments/form", comment: Comment.new, post: @post %>
<% end %>

<%# 4. Show a flash message %>
<%= turbo_stream.prepend "flash_messages" do %>
  <div class="flash flash--success" data-controller="auto-dismiss">
    Comment added successfully
  </div>
<% end %>
```

### Targeting with dom_id

Use Rails `dom_id` helper for consistent, collision-free target IDs:

```erb
<%# In your view: generates id="comment_42" %>
<div id="<%= dom_id(comment) %>">
  <%= comment.body %>
</div>

<%# In your stream template: targets "comment_42" %>
<%= turbo_stream.replace dom_id(@comment), partial: "comments/comment", locals: { comment: @comment } %>
```

For collections, use a container with a known ID:

```erb
<%# In your view %>
<div id="<%= dom_id(@post, :comments) %>">
  <%= render @post.comments %>
</div>

<%# In your stream template %>
<%= turbo_stream.append dom_id(@post, :comments), partial: "comments/comment", locals: { comment: @comment } %>
```

### Controller Setup

Use `respond_to` to serve both Turbo Stream and HTML formats:

```ruby
class CommentsController < ApplicationController
  def create
    @post = Post.find(params[:post_id])
    @comment = @post.comments.create!(comment_params)

    respond_to do |format|
      format.turbo_stream  # renders create.turbo_stream.erb
      format.html { redirect_to @post, notice: "Comment added" }
    end
  end

  def destroy
    @comment = Comment.find(params[:id])
    @comment.destroy!

    respond_to do |format|
      format.turbo_stream  # renders destroy.turbo_stream.erb
      format.html { redirect_to @comment.post, notice: "Comment removed" }
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:body)
  end
end
```

The `destroy` stream template uses `remove` to take the element out of the DOM:

```erb
<%# app/views/comments/destroy.turbo_stream.erb %>
<%= turbo_stream.remove dom_id(@comment) %>
```

### HTML Fallback

Always provide an HTML fallback for non-Turbo clients (direct links, JavaScript disabled, mobile apps):

```ruby
respond_to do |format|
  format.turbo_stream
  format.html { redirect_to @post }
end
```

For error cases, re-render the form with validation errors:

```ruby
def create
  @post = Post.find(params[:post_id])
  @comment = @post.comments.build(comment_params)

  if @comment.save
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @post }
    end
  else
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "new_comment_form",
          partial: "comments/form",
          locals: { comment: @comment, post: @post }
        )
      end
      format.html { render :new, status: :unprocessable_entity }
    end
  end
end
```

## Key Points

- Each `.turbo_stream.erb` template can contain multiple stream actions
- Use `dom_id` for target IDs to avoid collisions and stay consistent
- Always pair `format.turbo_stream` with `format.html` for progressive enhancement
- Render the same partial for initial page load and stream updates to keep markup in sync
- Use `update` when you only need to change inner content; use `replace` when the element itself must change

## Pattern Card: Multi-Action Stream Responses

**When to use**: A single user action should update multiple independent parts of the page.

**GOOD - Multiple targeted stream actions in one response**:

```erb
<%# app/views/tasks/update.turbo_stream.erb %>

<%# Update the task itself %>
<%= turbo_stream.replace dom_id(@task), partial: "tasks/task", locals: { task: @task } %>

<%# Update the progress bar %>
<%= turbo_stream.update "project_progress" do %>
  <%= render "projects/progress_bar", project: @task.project %>
<% end %>

<%# Update the sidebar count %>
<%= turbo_stream.update "incomplete_count" do %>
  <%= @task.project.tasks.incomplete.count %>
<% end %>
```

```ruby
# app/controllers/tasks_controller.rb
class TasksController < ApplicationController
  def update
    @task = Task.find(params[:id])
    @task.update!(task_params)

    respond_to do |format|
      format.turbo_stream  # renders update.turbo_stream.erb
      format.html { redirect_to @task.project }
    end
  end
end
```

**BAD - Replacing a large container to update everything at once**:

```erb
<%# Replacing the entire page section is wasteful and loses DOM state %>
<%= turbo_stream.replace "main_content" do %>
  <%= render "projects/show_content", project: @task.project %>
<% end %>
```

This replaces too much DOM, loses scroll position, resets form inputs, and is slower than targeted updates.
