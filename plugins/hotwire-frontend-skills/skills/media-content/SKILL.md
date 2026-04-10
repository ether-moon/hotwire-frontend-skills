---
name: media-content
description: >-
  Handles media-heavy Hotwire features: image/video/audio uploads, previews, playback controls,
  progress tracking, galleries, carousels, and third-party integrations (WaveSurfer, Swiper,
  Picture-in-Picture, Blurhash). Use when the core problem is media rendering, playback state,
  audio/video player, file preview, carousel, gallery, waveform display, or media library integration.
  Cross-references: turbo-streams for server-pushed updates, hotwire-forms for upload forms,
  stimulus-controllers for non-media controller patterns.
allowed-tools: Read, Grep, Glob, Task, mcp__context7__resolve-library-id, mcp__context7__query-docs
---

# Media & Rich Content

Implement media-centric Hotwire features with Stimulus and Turbo Frames. This skill covers upload previews, playback controls, progress persistence, and third-party media library integrations.

## Core Workflow

### Step 1: Identify the Media Mode

| Mode | Examples | Key Concern |
|---|---|---|
| Upload/Preview | Image preview before submit, file validation | Blob URL lifecycle |
| Playback controls | Video player, audio waveform, Picture-in-Picture | Browser API integration |
| Progress persistence | Video progress tracker, bookmark position | State serialization |
| Library integration | WaveSurfer, Swiper, Blurhash | Third-party lifecycle |
| Time-synced content | Scrolling lyrics, chaptered video | Frame update timing |

### Step 2: Keep Media State in Stimulus Values

Bridge third-party APIs through value callbacks and targets. The controller owns the state; the library renders it. Declare `static values` for media state (currentTime, playing, volume) and use `valueChanged` callbacks to sync with the player API.

### Step 3: Use Browser-Native APIs First

Prefer native APIs before reaching for libraries:
- `URL.createObjectURL()` for file previews
- Picture-in-Picture API for floating video
- `IntersectionObserver` for lazy media loading
- `MediaSession` API for playback metadata
- Web Share API for sharing media

### Step 4: Clean Up All Resources in disconnect()

Media controllers allocate heavy resources. Every `connect()` must have a matching `disconnect()`:
- Revoke blob URLs after preview rendering
- Destroy third-party player instances
- Disconnect observers
- Clear timers and animation frames

### Step 5: Persist Only Intentional Client State

Save playback progress, marker positions, or user preferences deliberately. Reconcile stored state on reconnection — do not blindly restore stale state.

## Guardrails

1. **Revoke blob URLs after image/file preview rendering.**
   ```javascript
   // GOOD
   const url = URL.createObjectURL(file)
   img.src = url
   img.onload = () => URL.revokeObjectURL(url)

   // BAD — memory leak
   img.src = URL.createObjectURL(file)
   ```

2. **Feature-detect browser APIs (PiP/Web Share/MediaSession).** Hide UI for unsupported APIs.
   ```javascript
   // GOOD: Feature-detect before exposing UI
   connect() {
     this.pipButtonTarget.hidden = !document.pictureInPictureEnabled
   }

   // BAD: Assume API exists
   connect() {
     this.playerTarget.requestPictureInPicture()
   }
   ```

3. **Do not mix transport concerns with rendering.** Media rendering belongs here; stream orchestration belongs in `turbo-streams`.

4. **Keep frame updates incremental for time-based UI** (lyrics, carousels, progress widgets). Do not replace the entire container on each tick.

5. **Clean up third-party library instances in disconnect().** WaveSurfer, Swiper, and similar libraries hold references that must be explicitly destroyed.
   ```javascript
   // GOOD: Destroy on disconnect
   disconnect() {
     this.wavesurfer?.destroy()
     this.wavesurfer = null
   }

   // BAD: No cleanup — memory leak and stale event listeners
   disconnect() {
     // nothing
   }
   ```

## References

| Topic | File |
|---|---|
| Upload previews (blob URLs) | `references/image-upload-previews.md` |
| Progressive loading (Blurhash) | `references/progressive-image-loading-blurhash.md` |
| Picture-in-Picture | `references/picture-in-picture.md` |
| Video progress persistence | `references/video-progress-tracker.md` |
| WaveSurfer markers | `references/wavesurfer-markers.md` |
| Time-synced lyrics | `references/scrolling-lyrics.md` |
| Carousel (Swiper) | `references/swiper-integration.md` |

Full catalog: `references/INDEX.md`.

Out-of-scope requests: route back to `frontend-craft` for triage.
