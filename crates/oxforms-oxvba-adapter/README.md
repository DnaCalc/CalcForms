# OxForms OxVba Adapter

This crate is the OxVba-specific adapter for OxForms PAL services.

Its current `smoke_canvas` module owns the W002 smoke `OxForms.SmokeCanvas`
projection, including `PortableDispatch`, `PortableComProjection`, `Variant`
marshalling, and the OxVba project-closure smoke test. The core `oxforms-pal`
crate must stay independent of OxVba and host-runtime details.

The current surface is smoke-only. It proves the shape:

```text
OxForms VBA library -> OxVba adapter -> oxforms-pal core renderer
```

It is not the final MSForms compatibility API.
