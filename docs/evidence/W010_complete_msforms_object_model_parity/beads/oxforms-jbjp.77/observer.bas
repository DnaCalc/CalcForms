Option Explicit
Public Function Run4Lifetime() As String
    On Error GoTo Failed
    Dim Held As WorkbookGreeter, Again As WorkbookGreeter
    Dim Fresh As WorkbookGreeter, ExplicitForm As WorkbookGreeter
    Dim S As String
    Unload WorkbookGreeter
    Load WorkbookGreeter
    Set Held = WorkbookGreeter
    Set Again = WorkbookGreeter
    S = "loaded;same=" & CStr(Held Is Again) & ";" & Held.State() & vbLf
    WorkbookGreeter.Show vbModeless
    WorkbookGreeter.InputName.Text = "Lifetime"
    WorkbookGreeter.Hide
    S = S & "hidden;visible=" & CStr(WorkbookGreeter.Visible) & ";" & WorkbookGreeter.State() & vbLf
    WorkbookGreeter.Show vbModeless
    S = S & "reshown;same=" & CStr(Held Is WorkbookGreeter) & ";visible=" & CStr(WorkbookGreeter.Visible) & ";" & WorkbookGreeter.State() & vbLf
    Unload WorkbookGreeter
    S = S & "unloaded-held;same=" & CStr(Held Is Again) & vbLf
    Load WorkbookGreeter
    Set Fresh = WorkbookGreeter
    S = S & "default-after-unload;same=" & CStr(Held Is Fresh) & ";" & Fresh.State() & vbLf
    Set ExplicitForm = New WorkbookGreeter
    Load ExplicitForm
    S = S & "explicit-new;same-default=" & CStr(ExplicitForm Is Fresh) & ";" & ExplicitForm.State() & vbLf
    ExplicitForm.InputName.Text = "Explicit"
    S = S & "default-after-explicit;" & Fresh.State() & vbLf
    S = S & "explicit-edited;" & ExplicitForm.State() & vbLf
    Unload ExplicitForm
    Unload Fresh
    Set ExplicitForm = Nothing
    Set Held = Nothing
    Set Again = Nothing
    Set Fresh = Nothing
    Unload WorkbookGreeter
    Run4Lifetime = S
    Exit Function
Failed:
    Run4Lifetime = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description & vbLf & S
    On Error Resume Next
    Unload ExplicitForm
    Unload Held
    Unload Fresh
    Unload WorkbookGreeter
End Function
