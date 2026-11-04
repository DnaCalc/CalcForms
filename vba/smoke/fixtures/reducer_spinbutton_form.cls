Option Explicit

' W009 SpinButton depth fixture: value/range state and keyboard/mouse event order
' live on the SpinButton object model; OxReducer only routes turns to it.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mSpin As SpinButton
Private WithEvents mField As TextBox
Private mLog As String

Private Sub Class_Initialize()
    Set mForm = Nothing
    Set mReducer = Nothing
    Set mSpin = Nothing
    Set mField = Nothing
End Sub

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "spinbuttonform"
    mForm.Width = 180
    mForm.Height = 120

    Set mSpin = mForm.Controls.Add("Forms.SpinButton.1", "Spin")
    mSpin.Left = 20
    mSpin.Top = 20
    mSpin.Width = 28
    mSpin.Height = 58
    mSpin.Min = -2
    mSpin.Max = 4
    mSpin.SmallChange = 2
    mSpin.Value = 0
    mSpin.Core.TabIndex = 0

    Set mField = mForm.Controls.Add("Forms.TextBox.1", "Field")
    mField.Left = 70
    mField.Top = 20
    mField.Width = 80
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

Public Property Get SpinValue() As Long
    SpinValue = mSpin.Value
End Property

Public Property Get SpinDiagnostics() As String
    SpinDiagnostics = mSpin.Diagnostics
End Property

Public Property Get AccessibilitySnapshot() As String
    AccessibilitySnapshot = mReducer.AccessibilitySnapshot
End Property

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Public Sub ClearLog()
    mLog = ""
End Sub

Public Sub DisableSpin()
    mSpin.Enabled = False
End Sub

Public Sub HideSpin()
    mSpin.Visible = False
End Sub

Private Sub mSpin_Enter()
    Append "Spin.Enter"
End Sub
Private Sub mSpin_Exit(ByVal Cancel As ReturnBoolean)
    Append "Spin.Exit"
End Sub
Private Sub mSpin_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Spin.MouseDown"
End Sub
Private Sub mSpin_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Spin.MouseUp"
End Sub
Private Sub mSpin_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "Spin.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mSpin_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "Spin.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mSpin_SpinUp()
    Append "Spin.SpinUp=" & CStr(mSpin.Value)
End Sub
Private Sub mSpin_SpinDown()
    Append "Spin.SpinDown=" & CStr(mSpin.Value)
End Sub
Private Sub mSpin_Change()
    Append "Spin.Change=" & CStr(mSpin.Value)
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
