Option Explicit
Private mTrace As String
Private mFailure As String
Public Function Snapshot(ByVal Reset As Boolean) As String
    On Error GoTo Failed
    If Len(mFailure) > 0 Then Err.Raise 5, "TabProbe", mFailure
    Snapshot = mTrace
    If Reset Then mTrace = ""
    Exit Function
Failed:
    Snapshot = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Private Sub TabsControl_MouseDown(ByVal Index As Long, ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mTrace = mTrace & "TabsControl.MouseDown:index=" & CStr(Index) & ";value=" & CStr(TabsControl.Value) & ";button=" & CStr(Button) & ";shift=" & CStr(Shift) & "|"
    Exit Sub
Failed:
    mFailure = CStr(Err.Number) & ":" & Err.Description
End Sub
Private Sub TabsControl_MouseUp(ByVal Index As Long, ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mTrace = mTrace & "TabsControl.MouseUp:index=" & CStr(Index) & ";value=" & CStr(TabsControl.Value) & ";button=" & CStr(Button) & ";shift=" & CStr(Shift) & "|"
    Exit Sub
Failed:
    mFailure = CStr(Err.Number) & ":" & Err.Description
End Sub
Private Sub PagesControl_MouseDown(ByVal Index As Long, ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mTrace = mTrace & "PagesControl.MouseDown:index=" & CStr(Index) & ";value=" & CStr(PagesControl.Value) & ";button=" & CStr(Button) & ";shift=" & CStr(Shift) & "|"
    Exit Sub
Failed:
    mFailure = CStr(Err.Number) & ":" & Err.Description
End Sub
Private Sub PagesControl_MouseUp(ByVal Index As Long, ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mTrace = mTrace & "PagesControl.MouseUp:index=" & CStr(Index) & ";value=" & CStr(PagesControl.Value) & ";button=" & CStr(Button) & ";shift=" & CStr(Shift) & "|"
    Exit Sub
Failed:
    mFailure = CStr(Err.Number) & ":" & Err.Description
End Sub