Option Explicit

' W008 veto-click oracle UserForm code-behind.
'
' Every focus (Enter/Exit), validation (BeforeUpdate/AfterUpdate), Change, and
' mouse (MouseDown/MouseUp) handler on both TextBoxes logs one W008VetoClickLog
' row via W008VetoClickLog(control, event, argName, argBefore, argAfter,
' focusOwnerAfter, textValueAfter). argBefore is the Cancel ReturnBoolean .Value
' as read at handler entry (pre-mutation); argAfter is the same argument .Value
' after this handler optionally vetoed (Cancel.Value = True). focusOwnerAfter is
' Me.ActiveControl.Name (or "" when ActiveControl Is Nothing). textValueAfter is
' the relevant TextBox .Text.
'
' The Exit veto is gated on Public module flags (set by the per-scenario Set...
' macros in the standard module), so this single form covers both the non-vetoing
' baseline and the vetoing-mouse-click scenario against live Excel/MSForms. The
' load-bearing question: does a vetoing Exit (Cancel=True) absorb a focus-changing
' mouse click -- i.e. do TextBox2's MouseDown/MouseUp/Enter fire, and where does
' focus end up? No OxForms runtime behaviour is implied.

Private Function FocusOwnerName() As String
    If Me.ActiveControl Is Nothing Then
        FocusOwnerName = ""
    Else
        FocusOwnerName = Me.ActiveControl.Name
    End If
End Function

' ---- UserForm ----

Private Sub UserForm_Initialize()
    W008VetoClickLog Me.Name, "Initialize", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

' ---- TextBox1 ----

Private Sub TextBox1_Enter()
    W008VetoClickLog "TextBox1", "Enter", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    Dim before As String
    before = CStr(Cancel.Value)
    If gVetoExit And gVetoControl = "TextBox1" Then
        Cancel.Value = True
    End If
    W008VetoClickLog "TextBox1", "Exit", "Cancel", before, CStr(Cancel.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_BeforeUpdate(ByVal Cancel As MSForms.ReturnBoolean)
    W008VetoClickLog "TextBox1", "BeforeUpdate", "Cancel", CStr(Cancel.Value), CStr(Cancel.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_AfterUpdate()
    W008VetoClickLog "TextBox1", "AfterUpdate", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_Change()
    W008VetoClickLog "TextBox1", "Change", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    W008VetoClickLog "TextBox1", "MouseDown", "Button", CStr(Button), CStr(Button), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    W008VetoClickLog "TextBox1", "MouseUp", "Button", CStr(Button), CStr(Button), FocusOwnerName(), TextBox1.Text
End Sub

' ---- TextBox2 ----

Private Sub TextBox2_Enter()
    W008VetoClickLog "TextBox2", "Enter", "", "", "", FocusOwnerName(), TextBox2.Text
End Sub

Private Sub TextBox2_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    Dim before As String
    before = CStr(Cancel.Value)
    If gVetoExit And gVetoControl = "TextBox2" Then
        Cancel.Value = True
    End If
    W008VetoClickLog "TextBox2", "Exit", "Cancel", before, CStr(Cancel.Value), FocusOwnerName(), TextBox2.Text
End Sub

Private Sub TextBox2_BeforeUpdate(ByVal Cancel As MSForms.ReturnBoolean)
    W008VetoClickLog "TextBox2", "BeforeUpdate", "Cancel", CStr(Cancel.Value), CStr(Cancel.Value), FocusOwnerName(), TextBox2.Text
End Sub

Private Sub TextBox2_AfterUpdate()
    W008VetoClickLog "TextBox2", "AfterUpdate", "", "", "", FocusOwnerName(), TextBox2.Text
End Sub

Private Sub TextBox2_Change()
    W008VetoClickLog "TextBox2", "Change", "", "", "", FocusOwnerName(), TextBox2.Text
End Sub

Private Sub TextBox2_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    W008VetoClickLog "TextBox2", "MouseDown", "Button", CStr(Button), CStr(Button), FocusOwnerName(), TextBox2.Text
End Sub

Private Sub TextBox2_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    W008VetoClickLog "TextBox2", "MouseUp", "Button", CStr(Button), CStr(Button), FocusOwnerName(), TextBox2.Text
End Sub
