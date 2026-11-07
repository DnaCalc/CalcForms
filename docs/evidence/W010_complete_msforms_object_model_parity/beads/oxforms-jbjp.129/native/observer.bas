Option Explicit
Public Sub GreeterUnloadDefault()
    On Error GoTo Failed
    Unload WorkbookGreeter
    Exit Sub
Failed:
    Err.Raise Err.Number, "GreeterUnloadDefault", Err.Description
End Sub
