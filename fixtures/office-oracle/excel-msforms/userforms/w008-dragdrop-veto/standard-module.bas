Option Explicit

' Worksheet logger + show/clear + scenario macros for the W008 drag-drop veto oracle
' (oxforms-4f8). Each W008DragDropVetoLog row records the event sequence, the active scenario,
' the control, the event name, the count-relevant argument name, its value before and after the
' handler (so the BeforeDropOrPaste Cancel False -> True veto mutation is observable), the
' post-handler focus owner, the count-relevant value (TargetBox.Value read at handler entry, so
' a suppressed drop shows the value unchanged), and a notes field carrying the BeforeDropOrPaste
' Action/Effect/Shift/Data details. The capture selects the SourceBox text and drags it onto
' TargetBox; one scenario leaves gVetoDrop False (baseline drop) and the other sets it True
' (vetoing drop), so a single workbook covers both.

Public gScenario As String
Public gVetoDrop As Boolean

Private gW008DdvSeq As Long

Public Sub W008DdvLog( _
        ByVal controlName As String, _
        ByVal eventName As String, _
        ByVal argName As String, _
        ByVal argBefore As String, _
        ByVal argAfter As String, _
        ByVal focusOwnerAfter As String, _
        ByVal valueAfter As String, _
        ByVal notes As String)
    Dim ws As Worksheet
    Set ws = W008DdvSheet()
    gW008DdvSeq = gW008DdvSeq + 1
    Dim r As Long
    r = gW008DdvSeq + 1
    ws.Cells(r, 1).Value = gW008DdvSeq
    ws.Cells(r, 2).Value = gScenario
    ws.Cells(r, 3).Value = controlName
    ws.Cells(r, 4).Value = eventName
    ws.Cells(r, 5).Value = argName
    ws.Cells(r, 6).Value = argBefore
    ws.Cells(r, 7).Value = argAfter
    ws.Cells(r, 8).Value = focusOwnerAfter
    ws.Cells(r, 9).Value = valueAfter
    ws.Cells(r, 10).Value = notes
End Sub

Private Function W008DdvSheet() As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W008DragDropVetoLog")
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add
        ws.Name = "W008DragDropVetoLog"
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
    Set W008DdvSheet = ws
End Function

Public Sub ClearW008DragDropVetoLog()
    gW008DdvSeq = 0
    gScenario = ""
    gVetoDrop = False
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W008DragDropVetoLog")
    On Error GoTo 0
    If Not ws Is Nothing Then
        ws.Cells.Clear
    End If
End Sub

Public Sub ShowW008DragDropVetoModeless()
    OxFormsW008DragDropVeto.Show vbModeless
End Sub

Public Sub FocusControlW008DragDropVeto(ByVal name As String)
    OxFormsW008DragDropVeto.Controls(name).SetFocus
End Sub

' ---- scenario flag control ----

Public Sub SetW008ScenarioDragDropBaseline()
    gScenario = "dragdrop_baseline"
    gVetoDrop = False
End Sub

Public Sub SetW008ScenarioDragDropVeto()
    gScenario = "dragdrop_veto"
    gVetoDrop = True
End Sub
