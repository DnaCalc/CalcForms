Option Explicit

' Held form. Instances are stashed in the standard module global gHeldRef. The
' Hide/Unload buttons drive the modal return when this form is shown modal from a
' launcher button _Click; injected input clicks them. Lifecycle handlers
' (QueryClose, Terminate) log the held-reference state columns visible at handler
' entry so the held-reference residual dimension is recorded alongside the
' already-captured ordering (oxforms-0a0.24).

Private Sub UserForm_Initialize()
    W006HeldRefAppendLog Me, "held", "OxFormsW006HeldRefForm", "MSForms.UserForm", "Initialize", "msforms_event", "no arguments", handlerName:="UserForm_Initialize"
End Sub

Private Sub UserForm_Activate()
    W006HeldRefAppendLog Me, "held", "OxFormsW006HeldRefForm", "MSForms.UserForm", "Activate", "msforms_event", "no arguments", handlerName:="UserForm_Activate"
End Sub

Private Sub UserForm_Deactivate()
    W006HeldRefAppendLog Me, "held", "OxFormsW006HeldRefForm", "MSForms.UserForm", "Deactivate", "msforms_event", "no arguments", handlerName:="UserForm_Deactivate"
End Sub

Private Sub UserForm_QueryClose(Cancel As Integer, CloseMode As Integer)
    Dim cancelBefore As Integer
    Dim origin As String

    cancelBefore = Cancel
    origin = W006HeldRefCurrentCloseOrigin()
    If Len(origin) = 0 Then
        origin = "held_queryclose_unknown_public_close_origin"
    End If

    W006HeldRefAppendLog Me, "held", "OxFormsW006HeldRefForm", "MSForms.UserForm", "QueryClose", "msforms_event", "Cancel As Integer; CloseMode As Integer", handlerName:="UserForm_QueryClose", closeOrigin:=origin, cancelBefore:=cancelBefore, cancelAfter:=Cancel, closeMode:=CloseMode
End Sub

Private Sub UserForm_Terminate()
    W006HeldRefAppendLog Me, "held", "OxFormsW006HeldRefForm", "MSForms.UserForm", "Terminate", "msforms_event", "no arguments", handlerName:="UserForm_Terminate", notes:="Terminate row records the fixture held-reference state columns visible to repo-owned VBA at handler entry."
End Sub

Private Sub HeldHideButton_Click()
    W006HeldRefSetCloseOrigin "held_hide_button"
    W006HeldRefAppendLog Me, "held", "HeldHideButton", "MSForms.CommandButton", "Click", "msforms_event", "no arguments", handlerName:="HeldHideButton_Click", actionName:="click"
    W006HeldRefAppendLog Me, "held", "OxFormsW006HeldRefForm", "MSForms.UserForm", "BeforeHide", "fixture_action", "fixture action", handlerName:="HeldHideButton_Click", actionName:="hide_held", closeOrigin:="held_hide_button", notes:="Calling Me.Hide from the held modal button Click handler; the global held reference is still active."
    Me.Hide
    W006HeldRefAppendLog Me, "held", "OxFormsW006HeldRefForm", "MSForms.UserForm", "AfterHide", "fixture_action", "fixture action", handlerName:="HeldHideButton_Click", actionName:="hide_held_return", closeOrigin:="held_hide_button", notes:="VBA code resumed after Me.Hide; this row does not imply Terminate."
End Sub

Private Sub HeldUnloadButton_Click()
    W006HeldRefSetCloseOrigin "held_unload_button"
    W006HeldRefAppendLog Me, "held", "HeldUnloadButton", "MSForms.CommandButton", "Click", "msforms_event", "no arguments", handlerName:="HeldUnloadButton_Click", actionName:="click"
    W006HeldRefAppendLog Me, "held", "OxFormsW006HeldRefForm", "MSForms.UserForm", "BeforeUnload", "fixture_action", "fixture action", handlerName:="HeldUnloadButton_Click", actionName:="unload_held", closeOrigin:="held_unload_button", notes:="Calling Unload Me from the held modal button Click handler; the global held reference is still active."
    Unload Me
    W006HeldRefAppendLog Me, "held", "OxFormsW006HeldRefForm", "MSForms.UserForm", "AfterUnload", "fixture_action", "fixture action", handlerName:="HeldUnloadButton_Click", actionName:="unload_held_return", closeOrigin:="held_unload_button", notes:="This row is present only if VBA code resumes after Unload Me."
End Sub
