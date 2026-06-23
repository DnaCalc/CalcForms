Option Explicit

' W007 native FM20 class-event gate fixture (oxforms-4pn.2).
' Ordinary VBA WithEvents sink: handler procedures follow the native
' Source_Event shape with no generic carrier. Proves OxVba routes native
' FM20-named events to attached WithEvents handlers.

Private WithEvents EventSource As W006NativeFm20EventSource
Private mLog As String

Public Sub Attach(ByVal Source As W006NativeFm20EventSource)
    Set EventSource = Source
End Sub

Public Property Get LogText() As String
    LogText = mLog
End Property

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then
        mLog = mLog & vbLf
    End If

    mLog = mLog & Line
End Sub

Private Sub EventSource_Click()
    Append "Click|no arguments"
End Sub

Private Sub EventSource_Change()
    Append "Change|no arguments"
End Sub

Private Sub EventSource_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "MouseDown|Button=" & Button & ";Shift=" & Shift & ";X=" & X & ";Y=" & Y
End Sub

Private Sub EventSource_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "MouseUp|Button=" & Button & ";Shift=" & Shift & ";X=" & X & ";Y=" & Y
End Sub

Private Sub EventSource_MouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "MouseMove|Button=" & Button & ";Shift=" & Shift & ";X=" & X & ";Y=" & Y
End Sub
