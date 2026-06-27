Option Explicit

' W006 CheckBox Space/Enter keyboard-toggle oracle UserForm code-behind.
'
' ToggleCheck fills the form, so a single click at the window centre focuses it.
' The capture then sends Space (VK 0x20) then Enter (VK 0x0D) via public user32
' SendInput. Every handler logs its sequence AND the control's .Value at handler
' entry, so the export shows the Click/Change/KeyDown/KeyUp ordering and whether
' .Value is already toggled when each handler runs (value_at_keydown vs
' value_at_keyup). The KeyDown/KeyUp handlers also log the KeyCode helper .Value
' before and after the handler body so any MSForms mutation is observable. No
' OxForms runtime behaviour is implied.

Private Sub UserForm_Initialize()
    W006CheckBoxKbdLog Me.Name, "ToggleCheck", "Initialize", CStr(ToggleCheck.Value), "", "", "form initialize"
End Sub

Private Sub ToggleCheck_Click()
    W006CheckBoxKbdLog Me.Name, "ToggleCheck", "Click", CStr(ToggleCheck.Value), "", "", "Click handler; .Value read at handler entry"
End Sub

Private Sub ToggleCheck_Change()
    W006CheckBoxKbdLog Me.Name, "ToggleCheck", "Change", CStr(ToggleCheck.Value), "", "", "Change handler; .Value read at handler entry"
End Sub

Private Sub ToggleCheck_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    Dim keyCodeBefore As String
    keyCodeBefore = ReturnHelperValueText(KeyCode)
    W006CheckBoxKbdLog Me.Name, "ToggleCheck", "KeyDown", CStr(ToggleCheck.Value), _
        keyCodeBefore, ReturnHelperValueText(KeyCode), _
        "KeyDown; Shift=" & CStr(Shift) & "; value read at handler entry (value_at_keydown)"
End Sub

Private Sub ToggleCheck_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    Dim keyCodeBefore As String
    keyCodeBefore = ReturnHelperValueText(KeyCode)
    W006CheckBoxKbdLog Me.Name, "ToggleCheck", "KeyUp", CStr(ToggleCheck.Value), _
        keyCodeBefore, ReturnHelperValueText(KeyCode), _
        "KeyUp; Shift=" & CStr(Shift) & "; value read at handler entry (value_at_keyup)"
End Sub

Private Function ReturnHelperValueText(ByVal helper As Object) As String
    On Error GoTo Failed
    ReturnHelperValueText = CStr(helper.Value)
    Exit Function
Failed:
    ReturnHelperValueText = "<unavailable>"
End Function
