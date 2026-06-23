# Excel UserForm Oracle Fixtures

This directory is reserved for small, repo-owned Excel/VBA UserForm fixture
inputs.

The first fixture should be stable before it is rich: one UserForm with known
caption, size, startup position, and one rectangle-like Label or Frame with
explicit geometry, color, border, caption, unit, font/theme, and DPI notes.

Current fixtures:

- `rectangle-label/` is the first fixture. It defines one Excel-hosted
  `UserForm` and one empty-caption `MSForms.Label` rectangle from repo-owned
  manifest data.
- `rectangle-label-text/` is the first text-bearing fixture. It keeps the same
  simple UserForm/Label shape but adds caption `OxForms`, explicit regular
  `Tahoma` 8.25 point text, and fixed foreground/alignment settings for W004
  text pixel observation.
- `interaction-events/` is the W005 interaction/event fixture. It creates one
  `UserForm` with a Label, TextBox, default CommandButton, and cancel
  CommandButton, plus repo-owned code-behind that logs representative MSForms
  events for later live oracle capture.
- `text-service-transfer/` is the W006 paste/text-service transfer fixture. It
  logs `BeforeDropOrPaste` and `Change` rows for a public `TextBox.Paste`
  fallback when the desktop blocks deterministic `Ctrl+V` driving.
- `drag-drop-transfer/` is the W006 true OLE drag/drop transfer fixture. It
  creates a repo-owned public `MSForms.DataObject`, starts a drag with
  `DataObject.StartDrag`, and logs `BeforeDragOver`/`BeforeDropOrPaste` rows on
  a target TextBox.
