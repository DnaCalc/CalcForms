Option Explicit

' Launcher form. Its CommandButton _Click handlers are the ONLY place a held
' form is entered with Show vbModal. Running Show vbModal from a button _Click is
' event-driven and does not block the host COM thread the way an excel.Run-driven
' Show vbModal would. After the held modal returns (because injected input clicked
' the held form's own Hide/Unload button), the SAME _Click handler releases the
' global held reference and logs the held-reference state. The held-reference state
' dimension is the in-scope residual; ordering is already captured in oxforms-0a0.24.

Private Sub UserForm_Initialize()
    W006HeldRefAppendLog Me, "launcher", "OxFormsW006HeldRefLauncher", "MSForms.UserForm", "Initialize", "msforms_event", "no arguments", handlerName:="UserForm_Initialize"
End Sub

Private Sub UserForm_Activate()
    W006HeldRefAppendLog Me, "launcher", "OxFormsW006HeldRefLauncher", "MSForms.UserForm", "Activate", "msforms_event", "no arguments", handlerName:="UserForm_Activate"
End Sub

Private Sub UserForm_Deactivate()
    W006HeldRefAppendLog Me, "launcher", "OxFormsW006HeldRefLauncher", "MSForms.UserForm", "Deactivate", "msforms_event", "no arguments", handlerName:="UserForm_Deactivate"
End Sub

Private Sub UserForm_QueryClose(Cancel As Integer, CloseMode As Integer)
    Dim cancelBefore As Integer
    cancelBefore = Cancel
    W006HeldRefAppendLog Me, "launcher", "OxFormsW006HeldRefLauncher", "MSForms.UserForm", "QueryClose", "msforms_event", "Cancel As Integer; CloseMode As Integer", handlerName:="UserForm_QueryClose", closeOrigin:=W006HeldRefCurrentCloseOrigin(), cancelBefore:=cancelBefore, cancelAfter:=Cancel, closeMode:=CloseMode
End Sub

Private Sub UserForm_Terminate()
    W006HeldRefAppendLog Me, "launcher", "OxFormsW006HeldRefLauncher", "MSForms.UserForm", "Terminate", "msforms_event", "no arguments", handlerName:="UserForm_Terminate"
End Sub

Private Sub LauncherModalHideButton_Click()
    W006HeldRefAppendLog Me, "launcher", "LauncherModalHideButton", "MSForms.CommandButton", "Click", "msforms_event", "no arguments", handlerName:="LauncherModalHideButton_Click", actionName:="click"
    W006HeldRefRunModalHeldScenario "modal_hide_return", "modal_hide_from_button", "hide"
End Sub

Private Sub LauncherModalUnloadButton_Click()
    W006HeldRefAppendLog Me, "launcher", "LauncherModalUnloadButton", "MSForms.CommandButton", "Click", "msforms_event", "no arguments", handlerName:="LauncherModalUnloadButton_Click", actionName:="click"
    W006HeldRefRunModalHeldScenario "modal_unload_return", "modal_unload_from_button", "unload"
End Sub

Private Sub LauncherCloseButton_Click()
    W006HeldRefSetCloseOrigin "launcher_close_button"
    W006HeldRefAppendLog Me, "launcher", "LauncherCloseButton", "MSForms.CommandButton", "Click", "msforms_event", "no arguments", handlerName:="LauncherCloseButton_Click", actionName:="click"
    W006HeldRefAppendLog Me, "launcher", "OxFormsW006HeldRefLauncher", "MSForms.UserForm", "BeforeUnloadLauncher", "fixture_action", "fixture action", handlerName:="LauncherCloseButton_Click", actionName:="unload_launcher", closeOrigin:="launcher_close_button", notes:="Calling Unload Me from the launcher close button Click handler."
    Unload Me
End Sub
