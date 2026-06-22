Public Sub ShowW005InteractionOracleModal()
    ConfigureOracleControls
    OxFormsW005InteractionOracleForm.Tag = "show_mode=modal"
    OxFormsW005InteractionOracleForm.Show vbModal
End Sub

Public Sub ClearW005InteractionLog()
    On Error Resume Next
    ThisWorkbook.Worksheets("W005EventLog").Cells.Clear
    On Error GoTo 0
End Sub

Public Sub ExportW005InteractionLogCsv()
    Dim outputPath As String

    If Len(ThisWorkbook.Path) = 0 Then
        Err.Raise vbObjectError + 5000, "OxFormsW005InteractionOracle", "Save the generated workbook before exporting the event log."
    End If

    outputPath = ThisWorkbook.Path & Application.PathSeparator & "w005-interaction-event-log.csv"
    ThisWorkbook.Worksheets("W005EventLog").Copy
    ActiveWorkbook.SaveAs Filename:=outputPath, FileFormat:=6
    ActiveWorkbook.Close SaveChanges:=False
End Sub
