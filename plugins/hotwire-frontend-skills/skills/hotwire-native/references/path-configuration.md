---
title: "Path Configuration"
---

# Path Configuration

> A server-hosted JSON file that tells native iOS/Android clients how to present each URL -- push, modal, replace, or hand off to native. Change behavior without app store releases.

## Decision

Path configuration is the **single most important architectural decision** in Hotwire Native. Keep routing logic on the server (JSON), not hardcoded in Swift/Kotlin. This enables: instant behavior changes without app releases, feature flags for native screens, consistent routing across platforms, and graceful degradation (unmatched paths default to web view push). Always provide a local fallback JSON bundled in the app for offline/first-launch.

## Pattern

### JSON Structure

```json
{
  "settings": {
    "tabs": [
      { "title": "Home", "path": "/", "icon": "house" },
      { "title": "Profile", "path": "/profile", "icon": "person" }
    ]
  },
  "rules": [
    {
      "patterns": ["/.*"],
      "properties": {
        "context": "default",
        "presentation": "default",
        "pull_to_refresh_enabled": true
      }
    },
    {
      "patterns": ["/new$", "/edit$"],
      "properties": {
        "context": "modal",
        "presentation": "default",
        "pull_to_refresh_enabled": false
      }
    },
    {
      "patterns": ["/camera"],
      "properties": {
        "view_controller": "native_camera"
      }
    }
  ]
}
```

- **settings**: Global config (tabs, feature flags, min app version) read at startup
- **rules**: Ordered array evaluated top-to-bottom; **last matching rule wins** (properties merge)

### URL Pattern Matching

- Patterns match URL path only (not query string or fragment)
- Standard regex: `^`, `$`, `.*`, character classes
- Multiple patterns in array are OR-matched

### Presentation Styles

| Presentation | Behavior | Use Case |
|---|---|---|
| `default` / `push` | Push onto nav stack | Most pages |
| `pop` | Pop current screen | After form submission |
| `replace` | Replace current screen (no animation) | Tab switches, redirects |
| `replace_root` | Replace entire nav stack | Post-login redirect |
| `clear_all` | Clear all stacks, start fresh | Logout |
| `refresh` | Reload current screen in place | After successful save |
| `none` | Ignore navigation | Anchor links, JS-only actions |

### Context: Default vs Modal

- **`default`**: pushes onto main navigation stack
- **`modal`**: presents in a modal stack on top of main stack

Use `"context": "modal"` (NOT `"presentation": "modal"`). Modal is ideal for multi-step flows (new -> preview -> confirm) that should not pollute main nav history.

### Additional Built-in Properties

| Property | Type | Description |
|---|---|---|
| `animated` | boolean (default: true) | Whether transition is animated |
| `modal_style` | string (iOS only) | `large`, `medium`, `full`, `page_sheet`, `form_sheet` |
| `modal_dismiss_gesture_enabled` | boolean (iOS only) | Swipe-to-dismiss |

### Custom Properties

Add any key-value pairs for native app logic:

```json
{
  "patterns": ["/camera"],
  "properties": {
    "view_controller": "native_camera",
    "requires_authentication": true,
    "title": "Take Photo"
  }
}
```

**iOS**: In `NavigatorDelegate.handle(proposal:from:)`, check `proposal.properties["view_controller"]` and return `.acceptCustom(nativeVC)` or `.accept`.

**Android**: Route decision handling uses the current SDK's routing API.

### Pull-to-Refresh Per Path

Disable on forms (accidental pulls lose data), maps (gesture conflict), and custom scroll views:

```json
{ "patterns": ["/new$", "/edit$", "/maps"], "properties": { "pull_to_refresh_enabled": false } }
```

### Serving From Rails

```ruby
# app/controllers/api/v1/turbo/path_configurations_controller.rb
class Api::V1::Turbo::PathConfigurationsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def show
    render json: { settings: { tabs: [...] }, rules: rules }
  end

  private

  def rules
    [
      { patterns: [".*"],           properties: { context: "default", presentation: "default", pull_to_refresh_enabled: true } },
      { patterns: ["/new$", "/edit$"], properties: { context: "modal", pull_to_refresh_enabled: false } },
      { patterns: ["/camera"],      properties: { view_controller: "native_camera" } }
    ]
  end
end
```

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    namespace :turbo do
      resource :path_configuration, only: :show
    end
  end
end
```

For simpler setups, serve a static file from `public/turbo/path_configuration.json`.

### Loading in Native Apps

**iOS**: Call `Hotwire.loadPathConfiguration(sources:)` in AppDelegate/SceneDelegate with local fallback + remote URL. Applies to all navigators.

**Android**: Call `Hotwire.loadPathConfiguration()` in `Application.onCreate()` with local asset path (`assets/json/path-configuration.json`) + remote URL.

### Caching

Both platforms cache in local storage (iOS: `UserDefaults`, Android: `SharedPreferences`) and refresh in background.

```ruby
# Cache for 5 minutes, then revalidate
expires_in 5.minutes, public: true
render json: path_configuration

# No cache for critical changes (use sparingly)
response.headers["Cache-Control"] = "no-cache, no-store"
render json: path_configuration
```

## Pitfalls

**GOOD**: Server-driven JSON with local fallback -- update routing without app release
**BAD**: Hardcoded URL-to-presentation mapping in Swift/Kotlin -- every route change requires app store release

**GOOD**: `"context": "modal"` for forms and multi-step flows
**BAD**: `"presentation": "modal"` -- modal is a context, not a presentation style

**GOOD**: Rules ordered general-to-specific, last match wins
**BAD**: Specific rules placed before general catch-all -- they get overridden

**GOOD**: `pull_to_refresh_enabled: false` on form/edit pages
**BAD**: Pull-to-refresh on forms -- accidental gesture loses user input
