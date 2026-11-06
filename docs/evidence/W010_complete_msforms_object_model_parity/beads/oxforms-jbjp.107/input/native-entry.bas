Option Explicit
Public Function ParityInputTrace(ByVal Reset As Boolean) As String
    On Error GoTo Failed
    Dim F As Object
    Set F = LayoutCaptureForm()
    ParityInputTrace = F.ParityInputTrace(Reset)
    Exit Function
Failed:
    ParityInputTrace = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
