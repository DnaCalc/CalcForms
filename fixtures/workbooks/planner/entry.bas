Option Explicit
Public Sub OpenPlanner()
    On Error GoTo Failed
    PlannerForm.Show vbModeless
    Exit Sub
Failed:
    Err.Raise Err.Number, "OpenPlanner", Err.Description
End Sub
Public Function PlannerState() As String
    On Error GoTo Failed
    PlannerState = PlannerForm.State()
    Exit Function
Failed:
    PlannerState = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function PlannerTrace() As String
    On Error GoTo Failed
    PlannerTrace = PlannerForm.Trace()
    Exit Function
Failed:
    PlannerTrace = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
