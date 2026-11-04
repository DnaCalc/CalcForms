Option Explicit

' Focused ToggleButton proof fixture for W009. A single Forms.ToggleButton.1 is driven through
' OxReducer; WithEvents records real native events and the current Value for ordering checks.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mToggle As ToggleButton
Private mLog As String

Private Sub Class_Initialize()
    Set mForm = Nothing
    Set mReducer = Nothing
    Set mToggle = Nothing
End Sub

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "toggleform"
    mForm.Width = 220
    mForm.Height = 90

    Set mToggle = mForm.Controls.Add("Forms.ToggleButton.1", "Tog")
    mToggle.Caption = "Toggle"
    mToggle.Left = 20
    mToggle.Top = 20
    mToggle.Width = 110
    mToggle.Height = 24

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

Public Property Get Value() As Boolean
    Value = mToggle.Value
End Property

Public Sub SetValueTrue()
    mToggle.Value = True
    mForm.Render 96, 96
End Sub

Public Property Get Diagnostics() As String
    Dim Control As IOxControl
    Set Control = mToggle
    Diagnostics = _
        "caption=" & mToggle.Caption & _
        ";value=" & CStr(mToggle.Value) & _
        ";capabilities=" & mToggle.Core.CapabilityDescriptor & _
        ";accessibility=" & Control.AccessibilityRole & "/" & Control.AccessibilityValue & "/" & Control.AccessibilityPatterns
End Property

Public Property Get AccessibilitySnapshot() As String
    AccessibilitySnapshot = mReducer.AccessibilitySnapshot
End Property

Private Sub mToggle_Enter()
    Append "Enter"
End Sub
Private Sub mToggle_Exit(ByVal Cancel As ReturnBoolean)
    Append "Exit"
End Sub
Private Sub mToggle_BeforeUpdate(ByVal Cancel As ReturnBoolean)
    Append "BeforeUpdate"
End Sub
Private Sub mToggle_AfterUpdate()
    Append "AfterUpdate"
End Sub
Private Sub mToggle_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "MouseDown"
End Sub
Private Sub mToggle_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "MouseUp"
End Sub
Private Sub mToggle_Change()
    Append "Change=" & CStr(mToggle.Value)
End Sub
Private Sub mToggle_Click()
    Append "Click=" & CStr(mToggle.Value)
End Sub
Private Sub mToggle_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mToggle_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mToggle_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "KeyPress:" & CStr(KeyAscii.Value)
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
