Option Explicit
Public Sub ShowGreeter()
    WorkbookGreeter.Show vbModeless
End Sub
Public Sub HideGreeter()
    WorkbookGreeter.Hide
End Sub
Public Sub ResetGreeter()
    Unload WorkbookGreeter
    WorkbookGreeter.Show vbModeless
End Sub
Public Function GreeterState() As String
    GreeterState = WorkbookGreeter.State()
End Function
