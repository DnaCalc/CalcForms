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
    oxControlListBox = 4
    oxControlFrame = 5
    oxControlImage = 6
    oxControlSpinButton = 7
    oxControlToggleButton = 8
    oxControlOptionButton = 9
    oxControlComboBox = 10
    oxControlScrollBar = 11
    oxControlTabStrip = 12
    oxControlMultiPage = 13
    oxControlPage = 14
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

Public Enum fmMultiSelect
    fmMultiSelectSingle = 0
    fmMultiSelectMulti = 1
    fmMultiSelectExtended = 2
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

Private gOxProfileChecked As Boolean
Private gOxProfileEnabled As Boolean
Private gOxProfileSurface As Object

' Map a Forms 2.0 control ProgID ("Forms.Label.1") to the internal kind. Unknown -> -1.
' Case-insensitive, like real MSForms Controls.Add. The currently implemented intrinsic
' subset is Label, TextBox, CommandButton, CheckBox, OptionButton, ListBox, ComboBox,
' Frame, Image, SpinButton, ScrollBar, TabStrip, MultiPage/Page, and ToggleButton.
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
        Case "forms.listbox.1"
            OxKindFromProgId = oxControlListBox
        Case "forms.combobox.1"
            OxKindFromProgId = oxControlComboBox
        Case "forms.frame.1"
            OxKindFromProgId = oxControlFrame
        Case "forms.image.1"
            OxKindFromProgId = oxControlImage
        Case "forms.spinbutton.1"
            OxKindFromProgId = oxControlSpinButton
        Case "forms.scrollbar.1"
            OxKindFromProgId = oxControlScrollBar
        Case "forms.tabstrip.1"
            OxKindFromProgId = oxControlTabStrip
        Case "forms.multipage.1"
            OxKindFromProgId = oxControlMultiPage
        Case "forms.togglebutton.1"
            OxKindFromProgId = oxControlToggleButton
        Case "forms.optionbutton.1"
            OxKindFromProgId = oxControlOptionButton
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
        Case oxControlListBox
            Set Control = New ListBox
        Case oxControlComboBox
            Set Control = New ComboBox
        Case oxControlFrame
            Set Control = New Frame
        Case oxControlImage
            Set Control = New Image
        Case oxControlSpinButton
            Set Control = New SpinButton
        Case oxControlScrollBar
            Set Control = New ScrollBar
        Case oxControlTabStrip
            Set Control = New TabStrip
        Case oxControlMultiPage
            Set Control = New MultiPage
        Case oxControlToggleButton
            Set Control = New ToggleButton
        Case oxControlOptionButton
            Set Control = New OptionButtonControl
    End Select

    If Not Control Is Nothing Then
        Control.Core.Name = Name
    End If

    Set OxCreateControl = Control
End Function

' Profiling-only phase marker for W009 performance attribution. Normal runs do
' not cross to Rust at all; the ignored perf harness opts in with
' OXFORMS_PROFILE_TIMINGS.
Public Function OxProfileEnabled() As Boolean
    If Not gOxProfileChecked Then
        gOxProfileEnabled = (Len(Environ("OXFORMS_PROFILE_TIMINGS")) > 0)
        gOxProfileChecked = True
    End If
    OxProfileEnabled = gOxProfileEnabled
End Function

Public Sub OxProfileMark(ByVal Name As String)
    If Not OxProfileEnabled() Then Exit Sub
    If gOxProfileSurface Is Nothing Then
        Set gOxProfileSurface = CreateObject("OxForms.Surface")
    End If
    gOxProfileSurface.ProfileMark Name
End Sub
