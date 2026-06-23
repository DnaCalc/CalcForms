Option Explicit

' W005 smoke-only event source.
' The Rust adapter invokes these methods; each method raises a normal VBA event
' so OxVba's WithEvents/RaiseEvent machinery dispatches the handler.

Public Event Dispatched(ByVal Ordinal As Long, ByVal Target As String, ByVal EventName As String, ByVal Args As String)

Public Sub RaiseDispatch(ByVal Ordinal As Long, ByVal Target As String, ByVal EventName As String, ByVal Args As String)
    RaiseEvent Dispatched(Ordinal, Target, EventName, Args)
End Sub
