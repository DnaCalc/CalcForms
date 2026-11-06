Option Explicit
Public Function Run8ShowFocus() As String
    On Error GoTo Failed
    Dim C As Object, S As String
    Load OrderEntryForm
    OrderEntryForm.Show vbModeless
    S = "initial=" & OrderEntryForm.ActiveControl.Name
    For Each C In OrderEntryForm.Controls
        S = S & vbLf & C.Name & "=" & CStr(C.TabIndex)
    Next C
    OrderEntryForm.Controls("TeamChoice").SetFocus
    OrderEntryForm.Hide
    OrderEntryForm.Show vbModeless
    S = S & vbLf & "reshow=" & OrderEntryForm.ActiveControl.Name
    OrderEntryForm.Hide
    Run8ShowFocus = S
    Exit Function
Failed:
    Run8ShowFocus = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
