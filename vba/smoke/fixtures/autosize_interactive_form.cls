Option Explicit

' Interactive AutoSize demo form (oxforms-rq5.2 live showcase). Test/demo infrastructure,
' not the OxForms library. A bordered AutoSize label shrink-wraps its caption; a "Grow
' font" CommandButton's native Click handler bumps the label's font size, so the measure ->
' layout -> paint pipeline re-fits the box on screen. Because only the label (and the
' button) are invalidated, the runtime re-renders incrementally (rq5.2) -- the form is not
' rebuilt. Modeled on w007_object_model_probe_form: Build constructs the controls, the
' button is held WithEvents, and an ordinary VBA handler does the work.

Private mForm As UserForm
Private WithEvents GrowButton As CommandButton
Private mLabel As Label

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "autosizeDemo"
    mForm.Caption = "AutoSize"
    mForm.Width = 260
    mForm.Height = 160

    Set GrowButton = mForm.Controls.Add("Forms.CommandButton.1", "GrowButton")
    GrowButton.Caption = "Grow font"
    GrowButton.Left = 12
    GrowButton.Top = 12
    GrowButton.Width = 100
    GrowButton.Height = 24

    Set mLabel = mForm.Controls.Add("Forms.Label.1", "AutoLabel")
    mLabel.Caption = "Size me"
    mLabel.Left = 12
    mLabel.Top = 56
    ' Shrink-wrap the caption with a single-line border (the box hugs the text and re-fits
    ' as the font grows).
    mLabel.Core.AutoSize = True
    mLabel.Core.BorderStyle = fmBorderStyleSingle
End Sub

Public Property Get Form() As UserForm
    Set Form = mForm
End Property

' Native FM20 Click: grow the label's font by 4pt, cycling 8 -> 28 -> 8 so repeated clicks
' keep showing the box re-fit. The FontSize setter marks the label dirty, so the next
' re-render re-measures it and the hugging border tracks the new text size.
Private Sub GrowButton_Click()
    Dim NewSize As Single
    NewSize = mLabel.Core.FontSize + 4
    If NewSize > 28 Then NewSize = 8
    mLabel.Core.FontSize = NewSize
End Sub
