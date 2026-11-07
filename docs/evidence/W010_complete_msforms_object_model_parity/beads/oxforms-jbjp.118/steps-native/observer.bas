Option Explicit
Private Function Snapshot() As String
    Dim C As MSForms.ListBox
    Set C = InventoryForm.Controls("PickList")
    Snapshot = "height=" & CStr(C.Height) & ";integral=" & CStr(C.IntegralHeight) & ";top=" & CStr(C.TopIndex)
End Function
Public Function IntegralPrepare(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload InventoryForm
    Load InventoryForm
    InventoryForm.Zoom = Zoom
    InventoryForm.Show vbModeless
    InventoryForm.Controls("PickList").ListIndex = 22
    DoEvents
    IntegralPrepare = Snapshot()
    Exit Function
Failed:
    IntegralPrepare = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function IntegralStep(ByVal Member As String, ByVal Value As Long) As String
    On Error GoTo Failed
    Dim C As MSForms.ListBox, S As String
    Set C = InventoryForm.Controls("PickList")
    Select Case Member
        Case "integral": C.IntegralHeight = CBool(Value)
        Case "height": C.Height = CSng(Value)
        Case "none"
        Case Else: Err.Raise 5
    End Select
    S = Snapshot()
    DoEvents
    S = S & vbLf & Snapshot()
    C.TopIndex = 99
    IntegralStep = S & vbLf & Snapshot()
    Exit Function
Failed:
    IntegralStep = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
