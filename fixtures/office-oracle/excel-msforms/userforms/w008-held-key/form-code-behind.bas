Option Explicit

' W008 held-key oracle UserForm code-behind.
'
' Key, click, change, and focus handlers each log one W008HeldKeyLog row via
' W008HeldKeyLog(control, event, argName, argBefore, argAfter, focusOwnerAfter,
' valueAfter). For key handlers argBefore is the KeyCode ReturnInteger .Value read
' at handler entry and argAfter is that .Value at handler exit (this fixture does
' not swallow keys, so before == after); for ToggleCheck Click/Change the logged
' value is its .Value. focusOwnerAfter is Me.ActiveControl.Name (or "" when
' ActiveControl Is Nothing). valueAfter is the count-relevant value for the
' control (ToggleCheck.Value for the checkbox, TextBox1.Text for the textbox).
'
' Each row is one global-sequence entry, so a held-key OS auto-repeat run produces
' one row per repeat -- letting the worksheet answer esq.12: does a held Space
' re-toggle the CheckBox per repeat (multiple Change/Click) or once, and does a
' held default-button Enter re-fire Click per repeat? OkButton.Default is set at
' RUNTIME below. No OxForms runtime behaviour is implied.

Private Function FocusOwnerName() As String
    If Me.ActiveControl Is Nothing Then
        FocusOwnerName = ""
    Else
        FocusOwnerName = Me.ActiveControl.Name
    End If
End Function

' ---- UserForm ----

Private Sub UserForm_Initialize()
    ' Default property set at RUNTIME (never as a design-time fixture property).
    OkButton.Default = True
    W008HeldKeyLog Me.Name, "Initialize", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

' ---- TextBox1 (focus host for held Enter) ----

Private Sub TextBox1_Enter()
    W008HeldKeyLog "TextBox1", "Enter", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008HeldKeyLog "TextBox1", "KeyDown", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008HeldKeyLog "TextBox1", "KeyUp", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_Change()
    W008HeldKeyLog "TextBox1", "Change", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

' ---- OkButton (Default=True) ----

Private Sub OkButton_Enter()
    W008HeldKeyLog "OkButton", "Enter", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub OkButton_Click()
    W008HeldKeyLog "OkButton", "Click", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub OkButton_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008HeldKeyLog "OkButton", "KeyDown", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub OkButton_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008HeldKeyLog "OkButton", "KeyUp", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

' ---- ToggleCheck ----

Private Sub ToggleCheck_Click()
    W008HeldKeyLog "ToggleCheck", "Click", "Value", CStr(ToggleCheck.Value), CStr(ToggleCheck.Value), FocusOwnerName(), CStr(ToggleCheck.Value)
End Sub

Private Sub ToggleCheck_Change()
    W008HeldKeyLog "ToggleCheck", "Change", "Value", CStr(ToggleCheck.Value), CStr(ToggleCheck.Value), FocusOwnerName(), CStr(ToggleCheck.Value)
End Sub

Private Sub ToggleCheck_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008HeldKeyLog "ToggleCheck", "KeyDown", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), CStr(ToggleCheck.Value)
End Sub

Private Sub ToggleCheck_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008HeldKeyLog "ToggleCheck", "KeyUp", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), CStr(ToggleCheck.Value)
End Sub
