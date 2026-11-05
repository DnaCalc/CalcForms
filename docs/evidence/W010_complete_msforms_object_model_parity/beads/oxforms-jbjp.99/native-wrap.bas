Option Explicit
Public Function Run6WrapCase() As String
    On Error GoTo Failed
    With LayoutCommon.Clipped
        .Height = 30
        .Caption = "Long clipped label AgjpQy"
        .WordWrap = True
        Run6WrapCase = "caption=" & .Caption & ";wordwrap=" & CStr(.WordWrap) & ";width=" & CStr(.Width) & ";height=" & CStr(.Height) & ";font=" & .Font.Name & ";size=" & CStr(.Font.Size)
    End With
    LayoutCommon.Repaint
    Exit Function
Failed:
    Run6WrapCase = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
