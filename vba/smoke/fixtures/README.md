# VBA Smoke Fixtures

This directory contains fixture inputs and expected diagnostics produced by the
W002 VBA rectangle smoke.

`rectangle_fillrect_smoke.bas` is intentionally procedural. It does not require
`.frm` ingestion, `UserForm.Show`, or an MSForms object model. It creates the
host-injected `OxForms.SmokeCanvas`, calls `CreateSurface`, `FillRect`, and
`Flush`, and the Rust host object records/renders the same `FillRect` display
list as the Rust fixture from `oxforms-dwm.3`.
