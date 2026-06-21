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
cargo test -p oxforms-pal --test oxvba_rectangle_smoke -- --nocapture
```

The smoke API in this directory is temporary proof plumbing. It is not the final
MSForms compatibility surface.
