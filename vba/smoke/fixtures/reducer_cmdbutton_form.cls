Option Explicit

' Reducer-pivot increment 1 proof fixture (oxforms-ih6.1; test infrastructure, not the
' OxForms library). Builds a form with one CommandButton, an OxReducer, and a WithEvents sink
' that records the REAL FM20 events the reducer raises. A host test drives OxReducer.Dispatch
' with normalized pointer input and asserts both the reducer's ordered effect log AND that the
' native Click fired in order -- with no Rust reducer (oxforms-core) in the loop. The Perform*
' fixtures used elsewhere stand in for the runtime; here the OxReducer makes the routing +
' sequencing decision the Rust reduce() used to make.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mBtn As CommandButton
Private mLog As String

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "rform"
    mForm.Width = 160
    mForm.Height = 80

    Set mBtn = mForm.Controls.Add("Forms.CommandButton.1", "Btn1")
    mBtn.Caption = "OK"
    mBtn.Left = 20
    mBtn.Top = 20
    mBtn.Width = 80
    mBtn.Height = 30

    Set mReducer = New OxReducer
    mReducer.Init mForm

    ' Establish the resident scene (the runtime's first frame) so reducer repaints are
    ' incremental, exercising the real render seam.
    mForm.Render 96, 96
End Sub

' Drive the VBA reducer with a normalized pointer event; returns its ordered effect log.
Public Function Dispatch( _
        ByVal Kind As String, ByVal X As Long, ByVal Y As Long, _
        ByVal Button As Integer, ByVal Shift As Integer) As String
    Dispatch = mReducer.Dispatch(Kind, X, Y, Button, Shift)
End Function

' The real FM20 events the reducer raised, in order (one per line) -- proof the native event
' pipeline fired, not just the reducer's own log.
Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

' The button's armed pressed visual state (reducer-owned interaction state).
Public Property Get Pressed() As Boolean
    Pressed = mBtn.Core.Pressed
End Property

Public Property Get Form() As UserForm
    Set Form = mForm
End Property

' --- Ordinary VBA event handlers (the user-facing surface the reducer drives) ---
Private Sub mBtn_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "MouseDown"
End Sub

Private Sub mBtn_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "MouseUp"
End Sub

Private Sub mBtn_Click()
    Append "Click"
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
