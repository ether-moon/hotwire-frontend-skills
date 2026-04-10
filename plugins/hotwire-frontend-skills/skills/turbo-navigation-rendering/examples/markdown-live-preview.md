---
title: "Live Preview Markdown Editor"
---

Markdown editor with live preview using a single Turbo Frame wrapping a form. The textarea submits on input, the server renders markdown to HTML, and the frame re-renders with the preview without a full page reload.

**Patterns combined:** Turbo Frames, `data-turbo-permanent`, server-side rendering

### How It Works

Wrap the form and preview area in a Turbo Frame. On each input event, submit the form via POST. The server converts markdown to HTML (e.g., with `kramdown`) and issues a 303 redirect back to the same route. Turbo replaces the frame content with the updated preview.

### View

```html
<body>
  <h1>Markdown Editor</h1>
  <turbo-frame id="wrapper">
    <form action="/" method="POST">
      <textarea
        name="editor"
        cols="40"
        rows="10"
        data-turbo-permanent
        id="editor"
      ></textarea>
    </form>

    <article id="preview">{content}</article>
  </turbo-frame>
</body>
```

### JavaScript

```js
import '@hotwired/turbo';

document.querySelector('textarea#editor').addEventListener('input', (event) => {
  event.target.closest('form').requestSubmit();
});
```

### Why This Works

- **`data-turbo-permanent` preserves the textarea.** Turbo keeps elements with this attribute intact during frame updates, so the user's cursor position, selection, and focus are maintained while typing.
- **Server-side rendering.** Markdown-to-HTML conversion happens on the server, keeping the client simple and ensuring consistent output.
- **Turbo Frame scopes the update.** Without the frame wrapper, the entire page would reload on form submission, disrupting the editing experience.
- **303 redirect pattern.** The POST handler redirects with 303, which Turbo follows with a GET to re-render the frame. This prevents duplicate submissions on refresh.
