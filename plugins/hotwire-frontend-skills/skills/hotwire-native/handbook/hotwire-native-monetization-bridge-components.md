---
title: "Monetization Bridge Components"
---

# Monetization Bridge Components

> One-line summary: Use two bridge components (`purchase` for RevenueCat, `rewarded-ad` for AdMob) where Rails renders all UI and native handles all SDK calls.

## Decision (5 lines max)

Rails renders a hidden promo card; the native bridge reveals it for non-subscribers. No JavaScript API requests or token passing -- native SDKs handle everything. Two independent signals form the ad-free state: permanent RevenueCat subscription and temporary 2-hour timer from watching a rewarded ad. The promo card is inert in web browsers (bridge components only activate inside a native shell). This guide covers iOS only; see `references/bridge-components.md` for Android patterns.

## Architecture

```
Rails Partial (hidden)
        |
        v
rewarded-ad controller --connect--> Native: check subscription + timer
        |                                    |
        v                                    v
   [not subscriber]                    [subscriber]
   reveal promo card                   keep hidden
        |
        +-- Subscribe btn --showPaywall--> Native: RevenueCat PaywallVC
        |                                       |
        |                                  reply(success)
        |
        +-- Watch Ad btn --showAd--> Native: AdMob RewardedAd
                                           |
                                      reward earned?
                                      /          \
                                    yes           no
                                     |             |
                              set 2hr timer    reply(fail)
                              post notification
                              reply(success)
```

### Message Flow

| Event | Direction | Component | Payload | Response |
|-------|-----------|-----------|---------|----------|
| `connect` | Web -> Native | `rewarded-ad` | `{ workoutAppId }` | `{ isSubscriber }` |
| `showPaywall` | Web -> Native | `purchase` | `{}` | `{ success, message }` |
| `restorePurchases` | Web -> Native | `purchase` | `{}` | `{ success, message }` |
| `showAd` | Web -> Native | `rewarded-ad` | `{ workoutAppId }` | `{ success, message }` |

## Pattern

### Purchase Bridge Controller (Web)

```javascript
import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "purchase"
  static targets = ["paywallButton", "restoreButton"]

  showPaywall() {
    if (this.hasPaywallButtonTarget) this.paywallButtonTarget.disabled = true
    this.send("showPaywall", {}, (message) => {
      if (this.hasPaywallButtonTarget) this.paywallButtonTarget.disabled = false
    })
  }

  restorePurchases() {
    if (this.hasRestoreButtonTarget) this.restoreButtonTarget.disabled = true
    this.send("restorePurchases", {}, (message) => {
      if (this.hasRestoreButtonTarget) this.restoreButtonTarget.disabled = false
    })
  }
}
```

### Rewarded Ad Bridge Controller (Web)

```javascript
import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "rewarded-ad"
  static targets = ["widget", "adButton", "adButtonText"]
  static values = { workoutAppId: Number }

  connect() {
    super.connect()
    this.send("connect", { workoutAppId: this.workoutAppIdValue }, (message) => {
      if (message.data) {
        this.element.style.display = message.data.isSubscriber ? "none" : "block"
      }
    })
  }

  showAd() {
    if (this.hasAdButtonTarget) this.adButtonTarget.disabled = true
    this.send("showAd", { workoutAppId: this.workoutAppIdValue }, (message) => {
      if (this.hasAdButtonTarget) this.adButtonTarget.disabled = false
    })
  }
}
```

### Promo Card Partial

```erb
<!-- app/views/shared/_ad_free_sales_widget.html.erb -->
<div data-controller="rewarded-ad purchase"
     data-rewarded-ad-workout-app-id-value="<%= workout_app.id %>"
     style="display:none;">

  <h3>Train Ad-Free. Go Premium.</h3>

  <div data-controller="purchase">
    <button data-action="purchase#showPaywall" data-purchase-target="paywallButton">
      Subscribe to Go Ad-Free
    </button>
  </div>

  <button data-action="rewarded-ad#showAd" data-rewarded-ad-target="adButton">
    <span data-rewarded-ad-target="adButtonText">Watch Ad for Free Session</span>
  </button>
</div>
```

Insert into a feed after the first item:

```erb
<% @training_programs.each_with_index do |program, index| %>
  <!-- card markup -->
  <% if index == 0 %>
    <%= render "shared/ad_free_sales_widget", workout_app: @workout_app %>
  <% end %>
<% end %>
```

### Native Side (iOS) -- Implementation Notes

**PurchaseComponent** (subclass of `BridgeComponent`):
1. Component name: `"purchase"`
2. On `"showPaywall"`: present RevenueCat `PaywallViewController` in `UINavigationController`
3. On `"restorePurchases"`: call `Purchases.shared.restorePurchases`, reply success/failure
4. Conform to `PaywallViewControllerDelegate` to reply on purchase completion

**RewardedAdComponent** (subclass of `BridgeComponent`):
1. Component name: `"rewarded-ad"`
2. On `"connect"`: check RevenueCat subscription + `UserDefaults` timer, reply `isSubscriber`, preload ad
3. On `"showAd"`: re-check status, present preloaded `RewardedAd`, set `FullScreenContentDelegate`
4. On reward earned: set 2hr timer, post `.subscriptionStatusChanged` notification, reply success
5. On dismissed without reward: reply failure

### Ad-Free Timer -- Single Source of Truth

```swift
extension UserDefaults {
    private static let rewardedAdFreeUntilKey = "REWARDED_AD_FREE_UNTIL"
    static var rewardedAdFreeUntil: Date? {
        get { standard.object(forKey: rewardedAdFreeUntilKey) as? Date }
        set { standard.setValue(newValue, forKey: rewardedAdFreeUntilKey) }
    }

    var isRemoveAds: Bool {
        if bool(forKey: "REMOVE_ADS") { return true }  // Permanent subscription
        if let expiry = UserDefaults.rewardedAdFreeUntil { return Date() < expiry }  // Temp timer
        return false
    }
}
```

### Notification-Driven UI Updates

```swift
extension Foundation.Notification.Name {
    static let subscriptionStatusChanged = Foundation.Notification.Name("SubscriptionStatusChanged")
}

// Any observer (TabBarController, etc.) reacts immediately -- no page reload
@objc private func subscriptionStatusChanged() {
    if UserDefaults.standard.isRemoveAds { removeBannerAds() }
}
```

### Configuration (xcconfig to Runtime)

Ad unit IDs flow from build config through Info.plist into Swift:

```xcconfig
// Config.xcconfig (base)
DISPLAY_ADS = true
ADMOB_APP_ID = ca-app-pub-XXX~XXX
ADMOB_REWARDED_ID =  // Override per target

// Targets/MyApp.xcconfig
#include "Config.xcconfig"
ADMOB_REWARDED_ID = ca-app-pub-XXX/XXX
```

```swift
struct RuntimeConfiguration {
    struct AdMob {
        static var rewardedAdUnitId: String { Config.shared.adMobRewardedID ?? "" }
    }
}
```

## Pitfalls

**GOOD: Preload ads on `connect`**
Eliminates 2-5 second delay when user taps "Watch Ad".

**BAD: Load ad only when user taps**
User stares at a loading spinner. High abandonment rate.

---

**GOOD: Track earned vs. dismissed with separate delegate callbacks**
Reward granted only if `userDidEarnRewardHandler` fires. Dismissal without earning gets no timer.

**BAD: Grant reward on any ad dismissal**
Users close ads immediately and still get ad-free time.

---

**GOOD: Hidden partial with `display:none`, revealed by bridge component**
Progressive enhancement. Partial is inert in web browsers.

**BAD: Visible promo card that checks subscription via JavaScript API call**
Flashes on screen before hiding for subscribers. Requires API endpoint. Breaks in browsers.
