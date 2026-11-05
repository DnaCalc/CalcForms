Option Explicit
Public Function Run5SaveResults() As String
    On Error GoTo Failed
    Dim N As Integer, S As String
    S = Run5TextAssignments()
    N = FreeFile
    Open "C:\Work\DnaCalc\OxForms\docs\evidence\W010_complete_msforms_object_model_parity\beads\oxforms-jbjp.77\run5\native-text-assignments.txt" For Output As #N
    Print #N, S;
    Close #N
    S = Run5QueryClose()
    N = FreeFile
    Open "C:\Work\DnaCalc\OxForms\docs\evidence\W010_complete_msforms_object_model_parity\beads\oxforms-jbjp.77\run5\native-query-close.txt" For Output As #N
    Print #N, S;
    Close #N
    Run5SaveResults = S
    Exit Function
Failed:
    On Error Resume Next
    Close #N
    Run5SaveResults = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
