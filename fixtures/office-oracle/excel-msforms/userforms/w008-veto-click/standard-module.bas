Option Explicit

' Worksheet logger + show/clear + scenario macros for the W008 veto-click oracle.
' Each W008VetoClickLog row records the event sequence, the active scenario, the
' control, the event name, the relevant argument name, its value before and after
' the handler optionally vetoed it, the post-handler focus owner, and the relevant
' TextBox .Text. The capture script calls one Set... macro per scenario (which
' clears all flags then sets gScenario plus the flags that scenario needs) before
' driving that scenario's mouse click, so a single workbook covers both the
' non-vetoing baseline and the vetoing-mouse-click scenario through the shared
' worksheet.

Public gScenario As String
Public gVetoExit As Boolean
Public gVetoControl As String

Private gW008VetoClickSeq As Long

Public Sub W008VetoClickLog( _
        ByVal controlName As String, _
        ByVal eventName As String, _
        ByVal argName As String, _
        ByVal argBefore As String, _
        ByVal argAfter As String, _
        ByVal focusOwnerAfter As String, _
        ByVal textValueAfter As String)
    Dim ws As Worksheet
    Set ws = W008VetoClickSheet()
    gW008VetoClickSeq = gW008VetoClickSeq + 1
    Dim r As Long
    r = gW008VetoClickSeq + 1
    ws.Cells(r, 1).Value = gW008VetoClickSeq
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

Private Function W008VetoClickSheet() As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W008VetoClickLog")
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add
        ws.Name = "W008VetoClickLog"
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
    Set W008VetoClickSheet = ws
End Function

Public Sub ClearW008VetoClickLog()
    gW008VetoClickSeq = 0
    ClearW008VetoClickFlags
    gScenario = ""
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W008VetoClickLog")
    On Error GoTo 0
    If Not ws Is Nothing Then
        ws.Cells.Clear
    End If
End Sub

Public Sub ShowW008VetoClickModeless()
    OxFormsW008VetoClick.Show vbModeless
End Sub

Public Sub FocusControlW008VetoClick(ByVal name As String)
    OxFormsW008VetoClick.Controls(name).SetFocus
End Sub

' ---- scenario flag control ----

Private Sub ClearW008VetoClickFlags()
    gVetoExit = False
    gVetoControl = ""
End Sub

Public Sub SetW008ScenarioNonVetoClickBaseline()
    ClearW008VetoClickFlags
    gScenario = "nonveto_click_baseline"
End Sub

Public Sub SetW008ScenarioVetoExitClick()
    ClearW008VetoClickFlags
    gScenario = "veto_exit_click"
    gVetoExit = True
    gVetoControl = "TextBox1"
End Sub
