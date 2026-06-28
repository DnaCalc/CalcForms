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
' When True, InputField_Exit vetoes (Cancel = True). Default False -- a realistic field
' that releases focus, so the demo flow (focus field, type, click OK) lets OkButton_Click
' fire. The focus-validation conformance tests arm the veto via ArmExitVeto to exercise
' the Exit-veto-keeps-focus + ReturnBoolean readback paths (oxforms-esq.11).
Private mExitVeto As Boolean
' When True, InputField_BeforeUpdate vetoes (Cancel = True). Default False. Armed via
' ArmBeforeUpdateVeto to exercise the two-stage BeforeUpdate veto end-to-end (oxforms-esq.11).
Private mBeforeUpdateVeto As Boolean

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

' KeyPress carries a mutable KeyAscii; setting it to 0 swallows the character.
Private Sub InputField_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "InputField_KeyPress=" & KeyAscii.Value
    If KeyAscii.Value = 90 Then
        KeyAscii.Value = 0
    End If
End Sub

' Native FM20 focus-exit event (reserved word, handled as InputField_Exit). When the
' veto is armed it sets the mutable Cancel to keep focus, proving the ReturnBoolean
' round-trip; otherwise it releases focus (the default) so a click on OK commits.
Private Sub InputField_Exit(ByVal Cancel As ReturnBoolean)
    Append "InputField_Exit"
    Cancel.Value = mExitVeto
End Sub

' Arm the InputField_Exit veto for the focus-validation conformance tests. Called outside
' the event pipeline via RuntimeRunner.invoke_form_sub (oxforms-esq.11).
Public Sub ArmExitVeto()
    mExitVeto = True
End Sub

' Native FM20 BeforeUpdate event (oxforms-esq.7). When the veto is armed it sets the mutable
' Cancel to suppress the value commit (no AfterUpdate/Exit/Enter and focus stays); otherwise
' it releases (the default). Fires only on a dirty (edited) focus-out, before Exit.
Private Sub InputField_BeforeUpdate(ByVal Cancel As ReturnBoolean)
    Append "InputField_BeforeUpdate"
    Cancel.Value = mBeforeUpdateVeto
End Sub

' Arm the InputField_BeforeUpdate veto for the two-stage validation conformance test.
' Called outside the event pipeline via RuntimeRunner.invoke_form_sub (oxforms-esq.11).
Public Sub ArmBeforeUpdateVeto()
    mBeforeUpdateVeto = True
End Sub

Private Sub OkButton_Click()
    Append "OkButton_Click"
    OutputLabel.Caption = "Hello, " & InputField.Text
End Sub

' --- Form-level FM20 dispatch surface (oxforms-esq.2) ---
' The runtime invokes these Perform* members on the form module for form-targeted
' events (no control to call Perform* on); each calls the form's own UserForm_*
' handler. PerformQueryClose carries a mutable Cancel (ReturnInteger) the handler can
' set nonzero to veto the close, and returns the post-handler value.
Public Sub PerformInitialize()
    UserForm_Initialize
End Sub

Public Sub PerformActivate()
    UserForm_Activate
End Sub

Public Sub PerformDeactivate()
    UserForm_Deactivate
End Sub

Public Sub PerformTerminate()
    UserForm_Terminate
End Sub

Public Function PerformQueryClose(ByVal CloseMode As Integer) As Integer
    Dim Cancel As ReturnInteger
    Set Cancel = New ReturnInteger
    Cancel.Value = 0
    UserForm_QueryClose Cancel, CloseMode
    PerformQueryClose = Cancel.Value
End Function

' Form-level handlers (the form's own events).
Private Sub UserForm_Initialize()
    Append "UserForm_Initialize"
End Sub

Private Sub UserForm_Activate()
    Append "UserForm_Activate"
End Sub

Private Sub UserForm_Deactivate()
    Append "UserForm_Deactivate"
End Sub

Private Sub UserForm_Terminate()
    Append "UserForm_Terminate"
End Sub

' Vetoes a user/control-menu close (CloseMode 0 = vbFormControlMenu) and allows a
' code Unload (CloseMode 1), proving the readback reflects the handler's decision.
Private Sub UserForm_QueryClose(ByVal Cancel As ReturnInteger, ByVal CloseMode As Integer)
    Append "UserForm_QueryClose;CloseMode=" & CloseMode
    If CloseMode = 0 Then
        Cancel.Value = -1
    End If
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then
        mLog = mLog & vbLf
    End If
    mLog = mLog & Line
End Sub
