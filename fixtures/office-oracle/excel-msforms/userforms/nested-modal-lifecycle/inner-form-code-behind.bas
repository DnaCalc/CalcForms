Option Explicit

Private Sub UserForm_Initialize()
    W006NestedAppendLog Me, "inner", "OxFormsW006NestedInner", "MSForms.UserForm", "Initialize", "no arguments", handlerName:="UserForm_Initialize"
End Sub

Private Sub UserForm_Activate()
    W006NestedAppendLog Me, "inner", "OxFormsW006NestedInner", "MSForms.UserForm", "Activate", "no arguments", handlerName:="UserForm_Activate"
End Sub

Private Sub UserForm_Deactivate()
    W006NestedAppendLog Me, "inner", "OxFormsW006NestedInner", "MSForms.UserForm", "Deactivate", "no arguments", handlerName:="UserForm_Deactivate"
End Sub

Private Sub UserForm_QueryClose(Cancel As Integer, CloseMode As Integer)
    Dim cancelBefore As Integer
    Dim origin As String

    cancelBefore = Cancel
    origin = W006NestedCurrentCloseOrigin()
    If Len(origin) = 0 Then
        origin = "inner_queryclose_unknown_public_close_origin"
    End If

    W006NestedAppendLog Me, "inner", "OxFormsW006NestedInner", "MSForms.UserForm", "QueryClose", "Cancel As Integer; CloseMode As Integer", handlerName:="UserForm_QueryClose", closeOrigin:=origin, cancelBefore:=cancelBefore, cancelAfter:=Cancel, closeMode:=CloseMode
End Sub

Private Sub UserForm_Terminate()
    W006NestedAppendLog Me, "inner", "OxFormsW006NestedInner", "MSForms.UserForm", "Terminate", "no arguments", handlerName:="UserForm_Terminate"
End Sub

Private Sub InnerHideButton_Click()
    W006NestedSetCloseOrigin "inner_hide_button"
    W006NestedAppendLog Me, "inner", "InnerHideButton", "MSForms.CommandButton", "Click", "no arguments", handlerName:="InnerHideButton_Click", actionName:="click"
    W006NestedAppendLog Me, "inner", "OxFormsW006NestedInner", "MSForms.UserForm", "BeforeHide", "fixture action", handlerName:="InnerHideButton_Click", actionName:="hide_inner", closeOrigin:="inner_hide_button", notes:="Calling Me.Hide from the inner modal button Click handler."
    Me.Hide
    W006NestedAppendLog Me, "inner", "OxFormsW006NestedInner", "MSForms.UserForm", "AfterHide", "fixture action", handlerName:="InnerHideButton_Click", actionName:="hide_inner_return", closeOrigin:="inner_hide_button", notes:="VBA code resumed after Me.Hide."
End Sub

Private Sub InnerUnloadButton_Click()
    W006NestedSetCloseOrigin "inner_unload_button"
    W006NestedAppendLog Me, "inner", "InnerUnloadButton", "MSForms.CommandButton", "Click", "no arguments", handlerName:="InnerUnloadButton_Click", actionName:="click"
    W006NestedAppendLog Me, "inner", "OxFormsW006NestedInner", "MSForms.UserForm", "BeforeUnload", "fixture action", handlerName:="InnerUnloadButton_Click", actionName:="unload_inner", closeOrigin:="inner_unload_button", notes:="Calling Unload Me from the inner modal button Click handler."
    Unload Me
    W006NestedAppendLog Me, "inner", "OxFormsW006NestedInner", "MSForms.UserForm", "AfterUnload", "fixture action", handlerName:="InnerUnloadButton_Click", actionName:="unload_inner_return", closeOrigin:="inner_unload_button", notes:="This row is present only if VBA code resumes after Unload Me."
End Sub
