# Rendering Native Screens with SwiftUI in Hotwire Native
## UIHostingController, Path Configuration Routing, and MVVM Data Flow

---

## When to Go Native vs. Keep Web Views

### Go Native When

| Scenario | Why Native Wins |
|----------|----------------|
| Home screen / launch screen | Launch quickly with highest fidelity; cache data for offline access |
| Maps with gestures | Swiping, pinching, panning work as expected with native MapKit |
| Platform API integration | HealthKit, ARKit, CoreML flow directly from API to Swift |
| Tabbed content screens | 37signals uses native screens for each tab in Basecamp |

### Keep Using Web Views When

| Scenario | Why Web Wins |
|----------|-------------|
| Settings and preferences | Change frequently; web updates avoid native + API changes |
| Checkout flows | Adding fields requires no app store release |
| CRUD operations | Not unique to product experience; time better spent on native workflows |
| Dynamic heterogeneous content | Mixed item types require each type as its own native view |

**Rule of thumb:** SwiftUI updates often require changes to both the view and the server API. Each API change needs backward compatibility with all previous app versions. Web changes avoid this entirely.

---

## Architecture Overview

Five components for a SwiftUI native screen:

1. **SwiftUI View** -- Renders the native UI
2. **UIHostingController** -- Bridges SwiftUI into UIKit for Hotwire Native routing
3. **Path Configuration** -- Server-driven JSON rule mapping URLs to native screens
4. **Rails JSON Endpoint** -- Serves structured data via Jbuilder
5. **Model + ViewModel** -- MVVM data flow

| MVVM Component | Rails Equivalent | Responsibility |
|----------------|-----------------|----------------|
| Model | Rails model | Data objects (`Decodable` structs) |
| View | Rails view | Renders content (SwiftUI) |
| ViewModel | Rails controller | Coordinates data flow between model and view |

---

## SwiftUI View

```swift
// App/Views/MapView.swift
import MapKit
import SwiftUI

struct MapView: View {
    var viewModel: HikeViewModel

    var body: some View {
        Map {
            if let hike = viewModel.hike {
                Marker(hike.name, coordinate: hike.coordinate)
            }
        }
        .mapStyle(.hybrid(elevation: .realistic))
        .navigationTitle("Map")
        .clipped()
        .task { await viewModel.fetchCoordinates() }
    }
}
```

- `.task {}` runs async code when the view loads (triggers network request)
- `.clipped()` prevents the map from bleeding into navigation/tab bar
- `if let` safely unwraps optional `hike` so the marker renders only after data arrives

---

## UIHostingController Bridge

Bridges SwiftUI into UIKit so Hotwire Native can route to it.

```swift
// App/Controllers/MapController.swift
import SwiftUI
import UIKit

class MapController: UIHostingController<MapView> {
    convenience init(url: URL) {
        let viewModel = HikeViewModel(url: url)
        let view = MapView(viewModel: viewModel)
        self.init(rootView: view)
    }
}
```

- `UIHostingController<MapView>` is typed to render a specific SwiftUI view
- `convenience init(url:)` accepts the URL from the Hotwire Native proposal, creates the view model and view, then delegates to the designated initializer

---

## Path Configuration Routing

Server-served JSON that tells the native client how to present each URL.

```ruby
# app/controllers/configurations_controller.rb
class ConfigurationsController < ApplicationController
  def ios_v1
    render json: {
      settings: {},
      rules: [
        { patterns: ["/new$", "/edit$"],
          properties: { context: "modal" } },
        { patterns: ["/hikes/[0-9]+/map"],
          properties: { view_controller: "map" } }
      ]
    }
  end
end
```

The `view_controller` property is exposed through the `NavigatorDelegate` when the user taps a matching link.

For full path configuration details, see `references/path-configuration.md`.

---

## NavigatorDelegate and ProposalResult

Called every time the user taps a link. Returns a `ProposalResult`:

| Case | Behavior |
|------|----------|
| `.accept` | Route a standard `VisitableViewController` (web view) |
| `.acceptCustom(UIViewController)` | Route a custom view controller (native screen) |
| `.reject` | Cancel the navigation; no screen change |

### Implementation

1. Create a `SceneDelegate` conforming to `NavigatorDelegate`
2. Read `view_controller` property from the visit proposal
3. For `"map"`, return `.acceptCustom` with `MapController(url: proposal.url)`
4. For all other cases, return `.accept` for standard web view

Key details:
- Tab bar controller must use `lazy var` (not `let`) because it references `self` as the delegate
- The proposal's URL is passed to `MapController` for data fetching
- Add additional cases for more native screens

> API details for `NavigatorDelegate`, `VisitProposal`, and `ProposalResult` vary by version. Use context7 for version-specific docs.

For native navigation patterns including tabs, modals, and deep links, see `references/native-navigation.md`.

---

## Rails JSON Endpoint with Jbuilder

```ruby
# app/views/maps/show.json.jbuilder
json.extract! @hike, :name, :latitude, :longitude
```

Produces: `{ "name": "Crystal Springs", "latitude": 45.479588, "longitude": -122.635317 }`

The view model appends `.json` to the web URL (e.g., `/hikes/1/map.json`), so the same controller action serves both HTML and JSON via Rails content negotiation.

---

## Model with Decodable

```swift
// App/Models/Hike.swift
import MapKit

struct Hike: Decodable {
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
```

`Decodable` lets `JSONDecoder` parse JSON directly into a `Hike` instance -- no manual key mapping needed when property names match JSON keys.

---

## ViewModel with @Observable

```swift
// App/ViewModels/HikeViewModel.swift
import Foundation

@Observable class HikeViewModel {
    var hike: Hike?
    private let url: URL

    init(url: URL) {
        self.url = url.appendingPathExtension("json")
    }

    func fetchCoordinates() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            hike = try JSONDecoder().decode(Hike.self, from: data)
        } catch {
            print("Failed to fetch hike: \(error.localizedDescription)")
        }
    }
}
```

- `@Observable` binds properties to SwiftUI. When `hike` is set, `MapView` redraws automatically. Requires iOS 17+ (use `ObservableObject` + `@Published` for older versions).
- `.appendingPathExtension("json")` converts `/hikes/1/map` to `/hikes/1/map.json`

---

## Complete Data Flow

```
1. User taps /hikes/42/map
2. Path config matches "/hikes/[0-9]+/map" -> view_controller = "map"
3. NavigatorDelegate returns .acceptCustom(MapController(url:))
4. MapController creates HikeViewModel (appends .json)
5. MapView.task {} calls viewModel.fetchCoordinates()
6. HikeViewModel fetches /hikes/42/map.json -> Rails serves Jbuilder JSON
7. JSONDecoder parses into Hike model -> viewModel.hike set
8. @Observable triggers SwiftUI redraw -> Map renders with Marker
```

### File Structure

```
ios/App/
  Controllers/MapController.swift        # UIHostingController bridge
  Delegates/SceneDelegate.swift          # NavigatorDelegate routing
  Models/Hike.swift                      # Decodable data model
  ViewModels/HikeViewModel.swift         # @Observable data coordinator
  Views/MapView.swift                    # SwiftUI map view

rails/app/
  controllers/configurations_controller.rb  # Path config with view_controller rule
  views/maps/show.json.jbuilder             # JSON endpoint for native screens
```

### Adding More Native Screens

Repeat the pattern: SwiftUI view, `UIHostingController` subclass with `convenience init(url:)`, path config rule with `view_controller`, `NavigatorDelegate` case, Jbuilder endpoint, `Decodable` model + `@Observable` view model.
