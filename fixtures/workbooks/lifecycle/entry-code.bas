Option Explicit
Private mNext As Long
Private mLog As String
Public Function NextGeneration() As Long
    mNext = mNext + 1
    NextGeneration = mNext
End Function
Public Sub AppendTrace(ByVal Text As String)
    If Len(mLog) > 0 Then mLog = mLog & "|"
    mLog = mLog & Text
End Sub
Public Function Trace() As String
    Trace = mLog
End Function
Public Sub ShowLifecycle()
    LifecycleProbe.Show vbModeless
End Sub
Public Sub HideLifecycle()
    LifecycleProbe.Hide
End Sub
Public Sub UnloadLifecycle()
    Unload LifecycleProbe
End Sub
Public Function DefaultState() As String
    DefaultState = LifecycleProbe.State()
End Function
