---
title: "Multi-Step Wizard Form"
---

# Multi-Step Wizard Form

A multi-step registration wizard where each step is a separate page rendered inside a Turbo Frame. Wizard state is stored in the server session. Users can navigate forward and back without losing data.

## Controller

The controller stores each step's data in the session and validates per-step. The final `complete` action builds the actual model from accumulated session data:

```ruby
class RegistrationsController < ApplicationController
  before_action :load_registration_from_session

  def new
    redirect_to step_1_registration_path
  end

  def step_1; end
  def step_2; end
  def step_3; end

  def create
    case params[:step]
    when "1"
      save_to_session(:step_1, step_1_params)
      if valid_step_1?
        redirect_to step_2_registration_path, status: :see_other
      else
        render :step_1, status: :unprocessable_entity
      end
    when "2"
      save_to_session(:step_2, step_2_params)
      if valid_step_2?
        redirect_to step_3_registration_path, status: :see_other
      else
        render :step_2, status: :unprocessable_entity
      end
    end
  end

  def complete
    @user = User.new(registration_params_from_session)
    if @user.save
      session.delete(:registration)
      redirect_to dashboard_path, status: :see_other, notice: "Welcome!"
    else
      @errors = @user.errors
      render :step_3, status: :unprocessable_entity
    end
  end

  private

  def load_registration_from_session
    @registration = session[:registration] || {}
  end

  def save_to_session(step, params)
    session[:registration] ||= {}
    session[:registration][step] = params.to_h
  end

  def registration_params_from_session
    (session.dig(:registration, :step_1) || {})
      .merge(session.dig(:registration, :step_2) || {})
  end

  def valid_step_1?
    params[:registration][:first_name].present? &&
      params[:registration][:last_name].present? &&
      params[:registration][:email].present?
  end

  def valid_step_2?
    params[:registration][:username].present? &&
      params[:registration][:password].present?
  end

  def step_1_params
    params.require(:registration).permit(:first_name, :last_name, :email)
  end

  def step_2_params
    params.require(:registration).permit(:username, :password)
  end
end
```

## Routes

Non-standard routes because each step needs its own URL:

```ruby
resource :registration, only: %i[new create] do
  member do
    get :step_1
    get :step_2
    get :step_3
    post :complete
  end
end
```

## Step View (Representative Pattern)

Each step follows the same structure -- a Turbo Frame wrapping the form with a `step` hidden field. Previous values are pre-filled from session:

```erb
<%# app/views/registrations/step_1.html.erb %>
<div class="max-w-md mx-auto">
  <%= render "progress", current_step: 1 %>

  <%= turbo_frame_tag "wizard_step" do %>
    <h2>Personal Information</h2>

    <%= form_with url: registration_path, method: :post do |f| %>
      <%= hidden_field_tag :step, 1 %>

      <%= f.label :first_name, "First Name" %>
      <%= text_field_tag "registration[first_name]",
            @registration.dig(:step_1, "first_name"),
            autofocus: true %>

      <%= f.label :last_name, "Last Name" %>
      <%= text_field_tag "registration[last_name]",
            @registration.dig(:step_1, "last_name") %>

      <%= f.label :email, "Email" %>
      <%= email_field_tag "registration[email]",
            @registration.dig(:step_1, "email") %>

      <%= f.submit "Next: Account Details",
            data: { turbo_submits_with: "Saving..." } %>
    <% end %>
  <% end %>
</div>
```

Step 2 adds a "Back" link. Step 3 is a read-only review with a `button_to` for final submission:

```erb
<%# Step 2 navigation %>
<%= link_to "Back", step_1_registration_path %>
<%= f.submit "Next: Review" %>

<%# Step 3 final submit %>
<%= link_to "Back", step_2_registration_path %>
<%= button_to "Create Account", complete_registration_path, method: :post,
      data: { turbo_submits_with: "Creating Account..." } %>
```

## Why This Works

- **Session storage, not hidden fields**: Wizard state lives in the server session. Users cannot tamper with previously submitted data, and navigating back pre-fills values from session.
- **422/303 lifecycle per step**: Each step validates independently. Failure re-renders the current step (422). Success redirects to the next step (303). This is the same pattern as a single-step form, applied repeatedly.
- **Turbo Frame for step content**: The `"wizard_step"` frame wraps each step so only the form area changes. The progress bar sits outside the frame and updates on each full page load.
- **Final validation on complete**: The `complete` action builds the real `User` model from all session data and runs full model validation. If it fails, the user sees errors on the review step and can navigate back to fix them.
- **Back navigation preserves state**: "Back" links are standard links. Since data is in the session, returning to a previous step shows the user's previously entered values.
- **`form_with url:` not `model:`**: Wizard steps post to a single `create` action with a `step` parameter, not to individual model-backed routes. `text_field_tag` with manual names gives full control over parameter structure.
