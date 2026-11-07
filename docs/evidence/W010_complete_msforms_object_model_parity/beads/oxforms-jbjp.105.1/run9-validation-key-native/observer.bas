Option Explicit
Private Declare PtrSafe Function GetFocus Lib "user32" () As LongPtr
Private Declare PtrSafe Function PostMessageW Lib "user32" (ByVal Window As LongPtr, ByVal Message As Long, ByVal WParam As LongPtr, ByVal LParam As LongPtr) As Long
Private Declare PtrSafe Function MapVirtualKeyW Lib "user32" (ByVal Code As Long, ByVal MapType As Long) As Long
Public Function OrderPrepare(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload OrderEntryForm
    Load OrderEntryForm
    OrderEntryForm.Zoom = Zoom
    OpenOrderEntry
    OrderPrepare = OrderEntryForm.State()
    Exit Function
Failed:
    OrderPrepare = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function OrderQueue(ByVal Code As Long, ByVal Character As Boolean) As String
    On Error GoTo Failed
    Dim Window As LongPtr
    Window = GetFocus()
    If Window = 0 Then Err.Raise 5, "OrderQueue", "No focused window in owned Excel"
    If Character Then
        If PostMessageW(Window, &H102, Code, 1) = 0 Then Err.Raise 5
    Else
        Dim Flags As Long
        Flags = 1 Or (MapVirtualKeyW(Code, 0) * 65536)
        If PostMessageW(Window, &H100, Code, Flags) = 0 Then Err.Raise 5
        If PostMessageW(Window, &H101, Code, Flags Or &HC0000000) = 0 Then Err.Raise 5
    End If
    OrderQueue = "queued"
    Exit Function
Failed:
    OrderQueue = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function OrderFocus() As String
    On Error GoTo Failed
    OrderFocus = OrderEntryForm.ActiveControl.Name
    Exit Function
Failed:
    OrderFocus = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Sub OrderReload(ByVal Zoom As Long)
    On Error GoTo Failed
    Unload OrderEntryForm
    Load OrderEntryForm
    OrderEntryForm.Zoom = Zoom
    OpenOrderEntry
    Exit Sub
Failed:
    Err.Raise Err.Number, "OrderReload", Err.Description
End Sub
