Option Explicit
Public LifeInitialized As Long
Public LifeTerminated As Long
Private Function Counts(ByVal StepName As String) As String
    Counts = StepName & ";initialize=" & CStr(LifeInitialized) & ";terminate=" & CStr(LifeTerminated) & vbLf
End Function
Public Function ObserveRelease() As String
    On Error GoTo Failed
    Dim F As WorkbookGreeter, G As WorkbookGreeter, C As MSForms.TextBox
    Dim S As String, N As Long
    Unload WorkbookGreeter
    LifeInitialized = 0
    LifeTerminated = 0
    Set F = New WorkbookGreeter
    S = Counts("explicit-new")
    Unload F
    S = S & Counts("explicit-unload")
    Set F = Nothing
    S = S & Counts("explicit-release")
    Set F = WorkbookGreeter
    S = S & Counts("default-created")
    Set G = WorkbookGreeter
    S = S & "same-default=" & CStr(F Is G) & vbLf
    Unload F
    S = S & Counts("default-unload-held")
    Set G = Nothing
    S = S & Counts("one-form-held")
    Set F = Nothing
    S = S & Counts("last-form-release")
    Set F = WorkbookGreeter
    Set C = F.InputName
    C.Text = "retained-control"
    S = S & Counts("control-held")
    Unload F
    S = S & Counts("control-unload")
    On Error Resume Next
    Err.Clear
    S = S & "old-control-text=" & C.Text & ";error=" & CStr(Err.Number) & vbLf
    Err.Clear
    C.Text = "after-unload"
    N = Err.Number
    S = S & "old-control-write-error=" & CStr(N) & vbLf
    On Error GoTo Failed
    Set F = Nothing
    S = S & Counts("only-control-held")
    Set C = Nothing
    S = S & Counts("last-control-release")
    ObserveRelease = S
    Exit Function
Failed:
    ObserveRelease = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description & vbLf & S
End Function
