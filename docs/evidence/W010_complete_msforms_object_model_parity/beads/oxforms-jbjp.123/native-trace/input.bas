Option Explicit
Private Declare PtrSafe Function GetFocus Lib "user32" () As LongPtr
Private Declare PtrSafe Function PostMessageW Lib "user32" (ByVal Window As LongPtr, ByVal Message As Long, ByVal WParam As LongPtr, ByVal LParam As LongPtr) As Long
Public Function EscapeQueue(ByVal Character As Boolean) As String
    On Error GoTo Failed
    Dim Window As LongPtr
    Window = GetFocus()
    If Window = 0 Then Err.Raise 5, "EscapeQueue", "No control window on the owned Excel thread"
    If Character Then
        If PostMessageW(Window, &H102, 57, 1) = 0 Then Err.Raise 5
    Else
        If PostMessageW(Window, &H100, 27, &H10001) = 0 Then Err.Raise 5
        If PostMessageW(Window, &H101, 27, &HC0010001) = 0 Then Err.Raise 5
    End If
    EscapeQueue = "queued"
    Exit Function
Failed:
    EscapeQueue = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
