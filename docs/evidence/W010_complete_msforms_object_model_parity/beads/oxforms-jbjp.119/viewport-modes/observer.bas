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

Public Function Run8ViewportMode(ByVal Mode As String) As String
    On Error GoTo Failed
    Dim C As MSForms.ListBox, S As String
    Set C = InventoryForm.Controls("PickList")
    S = "before_height=" & CStr(C.Height)
    Select Case Mode
        Case "height": C.Height = 72
        Case "height_small": C.Height = 71.25
        Case "width": C.Width = C.Width
        Case "integral_off": C.IntegralHeight = False
        Case "integral_on": C.IntegralHeight = True
        Case "flat": C.SpecialEffect = 0
        Case "font": C.Font.Size = 8.25
        Case "none"
        Case Else: Err.Raise 5
    End Select
    C.ListIndex = 22
    S = S & ";index_top=" & CStr(C.TopIndex)
    C.TopIndex = 99
    S = S & ";max_top=" & CStr(C.TopIndex) & ";height=" & CStr(C.Height) & ";font=" & CStr(C.Font.Size) & ";integral=" & CStr(C.IntegralHeight) & ";border=" & CStr(C.BorderStyle) & ";effect=" & CStr(C.SpecialEffect)
    Run8ViewportMode = S
    Exit Function
Failed:
    Run8ViewportMode = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
