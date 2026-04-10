---
title: "Rendering Native Screens with Jetpack Compose"
---

# Rendering Native Screens with Jetpack Compose

> One-line summary: Build Android native screens using HotwireFragment + Compose + MVVM, routed via path configuration URI matching.

## Decision (5 lines max)

Use native Compose screens only when web views cannot access required platform APIs (maps, camera, sensors). Each native screen adds six components versus zero for a web view. The same Rails JSON endpoint serves both iOS and Android. Path configuration drives routing declaratively via `@HotwireDestinationDeepLink` annotations. For the full decision framework, see the iOS SwiftUI handbook.

## Architecture

Six components per native screen (one more than iOS because Compose lives inside XML fragment layouts):

1. **Fragment Layout (XML)** -- `ComposeView` + `AppBarLayout` for toolbar
2. **HotwireFragment subclass** -- Inflates layout, bridges to Compose via `setContent {}`
3. **@Composable function** -- Declarative UI layer
4. **Path Configuration + Fragment Registration** -- Server-driven JSON rule with `uri` property
5. **Rails JSON Endpoint** -- Jbuilder template (shared with iOS)
6. **Model + ViewModel** -- MVVM data fetch with `mutableStateOf`

### MVVM Mapping

| MVVM Component | Rails Equivalent | Android Implementation |
|----------------|-----------------|----------------------|
| Model | Rails model | Kotlin `data class` |
| View | Rails view | `@Composable` function |
| ViewModel | Rails controller | `ViewModel` with `mutableStateOf` |

### Platform Routing Comparison

| Aspect | iOS | Android |
|--------|-----|---------|
| Path config property | `view_controller: "map"` | `uri: "hotwire://fragment/map"` |
| Native-side routing | `NavigatorDelegate` switch | `@HotwireDestinationDeepLink` annotation |
| Screen registration | Implicit via switch | Explicit `Hotwire.registerFragmentDestinations()` |

## Pattern

### 1. Fragment Layout (XML)

Wrap `ComposeView` below an `AppBarLayout` so the toolbar is not covered:

```xml
<!-- res/layout/fragment_map.xml -->
<androidx.constraintlayout.widget.ConstraintLayout
    android:fitsSystemWindows="true" ...>
    <com.google.android.material.appbar.AppBarLayout
        android:id="@+id/app_bar" ...>
        <com.google.android.material.appbar.MaterialToolbar
            android:id="@+id/toolbar" ... />
    </com.google.android.material.appbar.AppBarLayout>
    <androidx.compose.ui.platform.ComposeView
        android:id="@+id/compose_view"
        android:layout_height="0dp"
        app:layout_constraintTop_toBottomOf="@+id/app_bar"
        app:layout_constraintBottom_toBottomOf="parent" ... />
</androidx.constraintlayout.widget.ConstraintLayout>
```

### 2. HotwireFragment + Composable

```kotlin
@HotwireDestinationDeepLink(uri = "hotwire://fragment/map")
class MapFragment : HotwireFragment() {
    private lateinit var viewModel: HikeViewModel

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        viewModel = HikeViewModel(url = "${navigator.location}.json")
        val view = inflater.inflate(R.layout.fragment_map, container, false)
        view.findViewById<ComposeView>(R.id.compose_view).apply {
            setContent { MapView(viewModel = viewModel) }
        }
        return view
    }
}

@Composable
fun MapView(viewModel: HikeViewModel) {
    LaunchedEffect(viewModel) { viewModel.fetchCoordinates() }
    val hike = viewModel.hike.value
    if (hike != null) {
        val cameraPositionState = rememberCameraPositionState {
            position = CameraPosition.fromLatLngZoom(hike.coordinate, 15f)
        }
        GoogleMap(cameraPositionState = cameraPositionState, properties = MapProperties(mapType = MapType.HYBRID)) {
            Marker(state = rememberMarkerState(position = hike.coordinate), title = hike.name)
        }
    }
}
```

### 3. Model + ViewModel

```kotlin
data class Hike(val name: String, val latitude: Double, val longitude: Double) {
    val coordinate: LatLng get() = LatLng(latitude, longitude)
}

class HikeViewModel(private val url: String) : ViewModel() {
    var hike = mutableStateOf<Hike?>(null)
        private set

    suspend fun fetchCoordinates() {
        val data = withContext(Dispatchers.IO) { URL(url).readText() }
        val json = JSONObject(data)
        hike.value = Hike(json.getString("name"), json.getDouble("latitude"), json.getDouble("longitude"))
    }
}
```

### 4. Fragment Registration + Path Configuration

```kotlin
// MyApplication.kt
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Hotwire.loadPathConfiguration(context = this,
            location = PathConfiguration.Location(remoteFileUrl = "$baseURL/configurations/android_v1.json"))
        Hotwire.registerFragmentDestinations(HotwireWebFragment::class, MapFragment::class)
    }
}
```

```ruby
# Path configuration rule (android_v1)
{ patterns: ["/hikes/[0-9]+/map"], properties: { uri: "hotwire://fragment/map", title: "Map" } }
```

### 5. Rails JSON Endpoint (shared with iOS)

```ruby
# app/views/maps/show.json.jbuilder
json.extract! @hike, :name, :latitude, :longitude
```

## End-to-End Flow

```
1. User taps /hikes/42/map
2. Path config matches -> uri = "hotwire://fragment/map"
3. Framework resolves @HotwireDestinationDeepLink -> MapFragment
4. MapFragment.onCreateView() -> HikeViewModel("...42/map.json") -> setContent { MapView }
5. LaunchedEffect fires fetchCoordinates() on Dispatchers.IO
6. Rails returns JSON -> mutableStateOf updates -> Compose recomposes with map
```

### ViewModel Platform Comparison

| Concern | iOS (Swift) | Android (Kotlin) |
|---------|-------------|------------------|
| Reactive binding | `@Observable` | `mutableStateOf()` |
| Async marker | `async` | `suspend` |
| JSON deserialization | `JSONDecoder` + `Decodable` | Manual `JSONObject` |
| Threading | Implicit with `await` | Explicit `withContext(Dispatchers.IO)` |
| View-side trigger | `.task {}` | `LaunchedEffect` |

## Pitfalls

**GOOD: AppBarLayout above ComposeView in ConstraintLayout**
Toolbar is visible with back navigation. ComposeView fills remaining space.

**BAD: ComposeView alone with no AppBarLayout**
Compose paints over the toolbar. Users have no back button.

---

**GOOD: Register every fragment in `Hotwire.registerFragmentDestinations()`**
Framework can resolve all `@HotwireDestinationDeepLink` annotations.

**BAD: Forget to register a new fragment**
Navigation silently falls through to `HotwireWebFragment` showing a web page.

---

**GOOD: `mutableStateOf` for reactive Compose state**
Compose automatically recomposes when value changes.

**BAD: Plain `var` without state wrapper**
Compose never sees the update. UI stays blank after data loads.

---

### Adding More Native Screens

Each new screen follows the same recipe:
1. Layout XML: `AppBarLayout` + `ComposeView`
2. `HotwireFragment` subclass with `@HotwireDestinationDeepLink`
3. `@Composable` function for UI
4. Register fragment in `Application` subclass
5. Add path config rule with matching `uri`
6. Jbuilder endpoint + `data class` + `ViewModel`
