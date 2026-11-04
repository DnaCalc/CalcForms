Option Explicit

' W009 Frame representative fixture: a root Frame owns nested controls with local
' coordinates. OxReducer should route pointer/keyboard/focus through the tree.

Private mForm As UserForm
Private mReducer As OxReducer
Private mFrame As Frame
Private WithEvents mInner As TextBox
Private WithEvents mInnerButton As CommandButton
Private WithEvents mClipped As TextBox
Private WithEvents mOuter As TextBox
Private mLog As String

Private Sub Class_Initialize()
    Set mForm = Nothing
    Set mReducer = Nothing
    Set mFrame = Nothing
    Set mInner = Nothing
    Set mInnerButton = Nothing
    Set mClipped = Nothing
    Set mOuter = Nothing
End Sub

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "frameform"
    mForm.Width = 260
    mForm.Height = 170

    Set mFrame = mForm.Controls.Add("Forms.Frame.1", "Group")
    mFrame.Caption = "Group"
    mFrame.Left = 20
    mFrame.Top = 20
    mFrame.Width = 180
    mFrame.Height = 90

    Set mInner = mFrame.Controls.Add("Forms.TextBox.1", "InnerField")
    mInner.Left = 10
    mInner.Top = 18
    mInner.Width = 90
    mInner.Height = 20
    mInner.Core.TabIndex = 0

    Set mInnerButton = mFrame.Controls.Add("Forms.CommandButton.1", "InnerButton")
    mInnerButton.Caption = "Inside"
    mInnerButton.Left = 108
    mInnerButton.Top = 18
    mInnerButton.Width = 54
    mInnerButton.Height = 20
    mInnerButton.Core.TabIndex = 1

    Set mClipped = mFrame.Controls.Add("Forms.TextBox.1", "ClippedField")
    mClipped.Left = 10
    mClipped.Top = 55
    mClipped.Width = 90
    mClipped.Height = 40
    mClipped.Text = "clip"
    mClipped.Core.TabIndex = 3

    Set mOuter = mForm.Controls.Add("Forms.TextBox.1", "OuterField")
    mOuter.Left = 20
    mOuter.Top = 124
    mOuter.Width = 100
    mOuter.Height = 20
    mOuter.Core.TabIndex = 2

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

Public Property Get FocusName() As String
    FocusName = mReducer.FocusName
End Property

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Public Sub ClearLog()
    mLog = ""
End Sub

Public Property Get RootControlCount() As Long
    RootControlCount = mForm.Controls.Count
End Property

Public Property Get FrameChildCount() As Long
    FrameChildCount = mFrame.Controls.Count
End Property

Public Property Get InnerText() As String
    InnerText = mInner.Text
End Property

Public Property Get FrameDiagnostics() As String
    FrameDiagnostics = mFrame.Diagnostics
End Property

Public Property Get InteractionIndexSummary() As String
    InteractionIndexSummary = mReducer.InteractionIndexSummary
End Property

Public Property Get AccessibilitySnapshot() As String
    AccessibilitySnapshot = mReducer.AccessibilitySnapshot
End Property

Public Sub RemoveInnerButton()
    mFrame.Controls.Remove "InnerButton"
End Sub

Public Sub Render()
    mForm.Render 96, 96
End Sub

Private Sub mInner_Enter()
    Append "Inner.Enter"
End Sub
Private Sub mInner_Exit(ByVal Cancel As ReturnBoolean)
    Append "Inner.Exit"
End Sub
Private Sub mInner_BeforeUpdate(ByVal Cancel As ReturnBoolean)
    Append "Inner.BeforeUpdate"
End Sub
Private Sub mInner_AfterUpdate()
    Append "Inner.AfterUpdate"
End Sub
Private Sub mInner_Change()
    Append "Inner.Change:" & mInner.Text
End Sub
Private Sub mInner_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Inner.MouseDown:" & CStr(CLng(X)) & "," & CStr(CLng(Y))
End Sub
Private Sub mInner_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Inner.MouseUp:" & CStr(CLng(X)) & "," & CStr(CLng(Y))
End Sub
Private Sub mInner_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "Inner.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mInner_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "Inner.KeyPress:" & CStr(KeyAscii.Value)
End Sub

Private Sub mInnerButton_Enter()
    Append "InnerButton.Enter"
End Sub
Private Sub mInnerButton_Click()
    Append "InnerButton.Click"
End Sub

Private Sub mClipped_Enter()
    Append "Clipped.Enter"
End Sub
Private Sub mClipped_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Clipped.MouseDown:" & CStr(CLng(X)) & "," & CStr(CLng(Y))
End Sub
Private Sub mClipped_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Clipped.MouseUp:" & CStr(CLng(X)) & "," & CStr(CLng(Y))
End Sub

Private Sub mOuter_Enter()
    Append "Outer.Enter"
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
