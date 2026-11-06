Option Explicit
Public EscapeMode As String
Public EscapeLog As String

Public Function EscapePrepare(ByVal Mode As String, ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload InventoryForm
    EscapeMode = Mode
    Load InventoryForm
    InventoryForm.QtyInput.Text = ""
    InventoryForm.Zoom = Zoom
    InventoryForm.Width = 450 * Zoom / 100
    InventoryForm.Height = 270 * Zoom / 100
    InventoryForm.Show vbModeless
    If Mode = "submit_clean" Then
        InventoryForm.SubmitButton.SetFocus
    Else
        InventoryForm.QtyInput.SetFocus
    End If
    EscapeLog = ""
    EscapePrepare = EscapeObserve()
    Exit Function
Failed:
    EscapePrepare = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function EscapeObserve() As String
    On Error GoTo Failed
    EscapeObserve = "focus=" & InventoryForm.ActiveControl.Name & ";visible=" & CStr(InventoryForm.Visible) & ";text=" & InventoryForm.QtyInput.Text & ";log=" & EscapeLog
    Exit Function
Failed:
    EscapeObserve = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
