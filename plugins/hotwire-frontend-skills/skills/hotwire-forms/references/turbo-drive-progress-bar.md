---
title: Turbo Drive - Re-Use the Turbo Progress Bar
---

## Table of Contents

- [Overview](#overview)
- [Turbo Progress Bar API](#turbo-progress-bar-api)
- [Rails Implementation with ActionCable](#rails-implementation-with-actioncable)
  - [ActionCable Channel](#actioncable-channel)
  - [Controller Action](#controller-action)
  - [Background Job](#background-job)
  - [JavaScript with ActionCable](#javascript-with-actioncable)
- [Dynamic Enable/Disable](#dynamic-enabledisable)
- [Considerations](#considerations)
- [Pattern Card: Custom Progress Bar for Long Operations](#pattern-card-custom-progress-bar-for-long-operations)


## Overview
Turbo Drive includes a progress bar displayed at the top of the browser window. By default, it appears when a Turbo Drive visit exceeds a specific timeout. The progress bar can be programmatically controlled for custom use cases.

## Turbo Progress Bar API

Turbo Drive includes a built-in progress bar that appears after a configurable delay. The only officially documented configuration is `Turbo.config.drive.progressBarDelay`, which controls the millisecond delay before the progress bar appears during navigation.

> Specific API usage for programmatic progress bar control varies by version. Use context7 to fetch the latest official documentation for version-specific API details.

## Rails Implementation with ActionCable

### ActionCable Channel
Create a channel to broadcast progress updates:

```ruby
# app/channels/progress_channel.rb
class ProgressChannel < ApplicationCable::Channel
  def subscribed
    stream_from "progress_#{params[:id]}"
  end
end
```

### Controller Action
Create a controller action that starts a background process and broadcasts progress:

```ruby
# app/controllers/tasks_controller.rb
class TasksController < ApplicationController
  def start
    task_id = SecureRandom.uuid

    # Start background job or process
    ProgressJob.perform_later(task_id)

    render json: { task_id: task_id }
  end
end
```

### Background Job
Use a background job to simulate progress updates:

```ruby
# app/jobs/progress_job.rb
class ProgressJob < ApplicationJob
  def perform(task_id)
    progress = 0

    while progress < 1.0
      sleep 0.1 # Simulate work
      progress += 0.05
      progress = [progress, 1.0].min

      ActionCable.server.broadcast(
        "progress_#{task_id}",
        { amount: progress }
      )
    end
  end
end
```

### JavaScript with ActionCable
On the client side, subscribe to the ActionCable channel and update the UI when progress messages arrive. The progress bar DOM manipulation is straightforward -- update a width style or CSS custom property based on the received percentage value.

## Dynamic Enable/Disable
To enable or disable progress bar updates dynamically, guard the progress bar state management with conditional logic based on data attributes or other conditions. For example, check a data attribute on the event's target element before updating the progress bar.

## Considerations
The Turbo progress bar is designed for navigation feedback. Using it for non-navigation tasks may result in poor UX. Consider using it for extended navigation scenarios such as filtering large datasets that take time to process.


## Pattern Card: Custom Progress Bar for Long Operations

**When to use**: Background jobs, file uploads, or any operation with measurable progress.

**GOOD - Broadcasting progress via ActionCable and updating Turbo's progress bar**:

Use ActionCable to broadcast progress updates from a background job, and update Turbo's built-in progress bar on the client side.

```ruby
# app/jobs/progress_job.rb
class ProgressJob < ApplicationJob
  def perform(task_id)
    progress = 0
    while progress < 1.0
      progress += 0.05
      ActionCable.server.broadcast("progress_#{task_id}", { amount: progress })
      sleep 0.1
    end
  end
end
```

> Specific API usage for programmatic progress bar control on the JavaScript side varies by version. Use context7 to fetch the latest official documentation for version-specific API details.

**BAD - Custom progress bar without Turbo integration**:

```javascript
// Don't create a separate progress bar system
const customBar = document.createElement('div');
// ... lots of custom CSS and positioning
```
