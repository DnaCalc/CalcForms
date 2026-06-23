Option Explicit

' OxForms object-model shared declarations and the control factory.
'
' This module is the single extension point for intrinsic controls: adding a new
' control means writing one class module that Implements IOxControl and adding one
' Case to OxCreateControl. Nothing else in the framework changes. See
' docs/specs/RENDERING_ARCHITECTURE.md (§5) for the authoring recipe.

Public Enum OxControlKind
    oxControlLabel = 0
    oxControlTextBox = 1
    oxControlCommandButton = 2
    oxControlCheckBox = 3
End Enum

' Create an unparented control of the requested kind with its Name assigned.
' The caller (normally OxUserForm.Add) binds it to a host afterwards. Returns
' Nothing for a kind that has no class module yet.
Public Function OxCreateControl(ByVal Kind As OxControlKind, ByVal Name As String) As IOxControl
    Dim Control As IOxControl

    Select Case Kind
        Case oxControlLabel
            Set Control = New Label
        Case oxControlTextBox
            Set Control = New TextBox
        Case oxControlCommandButton
            Set Control = New CommandButton
    End Select

    If Not Control Is Nothing Then
        Control.Core.Name = Name
    End If

    Set OxCreateControl = Control
End Function
