---
title: "Bridge Component Cookbook"
---

# Bridge Component Cookbook

## Table of Contents

- [Overview](#overview)
- [1. Share Sheet](#1-share-sheet)
  - [JavaScript: Share Bridge Component](#javascript-share-bridge-component)
  - [Swift: Native Share Handler](#swift-native-share-handler)
  - [Kotlin: Native Share Handler](#kotlin-native-share-handler)
  - [HTML: Share Markup](#html-share-markup)
- [2. Native Menu](#2-native-menu)
  - [JavaScript: Menu Bridge Component](#javascript-menu-bridge-component)
  - [Swift: Native Menu Handler](#swift-native-menu-handler)
  - [Kotlin: Native Menu Handler](#kotlin-native-menu-handler)
  - [HTML: Menu Markup](#html-menu-markup)
- [3. Form Submit Button](#3-form-submit-button)
  - [JavaScript: Form Submit Bridge Component](#javascript-form-submit-bridge-component)
  - [Swift: Native Submit Handler](#swift-native-submit-handler)
  - [Kotlin: Native Submit Handler](#kotlin-native-submit-handler)
  - [HTML: Form Markup](#html-form-markup)
- [4. Native Alert](#4-native-alert)
  - [JavaScript: Alert Bridge Component](#javascript-alert-bridge-component)
  - [Swift: Native Alert Handler](#swift-native-alert-handler)
  - [Kotlin: Native Alert Handler](#kotlin-native-alert-handler)
  - [HTML: Alert Markup](#html-alert-markup)
- [Registration Summary](#registration-summary)

## Overview

This cookbook provides four complete bridge component implementations. Each component follows the same pattern:

1. **JavaScript bridge component** (extends `BridgeComponent` from `@hotwired/hotwire-native-bridge`): Runs in the web view, sends data to native, receives replies.
2. **Swift native handler** (subclasses `BridgeComponent` from `HotwireNative`): Presents iOS-native UI, sends replies back to JavaScript. Access the hosting view controller via the component's delegate.
3. **Kotlin native handler** (subclasses `BridgeComponent<HotwireDestination>` from `dev.hotwire.core`): Presents Android-native UI, sends replies back to JavaScript.
4. **HTML markup**: The ERB template with data attributes that wire everything together.

> Use context7 to fetch the latest official documentation for version-specific API details.

Every component follows the progressive enhancement principle: the web version works without the native shell. When running inside a Hotwire Native app, the native UI replaces or augments the web UI.

---

## 1. Share Sheet

**Purpose**: A web page has content the user can share. In a browser, a standard share link is shown. In the native app, tapping the share button opens the platform's native share sheet (UIActivityViewController on iOS, Intent.ACTION_SEND on Android).

### JavaScript: Share Bridge Component

```javascript
// app/javascript/bridge/share_component.js
import { BridgeComponent, BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "share"
  static targets = ["button"]

  connect() {
    super.connect()

    // Send share data to native on connect
    const shareData = {
      url: this.element.dataset.shareUrl,
      title: this.element.dataset.shareTitle,
      text: this.element.dataset.shareText || ""
    }

    this.send("connect", shareData, () => {
      // Native acknowledged -- hide the web share button
      if (this.hasButtonTarget) {
        this.buttonTarget.hidden = true
      }
    })
  }

  onReceive(message) {
    if (message.event === "shared") {
      // User completed sharing via native sheet
      // Optionally update UI to show "Shared!" confirmation
      if (this.hasButtonTarget) {
        this.buttonTarget.textContent = "Shared!"
        setTimeout(() => {
          this.buttonTarget.textContent = "Share"
        }, 2000)
      }
    }
  }

  // Web fallback: use Web Share API if available, otherwise copy to clipboard
  webShare(event) {
    event.preventDefault()
    const shareData = {
      url: this.element.dataset.shareUrl,
      title: this.element.dataset.shareTitle,
      text: this.element.dataset.shareText || ""
    }

    if (navigator.share) {
      navigator.share(shareData)
    } else {
      navigator.clipboard.writeText(shareData.url)
      this.buttonTarget.textContent = "Link copied!"
      setTimeout(() => {
        this.buttonTarget.textContent = "Share"
      }, 2000)
    }
  }
}
```

### Swift: Native Share Handler

The iOS `ShareComponent` (subclass of `BridgeComponent`) should:
1. Override `class var name` to return `"share"`.
2. On "connect" event: parse URL, title, and text from message data.
3. Add a share `UIBarButtonItem` (SF Symbol: `square.and.arrow.up`) to the navigation bar via the delegate's destination view controller.
4. On tap: present `UIActivityViewController` with share items. Set `popoverPresentationController.barButtonItem` for iPad.
5. After sharing: reply to JavaScript with `"shared"` event.
6. On `onWebViewDidDisappear()`: remove the bar button item.

> Use context7 to fetch the latest official documentation for version-specific API details.

### Kotlin: Native Share Handler

The Android `ShareComponent` (subclass of `BridgeComponent<HotwireDestination>`) should:
1. On "connect" event: deserialize share data (URL, title, text) using `@Serializable` data class.
2. Add a share action to the toolbar menu.
3. On tap: create an `Intent.ACTION_SEND` with the share data and launch via `Intent.createChooser`.
4. Reply to JavaScript with `"shared"` event.

> Use context7 to fetch the latest official documentation for version-specific API details.

### HTML: Share Markup

```erb
<%# app/views/posts/show.html.erb %>
<article>
  <h1><%= @post.title %></h1>
  <%= simple_format(@post.body) %>

  <%# Bridge component: native share sheet in Hotwire Native, web fallback in browser %>
  <div data-controller="bridge--share"
       data-share-url="<%= post_url(@post) %>"
       data-share-title="<%= @post.title %>"
       data-share-text="Check out this post!">

    <%# Web fallback button (hidden when native bridge is active) %>
    <button data-bridge--share-target="button"
            data-action="click->bridge--share#webShare"
            class="btn btn-secondary">
      Share
    </button>
  </div>
</article>
```

---

## 2. Native Menu

**Purpose**: A web page defines a list of actions (edit, delete, archive). In a browser, these are shown as buttons or a dropdown. In the native app, they appear as a native UIMenu (iOS) or overflow menu (Android) on the navigation bar.

### JavaScript: Menu Bridge Component

```javascript
// app/javascript/bridge/menu_component.js
import { BridgeComponent, BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "menu"

  connect() {
    super.connect()

    // Parse menu items from data attribute
    const items = JSON.parse(this.element.dataset.menuItems || "[]")

    this.send("connect", { items }, () => {
      // Native acknowledged -- optionally hide web dropdown
      const webMenu = this.element.querySelector("[data-menu-web]")
      if (webMenu) webMenu.hidden = true
    })
  }

  onReceive(message) {
    if (message.event === "itemSelected") {
      const selectedEvent = message.data?.event
      this.handleMenuSelection(selectedEvent)
    }
  }

  handleMenuSelection(event) {
    switch (event) {
      case "edit":
        const editUrl = this.element.dataset.menuEditUrl
        if (editUrl) Turbo.visit(editUrl)
        break
      case "delete":
        const deleteForm = this.element.querySelector("[data-menu-delete-form]")
        if (deleteForm) deleteForm.requestSubmit()
        break
      case "archive":
        const archiveForm = this.element.querySelector("[data-menu-archive-form]")
        if (archiveForm) archiveForm.requestSubmit()
        break
      case "share":
        // Delegate to share component or use Web Share API
        if (navigator.share) {
          navigator.share({ url: window.location.href })
        }
        break
    }
  }
}
```

### Swift: Native Menu Handler

The iOS `MenuComponent` (subclass of `BridgeComponent`) should:
1. Override `class var name` to return `"menu"`.
2. On "connect" event: parse menu items array from message data (each item has title, icon, event, destructive).
3. Build a `UIMenu` from the items with `UIAction` entries. Use SF Symbols for icons. Mark destructive items.
4. Set the menu on a `UIBarButtonItem` (SF Symbol: `ellipsis.circle`) and assign to navigation bar via the delegate.
5. On menu item selection: reply to JavaScript with `"itemSelected"` event and the selected item's event string.
6. On `onWebViewDidDisappear()`: remove the bar button item.

> Use context7 to fetch the latest official documentation for version-specific API details.

### Kotlin: Native Menu Handler

The Android `MenuComponent` (subclass of `BridgeComponent<HotwireDestination>`) should:
1. On "connect" event: deserialize menu items array with `@Serializable` data classes (`ConnectData` containing `List<MenuItemData>`).
2. Populate the toolbar menu dynamically. Show the first item as `SHOW_AS_ACTION_IF_ROOM`, rest as overflow.
3. On menu item click: reply to JavaScript with `"itemSelected"` event and the selected item's event string.

> Use context7 to fetch the latest official documentation for version-specific API details.

### HTML: Menu Markup

```erb
<%# app/views/posts/show.html.erb %>
<article>
  <h1><%= @post.title %></h1>
  <%= simple_format(@post.body) %>

  <%# Bridge component: native overflow menu in Hotwire Native, web dropdown in browser %>
  <div data-controller="bridge--menu"
       data-menu-items='<%= [
         { title: "Edit", icon: "pencil", event: "edit" },
         { title: "Share", icon: "square.and.arrow.up", event: "share" },
         { title: "Archive", icon: "archivebox", event: "archive" },
         { title: "Delete", icon: "trash", event: "delete", destructive: true }
       ].to_json %>'
       data-menu-edit-url="<%= edit_post_path(@post) %>">

    <%# Web fallback: dropdown menu (hidden when native bridge is active) %>
    <div data-menu-web class="dropdown">
      <button class="btn btn-secondary dropdown-toggle">Actions</button>
      <div class="dropdown-menu">
        <%= link_to "Edit", edit_post_path(@post), class: "dropdown-item" %>
        <button class="dropdown-item" data-action="click->share#open">Share</button>
        <%= button_to "Archive", archive_post_path(@post),
            method: :patch, class: "dropdown-item",
            form: { data: { menu_archive_form: true } } %>
        <%= button_to "Delete", @post, method: :delete,
            class: "dropdown-item text-danger",
            form: { data: { turbo_confirm: "Delete this post?", menu_delete_form: true } } %>
      </div>
    </div>
  </div>
</article>
```

---

## 3. Form Submit Button

**Purpose**: Forms in web views have a submit button at the bottom of the page. In the native app, the submit action moves to a native bar button in the navigation bar, matching the iOS/Android convention for "Save" buttons.

### JavaScript: Form Submit Bridge Component

```javascript
// app/javascript/bridge/form_submit_component.js
import { BridgeComponent, BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "form-submit"
  static targets = ["submit", "form"]

  connect() {
    super.connect()

    const submitTitle = this.submitTarget.value ||
                        this.submitTarget.textContent ||
                        "Submit"

    this.send("connect", { submitTitle }, () => {
      // Native acknowledged -- hide the web submit button
      this.submitTarget.hidden = true
    })
  }

  onReceive(message) {
    if (message.event === "submit") {
      // Native bar button was tapped -- submit the web form
      this.formTarget.requestSubmit()
    }
  }

  // Handle form submission state
  submitStart() {
    // Notify native to show loading state on the bar button
    this.send("submitStart", {})
  }

  submitEnd() {
    // Notify native to restore the bar button
    this.send("submitEnd", {})
  }
}
```

### Swift: Native Submit Handler

The iOS `FormSubmitComponent` (subclass of `BridgeComponent`) should:
1. Override `class var name` to return `"form-submit"`.
2. Handle three events: "connect" (set up bar button), "submitStart" (show loading), "submitEnd" (restore button).
3. On "connect": read `submitTitle` from message data, create a `UIBarButtonItem` with `.done` style, assign to navigation bar.
4. On tap: reply to JavaScript with `"submit"` event, provide haptic feedback via `UIImpactFeedbackGenerator`.
5. Loading state: swap bar button with `UIActivityIndicatorView` wrapped in `UIBarButtonItem(customView:)`.
6. On `onWebViewDidDisappear()`: remove the bar button item.

> Use context7 to fetch the latest official documentation for version-specific API details.

### Kotlin: Native Submit Handler

The Android `FormSubmitComponent` (subclass of `BridgeComponent<HotwireDestination>`) should:
1. Handle three events: "connect" (set up toolbar menu item), "submitStart" (disable and show "Saving..."), "submitEnd" (restore).
2. On "connect": deserialize `submitTitle`, add menu item to toolbar with `SHOW_AS_ACTION_ALWAYS`.
3. On tap: reply to JavaScript with `"submit"` event, provide haptic feedback via `HapticFeedbackConstants.CONFIRM`.
4. Loading/restore state: toggle menu item's `isEnabled` and `title`.

> Use context7 to fetch the latest official documentation for version-specific API details.

### HTML: Form Markup

```erb
<%# app/views/posts/_form.html.erb %>
<%= form_with(
      model: post,
      data: {
        controller: "bridge--form-submit",
        action: "turbo:submit-start->bridge--form-submit#submitStart turbo:submit-end->bridge--form-submit#submitEnd"
      }
    ) do |f| %>

  <div data-bridge--form-submit-target="form">
    <div class="field">
      <%= f.label :title %>
      <%= f.text_field :title, class: "form-control" %>
    </div>

    <div class="field">
      <%= f.label :body %>
      <%= f.text_area :body, class: "form-control", rows: 10 %>
    </div>

    <div class="field">
      <%= f.label :category %>
      <%= f.select :category, Post::CATEGORIES, { prompt: "Select category" }, class: "form-control" %>
    </div>
  </div>

  <%# Web submit button (hidden when native bar button is active) %>
  <div data-bridge--form-submit-target="submit">
    <%= f.submit class: "btn btn-primary mt-3" %>
  </div>
<% end %>
```

---

## 4. Native Alert

**Purpose**: A web page needs to show a confirmation or notification dialog. In a browser, this might use a modal or inline alert. In the native app, it presents a native UIAlertController (iOS) or MaterialAlertDialog (Android).

### JavaScript: Alert Bridge Component

```javascript
// app/javascript/bridge/alert_component.js
import { BridgeComponent, BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "alert"

  connect() {
    super.connect()

    const alertData = {
      title: this.element.dataset.alertTitle || "Alert",
      message: this.element.dataset.alertMessage || "",
      actions: JSON.parse(this.element.dataset.alertActions || '[{"title": "OK", "event": "dismiss"}]')
    }

    this.send("connect", alertData)
  }

  onReceive(message) {
    if (message.event === "actionSelected") {
      const action = message.data?.event
      this.handleAction(action)
    }
  }

  handleAction(action) {
    switch (action) {
      case "confirm":
        // Find and submit the confirmation form
        const confirmForm = this.element.querySelector("[data-alert-confirm-form]")
        if (confirmForm) confirmForm.requestSubmit()
        break
      case "dismiss":
        // Remove the alert element
        this.element.remove()
        break
      case "cancel":
        // Do nothing, dismiss handled by native
        break
    }
  }

  // Web fallback: show a browser confirm dialog
  showWebAlert(event) {
    event.preventDefault()
    const title = this.element.dataset.alertTitle || "Confirm"
    const message = this.element.dataset.alertMessage || "Are you sure?"

    if (confirm(`${title}\n\n${message}`)) {
      this.handleAction("confirm")
    }
  }
}
```

### Swift: Native Alert Handler

The iOS `AlertComponent` (subclass of `BridgeComponent`) should:
1. Override `class var name` to return `"alert"`.
2. On "connect" event: parse title, message, and actions array from message data.
3. Create a `UIAlertController` with `.alert` preferred style.
4. For each action: determine style (`.destructive`, `.cancel`, or `.default`) and add as `UIAlertAction`.
5. On action tap: reply to JavaScript with `"actionSelected"` event and the action's event string.
6. Present the alert on the hosting view controller (accessed via delegate).

> Use context7 to fetch the latest official documentation for version-specific API details.

### Kotlin: Native Alert Handler

The Android `AlertComponent` (subclass of `BridgeComponent<HotwireDestination>`) should:
1. On "connect" event: deserialize alert data (title, message, actions) using `@Serializable` data classes.
2. Build a `MaterialAlertDialogBuilder` with title and message.
3. Map up to 3 actions to positive/negative/neutral buttons (Android AlertDialog limit).
4. On button click: reply to JavaScript with `"actionSelected"` event and the action's event string.

> Use context7 to fetch the latest official documentation for version-specific API details.

### HTML: Alert Markup

```erb
<%# Example 1: Confirmation before destructive action %>
<div data-controller="bridge--alert"
     data-alert-title="Delete Post"
     data-alert-message="This action cannot be undone. Are you sure you want to delete this post?"
     data-alert-actions='<%= [
       { title: "Delete", event: "confirm", destructive: true },
       { title: "Cancel", event: "cancel", style: "cancel" }
     ].to_json %>'>

  <%# Hidden form for the destructive action %>
  <%= button_to "Delete", @post, method: :delete,
      form: { data: { alert_confirm_form: true }, hidden: true } %>

  <%# Web fallback button %>
  <button data-action="click->bridge--alert#showWebAlert"
          class="btn btn-danger">
    Delete Post
  </button>
</div>

<%# Example 2: Success notification after save (auto-dismiss) %>
<% if flash[:notice] %>
  <div data-controller="bridge--alert"
       data-alert-title="Success"
       data-alert-message="<%= flash[:notice] %>"
       data-alert-actions='<%= [{ title: "OK", event: "dismiss" }].to_json %>'>
  </div>
<% end %>

<%# Example 3: Unsaved changes warning %>
<div data-controller="bridge--alert"
     data-alert-title="Unsaved Changes"
     data-alert-message="You have unsaved changes. Do you want to discard them?"
     data-alert-actions='<%= [
       { title: "Discard", event: "confirm", destructive: true },
       { title: "Keep Editing", event: "cancel", style: "cancel" }
     ].to_json %>'>
</div>
```

---

## Registration Summary

Register all bridge components in each platform:

**JavaScript (shared across web and native):**

Bridge components are Stimulus controllers -- register them like any other controller.
With importmap-rails or esbuild autoloading, controllers in `app/javascript/controllers/bridge/`
register automatically via the `bridge--` prefix.

Manual registration:

```javascript
// app/javascript/application.js
import { Application } from "@hotwired/stimulus"
import ShareController from "./controllers/bridge/share_controller"
import MenuController from "./controllers/bridge/menu_controller"
import FormSubmitController from "./controllers/bridge/form_submit_controller"
import AlertController from "./controllers/bridge/alert_controller"

const application = Application.start()
application.register("bridge--share", ShareController)
application.register("bridge--menu", MenuController)
application.register("bridge--form-submit", FormSubmitController)
application.register("bridge--alert", AlertController)
```

**iOS (Swift):**

```swift
// Configure in AppDelegate or SceneDelegate
Hotwire.registerBridgeComponents([
    ShareComponent.self,
    MenuComponent.self,
    FormSubmitComponent.self,
    AlertComponent.self
])
```

**Android (Kotlin):**

```kotlin
// Configure in Application.onCreate()
Hotwire.registerBridgeComponents(
    BridgeComponentFactory("share", ::ShareComponent),
    BridgeComponentFactory("menu", ::MenuComponent),
    BridgeComponentFactory("form-submit", ::FormSubmitComponent),
    BridgeComponentFactory("alert", ::AlertComponent)
)
```
