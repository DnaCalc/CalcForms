Option Explicit
Public Function PlannerPrepare(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload PlannerForm
    Load PlannerForm
    PlannerForm.Zoom = Zoom
    PlannerForm.Show vbModeless
    PlannerPrepare = PlannerForm.State()
    Exit Function
Failed:
    PlannerPrepare = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function PlannerSet(ByVal ControlName As String, ByVal Value As Long) As Long
    On Error GoTo Failed
    PlannerForm.Controls(ControlName).Value = Value
    Exit Function
Failed:
    PlannerSet = Err.Number
End Function
Public Sub PlannerFinish()
    On Error GoTo Failed
    Unload PlannerForm
    Exit Sub
Failed:
    Err.Raise Err.Number, "PlannerFinish", Err.Description
End Sub
