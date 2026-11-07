Option Explicit
Private mParityEvents As String
Private mParityFailure As String
Public WithEvents Unchecked As CheckBox
Public WithEvents Checked As CheckBox
Public WithEvents OptionOne As OptionButtonControl
Public WithEvents OptionTwo As OptionButtonControl
Public WithEvents ToggleOff As ToggleButton
Public WithEvents ToggleOn As ToggleButton
Public WithEvents Choices As ListBox
Public WithEvents Dropdown As ComboBox
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
    Unchecked.Caption = "Unchecked"
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
    OptionOne.Caption = "First option"
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
    ToggleOff.Caption = "Toggle off"
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
    Choices.AddItem "Alpha"
    Choices.AddItem "Beta"
    Choices.AddItem "Gamma"
    Choices.ListIndex = 1
    Set Dropdown = CalcFormsHostForm.Controls.Add("Forms.ComboBox.1", "Dropdown")
    Dropdown.Left = 174
    Dropdown.Top = 114
    Dropdown.Width = 130
    Dropdown.Height = 21
    Dropdown.Core.TabIndex = 7
    Dropdown.Core.FontSize = 8.25
    Dropdown.Enabled = True
    Dropdown.AddItem "Alpha"
    Dropdown.AddItem "Beta"
    Dropdown.AddItem "Gamma"
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

Public Function ParityMeasurements() As String
    On Error GoTo Failed
    Dim S As String
    S = S & Parity_Unchecked()
    S = S & Parity_Checked()
    S = S & Parity_OptionOne()
    S = S & Parity_OptionTwo()
    S = S & Parity_ToggleOff()
    S = S & Parity_ToggleOn()
    S = S & Parity_Choices()
    S = S & Parity_Dropdown()
    ParityMeasurements = S
    Exit Function
Failed:
    ParityMeasurements = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function

Private Function Parity_Unchecked() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = Unchecked.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "Unchecked~value_changes~initial~" & CStr(Unchecked.Value) & vbLf
    S = S & "Unchecked~event_order~initial~" & mParityEvents & vbLf
    Unchecked.Value = Not CBool(Original)
    S = S & "Unchecked~value_changes~set~" & CStr(Unchecked.Value) & vbLf
    S = S & "Unchecked~event_order~set~" & mParityEvents & vbLf
    Unchecked.Value = Not CBool(Original)
    S = S & "Unchecked~value_changes~repeat~" & CStr(Unchecked.Value) & vbLf
    S = S & "Unchecked~event_order~repeat~" & mParityEvents & vbLf
    Unchecked.Value = Original
    S = S & "Unchecked~value_changes~restore~" & CStr(Unchecked.Value) & vbLf
    S = S & "Unchecked~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_Unchecked = S
    Exit Function
Failed:
    Parity_Unchecked = "CALCFORMS_NATIVE_ERROR:Unchecked:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_Checked() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = Checked.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "Checked~value_changes~initial~" & CStr(Checked.Value) & vbLf
    S = S & "Checked~event_order~initial~" & mParityEvents & vbLf
    Checked.Value = Not CBool(Original)
    S = S & "Checked~value_changes~set~" & CStr(Checked.Value) & vbLf
    S = S & "Checked~event_order~set~" & mParityEvents & vbLf
    Checked.Value = Not CBool(Original)
    S = S & "Checked~value_changes~repeat~" & CStr(Checked.Value) & vbLf
    S = S & "Checked~event_order~repeat~" & mParityEvents & vbLf
    Checked.Value = Original
    S = S & "Checked~value_changes~restore~" & CStr(Checked.Value) & vbLf
    S = S & "Checked~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_Checked = S
    Exit Function
Failed:
    Parity_Checked = "CALCFORMS_NATIVE_ERROR:Checked:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_OptionOne() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = OptionOne.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "OptionOne~value_changes~initial~" & CStr(OptionOne.Value) & vbLf
    S = S & "OptionOne~event_order~initial~" & mParityEvents & vbLf
    OptionOne.Value = Not CBool(Original)
    S = S & "OptionOne~value_changes~set~" & CStr(OptionOne.Value) & vbLf
    S = S & "OptionOne~event_order~set~" & mParityEvents & vbLf
    OptionOne.Value = Not CBool(Original)
    S = S & "OptionOne~value_changes~repeat~" & CStr(OptionOne.Value) & vbLf
    S = S & "OptionOne~event_order~repeat~" & mParityEvents & vbLf
    OptionOne.Value = Original
    S = S & "OptionOne~value_changes~restore~" & CStr(OptionOne.Value) & vbLf
    S = S & "OptionOne~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_OptionOne = S
    Exit Function
Failed:
    Parity_OptionOne = "CALCFORMS_NATIVE_ERROR:OptionOne:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_OptionTwo() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = OptionTwo.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "OptionTwo~value_changes~initial~" & CStr(OptionTwo.Value) & vbLf
    S = S & "OptionTwo~event_order~initial~" & mParityEvents & vbLf
    OptionTwo.Value = Not CBool(Original)
    S = S & "OptionTwo~value_changes~set~" & CStr(OptionTwo.Value) & vbLf
    S = S & "OptionTwo~event_order~set~" & mParityEvents & vbLf
    OptionTwo.Value = Not CBool(Original)
    S = S & "OptionTwo~value_changes~repeat~" & CStr(OptionTwo.Value) & vbLf
    S = S & "OptionTwo~event_order~repeat~" & mParityEvents & vbLf
    OptionTwo.Value = Original
    S = S & "OptionTwo~value_changes~restore~" & CStr(OptionTwo.Value) & vbLf
    S = S & "OptionTwo~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_OptionTwo = S
    Exit Function
Failed:
    Parity_OptionTwo = "CALCFORMS_NATIVE_ERROR:OptionTwo:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_ToggleOff() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = ToggleOff.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "ToggleOff~value_changes~initial~" & CStr(ToggleOff.Value) & vbLf
    S = S & "ToggleOff~event_order~initial~" & mParityEvents & vbLf
    ToggleOff.Value = Not CBool(Original)
    S = S & "ToggleOff~value_changes~set~" & CStr(ToggleOff.Value) & vbLf
    S = S & "ToggleOff~event_order~set~" & mParityEvents & vbLf
    ToggleOff.Value = Not CBool(Original)
    S = S & "ToggleOff~value_changes~repeat~" & CStr(ToggleOff.Value) & vbLf
    S = S & "ToggleOff~event_order~repeat~" & mParityEvents & vbLf
    ToggleOff.Value = Original
    S = S & "ToggleOff~value_changes~restore~" & CStr(ToggleOff.Value) & vbLf
    S = S & "ToggleOff~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_ToggleOff = S
    Exit Function
Failed:
    Parity_ToggleOff = "CALCFORMS_NATIVE_ERROR:ToggleOff:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_ToggleOn() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = ToggleOn.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "ToggleOn~value_changes~initial~" & CStr(ToggleOn.Value) & vbLf
    S = S & "ToggleOn~event_order~initial~" & mParityEvents & vbLf
    ToggleOn.Value = Not CBool(Original)
    S = S & "ToggleOn~value_changes~set~" & CStr(ToggleOn.Value) & vbLf
    S = S & "ToggleOn~event_order~set~" & mParityEvents & vbLf
    ToggleOn.Value = Not CBool(Original)
    S = S & "ToggleOn~value_changes~repeat~" & CStr(ToggleOn.Value) & vbLf
    S = S & "ToggleOn~event_order~repeat~" & mParityEvents & vbLf
    ToggleOn.Value = Original
    S = S & "ToggleOn~value_changes~restore~" & CStr(ToggleOn.Value) & vbLf
    S = S & "ToggleOn~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_ToggleOn = S
    Exit Function
Failed:
    Parity_ToggleOn = "CALCFORMS_NATIVE_ERROR:ToggleOn:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_Choices() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = Choices.ListIndex
    mParityEvents = ""
    mParityFailure = ""
    S = S & "Choices~value_changes~initial~" & CStr(Choices.ListIndex) & ";value=" & CStr(Choices.Value) & vbLf
    S = S & "Choices~event_order~initial~" & mParityEvents & vbLf
    Choices.ListIndex = 2
    S = S & "Choices~value_changes~set~" & CStr(Choices.ListIndex) & ";value=" & CStr(Choices.Value) & vbLf
    S = S & "Choices~event_order~set~" & mParityEvents & vbLf
    Choices.ListIndex = 2
    S = S & "Choices~value_changes~repeat~" & CStr(Choices.ListIndex) & ";value=" & CStr(Choices.Value) & vbLf
    S = S & "Choices~event_order~repeat~" & mParityEvents & vbLf
    Choices.ListIndex = Original
    S = S & "Choices~value_changes~restore~" & CStr(Choices.ListIndex) & ";value=" & CStr(Choices.Value) & vbLf
    S = S & "Choices~event_order~restore~" & mParityEvents & vbLf
    Choices.ListIndex = 1
    S = S & "Choices~selection~select~" & CStr(Choices.ListIndex) & vbLf
    Choices.ListIndex = Original
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_Choices = S
    Exit Function
Failed:
    Parity_Choices = "CALCFORMS_NATIVE_ERROR:Choices:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_Dropdown() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = Dropdown.ListIndex
    mParityEvents = ""
    mParityFailure = ""
    S = S & "Dropdown~value_changes~initial~" & CStr(Dropdown.ListIndex) & ";value=" & CStr(Dropdown.Value) & vbLf
    S = S & "Dropdown~event_order~initial~" & mParityEvents & vbLf
    Dropdown.ListIndex = 2
    S = S & "Dropdown~value_changes~set~" & CStr(Dropdown.ListIndex) & ";value=" & CStr(Dropdown.Value) & vbLf
    S = S & "Dropdown~event_order~set~" & mParityEvents & vbLf
    Dropdown.ListIndex = 2
    S = S & "Dropdown~value_changes~repeat~" & CStr(Dropdown.ListIndex) & ";value=" & CStr(Dropdown.Value) & vbLf
    S = S & "Dropdown~event_order~repeat~" & mParityEvents & vbLf
    Dropdown.ListIndex = Original
    S = S & "Dropdown~value_changes~restore~" & CStr(Dropdown.ListIndex) & ";value=" & CStr(Dropdown.Value) & vbLf
    S = S & "Dropdown~event_order~restore~" & mParityEvents & vbLf
    Dropdown.ListIndex = 1
    S = S & "Dropdown~selection~select~" & CStr(Dropdown.ListIndex) & vbLf
    Dropdown.ListIndex = Original
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_Dropdown = S
    Exit Function
Failed:
    Parity_Dropdown = "CALCFORMS_NATIVE_ERROR:Dropdown:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Sub Unchecked_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Unchecked.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Unchecked_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Unchecked.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Checked_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Checked.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Checked_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Checked.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub OptionOne_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "OptionOne.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub OptionOne_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "OptionOne.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub OptionTwo_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "OptionTwo.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub OptionTwo_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "OptionTwo.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub ToggleOff_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "ToggleOff.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub ToggleOff_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "ToggleOff.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub ToggleOn_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "ToggleOn.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub ToggleOn_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "ToggleOn.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Choices_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Choices.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Choices_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Choices.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Dropdown_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Dropdown.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Dropdown_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Dropdown.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Public Function ParityInputTrace(ByVal Reset As Boolean) As String
    On Error GoTo Failed
    If Reset Then
        mParityEvents = ""
        mParityFailure = ""
    End If
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    ParityInputTrace = mParityEvents
    Exit Function
Failed:
    ParityInputTrace = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function

Private Sub Unchecked_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Unchecked.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Checked_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Checked.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub OptionOne_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "OptionOne.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub OptionTwo_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "OptionTwo.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub ToggleOff_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "ToggleOff.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub ToggleOn_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "ToggleOn.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Choices_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Choices.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Dropdown_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Dropdown.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub UserForm_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "(form).MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "form-mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Public Function ParityInputMeasurements() As String
    On Error GoTo Failed
    Dim S As String, E As String, First As String, I As Long
    S = "@initial~" & CalcFormsHostReducer.FocusName & vbLf
    E = CalcFormsHostReducer.DispatchKey("keydown", 9, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 9, 0)
    First = CalcFormsHostReducer.FocusName
    S = S & "@visit~" & First & vbLf
    For I = 1 To 11
        E = CalcFormsHostReducer.DispatchKey("keydown", 9, 0)
        E = CalcFormsHostReducer.DispatchKey("keyup", 9, 0)
        S = S & "@visit~" & CalcFormsHostReducer.FocusName & vbLf
        If CalcFormsHostReducer.FocusName = First Then Exit For
    Next
    If CalcFormsHostReducer.FocusName <> First Then Err.Raise 5, "ParityInput", "Tab cycle did not close"
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 77, 21, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 77, 21, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Unchecked~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 239, 21, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 239, 21, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Checked~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 77, 51, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 77, 51, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "OptionOne~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 239, 51, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 239, 51, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "OptionTwo~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 77, 84, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 77, 84, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "ToggleOff~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 239, 84, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 239, 84, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "ToggleOn~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 77, 150, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 77, 150, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Choices~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 239, 124, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 239, 124, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Dropdown~hit_testing~interior~" & mParityEvents & vbLf
    ParityInputMeasurements = S
    Exit Function
Failed:
    ParityInputMeasurements = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
