Option Explicit

' Reducer-pivot increment 3 proof fixture (oxforms-ih6.3; test infrastructure). Two TextBoxes
' driven through OxReducer. WithEvents sinks record the focus/keyboard/validation events so the
' tests can assert the oracle orderings: typing fires KeyDown -> KeyPress -> Change -> KeyUp; a
' clean focus change fires Exit -> Enter; a dirty focus-out fires BeforeUpdate -> AfterUpdate ->
' Exit -> Enter; and an Exit or BeforeUpdate veto keeps focus. No Rust reducer in the loop.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mT1 As TextBox
Private WithEvents mT2 As TextBox
Private WithEvents mLbl As Label
Private mLog As String
Private mT1ExitVeto As Boolean
Private mT1BeforeUpdateVeto As Boolean
Private mT1PasteVeto As Boolean

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "tbform"
    mForm.Width = 160
    mForm.Height = 100

    Set mT1 = mForm.Controls.Add("Forms.TextBox.1", "T1")
    mT1.Left = 20
    mT1.Top = 20
    mT1.Width = 100
    mT1.Height = 18

    Set mT2 = mForm.Controls.Add("Forms.TextBox.1", "T2")
    mT2.Left = 20
    mT2.Top = 50
    mT2.Width = 100
    mT2.Height = 18

    ' A Label (not focusable, not a tab stop) to pin click routing + that it never takes focus.
    Set mLbl = mForm.Controls.Add("Forms.Label.1", "Lbl")
    mLbl.Caption = "L"
    mLbl.Left = 20
    mLbl.Top = 75
    mLbl.Width = 100
    mLbl.Height = 18

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

Public Function DispatchDrop(ByVal Text As String) As String
    DispatchDrop = mReducer.DispatchDrop(Text)
End Function

Public Sub SetClipboardText(ByVal Text As String)
    mReducer.SetClipboardText Text
End Sub

Public Sub ArmT1PasteVeto()
    mT1PasteVeto = True
End Sub

Public Property Get FocusName() As String
    FocusName = mReducer.FocusName
End Property

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Public Sub ClearLog()
    mLog = ""
End Sub

Public Property Get T1Text() As String
    T1Text = mT1.Text
End Property

Public Property Get T2Text() As String
    T2Text = mT2.Text
End Property

Public Sub ArmT1ExitVeto()
    mT1ExitVeto = True
End Sub

Public Sub ArmT1BeforeUpdateVeto()
    mT1BeforeUpdateVeto = True
End Sub

' --- T1 event sink ---
Private Sub mT1_Enter()
    Append "T1.Enter"
End Sub
Private Sub mT1_Exit(ByVal Cancel As ReturnBoolean)
    Append "T1.Exit"
    Cancel.Value = mT1ExitVeto
End Sub
Private Sub mT1_BeforeUpdate(ByVal Cancel As ReturnBoolean)
    Append "T1.BeforeUpdate"
    Cancel.Value = mT1BeforeUpdateVeto
End Sub
Private Sub mT1_AfterUpdate()
    Append "T1.AfterUpdate"
End Sub
Private Sub mT1_Change()
    Append "T1.Change"
End Sub
Private Sub mT1_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "T1.KeyDown"
    ' Swallow the letter 'Q' (81) to prove a swallowed KeyDown suppresses the next character.
    If KeyCode.Value = 81 Then KeyCode.Value = 0
End Sub
Private Sub mT1_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "T1.KeyUp"
End Sub
Private Sub mT1_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "T1.KeyPress"
End Sub
Private Sub mT1_BeforeDropOrPaste(ByVal Cancel As ReturnBoolean, ByVal Action As Integer, ByVal Shift As Integer)
    Append "T1.BeforeDropOrPaste"
    Cancel.Value = mT1PasteVeto
End Sub

' --- T2 event sink (focus target) ---
Private Sub mT2_Enter()
    Append "T2.Enter"
End Sub
Private Sub mT2_Exit(ByVal Cancel As ReturnBoolean)
    Append "T2.Exit"
End Sub

' --- Label sink (display-only; click routes but never focuses) ---
Private Sub mLbl_Click()
    Append "Lbl.Click"
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
