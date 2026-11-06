Private mParityEvents As String
Private mParityFailure As String
Public Function ParityInputTrace(ByVal Reset As Boolean) As String
    On Error GoTo Failed
    If Reset Then
        mParityEvents = ""
        mParityFailure = ""
    End If
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    ParityInputTrace = mParityEvents
    Exit Function
Failed:
    ParityInputTrace = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function

Private Sub Greet_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Greet.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub InputName_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "InputName.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Loud_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Loud.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Output_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Output.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Prompt_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Prompt.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub UserForm_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "(form).MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "form-mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub
