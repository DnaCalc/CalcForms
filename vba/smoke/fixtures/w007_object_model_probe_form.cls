Option Explicit

' W007 object-model proving fixture (oxforms-4pn.3). Test infrastructure, not the
' OxForms library. It exercises the object model the way a real user form (and,
' later, the .frm loader + runtime) will: build controls through Controls.Add by
' Forms 2.0 ProgID, hold them as WithEvents fields, handle native control events with ordinary
' VBA handler code. The Perform*/ApplyUserText calls below stand in for the
' runtime's input dispatch so a host test can drive the form without a window.

Private mForm As UserForm
Private WithEvents OkButton As CommandButton
Private WithEvents InputField As TextBox
Private OutputLabel As Label
Private mLog As String

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "greeter"
    mForm.Caption = "Greeter"
    mForm.Width = 200
    mForm.Height = 120

    Set InputField = mForm.Controls.Add("Forms.TextBox.1", "InputField")
    InputField.Left = 12
    InputField.Top = 12
    InputField.Width = 120
    InputField.Height = 18

    Set OkButton = mForm.Controls.Add("Forms.CommandButton.1", "OkButton")
    OkButton.Caption = "OK"
    OkButton.Left = 140
    OkButton.Top = 12
    OkButton.Width = 60
    OkButton.Height = 20

    Set OutputLabel = mForm.Controls.Add("Forms.Label.1", "OutputLabel")
    OutputLabel.Caption = "(idle)"
    OutputLabel.Left = 12
    OutputLabel.Top = 40
    OutputLabel.Width = 188
    OutputLabel.Height = 18
End Sub

Public Property Get Form() As UserForm
    Set Form = mForm
End Property

Public Property Get OutputCaption() As String
    OutputCaption = OutputLabel.Caption
End Property

Public Property Get Log() As String
    Log = mLog
End Property

' --- Runtime-input stand-ins ---
Public Sub TypeIntoInput(ByVal Text As String)
    InputField.ApplyUserText Text
End Sub

Public Sub ClickOk()
    OkButton.PerformClick
End Sub

Public Function SendInputKeyDown(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    SendInputKeyDown = InputField.PerformKeyDown(KeyCode, Shift)
End Function

Public Function SendInputExit() As Boolean
    SendInputExit = InputField.PerformExit()
End Function

' --- Ordinary VBA event handlers (the user-facing surface) ---
Private Sub InputField_Change()
    Append "InputField_Change=" & InputField.Text
End Sub

Private Sub InputField_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "InputField_KeyDown=" & KeyCode.Value & ";Shift=" & Shift
    If KeyCode.Value = 27 Then
        KeyCode.Value = 0
    End If
End Sub

Private Sub InputField_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "InputField_KeyUp=" & KeyCode.Value & ";Shift=" & Shift
    If KeyCode.Value = 27 Then
        KeyCode.Value = 0
    End If
End Sub

' Native FM20 focus-exit event (reserved word, handled as InputField_Exit). Sets
' the mutable Cancel to keep focus, proving the ReturnBoolean round-trip.
Private Sub InputField_Exit(ByVal Cancel As ReturnBoolean)
    Append "InputField_Exit"
    Cancel.Value = True
End Sub

Private Sub OkButton_Click()
    Append "OkButton_Click"
    OutputLabel.Caption = "Hello, " & InputField.Text
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then
        mLog = mLog & vbLf
    End If
    mLog = mLog & Line
End Sub
