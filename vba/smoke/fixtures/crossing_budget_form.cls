Option Explicit

' rq5.3 crossing-budget probe. Test infrastructure, not the OxForms library. Builds Count
' Label controls so a test can assert the VBA->Rust crossing count of a steady-state change
' is INDEPENDENT of the control count (the §6 budget): changing one control crosses one
' incremental SubmitPatch + at most one MeasureText, regardless of the other controls. This
' is the rq5.2 incremental-invalidation payoff, measured as a P6 gate.

Private mForm As UserForm
Private mFirst As Label

Public Sub Build(ByVal Count As Long)
    Set mForm = New UserForm
    mForm.Name = "crossingBudget"
    mForm.Width = 200
    mForm.Height = 600

    Dim I As Long, Lbl As Label
    For I = 1 To Count
        Set Lbl = mForm.Controls.Add("Forms.Label.1", "L" & CStr(I))
        Lbl.Caption = "Item " & CStr(I)
        Lbl.Left = 8
        Lbl.Top = I * 14
        If I = 1 Then Set mFirst = Lbl
    Next I
End Sub

Public Sub RenderOnce()
    mForm.Render 96, 96
End Sub

' Change exactly ONE control (the first label's caption): the steady-state "keystroke".
Public Sub ChangeOne()
    mFirst.Caption = "Changed"
End Sub
