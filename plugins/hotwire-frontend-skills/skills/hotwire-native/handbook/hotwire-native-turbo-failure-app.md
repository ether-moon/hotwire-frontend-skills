---
title: "TurboFailureApp for Hotwire Native Authentication"
---

# TurboFailureApp for Hotwire Native Authentication

> One-line summary: Override Devise's FailureApp to return 401/422 status codes to native apps instead of 302 redirects.

## Decision (5 lines max)

Standard Devise returns 302 redirects for unauthenticated requests, which confuses native app navigation. TurboFailureApp overrides `http_auth?` to return proper HTTP status codes (401 for "not authenticated", 422 for "login failed") when the request comes from a Hotwire Native app. Form submissions are exempted via a `hotwire_native_form` hidden field so they follow normal redirect flow. Web browser behavior is unchanged.

## Architecture

```
Mobile App Request
        |
   Authentication Required?
        |              |
      YES             NO
        |              |
  TurboFailureApp   Continue
        |
  hotwire_native_app?
        |       |
       YES     NO
        |       |
   Return 401  Return 302
```

### Response Code Mapping

| Scenario | Web Response | Mobile Response |
|----------|-------------|-----------------|
| Not authenticated | `302 -> /login` | `401 Unauthorized` |
| Login failed | `302 -> /login` | `422 Unprocessable Entity` |
| Session expired | `302 -> /login` | `401 Unauthorized` |
| Form submission | `302 -> /login` | `302 -> /login` (normal flow) |

## Pattern

### Core TurboFailureApp

```ruby
# config/initializers/devise.rb
class TurboFailureApp < Devise::FailureApp
  class << self
    def helper_method(*methods) end  # Compatibility for Turbo::Native::Navigation
  end

  include Turbo::Native::Navigation

  def http_auth?
    (hotwire_native_app? && !params["hotwire_native_form"]) || super
  end
end
```

### Devise Configuration

```ruby
# config/initializers/devise.rb
Devise.setup do |config|
  config.navigational_formats = ["*/*", :html, :turbo_stream, :json]
  config.responder.error_status = :unprocessable_entity
  config.responder.redirect_status = :see_other

  config.warden do |manager|
    manager.failure_app = TurboFailureApp
  end
end
```

### Login Form With Hidden Field

```erb
<%= form_with(model: resource, as: resource_name, url: session_path(resource_name), data: { turbo: true }) do |f| %>
  <%= hidden_field_tag :hotwire_native_form, "true" if hotwire_native_app? %>
  <div class="field"><%= f.email_field :email, autofocus: true %></div>
  <div class="field"><%= f.password_field :password %></div>
  <%= f.submit "Log in" %>
<% end %>
```

The `hotwire_native_form` param tells TurboFailureApp to use redirect behavior (not 401) for form submission failures, allowing normal Turbo form error handling.

### Custom Sessions Controller

```ruby
class Users::SessionsController < Devise::SessionsController
  # CSRF is kept enabled — native clients send X-CSRF-Token header from meta tag.
  # Only skip for JSON API auth if you use a separate token-based auth flow.
  respond_to :html, :json

  def create
    respond_to do |format|
      format.html { super }
      format.json do
        self.resource = warden.authenticate(auth_options)
        if resource
          sign_in(resource_name, resource)
          render json: { user: { id: resource.id, email: resource.email } }, status: :ok
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end
    end
  end
end
```

### iOS 401 Handling

```swift
func handleResponse(_ response: HTTPURLResponse) {
    switch response.statusCode {
    case 401: presentLoginScreen()
    case 422: showAuthenticationError()
    case 200...299: handleSuccessResponse()
    default: handleError(response.statusCode)
    }
}
```

> Use context7 for version-specific `NavigatorDelegate` error callback details.

### Route Configuration

```ruby
devise_for :users, controllers: {
  sessions: "users/sessions",
  registrations: "users/registrations"
}
```

## Testing

```bash
# Unauthenticated native request -> 401
curl -H "User-Agent: Turbo Native iOS" -v http://localhost:3000/app/dashboard

# Unauthenticated web request -> 302
curl -H "User-Agent: Mozilla/5.0" -v http://localhost:3000/app/dashboard

# Failed login from mobile -> 422
curl -X POST -H "User-Agent: Turbo Native iOS" -H "Accept: application/json" \
     -d '{"user":{"email":"test@example.com","password":"wrong"}}' \
     -v http://localhost:3000/users/sign_in
```

```ruby
# spec/requests/authentication_spec.rb
RSpec.describe "Authentication", type: :request do
  context "Hotwire Native iOS" do
    let(:headers) { { "User-Agent" => "Turbo Native iOS" } }

    it "returns 401 for unauthenticated requests" do
      get "/app/dashboard", headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "web browser" do
    it "redirects to login page" do
      get "/app/dashboard", headers: { "User-Agent" => "Mozilla/5.0" }
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
```

## Pitfalls

**GOOD: `hotwire_native_form` hidden field on login form**
Form submissions get redirect behavior. TurboFailureApp returns 401 only for page visits.

**BAD: No `hotwire_native_form` param**
Login form submissions return 401 instead of processing. User cannot sign in.

---

**GOOD: `respond_to :html, :json` on controllers**
Mobile requests with `Accept: application/json` get JSON error responses.

**BAD: No JSON responder**
HTML returned instead of JSON for mobile error responses.

---

**GOOD: `Turbo::Native::Navigation` included in TurboFailureApp**
`hotwire_native_app?` helper works correctly for User-Agent detection.

**BAD: Custom User-Agent check that doesn't match SDK string**
Detection fails. Mobile app gets 302 redirects like a browser.

---

**GOOD: `skip_before_action :verify_authenticity_token` for session create**
Native app can submit login without CSRF token.

**BAD: CSRF required for all requests**
`ActionController::InvalidAuthenticityToken` on every native login attempt.
