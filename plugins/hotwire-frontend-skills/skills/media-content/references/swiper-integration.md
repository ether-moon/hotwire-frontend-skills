---
title: Frame-Based Carousel with View Transitions
---

> **Note:** This pattern uses Turbo Frames and the View Transitions API to create carousel behavior without external libraries. It does not use the Swiper.js library.

## Table of Contents

- [Overview](#overview)
- [Autoplay With Turbo Frames](#autoplay-with-turbo-frames)
  - [HTML Structure](#autoplay-html-structure)
  - [Server-Side Implementation](#server-side-implementation)
  - [JavaScript Implementation](#autoplay-javascript)
  - [Key Points: Autoplay](#key-points-autoplay)
- [View Transitions](#view-transitions)
  - [HTML Structure](#view-transitions-html-structure)
  - [CSS View Transitions](#css-view-transitions)
  - [JavaScript Implementation](#view-transitions-javascript)
  - [Key Points: View Transitions](#key-points-view-transitions)


## Overview

Two approaches to swiper/carousel behavior using Turbo and the View Transitions API:

1. **Autoplay with Turbo Frames** -- A Turbo Frame auto-advances slides using `setTimeout` and wraps rendering with `document.startViewTransition` for smooth transitions.
2. **Directional View Transitions with Turbo Drive** -- Full-page navigations with directional (left/right) swipe animations using Turbo Drive's render interception and CSS view transitions.

Both approaches rely on the View Transitions API, but they differ in scope: Turbo Frames for embedded components, Turbo Drive for full-page gallery navigation.

## Autoplay With Turbo Frames

Create an autoplaying image swiper embedded in a Turbo Frame. Unlike full page navigations, Turbo Frame navigations do not automatically trigger view transitions, so `document.startViewTransition` must be used manually.

### HTML Structure

A single Turbo Frame points to a route returning a slide containing an image:

```html
<body>
  <main>
    <turbo-frame id="swiper" src="/slide/1000"></turbo-frame>
  </main>
</body>
```

### Server-Side Implementation

The server returns a slide with a `data-next` attribute indicating the next slide ID. The slide IDs loop through an array:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get '/slide/:id', to: 'slides#show'
end

# app/controllers/slides_controller.rb
class SlidesController < ApplicationController
  SLIDE_IDS = [1000, 1001, 1002, 1011].freeze

  def show
    @current_id = params[:id].to_i
    current_index = SLIDE_IDS.index(@current_id)
    next_index = current_index == SLIDE_IDS.length - 1 ? 0 : current_index + 1
    @next_id = SLIDE_IDS[next_index]
  end
end
```

```erb
<!-- app/views/slides/show.html.erb -->
<turbo-frame id="swiper">
  <article data-next="<%= @next_id %>">
    <img
      src="https://picsum.photos/id/<%= @current_id %>/600/400"
      width="600"
      height="400"
    />
  </article>
</turbo-frame>
```

### JavaScript Implementation

The autoplay feature uses `setTimeout` triggered on `turbo:frame-load`. View transitions are enabled by intercepting `turbo:before-frame-render` and wrapping the render function with `document.startViewTransition`:

```js
import '@hotwired/turbo';
import 'controllers';

Turbo.start();

document
  .querySelector('#swiper')
  .addEventListener('turbo:frame-load', (event) => {
    setTimeout(() => {
      const nextId = event.target.querySelector('article').dataset.next;
      event.target.src = `/slide/${nextId}`;
    }, 5000);
  });

document
  .querySelector('#swiper')
  .addEventListener('turbo:before-frame-render', (event) => {
    if (document.startViewTransition) {
      const originalRender = event.detail.render;
      event.detail.render = (currentElement, newElement) => {
        document.startViewTransition(() =>
          originalRender(currentElement, newElement)
        );
      };
    }
  });
```

### Key Points: Autoplay

1. **Manual view transitions**: Turbo Frames do not trigger automatic view transitions because they are not full page navigations. Use `document.startViewTransition` to manually start a same-document transition.

2. **Render interception**: Store a reference to the original render method from `event.detail.render`, then override it with a function that wraps the original render call in `document.startViewTransition`.

3. **Autoplay mechanism**: Use `turbo:frame-load` to detect when a frame loads, then use `setTimeout` to automatically navigate to the next slide after a delay.

4. **Next slide reference**: The server includes a `data-next` attribute on each slide's article element, allowing the client to determine the next slide ID without additional requests.

## View Transitions

Use Turbo Drive's built-in View Transitions API support to create directional swiper-like animations when navigating through pages.

### HTML Structure

Navigation links use `aria-label` attributes to indicate direction:

```html
<body>
  <main>
    <a href="/page2.html" aria-label="Next">
      <sl-icon-button name="arrow-right" label="Next"></sl-icon-button>
    </a>

    <sl-card>
      <img
        slot="image"
        src="https://picsum.photos/id/1000/600/400"
        width="600"
        height="400"
      />
      <strong>Summit</strong>
      <p>Stand on top of the world</p>
    </sl-card>
  </main>
</body>
```

### CSS View Transitions

Configure a custom view transition named `swiper` for the card element. Define animations for swiping old content out and new content in from left or right. Apply these animations to `::view-transition-old` and `::view-transition-new` based on a `data-direction` attribute on the `html` root element.

### JavaScript Implementation

Use Turbo events to detect navigation direction and apply the appropriate transition:

```js
import '@hotwired/turbo';

document.addEventListener('turbo:click', (event) => {
  window.transitionInitiator = event.target;
});

document.addEventListener('turbo:before-render', (event) => {
  event.preventDefault();

  switch (window.transitionInitiator?.ariaLabel) {
    case 'Previous':
      document.documentElement.dataset.direction = 'prev';
      break;
    case 'Next':
      document.documentElement.dataset.direction = 'next';
      break;
  }

  delete window.transitionInitiator;

  event.detail.resume();
});

document.addEventListener('turbo:load', (event) => {
  delete document.documentElement.dataset.direction;
});
```

### Key Points: View Transitions

1. **Register the transition initiator**: Capture the clicked element in the `turbo:click` event and store it in a temporary variable. The `turbo:before-render` event does not contain a reference to the clicked link.

2. **Apply direction attribute**: In `turbo:before-render`, check the `aria-label` of the stored initiator element and set `data-direction` on the `html` root element. Clean up the temporary variable before resuming rendering.

3. **Clean up after transition**: Remove the `data-direction` attribute in `turbo:load` to prevent it from being cached by Turbo, which would cause incorrect transitions on subsequent navigations.
