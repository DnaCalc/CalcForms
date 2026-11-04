# Rectangle Smoke App Project

`RectangleSmokeApp.basproj` is the W002 app-side fixture. It references
`../../../oxforms/CalcForms.basproj` and executes
`../../fixtures/rectangle_fillrect_smoke.bas`.

The app creates an CalcForms smoke form through the library. It must not directly
create `CalcForms.SmokeCanvas`; that low-level bridge belongs inside the CalcForms
library fixture for this smoke.
