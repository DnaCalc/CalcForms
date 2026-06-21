Option Explicit

' W002 smoke-only app project fixture.
' This is not an MSForms compatibility API and does not model UserForm behavior.

Public renderedCommandCount As Long

Public Sub Run()
    Dim form As Object

    Set form = OxForms.NewSmokeForm()
    renderedCommandCount = form.RenderRectangleSmoke()
End Sub
