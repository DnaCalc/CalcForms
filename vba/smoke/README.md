# OxForms VBA Smoke Sources

This directory is reserved for procedural or class-based VBA smoke sources used
by W002.

`rectangle_fillrect_smoke.bas` is the W002 procedural smoke used by
`oxforms-dwm.4`. It emits a smoke-only diagnostic batch through `Debug.Print`;
the Rust harness captures those lines through OxVba host callbacks and submits
them to the OxForms PAL headless renderer.

Targeted command:

```powershell
cargo test -p oxforms-pal --test oxvba_rectangle_smoke -- --nocapture
```

The smoke API in this directory is temporary proof plumbing. It is not the final
MSForms compatibility surface.
