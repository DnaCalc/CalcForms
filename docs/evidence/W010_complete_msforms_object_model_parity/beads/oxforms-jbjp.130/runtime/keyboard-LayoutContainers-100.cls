Option Explicit
Private mParityEvents As String
Private mParityFailure As String
Public WithEvents Group As Frame
Public WithEvents NestedLabel As Label
Public WithEvents NestedInput As TextBox
Public WithEvents Picture As Image
Public WithEvents Spinner As SpinButton
Public WithEvents Slider As ScrollBar
Public WithEvents TabsControl As TabStrip
Public WithEvents PagesControl As MultiPage
' Private host entrypoints composed with an Office FormModule. These members
' are invoked by the owning CalcVBA session, not added to the MSForms facade.
Private CalcFormsHostForm As UserForm
Private CalcFormsHostReducer As OxReducer
Private Sub CalcFormsHostBuild()
    Set CalcFormsHostForm = New UserForm
    CalcFormsHostForm.Name = "LayoutContainers"
    CalcFormsHostForm.Caption = "CalcForms layout - containers"
    CalcFormsHostForm.Width = 390
    CalcFormsHostForm.Height = 285
    Set Group = CalcFormsHostForm.Controls.Add("Forms.Frame.1", "Group")
    Group.Left = 12
    Group.Top = 12
    Group.Width = 174
    Group.Height = 72
    Group.Core.TabIndex = 0
    Group.Core.FontSize = 8.25
    Group.Enabled = True
    Group.Caption = "Details"
    Set NestedLabel = Group.Controls.Add("Forms.Label.1", "NestedLabel")
    NestedLabel.Left = 12
    NestedLabel.Top = 18
    NestedLabel.Width = 138
    NestedLabel.Height = 18
    NestedLabel.Core.TabIndex = 0
    NestedLabel.Core.FontSize = 8.25
    NestedLabel.Enabled = True
    NestedLabel.Caption = "Inside frame"
    Set NestedInput = Group.Controls.Add("Forms.TextBox.1", "NestedInput")
    NestedInput.Left = 12
    NestedInput.Top = 39
    NestedInput.Width = 138
    NestedInput.Height = 18
    NestedInput.Core.TabIndex = 1
    NestedInput.Core.FontSize = 8.25
    NestedInput.Enabled = True
    NestedInput.Text = "Nested"
    Set Picture = CalcFormsHostForm.Controls.Add("Forms.Image.1", "Picture")
    Picture.Left = 210
    Picture.Top = 12
    Picture.Width = 66
    Picture.Height = 54
    Picture.Core.TabIndex = 1
    Picture.Core.FontSize = 8.25
    Picture.Enabled = True
    Set Spinner = CalcFormsHostForm.Controls.Add("Forms.SpinButton.1", "Spinner")
    Spinner.Left = 300
    Spinner.Top = 12
    Spinner.Width = 18
    Spinner.Height = 54
    Spinner.Core.TabIndex = 2
    Spinner.Core.FontSize = 8.25
    Spinner.Enabled = True
    Set Slider = CalcFormsHostForm.Controls.Add("Forms.ScrollBar.1", "Slider")
    Slider.Left = 12
    Slider.Top = 102
    Slider.Width = 174
    Slider.Height = 18
    Slider.Core.TabIndex = 3
    Slider.Core.FontSize = 8.25
    Slider.Enabled = True
    Set TabsControl = CalcFormsHostForm.Controls.Add("Forms.TabStrip.1", "TabsControl")
    TabsControl.Left = 12
    TabsControl.Top = 144
    TabsControl.Width = 174
    TabsControl.Height = 102
    TabsControl.Core.TabIndex = 4
    TabsControl.Core.FontSize = 8.25
    TabsControl.Enabled = True
    TabsControl.Tabs.Add "First"
    TabsControl.Tabs.Add "Second"
    Set PagesControl = CalcFormsHostForm.Controls.Add("Forms.MultiPage.1", "PagesControl")
    PagesControl.Left = 210
    PagesControl.Top = 102
    PagesControl.Width = 162
    PagesControl.Height = 144
    PagesControl.Core.TabIndex = 5
    PagesControl.Core.FontSize = 8.25
    PagesControl.Enabled = True
    PagesControl.Pages.Add "First"
    PagesControl.Pages.Add "Second"
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
    CalcFormsHostInputText = NestedInput.Text
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
    LayoutFacts = LayoutFacts & "" & Group.Name & ";" & "Frame" & ";" & CStr(Group.Left) & ";" & CStr(Group.Top) & ";" & CStr(Group.Width) & ";" & CStr(Group.Height) & ";" & CStr(Group.Core.NodeId) & ";" & CStr(Group.Core.PaintLeft) & ";" & CStr(Group.Core.PaintTop) & ";" & CStr(Group.Core.FontSize) & ";" & CStr(Group.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "Group." & NestedLabel.Name & ";" & "Label" & ";" & CStr(NestedLabel.Left) & ";" & CStr(NestedLabel.Top) & ";" & CStr(NestedLabel.Width) & ";" & CStr(NestedLabel.Height) & ";" & CStr(NestedLabel.Core.NodeId) & ";" & CStr(NestedLabel.Core.PaintLeft) & ";" & CStr(NestedLabel.Core.PaintTop) & ";" & CStr(NestedLabel.Core.FontSize) & ";" & CStr(NestedLabel.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "Group." & NestedInput.Name & ";" & "TextBox" & ";" & CStr(NestedInput.Left) & ";" & CStr(NestedInput.Top) & ";" & CStr(NestedInput.Width) & ";" & CStr(NestedInput.Height) & ";" & CStr(NestedInput.Core.NodeId) & ";" & CStr(NestedInput.Core.PaintLeft) & ";" & CStr(NestedInput.Core.PaintTop) & ";" & CStr(NestedInput.Core.FontSize) & ";" & CStr(NestedInput.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & Picture.Name & ";" & "Image" & ";" & CStr(Picture.Left) & ";" & CStr(Picture.Top) & ";" & CStr(Picture.Width) & ";" & CStr(Picture.Height) & ";" & CStr(Picture.Core.NodeId) & ";" & CStr(Picture.Core.PaintLeft) & ";" & CStr(Picture.Core.PaintTop) & ";" & CStr(Picture.Core.FontSize) & ";" & CStr(Picture.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & Spinner.Name & ";" & "SpinButton" & ";" & CStr(Spinner.Left) & ";" & CStr(Spinner.Top) & ";" & CStr(Spinner.Width) & ";" & CStr(Spinner.Height) & ";" & CStr(Spinner.Core.NodeId) & ";" & CStr(Spinner.Core.PaintLeft) & ";" & CStr(Spinner.Core.PaintTop) & ";" & CStr(Spinner.Core.FontSize) & ";" & CStr(Spinner.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & Slider.Name & ";" & "ScrollBar" & ";" & CStr(Slider.Left) & ";" & CStr(Slider.Top) & ";" & CStr(Slider.Width) & ";" & CStr(Slider.Height) & ";" & CStr(Slider.Core.NodeId) & ";" & CStr(Slider.Core.PaintLeft) & ";" & CStr(Slider.Core.PaintTop) & ";" & CStr(Slider.Core.FontSize) & ";" & CStr(Slider.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & TabsControl.Name & ";" & "TabStrip" & ";" & CStr(TabsControl.Left) & ";" & CStr(TabsControl.Top) & ";" & CStr(TabsControl.Width) & ";" & CStr(TabsControl.Height) & ";" & CStr(TabsControl.Core.NodeId) & ";" & CStr(TabsControl.Core.PaintLeft) & ";" & CStr(TabsControl.Core.PaintTop) & ";" & CStr(TabsControl.Core.FontSize) & ";" & CStr(TabsControl.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & PagesControl.Name & ";" & "MultiPage" & ";" & CStr(PagesControl.Left) & ";" & CStr(PagesControl.Top) & ";" & CStr(PagesControl.Width) & ";" & CStr(PagesControl.Height) & ";" & CStr(PagesControl.Core.NodeId) & ";" & CStr(PagesControl.Core.PaintLeft) & ";" & CStr(PagesControl.Core.PaintTop) & ";" & CStr(PagesControl.Core.FontSize) & ";" & CStr(PagesControl.Core.TabIndex) & vbLf
End Function

Public Function ParityMeasurements() As String
    On Error GoTo Failed
    Dim S As String
    S = S & Parity_NestedInput()
    S = S & Parity_Spinner()
    S = S & Parity_Slider()
    S = S & Parity_TabsControl()
    S = S & Parity_PagesControl()
    ParityMeasurements = S
    Exit Function
Failed:
    ParityMeasurements = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function

Private Function Parity_NestedInput() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = NestedInput.Text
    mParityEvents = ""
    mParityFailure = ""
    S = S & "Group.NestedInput~value_changes~initial~" & CStr(NestedInput.Text) & vbLf
    S = S & "Group.NestedInput~event_order~initial~" & mParityEvents & vbLf
    NestedInput.Text = "Parity probe"
    S = S & "Group.NestedInput~value_changes~set~" & CStr(NestedInput.Text) & vbLf
    S = S & "Group.NestedInput~event_order~set~" & mParityEvents & vbLf
    NestedInput.Text = "Parity probe"
    S = S & "Group.NestedInput~value_changes~repeat~" & CStr(NestedInput.Text) & vbLf
    S = S & "Group.NestedInput~event_order~repeat~" & mParityEvents & vbLf
    NestedInput.Text = Original
    S = S & "Group.NestedInput~value_changes~restore~" & CStr(NestedInput.Text) & vbLf
    S = S & "Group.NestedInput~event_order~restore~" & mParityEvents & vbLf
    NestedInput.Text = "Alpha Beta"
    NestedInput.SelStart = 2
    NestedInput.SelLength = 4
    S = S & "Group.NestedInput~selection~range~" & CStr(NestedInput.SelStart) & ";" & CStr(NestedInput.SelLength) & ";" & NestedInput.SelText & vbLf
    NestedInput.SelText = "X"
    S = S & "Group.NestedInput~selection~replace~" & NestedInput.Text & ";" & CStr(NestedInput.SelStart) & ";" & CStr(NestedInput.SelLength) & vbLf
    NestedInput.Text = Original
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_NestedInput = S
    Exit Function
Failed:
    Parity_NestedInput = "CALCFORMS_NATIVE_ERROR:Group.NestedInput:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_Spinner() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = Spinner.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "Spinner~value_changes~initial~" & CStr(Spinner.Value) & vbLf
    S = S & "Spinner~event_order~initial~" & mParityEvents & vbLf
    Spinner.Value = 1
    S = S & "Spinner~value_changes~set~" & CStr(Spinner.Value) & vbLf
    S = S & "Spinner~event_order~set~" & mParityEvents & vbLf
    Spinner.Value = 1
    S = S & "Spinner~value_changes~repeat~" & CStr(Spinner.Value) & vbLf
    S = S & "Spinner~event_order~repeat~" & mParityEvents & vbLf
    Spinner.Value = Original
    S = S & "Spinner~value_changes~restore~" & CStr(Spinner.Value) & vbLf
    S = S & "Spinner~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_Spinner = S
    Exit Function
Failed:
    Parity_Spinner = "CALCFORMS_NATIVE_ERROR:Spinner:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_Slider() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = Slider.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "Slider~value_changes~initial~" & CStr(Slider.Value) & vbLf
    S = S & "Slider~event_order~initial~" & mParityEvents & vbLf
    Slider.Value = 1
    S = S & "Slider~value_changes~set~" & CStr(Slider.Value) & vbLf
    S = S & "Slider~event_order~set~" & mParityEvents & vbLf
    Slider.Value = 1
    S = S & "Slider~value_changes~repeat~" & CStr(Slider.Value) & vbLf
    S = S & "Slider~event_order~repeat~" & mParityEvents & vbLf
    Slider.Value = Original
    S = S & "Slider~value_changes~restore~" & CStr(Slider.Value) & vbLf
    S = S & "Slider~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_Slider = S
    Exit Function
Failed:
    Parity_Slider = "CALCFORMS_NATIVE_ERROR:Slider:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_TabsControl() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = TabsControl.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "TabsControl~value_changes~initial~" & CStr(TabsControl.Value) & vbLf
    S = S & "TabsControl~event_order~initial~" & mParityEvents & vbLf
    TabsControl.Value = 1
    S = S & "TabsControl~value_changes~set~" & CStr(TabsControl.Value) & vbLf
    S = S & "TabsControl~event_order~set~" & mParityEvents & vbLf
    TabsControl.Value = 1
    S = S & "TabsControl~value_changes~repeat~" & CStr(TabsControl.Value) & vbLf
    S = S & "TabsControl~event_order~repeat~" & mParityEvents & vbLf
    TabsControl.Value = Original
    S = S & "TabsControl~value_changes~restore~" & CStr(TabsControl.Value) & vbLf
    S = S & "TabsControl~event_order~restore~" & mParityEvents & vbLf
    TabsControl.Value = 1
    S = S & "TabsControl~selection~select~" & CStr(TabsControl.Value) & vbLf
    TabsControl.Value = Original
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_TabsControl = S
    Exit Function
Failed:
    Parity_TabsControl = "CALCFORMS_NATIVE_ERROR:TabsControl:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_PagesControl() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = PagesControl.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "PagesControl~value_changes~initial~" & CStr(PagesControl.Value) & vbLf
    S = S & "PagesControl~event_order~initial~" & mParityEvents & vbLf
    PagesControl.Value = 1
    S = S & "PagesControl~value_changes~set~" & CStr(PagesControl.Value) & vbLf
    S = S & "PagesControl~event_order~set~" & mParityEvents & vbLf
    PagesControl.Value = 1
    S = S & "PagesControl~value_changes~repeat~" & CStr(PagesControl.Value) & vbLf
    S = S & "PagesControl~event_order~repeat~" & mParityEvents & vbLf
    PagesControl.Value = Original
    S = S & "PagesControl~value_changes~restore~" & CStr(PagesControl.Value) & vbLf
    S = S & "PagesControl~event_order~restore~" & mParityEvents & vbLf
    PagesControl.Value = 1
    S = S & "PagesControl~selection~select~" & CStr(PagesControl.Value) & vbLf
    PagesControl.Value = Original
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_PagesControl = S
    Exit Function
Failed:
    Parity_PagesControl = "CALCFORMS_NATIVE_ERROR:PagesControl:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Sub NestedInput_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Group.NestedInput.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Spinner_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Spinner.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Spinner_SpinUp()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Spinner.SpinUp|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Spinner_SpinDown()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Spinner.SpinDown|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Slider_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Slider.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Slider_Scroll()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Slider.Scroll|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub TabsControl_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "TabsControl.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub PagesControl_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "PagesControl.Change|"
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

Private Sub Group_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Group.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub NestedLabel_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Group.NestedLabel.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub NestedInput_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Group.NestedInput.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Picture_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Picture.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Spinner_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Spinner.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Slider_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Slider.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub TabsControl_MouseDown(ByVal Index As Long, ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "TabsControl.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub PagesControl_MouseDown(ByVal Index As Long, ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "PagesControl.MouseDown|"
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
    E = CalcFormsHostReducer.Dispatch("mousedown", 183, 81, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 183, 81, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Group~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 94, 45, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 94, 45, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Group.NestedLabel~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 94, 66, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 94, 66, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Group.NestedInput~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 243, 39, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 243, 39, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Picture~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 309, 39, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 309, 39, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Spinner~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 99, 111, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 99, 111, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Slider~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 99, 195, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 99, 195, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "TabsControl~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 369, 243, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 369, 243, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "PagesControl~hit_testing~interior~" & mParityEvents & vbLf
    ParityInputMeasurements = S
    Exit Function
Failed:
    ParityInputMeasurements = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function

Private Function ParityListSnapshot(ByVal C As Object) As String
    On Error GoTo Failed
    Dim S As String, Stage As String
    S = "index=" & CStr(C.ListIndex) & ";count=" & CStr(C.ListCount)
    Stage = "top"
    ParityListSnapshot = S & ";top=" & CStr(C.TopIndex)
    Exit Function
Failed:
    If Stage = "top" Then
        ParityListSnapshot = S & ";top_error=" & CStr(Err.Number)
    Else
        ParityListSnapshot = "CALCFORMS_NATIVE_ERROR:list-state:" & CStr(Err.Number) & ":" & Err.Description
    End If
End Function

Public Function ParityScroll(ByVal Prepare As Boolean) As String
    On Error GoTo Failed
    Dim I As Long, S As String
    ParityScroll = S
    Exit Function
Failed:
    ParityScroll = "CALCFORMS_NATIVE_ERROR:scroll:" & CStr(Err.Number) & ":" & Err.Description
End Function

Public Function ParityKeyboardMeasurements() As String
    On Error GoTo Failed
    Dim S As String, E As String
    E = CalcFormsHostReducer.DispatchKey("keydown", 9, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 9, 0)
    E = CalcFormsHostReducer.Dispatch("mousedown", 183, 81, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 183, 81, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Group~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Group~escape_cancel~escape~" & mParityEvents & vbLf
    E = CalcFormsHostReducer.Dispatch("mousedown", 94, 45, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 94, 45, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Group.NestedLabel~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Group.NestedLabel~escape_cancel~escape~" & mParityEvents & vbLf
    E = CalcFormsHostReducer.Dispatch("mousedown", 94, 66, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 94, 66, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Group.NestedInput~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Group.NestedInput~escape_cancel~escape~" & mParityEvents & vbLf
    E = CalcFormsHostReducer.Dispatch("mousedown", 243, 39, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 243, 39, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Picture~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Picture~escape_cancel~escape~" & mParityEvents & vbLf
    E = CalcFormsHostReducer.Dispatch("mousedown", 309, 39, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 309, 39, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Spinner~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Spinner~escape_cancel~escape~" & mParityEvents & vbLf
    E = CalcFormsHostReducer.Dispatch("mousedown", 99, 111, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 99, 111, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Slider~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Slider~escape_cancel~escape~" & mParityEvents & vbLf
    E = CalcFormsHostReducer.Dispatch("mousedown", 99, 195, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 99, 195, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "TabsControl~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "TabsControl~escape_cancel~escape~" & mParityEvents & vbLf
    E = CalcFormsHostReducer.Dispatch("mousedown", 369, 243, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 369, 243, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "PagesControl~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "PagesControl~escape_cancel~escape~" & mParityEvents & vbLf
    ParityKeyboardMeasurements = S
    Exit Function
Failed:
    ParityKeyboardMeasurements = "CALCFORMS_NATIVE_ERROR:keyboard:" & CStr(Err.Number) & ":" & Err.Description
End Function
