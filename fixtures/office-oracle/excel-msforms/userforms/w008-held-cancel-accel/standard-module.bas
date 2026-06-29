Option Explicit

' Worksheet logger + show/clear + scenario macros for the W008 held cancel/accelerator oracle
' (oxforms-uvh). Each W008HeldCancelAccelLog row records the event sequence, the active
' scenario, the control, the event name, the count-relevant argument name, its value before and
' after the handler (this fixture does not mutate keys, so before == after), the post-handler
' focus owner (so a focus transfer to the activated button is observable), and TextBox1.Text.
' The capture sets gScenario via one Set... macro per scenario, so a single workbook covers both
' held_escape_cancel and held_alt_accelerator through the shared worksheet. One row per OS
' auto-repeat answers uvh (does the activation Click multiply with hold time?).

Public gScenario As String

Private gW008HcaSeq As Long

Public Sub W008HcaLog( _
        ByVal controlName As String, _
        ByVal eventName As String, _
        ByVal argName As String, _
        ByVal argBefore As String, _
        ByVal argAfter As String, _
        ByVal focusOwnerAfter As String, _
        ByVal valueAfter As String)
    Dim ws As Worksheet
    Set ws = W008HcaSheet()
    gW008HcaSeq = gW008HcaSeq + 1
    Dim r As Long
    r = gW008HcaSeq + 1
    ws.Cells(r, 1).Value = gW008HcaSeq
    ws.Cells(r, 2).Value = gScenario
    ws.Cells(r, 3).Value = controlName
    ws.Cells(r, 4).Value = eventName
    ws.Cells(r, 5).Value = argName
    ws.Cells(r, 6).Value = argBefore
    ws.Cells(r, 7).Value = argAfter
    ws.Cells(r, 8).Value = focusOwnerAfter
    ws.Cells(r, 9).Value = valueAfter
    ws.Cells(r, 10).Value = ""
End Sub

Private Function W008HcaSheet() As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W008HeldCancelAccelLog")
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add
        ws.Name = "W008HeldCancelAccelLog"
    End If
    If Len(CStr(ws.Cells(1, 1).Value)) = 0 Then
        ws.Cells(1, 1).Value = "sequence"
        ws.Cells(1, 2).Value = "scenario"
        ws.Cells(1, 3).Value = "control_name"
        ws.Cells(1, 4).Value = "event_name"
        ws.Cells(1, 5).Value = "arg_name"
        ws.Cells(1, 6).Value = "arg_before"
        ws.Cells(1, 7).Value = "arg_after"
        ws.Cells(1, 8).Value = "focus_owner_after"
        ws.Cells(1, 9).Value = "value_after"
        ws.Cells(1, 10).Value = "notes"
    End If
    Set W008HcaSheet = ws
End Function

Public Sub ClearW008HeldCancelAccelLog()
    gW008HcaSeq = 0
    gScenario = ""
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W008HeldCancelAccelLog")
    On Error GoTo 0
    If Not ws Is Nothing Then
        ws.Cells.Clear
    End If
End Sub

Public Sub ShowW008HeldCancelAccelModeless()
    OxFormsW008HeldCancelAccel.Show vbModeless
End Sub

Public Sub FocusControlW008HeldCancelAccel(ByVal name As String)
    OxFormsW008HeldCancelAccel.Controls(name).SetFocus
End Sub

' ---- scenario flag control ----

Public Sub SetW008ScenarioHeldEscapeCancel()
    gScenario = "held_escape_cancel"
End Sub

Public Sub SetW008ScenarioHeldAltAccelerator()
    gScenario = "held_alt_accelerator"
End Sub
