Option Explicit

' W008 held cancel/accelerator oracle UserForm code-behind (oxforms-uvh).
'
' Load-bearing question: esq.15 proved a held DEFAULT-BUTTON Enter activates the button
' EXACTLY ONCE (no per-OS-repeat re-fire). This fixture asks the analogous question for the
' two activation paths esq.15 deliberately left repeat-blind:
'   (1) a held Escape on a form with a CANCEL button -- does CancelButton_Click re-fire per
'       OS auto-repeat, or once? And does Escape TRANSFER focus to the cancel button (as a
'       default-button Enter transfers to Ok), or click in place?
'   (2) a held Alt+accelerator -- does AccelButton_Click re-fire per repeat, or once?
'
' Every handler logs one W008HeldCancelAccelLog row via W008HcaLog(control, event, argName,
' argBefore, argAfter, focusOwnerAfter, valueAfter). For key handlers argBefore/argAfter are
' KeyCode.Value at handler entry/exit (this fixture does not swallow keys, so before == after);
' focusOwnerAfter is Me.ActiveControl.Name (or "" when Nothing) -- so a focus transfer to the
' activated button is observable; valueAfter is TextBox1.Text. A held key yields one row per OS
' repeat, so the Click count answers uvh. No OxForms runtime behaviour is implied; no arg is
' mutated.

Private Function FocusOwnerName() As String
    If Me.ActiveControl Is Nothing Then
        FocusOwnerName = ""
    Else
        FocusOwnerName = Me.ActiveControl.Name
    End If
End Function

' ---- UserForm ----

Private Sub UserForm_Initialize()
    ' Cancel property set at RUNTIME (never as a design-time fixture property, mirroring the
    ' held-key OkButton.Default gotcha). The AccelButton accelerator rides its '&Apply' caption.
    CancelButton.Cancel = True
    W008HcaLog Me.Name, "Initialize", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

' ---- TextBox1 (focus host for the held key) ----

Private Sub TextBox1_Enter()
    W008HcaLog "TextBox1", "Enter", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008HcaLog "TextBox1", "KeyDown", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008HcaLog "TextBox1", "KeyUp", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

' ---- CancelButton (Cancel=True; activated by Escape) ----

Private Sub CancelButton_Enter()
    W008HcaLog "CancelButton", "Enter", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub CancelButton_Click()
    W008HcaLog "CancelButton", "Click", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub CancelButton_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008HcaLog "CancelButton", "KeyDown", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub CancelButton_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008HcaLog "CancelButton", "KeyUp", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

' ---- AccelButton ('&Apply'; activated by Alt+A) ----

Private Sub AccelButton_Enter()
    W008HcaLog "AccelButton", "Enter", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub AccelButton_Click()
    W008HcaLog "AccelButton", "Click", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub AccelButton_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008HcaLog "AccelButton", "KeyDown", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub AccelButton_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008HcaLog "AccelButton", "KeyUp", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub
