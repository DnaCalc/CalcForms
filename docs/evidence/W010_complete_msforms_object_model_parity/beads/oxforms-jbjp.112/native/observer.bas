Option Explicit
Private Function ViewportState(ByVal ErrorCode As Long) As String
    Dim C As MSForms.ListBox
    Set C = LayoutSelection.Controls("Choices")
    ViewportState = "error=" & CStr(ErrorCode) & ";index=" & CStr(C.ListIndex) & ";top=" & CStr(C.TopIndex) & ";count=" & CStr(C.ListCount) & ";height=" & CStr(C.Height)
End Function
Public Function Run8ViewportPrepare(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Load LayoutSelection
    LayoutSelection.Zoom = Zoom
    Dim C As MSForms.ListBox, I As Long
    Set C = LayoutSelection.Controls("Choices")
    C.Clear
    C.Height = 72
    For I = 0 To 22
        C.AddItem "Row " & CStr(I)
    Next
    C.ListIndex = 1
    C.TopIndex = 0
    LayoutSelection.Show vbModeless
    Run8ViewportPrepare = ViewportState(0)
    Exit Function
Failed:
    Run8ViewportPrepare = "CALCFORMS_NATIVE_ERROR:prepare:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function Run8ViewportSet(ByVal Member As String, ByVal Value As Long) As String
    On Error GoTo Failed
    Dim C As MSForms.ListBox, Code As Long
    Set C = LayoutSelection.Controls("Choices")
    Select Case Member
        Case "top": C.TopIndex = Value
        Case "index": C.ListIndex = Value
        Case "height": C.Height = Value
        Case "clear": C.Clear
        Case Else: Err.Raise 5
    End Select
    Run8ViewportSet = ViewportState(0)
    Exit Function
Failed:
    Code = Err.Number
    Err.Clear
    On Error GoTo Fatal
    Run8ViewportSet = ViewportState(Code)
    Exit Function
Fatal:
    Run8ViewportSet = "CALCFORMS_NATIVE_ERROR:snapshot:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Sub Run8ViewportFinish()
    On Error GoTo Failed
    LayoutSelection.Hide
    Exit Sub
Failed:
    Err.Raise Err.Number, "Run8ViewportFinish", Err.Description
End Sub
