Option Explicit
Public Sub OrderObserverReset()
    On Error GoTo Failed
    Unload OrderEntryForm
    Exit Sub
Failed:
    Err.Raise Err.Number, "OrderObserverReset", Err.Description
End Sub
Public Function OrderObserverForm() As Object
    On Error GoTo Failed
    Set OrderObserverForm = OrderEntryForm
    Exit Function
Failed:
    Set OrderObserverForm = Nothing
End Function
