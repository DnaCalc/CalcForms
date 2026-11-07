
Private Function InlineCaseValue() As Long
    Select Case 2
        Case 1: InlineCaseValue = 11
        Case 2: InlineCaseValue = 22
        Case Else: InlineCaseValue = 99
    End Select
End Function
Private Function MultilineCaseValue() As Long
    Select Case 2
        Case 1
            MultilineCaseValue = 11
        Case 2
            MultilineCaseValue = 22
        Case Else
            MultilineCaseValue = 99
    End Select
End Function
Private Function ChainValue() As String
    On Error GoTo Failed
    Dim C As IOxControl
    Set C = CalcFormsHostForm.Controls.Item("Choices")
    ChainValue = CStr(C.Core.MeasureTextCount)
    Exit Function
Failed:
    ChainValue = "error:" & CStr(Err.Number) & ":" & Err.Description
End Function
Private Function TypedValue() As String
    On Error GoTo Failed
    Dim C As IOxControl, Core As OxControlCore
    Set C = CalcFormsHostForm.Controls.Item("Choices")
    Set Core = C.Core
    TypedValue = CStr(Core.MeasureTextCount)
    Exit Function
Failed:
    TypedValue = "error:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function Run9EngineRepro() As String
    Run9EngineRepro = "inline=" & CStr(InlineCaseValue()) & ";multiline=" & CStr(MultilineCaseValue()) & ";chained=" & ChainValue() & ";typed=" & TypedValue()
End Function
