Option Explicit

Private Sub UserForm_Initialize()
    W006NestedAppendLog Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "Initialize", "no arguments", handlerName:="UserForm_Initialize"
End Sub

Private Sub UserForm_Activate()
    W006NestedAppendLog Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "Activate", "no arguments", handlerName:="UserForm_Activate"
End Sub

Private Sub UserForm_Deactivate()
    W006NestedAppendLog Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "Deactivate", "no arguments", handlerName:="UserForm_Deactivate"
End Sub

Private Sub UserForm_QueryClose(Cancel As Integer, CloseMode As Integer)
    Dim cancelBefore As Integer
    cancelBefore = Cancel
    W006NestedAppendLog Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "QueryClose", "Cancel As Integer; CloseMode As Integer", handlerName:="UserForm_QueryClose", closeOrigin:=W006NestedCurrentCloseOrigin(), cancelBefore:=cancelBefore, cancelAfter:=Cancel, closeMode:=CloseMode
End Sub

Private Sub UserForm_Terminate()
    W006NestedAppendLog Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "Terminate", "no arguments", handlerName:="UserForm_Terminate"
End Sub

Private Sub OuterShowInnerHideButton_Click()
    Dim parentRow As Long

    W006NestedSetCurrentScenario "inner_hide_button"
    W006NestedSetCloseOrigin ""
    W006NestedAppendLog Me, "outer", "OuterShowInnerHideButton", "MSForms.CommandButton", "Click", "no arguments", handlerName:="OuterShowInnerHideButton_Click", actionName:="click"
    parentRow = W006NestedAppendLog(Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "BeforeInnerShowModal", "fixture action", handlerName:="OuterShowInnerHideButton_Click", actionName:="show_inner_modal", closeOrigin:="outer_show_inner_hide_button", notes:="Calling inner UserForm.Show vbModal from the outer button Click handler.")
    W006NestedSetModalParentRowId parentRow
    W006NestedShowInnerModal "inner_hide_button"
    W006NestedClearModalParentRowId
    W006NestedSetCloseOrigin ""
    W006NestedAppendLog Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "AfterInnerShowModalReturn", "fixture action", handlerName:="OuterShowInnerHideButton_Click", actionName:="inner_modal_return", closeOrigin:="inner_hide_button", notes:="Outer handler resumed after the inner modal frame returned.", parentRowId:=parentRow
End Sub

Private Sub OuterShowInnerUnloadButton_Click()
    Dim parentRow As Long

    W006NestedSetCurrentScenario "inner_unload_button"
    W006NestedSetCloseOrigin ""
    W006NestedAppendLog Me, "outer", "OuterShowInnerUnloadButton", "MSForms.CommandButton", "Click", "no arguments", handlerName:="OuterShowInnerUnloadButton_Click", actionName:="click"
    parentRow = W006NestedAppendLog(Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "BeforeInnerShowModal", "fixture action", handlerName:="OuterShowInnerUnloadButton_Click", actionName:="show_inner_modal", closeOrigin:="outer_show_inner_unload_button", notes:="Calling inner UserForm.Show vbModal from the outer button Click handler.")
    W006NestedSetModalParentRowId parentRow
    W006NestedShowInnerModal "inner_unload_button"
    W006NestedClearModalParentRowId
    W006NestedSetCloseOrigin ""
    W006NestedAppendLog Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "AfterInnerShowModalReturn", "fixture action", handlerName:="OuterShowInnerUnloadButton_Click", actionName:="inner_modal_return", closeOrigin:="inner_unload_button", notes:="Outer handler resumed after the inner modal frame returned.", parentRowId:=parentRow
End Sub

Private Sub OuterShowInnerCloseButton_Click()
    Dim parentRow As Long

    W006NestedSetCurrentScenario "inner_system_close_alt_f4"
    W006NestedSetCloseOrigin "inner_system_close_alt_f4"
    W006NestedAppendLog Me, "outer", "OuterShowInnerCloseButton", "MSForms.CommandButton", "Click", "no arguments", handlerName:="OuterShowInnerCloseButton_Click", actionName:="click"
    parentRow = W006NestedAppendLog(Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "BeforeInnerShowModal", "fixture action", handlerName:="OuterShowInnerCloseButton_Click", actionName:="show_inner_modal", closeOrigin:="outer_show_inner_close_button", notes:="Calling inner UserForm.Show vbModal from the outer button Click handler; public automation will send Alt+F4 to the inner modal window.")
    W006NestedSetModalParentRowId parentRow
    W006NestedShowInnerModal "inner_system_close_alt_f4"
    W006NestedClearModalParentRowId
    W006NestedSetCloseOrigin ""
    W006NestedAppendLog Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "AfterInnerShowModalReturn", "fixture action", handlerName:="OuterShowInnerCloseButton_Click", actionName:="inner_modal_return", closeOrigin:="inner_system_close_alt_f4", notes:="Outer handler resumed after the inner modal frame returned.", parentRowId:=parentRow
End Sub

Private Sub OuterHideButton_Click()
    W006NestedSetCurrentScenario "outer_hide_button"
    W006NestedSetCloseOrigin "outer_hide_button"
    W006NestedAppendLog Me, "outer", "OuterHideButton", "MSForms.CommandButton", "Click", "no arguments", handlerName:="OuterHideButton_Click", actionName:="click"
    W006NestedAppendLog Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "BeforeHide", "fixture action", handlerName:="OuterHideButton_Click", actionName:="hide_outer", closeOrigin:="outer_hide_button", notes:="Calling Me.Hide from the outer button Click handler."
    Me.Hide
    W006NestedAppendLog Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "AfterHide", "fixture action", handlerName:="OuterHideButton_Click", actionName:="hide_outer_return", closeOrigin:="outer_hide_button", notes:="VBA code resumed after Me.Hide."
End Sub

Private Sub OuterUnloadButton_Click()
    W006NestedSetCurrentScenario "outer_unload_button"
    W006NestedSetCloseOrigin "outer_unload_button"
    W006NestedAppendLog Me, "outer", "OuterUnloadButton", "MSForms.CommandButton", "Click", "no arguments", handlerName:="OuterUnloadButton_Click", actionName:="click"
    W006NestedAppendLog Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "BeforeUnload", "fixture action", handlerName:="OuterUnloadButton_Click", actionName:="unload_outer", closeOrigin:="outer_unload_button", notes:="Calling Unload Me from the outer button Click handler."
    Unload Me
    W006NestedAppendLog Me, "outer", "OxFormsW006NestedOuter", "MSForms.UserForm", "AfterUnload", "fixture action", handlerName:="OuterUnloadButton_Click", actionName:="unload_outer_return", closeOrigin:="outer_unload_button", notes:="This row is present only if VBA code resumes after Unload Me."
End Sub
