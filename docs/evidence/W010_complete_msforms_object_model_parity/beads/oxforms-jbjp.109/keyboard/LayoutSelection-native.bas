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
    If Prepare Then
        For I = 1 To 20
            Choices.AddItem "Row " & CStr(I)
        Next
    End If
    S = ParityListSnapshot(Choices)
    ParityScroll = S
    Exit Function
Failed:
    ParityScroll = "CALCFORMS_NATIVE_ERROR:scroll:" & CStr(Err.Number) & ":" & Err.Description
End Function
