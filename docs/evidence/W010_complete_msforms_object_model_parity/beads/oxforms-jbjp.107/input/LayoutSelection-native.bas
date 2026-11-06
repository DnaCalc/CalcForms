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

Private Sub Unchecked_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Unchecked.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Checked_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Checked.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub OptionOne_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "OptionOne.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub OptionTwo_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "OptionTwo.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub ToggleOff_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "ToggleOff.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub ToggleOn_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "ToggleOn.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Choices_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Choices.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Dropdown_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Dropdown.MouseDown|"
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
