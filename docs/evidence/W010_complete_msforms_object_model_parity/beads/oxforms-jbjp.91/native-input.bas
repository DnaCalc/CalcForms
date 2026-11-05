Option Explicit
Private mInputClicks As Long
Private mInputError As String
Private Sub UserForm_Initialize()
    InputName.Text = "Alpha Beta Gamma Delta"
    Greet.Accelerator = "G"
End Sub
Private Sub Greet_Click()
    On Error GoTo Failed
    mInputClicks = mInputClicks + 1
    Exit Sub
Failed:
    mInputError = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Sub
Public Function InputState() As String
    On Error GoTo Failed
    If Len(mInputError) > 0 Then
        InputState = mInputError
        Exit Function
    End If
    InputState = "text=" & InputName.Text & ";start=" & CStr(InputName.SelStart) & ";length=" & CStr(InputName.SelLength) & ";selected=" & InputName.SelText & ";clicks=" & CStr(mInputClicks) & ";focus=" & Me.ActiveControl.Name
    Exit Function
Failed:
    InputState = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
