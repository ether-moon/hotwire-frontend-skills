---
name: hotwire-forms
description: >-
  Handles Hotwire form workflows: form submission lifecycle (422/303), inline editing,
  validation errors, typeahead/autocomplete, modal forms, external form controls,
  autosave, activity indicators, and symmetric submit locking.
  Use when building interactive forms, inline editing, click-to-edit, search, autocomplete,
  form validation errors, or submission UX.
  Cross-references: turbo-streams for real-time validation, stimulus-controllers for complex form behavior,
  turbo-navigation-rendering for frame navigation context.
allowed-tools: Read, Grep, Glob, Task, mcp__context7__resolve-library-id, mcp__context7__query-docs
---

# Hotwire Forms

Implement form-centric Hotwire workflows with Turbo Frames and Stimulus. This skill covers the full form lifecycle: submission, validation, inline edit, typeahead, autosave, activity indicators, and submit UX.

## Core Workflow

### Step 1: Identify the Form Flow

| Requirement | Pattern | Reference |
|---|---|---|
| Click-to-edit content in place | Inline edit with Turbo Frames | `references/turbo-frames-inline-edit.md` |
| Form inside a modal dialog | Modal form with validation | `references/turbo-frames-modal-validation.md` |
| As-you-type search filtering | Typeahead search | `references/turbo-frames-typeahead.md` |
| Typeahead with validation/focus | Typeahead search (validation section) | `references/turbo-frames-typeahead.md` |
| Submit button outside the form | External form controls | `references/turbo-frames-external-forms.md` |
| Standard form create/update | Form submission lifecycle | `references/form-submission-lifecycle.md` |
| Dynamic form behavior from data | Stimulus action parameters | `references/action-parameters-forms.md` |

### Step 2: Wrap the Form in the Appropriate Turbo Frame

Every interactive form pattern needs a Turbo Frame boundary:

- **Inline edit**: Frame wraps both display and edit views.
- **Modal form**: Frame wraps the modal content.
- **Typeahead search**: Frame wraps the results list.
- **Standard form**: Frame wraps the form when other page content should not change.

### Step 3: Handle Response Codes (422 for Errors, 303 for Success)

Turbo requires specific HTTP status codes:

- **Validation failure**: Return `422 Unprocessable Entity` — Turbo re-renders the form with errors.
- **Success**: Return `303 See Other` redirect — Turbo follows the redirect.
- Returning `200` for validation errors **breaks Turbo**.

See `references/form-submission-lifecycle.md` for full controller patterns.

### Step 4: Add Activity Indicators and Submit Locking

- Use `data-turbo-submits-with` for submit button loading states.
- Keep submit locking/unlocking symmetric between `turbo:submit-start` and `turbo:submit-end`.
- Show form activity indicators with a 200ms delay to avoid flash on fast submissions.

```erb
<%# GOOD: Turbo handles button state %>
<%= f.submit "Save", data: { turbo_submits_with: "Saving..." } %>
```

### Step 5: Preserve User Context

- **Focus/caret/selection**: Restore after form rerenders. Do not reset focus to top of form on validation error.
- **Scroll position**: Turbo Frames preserve scroll by default since only frame content changes.
- **Filter state**: Ensure redirects preserve query parameters when form lives alongside filters.
- **Single source of truth**: Avoid duplicate controls across frame and non-frame DOM.

## Guardrails

1. **Let Rails handle CSRF tokens automatically.** Never manually inject tokens.
   ```erb
   <%# GOOD %>
   <%= form_with model: @task do |f| %>
   <% end %>

   <%# BAD %>
   <form action="/tasks" method="post">
     <input type="hidden" name="authenticity_token" value="<%= form_authenticity_token %>">
   </form>
   ```

2. **Use `form_with`, not `form_tag`.** `form_with` generates Turbo-compatible forms by default.

3. **Return `422` for validation errors, `303` for success.** Returning `200` prevents Turbo from re-rendering. See Step 3 above.

4. **Wrap modal forms in their own Turbo Frame.** Match the frame ID to the trigger link's target.

5. **Use `data-turbo-submits-with` for button states.** Do not write custom JavaScript for this.

6. **Prefer `form_with url:` for search forms.** Search forms use GET and do not map to a model.

7. **Keep one source of truth for input state.** Avoid duplicating controls across frame and non-frame DOM.

8. **Use the HTML `form` attribute** for controls rendered outside the target `<form>` hierarchy.

9. **Debounce/throttle keystroke-driven submissions.** Do not fire submit on every keystroke.

10. **Keep submit locking symmetric.** Every lock on `turbo:submit-start` must unlock on `turbo:submit-end`.

Full catalog: `references/INDEX.md`.

Out-of-scope requests: route back to `frontend-craft` for triage.
