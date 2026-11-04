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

Private Sub Class_Initialize()
    Set mForm = Nothing
    Set mReducer = Nothing
    Set mT1 = Nothing
    Set mT2 = Nothing
    Set mLbl = Nothing
End Sub

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

Public Sub Render()
    mForm.Render 96, 96
End Sub

Public Sub SetClipboardText(ByVal Text As String)
    mReducer.SetClipboardText Text
End Sub

Public Property Get ClipboardText() As String
    ClipboardText = mReducer.ClipboardText
End Property

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

Public Property Get T1Value() As String
    T1Value = mT1.Value
End Property

Public Property Get T1SelStart() As Long
    T1SelStart = mT1.SelStart
End Property

Public Property Get T1SelLength() As Long
    T1SelLength = mT1.SelLength
End Property

Public Property Get T1SelText() As String
    T1SelText = mT1.SelText
End Property

Public Property Get T1HideSelection() As Boolean
    T1HideSelection = mT1.HideSelection
End Property

Public Property Get T1MultiLine() As Boolean
    T1MultiLine = mT1.MultiLine
End Property

Public Property Get T1CanUndo() As Boolean
    T1CanUndo = mT1.CanUndo
End Property

Public Property Get T1CanRedo() As Boolean
    T1CanRedo = mT1.CanRedo
End Property

Public Property Get T1CompositionActive() As Boolean
    T1CompositionActive = mT1.CompositionActive
End Property

Public Property Get T1CompositionText() As String
    T1CompositionText = mT1.CompositionText
End Property

Public Property Get T1Diagnostics() As String
    T1Diagnostics = _
        "text=" & mT1.Text & _
        ";value=" & mT1.Value & _
        ";sel_start=" & CStr(mT1.SelStart) & _
        ";sel_length=" & CStr(mT1.SelLength) & _
        ";sel_text=" & mT1.SelText & _
        ";hide_selection=" & CStr(mT1.HideSelection) & _
        ";multiline=" & CStr(mT1.MultiLine) & _
        ";can_undo=" & CStr(mT1.CanUndo) & _
        ";can_redo=" & CStr(mT1.CanRedo) & _
        ";composition_active=" & CStr(mT1.CompositionActive) & _
        ";composition_text=" & mT1.CompositionText & _
        ";capabilities=" & mT1.Core.CapabilityDescriptor
End Property

Public Sub SetT1Text(ByVal Value As String)
    mT1.Text = Value
    mT1.SelStart = Len(Value)
    mT1.SelLength = 0
End Sub

Public Sub SetT1Value(ByVal Value As String)
    mT1.Value = Value
End Sub

Public Sub SetT1Selection(ByVal Start As Long, ByVal Length As Long)
    mT1.SelStart = Start
    mT1.SelLength = Length
End Sub

Public Sub SetT1SelText(ByVal Value As String)
    mT1.SelText = Value
End Sub

Public Sub SetT1HideSelection(ByVal Value As Boolean)
    mT1.HideSelection = Value
End Sub

Public Sub SetT1MultiLine(ByVal Value As Boolean)
    mT1.MultiLine = Value
End Sub

Public Sub T1Undo()
    mT1.Undo
End Sub

Public Sub T1Redo()
    mT1.Redo
End Sub

Public Sub T1BeginComposition()
    mT1.BeginComposition
End Sub

Public Sub T1UpdateComposition(ByVal PreeditText As String)
    mT1.UpdateComposition PreeditText
End Sub

Public Sub T1CommitComposition(ByVal CommitText As String)
    mT1.CommitComposition CommitText
End Sub

Public Sub T1CancelComposition()
    mT1.CancelComposition
End Sub

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
    ' Swallow Escape too: unlike Q, it has no paired CharacterInput, so the next real character
    ' must not be eaten by stale swallow state.
    If KeyCode.Value = 27 Then KeyCode.Value = 0
End Sub
Private Sub mT1_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "T1.KeyUp"
End Sub
Private Sub mT1_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "T1.KeyPress"
    ' Swallow the character 'Z' (90) at the KeyPress level to prove a zeroed KeyAscii suppresses
    ' the insert + Change (distinct from the KeyDown swallow above).
    If KeyAscii.Value = 90 Then KeyAscii.Value = 0
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
