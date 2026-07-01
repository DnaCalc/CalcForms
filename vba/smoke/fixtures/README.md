# VBA Smoke Fixtures

This directory contains fixture inputs and expected diagnostics produced by the
W002 VBA rectangle smoke app project.

`rectangle_fillrect_smoke.bas` is intentionally procedural. It does not require
`.frm` ingestion, `UserForm.Show`, or an MSForms object model. It is loaded by
`../projects/rectangle_app/RectangleSmokeApp.basproj`, references the OxForms
VBA library, creates an OxForms smoke form, and records the `Flush` return value.
The low-level `OxForms.SmokeCanvas` PAL object is created inside the OxForms
library, not by this app fixture.

`full_surface_showcase_form.cls` is the evolving Forms super-app fixture. It is
the first stop for runnable current-state proof: every supported intrinsic
control is visible, current method/event families are wired through ordinary VBA
`WithEvents` handlers, and unsupported future intrinsics appear as pending
catalog rows. Extend this fixture when a control lane lands so the showcase grows
with the product surface.
