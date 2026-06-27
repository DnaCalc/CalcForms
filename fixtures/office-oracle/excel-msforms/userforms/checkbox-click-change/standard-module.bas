Option Explicit

' Worksheet logger + show/clear macros for the W006 CheckBox Click-vs-Change
' oracle. Each row records the event sequence, the control, the event name, and
' the CheckBox .Value as read at handler entry, so the Click/Change ordering and
' the toggle timing are both observable.

Private gW006CheckBoxSeq As Long

Public Sub W006CheckBoxLog( _
        ByVal formName As String, _
        ByVal controlName As String, _
        ByVal eventName As String, _
        ByVal valueText As String, _
        ByVal notes As String)
    Dim ws As Worksheet
    Set ws = W006CheckBoxSheet()
    gW006CheckBoxSeq = gW006CheckBoxSeq + 1
    Dim r As Long
    r = gW006CheckBoxSeq + 1
    ws.Cells(r, 1).Value = gW006CheckBoxSeq
    ws.Cells(r, 2).Value = formName
    ws.Cells(r, 3).Value = controlName
    ws.Cells(r, 4).Value = eventName
    ws.Cells(r, 5).Value = valueText
    ws.Cells(r, 6).Value = notes
End Sub

Private Function W006CheckBoxSheet() As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W006CheckBoxLog")
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add
        ws.Name = "W006CheckBoxLog"
    End If
    If Len(CStr(ws.Cells(1, 1).Value)) = 0 Then
        ws.Cells(1, 1).Value = "sequence"
        ws.Cells(1, 2).Value = "form_name"
        ws.Cells(1, 3).Value = "control_name"
        ws.Cells(1, 4).Value = "event_name"
        ws.Cells(1, 5).Value = "value"
        ws.Cells(1, 6).Value = "notes"
    End If
    Set W006CheckBoxSheet = ws
End Function

Public Sub ClearW006CheckBoxLog()
    gW006CheckBoxSeq = 0
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W006CheckBoxLog")
    On Error GoTo 0
    If Not ws Is Nothing Then
        ws.Cells.Clear
    End If
End Sub

Public Sub ShowW006CheckBoxModeless()
    OxFormsW006CheckBox.Show vbModeless
End Sub
