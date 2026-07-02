Option Explicit

' Reducer-pivot increment 1 hit-routing fixture (oxforms-ih6.1; test infrastructure). Two
' OVERLAPPING CommandButtons exercise the part of geometric routing most likely to diverge
' from the oracle kernel: OxReducer.HitTest's z-order + last-added tie-break (the VBA port of
' oxforms-core hit_test_control_tree's max_by_key((z_order, index))), and capture routing of a
' MouseUp back to the pressed control across a sibling. WithEvents sinks on both buttons record
' which control actually received each native event.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mA As CommandButton
Private WithEvents mB As CommandButton
Private mLog As String

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "hitform"
    mForm.Width = 200
    mForm.Height = 100

    ' A: x in [20,100), y in [20,60). B: x in [40,120), y in [20,60). Overlap x in [40,100).
    ' B is added AFTER A, so on an equal-z tie B (later index) wins, matching the kernel.
    Set mA = mForm.Controls.Add("Forms.CommandButton.1", "A")
    mA.Caption = "A"
    mA.Left = 20
    mA.Top = 20
    mA.Width = 80
    mA.Height = 40

    Set mB = mForm.Controls.Add("Forms.CommandButton.1", "B")
    mB.Caption = "B"
    mB.Left = 40
    mB.Top = 20
    mB.Width = 80
    mB.Height = 40

    Set mReducer = New OxReducer
    mReducer.Init mForm
    mForm.Render 96, 96
End Sub

Public Function Dispatch( _
        ByVal Kind As String, ByVal X As Long, ByVal Y As Long, _
        ByVal Button As Integer, ByVal Shift As Integer) As String
    Dispatch = mReducer.Dispatch(Kind, X, Y, Button, Shift)
End Function

' Set a control's z-order by name, so a test can make A win the overlap (higher z) after the
' default equal-z tie sends it to B.
Public Sub SetZOrder(ByVal Name As String, ByVal Z As Long)
    mForm.ControlByName(Name).Core.ZOrder = Z
End Sub

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Public Property Get InteractionStateSummary() As String
    InteractionStateSummary = mReducer.InteractionStateSummary
End Property

Private Sub mA_Click()
    Append "A.Click"
End Sub
Private Sub mB_Click()
    Append "B.Click"
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
