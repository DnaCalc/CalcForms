Option Explicit

Private Sub UserForm_Initialize()
    W006TerminateAppendLog Me, "OxFormsW006TerminateForm", "MSForms.UserForm", "Initialize", "msforms_event", "no arguments", handlerName:="UserForm_Initialize"
End Sub

Private Sub UserForm_Activate()
    W006TerminateAppendLog Me, "OxFormsW006TerminateForm", "MSForms.UserForm", "Activate", "msforms_event", "no arguments", handlerName:="UserForm_Activate"
    W006TerminateMaybeRunAutoAction Me
End Sub

Private Sub UserForm_Deactivate()
    W006TerminateAppendLog Me, "OxFormsW006TerminateForm", "MSForms.UserForm", "Deactivate", "msforms_event", "no arguments", handlerName:="UserForm_Deactivate"
End Sub

Private Sub UserForm_QueryClose(Cancel As Integer, CloseMode As Integer)
    Dim cancelBefore As Integer
    cancelBefore = Cancel
    W006TerminateAppendLog Me, "OxFormsW006TerminateForm", "MSForms.UserForm", "QueryClose", "msforms_event", "Cancel As Integer; CloseMode As Integer", handlerName:="UserForm_QueryClose", closeOrigin:=W006TerminateCurrentCloseOrigin(), cancelBefore:=cancelBefore, cancelAfter:=Cancel, closeMode:=CloseMode
End Sub

Private Sub UserForm_Terminate()
    W006TerminateAppendLog Me, "OxFormsW006TerminateForm", "MSForms.UserForm", "Terminate", "msforms_event", "no arguments", handlerName:="UserForm_Terminate", notes:="Terminate row records the fixture reference-state columns visible to repo-owned VBA at handler entry."
End Sub
