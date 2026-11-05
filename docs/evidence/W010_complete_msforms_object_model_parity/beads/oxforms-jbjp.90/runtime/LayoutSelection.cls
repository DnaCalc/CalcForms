Option Explicit
Public Unchecked As CheckBox
Public Checked As CheckBox
Public OptionOne As OptionButtonControl
Public OptionTwo As OptionButtonControl
Public ToggleOff As ToggleButton
Public ToggleOn As ToggleButton
Public Choices As ListBox
Public Dropdown As ComboBox
' Private host entrypoints composed with an Office FormModule. These members
' are invoked by the owning CalcVBA session, not added to the MSForms facade.
Private CalcFormsHostForm As UserForm
Private CalcFormsHostReducer As OxReducer
Private Sub CalcFormsHostBuild()
    Set CalcFormsHostForm = New UserForm
    CalcFormsHostForm.Name = "LayoutSelection"
    CalcFormsHostForm.Caption = "CalcForms layout - selection"
    CalcFormsHostForm.Width = 330
    CalcFormsHostForm.Height = 210
    Set Unchecked = CalcFormsHostForm.Controls.Add("Forms.CheckBox.1", "Unchecked")
    Unchecked.Left = 12
    Unchecked.Top = 12
    Unchecked.Width = 130
    Unchecked.Height = 18
    Unchecked.Core.TabIndex = 0
    Unchecked.Core.FontSize = 8.25
    Unchecked.Enabled = True
    Unchecked.Caption = "A&B && C&"
    Set Checked = CalcFormsHostForm.Controls.Add("Forms.CheckBox.1", "Checked")
    Checked.Left = 174
    Checked.Top = 12
    Checked.Width = 130
    Checked.Height = 18
    Checked.Core.TabIndex = 1
    Checked.Core.FontSize = 8.25
    Checked.Enabled = True
    Checked.Caption = "Checked"
    Checked.Value = True
    Set OptionOne = CalcFormsHostForm.Controls.Add("Forms.OptionButton.1", "OptionOne")
    OptionOne.Left = 12
    OptionOne.Top = 42
    OptionOne.Width = 130
    OptionOne.Height = 18
    OptionOne.Core.TabIndex = 2
    OptionOne.Core.FontSize = 8.25
    OptionOne.Enabled = True
    OptionOne.Caption = "A&B && C&"
    OptionOne.Value = True
    Set OptionTwo = CalcFormsHostForm.Controls.Add("Forms.OptionButton.1", "OptionTwo")
    OptionTwo.Left = 174
    OptionTwo.Top = 42
    OptionTwo.Width = 130
    OptionTwo.Height = 18
    OptionTwo.Core.TabIndex = 3
    OptionTwo.Core.FontSize = 8.25
    OptionTwo.Enabled = True
    OptionTwo.Caption = "Second option"
    Set ToggleOff = CalcFormsHostForm.Controls.Add("Forms.ToggleButton.1", "ToggleOff")
    ToggleOff.Left = 12
    ToggleOff.Top = 72
    ToggleOff.Width = 130
    ToggleOff.Height = 24
    ToggleOff.Core.TabIndex = 4
    ToggleOff.Core.FontSize = 8.25
    ToggleOff.Enabled = True
    ToggleOff.Caption = "A&B && C&"
    Set ToggleOn = CalcFormsHostForm.Controls.Add("Forms.ToggleButton.1", "ToggleOn")
    ToggleOn.Left = 174
    ToggleOn.Top = 72
    ToggleOn.Width = 130
    ToggleOn.Height = 24
    ToggleOn.Core.TabIndex = 5
    ToggleOn.Core.FontSize = 8.25
    ToggleOn.Enabled = True
    ToggleOn.Caption = "Toggle on"
    ToggleOn.Value = True
    Set Choices = CalcFormsHostForm.Controls.Add("Forms.ListBox.1", "Choices")
    Choices.Left = 12
    Choices.Top = 114
    Choices.Width = 130
    Choices.Height = 72
    Choices.Core.TabIndex = 6
    Choices.Core.FontSize = 8.25
    Choices.Enabled = True
    Choices.AddItem "A&B"
    Choices.AddItem "A&&B"
    Choices.AddItem "tail&"
    Choices.ListIndex = 1
    Set Dropdown = CalcFormsHostForm.Controls.Add("Forms.ComboBox.1", "Dropdown")
    Dropdown.Left = 174
    Dropdown.Top = 114
    Dropdown.Width = 130
    Dropdown.Height = 21
    Dropdown.Core.TabIndex = 7
    Dropdown.Core.FontSize = 8.25
    Dropdown.Enabled = True
    Dropdown.AddItem "A&B"
    Dropdown.AddItem "A&&B"
    Dropdown.AddItem "tail&"
    Dropdown.ListIndex = 1
    Set CalcFormsHostReducer = New OxReducer
    CalcFormsHostReducer.Init CalcFormsHostForm
End Sub

Private Function CalcFormsHostDispatch(ByVal Kind As String, ByVal X As Long, ByVal Y As Long, ByVal Button As Integer, ByVal Shift As Integer) As String
    CalcFormsHostDispatch = CalcFormsHostReducer.Dispatch(Kind, X, Y, Button, Shift)
End Function

Private Function CalcFormsHostDispatchKey(ByVal Kind As String, ByVal KeyCode As Integer, ByVal Shift As Integer) As String
    CalcFormsHostDispatchKey = CalcFormsHostReducer.DispatchKey(Kind, KeyCode, Shift)
End Function

Private Function CalcFormsHostDispatchChar(ByVal Text As String) As String
    CalcFormsHostDispatchChar = CalcFormsHostReducer.DispatchChar(Text)
End Function

Private Function CalcFormsHostDispatchDrop(ByVal Text As String) As String
    CalcFormsHostDispatchDrop = CalcFormsHostReducer.DispatchDrop(Text)
End Function

Private Function CalcFormsHostDispatchTimer(ByVal Slot As String, ByVal Fires As Long) As String
    CalcFormsHostDispatchTimer = ""
End Function

Private Sub CalcFormsHostSetClipboardText(ByVal Text As String)
    CalcFormsHostReducer.SetClipboardText Text
End Sub

Private Sub CalcFormsHostRender()
    CalcFormsHostForm.Render 96, 96
End Sub

Private Property Get CalcFormsHostFocusName() As String
    CalcFormsHostFocusName = CalcFormsHostReducer.FocusName
End Property

Private Property Get CalcFormsHostAccessibilitySnapshot() As String
    CalcFormsHostAccessibilitySnapshot = CalcFormsHostReducer.AccessibilitySnapshot
End Property

Private Property Get CalcFormsHostInputText() As String
    CalcFormsHostInputText = ""
End Property

Private Sub CalcFormsHostPerformInitialize()

End Sub

Private Sub CalcFormsHostPerformActivate()

End Sub

Private Sub CalcFormsHostPerformDeactivate()

End Sub

Private Sub CalcFormsHostPerformTerminate()

End Sub

Private Function CalcFormsHostPerformQueryClose(ByVal CloseMode As Integer) As Integer
    Dim Cancel As Integer
    Cancel = 0

    CalcFormsHostPerformQueryClose = Cancel
End Function

Public Function LayoutFacts() As String
    LayoutFacts = ""
    LayoutFacts = LayoutFacts & "" & Unchecked.Name & ";" & "CheckBox" & ";" & CStr(Unchecked.Left) & ";" & CStr(Unchecked.Top) & ";" & CStr(Unchecked.Width) & ";" & CStr(Unchecked.Height) & ";" & CStr(Unchecked.Core.NodeId) & ";" & CStr(Unchecked.Core.PaintLeft) & ";" & CStr(Unchecked.Core.PaintTop) & ";" & CStr(Unchecked.Core.FontSize) & ";" & CStr(Unchecked.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & Checked.Name & ";" & "CheckBox" & ";" & CStr(Checked.Left) & ";" & CStr(Checked.Top) & ";" & CStr(Checked.Width) & ";" & CStr(Checked.Height) & ";" & CStr(Checked.Core.NodeId) & ";" & CStr(Checked.Core.PaintLeft) & ";" & CStr(Checked.Core.PaintTop) & ";" & CStr(Checked.Core.FontSize) & ";" & CStr(Checked.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & OptionOne.Name & ";" & "OptionButton" & ";" & CStr(OptionOne.Left) & ";" & CStr(OptionOne.Top) & ";" & CStr(OptionOne.Width) & ";" & CStr(OptionOne.Height) & ";" & CStr(OptionOne.Core.NodeId) & ";" & CStr(OptionOne.Core.PaintLeft) & ";" & CStr(OptionOne.Core.PaintTop) & ";" & CStr(OptionOne.Core.FontSize) & ";" & CStr(OptionOne.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & OptionTwo.Name & ";" & "OptionButton" & ";" & CStr(OptionTwo.Left) & ";" & CStr(OptionTwo.Top) & ";" & CStr(OptionTwo.Width) & ";" & CStr(OptionTwo.Height) & ";" & CStr(OptionTwo.Core.NodeId) & ";" & CStr(OptionTwo.Core.PaintLeft) & ";" & CStr(OptionTwo.Core.PaintTop) & ";" & CStr(OptionTwo.Core.FontSize) & ";" & CStr(OptionTwo.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & ToggleOff.Name & ";" & "ToggleButton" & ";" & CStr(ToggleOff.Left) & ";" & CStr(ToggleOff.Top) & ";" & CStr(ToggleOff.Width) & ";" & CStr(ToggleOff.Height) & ";" & CStr(ToggleOff.Core.NodeId) & ";" & CStr(ToggleOff.Core.PaintLeft) & ";" & CStr(ToggleOff.Core.PaintTop) & ";" & CStr(ToggleOff.Core.FontSize) & ";" & CStr(ToggleOff.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & ToggleOn.Name & ";" & "ToggleButton" & ";" & CStr(ToggleOn.Left) & ";" & CStr(ToggleOn.Top) & ";" & CStr(ToggleOn.Width) & ";" & CStr(ToggleOn.Height) & ";" & CStr(ToggleOn.Core.NodeId) & ";" & CStr(ToggleOn.Core.PaintLeft) & ";" & CStr(ToggleOn.Core.PaintTop) & ";" & CStr(ToggleOn.Core.FontSize) & ";" & CStr(ToggleOn.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & Choices.Name & ";" & "ListBox" & ";" & CStr(Choices.Left) & ";" & CStr(Choices.Top) & ";" & CStr(Choices.Width) & ";" & CStr(Choices.Height) & ";" & CStr(Choices.Core.NodeId) & ";" & CStr(Choices.Core.PaintLeft) & ";" & CStr(Choices.Core.PaintTop) & ";" & CStr(Choices.Core.FontSize) & ";" & CStr(Choices.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & Dropdown.Name & ";" & "ComboBox" & ";" & CStr(Dropdown.Left) & ";" & CStr(Dropdown.Top) & ";" & CStr(Dropdown.Width) & ";" & CStr(Dropdown.Height) & ";" & CStr(Dropdown.Core.NodeId) & ";" & CStr(Dropdown.Core.PaintLeft) & ";" & CStr(Dropdown.Core.PaintTop) & ";" & CStr(Dropdown.Core.FontSize) & ";" & CStr(Dropdown.Core.TabIndex) & vbLf
End Function
