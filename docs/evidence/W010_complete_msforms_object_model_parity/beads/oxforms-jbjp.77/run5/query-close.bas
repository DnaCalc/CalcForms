Option Explicit
Public Run5EventLog As String
Public Function Run5QueryClose() As String
    On Error GoTo Failed
    Unload WorkbookGreeter
    Load WorkbookGreeter
    Run5EventLog = ""
    WorkbookGreeter.Show vbModeless
    WorkbookGreeter.InputName.Text = "veto"
    Unload WorkbookGreeter
    Dim S As String
    S = "veto;visible=" & CStr(WorkbookGreeter.Visible) & ";" & Run5EventLog & vbLf
    WorkbookGreeter.InputName.Text = "ok"
    Unload WorkbookGreeter
    S = S & "allowed;" & Run5EventLog & vbLf
    Run5QueryClose = S
    Exit Function
Failed:
    Run5QueryClose = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
