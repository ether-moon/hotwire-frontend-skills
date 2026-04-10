---
title: "Turbo iOS Setup"
---

# Turbo iOS Setup

## Table of Contents

- [Overview](#overview)
- [Project Setup](#project-setup)
  - [Swift Package Manager Dependency](#swift-package-manager-dependency)
  - [Minimum Deployment Target](#minimum-deployment-target)
- [Implementation](#implementation)
  - [SceneDelegate Configuration](#scenedelegate-configuration)
  - [Navigator Setup](#navigator-setup)
  - [WKWebView Configuration](#wkwebview-configuration)
  - [Custom User Agent](#custom-user-agent)
  - [Session Management for Multiple Stacks](#session-management-for-multiple-stacks)
  - [Handling Visits and Errors](#handling-visits-and-errors)
- [Pattern Card](#pattern-card)

## Overview

Hotwire Native for iOS (`hotwire-native-ios`) provides a Swift framework that wraps WKWebView with Turbo-aware navigation. Instead of building screens in UIKit or SwiftUI, the native app loads your existing Rails web pages inside a web view and uses Turbo's visit lifecycle to manage navigation transitions natively.

The core component is `Navigator`, which manages a navigation stack of web views. When the user taps a link, Turbo intercepts it, tells the native side to push a new view controller, and the new page loads seamlessly with a native push animation. The result feels like a native app while rendering server-side HTML.

Key concepts:
- **Navigator**: Manages a UINavigationController with web view controllers. Handles push, modal, and replace presentations.
- **Session**: A Turbo session manages a single WKWebView and its visit lifecycle. Each navigation stack gets its own session.
- **PathConfiguration**: A JSON file (served from Rails) that tells the native app how to present each URL pattern.
- **Visit**: A navigation event -- either an "advance" (push) or "replace" (swap current page).

## Project Setup

### Swift Package Manager Dependency

Add the Hotwire Native iOS package to your Xcode project:

1. In Xcode, go to File > Add Package Dependencies.
2. Enter the repository URL: `https://github.com/hotwired/hotwire-native-ios`
3. Select the version rule (e.g., "Up to Next Major Version" from `1.0.0`).
4. Add the `HotwireNative` library to your app target.

Or add it to your `Package.swift` if using a Swift package:

```swift
dependencies: [
    .package(url: "https://github.com/hotwired/hotwire-native-ios", from: "1.0.0")
]
```

### Minimum Deployment Target

Check the hotwire-native-ios repository for the current minimum iOS version requirement. Set the deployment target in your Xcode project or `Package.swift` accordingly.

> Use context7 to fetch the latest official documentation for version-specific API details.

## Implementation

### SceneDelegate Configuration

The `SceneDelegate` is where the app creates its window and starts the first Turbo visit. Remove the Storyboard reference from `Info.plist` and set up the window programmatically.

The SceneDelegate should:
1. Create a `Navigator` instance (the primary navigation manager).
2. Set the window's root view controller to the navigator's root view controller.
3. Load path configuration globally via `Hotwire.loadPathConfiguration(sources:)` (not on individual navigator instances).
4. Route to the initial URL.

> Use context7 to fetch the latest official documentation for version-specific API details.

### Navigator Setup

`Navigator` is the primary interface for Hotwire Native navigation. It manages a `UINavigationController`, handles path configuration rules, and coordinates Turbo sessions.

Setup steps:
1. Create a `Navigator` instance and assign its delegate.
2. Load path configuration globally using `Hotwire.loadPathConfiguration(sources:)` in AppDelegate or SceneDelegate -- path configuration is loaded once for the entire app, not per navigator.
3. Implement `NavigatorDelegate` to handle visit proposals and errors.

The `NavigatorDelegate` protocol provides:
- `handle(proposal:from:) -> ProposalResult` -- Decide how to handle each visit. Return `.accept` for standard web view, `.acceptCustom(controller)` for a native screen, or `.reject` to ignore.
- Error handling methods for network failures, HTTP errors, etc.

> Use context7 to fetch the latest official documentation for version-specific API details.

### WKWebView Configuration

Customize the WKWebView to set up JavaScript bridge support, cookie sharing, and process pool configuration.

```swift
// WebViewConfiguration.swift
import WebKit
import HotwireNative

extension SceneDelegate {
    func configureWebView() {
        // All Hotwire Native web views share this configuration
        let configuration = WKWebViewConfiguration()

        // Share a single process pool across all web views for cookie sharing
        configuration.processPool = WKProcessPool()

        // Enable inline media playback
        configuration.allowsInlineMediaPlayback = true

        // Configure the web view through Hotwire's configuration point
        Hotwire.config.makeCustomWebView = { config in
            let webView = WKWebView(frame: .zero, configuration: config)
            // Disable link previews (3D Touch / long press)
            webView.allowsLinkPreview = false

            #if DEBUG
            // Enable Web Inspector for debugging in development
            if #available(iOS 16.4, *) {
                webView.isInspectable = true
            }
            #endif

            return webView
        }
    }
}
```

### Custom User Agent

The custom user agent string is critical -- it tells your Rails backend that the request is coming from a Hotwire Native app. Rails uses this to conditionally render native-optimized layouts.

Set `Hotwire.config.applicationUserAgentPrefix` in AppDelegate or SceneDelegate before any web view loads. The library automatically appends Hotwire Native identifiers and bridge component information to the user agent string.

Your Rails backend detects this with the built-in helper:

```ruby
# Returns true when user agent contains "Turbo Native"
turbo_native_app?
```

### Session Management for Multiple Stacks

When using a tab bar, each tab needs its own `Navigator` instance with its own session. This prevents navigation state from leaking between tabs.

Pattern:
1. Create a `UITabBarController` subclass.
2. Create one `Navigator` per tab, each with its own delegate.
3. Path configuration is loaded globally via `Hotwire.loadPathConfiguration(sources:)` -- it applies to all navigators.
4. Set each navigator's root view controller as a tab.
5. Route each tab to its initial URL.

> Use context7 to fetch the latest official documentation for version-specific API details.

### Handling Visits and Errors

The `NavigatorDelegate` methods give you fine-grained control over the visit lifecycle:

- **`handle(proposal:from:)`**: Check path configuration properties to decide how to handle each visit. Route to native screens based on `view_controller` custom property. Open external URLs in Safari and return `.reject`. Return `.accept` for standard web view handling.
- **Error handling**: Detect HTTP errors (401, 500, etc.) and network failures. Show native error screens or retry UI.
- **Form submission**: Hook into form submission lifecycle for haptic feedback or post-submission actions.

> Use context7 to fetch the latest official documentation for version-specific API details.

## Pattern Card

### GOOD: Navigator With Proper Session Config and Path Configuration

The correct setup:
1. Create a `Navigator` instance with a `NavigatorDelegate`.
2. Load path configuration globally via `Hotwire.loadPathConfiguration(sources:)` with both a local fallback and a remote server URL.
3. Set a custom user agent prefix via `Hotwire.config.applicationUserAgentPrefix`.
4. Set the navigator's root view controller as the window root.
5. Route to the initial URL.

This approach uses `Navigator` for automatic navigation management, loads path configuration from both a local fallback and a remote server, sets a custom user agent for Rails detection, and delegates native screen decisions to the path configuration JSON.

### BAD: Manual WKWebView Without Turbo Navigation

```swift
class ViewController: UIViewController {
    let webView = WKWebView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(webView)
        webView.frame = view.bounds

        // No Turbo session -- links open in the same web view with no native transitions
        // No path configuration -- every URL renders identically
        // No custom user agent -- Rails cannot detect native app
        // No error handling -- network failures show a blank white screen
        let request = URLRequest(url: URL(string: "https://app.example.com")!)
        webView.load(request)
    }
}
```

This loses all Hotwire Native benefits: no native navigation transitions, no server-driven routing, no error handling, no session management, and no way for the Rails backend to detect the native app. The user sees a website in a frame rather than a native app experience.
