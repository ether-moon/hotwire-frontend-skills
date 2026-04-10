---
title: "Tabbed Settings Page"
---

User settings page with multiple tabs (Profile, Notifications, Security, Billing). Each tab loads its content into a shared Turbo Frame. Active tab is tracked via URL for bookmarkability.

**Patterns combined:** Tabbed navigation, Turbo Frames, form submission within frames

### Routes

```ruby
# config/routes.rb
resource :settings, only: [:show] do
  member do
    get :profile
    get :notifications
    get :security
    get :billing
    patch :update_profile
    patch :update_notifications
    patch :update_security
  end
end
```

### Controller

```ruby
# app/controllers/settings_controller.rb
class SettingsController < ApplicationController
  before_action :set_user

  TABS = %w[profile notifications security billing].freeze

  def show
    @active_tab = valid_tab(params[:tab])
    redirect_to settings_path(tab: "profile") unless params[:tab].present?
  end

  def profile
    @active_tab = "profile"
  end

  def notifications
    @active_tab = "notifications"
    @notification_preferences = @user.notification_preferences
  end

  def security
    @active_tab = "security"
  end

  def billing
    @active_tab = "billing"
    @subscription = @user.subscription
    @invoices = @user.invoices.order(created_at: :desc).limit(10)
  end

  def update_profile
    if @user.update(profile_params)
      redirect_to profile_settings_path, notice: "Profile updated."
    else
      render :profile, status: :unprocessable_entity
    end
  end

  def update_notifications
    if @user.update(notification_params)
      redirect_to notifications_settings_path, notice: "Notification preferences saved."
    else
      render :notifications, status: :unprocessable_entity
    end
  end

  def update_security
    if @user.update_with_password(security_params)
      redirect_to security_settings_path, notice: "Password changed."
    else
      render :security, status: :unprocessable_entity
    end
  end

  private

  def set_user = @user = Current.user
  def valid_tab(tab) = TABS.include?(tab) ? tab : "profile"
  def profile_params = params.require(:user).permit(:first_name, :last_name, :email, :bio, :avatar)
  def notification_params = params.require(:user).permit(notification_preferences: [:email_comments, :email_mentions, :email_digest, :push_enabled])
  def security_params = params.require(:user).permit(:current_password, :password, :password_confirmation)
end
```

### Settings Layout View

Tab links target the shared `settings_content` frame. Each tab has its own URL for direct access.

```erb
<%# app/views/settings/show.html.erb %>
<div class="settings-page">
  <h1>Settings</h1>

  <div class="settings-layout">
    <nav class="settings-tabs" data-controller="tabs" data-tabs-active-class="tab--active">
      <%= link_to "Profile", profile_settings_path,
        class: "tab #{'tab--active' if @active_tab == 'profile'}",
        data: { turbo_frame: "settings_content", tabs_target: "tab", action: "tabs#activate" } %>

      <%= link_to "Notifications", notifications_settings_path,
        class: "tab #{'tab--active' if @active_tab == 'notifications'}",
        data: { turbo_frame: "settings_content", tabs_target: "tab", action: "tabs#activate" } %>

      <%= link_to "Security", security_settings_path,
        class: "tab #{'tab--active' if @active_tab == 'security'}",
        data: { turbo_frame: "settings_content", tabs_target: "tab", action: "tabs#activate" } %>

      <%= link_to "Billing", billing_settings_path,
        class: "tab #{'tab--active' if @active_tab == 'billing'}",
        data: { turbo_frame: "settings_content", tabs_target: "tab", action: "tabs#activate" } %>
    </nav>

    <%= turbo_frame_tag "settings_content" do %>
      <%= render "settings/profile_form" %>
    <% end %>
  </div>
</div>
```

### Tab Content (Profile example)

```erb
<%# app/views/settings/profile.html.erb %>
<%= turbo_frame_tag "settings_content" do %>
  <section class="settings-section">
    <h2>Profile</h2>
    <%= form_with model: @user, url: update_profile_settings_path, method: :patch do |f| %>
      <% if @user.errors.any? %>
        <div class="form-errors">
          <ul><% @user.errors.full_messages.each do |msg| %><li><%= msg %></li><% end %></ul>
        </div>
      <% end %>
      <div class="form-row">
        <div class="form-group"><%= f.label :first_name %><%= f.text_field :first_name %></div>
        <div class="form-group"><%= f.label :last_name %><%= f.text_field :last_name %></div>
      </div>
      <div class="form-group"><%= f.label :email %><%= f.email_field :email %></div>
      <div class="form-group"><%= f.label :bio %><%= f.text_area :bio, rows: 4 %></div>
      <div class="form-actions"><%= f.submit "Save profile", class: "btn btn-primary" %></div>
    <% end %>
  </section>
<% end %>
```

### Tabs Stimulus Controller

```javascript
// app/javascript/controllers/tabs_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab"]
  static classes = ["active"]

  activate(event) {
    this.tabTargets.forEach(tab => tab.classList.remove(...this.activeClasses))
    event.currentTarget.classList.add(...this.activeClasses)
  }

  connect() {
    const currentPath = window.location.pathname
    this.tabTargets.forEach(tab => {
      if (tab.getAttribute("href") === currentPath) {
        this.tabTargets.forEach(t => t.classList.remove(...this.activeClasses))
        tab.classList.add(...this.activeClasses)
      }
    })
  }
}
```

### Why This Works

- **Forms submit within the frame.** The controller redirects back to the tab path after update. The response includes `settings_content`, so only tab content refreshes while the tab bar stays in place.
- **Validation errors render within the frame.** `render :profile, status: :unprocessable_entity` returns a 422, telling Turbo to replace the frame content with the form showing errors.
- **External links break out.** Links like "Change plan" use `data: { turbo_frame: "_top" }` to navigate the full page.
- **Each tab has its own URL.** Users can bookmark `settings/security` directly. Without JavaScript, the full page renders with the correct tab content.
