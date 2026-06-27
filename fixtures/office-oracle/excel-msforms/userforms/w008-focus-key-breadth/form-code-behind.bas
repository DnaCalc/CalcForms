Option Explicit

' W008 focus + key fold-back oracle UserForm code-behind.
'
' Every focus, validation, and keyboard handler logs one W008BreadthLog row via
' W008Log(control, event, argName, argBefore, argAfter, focusOwnerAfter,
' textValueAfter). argBefore is the ReturnBoolean/ReturnInteger argument .Value as
' read at handler entry (pre-mutation); argAfter is the same argument .Value after
' this handler optionally mutated it. focusOwnerAfter is Me.ActiveControl.Name (or
' "" when ActiveControl Is Nothing). textValueAfter is the relevant TextBox .Text.
'
' Mutations are gated on Public module flags (set by the per-scenario Set... macros
' in the standard module), so this single form covers Tab focus transfer, Exit
' veto, BeforeUpdate veto, default-button Enter, and KeyDown/KeyPress/arrow swallow
' against live Excel/MSForms. No OxForms runtime behaviour is implied.

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
    W008Log Me.Name, "Initialize", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

' ---- TextBox1 ----

Private Sub TextBox1_Enter()
    W008Log "TextBox1", "Enter", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    Dim before As String
    before = CStr(Cancel.Value)
    If gVetoExit And gVetoControl = "TextBox1" Then
        Cancel.Value = True
    End If
    W008Log "TextBox1", "Exit", "Cancel", before, CStr(Cancel.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_BeforeUpdate(ByVal Cancel As MSForms.ReturnBoolean)
    Dim before As String
    before = CStr(Cancel.Value)
    If gVetoBeforeUpdate Then
        Cancel.Value = True
    End If
    W008Log "TextBox1", "BeforeUpdate", "Cancel", before, CStr(Cancel.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_AfterUpdate()
    W008Log "TextBox1", "AfterUpdate", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    Dim before As String
    before = CStr(KeyCode.Value)
    If gSwallowKeyDown Then
        KeyCode.Value = 0
    End If
    W008Log "TextBox1", "KeyDown", "KeyCode", before, CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_KeyPress(ByVal KeyAscii As MSForms.ReturnInteger)
    Dim before As String
    before = CStr(KeyAscii.Value)
    If gSwallowKeyPress Then
        KeyAscii.Value = 0
    End If
    W008Log "TextBox1", "KeyPress", "KeyAscii", before, CStr(KeyAscii.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008Log "TextBox1", "KeyUp", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub TextBox1_Change()
    W008Log "TextBox1", "Change", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

' ---- TextBox2 ----

Private Sub TextBox2_Enter()
    W008Log "TextBox2", "Enter", "", "", "", FocusOwnerName(), TextBox2.Text
End Sub

Private Sub TextBox2_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    Dim before As String
    before = CStr(Cancel.Value)
    If gVetoExit And gVetoControl = "TextBox2" Then
        Cancel.Value = True
    End If
    W008Log "TextBox2", "Exit", "Cancel", before, CStr(Cancel.Value), FocusOwnerName(), TextBox2.Text
End Sub

Private Sub TextBox2_BeforeUpdate(ByVal Cancel As MSForms.ReturnBoolean)
    Dim before As String
    before = CStr(Cancel.Value)
    If gVetoBeforeUpdate Then
        Cancel.Value = True
    End If
    W008Log "TextBox2", "BeforeUpdate", "Cancel", before, CStr(Cancel.Value), FocusOwnerName(), TextBox2.Text
End Sub

Private Sub TextBox2_AfterUpdate()
    W008Log "TextBox2", "AfterUpdate", "", "", "", FocusOwnerName(), TextBox2.Text
End Sub

Private Sub TextBox2_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    Dim before As String
    before = CStr(KeyCode.Value)
    If gSwallowKeyDown Then
        KeyCode.Value = 0
    End If
    W008Log "TextBox2", "KeyDown", "KeyCode", before, CStr(KeyCode.Value), FocusOwnerName(), TextBox2.Text
End Sub

Private Sub TextBox2_KeyPress(ByVal KeyAscii As MSForms.ReturnInteger)
    Dim before As String
    before = CStr(KeyAscii.Value)
    If gSwallowKeyPress Then
        KeyAscii.Value = 0
    End If
    W008Log "TextBox2", "KeyPress", "KeyAscii", before, CStr(KeyAscii.Value), FocusOwnerName(), TextBox2.Text
End Sub

Private Sub TextBox2_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008Log "TextBox2", "KeyUp", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox2.Text
End Sub

Private Sub TextBox2_Change()
    W008Log "TextBox2", "Change", "", "", "", FocusOwnerName(), TextBox2.Text
End Sub

' ---- OkButton ----

Private Sub OkButton_Enter()
    W008Log "OkButton", "Enter", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub OkButton_Click()
    W008Log "OkButton", "Click", "", "", "", FocusOwnerName(), TextBox1.Text
End Sub

Private Sub OkButton_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    Dim before As String
    before = CStr(KeyCode.Value)
    If gSwallowKeyDown Then
        KeyCode.Value = 0
    End If
    W008Log "OkButton", "KeyDown", "KeyCode", before, CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub OkButton_KeyPress(ByVal KeyAscii As MSForms.ReturnInteger)
    Dim before As String
    before = CStr(KeyAscii.Value)
    If gSwallowKeyPress Then
        KeyAscii.Value = 0
    End If
    W008Log "OkButton", "KeyPress", "KeyAscii", before, CStr(KeyAscii.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub OkButton_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    W008Log "OkButton", "KeyUp", "KeyCode", CStr(KeyCode.Value), CStr(KeyCode.Value), FocusOwnerName(), TextBox1.Text
End Sub

' ---- ToggleCheck ----

Private Sub ToggleCheck_Click()
    W008Log "ToggleCheck", "Click", "Value", CStr(ToggleCheck.Value), CStr(ToggleCheck.Value), FocusOwnerName(), TextBox1.Text
End Sub

Private Sub ToggleCheck_Change()
    W008Log "ToggleCheck", "Change", "Value", CStr(ToggleCheck.Value), CStr(ToggleCheck.Value), FocusOwnerName(), TextBox1.Text
End Sub
