Option Explicit

' Worksheet logger + show/clear macros for the W006 Ctrl+V keyboard-ordering
' oracle. Each row records the event sequence, the control, the event name, the
' mutable argument name (if any), the argument .Value before and after the
' handler body, the control .Value at handler entry, and free-form notes, so the
' KeyDown/KeyPress/KeyUp vs BeforeDropOrPaste vs Change ordering and any Return*
' helper mutation are both observable.

Private gW006CtrlVSeq As Long

Public Sub W006CtrlVLog( _
        ByVal controlName As String, _
        ByVal eventName As String, _
        ByVal argName As String, _
        ByVal argBefore As String, _
        ByVal argAfter As String, _
        ByVal valueText As String, _
        ByVal notes As String)
    Dim ws As Worksheet
    Set ws = W006CtrlVSheet()
    gW006CtrlVSeq = gW006CtrlVSeq + 1
    Dim r As Long
    r = gW006CtrlVSeq + 1
    ws.Cells(r, 1).Value = gW006CtrlVSeq
    ws.Cells(r, 2).Value = controlName
    ws.Cells(r, 3).Value = eventName
    ws.Cells(r, 4).Value = argName
    ws.Cells(r, 5).Value = argBefore
    ws.Cells(r, 6).Value = argAfter
    ws.Cells(r, 7).Value = valueText
    ws.Cells(r, 8).Value = notes
End Sub

Private Function W006CtrlVSheet() As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W006CtrlVLog")
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add
        ws.Name = "W006CtrlVLog"
    End If
    If Len(CStr(ws.Cells(1, 1).Value)) = 0 Then
        ws.Cells(1, 1).Value = "sequence"
        ws.Cells(1, 2).Value = "control_name"
        ws.Cells(1, 3).Value = "event_name"
        ws.Cells(1, 4).Value = "arg_name"
        ws.Cells(1, 5).Value = "arg_before"
        ws.Cells(1, 6).Value = "arg_after"
        ws.Cells(1, 7).Value = "value"
        ws.Cells(1, 8).Value = "notes"
    End If
    Set W006CtrlVSheet = ws
End Function

Public Sub ClearW006CtrlVLog()
    gW006CtrlVSeq = 0
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W006CtrlVLog")
    On Error GoTo 0
    If Not ws Is Nothing Then
        ws.Cells.Clear
    End If
End Sub

Public Sub ShowW006CtrlVModeless()
    OxFormsW006CtrlV.Show vbModeless
End Sub
