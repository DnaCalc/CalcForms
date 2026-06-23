# OxForms VBA Smoke Sources

This directory is reserved for procedural or class-based VBA smoke sources and
project fixtures used by W002.

`projects/rectangle_app/RectangleSmokeApp.basproj` is the W002 app fixture. It
references `vba/oxforms/OxForms.basproj`, creates an OxForms smoke form
through the library, and does not directly create the PAL canvas. The OxForms
library owns the smoke-only `CreateObject("OxForms.SmokeCanvas")` bridge to the
Rust PAL; the Rust harness registers that ProgID, the library calls
`CreateSurface`, `FillRect`, and `Flush`, and `Flush` invokes the OxForms PAL
headless renderer.

Targeted command:

```powershell
cargo test -p oxforms-oxvba-adapter --test oxvba_rectangle_smoke -- --nocapture
```

The smoke API in this directory is temporary proof plumbing. It is not the final
MSForms compatibility surface.

`fixtures/w005_probe_event_source.cls` and
`fixtures/w005_probe_event_harness.cls` are W005 event-dispatch smoke fixtures.
They prove reducer event effects can reach VBA handler code through OxVba
`RaiseEvent`/`WithEvents`. They use one generic `Dispatched` carrier event as
test infrastructure because direct FM20-named event raises are tracked in
`docs/handovers/HANDOVER_OxVba_w005_fm20_event_raise.md`; this carrier must not
be treated as the final forms event runtime.
