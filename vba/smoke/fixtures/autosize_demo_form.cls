Option Explicit

' W007 AutoSize layout proving fixture (oxforms-4pn.14). Test infrastructure, not the
' OxForms library. A bordered AutoSize label shrink-wraps its caption: the measure ->
' layout -> paint pipeline derives the label's bounds from OxForms.Surface.MeasureText
' metrics, so a font-size change re-measures and the box re-fits. This makes the metrics
' round-trip load-bearing (a wrong measurement would be a visibly wrong box).
'
' Build constructs the form; RenderOnce re-renders it across OxForms.Surface (so the
' resident scene reflects the current size); GrowFont bumps the label's font size.

Private mForm As UserForm
Private mLabel As Label

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "autosize"
    mForm.Width = 200
    mForm.Height = 120

    Set mLabel = mForm.Controls.Add("Forms.Label.1", "AutoLabel")
    mLabel.Left = 12
    mLabel.Top = 12
    mLabel.Caption = "Size me"
    ' Shrink-wrap the caption with a single-line border (the box hugs the text).
    mLabel.Core.AutoSize = True
    mLabel.Core.BorderStyle = fmBorderStyleSingle
End Sub

Public Sub RenderOnce()
    mForm.Render 96, 96
End Sub

Public Sub GrowFont()
    mLabel.Core.FontSize = mLabel.Core.FontSize + 6
End Sub
