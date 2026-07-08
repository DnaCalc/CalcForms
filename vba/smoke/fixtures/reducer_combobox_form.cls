Option Explicit

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mCombo As ComboBox
Private mLog As String

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "combo_fixture"
    mForm.Width = 220
    mForm.Height = 140

    Set mCombo = mForm.Controls.Add("Forms.ComboBox.1", "Choice")
    mCombo.Left = 20
    mCombo.Top = 20
    mCombo.Width = 120
    mCombo.Height = 22
    mCombo.Core.TabIndex = 0
    mCombo.AddItem "Red"
    mCombo.AddItem "Green"
    mCombo.AddItem "Blue"
    mCombo.Value = "Red"

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

Public Property Get FocusName() As String
    FocusName = mReducer.FocusName
End Property

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Public Property Get ComboDiagnostics() As String
    ComboDiagnostics = mCombo.Diagnostics
End Property

Public Property Get ComboValue() As String
    ComboValue = mCombo.Value
End Property

Public Property Get ComboListIndex() As Long
    ComboListIndex = mCombo.ListIndex
End Property

Public Property Get ComboDropDownOpen() As Boolean
    ComboDropDownOpen = mCombo.DropDownOpen
End Property

Public Property Get AccessibilitySnapshot() As String
    AccessibilitySnapshot = mReducer.AccessibilitySnapshot
End Property

Private Sub mCombo_DropButtonClick()
    Append "DropButtonClick"
End Sub

Private Sub mCombo_Change()
    Append "Change:" & mCombo.Value
End Sub

Private Sub mCombo_Click()
    Append "Click"
End Sub

Private Sub Append(ByVal Entry As String)
    If Len(mLog) > 0 Then mLog = mLog & "|"
    mLog = mLog & Entry
End Sub
