---
title: "Native Authentication"
---

# Native Authentication

> One-line summary: Let the web app own authentication via cookies; the native shell detects 401s, persists sessions in Keychain, and optionally adds biometric unlock.

## Decision (5 lines max)

The web view's cookies are the single source of truth for auth state. The native shell never manages its own JWT tokens or calls a separate login API. Keychain (iOS) persists cookies across app launches since the system may clear WKWebView cookies. Biometric auth protects the stored session, not the web login itself. Path configuration presents login screens as modals with `replace_root`.

## Architecture

```
App Launch
    |
    +-- Check Keychain for stored session cookie
    |   |
    |   +-- Found -> Set cookie in WKWebView -> Navigate to home
    |   |                                          |
    |   |                               Cookie valid? Yes -> App ready
    |   |                                            No (401) -> Login
    |   |
    |   +-- Not found -> Navigate to login page
    |
    +-- Login page (web view)
        |
        +-- User submits credentials (standard Rails form)
        +-- Rails sets session cookie
        +-- WKWebView receives cookie
        +-- Native reads cookie, stores in Keychain
        +-- Navigate to home
```

## Pattern

### Cookie Management (iOS)

```swift
class CookieManager {
    static let shared = CookieManager()
    private let cookieStore = WKWebsiteDataStore.default().httpCookieStore

    func getSessionCookies() async -> [HTTPCookie] {
        let cookies = await cookieStore.allCookies()
        return cookies.filter { $0.domain.contains("app.example.com") }
    }
    func setCookie(_ cookie: HTTPCookie) async { await cookieStore.setCookie(cookie) }
    func clearAllCookies() async {
        for cookie in await cookieStore.allCookies() { await cookieStore.deleteCookie(cookie) }
    }
}
```

All WKWebViews must share the default data store (do NOT create `WKWebsiteDataStore.nonPersistent()`).

### Sharing Cookies With Native HTTP Client (iOS)

```swift
class NativeHTTPClient {
    static let shared = NativeHTTPClient()
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        self.session = URLSession(configuration: config)
    }

    func syncCookiesFromWebView() async {
        for cookie in await CookieManager.shared.getSessionCookies() {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }
}
```

### Cookie Sharing (Android)

```kotlin
object CookieSyncHelper {
    private val cookieManager = CookieManager.getInstance()

    fun getSessionCookie(baseUrl: String): String? = cookieManager.getCookie(baseUrl)

    fun addCookiesToRequest(builder: okhttp3.Request.Builder, baseUrl: String): okhttp3.Request.Builder {
        getSessionCookie(baseUrl)?.let { builder.addHeader("Cookie", it) }
        return builder
    }

    fun clearCookies() { cookieManager.removeAllCookies(null); cookieManager.flush() }
}
```

### Keychain Persistence (iOS)

```swift
class KeychainSessionStore {
    static let shared = KeychainSessionStore()
    private let serviceName = "com.example.myapp.session"
    private let accountName = "session_cookie"

    func saveSession(cookies: [HTTPCookie]) { /* Archive to kSecClassGenericPassword */ }
    func restoreSession() -> [HTTPCookie]? { /* Unarchive from Keychain */ }
    func clearSession() { /* SecItemDelete */ }
}
```

Use `kSecAttrAccessibleAfterFirstUnlock` for the accessibility level. Delete existing item before adding to avoid duplicates.

### App Launch Flow With Biometric Unlock

```swift
// SceneDelegate.swift
Task {
    guard let cookies = KeychainSessionStore.shared.restoreSession(), !cookies.isEmpty else {
        navigator.route(baseURL.appending(path: "/login")); return
    }
    let biometricEnabled = UserDefaults.standard.bool(forKey: "biometric_unlock_enabled")
    if biometricEnabled && BiometricAuthManager.shared.isBiometricAvailable {
        guard await BiometricAuthManager.shared.authenticate(reason: "Unlock MyApp") else {
            navigator.route(baseURL.appending(path: "/login")); return
        }
    }
    for cookie in cookies { await CookieManager.shared.setCookie(cookie) }
    navigator.route(baseURL.appending(path: "/"))
}
```

### 401 Detection

Path configuration for login:
```json
{ "patterns": ["/login", "/sign_in", "/users/sign_in"],
  "properties": { "context": "modal", "presentation": "replace_root", "pull_to_refresh_enabled": false } }
```

**iOS**: In `NavigatorDelegate` error callback, check for HTTP 401. On 401: clear Keychain, route to login, store retry handler. After login: save new cookies, retry failed request.

**Android**: In navigator delegate error callback, check for HTTP 401. On 401: navigate to login. For other errors: fall through to default handling.

**Session expiry**: Rails may redirect (not 401) to login. After each page load, inspect the URL -- if it matches a login path, the session expired.

### Background Session Check (iOS)

```swift
// AppDelegate.swift
func applicationDidBecomeActive(_ application: UIApplication) {
    Task {
        await NativeHTTPClient.shared.syncCookiesFromWebView()
        let url = URL(string: "https://app.example.com/api/v1/session/check")!
        if let (_, response) = try? await URLSession.shared.data(for: URLRequest(url: url)),
           let http = response as? HTTPURLResponse, http.statusCode == 401 {
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
        }
    }
}
```

## Pitfalls

**GOOD: Web app's cookie-based session as single source of truth**
Keychain persists cookies. 401 detection redirects to login. After login, cookies saved for next launch. No auth logic duplicated in native code.

**BAD: Separate native auth system with JWT tokens**
Creates a parallel auth system disconnected from the web view. User may be authenticated in native HTTP but see a login page in the web view. Defeats the purpose of Hotwire Native.

---

**GOOD: Biometric protects the Keychain-stored session**
Face ID/Touch ID gates access to the already-authenticated session. Web login is unchanged.

**BAD: Biometric replaces web login**
Bypasses the server's auth entirely. Session state becomes inconsistent.

---

**GOOD: Share default WKWebsiteDataStore across all web views**
Single cookie jar. All web views see the same session.

**BAD: Create `WKWebsiteDataStore.nonPersistent()` per web view**
Isolated cookie jars. Login in one web view is invisible to others.
