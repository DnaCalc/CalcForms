Option Explicit
Public Function Run5TextAssignments() As String
    On Error GoTo Failed
    Unload WorkbookGreeter
    Load WorkbookGreeter
    Dim S As String
    WorkbookGreeter.InputName.Text = "A&B"
    S = WorkbookGreeter.State() & vbLf
    WorkbookGreeter.InputName.Text = "A&B"
    S = S & WorkbookGreeter.State() & vbLf
    WorkbookGreeter.InputName.Value = "A&&B"
    S = S & WorkbookGreeter.State() & vbLf
    WorkbookGreeter.InputName.SelStart = 1
    WorkbookGreeter.InputName.SelLength = 2
    WorkbookGreeter.InputName.SelText = "&"
    S = S & WorkbookGreeter.State() & vbLf
    Run5TextAssignments = S
    Exit Function
Failed:
    Run5TextAssignments = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
