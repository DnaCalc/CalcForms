Option Explicit

' W009 perf/budget fixture. Builds a form with a requested number of labels so
' the headless perf report can measure first paint, one-control incremental
' patching, and reducer hit-test cost at 10/50/100-control scale.

Private mForm As UserForm
Private mReducer As OxReducer
Private mFirst As Label
Private mCount As Long

Public Sub Build10()
    BuildCount 10
End Sub

Public Sub Build50()
    BuildCount 50
End Sub

Public Sub Build100()
    BuildCount 100
End Sub

Private Sub BuildCount(ByVal Count As Long)
    Set mForm = New UserForm
    mForm.Name = "perf_scale_" & CStr(Count)
    mForm.Width = 260
    mForm.Height = Count * 16 + 20
    mCount = Count

    Dim I As Long, Lbl As Label
    For I = 1 To Count
        Set Lbl = mForm.Controls.Add("Forms.Label.1", "L" & CStr(I))
        Lbl.Caption = "Item " & CStr(I)
        Lbl.Left = 8
        Lbl.Top = 8 + ((I - 1) * 16)
        Lbl.Width = 160
        Lbl.Height = 14
        If I = 1 Then Set mFirst = Lbl
    Next I

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

Public Function ChangeOne() As String
    mFirst.Caption = "Changed"
    ChangeOne = "changed"
End Function

Public Property Get ControlCount() As Long
    ControlCount = mCount
End Property

Public Property Get AccessibilitySnapshot() As String
    AccessibilitySnapshot = mReducer.AccessibilitySnapshot
End Property
