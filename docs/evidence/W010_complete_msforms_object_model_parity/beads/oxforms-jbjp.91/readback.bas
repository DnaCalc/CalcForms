Option Explicit
Public Function Run4InputState() As String
    On Error GoTo Failed
    Run4InputState = LayoutCommon.InputState()
    Exit Function
Failed:
    Run4InputState = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
