# Rectangle Smoke App Project

`RectangleSmokeApp.basproj` is the W002 app-side fixture. It references
`../../../oxforms/OxForms.basproj` and executes
`../../fixtures/rectangle_fillrect_smoke.bas`.

The app creates an OxForms smoke form through the library. It must not directly
create `OxForms.SmokeCanvas`; that low-level bridge belongs inside the OxForms
library fixture for this smoke.
