Option Explicit

' W006 Ctrl+V keyboard-ordering oracle UserForm code-behind.
'
' TextBox1 fills the form so a single window-centre click focuses it. The capture
' seeds the public Windows clipboard with a repo-owned text value, then sends
' Ctrl+V via public user32 SendInput. These handlers log, in sequence, every
' keyboard event (KeyDown/KeyPress/KeyUp) and the paste/value events
' (BeforeDropOrPaste/Change) that real Excel/MSForms raises for that injected
' Ctrl+V, so the export shows the keyboard-vs-paste-vs-Change ordering.
'
' For every MSForms.Return* helper argument the handler logs .Value before and
' after the handler body (arg_before/arg_after) so any helper mutation by MSForms
' itself is observable. The value column carries the TextBox1 .Value read at
' handler entry. No OxForms runtime behaviour is implied.
'
' BeforeDropOrPaste signature note: a plain TextBox uses the MdcTextEvents source
' interface, whose BeforeDropOrPaste has NO leading Index argument. The public
' argument order is Cancel, Action, Data, X, Y, Effect, Shift (docs/specs/
' FM20_EVENT_FACTS.md line for BeforeDropOrPaste; matches the live text-service-
' transfer fixture). MultiPage/TabStrip would add an Index As Long; a TextBox
' does not.

Private Sub UserForm_Initialize()
    W006CtrlVLog "TextBox1", "Initialize", "", "", "", CStr(TextBox1.Value), "form initialize"
End Sub

Private Sub TextBox1_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    Dim keyCodeBefore As String
    keyCodeBefore = ReturnHelperValueText(KeyCode)
    W006CtrlVLog "TextBox1", "KeyDown", "KeyCode", keyCodeBefore, ReturnHelperValueText(KeyCode), _
        CStr(TextBox1.Value), "KeyDown; Shift=" & CStr(Shift)
End Sub

Private Sub TextBox1_KeyPress(ByVal KeyAscii As MSForms.ReturnInteger)
    Dim keyAsciiBefore As String
    keyAsciiBefore = ReturnHelperValueText(KeyAscii)
    W006CtrlVLog "TextBox1", "KeyPress", "KeyAscii", keyAsciiBefore, ReturnHelperValueText(KeyAscii), _
        CStr(TextBox1.Value), "KeyPress"
End Sub

Private Sub TextBox1_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    Dim keyCodeBefore As String
    keyCodeBefore = ReturnHelperValueText(KeyCode)
    W006CtrlVLog "TextBox1", "KeyUp", "KeyCode", keyCodeBefore, ReturnHelperValueText(KeyCode), _
        CStr(TextBox1.Value), "KeyUp; Shift=" & CStr(Shift)
End Sub

Private Sub TextBox1_BeforeDropOrPaste( _
        ByVal Cancel As MSForms.ReturnBoolean, _
        ByVal Action As MSForms.fmAction, _
        ByVal Data As MSForms.DataObject, _
        ByVal X As Single, _
        ByVal Y As Single, _
        ByVal Effect As MSForms.ReturnEffect, _
        ByVal Shift As Integer)
    Dim cancelBefore As String
    Dim effectBefore As String
    cancelBefore = ReturnHelperValueText(Cancel)
    effectBefore = ReturnHelperValueText(Effect)
    W006CtrlVLog "TextBox1", "BeforeDropOrPaste", "Cancel", cancelBefore, ReturnHelperValueText(Cancel), _
        CStr(TextBox1.Value), _
        "Action=" & CStr(Action) & "; Effect_before=" & effectBefore & "; Effect_after=" & ReturnHelperValueText(Effect) & _
        "; X=" & CStr(X) & "; Y=" & CStr(Y) & "; Shift=" & CStr(Shift) & "; " & DataObjectObservationText(Data)
End Sub

Private Sub TextBox1_Change()
    W006CtrlVLog "TextBox1", "Change", "", "", "", CStr(TextBox1.Value), "Change handler; .Value read at handler entry"
End Sub

Private Function ReturnHelperValueText(ByVal helper As Object) As String
    On Error GoTo Failed
    ReturnHelperValueText = CStr(helper.Value)
    Exit Function
Failed:
    ReturnHelperValueText = "<unavailable>"
End Function

Private Function DataObjectObservationText(ByVal Data As MSForms.DataObject) As String
    On Error GoTo Failed
    If Data Is Nothing Then
        DataObjectObservationText = "data_object=nothing"
        Exit Function
    End If
    DataObjectObservationText = "data_object=present; public_getformat_1=" & CStr(Data.GetFormat(1))
    Exit Function
Failed:
    DataObjectObservationText = "data_object_observation_error=" & Err.Number & ":" & Err.Description
End Function
