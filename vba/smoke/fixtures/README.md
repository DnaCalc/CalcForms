# VBA Smoke Fixtures

This directory contains fixture inputs and expected diagnostics produced by the
W002 VBA rectangle smoke app project.

`rectangle_fillrect_smoke.bas` is intentionally procedural. It does not require
`.frm` ingestion, `UserForm.Show`, or an MSForms object model. It is loaded by
`../projects/rectangle_app/RectangleSmokeApp.basproj`, references the OxForms
VBA library, creates an OxForms smoke form, and records the `Flush` return value.
The low-level `OxForms.SmokeCanvas` PAL object is created inside the OxForms
library, not by this app fixture.
