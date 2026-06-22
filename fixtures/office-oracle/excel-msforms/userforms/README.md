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
