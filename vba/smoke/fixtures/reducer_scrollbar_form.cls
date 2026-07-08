Option Explicit

' W009 ScrollBar fixture: proves local range/value, page/thumb behavior, and
' Scroll-vs-Change distinction through the normal OxReducer route.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mScroll As ScrollBar
Private WithEvents mField As TextBox
Private mLog As String

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "scrollbarform"
    mForm.Width = 240
    mForm.Height = 120

    Set mScroll = mForm.Controls.Add("Forms.ScrollBar.1", "Amount")
    mScroll.Left = 20
    mScroll.Top = 20
    mScroll.Width = 160
    mScroll.Height = 18
    mScroll.Min = 0
    mScroll.Max = 100
    mScroll.SmallChange = 5
    mScroll.LargeChange = 20
    mScroll.Value = 40
    mScroll.Core.TabIndex = 0

    Set mField = mForm.Controls.Add("Forms.TextBox.1", "Field")
    mField.Left = 20
    mField.Top = 60
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

Public Property Get ScrollValue() As Long
    ScrollValue = mScroll.Value
End Property

Public Property Get ScrollDiagnostics() As String
    ScrollDiagnostics = mScroll.Diagnostics
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

Public Sub DisableScroll()
    mScroll.Enabled = False
End Sub

Public Sub HideScroll()
    mScroll.Visible = False
End Sub

Private Sub mScroll_Enter()
    Append "Scroll.Enter"
End Sub
Private Sub mScroll_Exit(ByVal Cancel As ReturnBoolean)
    Append "Scroll.Exit"
End Sub
Private Sub mScroll_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Scroll.MouseDown"
End Sub
Private Sub mScroll_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Scroll.MouseUp"
End Sub
Private Sub mScroll_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "Scroll.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mScroll_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "Scroll.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mScroll_Scroll()
    Append "Scroll.Scroll=" & CStr(mScroll.Value)
End Sub
Private Sub mScroll_Change()
    Append "Scroll.Change=" & CStr(mScroll.Value)
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
