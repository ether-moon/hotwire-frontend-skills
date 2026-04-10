---
title: "The Turbo Form Submission Lifecycle"
---

# The Turbo Form Submission Lifecycle

> Status codes drive Turbo form behavior: 422 re-renders errors in place, 303 follows the redirect, 200 on POST is silently ignored.

## Decision

- **422 Unprocessable Entity** -- Turbo renders the response body in place (re-renders form with errors)
- **303 See Other** -- Turbo follows the redirect and navigates to the new URL
- **200 OK** -- Turbo 8+ does NOT render POST responses with 200 (no user feedback at all)
- Always use `status: :see_other` (not default 302) after successful POST/PATCH/DELETE
- Getting status codes wrong is the #1 source of Turbo form bugs

## Lifecycle

```
User clicks submit
       |
       v
turbo:submit-start
  - form gets [aria-busy="true"]
  - submit button state changes (if data-turbo-submits-with)
       |
       v
Turbo sends fetch() request
  - Method: POST/PATCH/DELETE
  - Headers: Accept: text/vnd.turbo-stream.html, text/html
       |
       +---> Validation fails
       |         |
       |     render :action, status: :unprocessable_entity (422)
       |         |
       |     Turbo renders response body in place
       |
       +---> Validation succeeds
                 |
             redirect_to path, status: :see_other (303)
                 |
             Turbo follows redirect (GET request)
                 |
             turbo:load (new page rendered)
```

## Pattern

### Controller: the 422/303 contract

```ruby
def create
  @task = @project.tasks.build(task_params)
  if @task.save
    redirect_to project_tasks_path(@project), status: :see_other    # 303
  else
    render :new, status: :unprocessable_entity                       # 422
  end
end

def destroy
  @task.destroy!
  redirect_to project_tasks_path(@project), status: :see_other      # 303 for DELETE too
end
```

### View: error display + submit button state

```erb
<%= form_with model: @task do |f| %>
  <% if @task.errors.any? %>
    <div class="bg-red-50 p-4 rounded-md mb-4">
      <ul>
        <% @task.errors.full_messages.each do |msg| %>
          <li class="text-sm text-red-700"><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <%= f.text_field :title %>
  <%= f.text_area :description %>
  <%= f.submit "Save", data: { turbo_submits_with: "Saving..." } %>
<% end %>
```

`data-turbo-submits-with` changes button text during submission. Turbo auto-disables submit buttons -- no JS needed.

### Breaking out of a frame on redirect

```erb
<%# If the form is in a frame but the redirect should navigate the full page %>
<%= form_with model: @task, data: { turbo_frame: "_top" } do |f| %>
```

### Listening to submission events

```erb
<%= form_with model: @task,
      data: {
        controller: "form-events",
        action: "turbo:submit-start->form-events#submitStart turbo:submit-end->form-events#submitEnd"
      } do |f| %>
```

```javascript
export default class extends Controller {
  submitStart(event) {
    this.element.classList.add("submitting")
  }

  submitEnd(event) {
    const { success } = event.detail
    this.element.classList.remove("submitting")
  }
}
```

### Activity indicators with Turbo events

```js
document.addEventListener('turbo:submit-start', () => {
  document.querySelector('#hint').innerText = 'Saving...';
  document.querySelectorAll('input').forEach(input => input.disabled = true);
});

document.addEventListener('turbo:submit-end', () => {
  document.querySelector('#hint').innerText = 'Saved.';
});
```

Use `turbo:before-render` with `event.preventDefault()` / `event.detail.resume()` to add perceivable delays if needed.

## Pitfalls

### Returning 200 for validation errors

```ruby
# BAD -- Turbo 8+ silently ignores the response; user sees nothing
render :new

# GOOD -- Turbo re-renders the form in place
render :new, status: :unprocessable_entity
```

### Using 302 instead of 303

```ruby
# BAD -- Turbo expects 303 for non-GET form submissions
redirect_to tasks_path

# GOOD -- 303 guarantees a GET request for the redirect
redirect_to tasks_path, status: :see_other
```

### Forgetting the frame in the redirect response

If a form inside a frame submits and the redirect response does not contain a matching frame, Turbo falls back to full-page navigation. Either ensure the redirect target contains the matching frame, or use `data-turbo-frame="_top"` on the form.

### Manual button disable bypassing Turbo

```erb
<%# BAD -- this.form.submit() bypasses Turbo entirely %>
<%= f.submit "Save", onclick: "this.disabled=true; this.form.submit();" %>

<%# GOOD -- let Turbo handle it %>
<%= f.submit "Save", data: { turbo_submits_with: "Saving..." } %>
```

### Non-GET submissions in frames

When a form inside a Turbo Frame submits with POST/PATCH/DELETE:
1. 422 response: frame content replaced with the matching frame from response body
2. 303 redirect: Turbo follows it; the redirected page must contain the matching frame
3. Alternative: respond with Turbo Streams for more granular control
