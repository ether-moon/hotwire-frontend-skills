---
title: "Bridge Components"
---

# Bridge Components

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
  - [Message Flow](#message-flow)
  - [Message Format](#message-format)
- [Implementation](#implementation)
  - [JavaScript Side: BridgeComponent Base Class](#javascript-side-bridgecomponent-base-class)
  - [Registering JavaScript Components](#registering-javascript-components)
  - [iOS Side: BridgeComponent Protocol](#ios-side-bridgecomponent-protocol)
  - [Registering iOS Components](#registering-ios-components)
  - [Android Side: BridgeComponent Class](#android-side-bridgecomponent-class)
  - [Registering Android Components](#registering-android-components)
  - [Platform Detection](#platform-detection)
  - [Lifecycle Management](#lifecycle-management)
- [Pattern Card](#pattern-card)

## Overview

Bridge components provide two-way communication between your web application's JavaScript and the native Swift (iOS) or Kotlin (Android) code. They are built into Hotwire Native and require no additional dependencies beyond the web bridge library. Bridge components enable web pages to request native UI elements (share sheets, native menus, haptic feedback) and native code to send data back to the web page.

Bridge components follow the principle of progressive enhancement: the web page works fully without the native shell, but when running inside a Hotwire Native app, bridge components enhance the experience with platform-native UI.

Each bridge component has three parts:
1. **JavaScript component**: Runs in the web view. Sends messages to native and receives replies.
2. **iOS component**: Swift class that handles messages and presents native UIKit/SwiftUI UI.
3. **Android component**: Kotlin class that handles messages and presents native Android UI.

The JavaScript component is always the initiator. It declares what it needs (e.g., "show a share sheet with this URL"), and the native side fulfills the request using platform APIs.

## Architecture

### Message Flow

```
Web Page (JavaScript)                    Native App (Swift/Kotlin)
─────────────────────                    ────────────────────────

BridgeComponent                          BridgeComponent
  │                                        │
  ├── send("connect", data) ──────────►  onReceive(message)
  │                                        │
  │                                        ├── Present native UI
  │                                        │
  │  ◄──────────────── reply(message) ──── │
  │                                        │
  ├── onReceive(message)                   │
  │                                        │
```

1. The web page loads and the JavaScript bridge component sends a "connect" message with initial data.
2. The native component receives the message and configures its UI (e.g., adds a native bar button).
3. When the user interacts with the native UI, the native component sends a reply message back to JavaScript.
4. The JavaScript component receives the reply and performs the appropriate web action (e.g., submits a form).

### Message Format

Messages are JSON objects with a consistent structure:

```javascript
{
  "component": "form-submit",   // Component name (matches registration)
  "event": "connect",           // Event name: "connect", "submit", "disconnect", or custom
  "data": {                     // Arbitrary payload
    "title": "Save Changes",
    "submitButtonTitle": "Save"
  }
}
```

Standard events:
- **`connect`**: Sent by JavaScript when the component initializes on the page.
- **`disconnect`**: Sent by JavaScript when the component is removed from the page.
- Custom events (e.g., `submit`, `share`, `menuItemSelected`) are defined per component.

## Implementation

### JavaScript Side: BridgeComponent Base Class

Create JavaScript bridge components by extending the `BridgeComponent` class from `@hotwired/hotwire-native-bridge`:

```javascript
// app/javascript/controllers/bridge/form_submit_controller.js
import { BridgeComponent, BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "form-submit"
  static targets = ["submit"]

  connect() {
    super.connect()

    // Send initial data to native when the component connects
    const submitTitle = this.submitTarget.value || "Submit"
    this.send("connect", { submitTitle }, () => {
      // Callback fired when native acknowledges the message
    })
  }

  // Called when native sends a message back (e.g., user tapped native button)
  onReceive(message) {
    if (message.event === "submit") {
      this.submitTarget.click()
    }
  }
}
```

The `BridgeComponent` class extends Stimulus `Controller`, so it has the same lifecycle hooks (`connect`, `disconnect`), targets, values, and actions.

### Registering JavaScript Components

Bridge components are Stimulus controllers -- register them like any other controller.
With importmap-rails or esbuild autoloading, controllers in `app/javascript/controllers/bridge/`
are discovered automatically via the `bridge--` prefix.

Manual registration (if not using autoloading):

```javascript
// app/javascript/application.js
import { Application } from "@hotwired/stimulus"
import FormSubmitController from "./controllers/bridge/form_submit_controller"
import MenuController from "./controllers/bridge/menu_controller"
import ShareController from "./controllers/bridge/share_controller"
import AlertController from "./controllers/bridge/alert_controller"

const application = Application.start()

application.register("bridge--form-submit", FormSubmitController)
application.register("bridge--menu", MenuController)
application.register("bridge--share", ShareController)
application.register("bridge--alert", AlertController)
```

In your HTML, use bridge components like Stimulus controllers with the `bridge` prefix:

```erb
<%# app/views/posts/_form.html.erb %>
<%= form_with(model: post, data: { controller: "bridge--form-submit" }) do |f| %>
  <div>
    <%= f.label :title %>
    <%= f.text_field :title %>
  </div>

  <div>
    <%= f.label :body %>
    <%= f.text_area :body %>
  </div>

  <%# This button is hidden when running in native app (native bar button replaces it) %>
  <div data-bridge--form-submit-target="submit"
       class="<%= 'hidden' if turbo_native_app? %>">
    <%= f.submit "Save Post" %>
  </div>
<% end %>
```

### iOS Side: BridgeComponent Protocol

Create a native bridge component in Swift by subclassing `BridgeComponent` from `HotwireNative`:

1. Override `class var name: String` to match the JavaScript component name.
2. Override `onReceive(message:)` to handle messages from JavaScript (e.g., "connect" event).
3. Read message data to configure native UI (e.g., add a `UIBarButtonItem` to the navigation bar).
4. Access the hosting view controller through the component's delegate (the exact accessor may vary by version).
5. Send replies back to JavaScript via `reply(to:)` to trigger web actions.

> Use context7 to fetch the latest official documentation for version-specific API details.

### Registering iOS Components

Register native bridge components with Hotwire:

```swift
// AppDelegate.swift
import HotwireNative

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Hotwire.registerBridgeComponents([
            FormSubmitComponent.self,
            MenuComponent.self,
            ShareComponent.self,
            AlertComponent.self
        ])
        return true
    }
}
```

Call this before any web view loads.

### Android Side: BridgeComponent Class

Create the equivalent Kotlin bridge component by subclassing `BridgeComponent` with a generic type parameter (e.g., `BridgeComponent<HotwireDestination>`):

1. The constructor receives a component name and a `BridgeDelegate<HotwireDestination>`.
2. Override `onReceive(message:)` to handle messages (e.g., "connect" event).
3. Deserialize message data using `message.data<T>()` with `@Serializable` data classes.
4. Add native menu items to the toolbar via the delegate's fragment.
5. Send replies back to JavaScript via `replyTo()`.

> Use context7 to fetch the latest official documentation for version-specific API details.

### Registering Android Components

Register bridge components in the `Application.onCreate()` using `Hotwire.registerBridgeComponents()` with `BridgeComponentFactory` objects that pair a component name string with a class reference:

```kotlin
// MyApplication.kt
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Hotwire.registerBridgeComponents(
            BridgeComponentFactory("form-submit", ::FormSubmitComponent),
            BridgeComponentFactory("menu", ::MenuComponent),
            BridgeComponentFactory("share", ::ShareComponent),
            BridgeComponentFactory("alert", ::AlertComponent)
        )
    }
}
```

> Use context7 to fetch the latest official documentation for version-specific API details.

### Platform Detection

Detect whether the page is running inside a Hotwire Native app to conditionally enhance the UI:

**Server-side (Rails):**

```ruby
# Available in controllers and views
turbo_native_app?  # Returns true when user agent contains "Turbo Native"
```

```erb
<%# Conditionally hide web UI that native replaces %>
<div class="<%= 'hidden' if turbo_native_app? %>">
  <button>Share</button>  <%# Web fallback, hidden when native share sheet is available %>
</div>
```

**Client-side (JavaScript):**

```javascript
// Check user agent for Turbo Native
const isNative = navigator.userAgent.includes("Turbo Native")
```

**In bridge components:**

Bridge components only run when the native bridge is present, so you do not need to check. The `connect()` method is only called when the native app is hosting the web view.

### Lifecycle Management

Bridge components follow the Stimulus lifecycle, enhanced with bridge-specific hooks:

```javascript
import { BridgeComponent, BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "my-component"

  connect() {
    super.connect()  // IMPORTANT: Always call super.connect()
    // Component is now active in the web view
    // Send initial data to native
    this.send("connect", { /* initial data */ })
  }

  disconnect() {
    super.disconnect()  // IMPORTANT: Always call super.disconnect()
    // Component is being removed from the web view
    // Native side will receive a "disconnect" event automatically
  }

  onReceive(message) {
    // Handle messages from native
    // This is called on the JavaScript side when native sends a reply
  }
}
```

On the native side, the component lifecycle mirrors the web page:

- `onReceive(message:)` -- Called when JavaScript sends a message.
- `onWebViewDidDisappear()` -- Called when the web view navigates away from the page. Clean up any native UI here (e.g., remove bar button items).

The iOS component accesses the hosting view controller through the delegate.

> Use context7 to fetch the latest official documentation for version-specific API details.

## Pattern Card

### GOOD: Bridge Component With Proper Message Passing

```javascript
// JavaScript: Declares what it needs, sends structured data
import { BridgeComponent, BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "share"

  connect() {
    super.connect()
    this.send("connect", {
      url: this.element.dataset.shareUrl,
      title: this.element.dataset.shareTitle
    })
  }

  onReceive(message) {
    if (message.event === "shared") {
      // Native share completed, update UI
      this.element.textContent = "Shared!"
    }
  }
}
```

The iOS native handler (`BridgeComponent` subclass):
1. On "connect" event: read share URL and title from message data.
2. Add a share `UIBarButtonItem` to the navigation bar (accessed via delegate).
3. On tap: present `UIActivityViewController` with share items.
4. After sharing: reply to JavaScript with a "shared" event.

> Use context7 to fetch the latest official documentation for version-specific API details.

This approach keeps a clean separation: JavaScript declares data, native presents platform UI, and replies flow back through the bridge. The web page works without the native shell (the share button remains visible and functional as a web link).

### BAD: JavaScript Interface Injection Without Bridge Components

```swift
// BAD: Injecting JavaScript interfaces directly into WKWebView
class ViewController: UIViewController, WKScriptMessageHandler {
    func setupWebView() {
        let config = WKWebViewConfiguration()

        // Injecting raw message handlers bypasses the bridge lifecycle
        config.userContentController.add(self, name: "shareHandler")
        config.userContentController.add(self, name: "menuHandler")
        config.userContentController.add(self, name: "cameraHandler")

        let webView = WKWebView(frame: .zero, configuration: config)
    }

    func userContentController(
        _ controller: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // Raw message handling with no structure, no lifecycle management
        if message.name == "shareHandler" {
            let body = message.body as? [String: Any]
            // No reply mechanism -- one-way communication only
            // No disconnect handling -- native UI persists after page navigation
            // No component registration -- no way to know what the page supports
        }
    }
}
```

```javascript
// BAD: Calling webkit message handlers directly
document.querySelector("#share-btn").addEventListener("click", () => {
    // No bridge abstraction -- tightly coupled to WKWebView
    // Breaks on Android (no webkit.messageHandlers)
    // No lifecycle management -- no connect/disconnect
    // No structured message format
    window.webkit.messageHandlers.shareHandler.postMessage({
        url: window.location.href
    })
})
```

This approach bypasses the bridge framework entirely: no structured message format, no lifecycle management, no cross-platform support, no reply mechanism from native to web, and native UI persists after page navigation because there is no disconnect handling. Each platform requires completely different JavaScript code.
