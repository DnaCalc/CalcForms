Option Explicit

' Reducer-pivot increment 5 proof fixture (oxforms-ih6.5; test infrastructure). A TextBox plus a
' default button (OK), a cancel button (Cancel), an accelerator button ("&Go"), and a CheckBox,
' driven through OxReducer. WithEvents sinks record the events so the tests can assert: Enter on a
' field activates the default button (focus moves + Click), Escape activates the cancel button in
' place, Alt+letter activates the matching button, and Space toggles the focused CheckBox
' (value-first: Change/Click before KeyDown). No Rust reducer in the loop.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mField As TextBox
Private WithEvents mOk As CommandButton
Private WithEvents mCancelBtn As CommandButton
Private WithEvents mGo As CommandButton
Private WithEvents mChk As CheckBox
Private mLog As String

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "btnform"
    mForm.Width = 180
    mForm.Height = 130

    Set mField = mForm.Controls.Add("Forms.TextBox.1", "Field")
    mField.Left = 20
    mField.Top = 20
    mField.Width = 100
    mField.Height = 18

    Set mOk = mForm.Controls.Add("Forms.CommandButton.1", "Ok")
    mOk.Caption = "OK"
    mOk.Default = True
    mOk.Left = 20
    mOk.Top = 45
    mOk.Width = 60
    mOk.Height = 20

    Set mCancelBtn = mForm.Controls.Add("Forms.CommandButton.1", "CancelBtn")
    mCancelBtn.Caption = "Cancel"
    mCancelBtn.Cancel = True
    mCancelBtn.Left = 90
    mCancelBtn.Top = 45
    mCancelBtn.Width = 60
    mCancelBtn.Height = 20

    Set mGo = mForm.Controls.Add("Forms.CommandButton.1", "Go")
    mGo.Caption = "&Go"
    mGo.Left = 20
    mGo.Top = 70
    mGo.Width = 60
    mGo.Height = 20

    Set mChk = mForm.Controls.Add("Forms.CheckBox.1", "Chk")
    mChk.Caption = "Opt"
    mChk.Left = 20
    mChk.Top = 95
    mChk.Width = 100
    mChk.Height = 18

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

Public Property Get FocusName() As String
    FocusName = mReducer.FocusName
End Property

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Public Sub ClearLog()
    mLog = ""
End Sub

Public Property Get ChkValue() As Boolean
    ChkValue = mChk.Value
End Property

' --- Event sinks ---
Private Sub mField_Enter()
    Append "Field.Enter"
End Sub
Private Sub mField_Exit(ByVal Cancel As ReturnBoolean)
    Append "Field.Exit"
End Sub
Private Sub mField_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "Field.KeyDown"
End Sub

Private Sub mOk_Enter()
    Append "Ok.Enter"
End Sub
Private Sub mOk_Click()
    Append "Ok.Click"
End Sub

Private Sub mCancelBtn_Click()
    Append "Cancel.Click"
End Sub

Private Sub mGo_Enter()
    Append "Go.Enter"
End Sub
Private Sub mGo_Click()
    Append "Go.Click"
End Sub

Private Sub mChk_Change()
    Append "Chk.Change"
End Sub
Private Sub mChk_Click()
    Append "Chk.Click"
End Sub
Private Sub mChk_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "Chk.KeyDown"
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
