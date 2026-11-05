Option Explicit
Private mInputClicks As Long
Public Prompt As Label
Public InputName As TextBox
Public WithEvents Greet As CommandButton
Public Fractional As Label
Public Clipped As Label
Public LongInput As TextBox
Public Disabled As CommandButton
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
    InputName.Text = "Alpha Beta Gamma Delta"
    Set Greet = CalcFormsHostForm.Controls.Add("Forms.CommandButton.1", "Greet")
    Greet.Left = 198
    Greet.Top = 36
    Greet.Width = 84
    Greet.Height = 24
    Greet.Core.TabIndex = 2
    Greet.Core.FontSize = 8.25
    Greet.Enabled = True
    Greet.Caption = "&Greet"
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
    LayoutFacts = "text=" & InputName.Text & ";start=" & CStr(InputName.SelStart) & ";length=" & CStr(InputName.SelLength) & ";selected=" & InputName.SelText & ";clicks=" & CStr(mInputClicks) & ";focus=" & CalcFormsHostReducer.FocusName
End Function
Private Sub Greet_Click()
    mInputClicks = mInputClicks + 1
End Sub
