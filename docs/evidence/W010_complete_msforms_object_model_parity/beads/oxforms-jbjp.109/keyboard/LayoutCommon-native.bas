Private Sub Greet_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Greet.Click|"
    Exit Sub
Failed:
    mParityFailure = "command-click:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Disabled_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Disabled.Click|"
    Exit Sub
Failed:
    mParityFailure = "command-click:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Function ParityListSnapshot(ByVal C As Object) As String
    On Error GoTo Failed
    Dim S As String, Stage As String
    S = "index=" & CStr(C.ListIndex) & ";count=" & CStr(C.ListCount)
    Stage = "top"
    ParityListSnapshot = S & ";top=" & CStr(C.TopIndex)
    Exit Function
Failed:
    If Stage = "top" Then
        ParityListSnapshot = S & ";top_error=" & CStr(Err.Number)
    Else
        ParityListSnapshot = "CALCFORMS_NATIVE_ERROR:list-state:" & CStr(Err.Number) & ":" & Err.Description
    End If
End Function

Public Function ParityScroll(ByVal Prepare As Boolean) As String
    On Error GoTo Failed
    Dim I As Long, S As String
    ParityScroll = S
    Exit Function
Failed:
    ParityScroll = "CALCFORMS_NATIVE_ERROR:scroll:" & CStr(Err.Number) & ":" & Err.Description
End Function
