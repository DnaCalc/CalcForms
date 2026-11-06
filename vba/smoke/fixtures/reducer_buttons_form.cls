Option Explicit

' Reducer-pivot increment 5 proof fixture (oxforms-ih6.5; test infrastructure). A TextBox plus a
' default button (OK), a cancel button (Cancel), an accelerator button ("&Go"), and a CheckBox,
' driven through OxReducer. WithEvents sinks record the events so the tests can assert: Enter on a
' field activates the default button (focus moves + Click), Escape activates the cancel button in
' place, Alt+letter activates the matching button, and Space toggles the focused CheckBox
' (value-first: Change/Click before KeyDown). No Rust reducer in the loop.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mField As TextBox
Private WithEvents mOk As CommandButton
Private WithEvents mCancelBtn As CommandButton
Private WithEvents mGo As CommandButton
Private WithEvents mChk As CheckBox
Private mLog As String

Private Sub Class_Initialize()
    Set mForm = Nothing
    Set mReducer = Nothing
    Set mField = Nothing
    Set mOk = Nothing
    Set mCancelBtn = Nothing
    Set mGo = Nothing
    Set mChk = Nothing
End Sub

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "btnform"
    mForm.Width = 180
    mForm.Height = 130

    Set mField = mForm.Controls.Add("Forms.TextBox.1", "Field")
    mField.Left = 20
    mField.Top = 20
    mField.Width = 100
    mField.Height = 18

    Set mOk = mForm.Controls.Add("Forms.CommandButton.1", "Ok")
    mOk.Caption = "OK"
    mOk.Default = True
    mOk.Left = 20
    mOk.Top = 45
    mOk.Width = 60
    mOk.Height = 20

    Set mCancelBtn = mForm.Controls.Add("Forms.CommandButton.1", "CancelBtn")
    mCancelBtn.Caption = "Cancel"
    mCancelBtn.Cancel = True
    mCancelBtn.Left = 90
    mCancelBtn.Top = 45
    mCancelBtn.Width = 60
    mCancelBtn.Height = 20

    Set mGo = mForm.Controls.Add("Forms.CommandButton.1", "Go")
    mGo.Caption = "Go"
    mGo.Accelerator = "G"
    mGo.Left = 20
    mGo.Top = 70
    mGo.Width = 60
    mGo.Height = 20

    Set mChk = mForm.Controls.Add("Forms.CheckBox.1", "Chk")
    mChk.Caption = "Opt"
    mChk.Left = 20
    mChk.Top = 95
    mChk.Width = 100
    mChk.Height = 18

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

Public Property Get InteractionStateSummary() As String
    InteractionStateSummary = mReducer.InteractionStateSummary
End Property

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Public Sub ClearLog()
    mLog = ""
End Sub

Public Property Get ChkValue() As Boolean
    ChkValue = mChk.Value
End Property

Public Property Get ControlCount() As Long
    ControlCount = mForm.Controls.Count
End Property

Public Property Get InteractionIndexBuildCount() As Long
    InteractionIndexBuildCount = mReducer.InteractionIndexBuildCount
End Property

Public Property Get InteractionIndexSummary() As String
    InteractionIndexSummary = mReducer.InteractionIndexSummary
End Property

Public Property Get CapabilityCatalog() As String
    CapabilityCatalog = _
        "Field:" & mField.Core.CapabilityDescriptor & vbLf & _
        "Ok:" & mOk.Core.CapabilityDescriptor & vbLf & _
        "CancelBtn:" & mCancelBtn.Core.CapabilityDescriptor & vbLf & _
        "Go:" & mGo.Core.CapabilityDescriptor & vbLf & _
        "Chk:" & mChk.Core.CapabilityDescriptor
End Property

Public Sub DisableDefaultButton()
    mOk.Enabled = False
End Sub

Public Sub HideCheckBox()
    mChk.Visible = False
End Sub

Public Sub HideFocusedField()
    mField.Visible = False
End Sub

Public Sub DisableFocusedField()
    mField.Enabled = False
End Sub

Public Sub DisableFieldTabStop()
    mField.Core.TabStop = False
End Sub

Public Sub AddLateTextBox()
    Dim LateBox As TextBox
    Set LateBox = mForm.Controls.Add("Forms.TextBox.1", "Late")
    LateBox.Left = 130
    LateBox.Top = 20
    LateBox.Width = 40
    LateBox.Height = 18
    LateBox.Core.TabIndex = 99
End Sub

Public Sub RemoveLateTextBox()
    mForm.Controls.Remove "Late"
End Sub

Public Sub RemoveFocusedField()
    mForm.Controls.Remove "Field"
    Set mField = Nothing
End Sub

Public Property Get HasField() As Boolean
    HasField = mForm.HasControl("Field")
End Property

Public Property Get HasLate() As Boolean
    HasLate = mForm.HasControl("Late")
End Property

Public Sub RenameFieldToRenamed()
    mField.Core.Name = "RenamedField"
End Sub

Public Property Get RenamedFieldLookupName() As String
    Dim Control As IOxControl
    Set Control = mForm.ControlByName("RenamedField")
    RenamedFieldLookupName = Control.Core.Name
End Property

Public Property Get RenamedFieldItemName() As String
    Dim Control As IOxControl
    Set Control = mForm.Controls.Item("RenamedField")
    RenamedFieldItemName = Control.Core.Name
End Property

Public Sub Render()
    mForm.Render 96, 96
End Sub

' --- Event sinks ---
Private Sub mField_Enter()
    Append "Field.Enter"
End Sub
Private Sub mField_Exit(ByVal Cancel As ReturnBoolean)
    Append "Field.Exit"
End Sub
Private Sub mField_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "Field.KeyDown"
End Sub

Private Sub mOk_Enter()
    Append "Ok.Enter"
End Sub
Private Sub mOk_Click()
    Append "Ok.Click"
End Sub

Private Sub mCancelBtn_Click()
    Append "Cancel.Click"
End Sub

Private Sub mGo_Enter()
    Append "Go.Enter"
End Sub
Private Sub mGo_Click()
    Append "Go.Click"
End Sub

Private Sub mChk_Change()
    Append "Chk.Change"
End Sub
Private Sub mChk_Click()
    Append "Chk.Click"
End Sub
Private Sub mChk_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "Chk.KeyDown"
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
