Option Explicit

' Focused OptionButton proof fixture for W009. Two buttons share GroupName="Mode";
' the third uses another group to prove same-container grouping is scoped by name.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mOne As OptionButtonControl
Private WithEvents mTwo As OptionButtonControl
Private WithEvents mOther As OptionButtonControl
Private mLog As String

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "optionform"
    mForm.Width = 260
    mForm.Height = 120

    Set mOne = mForm.Controls.Add("Forms.OptionButton.1", "One")
    If mOne Is Nothing Then Err.Raise 424, , "mOne add returned Nothing"
    mOne.Caption = "One"
    mOne.GroupName = "Mode"
    mOne.Value = True
    mOne.Left = 20
    mOne.Top = 18
    mOne.Width = 110
    mOne.Height = 24

    Set mTwo = mForm.Controls.Add("Forms.OptionButton.1", "Two")
    If mTwo Is Nothing Then Err.Raise 424, , "mTwo add returned Nothing"
    mTwo.Caption = "Two"
    mTwo.GroupName = "Mode"
    mTwo.Left = 20
    mTwo.Top = 48
    mTwo.Width = 110
    mTwo.Height = 24

    Set mOther = mForm.Controls.Add("Forms.OptionButton.1", "Other")
    If mOther Is Nothing Then Err.Raise 424, , "mOther add returned Nothing"
    mOther.Caption = "Other"
    mOther.GroupName = "Other"
    mOther.Value = True
    mOther.Left = 150
    mOther.Top = 18
    mOther.Width = 110
    mOther.Height = 24

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

Public Sub Render()
    mForm.Render 96, 96
End Sub

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Public Sub ClearLog()
    mLog = ""
End Sub

Public Property Get Values() As String
    Values = CStr(mOne.Value) & "/" & CStr(mTwo.Value) & "/" & CStr(mOther.Value)
End Property

Public Property Get Diagnostics() As String
    Dim Control As IOxControl
    Set Control = mOne
    Diagnostics = _
        "one=" & CStr(mOne.Value) & _
        ";two=" & CStr(mTwo.Value) & _
        ";other=" & CStr(mOther.Value) & _
        ";group=" & mOne.GroupName & _
        ";capabilities=" & mOne.Core.CapabilityDescriptor & _
        ";accessibility=" & Control.AccessibilityRole & "/" & Control.AccessibilityValue & "/" & Control.AccessibilityPatterns
End Property

Public Property Get AccessibilitySnapshot() As String
    AccessibilitySnapshot = mReducer.AccessibilitySnapshot
End Property

Private Sub mOne_Enter()
    Append "One.Enter"
End Sub
Private Sub mOne_Exit(ByVal Cancel As ReturnBoolean)
    Append "One.Exit"
End Sub
Private Sub mOne_BeforeUpdate(ByVal Cancel As ReturnBoolean)
    Append "One.BeforeUpdate"
End Sub
Private Sub mOne_AfterUpdate()
    Append "One.AfterUpdate"
End Sub
Private Sub mOne_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "One.MouseDown"
End Sub
Private Sub mOne_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "One.MouseUp"
End Sub
Private Sub mOne_Change()
    Append "One.Change=" & CStr(mOne.Value)
End Sub
Private Sub mOne_Click()
    Append "One.Click=" & CStr(mOne.Value)
End Sub
Private Sub mOne_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "One.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mOne_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "One.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mOne_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "One.KeyPress:" & CStr(KeyAscii.Value)
End Sub

Private Sub mTwo_Enter()
    Append "Two.Enter"
End Sub
Private Sub mTwo_Exit(ByVal Cancel As ReturnBoolean)
    Append "Two.Exit"
End Sub
Private Sub mTwo_BeforeUpdate(ByVal Cancel As ReturnBoolean)
    Append "Two.BeforeUpdate"
End Sub
Private Sub mTwo_AfterUpdate()
    Append "Two.AfterUpdate"
End Sub
Private Sub mTwo_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Two.MouseDown"
End Sub
Private Sub mTwo_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Two.MouseUp"
End Sub
Private Sub mTwo_Change()
    Append "Two.Change=" & CStr(mTwo.Value)
End Sub
Private Sub mTwo_Click()
    Append "Two.Click=" & CStr(mTwo.Value)
End Sub
Private Sub mTwo_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "Two.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mTwo_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "Two.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mTwo_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "Two.KeyPress:" & CStr(KeyAscii.Value)
End Sub

Private Sub mOther_Change()
    Append "Other.Change=" & CStr(mOther.Value)
End Sub
Private Sub mOther_Click()
    Append "Other.Click=" & CStr(mOther.Value)
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
