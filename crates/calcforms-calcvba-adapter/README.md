# CalcForms CalcVBA Adapter

This crate is the CalcVBA-specific adapter for CalcForms PAL services.

It projects the `CalcForms.Surface` seam (the retained-Scene drawing boundary VBA forms
self-render through via `BeginScene`/`SubmitPatch`/`MeasureText`) and drives the runtime
effect/render loop (`runtime_runner`). It owns the CalcVBA glue — `PortableDispatch`,
`PortableComProjection`, `Variant` marshalling, and the `NodeId`↔control map. The core
`calcforms-pal` crate must stay independent of CalcVBA and host-runtime details. (The W002
`CalcForms.SmokeCanvas` projection ran in parallel during the migration and was retired in
oxforms-rq5.1.)

The shape:

```text
CalcForms VBA library -> CalcVBA adapter (CalcForms.Surface) -> calcforms-pal retained Scene -> renderer
```

It is not yet the final MSForms compatibility API.
