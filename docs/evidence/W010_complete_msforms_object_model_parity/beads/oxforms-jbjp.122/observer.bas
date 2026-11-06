Option Explicit
Public Function Run8GreeterPrepare(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload WorkbookGreeter
    Load WorkbookGreeter
    Dim W As Single, H As Single
    W = WorkbookGreeter.InsideWidth
    H = WorkbookGreeter.InsideHeight
    WorkbookGreeter.Zoom = Zoom
    WorkbookGreeter.Width = WorkbookGreeter.Width + W * (Zoom / 100 - 1)
    WorkbookGreeter.Height = WorkbookGreeter.Height + H * (Zoom / 100 - 1)
    WorkbookGreeter.Show vbModeless
    Run8GreeterPrepare = WorkbookGreeter.ActiveControl.Name & ";" & CStr(W) & ";" & CStr(H)
    Exit Function
Failed:
    Run8GreeterPrepare = "CALCFORMS_NATIVE_ERROR:prepare:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function Run8GreeterForm() As Object
    On Error GoTo Failed
    Set Run8GreeterForm = WorkbookGreeter
    Exit Function
Failed:
    Err.Raise Err.Number, "GreeterForm", Err.Description
End Function
Public Function Run8GreeterState() As String
    On Error GoTo Failed
    Run8GreeterState = WorkbookGreeter.State()
    Exit Function
Failed:
    Run8GreeterState = "CALCFORMS_NATIVE_ERROR:state:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function Run8GreeterTrace(ByVal Reset As Boolean) As String
    On Error GoTo Failed
    Run8GreeterTrace = WorkbookGreeter.ParityInputTrace(Reset)
    Exit Function
Failed:
    Run8GreeterTrace = "CALCFORMS_NATIVE_ERROR:trace:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Sub Run8GreeterFinish()
    On Error GoTo Failed
    Unload WorkbookGreeter
    Exit Sub
Failed:
    Err.Raise Err.Number, "GreeterFinish", Err.Description
End Sub
