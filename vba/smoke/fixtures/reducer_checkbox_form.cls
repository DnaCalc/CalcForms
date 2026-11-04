Option Explicit

' Reducer-pivot increment 2 proof fixture (oxforms-ih6.2; test infrastructure). A form with one
' CheckBox driven through OxReducer. A WithEvents sink records the real FM20 events AND the
' control's Value at each, proving the MSForms mouse-toggle order: MouseDown -> MouseUp ->
' Change -> Click, with the value flipped BEFORE Change/Click (value-before-Click, the oracle
' order). No Rust reducer (calcforms-core) in the loop.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mChk As CheckBox
Private mLog As String

Private Sub Class_Initialize()
    Set mForm = Nothing
    Set mReducer = Nothing
    Set mChk = Nothing
End Sub

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "chkform"
    mForm.Width = 200
    mForm.Height = 80

    Set mChk = mForm.Controls.Add("Forms.CheckBox.1", "Chk1")
    mChk.Caption = "Agree"
    mChk.Left = 20
    mChk.Top = 20
    mChk.Width = 120
    mChk.Height = 20

    Set mReducer = New OxReducer
    mReducer.Init mForm
    mForm.Render 96, 96
End Sub

Public Function Dispatch( _
        ByVal Kind As String, ByVal X As Long, ByVal Y As Long, _
        ByVal Button As Integer, ByVal Shift As Integer) As String
    Dispatch = mReducer.Dispatch(Kind, X, Y, Button, Shift)
End Function

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Public Property Get Value() As Boolean
    Value = mChk.Value
End Property

Private Sub mChk_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "MouseDown"
End Sub
Private Sub mChk_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "MouseUp"
End Sub
' The value is read inside the handler to prove it is already the NEW value when Change/Click fire.
Private Sub mChk_Change()
    Append "Change=" & mChk.Value
End Sub
Private Sub mChk_Click()
    Append "Click=" & mChk.Value
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
