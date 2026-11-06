Option Explicit

' W009 TabStrip fixture: proves Tabs collection state, selected index, Change event,
' keyboard/pointer routing, and accessibility through the normal OxReducer route.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mTabs As TabStrip
Private WithEvents mField As TextBox
Private mLog As String

Private Sub Class_Initialize()
    Set mForm = Nothing
    Set mReducer = Nothing
    Set mTabs = Nothing
    Set mField = Nothing
End Sub

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "tabstripform"
    mForm.Width = 260
    mForm.Height = 130

    Set mTabs = mForm.Controls.Add("Forms.TabStrip.1", "Pages")
    mTabs.Left = 20
    mTabs.Top = 20
    mTabs.Width = 180
    mTabs.Height = 70
    mTabs.Tabs.Add "Alpha"
    mTabs.Tabs.Add "Beta"
    mTabs.Tabs.Add "Gamma"
    mTabs.Value = 0
    mTabs.Core.TabIndex = 0

    Set mField = mForm.Controls.Add("Forms.TextBox.1", "Field")
    mField.Left = 20
    mField.Top = 96
    mField.Width = 80
    mField.Height = 20
    mField.Core.TabIndex = 1

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

Public Property Get TabValue() As Long
    TabValue = mTabs.Value
End Property

Public Property Get TabCaption() As String
    TabCaption = mTabs.SelectedCaption
End Property

Public Property Get TabCount() As Long
    TabCount = mTabs.Tabs.Count
End Property

Public Property Get FirstCaption() As String
    FirstCaption = mTabs.Tabs.Item(0).Caption
End Property

Public Property Get SecondSelected() As Boolean
    SecondSelected = mTabs.Tabs.Item(1).Selected
End Property

Public Property Get TabDiagnostics() As String
    TabDiagnostics = mTabs.Diagnostics
End Property

Public Property Get AccessibilitySnapshot() As String
    AccessibilitySnapshot = mReducer.AccessibilitySnapshot
End Property

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Public Sub ClearLog()
    mLog = ""
End Sub

Public Sub DisableTabs()
    mTabs.Enabled = False
End Sub

Public Sub HideTabs()
    mTabs.Visible = False
End Sub

Private Sub mTabs_Enter()
    Append "TabStrip.Enter"
End Sub
Private Sub mTabs_Exit(ByVal Cancel As ReturnBoolean)
    Append "TabStrip.Exit"
End Sub
Private Sub mTabs_MouseDown(ByVal Index As Long, ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "TabStrip.MouseDown:" & CStr(CLng(X)) & "," & CStr(CLng(Y))
End Sub
Private Sub mTabs_MouseUp(ByVal Index As Long, ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "TabStrip.MouseUp"
End Sub
Private Sub mTabs_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "TabStrip.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mTabs_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "TabStrip.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mTabs_Change()
    Append "TabStrip.Change=" & CStr(mTabs.Value) & ":" & mTabs.SelectedCaption
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
