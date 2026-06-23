Option Explicit

' W005 smoke-only event sink.
' The generic carrier is test infrastructure; the original event names and
' argument metadata are preserved in the payload.

Private WithEvents EventSource As W005ProbeEventSource
Private mLog As String

Public Sub Attach(ByVal Source As W005ProbeEventSource)
    Set EventSource = Source
End Sub

Public Property Get LogText() As String
    LogText = mLog
End Property

Private Sub EventSource_Dispatched(ByVal Ordinal As Long, ByVal Target As String, ByVal EventName As String, ByVal Args As String)
    If Len(mLog) > 0 Then
        mLog = mLog & vbLf
    End If

    mLog = mLog & CStr(Ordinal) & "|" & Target & "|" & EventName & "|" & Args
End Sub
