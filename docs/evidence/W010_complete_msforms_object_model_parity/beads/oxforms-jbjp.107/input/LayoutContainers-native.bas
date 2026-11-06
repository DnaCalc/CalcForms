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

Private Sub Group_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Group.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub NestedLabel_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Group.NestedLabel.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub NestedInput_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Group.NestedInput.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Picture_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Picture.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub TabsControl_MouseDown(ByVal Index As Long, ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "TabsControl.MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub PagesControl_MouseDown(ByVal Index As Long, ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "PagesControl.MouseDown|"
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
