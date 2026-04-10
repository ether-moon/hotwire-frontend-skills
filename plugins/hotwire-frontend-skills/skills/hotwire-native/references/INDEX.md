# Hotwire Native References

Build native iOS and Android apps powered by your Rails web application.

## Hotwire Focus

- Hotwire Native iOS (hotwire-native-ios)
- Hotwire Native Android (hotwire-native-android)
- Bridge Components

## Articles

- [Turbo iOS Setup](turbo-ios-setup.md) — Setting up an iOS app with Hotwire Native: Xcode project configuration, Swift Package Manager dependency, Navigator session management, WKWebView configuration with custom user agent, and SceneDelegate initialization.
- [Turbo Android Setup](turbo-android-setup.md) — Setting up an Android app with Hotwire Native: Gradle dependency, HotwireActivity and NavigatorHost configuration, WebView setup with custom user agent, navigation graph, and back navigation handling.
- [Path Configuration](path-configuration.md) — Server-driven routing with JSON path configuration: URL pattern matching, presentation styles (push, modal, pop, replace, none), context management, pull-to-refresh per path, Rails controller endpoint, and caching strategies.
- [Bridge Components](bridge-components.md) — Two-way web-to-native communication: JavaScript BridgeComponent class, Swift and Kotlin native handlers, message format and lifecycle, platform detection, and component registration patterns.
- [Native Navigation](native-navigation.md) — Native navigation patterns for Hotwire Native apps: tab bar navigation with multiple sessions, native screens for platform APIs, bottom sheets and modals, pull-to-refresh, external URL handling, deep links, and navigation bar customization.
- [Native Authentication](native-authentication.md) — Authentication in Hotwire Native apps: cookie-based session management in WKWebView, cookie sharing between web view and native HTTP client, Keychain persistence, login flow with 401 detection, session expiry handling, and biometric authentication integration.
- [Rails Native Backend](rails-native-backend.md) — Rails backend patterns for Hotwire Native: `turbo_native_app?` detection, conditional rendering for native vs web, path configuration endpoint, form submission patterns, native-specific Turbo Stream responses, and app version enforcement.
