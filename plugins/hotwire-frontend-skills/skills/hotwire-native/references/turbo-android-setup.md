---
title: "Turbo Android Setup"
---

# Turbo Android Setup

## Table of Contents

- [Overview](#overview)
- [Project Setup](#project-setup)
  - [Gradle Dependency](#gradle-dependency)
  - [Minimum SDK Version](#minimum-sdk-version)
  - [Internet Permission](#internet-permission)
- [Implementation](#implementation)
  - [MainActivity Configuration](#mainactivity-configuration)
  - [NavigatorHost Setup](#navigatorhost-setup)
  - [Navigation Graph](#navigation-graph)
  - [WebView Configuration](#webview-configuration)
  - [Custom User Agent](#custom-user-agent)
  - [Handling Back Navigation](#handling-back-navigation)
  - [Deep Link Handling](#deep-link-handling)
- [Pattern Card](#pattern-card)

## Overview

Hotwire Native for Android (`hotwire-native-android`) provides a Kotlin framework that wraps Android's WebView with Turbo-aware navigation using the Jetpack Navigation component. Instead of building screens with Jetpack Compose or XML layouts, the native app loads your Rails web pages inside WebView fragments and uses Turbo's visit lifecycle to drive fragment-based navigation transitions.

The architecture follows Android conventions:
- **HotwireActivity**: A single Activity that hosts a navigation graph of fragments.
- **NavigatorHost**: A NavHostFragment that manages the navigator session and WebView.
- **HotwireWebFragment**: A fragment that displays a web page via Turbo. One per screen in the navigation stack.
- **PathConfiguration**: The same JSON routing rules used on iOS, controlling how each URL is presented (push, modal, replace, native).

Key differences from iOS:
- Android uses a single Activity with fragments, rather than multiple UIViewControllers.
- Navigation is managed by Jetpack Navigation component with a nav graph XML.
- Back navigation uses the Android system back gesture/button and `OnBackPressedDispatcher`.

## Project Setup

### Gradle Dependency

Add the Hotwire Native Android dependencies to your app-level `build.gradle.kts`. The SDK is split into two artifacts:
- `dev.hotwire:core` -- Core Hotwire Native functionality.
- `dev.hotwire:navigation-fragments` -- Fragment-based navigation support.

Also include the Jetpack Navigation dependency.

> Use context7 to fetch the latest official documentation for version-specific API details.

### Minimum SDK Version

Hotwire Native Android requires API level 28 (Android 9.0) or higher:

```kotlin
// app/build.gradle.kts
android {
    defaultConfig {
        minSdk = 28
    }
}
```

### Internet Permission

Add the internet permission to `AndroidManifest.xml`:

```xml
<!-- AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <!-- ... -->
</manifest>
```

## Implementation

### MainActivity Configuration

The main activity hosts the navigation graph and serves as the entry point. It extends `HotwireActivity` which handles session lifecycle and navigation events.

Setup steps:
1. Extend `HotwireActivity` (not `AppCompatActivity` directly).
2. Set the content view with a layout that contains a `NavigatorHost` fragment.
3. Path configuration is loaded globally in the `Application` subclass via `Hotwire.loadPathConfiguration()`, not in the Activity.
4. Fragment destinations and bridge components are also registered in the `Application` subclass.

> Use context7 to fetch the latest official documentation for version-specific API details.

### NavigatorHost Setup

The `NavigatorHost` manages the navigation session and WebView. It replaces the layout XML's fragment container.

Architecture:
1. The activity layout includes a `FragmentContainerView` referencing a `NavigatorHost`.
2. Fragment destinations are registered globally in the `Application.onCreate()` via `Hotwire.registerFragmentDestinations()` -- not as overridden properties.
3. WebView configuration (user agent, JavaScript settings) is done through `Hotwire.config` globally, not by directly accessing `session.webView`.

```xml
<!-- res/layout/activity_main.xml -->
<?xml version="1.0" encoding="utf-8"?>
<androidx.constraintlayout.widget.ConstraintLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <androidx.fragment.app.FragmentContainerView
        android:id="@+id/main_nav_host"
        android:layout_width="0dp"
        android:layout_height="0dp"
        app:layout_constraintTop_toTopOf="parent"
        app:layout_constraintBottom_toBottomOf="parent"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent"
        app:defaultNavHost="true" />

</androidx.constraintlayout.widget.ConstraintLayout>
```

> Use context7 to fetch the latest official documentation for version-specific API details.

### Navigation Graph

Define the navigation graph with fragment destinations. Hotwire Native uses this to map URL patterns to fragments:

```xml
<!-- res/navigation/main_nav_graph.xml -->
<?xml version="1.0" encoding="utf-8"?>
<navigation
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:id="@+id/main_nav_graph"
    app:startDestination="@id/webFragment">

    <!-- Default web view fragment for all URLs -->
    <fragment
        android:id="@+id/webFragment"
        android:name="com.example.myapp.WebFragment"
        android:label="Web">
    </fragment>

    <!-- Modal web view fragment -->
    <fragment
        android:id="@+id/webModalFragment"
        android:name="com.example.myapp.WebModalFragment"
        android:label="Modal">
    </fragment>

    <!-- Native camera fragment -->
    <fragment
        android:id="@+id/nativeCameraFragment"
        android:name="com.example.myapp.NativeCameraFragment"
        android:label="Camera">
    </fragment>

</navigation>
```

Create a web fragment that displays Turbo web pages by extending `HotwireWebFragment` and annotating with `@HotwireDestinationDeepLink` (using the `hotwire://` URI scheme, not `turbo://`).

Key points:
- Use `HotwireWebFragment` as the base class (not `TurboWebFragment`).
- Annotate with `@HotwireDestinationDeepLink(uri = "hotwire://fragment/web")`.
- Override visit completion and error callbacks to handle navigation and error states.

> Use context7 to fetch the latest official documentation for version-specific API details.

### WebView Configuration

Configure the WebView globally through `Hotwire.config` rather than accessing `session.webView` directly. Settings include:
- JavaScript and DOM storage (enabled by default).
- Caching strategy for offline support.
- Mixed content mode for development.
- WebView debugging in development builds.

> Use context7 to fetch the latest official documentation for version-specific API details.

### Custom User Agent

The user agent string must include "Turbo Native" for Rails backend detection. Configure the user agent prefix globally rather than accessing the WebView directly. The library automatically appends Hotwire Native identifiers.

Your Rails backend detects this with:

```ruby
# Returns true when user agent contains "Turbo Native"
turbo_native_app?
```

> Use context7 to fetch the latest official documentation for version-specific API details.

### Handling Back Navigation

Android back navigation integrates with the Jetpack Navigation component. Hotwire Native handles most cases automatically, but you can customize:

Back navigation in `HotwireWebFragment` subclasses:
- Check if the web view has its own back history; if so, go back in the web view.
- Otherwise, pop the fragment from the navigation stack.

For modal fragments using bottom sheet dialog fragments:
- Override back press to dismiss the dialog.

Use `@HotwireDestinationDeepLink` annotations with the `hotwire://` URI scheme (e.g., `hotwire://fragment/web`, `hotwire://fragment/web/modal`).

> Use context7 to fetch the latest official documentation for version-specific API details.

### Deep Link Handling

Configure deep links in `AndroidManifest.xml` to open specific URLs directly in the app:

```xml
<!-- AndroidManifest.xml -->
<activity android:name=".MainActivity">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />

        <data
            android:scheme="https"
            android:host="app.example.com"
            android:pathPrefix="/" />
    </intent-filter>
</activity>
```

Handle the deep link in the Activity:

```kotlin
// MainActivity.kt
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_main)

    // Handle deep link intent
    intent?.data?.let { uri ->
        val location = uri.toString()
        navigator.route(location)
    }
}

override fun onNewIntent(intent: Intent?) {
    super.onNewIntent(intent)
    // Handle deep link when app is already running
    intent?.data?.let { uri ->
        navigator.route(uri.toString())
    }
}
```

## Pattern Card

### GOOD: HotwireActivity With Proper Navigation and Session Config

The correct setup:
1. `Application` subclass registers fragment destinations via `Hotwire.registerFragmentDestinations()`.
2. `Application` subclass loads path configuration via `Hotwire.loadPathConfiguration()`.
3. `HotwireActivity` subclass sets the content view with a `NavigatorHost` layout.
4. Custom user agent is set globally via `Hotwire.config`.

This approach uses `HotwireActivity` with a navigation graph for native transitions, configures path configuration from both local and remote sources, registers typed fragments for web and modal presentations, and sets a custom user agent for Rails detection.

### BAD: Plain WebView Activity Without Turbo

```kotlin
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val webView = WebView(this)
        setContentView(webView)

        webView.settings.javaScriptEnabled = true

        // No Turbo session -- all navigation happens inside a single WebView
        // No path configuration -- cannot present modals or native screens
        // No custom user agent -- Rails cannot detect native app
        // No fragment navigation -- no native back stack
        // No error handling -- network errors show Android's default error page
        webView.loadUrl("https://app.example.com")
    }

    // Back button just calls webView.goBack() with no stack management
    override fun onBackPressed() {
        val webView = findViewById<WebView>(android.R.id.content)
        if (webView.canGoBack()) webView.goBack() else super.onBackPressed()
    }
}
```

This loses all Hotwire Native benefits: no native navigation transitions between pages, no server-driven routing, no modal presentations, no typed fragment registration, and no way for the Rails backend to detect the native app. Every page renders identically in a single WebView with browser-like forward/back behavior instead of native stack navigation.
