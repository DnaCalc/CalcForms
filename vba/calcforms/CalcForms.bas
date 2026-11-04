Option Explicit

' W002 smoke-only CalcForms library entrypoint.
' This is not the final MSForms compatibility API.

Public Function NewSmokeForm() As Object
    Dim form As CalcFormsSmokeForm

    Set form = New CalcFormsSmokeForm
    Set NewSmokeForm = form
End Function
