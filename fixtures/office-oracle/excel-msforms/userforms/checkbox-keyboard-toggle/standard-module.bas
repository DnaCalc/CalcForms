Option Explicit

' Worksheet logger + show/clear macros for the W006 CheckBox Space/Enter
' keyboard-toggle oracle. Each row records the event sequence, the form, the
' control, the event name, the CheckBox .Value at handler entry, the KeyCode
' helper .Value before/after the handler body (for KeyDown/KeyUp), and notes, so
' the Click/Change/KeyDown/KeyUp ordering, the toggle timing (value_at_keydown vs
' value_at_keyup), and any KeyCode mutation are observable.

Private gW006CheckBoxKbdSeq As Long

Public Sub W006CheckBoxKbdLog( _
        ByVal formName As String, _
        ByVal controlName As String, _
        ByVal eventName As String, _
        ByVal valueText As String, _
        ByVal keyCodeBefore As String, _
        ByVal keyCodeAfter As String, _
        ByVal notes As String)
    Dim ws As Worksheet
    Set ws = W006CheckBoxKbdSheet()
    gW006CheckBoxKbdSeq = gW006CheckBoxKbdSeq + 1
    Dim r As Long
    r = gW006CheckBoxKbdSeq + 1
    ws.Cells(r, 1).Value = gW006CheckBoxKbdSeq
    ws.Cells(r, 2).Value = formName
    ws.Cells(r, 3).Value = controlName
    ws.Cells(r, 4).Value = eventName
    ws.Cells(r, 5).Value = valueText
    ws.Cells(r, 6).Value = keyCodeBefore
    ws.Cells(r, 7).Value = keyCodeAfter
    ws.Cells(r, 8).Value = notes
End Sub

Private Function W006CheckBoxKbdSheet() As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W006CheckBoxKbdLog")
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add
        ws.Name = "W006CheckBoxKbdLog"
    End If
    If Len(CStr(ws.Cells(1, 1).Value)) = 0 Then
        ws.Cells(1, 1).Value = "sequence"
        ws.Cells(1, 2).Value = "form_name"
        ws.Cells(1, 3).Value = "control_name"
        ws.Cells(1, 4).Value = "event_name"
        ws.Cells(1, 5).Value = "value"
        ws.Cells(1, 6).Value = "key_code_before"
        ws.Cells(1, 7).Value = "key_code_after"
        ws.Cells(1, 8).Value = "notes"
    End If
    Set W006CheckBoxKbdSheet = ws
End Function

Public Sub ClearW006CheckBoxKbdLog()
    gW006CheckBoxKbdSeq = 0
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W006CheckBoxKbdLog")
    On Error GoTo 0
    If Not ws Is Nothing Then
        ws.Cells.Clear
    End If
End Sub

Public Sub ShowW006CheckBoxKbdModeless()
    OxFormsW006CheckBoxKbd.Show vbModeless
End Sub
