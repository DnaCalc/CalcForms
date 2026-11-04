Option Explicit

' W009 reentrancy/lifecycle hazard fixture. It intentionally keeps the modal
' side as an explicit blocker while proving handler mutation, nested reducer
' dispatch, validation veto, lifecycle callback ordering, and same-turn repaint
' through the normal OxRuntime -> OxReducer -> UserForm.Render path.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mField As TextBox
Private WithEvents mTarget As TextBox
Private WithEvents mReenter As CommandButton
Private WithEvents mStatus As Label
Private mLog As String
Private mBeforeUpdateVeto As Boolean
Private mHidden As Boolean
Private mUnloaded As Boolean
Private mQueryCloseVeto As Boolean

Private Sub Class_Initialize()
    Set mForm = Nothing
    Set mReducer = Nothing
    Set mField = Nothing
    Set mTarget = Nothing
    Set mReenter = Nothing
    Set mStatus = Nothing
End Sub

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "reentrancy_form"
    mForm.Caption = "Reentrancy"
    mForm.Width = 260
    mForm.Height = 150
    mHidden = False
    mUnloaded = False
    mQueryCloseVeto = False
    mBeforeUpdateVeto = False

    Set mField = mForm.Controls.Add("Forms.TextBox.1", "Field")
    mField.Left = 20
    mField.Top = 20
    mField.Width = 100
    mField.Height = 18

    Set mTarget = mForm.Controls.Add("Forms.TextBox.1", "Target")
    mTarget.Left = 20
    mTarget.Top = 54
    mTarget.Width = 100
    mTarget.Height = 18

    Set mReenter = mForm.Controls.Add("Forms.CommandButton.1", "Reenter")
    mReenter.Caption = "Reenter"
    mReenter.Left = 138
    mReenter.Top = 20
    mReenter.Width = 80
    mReenter.Height = 24

    Set mStatus = mForm.Controls.Add("Forms.Label.1", "Status")
    mStatus.Caption = "ready"
    mStatus.Left = 20
    mStatus.Top = 96
    mStatus.Width = 200
    mStatus.Height = 18

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

Public Sub SetClipboardText(ByVal Text As String)
    mReducer.SetClipboardText Text
End Sub

Public Sub Render()
    mForm.Render 96, 96
End Sub

Public Property Get FocusName() As String
    FocusName = mReducer.FocusName
End Property

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Public Property Get FieldText() As String
    FieldText = mField.Text
End Property

Public Property Get TargetText() As String
    TargetText = mTarget.Text
End Property

Public Property Get StatusCaption() As String
    StatusCaption = mStatus.Caption
End Property

Public Property Get LifecycleSummary() As String
    LifecycleSummary = _
        "hidden=" & CStr(mHidden) & _
        ";unloaded=" & CStr(mUnloaded) & _
        ";query_veto=" & CStr(mQueryCloseVeto) & _
        ";modal=BLOCKED:no nested modal pump in OxRuntime yet"
End Property

Public Property Get AccessibilitySnapshot() As String
    AccessibilitySnapshot = mReducer.AccessibilitySnapshot
End Property

Public Sub ClearLog()
    mLog = ""
End Sub

Public Sub ArmBeforeUpdateVeto()
    mBeforeUpdateVeto = True
End Sub

Public Sub ArmQueryCloseVeto()
    mQueryCloseVeto = True
End Sub

Public Function RequestHide() As String
    mHidden = True
    mForm.Caption = "hidden"
    mForm.Render 96, 96
    Append "Form.HideRequested"
    RequestHide = LifecycleSummary
End Function

Public Function RequestUnload() As String
    mUnloaded = True
    mForm.Controls.Remove "Reenter"
    mForm.Render 96, 96
    Append "Form.UnloadRequested"
    RequestUnload = LifecycleSummary
End Function

Public Function ModalProbe() As String
    ModalProbe = "BLOCKED:no nested modal pump in OxRuntime yet"
End Function

Public Function QueryCloseAllowed() As String
    mQueryCloseVeto = False
    QueryCloseAllowed = "cancel=" & CStr(PerformQueryClose(1))
End Function

Public Function QueryCloseVetoed() As String
    mQueryCloseVeto = True
    QueryCloseVetoed = "cancel=" & CStr(PerformQueryClose(0))
End Function

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
    UserForm_QueryClose Cancel, CloseMode
    PerformQueryClose = Cancel.Value
End Function

Private Sub mField_Enter()
    Append "Field.Enter"
End Sub

Private Sub mField_Exit(ByVal Cancel As ReturnBoolean)
    Append "Field.Exit"
End Sub

Private Sub mField_BeforeUpdate(ByVal Cancel As ReturnBoolean)
    Append "Field.BeforeUpdate"
    Cancel.Value = mBeforeUpdateVeto
End Sub

Private Sub mField_AfterUpdate()
    Append "Field.AfterUpdate"
End Sub

Private Sub mField_Change()
    Append "Field.Change=" & mField.Text
    mStatus.Caption = "field:" & mField.Text
    mForm.Render 96, 96
    Append "Field.Change.Render"
End Sub

Private Sub mTarget_Enter()
    Append "Target.Enter"
End Sub

Private Sub mReenter_Enter()
    Append "Reenter.Enter"
End Sub

Private Sub mReenter_Exit(ByVal Cancel As ReturnBoolean)
    Append "Reenter.Exit"
End Sub

Private Sub mReenter_Click()
    Append "Reenter.Click.Begin"
    Append "NestedKey=" & mReducer.DispatchKey("keydown", 9, 0)
    Append "NestedChar=" & mReducer.DispatchChar("r")
    mStatus.Caption = "nested:" & mField.Text
    mForm.Render 96, 96
    Append "Reenter.Click.Render"
    Append "Reenter.Click.End"
End Sub

Private Sub UserForm_Initialize()
    Append "UserForm.Initialize"
End Sub

Private Sub UserForm_Activate()
    Append "UserForm.Activate"
End Sub

Private Sub UserForm_Deactivate()
    Append "UserForm.Deactivate"
End Sub

Private Sub UserForm_Terminate()
    Append "UserForm.Terminate"
End Sub

Private Sub UserForm_QueryClose(ByVal Cancel As ReturnInteger, ByVal CloseMode As Integer)
    Append "UserForm.QueryClose:" & CStr(CloseMode)
    If mQueryCloseVeto Then Cancel.Value = 1
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
