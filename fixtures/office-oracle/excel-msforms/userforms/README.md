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
