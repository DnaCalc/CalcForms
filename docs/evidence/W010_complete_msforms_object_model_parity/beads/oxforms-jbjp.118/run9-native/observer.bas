Option Explicit
Private Function IntegralRow(ByVal C As MSForms.ListBox, ByVal StepName As String) As String
    C.ListIndex = 22
    C.TopIndex = 99
    IntegralRow = StepName & ";height=" & CStr(C.Height) & ";integral=" & CStr(C.IntegralHeight) & ";top=" & CStr(C.TopIndex) & vbLf
End Function
Public Function IntegralRun(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload InventoryForm
    Load InventoryForm
    InventoryForm.Zoom = Zoom
    InventoryForm.Width = 450 * Zoom / 100
    InventoryForm.Height = 270 * Zoom / 100
    Dim C As MSForms.ListBox, S As String
    Set C = InventoryForm.Controls("PickList")
    S = "before-show;height=" & CStr(C.Height) & ";integral=" & CStr(C.IntegralHeight) & vbLf
    InventoryForm.Show vbModeless
    S = S & IntegralRow(C, "shown")
    C.IntegralHeight = True
    S = S & IntegralRow(C, "same-true")
    C.IntegralHeight = False
    S = S & IntegralRow(C, "false")
    C.IntegralHeight = False
    S = S & IntegralRow(C, "same-false")
    C.IntegralHeight = True
    S = S & IntegralRow(C, "true")
    C.IntegralHeight = True
    S = S & IntegralRow(C, "same-true-after-toggle")
    C.IntegralHeight = False
    C.Height = 80
    S = S & IntegralRow(C, "false-height-80")
    C.IntegralHeight = True
    S = S & IntegralRow(C, "true-height-80")
    C.Height = 72
    S = S & IntegralRow(C, "true-height-72")
    DoEvents
    S = S & IntegralRow(C, "after-doevents")
    InventoryForm.Hide
    InventoryForm.Show vbModeless
    S = S & IntegralRow(C, "reshow")
    InventoryForm.Hide
    IntegralRun = S
    Exit Function
Failed:
    IntegralRun = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description & vbLf & S
End Function
