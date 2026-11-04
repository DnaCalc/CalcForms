# CalcForms VBA Library Smoke Fixture

This directory contains the W002 smoke-only CalcForms VBA library project.

`CalcForms.basproj` is loaded as a referenced library by
`../smoke/projects/rectangle_app/RectangleSmokeApp.basproj`. It exposes
`NewSmokeForm`, which returns `CalcFormsSmokeForm`. The smoke form owns the
temporary PAL bridge by creating `CalcForms.SmokeCanvas` and calling
`CreateSurface`, `FillRect`, and `Flush`.

This is not the final MSForms compatibility surface. It does not implement
`.frm` ingestion, `UserForm.Show`, intrinsic controls, input routing, or form
module materialization.
