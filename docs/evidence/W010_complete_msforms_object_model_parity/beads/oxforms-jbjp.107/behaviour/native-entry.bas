Option Explicit
Public Function ParityNativeMeasurements() As String
    On Error GoTo Failed
    Dim F As Object
    Set F = LayoutCaptureForm()
    ParityNativeMeasurements = F.ParityMeasurements()
    Exit Function
Failed:
    ParityNativeMeasurements = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
