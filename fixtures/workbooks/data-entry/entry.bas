Option Explicit
Private mEntryFailure As String
Public Sub OpenOrderEntry()
    On Error GoTo Failed
    OrderEntryForm.Show vbModeless
    Exit Sub
Failed:
    mEntryFailure = "CALCFORMS_NATIVE_ERROR:Open:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Public Function OrderEntryState() As String
    On Error GoTo Failed
    If Len(mEntryFailure) > 0 Then
        OrderEntryState = mEntryFailure
    Else
        OrderEntryState = OrderEntryForm.State()
    End If
    Exit Function
Failed:
    OrderEntryState = "CALCFORMS_NATIVE_ERROR:State:" & CStr(Err.Number) & ":" & Err.Description
End Function

Public Function OrderEntryTrace() As String
    On Error GoTo Failed
    OrderEntryTrace = OrderEntryForm.Trace()
    Exit Function
Failed:
    OrderEntryTrace = "CALCFORMS_NATIVE_ERROR:Trace:" & CStr(Err.Number) & ":" & Err.Description
End Function

Public Function CurrentOrderEntry() As Object
    On Error GoTo Failed
    Set CurrentOrderEntry = OrderEntryForm
    Exit Function
Failed:
    Set CurrentOrderEntry = Nothing
End Function
