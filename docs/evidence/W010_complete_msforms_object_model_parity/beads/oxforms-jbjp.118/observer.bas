Option Explicit
Public Function Run8IntegralGeometry(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload InventoryForm
    Load InventoryForm
    InventoryForm.Zoom = Zoom
    Dim C As MSForms.ListBox, S As String
    Set C = InventoryForm.Controls("PickList")
    S = "before:height=" & CStr(C.Height) & ";font=" & C.Font.Name & ";size=" & CStr(C.Font.Size) & ";integral=" & CStr(C.IntegralHeight)
    InventoryForm.Show vbModeless
    S = S & vbLf & "after:height=" & CStr(C.Height) & ";font=" & C.Font.Name & ";size=" & CStr(C.Font.Size) & ";integral=" & CStr(C.IntegralHeight)
    InventoryForm.Hide
    Run8IntegralGeometry = S
    Exit Function
Failed:
    Run8IntegralGeometry = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
