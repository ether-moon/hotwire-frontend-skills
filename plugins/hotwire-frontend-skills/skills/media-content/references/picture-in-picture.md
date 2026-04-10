---
title: Stimulus - Picture in Picture API
---

## Table of Contents

- [Overview](#overview)
- [Implementation](#implementation)
  - [Stimulus Controller](#stimulus-controller)
  - [HTML Markup](#html-markup)
- [Important Considerations](#important-considerations)
- [Pattern Card: Picture-in-Picture Video](#pattern-card-picture-in-picture-video)


## Overview

The Picture-in-Picture API allows creating floating windows from any `<video>` element. This implementation uses Stimulus with the `useIntersection` mixin from Stimulus Use to automatically trigger Picture-in-Picture mode when a video element scrolls out of the viewport.

**Browser Compatibility:** The standard Picture-in-Picture API (`requestPictureInPicture`) is supported in Chrome 70+, Safari 13.1+, and Edge 79+. Firefox provides its own PiP implementation but does not support the standard API.

## Implementation

The `useIntersection` mixin from Stimulus Use wraps an `IntersectionObserver` (the same mechanism used by Turbo Frames for lazy loading). It provides `appear` and `disappear` callbacks that are invoked when the controller's element enters or leaves the viewport.

### Stimulus Controller

```js
import { Controller } from '@hotwired/stimulus';
import { useIntersection } from 'stimulus-use';

export default class extends Controller {
  static classes = ['hidden'];

  connect() {
    useIntersection(this);
    this.userHasInteracted = false;

    // Track user interaction with the video — PiP requires prior user activation
    this.playHandler = () => { this.userHasInteracted = true; };
    this.element.addEventListener('play', this.playHandler);
  }

  disconnect() {
    this.element.removeEventListener('play', this.playHandler);
  }

  appear() {
    if (document.pictureInPictureElement) {
      document.exitPictureInPicture();
    }
  }

  disappear() {
    // Only auto-enter PiP if the user has previously interacted with the video.
    // requestPictureInPicture() requires user activation and will throw
    // NotAllowedError if called without it (e.g., from an IntersectionObserver callback).
    if (!document.pictureInPictureElement && this.userHasInteracted) {
      this.element.requestPictureInPicture().catch(() => {
        // User activation may have expired — silently fail
      });
    }
  }

  // In production, prefer Stimulus targets over document.querySelector for the indicator element.
  showIndicator() {
    document.querySelector('#indicator').classList.remove(this.hiddenClass);
  }

  hideIndicator() {
    document.querySelector('#indicator').classList.add(this.hiddenClass);
  }
}
```

The controller:
- Initializes `useIntersection` in `connect()` and tracks whether the user has interacted with the video
- Calls `exitPictureInPicture()` in `appear()` when the video scrolls back into view
- Calls `requestPictureInPicture()` in `disappear()` only if the user has previously interacted with the video (required for user activation)
- Catches potential `NotAllowedError` if user activation has expired

### HTML Markup

```html
<body>
  <div id="indicator" class="hidden">
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 512 512"
      fill="currentColor"
    >
      <path
        d="M432 48H208c-17.7 0-32 14.3-32 32V96H128V80c0-44.2 35.8-80 80-80H432c44.2 0 80 35.8 80 80V304c0 44.2-35.8 80-80 80H416V336h16c17.7 0 32-14.3 32-32V80c0-17.7-14.3-32-32-32zM48 448c0 8.8 7.2 16 16 16H320c8.8 0 16-7.2 16-16V256H48V448zM64 128H320c35.3 0 64 28.7 64 64V448c0 35.3-28.7 64-64 64H64c-35.3 0-64-28.7-64-64V192c0-35.3 28.7-64 64-64z"
      />
    </svg>
  </div>
  <div style="overflow-y: scroll">
    <div class="video-wrapper">
      <video
        controls
        loop
        data-controller="pip"
        data-pip-hidden-class="hidden"
        data-action="enterpictureinpicture->pip#showIndicator leavepictureinpicture->pip#hideIndicator"
      >
        <source src="/assets/guitar_string2.mp4" type="video/mp4" />
      </video>
    </div>
    <div class="scroll-container">Keep scrolling ... 👇</div>
  </div>
</body>
```

The video element uses:
- `data-controller="pip"` to attach the controller
- `data-pip-hidden-class="hidden"` to configure the CSS class for the indicator
- `data-action` to listen for `enterpictureinpicture` and `leavepictureinpicture` events

## Important Considerations

The Picture-in-Picture API requires a user interaction with the `<video>` element before it can be requested (a "user trusted event"). This requirement applies each time Picture-in-Picture is closed and reopened. The video must be playing for Picture-in-Picture to work.


## Pattern Card: Picture-in-Picture Video

**When to use**: Keep video playing in a floating window when scrolled out of view.

**GOOD - IntersectionObserver with stimulus-use**:

```html
<video controls data-controller="pip"
       data-action="enterpictureinpicture->pip#showIndicator
                    leavepictureinpicture->pip#hideIndicator">
  <source src="/video.mp4" type="video/mp4">
</video>

<div id="pip-indicator" class="hidden">PiP Active</div>
```

```javascript
import { Controller } from '@hotwired/stimulus';
import { useIntersection } from 'stimulus-use';

export default class extends Controller {
  connect() {
    useIntersection(this);
    this.userHasInteracted = false;
    this.element.addEventListener('play', () => {
      this.userHasInteracted = true;
    });
  }

  appear() {
    if (document.pictureInPictureElement) {
      document.exitPictureInPicture();
    }
  }

  disappear() {
    // Only attempt PiP if the user has interacted with the video —
    // requestPictureInPicture() requires user activation.
    if (!document.pictureInPictureElement && this.userHasInteracted) {
      this.element.requestPictureInPicture().catch(() => {});
    }
  }

  showIndicator() {
    document.querySelector('#pip-indicator').classList.remove('hidden');
  }

  hideIndicator() {
    document.querySelector('#pip-indicator').classList.add('hidden');
  }
}
```

**Note**: Picture-in-Picture requires prior user interaction with the video (user activation). The standard API is not supported in Firefox, which provides its own PiP implementation.
