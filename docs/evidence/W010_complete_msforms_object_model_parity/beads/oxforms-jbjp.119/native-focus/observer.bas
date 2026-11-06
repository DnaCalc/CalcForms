Option Explicit
Public Function Run8InventoryPrepare(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload InventoryForm
    Load InventoryForm
    InventoryForm.Zoom = Zoom
    InventoryForm.Width = 450 * Zoom / 100
    InventoryForm.Height = 270 * Zoom / 100
    InventoryForm.Show vbModeless
    Run8InventoryPrepare = InventoryForm.ActiveControl.Name
    Exit Function
Failed:
    Run8InventoryPrepare = "CALCFORMS_NATIVE_ERROR:prepare:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function Run8InventorySet(ByVal Member As String, ByVal Value As String) As String
    On Error GoTo Failed
    Select Case Member
        Case "quantity"
            InventoryForm.Controls("QtyInput").Text = Value
        Case "index"
            InventoryForm.Controls("PickList").ListIndex = CLng(Value)
        Case "focus"
            InventoryForm.Controls("PickList").SetFocus
        Case "show"
            InventoryForm.Show vbModeless
        Case Else
            Err.Raise 5, "InventoryProbe", "Unknown action"
    End Select
    Run8InventorySet = InventoryForm.State()
    Exit Function
Failed:
    Run8InventorySet = "CALCFORMS_NATIVE_ERROR:set:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Sub Run8InventoryFinish()
    On Error GoTo Failed
    Unload InventoryForm
    Exit Sub
Failed:
    Err.Raise Err.Number, "InventoryProbeFinish", Err.Description
End Sub

Public Function Run8InventoryFocus() As String
    On Error GoTo Failed
    Run8InventoryFocus = InventoryForm.ActiveControl.Name
    Exit Function
Failed:
    Run8InventoryFocus = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function Run8FocusViewport() As String
    On Error GoTo Failed
    Dim C As MSForms.ListBox, S As String
    Set C = InventoryForm.Controls("PickList")
    InventoryForm.Controls("QtyInput").SetFocus
    C.ListIndex = 22
    S = "unfocused_index=" & CStr(C.TopIndex)
    C.TopIndex = 99
    S = S & ";unfocused_top=" & CStr(C.TopIndex)
    C.ListIndex = 0
    C.TopIndex = 0
    C.SetFocus
    C.ListIndex = 22
    S = S & ";focused_index=" & CStr(C.TopIndex)
    C.TopIndex = 99
    S = S & ";focused_top=" & CStr(C.TopIndex)
    Run8FocusViewport = S
    Exit Function
Failed:
    Run8FocusViewport = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
