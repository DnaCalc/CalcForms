Option Explicit
Private mParityEvents As String
Private mParityFailure As String
Public WithEvents Prompt As Label
Public WithEvents InputName As TextBox
Public WithEvents Greet As CommandButton
Public WithEvents Fractional As Label
Public WithEvents Clipped As Label
Public WithEvents LongInput As TextBox
Public WithEvents Disabled As CommandButton
' Private host entrypoints composed with an Office FormModule. These members
' are invoked by the owning CalcVBA session, not added to the MSForms facade.
Private CalcFormsHostForm As UserForm
Private CalcFormsHostReducer As OxReducer
Private Sub CalcFormsHostBuild()
    Set CalcFormsHostForm = New UserForm
    CalcFormsHostForm.Name = "LayoutCommon"
    CalcFormsHostForm.Caption = "CalcForms layout - common"
    CalcFormsHostForm.Width = 300
    CalcFormsHostForm.Height = 180
    Set Prompt = CalcFormsHostForm.Controls.Add("Forms.Label.1", "Prompt")
    Prompt.Left = 12
    Prompt.Top = 12
    Prompt.Width = 170
    Prompt.Height = 18
    Prompt.Core.TabIndex = 0
    Prompt.Core.FontSize = 8.25
    Prompt.Enabled = True
    Prompt.Caption = "Your name: AgjpQy"
    Set InputName = CalcFormsHostForm.Controls.Add("Forms.TextBox.1", "InputName")
    InputName.Left = 12
    InputName.Top = 36
    InputName.Width = 170
    InputName.Height = 20
    InputName.Core.TabIndex = 1
    InputName.Core.FontSize = 8.25
    InputName.Enabled = True
    InputName.Text = "Ada"
    Set Greet = CalcFormsHostForm.Controls.Add("Forms.CommandButton.1", "Greet")
    Greet.Left = 198
    Greet.Top = 36
    Greet.Width = 84
    Greet.Height = 24
    Greet.Core.TabIndex = 2
    Greet.Core.FontSize = 8.25
    Greet.Enabled = True
    Greet.Caption = "Greet"
    Greet.Default = True
    Set Fractional = CalcFormsHostForm.Controls.Add("Forms.Label.1", "Fractional")
    Fractional.Left = 12.375
    Fractional.Top = 74.625
    Fractional.Width = 123.375
    Fractional.Height = 17.625
    Fractional.Core.TabIndex = 3
    Fractional.Core.FontSize = 8.25
    Fractional.Enabled = True
    Fractional.Caption = "Fractional position"
    Set Clipped = CalcFormsHostForm.Controls.Add("Forms.Label.1", "Clipped")
    Clipped.Left = 162
    Clipped.Top = 75
    Clipped.Width = 70
    Clipped.Height = 12
    Clipped.Core.TabIndex = 4
    Clipped.Core.FontSize = 8.25
    Clipped.Enabled = True
    Clipped.Caption = "Long clipped label AgjpQy"
    Set LongInput = CalcFormsHostForm.Controls.Add("Forms.TextBox.1", "LongInput")
    LongInput.Left = 12
    LongInput.Top = 108
    LongInput.Width = 150
    LongInput.Height = 20
    LongInput.Core.TabIndex = 5
    LongInput.Core.FontSize = 8.25
    LongInput.Enabled = True
    LongInput.Text = "A long input with a clipped trailing word"
    Set Disabled = CalcFormsHostForm.Controls.Add("Forms.CommandButton.1", "Disabled")
    Disabled.Left = 198
    Disabled.Top = 108
    Disabled.Width = 84
    Disabled.Height = 24
    Disabled.Core.TabIndex = 6
    Disabled.Core.FontSize = 8.25
    Disabled.Enabled = False
    Disabled.Caption = "Disabled"
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
    CalcFormsHostInputText = InputName.Text
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
    LayoutFacts = LayoutFacts & "" & Prompt.Name & ";" & "Label" & ";" & CStr(Prompt.Left) & ";" & CStr(Prompt.Top) & ";" & CStr(Prompt.Width) & ";" & CStr(Prompt.Height) & ";" & CStr(Prompt.Core.NodeId) & ";" & CStr(Prompt.Core.PaintLeft) & ";" & CStr(Prompt.Core.PaintTop) & ";" & CStr(Prompt.Core.FontSize) & ";" & CStr(Prompt.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & InputName.Name & ";" & "TextBox" & ";" & CStr(InputName.Left) & ";" & CStr(InputName.Top) & ";" & CStr(InputName.Width) & ";" & CStr(InputName.Height) & ";" & CStr(InputName.Core.NodeId) & ";" & CStr(InputName.Core.PaintLeft) & ";" & CStr(InputName.Core.PaintTop) & ";" & CStr(InputName.Core.FontSize) & ";" & CStr(InputName.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & Greet.Name & ";" & "CommandButton" & ";" & CStr(Greet.Left) & ";" & CStr(Greet.Top) & ";" & CStr(Greet.Width) & ";" & CStr(Greet.Height) & ";" & CStr(Greet.Core.NodeId) & ";" & CStr(Greet.Core.PaintLeft) & ";" & CStr(Greet.Core.PaintTop) & ";" & CStr(Greet.Core.FontSize) & ";" & CStr(Greet.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & Fractional.Name & ";" & "Label" & ";" & CStr(Fractional.Left) & ";" & CStr(Fractional.Top) & ";" & CStr(Fractional.Width) & ";" & CStr(Fractional.Height) & ";" & CStr(Fractional.Core.NodeId) & ";" & CStr(Fractional.Core.PaintLeft) & ";" & CStr(Fractional.Core.PaintTop) & ";" & CStr(Fractional.Core.FontSize) & ";" & CStr(Fractional.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & Clipped.Name & ";" & "Label" & ";" & CStr(Clipped.Left) & ";" & CStr(Clipped.Top) & ";" & CStr(Clipped.Width) & ";" & CStr(Clipped.Height) & ";" & CStr(Clipped.Core.NodeId) & ";" & CStr(Clipped.Core.PaintLeft) & ";" & CStr(Clipped.Core.PaintTop) & ";" & CStr(Clipped.Core.FontSize) & ";" & CStr(Clipped.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & LongInput.Name & ";" & "TextBox" & ";" & CStr(LongInput.Left) & ";" & CStr(LongInput.Top) & ";" & CStr(LongInput.Width) & ";" & CStr(LongInput.Height) & ";" & CStr(LongInput.Core.NodeId) & ";" & CStr(LongInput.Core.PaintLeft) & ";" & CStr(LongInput.Core.PaintTop) & ";" & CStr(LongInput.Core.FontSize) & ";" & CStr(LongInput.Core.TabIndex) & vbLf
    LayoutFacts = LayoutFacts & "" & Disabled.Name & ";" & "CommandButton" & ";" & CStr(Disabled.Left) & ";" & CStr(Disabled.Top) & ";" & CStr(Disabled.Width) & ";" & CStr(Disabled.Height) & ";" & CStr(Disabled.Core.NodeId) & ";" & CStr(Disabled.Core.PaintLeft) & ";" & CStr(Disabled.Core.PaintTop) & ";" & CStr(Disabled.Core.FontSize) & ";" & CStr(Disabled.Core.TabIndex) & vbLf
End Function

Public Function ParityMeasurements() As String
    On Error GoTo Failed
    Dim S As String
    S = S & Parity_InputName()
    S = S & Parity_LongInput()
    ParityMeasurements = S
    Exit Function
Failed:
    ParityMeasurements = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function

Private Function Parity_InputName() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = InputName.Text
    mParityEvents = ""
    mParityFailure = ""
    S = S & "InputName~value_changes~initial~" & CStr(InputName.Text) & vbLf
    S = S & "InputName~event_order~initial~" & mParityEvents & vbLf
    InputName.Text = "Parity probe"
    S = S & "InputName~value_changes~set~" & CStr(InputName.Text) & vbLf
    S = S & "InputName~event_order~set~" & mParityEvents & vbLf
    InputName.Text = "Parity probe"
    S = S & "InputName~value_changes~repeat~" & CStr(InputName.Text) & vbLf
    S = S & "InputName~event_order~repeat~" & mParityEvents & vbLf
    InputName.Text = Original
    S = S & "InputName~value_changes~restore~" & CStr(InputName.Text) & vbLf
    S = S & "InputName~event_order~restore~" & mParityEvents & vbLf
    InputName.Text = "Alpha Beta"
    InputName.SelStart = 2
    InputName.SelLength = 4
    S = S & "InputName~selection~range~" & CStr(InputName.SelStart) & ";" & CStr(InputName.SelLength) & ";" & InputName.SelText & vbLf
    InputName.SelText = "X"
    S = S & "InputName~selection~replace~" & InputName.Text & ";" & CStr(InputName.SelStart) & ";" & CStr(InputName.SelLength) & vbLf
    InputName.Text = Original
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_InputName = S
    Exit Function
Failed:
    Parity_InputName = "CALCFORMS_NATIVE_ERROR:InputName:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_LongInput() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = LongInput.Text
    mParityEvents = ""
    mParityFailure = ""
    S = S & "LongInput~value_changes~initial~" & CStr(LongInput.Text) & vbLf
    S = S & "LongInput~event_order~initial~" & mParityEvents & vbLf
    LongInput.Text = "Parity probe"
    S = S & "LongInput~value_changes~set~" & CStr(LongInput.Text) & vbLf
    S = S & "LongInput~event_order~set~" & mParityEvents & vbLf
    LongInput.Text = "Parity probe"
    S = S & "LongInput~value_changes~repeat~" & CStr(LongInput.Text) & vbLf
    S = S & "LongInput~event_order~repeat~" & mParityEvents & vbLf
    LongInput.Text = Original
    S = S & "LongInput~value_changes~restore~" & CStr(LongInput.Text) & vbLf
    S = S & "LongInput~event_order~restore~" & mParityEvents & vbLf
    LongInput.Text = "Alpha Beta"
    LongInput.SelStart = 2
    LongInput.SelLength = 4
    S = S & "LongInput~selection~range~" & CStr(LongInput.SelStart) & ";" & CStr(LongInput.SelLength) & ";" & LongInput.SelText & vbLf
    LongInput.SelText = "X"
    S = S & "LongInput~selection~replace~" & LongInput.Text & ";" & CStr(LongInput.SelStart) & ";" & CStr(LongInput.SelLength) & vbLf
    LongInput.Text = Original
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_LongInput = S
    Exit Function
Failed:
    Parity_LongInput = "CALCFORMS_NATIVE_ERROR:LongInput:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Sub InputName_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "InputName.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub LongInput_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "LongInput.Change|"
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

Private Sub Prompt_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Prompt.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub InputName_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "InputName.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Greet_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Greet.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Fractional_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Fractional.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Clipped_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Clipped.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub LongInput_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "LongInput.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Disabled_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Disabled.MouseDown|"
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
    For I = 1 To 10
        E = CalcFormsHostReducer.DispatchKey("keydown", 9, 0)
        E = CalcFormsHostReducer.DispatchKey("keyup", 9, 0)
        S = S & "@visit~" & CalcFormsHostReducer.FocusName & vbLf
        If CalcFormsHostReducer.FocusName = First Then Exit For
    Next
    If CalcFormsHostReducer.FocusName <> First Then Err.Raise 5, "ParityInput", "Tab cycle did not close"
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 97, 21, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 97, 21, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Prompt~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 97, 46, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 97, 46, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "InputName~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 240, 48, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 240, 48, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Greet~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 74, 83, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 74, 83, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Fractional~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 196, 81, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 196, 81, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Clipped~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 87, 118, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 87, 118, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "LongInput~hit_testing~interior~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.Dispatch("mousedown", 240, 120, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 240, 120, 1, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    S = S & "Disabled~hit_testing~interior~" & mParityEvents & vbLf
    ParityInputMeasurements = S
    Exit Function
Failed:
    ParityInputMeasurements = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function

Private Sub Greet_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Greet.Click|"
    Exit Sub
Failed:
    mParityFailure = "command-click:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Disabled_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Disabled.Click|"
    Exit Sub
Failed:
    mParityFailure = "command-click:" & CStr(Err.Number) & ":" & Err.Description
End Sub

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
    E = CalcFormsHostReducer.Dispatch("mousedown", 97, 21, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 97, 21, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Prompt~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Prompt~escape_cancel~escape~" & mParityEvents & vbLf
    E = CalcFormsHostReducer.Dispatch("mousedown", 97, 46, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 97, 46, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "InputName~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "InputName~escape_cancel~escape~" & mParityEvents & vbLf
    E = CalcFormsHostReducer.Dispatch("mousedown", 240, 48, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 240, 48, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Greet~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Greet~escape_cancel~escape~" & mParityEvents & vbLf
    E = CalcFormsHostReducer.Dispatch("mousedown", 74, 83, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 74, 83, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Fractional~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Fractional~escape_cancel~escape~" & mParityEvents & vbLf
    E = CalcFormsHostReducer.Dispatch("mousedown", 196, 81, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 196, 81, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Clipped~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Clipped~escape_cancel~escape~" & mParityEvents & vbLf
    E = CalcFormsHostReducer.Dispatch("mousedown", 87, 118, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 87, 118, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "LongInput~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "LongInput~escape_cancel~escape~" & mParityEvents & vbLf
    E = CalcFormsHostReducer.Dispatch("mousedown", 240, 120, 1, 0)
    E = CalcFormsHostReducer.Dispatch("mouseup", 240, 120, 1, 0)
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 13, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 13, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Disabled~enter_default~enter~" & mParityEvents & vbLf
    mParityEvents = ""
    mParityFailure = ""
    E = CalcFormsHostReducer.DispatchKey("keydown", 27, 0)
    E = CalcFormsHostReducer.DispatchKey("keyup", 27, 0)
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure
    S = S & "Disabled~escape_cancel~escape~" & mParityEvents & vbLf
    ParityKeyboardMeasurements = S
    Exit Function
Failed:
    ParityKeyboardMeasurements = "CALCFORMS_NATIVE_ERROR:keyboard:" & CStr(Err.Number) & ":" & Err.Description
End Function
