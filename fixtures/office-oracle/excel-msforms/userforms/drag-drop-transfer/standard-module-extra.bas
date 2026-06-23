Public Sub ClearW006OleDragDropLog()
    On Error Resume Next
    ThisWorkbook.Worksheets("W006OleDragDropEventLog").Cells.Clear
    On Error GoTo 0
End Sub

Public Function W006OleDragDropTargetText() As String
    W006OleDragDropTargetText = OxFormsW006OleDragDropForm.TargetDropTextBox.Text
End Function
