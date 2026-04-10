---
title: "Broadcasting with ActionCable and Solid Cable"
---

# Broadcasting with ActionCable and Solid Cable

> Push real-time Turbo Stream updates to all connected clients over WebSocket when server data changes -- no polling needed.

## Decision

Choose between **declarative** (`broadcasts_to` -- zero-config CRUD broadcasting) and **manual** (`after_*_commit` + `broadcast_*_to` -- full control over what/when/how). Use `_later` variants for async broadcasting via Active Job. In multi-tenant apps, **always** scope broadcast channel names to the tenant. For transport, choose Redis-backed ActionCable (default) or Solid Cable (database-backed, no Redis).

## Pattern

### View: Subscribe to a Channel

```erb
<%= turbo_stream_from @post, :comments %>
<div id="comments"><%= render @post.comments %></div>
```

`turbo_stream_from` generates a `<turbo-cable-stream-source>` element that opens a WebSocket subscription. Multiple arguments are joined into a signed stream name.

### Model: Declarative Broadcasting

```ruby
class Comment < ApplicationRecord
  belongs_to :post

  broadcasts_to ->(comment) { [comment.post, :comments] },
                inserts_by: :append,
                target: "comments"
end
```

Equivalent to three separate callbacks:

```ruby
after_create_commit  -> { broadcast_append_to(post, :comments, target: "comments") }
after_update_commit  -> { broadcast_replace_to(post, :comments) }
after_destroy_commit -> { broadcast_remove_to(post, :comments) }
```

Override partial: `partial: "comments/comment_card"`.

### Model: Manual Broadcasting

```ruby
class Message < ApplicationRecord
  belongs_to :conversation

  after_create_commit  :broadcast_new_message
  after_update_commit  :broadcast_updated_message
  after_destroy_commit :broadcast_removal

  private

  def broadcast_new_message
    broadcast_append_to(
      [conversation, :messages],
      target: "messages",
      partial: "messages/message",
      locals: { message: self, current_user: nil }
    )
  end

  def broadcast_updated_message
    broadcast_replace_to([conversation, :messages], partial: "messages/message",
                         locals: { message: self, current_user: nil })
  end

  def broadcast_removal
    broadcast_remove_to([conversation, :messages])
  end
end
```

Async variant for lower response latency:

```ruby
after_create_commit -> {
  broadcast_append_later_to([conversation, :messages], target: "messages",
                            partial: "messages/message", locals: { message: self })
}
```

### Multi-Tenant Scoping

Always include the tenant in the stream name:

```ruby
class Task < ApplicationRecord
  belongs_to :project
  has_one :account, through: :project

  broadcasts_to ->(task) { [task.account, task.project, :tasks] },
                inserts_by: :append, target: "tasks"
end
```

```erb
<%= turbo_stream_from Current.account, @project, :tasks %>
<div id="tasks"><%= render @project.tasks %></div>
```

Reusable concern for tenant-scoped broadcasting:

```ruby
module TenantBroadcastable
  extend ActiveSupport::Concern

  included do
    after_create_commit  :broadcast_tenant_append
    after_update_commit  :broadcast_tenant_replace
    after_destroy_commit :broadcast_tenant_remove
  end

  private

  def broadcast_tenant_append
    broadcast_append_later_to(
      [account, self.class.name.underscore.pluralize],
      target: self.class.name.underscore.pluralize,
      partial: to_partial_path
    )
  end

  def broadcast_tenant_replace
    broadcast_replace_later_to(
      [account, self.class.name.underscore.pluralize],
      partial: to_partial_path
    )
  end

  def broadcast_tenant_remove
    broadcast_remove_to([account, self.class.name.underscore.pluralize])
  end

  def account
    respond_to?(:account) ? super : Current.account
  end
end
```

### Broadcasting from Background Jobs

Use `Turbo::StreamsChannel.broadcast_*_to` outside models:

```ruby
class ImportContactsJob < ApplicationJob
  include ActionView::RecordIdentifier

  def perform(import)
    import.process!
    Turbo::StreamsChannel.broadcast_replace_to(
      [import.account, import.user, :imports],
      target: dom_id(import),
      partial: "imports/import",
      locals: { import: import }
    )
  end
end
```

### Solid Cable (Redis-free Alternative)

```bash
bundle add solid_cable && bin/rails solid_cable:install
```

```yaml
# config/cable.yml
production:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
```

Advantages: no Redis infrastructure, messages survive restarts, works with SQLite, same deployment model as Rails.

### Combobox with Real-Time WebSocket Updates

Use Stimulus outlets to decouple WebSocket message handling from DOM updates:

```js
// external_websocket_controller.js
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { url: String }
  static outlets = ['receiver']

  connect() {
    this.websocket = new WebSocket(this.urlValue)
    this.websocket.addEventListener('message', this.handleMessage)
  }

  disconnect() { this.websocket?.close() }

  handleMessage = (event) => {
    const { topic, payload } = JSON.parse(event.data)
    this.receiverOutlets
      .filter(o => topic.startsWith(o.element.dataset.value))
      .forEach(o => o.changeLabel(payload.value))
  }
}
```

```js
// receiver_controller.js -- attached to each combobox option
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  changeLabel(state) {
    this.element.innerHTML = this.element.innerHTML.replace(/\(.*\)/, `(${state})`)
  }
}
```

## Pitfalls

**GOOD**: `broadcasts_to ->(task) { [task.account, task.project, :tasks] }`
**BAD**: `broadcasts_to ->(task) { :all_tasks }` -- leaks data across tenants

**GOOD**: `broadcast_append_later_to(...)` for async, lower-latency responses
**BAD**: Synchronous broadcasts in hot request paths causing slow responses

**GOOD**: `Turbo::StreamsChannel.broadcast_*_to(...)` from jobs/services
**BAD**: Calling model broadcast methods outside of model context

**GOOD**: Solid Cable for simpler deployments (no Redis dependency)
**BAD**: Using Solid Cable with very high message volume without tuning polling interval
