# W005 Visible Input Smoke Capture

Capture id: visible-input-smoke-20260623T035500Z
Bead: oxforms-xvx.11

This capture opens the OxForms W005 probe smoke window, drives public Windows input into it, and records the normalized `UiEvent` and reducer/effect evidence emitted by `crates/oxforms-core/examples/w005_visible_input_smoke.rs`.

## Scope

- Evidence/test infrastructure only; not a final host, runtime, or `UserForm.Show` parity claim.
- The visible path supplements headless reducer tests and future trace/replay; it is not the only verification path.
- Coordinates record both driver-side screen/client injection points and smoke-side normalized `client_pixels` / `form_logical` payloads.
