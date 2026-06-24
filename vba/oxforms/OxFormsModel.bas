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

' MSForms 3D appearance, values from [MS-OFORMS] fmSpecialEffect (see spec s5.6).
' VBA owns the SpecialEffect -> generic EdgeEffect mapping; the Rust kernel only
' knows the generic edge (it never learns "TextBox").
Public Enum OxSpecialEffect
    oxEffectFlat = 0
    oxEffectRaised = 1
    oxEffectSunken = 2
    oxEffectEtched = 3
    oxEffectBump = 6
End Enum

' [MS-OFORMS] fmBorderStyle.
Public Enum OxBorderStyle
    oxBorderNone = 0
    oxBorderSingle = 1
End Enum

' Sentinel for the BackColor/ForeColor/BorderColor band meaning "no explicit
' override; resolve from the theme at paint time". Distinct from any 0xRRGGBB
' value and from the 0x80000000 OLE_COLOR system-index flag.
Public Const oxColorAuto As Long = -1

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
