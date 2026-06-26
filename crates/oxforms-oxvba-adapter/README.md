# OxForms OxVba Adapter

This crate is the OxVba-specific adapter for OxForms PAL services.

It projects the `OxForms.Surface` seam (the retained-Scene drawing boundary VBA forms
self-render through via `BeginScene`/`SubmitPatch`/`MeasureText`) and drives the runtime
effect/render loop (`runtime_runner`). It owns the OxVba glue — `PortableDispatch`,
`PortableComProjection`, `Variant` marshalling, and the `NodeId`↔control map. The core
`oxforms-pal` crate must stay independent of OxVba and host-runtime details. (The W002
`OxForms.SmokeCanvas` projection ran in parallel during the migration and was retired in
oxforms-rq5.1.)

The shape:

```text
OxForms VBA library -> OxVba adapter (OxForms.Surface) -> oxforms-pal retained Scene -> renderer
```

It is not yet the final MSForms compatibility API.
