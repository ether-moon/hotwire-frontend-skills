---
title: "Native Navigation Patterns"
---

# Native Navigation Patterns

> One-line summary: Combine server-driven path configuration with native tab bars, modals, native screens, deep links, and pull-to-refresh for a native-feeling app around web content.

## Decision (5 lines max)

Navigation decisions are server-driven through path configuration JSON. The native app reads it to determine how to present each URL: push, modal, native screen, or open externally. Each tab gets its own `Navigator` (iOS) / `NavigatorHost` (Android) with independent navigation stack and session. Reserve native screens only for features requiring platform APIs (camera, maps, biometrics). Web views handle everything else with native push/pop transitions.

## Pattern

### Tab Bar Navigation

**iOS**: Create `UITabBarController` subclass. One `Navigator` per tab with independent stack and session. Load path configuration globally. Implement `NavigatorDelegate` for visit proposals.

**Android**: `HotwireActivity` subclass with `NavigatorHost` + `BottomNavigationView`. Connect via `NavigationUI.setupWithNavController()`.

```xml
<!-- res/layout/activity_main.xml -->
<LinearLayout android:orientation="vertical" ...>
    <androidx.fragment.app.FragmentContainerView
        android:id="@+id/nav_host_fragment"
        android:name="com.example.myapp.MainSessionNavHostFragment"
        android:layout_height="0dp" android:layout_weight="1"
        app:defaultNavHost="true" />
    <com.google.android.material.bottomnavigation.BottomNavigationView
        android:id="@+id/bottom_navigation"
        app:menu="@menu/bottom_navigation" ... />
</LinearLayout>
```

**Badge counts from server:**
```swift
func updateNotificationBadge(count: Int) {
    notificationsNavigator.rootViewController.tabBarItem.badgeValue = count > 0 ? "\(count)" : nil
}
```

### Native Screens for Platform APIs

Route specific URLs to native controllers via path configuration:

```json
{ "rules": [
    { "patterns": ["/camera"], "properties": { "view_controller": "native_camera", "context": "modal" } },
    { "patterns": ["/maps/.*"], "properties": { "view_controller": "native_map" } },
    { "patterns": ["/settings/notifications"], "properties": { "view_controller": "native_notification_settings" } }
]}
```

**iOS native screen example:**
```swift
class CameraViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Take Photo"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        setupCamera()
    }
    func photoWasCaptured(imageURL: URL) {
        dismiss(animated: true) {
            NotificationCenter.default.post(name: .photoCaptured, object: nil, userInfo: ["url": imageURL])
        }
    }
}
```

**Android**: Fragments use `@HotwireDestinationDeepLink` with `hotwire://` URI scheme. Use `ActivityResultContracts` for platform API access. Pass results back via `savedStateHandle`.

### Modals and Bottom Sheets

```json
{ "rules": [
    { "patterns": ["/new$", "/edit$"], "properties": { "context": "modal" } },
    { "patterns": ["/share$", "/actions$"], "properties": { "context": "modal" } }
]}
```

**iOS**: When `context` is `"modal"`, presented as page sheet by default. Configure via `modal_style` property (`large`, `medium`, `full`, `page_sheet`, `form_sheet`).

**Android**: Bottom sheet dialog fragment with `@HotwireDestinationDeepLink(uri = "hotwire://fragment/web/modal")`. Configure `BottomSheetBehavior` for expanded/draggable state.

### Pull-to-Refresh

Configured per-path in path configuration:

```json
{ "rules": [
    { "patterns": [".*"], "properties": { "pull_to_refresh_enabled": true } },
    { "patterns": ["/new$", "/edit$"], "properties": { "pull_to_refresh_enabled": false } },
    { "patterns": ["/maps"], "properties": { "pull_to_refresh_enabled": false } }
]}
```

Disable on forms (accidental refresh loses input) and interactive content (maps, canvases).

### External URLs

**iOS**: In `NavigatorDelegate.handle(proposal:)` -- check if URL host differs from app's base host. If external, open in Safari via `UIApplication.shared.open()` and return `.reject`. Handle non-HTTP schemes (`mailto:`, `tel:`) via system handler.

**Android**: Check URL host in route decision handler. Launch `Intent.ACTION_VIEW` for external URLs.

### Deep Links

**iOS (Universal Links):**
Handle in `SceneDelegate.scene(_:continue:)`. Extract URL from `NSUserActivity`, route via `navigator.route(url)`.

```ruby
# config/routes.rb
get "/.well-known/apple-app-site-association", to: "well_known#apple_app_site_association"

# Controller
def apple_app_site_association
  render json: { applinks: { apps: [], details: [{ appID: "TEAM_ID.com.example.myapp", paths: ["*"] }] } }
end
```

**Android (App Links):**
```xml
<activity android:name=".MainActivity">
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="app.example.com" />
    </intent-filter>
</activity>
```

```ruby
# Digital Asset Links
def asset_links
  render json: [{ relation: ["delegate_permission/common.handle_all_urls"],
    target: { namespace: "android_app", package_name: "com.example.myapp",
              sha256_cert_fingerprints: [ENV["ANDROID_SHA256_FINGERPRINT"]] } }]
end
```

### Navigation Bar Title

Hotwire Native reads the `<title>` tag automatically. Set via standard Rails:

```erb
<% content_for :title, @post.title %>
<%# In layout: %>
<title><%= content_for(:title) || "My App" %></title>
```

## Pitfalls

**GOOD: One Navigator per tab with independent navigation stack**
Each tab maintains its own back stack and session. Switching tabs preserves state.

**BAD: Single WebView with no native navigation**
No tab bar, no back stack, no modals. Experience indistinguishable from a home screen bookmark.

---

**GOOD: Path configuration drives all routing decisions**
Server controls which URLs are modals, native screens, or standard pushes. Change behavior without app update.

**BAD: Hard-coded URL checks in native code**
Every routing change requires an app store submission.

---

**GOOD: Native screens only for platform APIs (camera, maps, biometrics)**
Minimizes native code. Web views handle everything else.

**BAD: Native screens for content that works fine in a web view**
Double the maintenance for no user benefit.

---

**GOOD: Pull-to-refresh disabled on forms and interactive content**
No accidental data loss or gesture conflicts.

**BAD: Pull-to-refresh enabled everywhere**
User loses form input on accidental swipe. Map panning triggers page reload.
