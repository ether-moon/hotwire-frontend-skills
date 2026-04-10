---
name: hotwire-native
description: >-
  Builds native iOS and Android apps with Hotwire Native: iOS/Android setup,
  path configuration for server-driven routing, bridge components for web-to-native
  communication, native navigation patterns, authentication flows, and Rails backend integration.
  Use when building mobile apps, wrapping a Rails app in a native shell, iOS app, Android app,
  Hotwire Native iOS, Hotwire Native Android, bridge components, or native features.
  Cross-references: turbo-navigation-rendering for web view navigation,
  stimulus-controllers for bridge component JavaScript.
allowed-tools: Read, Grep, Glob, Task, mcp__context7__resolve-library-id, mcp__context7__query-docs
---

# Hotwire Native

Build native mobile apps that wrap an existing Rails web application using server-driven navigation and bridge components for platform-specific UX enhancements.

## Core Workflow

### Step 1: Start Web-First

Ensure the Rails web app works well on a mobile viewport before wrapping it in a native shell:

| Check | Why |
|---|---|
| Responsive layout at 375px width | Native web views render at device width |
| Touch-friendly tap targets (44pt minimum) | No hover states on mobile |
| Fast page loads under 3G throttling | Mobile networks are slower |
| Forms work without JavaScript | Bridge components enhance, not replace |

### Step 2: Set Up the Native Shell

Create the iOS or Android project with the Hotwire Native SDK. The native app is a thin wrapper: a navigation controller hosting a web view.

| Platform | SDK | Reference |
|---|---|---|
| iOS | hotwire-native-ios | `turbo-ios-setup.md` |
| Android | hotwire-native-android | `turbo-android-setup.md` |

### Important: Fetch Latest API Details

The Hotwire Native SDKs (iOS and Android) evolve across versions -- class names, method signatures, and import paths change. When specific API code is needed, use context7 (`resolve-library-id` → `query-docs`) to fetch the latest official documentation. The reference files in this skill describe architectural patterns and workflows but intentionally omit version-dependent implementation details.

### Step 3: Configure Path Configuration for Server-Driven Routing

Path configuration is the central routing mechanism — a JSON file served from your Rails app that tells the native client how to present each URL: push, modal, replace, or native screen.

- Every routing decision lives in path configuration, not hardcoded in native code.
- The Rails server controls navigation behavior, enabling updates without app store releases.

### Step 4: Add Native Screens Only Where Web Views Are Insufficient

| Native Screen Needed | Web View Sufficient |
|---|---|
| Camera/photo picker | Profile pages |
| Push notification settings | Lists and forms |
| Biometric authentication | Search and filters |
| Maps with real-time location | Content detail pages |
| AR/ML features | Settings pages |

### Step 5: Build Bridge Components for Platform-Specific UX

Bridge components provide two-way communication between web JavaScript and native Swift/Kotlin. Use them for UX enhancements: share sheets, native menus, haptic feedback, native action buttons.

- The web page declares what it needs.
- The native side presents the platform-appropriate UI.

## Guardrails

1. **Business logic stays in the web app.** Never duplicate Rails logic in Swift or Kotlin. The native shell is a presentation layer only.

2. **Use path configuration for routing decisions.** Never hardcode URL-to-presentation mappings.
   ```
   GOOD: {"patterns": ["/settings"], "properties": {"context": "modal", "presentation": "default"}}
   BAD:  if url.contains("settings") { presentModally() }
   ```

3. **Bridge components are for UX enhancements only.** They expose platform-native UI for content the web page already owns.

4. **Progressive enhancement — web must work without the native shell.** Use `turbo_native_app?` to conditionally enhance, not gate functionality.
   ```ruby
   # GOOD: Web shows its own button; native hides it
   <div data-bridge-form-submit class="<%= 'hidden' if turbo_native_app? %>">
     <%= f.submit "Save" %>
   </div>

   # BAD: Feature only works in native
   <% if turbo_native_app? %>
     <%# No web fallback %>
   <% end %>
   ```

5. **Share cookies between web views.** All WKWebView/WebView instances must share the same cookie store.

6. **Set a custom user agent including "Turbo Native".** The Rails backend detects this for conditional rendering.

7. **Handle web view failures gracefully.** Show native error screens for network failures, 401 redirects, and page load timeouts. Do not leave the user staring at a blank web view.

8. **Ensure cookies persist across web view instances.** Use a shared `WKProcessPool` (iOS) or shared `CookieManager` (Android) to prevent authentication loss when opening new web views.

## References

| Topic | File |
|---|---|
| iOS setup | `references/turbo-ios-setup.md` |
| Android setup | `references/turbo-android-setup.md` |
| Path configuration (routing) | `references/path-configuration.md` |
| Bridge components | `references/bridge-components.md` |
| Native navigation | `references/native-navigation.md` |
| Authentication / sessions | `references/native-authentication.md` |
| Rails backend integration | `references/rails-native-backend.md` |
| Bridge component cookbook | `examples/bridge-component-cookbook.md` |

Full catalog: `references/INDEX.md`. Official guides: `handbook/INDEX.md`.

Out-of-scope requests: route back to `frontend-craft` for triage.
