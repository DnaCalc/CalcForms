Option Explicit

' W002 smoke-only PAL diagnostic fixture.
' This is not an MSForms compatibility API and does not model UserForm behavior.

Public renderedCommandCount As Long

Public Sub Main()
    Dim canvas As Object

    Set canvas = CreateObject("OxForms.SmokeCanvas")
    canvas.CreateSurface 4, 3
    canvas.FillRect 1, 1, 2, 1, 16, 32, 48, 255
    renderedCommandCount = canvas.Flush()
End Sub
