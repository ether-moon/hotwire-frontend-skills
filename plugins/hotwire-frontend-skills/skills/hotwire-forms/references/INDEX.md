# Hotwire Forms References

Form handling patterns with Turbo Frames and Stimulus.

## Hotwire Focus

- Turbo Frames
- Turbo Form Submissions
- Stimulus (for form behavior)

## Articles

- [Inline Editing](turbo-frames-inline-edit.md) — Click-to-edit pattern using Turbo Frame swaps between display and edit views. Auto-focus, submit-on-blur, and state persistence.
- [Modal Forms with Validation](turbo-frames-modal-validation.md) — Modal dialogs with form validation using Turbo Frames. Native `<dialog>` element with Stimulus, 422/303 response handling, closing on success.
- [Typeahead Search](turbo-frames-typeahead.md) — As-you-type search updating results in a Turbo Frame. Debouncing with Stimulus, loading states, URL parameter preservation for bookmarkable search, validation, and focus/caret preservation during rerenders.
- [External Form Controls](turbo-frames-external-forms.md) — Form elements outside the frame that submit to the frame. The `form` attribute, `data-turbo-frame` targeting, and split-layout form patterns.
- [Form Submission Lifecycle](form-submission-lifecycle.md) — Complete Turbo form submission lifecycle from submit to response rendering. 422 vs 303 status codes, turbo:submit-start/end events, button state management, and activity indicators with render-pause delays.
- [Stimulus Action Parameters in Forms](action-parameters-forms.md) — Passing data from form elements to Stimulus actions via params. Dynamic form behavior, conditional fields, and element-specific actions.
- [Progress Bar for Forms](turbo-drive-progress-bar.md) — Programmatic control of the Turbo Drive progress bar for form submission feedback.

## Examples

- [Inline Edit Form](../examples/inline-edit-form.md) — Click-to-edit table row with blur-to-save, Escape-to-cancel, and Turbo Frame row swap.
- [Modal Form](../examples/modal-form.md) — Modal dialog with form validation, Turbo Stream append on success, and native `<dialog>` element.
- [Multi-Step Wizard](../examples/multi-step-wizard.md) — Multi-step registration wizard with session-based state, per-step validation, and back navigation.
