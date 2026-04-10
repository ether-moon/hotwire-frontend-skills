---
title: Turbo Drive - Render Interception
---

## Table of Contents

- [Overview](#overview)
- [Pausing Rendering for Animations](#pausing-rendering-for-animations)
- [Custom Render Functions](#custom-render-functions)
  - [Implementation](#implementation)
  - [Example: Image Transition with Navigation Swap](#example-image-transition-with-navigation-swap)
- [Important Considerations](#important-considerations)
- [Pattern Card](#pattern-card)

## Overview

Turbo Drive intercepts regular link clicks and swaps out the HTML `<body>` without doing a full reload of all the JavaScript and CSS. This is called an Application Visit.

After fetching the new content, but before actually rendering, the `turbo:before-render` event is called. This event allows you to:

1. **Pause rendering** to perform custom actions such as animations or page transitions. Call `event.preventDefault()` to pause, then call `event.detail.resume()` when ready to continue.
2. **Replace the render function** entirely by overwriting `event.detail.render` with a custom function that receives the current and new body elements.

The default Turbo Drive rendering process works as follows:

1. Check if the requested page will render (generally true, except for redirects)
2. Replace the body while preserving permanent elements
3. Activate the new body by adopting it into the DOM using `document.adoptNode(newBody)`
4. Render the new body

## Pausing Rendering for Animations

The `turbo:before-render` event handler can be used to add custom animations or perform asynchronous operations before rendering the new page. Call `event.preventDefault()` to pause rendering, then call `event.detail.resume()` when ready to continue.

Example implementation with a custom fly-out animation:

```js
document.addEventListener('turbo:before-render', async (event) => {
  event.preventDefault();

  if (!document.documentElement.hasAttribute('data-turbo-preview')) {
    document.querySelectorAll('svg').forEach((element, index) => {
      element.classList.add('fly-out');
      element.style.animationDelay = `${index * 100}ms`;
    });

    setTimeout(() => {
      event.detail.resume();
    }, 1000);
  } else {
    event.detail.resume();
  }
});
```

## Custom Render Functions

Instead of pausing and resuming the default render, you can replace the rendering logic entirely by overwriting `event.detail.render`. This gives you full control over how the old and new body elements are swapped.

The Turbo guide suggests using [morphdom](https://github.com/patrick-steele-idem/morphdom) as a replacement mechanism, but any custom logic can be implemented. When implementing custom rendering, you are responsible for handling all aspects of the page transition, including edge cases like activating new script elements.

### Implementation

Custom rendering can be implemented using a Stimulus controller attached to the body element:

```html
<body data-controller="image-transition" data-action="turbo:before-render->image-transition#swap">
```

```js
export default class extends Controller {
  swap(event) {
    event.detail.render = (currentBody, newBody) => {
      // rendering logic
    }
  }
}
```

The rendering logic can be parameterized by adding Stimulus values to the controller.

### Example: Image Transition with Navigation Swap

This example demonstrates custom rendering that swaps navigation elements and animates image transitions:

```js
document.addEventListener('turbo:before-render', async (event) => {
  event.detail.render = (currentBody, newBody) => {
    if (!document.documentElement.hasAttribute('data-turbo-preview')) {
      // Adopt the new body into the DOM
      document.adoptNode(newBody);

      // Swap navigation element
      currentBody
        .querySelector('#nav')
        .replaceWith(newBody.querySelector('#nav'));

      // Image transition logic
      const oldImage = currentBody.querySelector('img');
      const newImage = newBody.querySelector('img');
      oldImage.setAttribute('style', 'opacity: 1; z-index: 10;');

      oldImage.insertAdjacentElement('afterend', newImage);

      newImage.addEventListener('load', () => {
        newImage.setAttribute(
          'style',
          'opacity: 0; z-index: 0; filter: invert(100%) blur(16px);'
        );
        gsap.to(oldImage, {
          opacity: 0,
          filter: 'invert(100%) blur(16px)',
          duration: 2,
          ease: 'power2.inOut',
        });
        gsap.to(newImage, {
          opacity: 1,
          filter: 'invert(0%) blur(0px)',
          duration: 2,
          ease: 'power2.inOut',
        });

        setTimeout(() => {
          oldImage.remove();
        }, 2000);
      });
    }
  };
});
```

The image transition process:
1. The old image is given a higher z-index so the new one can go beneath it
2. The new image is inserted into the DOM
3. The new image is initialized with z-index 0, opacity 0, and a CSS filter: `invert(100%) blur(16px)`
4. Two animations are performed: fading in the new image and fading out the old one
5. After the animation completes, the old image is removed

## Important Considerations

- **Cache restoration visits must be handled.** Check for `<html data-turbo-preview>` attribute or opt out of caching altogether. The `turbo:before-render` event still fires on cache restores, which can cause animations to run unexpectedly.
- When implementing custom rendering, you must handle all aspects of page transitions, including script element activation.
- The `morphdom` library can be used as an alternative rendering mechanism with options like `onElUpdated` and other callbacks.

## Pattern Card

### GOOD: Using turbo:before-render for animations

```javascript
document.addEventListener('turbo:before-render', async (event) => {
  // Skip for cached previews
  if (document.documentElement.hasAttribute('data-turbo-preview')) {
    return;
  }

  event.preventDefault();

  // Animate out
  document.querySelectorAll('.animate-out').forEach((el, i) => {
    el.classList.add('fly-out');
    el.style.animationDelay = `${i * 100}ms`;
  });

  // Wait for animation, then continue
  setTimeout(() => event.detail.resume(), 500);
});
```

### BAD: Not checking for preview/cache

```javascript
// Don't animate on every render including cache restores
document.addEventListener('turbo:before-render', (event) => {
  event.preventDefault();
  animate().then(() => event.detail.resume()); // Runs on back button too!
});
```
