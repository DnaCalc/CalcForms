Option Explicit

' W009 ListBox representative fixture: list data lives in the ListBox object model while
' OxReducer only routes pointer/keyboard/focus turns to the control.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mChoices As ListBox
Private WithEvents mField As TextBox
Private mLog As String

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "listboxform"
    mForm.Width = 220
    mForm.Height = 150

    Set mChoices = mForm.Controls.Add("Forms.ListBox.1", "Choices")
    mChoices.Left = 20
    mChoices.Top = 20
    mChoices.Width = 120
    mChoices.Height = 58
    mChoices.Core.TabIndex = 0
    mChoices.AddItem "Red"
    mChoices.AddItem "Green"
    mChoices.AddItem "Blue"

    Set mField = mForm.Controls.Add("Forms.TextBox.1", "Field")
    mField.Left = 20
    mField.Top = 92
    mField.Width = 100
    mField.Height = 20
    mField.Core.TabIndex = 1

    Set mReducer = New OxReducer
    mReducer.Init mForm
    mForm.Render 96, 96
End Sub

Public Function Dispatch( _
        ByVal Kind As String, ByVal X As Long, ByVal Y As Long, _
        ByVal Button As Integer, ByVal Shift As Integer) As String
    Dispatch = mReducer.Dispatch(Kind, X, Y, Button, Shift)
End Function

Public Function DispatchKey(ByVal Kind As String, ByVal KeyCode As Integer, ByVal Shift As Integer) As String
    DispatchKey = mReducer.DispatchKey(Kind, KeyCode, Shift)
End Function

Public Function DispatchChar(ByVal Text As String) As String
    DispatchChar = mReducer.DispatchChar(Text)
End Function

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Public Sub ClearLog()
    mLog = ""
End Sub

Public Property Get FocusName() As String
    FocusName = mReducer.FocusName
End Property

Public Property Get ListDiagnostics() As String
    ListDiagnostics = mChoices.Diagnostics
End Property

Public Property Get SelectedSummary() As String
    Dim Text As String
    If mChoices.Selected(0) Then Text = "0"
    If mChoices.Selected(1) Then
        If Len(Text) > 0 Then Text = Text & ","
        Text = Text & "1"
    End If
    If mChoices.Selected(2) Then
        If Len(Text) > 0 Then Text = Text & ","
        Text = Text & "2"
    End If
    SelectedSummary = Text
End Property

Public Property Get GreenSelected() As Boolean
    GreenSelected = mChoices.Selected(1)
End Property

Public Property Get BlueCode() As String
    BlueCode = mChoices.Column(2, 1)
End Property

Public Property Get ListIndex() As Long
    ListIndex = mChoices.ListIndex
End Property

Public Property Get ListValue() As String
    ListValue = mChoices.Value
End Property

Public Property Get ListCount() As Long
    ListCount = mChoices.ListCount
End Property

Public Property Get FirstItem() As String
    FirstItem = mChoices.List(0)
End Property

Public Property Get AccessibilitySnapshot() As String
    AccessibilitySnapshot = mReducer.AccessibilitySnapshot
End Property

Public Property Get CapabilityCatalog() As String
    CapabilityCatalog = _
        "Choices:" & mChoices.Core.CapabilityDescriptor & vbLf & _
        "Field:" & mField.Core.CapabilityDescriptor
End Property

Public Sub SelectBlueProgrammatically()
    mChoices.ListIndex = 2
End Sub

Public Sub UseMultiSelect()
    mChoices.MultiSelect = fmMultiSelectMulti
End Sub

Public Sub UseExtendedMultiSelect()
    mChoices.MultiSelect = fmMultiSelectExtended
End Sub

Public Sub SelectRedAndBlueProgrammatically()
    mChoices.MultiSelect = fmMultiSelectMulti
    mChoices.Selected(0) = True
    mChoices.Selected(2) = True
End Sub

Public Sub ConfigureColumns()
    mChoices.Clear
    mChoices.ColumnCount = 2
    mChoices.BoundColumn = 2
    mChoices.AddRow "Red", "R"
    mChoices.AddRow "Green", "G"
    mChoices.AddRow "Blue", "B"
    mForm.Render 96, 96
End Sub

Public Sub DisableChoices()
    mChoices.Enabled = False
End Sub

Public Sub HideChoices()
    mChoices.Visible = False
End Sub

Public Sub Render()
    mForm.Render 96, 96
End Sub

Private Sub mChoices_Enter()
    Append "Choices.Enter"
End Sub
Private Sub mChoices_Exit(ByVal Cancel As ReturnBoolean)
    Append "Choices.Exit"
End Sub
Private Sub mChoices_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Choices.MouseDown"
End Sub
Private Sub mChoices_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Choices.MouseUp"
End Sub
Private Sub mChoices_Click()
    Append "Choices.Click:" & mChoices.Value
End Sub
Private Sub mChoices_Change()
    Append "Choices.Change:" & mChoices.Value
End Sub
Private Sub mChoices_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "Choices.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mChoices_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "Choices.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mChoices_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "Choices.KeyPress:" & CStr(KeyAscii.Value)
End Sub
Private Sub mChoices_BeforeUpdate(ByVal Cancel As ReturnBoolean)
    Append "Choices.BeforeUpdate"
End Sub
Private Sub mChoices_AfterUpdate()
    Append "Choices.AfterUpdate"
End Sub

Private Sub mField_Enter()
    Append "Field.Enter"
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
