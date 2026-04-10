---
title: "Stimulus - Managing Markers on a Wavesurfer Element"
---

# Stimulus - Managing Markers on a Wavesurfer Element

> Wrap a third-party library (WaveSurfer) in Stimulus using values as the source of truth and the library's events for DOM sync.

## Decision

- **Stimulus values own the state** -- the WaveSurfer Regions plugin is driven by `markersValue`, not the other way around
- `markersValueChanged` callback diffs previous vs. current arrays to detect additions AND removals in one place
- Library events (`region-created`, `region-removed`) handle DOM list updates -- no manual list management
- This makes state idempotent and compatible with out-of-band updates (Turbo refreshes, WebSockets)
- Timing gotcha: `markersValueChanged` fires before `connect()` on first load -- guard with `if (!this.regions) await new Promise(requestAnimationFrame)`

## Pattern

### Controller skeleton

```javascript
import { Controller } from '@hotwired/stimulus';
// Import WaveSurfer + Regions plugin per WaveSurfer.js docs

export default class extends Controller {
  static targets = ['audio', 'container', 'playButton', 'markerDescription', 'list'];
  static values = {
    markers: { type: Array, default: [] },
    playing: { type: Boolean, default: false },
  };

  connect() {
    // Initialize WaveSurfer instance + Regions plugin
    // Sync play/pause/finish events -> this.playingValue
    // Listen region-created -> insert list item via template
    // Listen region-removed -> remove list item by data-id
  }

  disconnect() { this.wavesurfer.destroy(); }

  playPause() { this.wavesurfer.playPause(); }

  playingValueChanged() {
    this.playButtonTarget.innerHTML = this.playingValue ? 'Pause' : 'Play';
  }
}
```

### Adding markers

```javascript
addMarkerAtCurrentTime() {
  const currentTime = this.wavesurfer.getCurrentTime();
  this.markersValue = [
    ...this.markersValue,
    { time: currentTime, description: this.markerDescriptionTarget.value },
  ];
  this.markerDescriptionTarget.value = '';
}
```

### Removing markers (via action parameter)

```javascript
removeMarker({ params: { time } }) {
  this.markersValue = this.markersValue.filter(
    (marker) => marker.time !== time
  );
}
```

### Value changed callback -- diffing additions and removals

```javascript
async markersValueChanged(markers, previousMarkers) {
  if (!this.regions) {
    await new Promise(requestAnimationFrame);  // Guard: fires before connect()
  }

  const prevTimes = new Set(previousMarkers.map(m => m.time));
  const currTimes = new Set(markers.map(m => m.time));

  markers.filter(m => !prevTimes.has(m.time)).forEach(m => this.#handleAddition(m));
  previousMarkers?.filter(m => !currTimes.has(m.time)).forEach(m => this.#handleRemoval(m));
}

#handleAddition(value) {
  this.regions?.addRegion({ start: value.time, content: value.description });
}

#handleRemoval(value) {
  this.regions?.getRegions()
    .find(region => region.start === value.time)
    ?.remove();
}
```

### DOM sync via library events

```javascript
// In connect():
this.regions.on('region-created', (region) => {
  this.listTarget.insertAdjacentHTML('beforeend',
    `<li data-id="${region.id}">${region.content}
       <button data-action="peaks#removeMarker"
               data-peaks-time-param="${region.start}">Remove</button>
     </li>`
  );
});

this.regions.on('region-removed', (region) => {
  this.listTarget.querySelector(`[data-id="${region.id}"]`).remove();
});
```

### HTML markup

```html
<div data-controller="peaks">
  <div data-peaks-target="container"></div>
  <audio data-peaks-target="audio">
    <source src="/assets/audio.ogg" type="audio/ogg" />
  </audio>

  <button data-action="peaks#playPause" data-peaks-target="playButton">Play</button>

  <input type="text" data-peaks-target="markerDescription" />
  <button data-action="peaks#addMarkerAtCurrentTime">Add Marker</button>

  <ul data-peaks-target="list"></ul>
</div>
```

## Pitfalls

### Mutating the value array in place

```javascript
// BAD -- Stimulus will not detect the change
this.markersValue.push({ time: 1.5 })

// GOOD -- spread into a new array to trigger markersValueChanged
this.markersValue = [...this.markersValue, { time: 1.5 }]
```

### Ignoring the timing gotcha

```javascript
// BAD -- regions is undefined on first load
markersValueChanged() {
  this.regions.addRegion(...)  // TypeError
}

// GOOD -- guard against callback firing before connect()
async markersValueChanged(markers, previousMarkers) {
  if (!this.regions) await new Promise(requestAnimationFrame);
  // ...
}
```

### Managing DOM manually instead of using library events

```javascript
// BAD -- duplicating DOM management logic
#handleAddition(value) {
  this.regions?.addRegion({ start: value.time });
  this.listTarget.insertAdjacentHTML(...)  // Fragile, diverges from library state
}

// GOOD -- let library events handle DOM updates
// addRegion triggers region-created event -> event listener updates the list
```

### Coupling to library internals

Consult WaveSurfer.js docs for current API. Import paths, method names (`addRegion`, `getRegions`, `remove`), and event names may change between versions. Keep library interaction in private methods (`#handleAddition`, `#handleRemoval`) so only those methods need updating.
