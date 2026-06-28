Option Explicit

' Worksheet logger + show/clear + scenario macros for the W008 dirty-focus-out oracle
' (esq.14). Each W008CheckBoxUpdateLog row records the event sequence, the active
' scenario, the control, the event name, the count-relevant argument name, its value
' before and after the handler (this fixture does not mutate args, so before == after),
' the post-handler focus owner, and the count-relevant value (TextBox1.Text or
' CheckBox1.Value). The capture sets gScenario via one Set... macro per scenario, so a
' single workbook covers both the CheckBox dirty focus-out and the TextBox
' edit-then-revert focus-out through the shared worksheet.

Public gScenario As String

Private gW008CbuSeq As Long

Public Sub W008CbuLog( _
        ByVal controlName As String, _
        ByVal eventName As String, _
        ByVal argName As String, _
        ByVal argBefore As String, _
        ByVal argAfter As String, _
        ByVal focusOwnerAfter As String, _
        ByVal valueAfter As String)
    Dim ws As Worksheet
    Set ws = W008CbuSheet()
    gW008CbuSeq = gW008CbuSeq + 1
    Dim r As Long
    r = gW008CbuSeq + 1
    ws.Cells(r, 1).Value = gW008CbuSeq
    ws.Cells(r, 2).Value = gScenario
    ws.Cells(r, 3).Value = controlName
    ws.Cells(r, 4).Value = eventName
    ws.Cells(r, 5).Value = argName
    ws.Cells(r, 6).Value = argBefore
    ws.Cells(r, 7).Value = argAfter
    ws.Cells(r, 8).Value = focusOwnerAfter
    ws.Cells(r, 9).Value = valueAfter
    ws.Cells(r, 10).Value = ""
End Sub

Private Function W008CbuSheet() As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W008CheckBoxUpdateLog")
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add
        ws.Name = "W008CheckBoxUpdateLog"
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
        ws.Cells(1, 9).Value = "value_after"
        ws.Cells(1, 10).Value = "notes"
    End If
    Set W008CbuSheet = ws
End Function

Public Sub ClearW008CheckBoxUpdateLog()
    gW008CbuSeq = 0
    gScenario = ""
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W008CheckBoxUpdateLog")
    On Error GoTo 0
    If Not ws Is Nothing Then
        ws.Cells.Clear
    End If
End Sub

Public Sub ShowW008CheckBoxUpdateModeless()
    OxFormsW008CheckBoxUpdate.Show vbModeless
End Sub

Public Sub FocusControlW008CheckBoxUpdate(ByVal name As String)
    OxFormsW008CheckBoxUpdate.Controls(name).SetFocus
End Sub

' ---- scenario flag control ----

Public Sub SetW008ScenarioCheckboxDirtyFocusOut()
    gScenario = "checkbox_dirty_focus_out"
End Sub

Public Sub SetW008ScenarioEditRevertFocusOut()
    gScenario = "edit_revert_focus_out"
End Sub
