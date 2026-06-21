# OxForms VBA Smoke Sources

This directory is reserved for procedural or class-based VBA smoke sources used
by W002.

`rectangle_fillrect_smoke.bas` is the W002 procedural smoke used by
`oxforms-dwm.7`. It obtains a smoke-only host object with
`CreateObject("OxForms.SmokeCanvas")` through OxVba's portable COM-like
projection. The Rust harness registers that ProgID, VBA calls
`CreateSurface`, `FillRect`, and `Flush`, and `Flush` invokes the OxForms PAL
headless renderer.

Targeted command:

```powershell
cargo test -p oxforms-pal --test oxvba_rectangle_smoke -- --nocapture
```

The smoke API in this directory is temporary proof plumbing. It is not the final
MSForms compatibility surface.
