Option Explicit

' OxForms object-model shared declarations and the control factory.
'
' This module is the single extension point for intrinsic controls: adding a new
' control means writing one class module that Implements IOxControl and adding one
' Case to OxKindFromProgId/OxCreateControl. Nothing else in the framework changes. See
' docs/specs/RENDERING_ARCHITECTURE.md (§5) for the authoring recipe.
'
' The public creation surface is Forms 2.0: callers use Controls.Add with a ProgID
' ("Forms.Label.1"). OxControlKind below is OxForms-INTERNAL machinery (it drives
' OxControlCore's per-kind appearance defaults and the ProgID->class factory); VBA authors
' never name it.

Public Enum OxControlKind
    oxControlLabel = 0
    oxControlTextBox = 1
    oxControlCommandButton = 2
    oxControlCheckBox = 3
End Enum

' MSForms 3D appearance, values from [MS-OFORMS] fmSpecialEffect (see spec s5.6).
' VBA owns the SpecialEffect -> generic EdgeEffect mapping; the Rust kernel only
' knows the generic edge (it never learns "TextBox").
Public Enum fmSpecialEffect
    fmSpecialEffectFlat = 0
    fmSpecialEffectRaised = 1
    fmSpecialEffectSunken = 2
    fmSpecialEffectEtched = 3
    fmSpecialEffectBump = 6
End Enum

' [MS-OFORMS] fmBorderStyle.
Public Enum fmBorderStyle
    fmBorderStyleNone = 0
    fmBorderStyleSingle = 1
End Enum

' Sentinel for the BackColor/ForeColor/BorderColor band meaning "no explicit
' override; resolve from the theme at paint time". Distinct from any 0xRRGGBB
' value and from the 0x80000000 OLE_COLOR system-index flag.
Public Const oxColorAuto As Long = -1

' The OxForms.Surface.MeasureBatch wire contract (oxforms-98v): ONE VBA->Rust crossing
' measures every text run a frame needs. A request and a result are typed records, so the
' free-form caption rides as a native String field (never packed/escaped/length-prefixed)
' and the metrics return as typed Longs (no VBA-side string parsing). The field order and
' kinds MUST match the Rust-side VbaRecordLayouts in
' crates/oxforms-oxvba-adapter/src/surface.rs; the VBA library and the renderer are
' co-versioned, so the two layouts change together in one commit (no on-wire versioning).
' Metrics are 1/1000 pt integers. RunId is the content-hash u64 as a decimal token (it does
' not fit a Long), which VBA re-emits verbatim into the patch's DrawText run.
Public Type OxMeasureRequest
    FontId As Long
    SizeMilliPt As Long
    Caption As String
End Type

Public Type OxMeasureResult
    RunId As String
    AdvanceMilliPt As Long
    AscentMilliPt As Long
    DescentMilliPt As Long
    LineGapMilliPt As Long
    CaretStopsMilliPtCsv As String
End Type

' Map a Forms 2.0 control ProgID ("Forms.Label.1") to the internal kind. Unknown -> -1.
' Case-insensitive, like real MSForms Controls.Add. The currently implemented intrinsic
' subset is Label, TextBox, CommandButton, and CheckBox.
Public Function OxKindFromProgId(ByVal ProgId As String) As OxControlKind
    Select Case LCase$(ProgId)
        Case "forms.label.1"
            OxKindFromProgId = oxControlLabel
        Case "forms.textbox.1"
            OxKindFromProgId = oxControlTextBox
        Case "forms.commandbutton.1"
            OxKindFromProgId = oxControlCommandButton
        Case "forms.checkbox.1"
            OxKindFromProgId = oxControlCheckBox
        Case Else
            OxKindFromProgId = -1
    End Select
End Function

' Create an unparented control for a Forms 2.0 ProgID with its Name assigned. The caller
' (Controls.Add) registers it on the form afterwards. Returns Nothing for an unknown ProgID.
Public Function OxCreateControl(ByVal ProgId As String, ByVal Name As String) As IOxControl
    Dim Control As IOxControl

    Select Case OxKindFromProgId(ProgId)
        Case oxControlLabel
            Set Control = New Label
        Case oxControlTextBox
            Set Control = New TextBox
        Case oxControlCommandButton
            Set Control = New CommandButton
        Case oxControlCheckBox
            Set Control = New CheckBox
    End Select

    If Not Control Is Nothing Then
        Control.Core.Name = Name
    End If

    Set OxCreateControl = Control
End Function
