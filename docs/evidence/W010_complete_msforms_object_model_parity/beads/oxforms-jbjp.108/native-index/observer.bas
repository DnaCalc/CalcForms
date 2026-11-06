Option Explicit
Public Function Run8TabPrepare(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Load Run8TabFormTwo
    Run8TabFormTwo.Zoom = Zoom
    Run8TabFormTwo.TabsControl.Value = 0
    Run8TabFormTwo.PagesControl.Value = 0
    Run8TabFormTwo.Show vbModeless
    Run8TabPrepare = Run8TabFormTwo.Snapshot(True)
    Exit Function
Failed:
    Run8TabPrepare = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function Run8TabSnapshot() As String
    Run8TabSnapshot = Run8TabFormTwo.Snapshot(True)
End Function
Public Sub Run8TabFinish()
    Unload Run8TabFormTwo
End Sub
