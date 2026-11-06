Option Explicit
Public Sub OpenInventory()
    On Error GoTo Failed
    InventoryForm.Show vbModeless
    Exit Sub
Failed:
    Err.Raise Err.Number, "OpenInventory", Err.Description
End Sub
Public Function InventoryState() As String
    On Error GoTo Failed
    InventoryState = InventoryForm.State()
    Exit Function
Failed:
    InventoryState = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function InventoryTrace() As String
    On Error GoTo Failed
    InventoryTrace = InventoryForm.Trace()
    Exit Function
Failed:
    InventoryTrace = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
