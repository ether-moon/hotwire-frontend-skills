---
title: "Rails Native Backend"
---

# Rails Native Backend

> One-line summary: Use `turbo_native_app?` to conditionally render layouts, serve path configuration, handle form redirects, and enforce app versions -- all from a single set of controllers and templates.

## Decision (5 lines max)

The Rails app controls navigation, layout, and feature availability for native clients. Serve a single HTML page that works in both browser and native shell. Use `turbo_native_app?` to conditionally enhance, never to gate functionality. Native layout strips web-only chrome (nav bar, footer, cookie banners). Path configuration is a JSON endpoint that drives all native routing decisions. Never duplicate the backend with a separate API for native clients.

## Pattern

### User Agent Detection

```ruby
# Available in controllers and views automatically
turbo_native_app?  # => true or false (checks for "Turbo Native" in User-Agent)
```

### Conditional Layout Switching

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  layout :resolve_layout
  private
  def resolve_layout
    turbo_native_app? ? "native" : "application"
  end
end
```

```erb
<%# app/views/layouts/native.html.erb -- no nav bar, no footer, no cookie banner %>
<!DOCTYPE html>
<html>
<head>
  <%= csrf_meta_tags %>
  <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
  <%= javascript_include_tag "application", "data-turbo-track": "reload", defer: true %>
</head>
<body class="native">
  <main><%= yield %></main>
</body>
</html>
```

### Conditional View Elements

```erb
<%# Web buttons hidden in native; bridge component provides native equivalent %>
<div class="<%= 'hidden' if turbo_native_app? %>">
  <%= link_to "Edit", edit_post_path(@post) %>
</div>

<%# Bridge component data (ignored by web browsers, consumed by native app) %>
<div data-controller="bridge--menu"
     data-bridge--menu-items-value='<%= [
       { title: "Edit", icon: "pencil", event: "edit" },
       { title: "Share", icon: "square.and.arrow.up", event: "share" }
     ].to_json %>'>
</div>
```

### Path Configuration Endpoint

```ruby
# app/controllers/api/v1/turbo/path_configurations_controller.rb
class PathConfigurationsController < ApplicationController
  skip_before_action :authenticate_user!, if: -> { defined?(authenticate_user!) }
  skip_before_action :verify_authenticity_token

  def show
    expires_in 5.minutes, public: true
    render json: { settings: settings, rules: rules }
  end

  private

  def settings
    { tabs: [
        { title: "Home", path: "/", icon: "house" },
        { title: "Notifications", path: "/notifications", icon: "bell" },
        { title: "Profile", path: "/profile", icon: "person" }
      ], minimum_app_version: "1.2.0" }
  end

  def rules
    [
      { patterns: [".*"], properties: { context: "default", pull_to_refresh_enabled: true } },
      { patterns: ["/new$", "/edit$"], properties: { context: "modal", pull_to_refresh_enabled: false } },
      { patterns: ["/login", "/sign_in"], properties: { context: "modal", presentation: "replace_root" } },
      { patterns: ["/camera"], properties: { view_controller: "native_camera", presentation: "modal" } },
      { patterns: ["/logout", "/sign_out"], properties: { presentation: "clear_all" } }
    ]
  end
end
```

### Form Patterns: Recede, Refresh, Resume

| Pattern | Behavior | When to Use |
|---------|----------|-------------|
| **Recede** | Pop modal, go back | Creating a new record from a modal |
| **Refresh** | Reload current page | Updating an existing record inline |
| **Resume** | Stay on current page | Multi-step forms, wizard flows |

```ruby
def create
  @post = Current.user.posts.build(post_params)
  if @post.save
    redirect_to posts_path, notice: "Post created!"  # Recede: redirect to list
  else
    render :new, status: :unprocessable_entity
  end
end

def update
  if @post.update(post_params)
    redirect_to @post, notice: "Post updated!"  # Refresh: redirect to same resource
  else
    render :edit, status: :unprocessable_entity
  end
end
```

### Native-Specific Turbo Stream Responses

```ruby
def create
  @post = Current.user.posts.build(post_params)
  if @post.save
    respond_to do |format|
      format.html { redirect_to posts_path }
      format.turbo_stream do
        if turbo_native_app?
          redirect_to posts_path  # Native: dismiss modal
        else
          render turbo_stream: turbo_stream.prepend("posts", partial: "posts/post", locals: { post: @post })
        end
      end
    end
  else
    render :new, status: :unprocessable_entity
  end
end
```

### Flash Messages in Native

```erb
<%# app/views/layouts/native.html.erb %>
<% if flash[:notice] %>
  <div data-controller="bridge--alert"
       data-bridge--alert-title-value="Success"
       data-bridge--alert-message-value="<%= flash[:notice] %>">
  </div>
<% end %>
```

### App Version Enforcement

```ruby
# app/controllers/concerns/native_version_check.rb
module NativeVersionCheck
  extend ActiveSupport::Concern
  MINIMUM_IOS_VERSION = "1.2.0"
  MINIMUM_ANDROID_VERSION = "1.2.0"

  included do
    before_action :check_native_app_version, if: :turbo_native_app?
  end

  private

  def check_native_app_version
    version = request.user_agent.match(/MyApp\/([\d.]+)/)&.[](1)
    return unless version
    minimum = request.user_agent.include?("iOS") ? MINIMUM_IOS_VERSION : MINIMUM_ANDROID_VERSION
    if Gem::Version.new(version) < Gem::Version.new(minimum)
      render "shared/upgrade_required", layout: "native", status: :upgrade_required
    end
  end
end
```

## Pitfalls

**GOOD: Single set of templates for web and native**
Native layout strips chrome. Bridge component data attributes ignored by browsers. Same controllers and routes for both.

**BAD: Separate API with its own controllers, serializers, and JWT auth**
Every feature implemented twice. Bugs fixed in two places. Web and native inevitably drift out of sync.

---

**GOOD: `turbo_native_app?` to conditionally enhance**
Hide web nav in native, show bridge component data. Same page works everywhere.

**BAD: `turbo_native_app?` to gate functionality**
Native-only features unreachable from web. Breaks the shared-template principle.

---

**GOOD: Path config served unauthenticated with 5-minute cache**
Native app can fetch routing rules before login. Reduces server load.

**BAD: Path config behind authentication**
App cannot route to the login screen because it needs to be authenticated to get the path config that tells it where login is.

---

**GOOD: Standard redirects after form submission**
Turbo handles recede/refresh automatically based on redirect target.

**BAD: Custom JSON responses for form success in native**
Bypasses Turbo's navigation. Must manually handle dismissal and reload.
