Option Explicit

' W008 dirty-focus-out oracle UserForm code-behind (esq.14).
'
' Two load-bearing questions this fixture lets live Excel/MSForms answer:
'   (1) CHECKBOX update events: when a CheckBox is toggled (dirty) and then loses
'       focus, does it fire BeforeUpdate -> AfterUpdate before Exit (like a TextBox),
'       or only Exit? (FM20_EVENT_FACTS.md treats CheckBox Enter/Exit/BeforeUpdate as
'       unknown for MdcCheckBoxEvents.)
'   (2) NET-VALUE (OldValue) semantics: when a TextBox is edited and then reverted to
'       its value-at-focus-gain (net change = none) before losing focus, does
'       BeforeUpdate/AfterUpdate still fire, or are they gated on a net value change?
'
' Every handler logs one W008CheckBoxUpdateLog row via W008CbuLog(control, event,
' argName, argBefore, argAfter, focusOwnerAfter, valueAfter). For ReturnBoolean args
' argBefore/argAfter are Cancel.Value at handler entry/exit (this fixture does NOT
' mutate Cancel -- it only observes whether the events fire, so before == after).
' focusOwnerAfter is Me.ActiveControl.Name (or "" when Nothing). valueAfter is the
' control's count-relevant value (TextBox1.Text or CStr(CheckBox1.Value)). No OxForms
' runtime behaviour is implied; no argument is mutated.

Private Function FocusOwnerName() As String
    If Me.ActiveControl Is Nothing Then
        FocusOwnerName = ""
    Else
        FocusOwnerName = Me.ActiveControl.Name
    End If
End Function

' ---- UserForm ----

Private Sub UserForm_Initialize()
    W008CbuLog Me.Name, "Initialize", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

' ---- TextBox1 (edit-then-revert subject) ----

Private Sub TextBox1_Enter()
    W008CbuLog "TextBox1", "Enter", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    W008CbuLog "TextBox1", "Exit", "Cancel", CStr(Cancel.Value), CStr(Cancel.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_BeforeUpdate(ByVal Cancel As MSForms.ReturnBoolean)
    W008CbuLog "TextBox1", "BeforeUpdate", "Cancel", CStr(Cancel.Value), CStr(Cancel.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_AfterUpdate()
    W008CbuLog "TextBox1", "AfterUpdate", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_Change()
    W008CbuLog "TextBox1", "Change", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008CbuLog "TextBox1", "KeyDown", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008CbuLog "TextBox1", "KeyUp", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

' ---- CheckBox1 (dirty-focus-out subject) ----

Private Sub CheckBox1_Enter()
    W008CbuLog "CheckBox1", "Enter", "", "", "", FocusOwnerName(), CStr(CheckBox1.Value)
End Sub

Private Sub CheckBox1_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    W008CbuLog "CheckBox1", "Exit", "Cancel", CStr(Cancel.Value), CStr(Cancel.Value), FocusOwnerName(), CStr(CheckBox1.Value)
End Sub

Private Sub CheckBox1_BeforeUpdate(ByVal Cancel As MSForms.ReturnBoolean)
    W008CbuLog "CheckBox1", "BeforeUpdate", "Cancel", CStr(Cancel.Value), CStr(Cancel.Value), FocusOwnerName(), CStr(CheckBox1.Value)
End Sub

Private Sub CheckBox1_AfterUpdate()
    W008CbuLog "CheckBox1", "AfterUpdate", "", "", "", FocusOwnerName(), CStr(CheckBox1.Value)
End Sub

Private Sub CheckBox1_Click()
    W008CbuLog "CheckBox1", "Click", "Value", CStr(CheckBox1.Value), CStr(CheckBox1.Value), FocusOwnerName(), CStr(CheckBox1.Value)
End Sub

Private Sub CheckBox1_Change()
    W008CbuLog "CheckBox1", "Change", "Value", CStr(CheckBox1.Value), CStr(CheckBox1.Value), FocusOwnerName(), CStr(CheckBox1.Value)
End Sub

Private Sub CheckBox1_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008CbuLog "CheckBox1", "KeyDown", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), CStr(CheckBox1.Value)
End Sub

Private Sub CheckBox1_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008CbuLog "CheckBox1", "KeyUp", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), CStr(CheckBox1.Value)
End Sub

' ---- TextBox2 (focus-out landing target) ----

Private Sub TextBox2_Enter()
    W008CbuLog "TextBox2", "Enter", "", "", "", FocusOwnerName(), TextBox2.Text
End Sub

Private Sub TextBox2_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    W008CbuLog "TextBox2", "Exit", "Cancel", CStr(Cancel.Value), CStr(Cancel.Value), FocusOwnerName(), TextBox2.Text
End Sub
