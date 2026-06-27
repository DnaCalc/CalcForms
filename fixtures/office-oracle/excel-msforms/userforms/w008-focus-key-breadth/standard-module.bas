Option Explicit

' Worksheet logger + show/clear + scenario macros for the W008 focus + key
' fold-back oracle. Each W008BreadthLog row records the event sequence, the active
' scenario, the control, the event name, the mutated argument name, its value
' before and after the handler mutated it, the post-handler focus owner, and the
' relevant TextBox .Text. The capture scripts call one Set... macro per scenario
' (which clears all flags then sets gScenario plus the flags that scenario needs)
' before driving that scenario's input, so a single workbook covers every focus,
' validation, and keyboard fold-back scenario through the shared worksheet.

Public gScenario As String
Public gVetoExit As Boolean
Public gVetoBeforeUpdate As Boolean
Public gSwallowKeyDown As Boolean
Public gSwallowKeyPress As Boolean
Public gVetoControl As String

Private gW008BreadthSeq As Long

Public Sub W008Log( _
        ByVal controlName As String, _
        ByVal eventName As String, _
        ByVal argName As String, _
        ByVal argBefore As String, _
        ByVal argAfter As String, _
        ByVal focusOwnerAfter As String, _
        ByVal textValueAfter As String)
    Dim ws As Worksheet
    Set ws = W008BreadthSheet()
    gW008BreadthSeq = gW008BreadthSeq + 1
    Dim r As Long
    r = gW008BreadthSeq + 1
    ws.Cells(r, 1).Value = gW008BreadthSeq
    ws.Cells(r, 2).Value = gScenario
    ws.Cells(r, 3).Value = controlName
    ws.Cells(r, 4).Value = eventName
    ws.Cells(r, 5).Value = argName
    ws.Cells(r, 6).Value = argBefore
    ws.Cells(r, 7).Value = argAfter
    ws.Cells(r, 8).Value = focusOwnerAfter
    ws.Cells(r, 9).Value = textValueAfter
    ws.Cells(r, 10).Value = ""
End Sub

Private Function W008BreadthSheet() As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W008BreadthLog")
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add
        ws.Name = "W008BreadthLog"
    End If
    If Len(CStr(ws.Cells(1, 1).Value)) = 0 Then
        ws.Cells(1, 1).Value = "sequence"
        ws.Cells(1, 2).Value = "scenario"
        ws.Cells(1, 3).Value = "control_name"
        ws.Cells(1, 4).Value = "event_name"
        ws.Cells(1, 5).Value = "arg_name"
        ws.Cells(1, 6).Value = "arg_before"
        ws.Cells(1, 7).Value = "arg_after"
        ws.Cells(1, 8).Value = "focus_owner_after"
        ws.Cells(1, 9).Value = "text_value_after"
        ws.Cells(1, 10).Value = "notes"
    End If
    Set W008BreadthSheet = ws
End Function

Public Sub ClearW008BreadthLog()
    gW008BreadthSeq = 0
    ClearW008Flags
    gScenario = ""
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W008BreadthLog")
    On Error GoTo 0
    If Not ws Is Nothing Then
        ws.Cells.Clear
    End If
End Sub

Public Sub ShowW008BreadthModeless()
    OxFormsW008Breadth.Show vbModeless
End Sub

Public Sub FocusControlW008(ByVal name As String)
    OxFormsW008Breadth.Controls(name).SetFocus
End Sub

' ---- scenario flag control ----

Private Sub ClearW008Flags()
    gVetoExit = False
    gVetoBeforeUpdate = False
    gSwallowKeyDown = False
    gSwallowKeyPress = False
    gVetoControl = ""
End Sub

Public Sub SetW008ScenarioTabTransfer()
    ClearW008Flags
    gScenario = "tab_transfer"
End Sub

Public Sub SetW008ScenarioExitVeto()
    ClearW008Flags
    gScenario = "exit_veto_keeps_focus"
    gVetoExit = True
    gVetoControl = "TextBox1"
End Sub

Public Sub SetW008ScenarioBeforeUpdateVeto()
    ClearW008Flags
    gScenario = "before_update_veto"
    gVetoBeforeUpdate = True
End Sub

Public Sub SetW008ScenarioCheckboxBaseline()
    ClearW008Flags
    gScenario = "checkbox_baseline"
End Sub

Public Sub SetW008ScenarioDefaultEnter()
    ClearW008Flags
    gScenario = "default_button_enter"
End Sub

Public Sub SetW008ScenarioSwallowKeyDown()
    ClearW008Flags
    gScenario = "swallow_keydown"
    gSwallowKeyDown = True
End Sub

Public Sub SetW008ScenarioSwallowKeyPress()
    ClearW008Flags
    gScenario = "swallow_keypress"
    gSwallowKeyPress = True
End Sub

Public Sub SetW008ScenarioArrowSwallow()
    ClearW008Flags
    gScenario = "arrow_swallow"
    gSwallowKeyDown = True
End Sub

Public Sub SetW008ScenarioChangeTiming()
    ClearW008Flags
    gScenario = "change_timing"
End Sub
