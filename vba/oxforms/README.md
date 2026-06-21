# OxForms VBA Library Smoke Fixture

This directory contains the W002 smoke-only OxForms VBA library project.

`OxForms.basproj` is loaded as a referenced library by
`../smoke/projects/rectangle_app/RectangleSmokeApp.basproj`. It exposes
`NewSmokeForm`, which returns `OxFormsSmokeForm`. The smoke form owns the
temporary PAL bridge by creating `OxForms.SmokeCanvas` and calling
`CreateSurface`, `FillRect`, and `Flush`.

This is not the final MSForms compatibility surface. It does not implement
`.frm` ingestion, `UserForm.Show`, intrinsic controls, input routing, or form
module materialization.
