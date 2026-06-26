Option Explicit

' rq5.2 invalidation-coalescing fixture. Test infrastructure, not the OxForms library.
' Proves the SuspendLayout/ResumeLayout band + NodeId dedup: a bulk multi-setter update
' inside the band invalidates each touched control exactly once, so the next incremental
' render emits one node per CHANGED control (not one per setter, and not the whole form).
'
' Build constructs a two-label form; RenderOnce re-renders it (first frame full, then
' incremental against the resident token); BulkUpdateSuspended runs a suspended update.

Private mForm As UserForm
Private mLabel1 As Label
Private mLabel2 As Label

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "invalidation"
    mForm.Width = 200
    mForm.Height = 120

    Set mLabel1 = mForm.Controls.Add("Forms.Label.1", "Label1")
    mLabel1.Left = 10
    mLabel1.Top = 10
    mLabel1.Caption = "One"

    Set mLabel2 = mForm.Controls.Add("Forms.Label.1", "Label2")
    mLabel2.Left = 10
    mLabel2.Top = 40
    mLabel2.Caption = "Two"
End Sub

Public Sub RenderOnce()
    mForm.Render 96, 96
End Sub

' Three render-affecting setters on Label1 + one on Label2, all inside one
' SuspendLayout/ResumeLayout band. With per-setter notification suppressed and NodeId
' dedup, exactly two controls end up invalidated (each once) -> the next incremental render
' emits two nodes, not four.
Public Sub BulkUpdateSuspended()
    mForm.SuspendLayout
    mLabel1.Core.Left = 20
    mLabel1.Core.Top = 20
    mLabel1.Core.Width = 90
    mLabel2.Core.Left = 30
    mForm.ResumeLayout
End Sub

' A SECOND suspended band touching ONLY Label1. Because each emit clears Core.Dirty, the
' next incremental render invalidates exactly Label1 -> one node. (Before the rq5.2 fix that
' clears Core.Dirty on emit, Label2 stayed stale-dirty from the earlier band and was wrongly
' re-emitted, so this would have produced two nodes.)
Public Sub BulkUpdateSuspendedLabel1Only()
    mForm.SuspendLayout
    mLabel1.Core.Left = 55
    mForm.ResumeLayout
End Sub

' Two NON-suspended setters on Label1: each fires OnControlInvalidated, so RecordInvalidated
' must dedup Label1 to a single entry (exercises its NodeId membership scan, not the suspend
' band) -> the next incremental render still emits exactly one node.
Public Sub BulkUpdateUnsuspendedLabel1()
    mLabel1.Core.Left = 70
    mLabel1.Core.Top = 70
End Sub

' Forms 2.0 robustness probe: Controls.Add of an UNKNOWN ProgID, and of a recognized-but-
' unimplemented one ("Forms.CheckBox.1" has no class yet), must return Nothing WITHOUT
' crashing and must NOT register a phantom control. (Guards the rq5-fek Nothing-handling in
' Controls.Add.) The returned controls are intentionally ignored.
Public Sub TryAddUnsupportedControls()
    Dim Bogus As IOxControl
    Set Bogus = mForm.Controls.Add("Forms.Bogus.1", "bogus")
    Dim Chk As IOxControl
    Set Chk = mForm.Controls.Add("Forms.CheckBox.1", "chk")
End Sub
