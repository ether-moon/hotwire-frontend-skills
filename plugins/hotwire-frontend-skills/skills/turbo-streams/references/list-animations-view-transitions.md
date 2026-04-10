---
title: List Animations and View Transitions with Turbo Streams
---

## Table of Contents

- [Overview](#overview)
- [Implementation](#implementation)
  - [CSS-Only Enter Animations with @starting-style](#css-only-enter-animations-with-starting-style)
  - [Exit Animations for Removals](#exit-animations-for-removals)
  - [View Transitions API with Turbo Streams](#view-transitions-api-with-turbo-streams)
  - [Scoped View Transitions per Stream Target](#scoped-view-transitions-per-stream-target)
  - [Morph Transitions](#morph-transitions)
  - [Rails Integration](#rails-integration)
- [Key Points](#key-points)
- [Pattern Card: CSS-Based Animations](#pattern-card-css-based-animations)

## Overview

When Turbo Streams add or remove elements from a list, the change is instant by default. Adding animations makes these changes feel polished and helps users track what changed. There are two complementary approaches:

1. **CSS `@starting-style`** -- pure CSS enter animations that work without JavaScript. New elements transition from their `@starting-style` values to their normal state.
2. **View Transitions API** -- a browser API that captures before/after snapshots and animates between them. Requires a JavaScript hook via `turbo:before-stream-render`.

Both approaches are CSS-driven and avoid manual JavaScript animation logic.

## Implementation

### CSS-Only Enter Animations with @starting-style

The CSS `@starting-style` rule defines the initial state of an element when it first appears in the DOM. Combined with CSS transitions, this creates enter animations with zero JavaScript:

```css
/* app/assets/stylesheets/stream_animations.css */

.task-item {
  opacity: 1;
  transform: translateY(0);
  transition: opacity 0.3s ease, transform 0.3s ease;

  /* Starting state when first inserted into the DOM */
  @starting-style {
    opacity: 0;
    transform: translateY(-10px);
  }
}
```

When Turbo Streams append or prepend a `.task-item` element, it automatically animates from `opacity: 0; translateY(-10px)` to its final state. No JavaScript is needed.

This works with all insertion stream actions: `append`, `prepend`, `before`, `after`, `replace`.

**Slide-in from the left**:

```css
.notification-item {
  opacity: 1;
  transform: translateX(0);
  transition: opacity 0.4s ease, transform 0.4s ease;

  @starting-style {
    opacity: 0;
    transform: translateX(-100%);
  }
}
```

**Scale-in effect**:

```css
.card-item {
  opacity: 1;
  transform: scale(1);
  transition: opacity 0.2s ease, transform 0.2s ease;

  @starting-style {
    opacity: 0;
    transform: scale(0.9);
  }
}
```

### Exit Animations for Removals

Turbo's `remove` action removes elements instantly. To animate the removal, intercept the stream render and add an exit animation before removing:

```javascript
// app/javascript/stream_animations.js
document.addEventListener("turbo:before-stream-render", (event) => {
  const stream = event.target

  if (stream.action === "remove") {
    const targetId = stream.getAttribute("target")
    const target = document.getElementById(targetId)

    if (target && target.classList.contains("animate-exit")) {
      event.preventDefault()

      target.classList.add("removing")
      target.addEventListener("transitionend", () => {
        target.remove()
      }, { once: true })
    }
  }
})
```

```css
.animate-exit {
  transition: opacity 0.3s ease, transform 0.3s ease;
}

.animate-exit.removing {
  opacity: 0;
  transform: translateX(100%);
}
```

```erb
<%# Mark elements that should animate on removal %>
<div id="<%= dom_id(task) %>" class="task-item animate-exit">
  <%= task.title %>
</div>
```

### View Transitions API with Turbo Streams

The View Transitions API captures a screenshot of the old state, renders the new state, then crossfades between them. Hook into Turbo's `turbo:before-stream-render` event to wrap stream rendering in a view transition:

```javascript
// app/javascript/view_transition_streams.js
document.addEventListener("turbo:before-stream-render", (event) => {
  // Only use view transitions if the browser supports them
  if (!document.startViewTransition) return

  const stream = event.target

  // Only apply to specific targets or actions
  if (stream.action === "append" || stream.action === "prepend") {
    const originalRender = event.detail.render

    event.detail.render = (streamElement) => {
      document.startViewTransition(() => {
        originalRender(streamElement)
      })
    }
  }
})
```

Define the transition animations in CSS:

```css
/* Animate new items sliding in */
::view-transition-new(list-item) {
  animation: slide-in 0.3s ease-out;
}

::view-transition-old(list-item) {
  animation: fade-out 0.2s ease-in;
}

@keyframes slide-in {
  from {
    opacity: 0;
    transform: translateY(-20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes fade-out {
  from { opacity: 1; }
  to { opacity: 0; }
}
```

Assign `view-transition-name` to the animated elements:

```erb
<%# app/views/tasks/_task.html.erb %>
<div id="<%= dom_id(task) %>"
     class="task-item"
     style="view-transition-name: <%= dom_id(task) %>">
  <h3><%= task.title %></h3>
  <p><%= task.description %></p>
</div>
```

Each element needs a unique `view-transition-name`. Using `dom_id` is a natural fit.

### Scoped View Transitions per Stream Target

Apply view transitions only for specific stream targets to avoid animating unrelated updates:

```javascript
// app/javascript/scoped_transitions.js
const ANIMATED_TARGETS = new Set(["tasks", "notifications", "messages"])

document.addEventListener("turbo:before-stream-render", (event) => {
  if (!document.startViewTransition) return

  const stream = event.target
  const targetId = stream.getAttribute("target")

  if (ANIMATED_TARGETS.has(targetId)) {
    const originalRender = event.detail.render

    event.detail.render = (streamElement) => {
      document.startViewTransition(() => {
        originalRender(streamElement)

        // Remove animation marker class after transition
        const newChild = document.getElementById(targetId)?.lastElementChild
        if (newChild) {
          newChild.classList.remove("new-item")
        }
      })
    }
  }
})
```

### Morph Transitions

When using Turbo 8 morphing, the `turbo:before-morph-element` event lets you set up view transitions for individual element morphs:

```javascript
// app/javascript/morph_transitions.js
document.addEventListener("turbo:before-morph-element", (event) => {
  if (!document.startViewTransition) return

  const { newElement } = event.detail
  const target = event.target

  // Only animate status changes
  if (target.dataset.status !== newElement.dataset.status) {
    event.preventDefault()

    document.startViewTransition(() => {
      target.replaceWith(newElement)
    })
  }
})
```

### Rails Integration

The Rails side simply renders standard Turbo Stream responses. Animations are handled entirely in CSS and JavaScript:

```ruby
# app/controllers/tasks_controller.rb
class TasksController < ApplicationController
  def create
    @task = @project.tasks.create!(task_params)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @project }
    end
  end

  def destroy
    @task = Task.find(params[:id])
    @task.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @task.project }
    end
  end
end
```

```erb
<%# app/views/tasks/create.turbo_stream.erb %>
<%= turbo_stream.append "tasks", partial: "tasks/task", locals: { task: @task } %>

<%# app/views/tasks/destroy.turbo_stream.erb %>
<%= turbo_stream.remove dom_id(@task) %>
```

The CSS `@starting-style` handles the enter animation for `create`, and the JavaScript exit handler animates the `destroy`.

## Key Points

- Use CSS `@starting-style` for zero-JavaScript enter animations on stream insertions
- Use `turbo:before-stream-render` to intercept removals and add exit animations
- Use the View Transitions API for crossfade-style animations between states
- Each element with `view-transition-name` must have a unique name (use `dom_id`)
- Scope view transitions to specific stream targets to avoid animating unrelated updates
- `@starting-style` has broad browser support; View Transitions API requires Chromium-based browsers
- Animations are CSS-driven; the Rails server sends standard stream responses with no animation logic

## Pattern Card: CSS-Based Animations

**When to use**: Animate list items being added or removed via Turbo Streams for a polished user experience.

**GOOD - CSS @starting-style for enter animations (zero JavaScript)**:

```css
.task-item {
  opacity: 1;
  transform: translateY(0);
  transition: opacity 0.3s ease, transform 0.3s ease;

  @starting-style {
    opacity: 0;
    transform: translateY(-10px);
  }
}
```

```erb
<%# Standard Turbo Stream -- CSS handles the animation %>
<%= turbo_stream.append "tasks", partial: "tasks/task", locals: { task: @task } %>
```

The element slides in automatically when appended. No JavaScript needed. Works with `append`, `prepend`, `before`, `after`.

**BAD - JavaScript-driven animations with manual DOM manipulation**:

```javascript
// Don't do this: manually animating elements after stream render
document.addEventListener("turbo:before-stream-render", (event) => {
  const originalRender = event.detail.render
  event.detail.render = (streamElement) => {
    originalRender(streamElement)

    // Manually finding and animating every new element
    const target = document.getElementById(streamElement.target)
    const lastChild = target?.lastElementChild
    if (lastChild) {
      lastChild.style.opacity = "0"
      lastChild.style.transform = "translateY(-10px)"
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          lastChild.style.transition = "all 0.3s ease"
          lastChild.style.opacity = "1"
          lastChild.style.transform = "translateY(0)"
        })
      })
    }
  }
})
```

This is verbose, fragile, and duplicates what CSS can handle declaratively.
