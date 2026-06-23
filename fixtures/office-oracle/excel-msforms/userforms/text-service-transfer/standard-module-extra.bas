Public Sub ClearW006TransferLog()
    On Error Resume Next
    ThisWorkbook.Worksheets("W006TransferEventLog").Cells.Clear
    On Error GoTo 0
End Sub

Public Sub FocusW006TransferTextBox()
    OxFormsW006TransferForm.OracleTextBox.SetFocus
End Sub

Public Sub SelectAllW006TransferTextBox()
    With OxFormsW006TransferForm.OracleTextBox
        .SelStart = 0
        .SelLength = Len(.Text)
    End With
End Sub

Public Sub PasteW006TransferTextBoxViaPublicMethod()
    OxFormsW006TransferForm.OracleTextBox.Paste
End Sub

Public Function W006TransferTextBoxText() As String
    W006TransferTextBoxText = OxFormsW006TransferForm.OracleTextBox.Text
End Function
