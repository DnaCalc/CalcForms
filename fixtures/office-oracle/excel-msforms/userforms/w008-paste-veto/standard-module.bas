Option Explicit

' Worksheet logger + show/clear + scenario macros for the W008 paste-veto oracle
' (esq.17). Each W008PasteVetoLog row records the event sequence, the active scenario,
' the control, the event name, the count-relevant argument name, its value before and
' after the handler (so the BeforeDropOrPaste Cancel False -> True veto mutation is
' observable), the post-handler focus owner, the count-relevant value (TextBox1.Value
' read at handler entry, so a suppressed paste shows the value unchanged), and a notes
' field carrying the BeforeDropOrPaste Action/Effect/Shift/Data details. The capture
' seeds the clipboard then sends Ctrl+V; one scenario leaves gVetoPaste False (baseline
' paste) and the other sets it True (vetoing paste), so a single workbook covers both.

Public gScenario As String
Public gVetoPaste As Boolean

Private gW008PvSeq As Long

Public Sub W008PvLog( _
        ByVal controlName As String, _
        ByVal eventName As String, _
        ByVal argName As String, _
        ByVal argBefore As String, _
        ByVal argAfter As String, _
        ByVal focusOwnerAfter As String, _
        ByVal valueAfter As String, _
        ByVal notes As String)
    Dim ws As Worksheet
    Set ws = W008PvSheet()
    gW008PvSeq = gW008PvSeq + 1
    Dim r As Long
    r = gW008PvSeq + 1
    ws.Cells(r, 1).Value = gW008PvSeq
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

Private Function W008PvSheet() As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W008PasteVetoLog")
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add
        ws.Name = "W008PasteVetoLog"
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
    Set W008PvSheet = ws
End Function

Public Sub ClearW008PasteVetoLog()
    gW008PvSeq = 0
    gScenario = ""
    gVetoPaste = False
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W008PasteVetoLog")
    On Error GoTo 0
    If Not ws Is Nothing Then
        ws.Cells.Clear
    End If
End Sub

Public Sub ShowW008PasteVetoModeless()
    OxFormsW008PasteVeto.Show vbModeless
End Sub

Public Sub FocusControlW008PasteVeto(ByVal name As String)
    OxFormsW008PasteVeto.Controls(name).SetFocus
End Sub

' ---- scenario flag control ----

Public Sub SetW008ScenarioPasteBaseline()
    gScenario = "paste_baseline"
    gVetoPaste = False
End Sub

Public Sub SetW008ScenarioPasteVeto()
    gScenario = "paste_veto"
    gVetoPaste = True
End Sub
