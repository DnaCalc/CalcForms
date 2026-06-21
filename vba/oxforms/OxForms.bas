Option Explicit

' W002 smoke-only OxForms library entrypoint.
' This is not the final MSForms compatibility API.

Public Function NewSmokeForm() As Object
    Dim form As OxFormsSmokeForm

    Set form = New OxFormsSmokeForm
    Set NewSmokeForm = form
End Function
