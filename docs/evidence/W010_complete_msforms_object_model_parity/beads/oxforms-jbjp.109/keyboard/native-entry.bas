Option Explicit
Public Function ParityScroll(ByVal Prepare As Boolean) As String
    On Error GoTo Failed
    Dim F As Object
    Set F = LayoutCaptureForm()
    ParityScroll = F.ParityScroll(Prepare)
    Exit Function
Failed:
    ParityScroll = "CALCFORMS_NATIVE_ERROR:scroll-entry:" & CStr(Err.Number) & ":" & Err.Description
End Function
