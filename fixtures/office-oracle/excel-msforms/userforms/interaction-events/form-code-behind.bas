Option Explicit

Private Const LOG_SHEET_NAME As String = "W005EventLog"
Private Const MOUSE_COORDINATE_SPACE As String = "msforms_event_args"

Private mSequence As Long

Private Sub UserForm_Initialize()
    mSequence = 0
    ResetLogSheet
    On Error Resume Next
    CallByName Me, "KeyPreview", VbLet, True
    On Error GoTo 0
    AppendLog "UserForm", "MSForms.UserForm", "Initialize", "no arguments", notes:="KeyPreview requested; live output decides actual key routing."
End Sub

Private Sub UserForm_Activate()
    AppendLog "UserForm", "MSForms.UserForm", "Activate", "no arguments"
End Sub

Private Sub UserForm_Deactivate()
    AppendLog "UserForm", "MSForms.UserForm", "Deactivate", "no arguments"
End Sub

Private Sub UserForm_Resize()
    AppendLog "UserForm", "MSForms.UserForm", "Resize", "no arguments", notes:="Form Width=" & ScalarToText(Me.Width) & "; Height=" & ScalarToText(Me.Height)
End Sub

Private Sub UserForm_QueryClose(Cancel As Integer, CloseMode As Integer)
    Dim cancelBefore As Integer
    cancelBefore = Cancel
    AppendLog "UserForm", "MSForms.UserForm", "QueryClose", "Cancel As Integer; CloseMode As Integer", cancelBefore:=cancelBefore, cancelAfter:=Cancel, closeMode:=CloseMode
End Sub

Private Sub UserForm_Terminate()
    AppendLog "UserForm", "MSForms.UserForm", "Terminate", "no arguments"
End Sub

Private Sub UserForm_Click()
    AppendLog "UserForm", "MSForms.UserForm", "Click", "no arguments"
End Sub

Private Sub UserForm_DblClick(ByVal Cancel As MSForms.ReturnBoolean)
    Dim beforeValue As String
    beforeValue = ReturnHelperValueText(Cancel)
    AppendLog "UserForm", "MSForms.UserForm", "DblClick", "Cancel As MSForms.ReturnBoolean", cancelBefore:=beforeValue, cancelAfter:=ReturnHelperValueText(Cancel)
End Sub

Private Sub UserForm_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "UserForm", "MSForms.UserForm", "MouseDown", Button, Shift, X, Y
End Sub

Private Sub UserForm_MouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "UserForm", "MSForms.UserForm", "MouseMove", Button, Shift, X, Y
End Sub

Private Sub UserForm_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "UserForm", "MSForms.UserForm", "MouseUp", Button, Shift, X, Y
End Sub

Private Sub UserForm_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    AppendKeyLog "UserForm", "MSForms.UserForm", "KeyDown", KeyCode, Shift
End Sub

Private Sub UserForm_KeyPress(ByVal KeyAscii As MSForms.ReturnInteger)
    AppendKeyPressLog "UserForm", "MSForms.UserForm", "KeyPress", KeyAscii
End Sub

Private Sub UserForm_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    AppendKeyLog "UserForm", "MSForms.UserForm", "KeyUp", KeyCode, Shift
End Sub

Private Sub OracleProbeLabel_Click()
    AppendLog "OracleProbeLabel", "MSForms.Label", "Click", "no arguments"
End Sub

Private Sub OracleProbeLabel_DblClick(ByVal Cancel As MSForms.ReturnBoolean)
    Dim beforeValue As String
    beforeValue = ReturnHelperValueText(Cancel)
    AppendLog "OracleProbeLabel", "MSForms.Label", "DblClick", "Cancel As MSForms.ReturnBoolean", cancelBefore:=beforeValue, cancelAfter:=ReturnHelperValueText(Cancel)
End Sub

Private Sub OracleProbeLabel_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "OracleProbeLabel", "MSForms.Label", "MouseDown", Button, Shift, X, Y
End Sub

Private Sub OracleProbeLabel_MouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "OracleProbeLabel", "MSForms.Label", "MouseMove", Button, Shift, X, Y
End Sub

Private Sub OracleProbeLabel_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "OracleProbeLabel", "MSForms.Label", "MouseUp", Button, Shift, X, Y
End Sub

Private Sub OracleDefaultButton_Click()
    AppendLog "OracleDefaultButton", "MSForms.CommandButton", "Click", "no arguments", notes:="Default=True; Accelerator=O in fixture manifest."
End Sub

Private Sub OracleDefaultButton_DblClick(ByVal Cancel As MSForms.ReturnBoolean)
    Dim beforeValue As String
    beforeValue = ReturnHelperValueText(Cancel)
    AppendLog "OracleDefaultButton", "MSForms.CommandButton", "DblClick", "Cancel As MSForms.ReturnBoolean", cancelBefore:=beforeValue, cancelAfter:=ReturnHelperValueText(Cancel)
End Sub

Private Sub OracleDefaultButton_Enter()
    AppendLog "OracleDefaultButton", "MSForms.CommandButton", "Enter", "no arguments"
End Sub

Private Sub OracleDefaultButton_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    Dim beforeValue As String
    beforeValue = ReturnHelperValueText(Cancel)
    AppendLog "OracleDefaultButton", "MSForms.CommandButton", "Exit", "Cancel As MSForms.ReturnBoolean", cancelBefore:=beforeValue, cancelAfter:=ReturnHelperValueText(Cancel)
End Sub

Private Sub OracleDefaultButton_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    AppendKeyLog "OracleDefaultButton", "MSForms.CommandButton", "KeyDown", KeyCode, Shift
End Sub

Private Sub OracleDefaultButton_KeyPress(ByVal KeyAscii As MSForms.ReturnInteger)
    AppendKeyPressLog "OracleDefaultButton", "MSForms.CommandButton", "KeyPress", KeyAscii
End Sub

Private Sub OracleDefaultButton_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    AppendKeyLog "OracleDefaultButton", "MSForms.CommandButton", "KeyUp", KeyCode, Shift
End Sub

Private Sub OracleDefaultButton_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "OracleDefaultButton", "MSForms.CommandButton", "MouseDown", Button, Shift, X, Y
End Sub

Private Sub OracleDefaultButton_MouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "OracleDefaultButton", "MSForms.CommandButton", "MouseMove", Button, Shift, X, Y
End Sub

Private Sub OracleDefaultButton_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "OracleDefaultButton", "MSForms.CommandButton", "MouseUp", Button, Shift, X, Y
End Sub

Private Sub OracleCancelButton_Click()
    AppendLog "OracleCancelButton", "MSForms.CommandButton", "Click", "no arguments", notes:="Cancel=True; Accelerator=C in fixture manifest."
End Sub

Private Sub OracleCancelButton_DblClick(ByVal Cancel As MSForms.ReturnBoolean)
    Dim beforeValue As String
    beforeValue = ReturnHelperValueText(Cancel)
    AppendLog "OracleCancelButton", "MSForms.CommandButton", "DblClick", "Cancel As MSForms.ReturnBoolean", cancelBefore:=beforeValue, cancelAfter:=ReturnHelperValueText(Cancel)
End Sub

Private Sub OracleCancelButton_Enter()
    AppendLog "OracleCancelButton", "MSForms.CommandButton", "Enter", "no arguments"
End Sub

Private Sub OracleCancelButton_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    Dim beforeValue As String
    beforeValue = ReturnHelperValueText(Cancel)
    AppendLog "OracleCancelButton", "MSForms.CommandButton", "Exit", "Cancel As MSForms.ReturnBoolean", cancelBefore:=beforeValue, cancelAfter:=ReturnHelperValueText(Cancel)
End Sub

Private Sub OracleCancelButton_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    AppendKeyLog "OracleCancelButton", "MSForms.CommandButton", "KeyDown", KeyCode, Shift
End Sub

Private Sub OracleCancelButton_KeyPress(ByVal KeyAscii As MSForms.ReturnInteger)
    AppendKeyPressLog "OracleCancelButton", "MSForms.CommandButton", "KeyPress", KeyAscii
End Sub

Private Sub OracleCancelButton_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    AppendKeyLog "OracleCancelButton", "MSForms.CommandButton", "KeyUp", KeyCode, Shift
End Sub

Private Sub OracleCancelButton_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "OracleCancelButton", "MSForms.CommandButton", "MouseDown", Button, Shift, X, Y
End Sub

Private Sub OracleCancelButton_MouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "OracleCancelButton", "MSForms.CommandButton", "MouseMove", Button, Shift, X, Y
End Sub

Private Sub OracleCancelButton_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "OracleCancelButton", "MSForms.CommandButton", "MouseUp", Button, Shift, X, Y
End Sub

Private Sub OracleTextBox_Change()
    AppendLog "OracleTextBox", "MSForms.TextBox", "Change", "no arguments"
End Sub

Private Sub OracleTextBox_BeforeUpdate(ByVal Cancel As MSForms.ReturnBoolean)
    Dim beforeValue As String
    beforeValue = ReturnHelperValueText(Cancel)
    AppendLog "OracleTextBox", "MSForms.TextBox", "BeforeUpdate", "Cancel As MSForms.ReturnBoolean", cancelBefore:=beforeValue, cancelAfter:=ReturnHelperValueText(Cancel)
End Sub

Private Sub OracleTextBox_AfterUpdate()
    AppendLog "OracleTextBox", "MSForms.TextBox", "AfterUpdate", "no arguments"
End Sub

Private Sub OracleTextBox_DblClick(ByVal Cancel As MSForms.ReturnBoolean)
    Dim beforeValue As String
    beforeValue = ReturnHelperValueText(Cancel)
    AppendLog "OracleTextBox", "MSForms.TextBox", "DblClick", "Cancel As MSForms.ReturnBoolean", cancelBefore:=beforeValue, cancelAfter:=ReturnHelperValueText(Cancel)
End Sub

Private Sub OracleTextBox_Enter()
    AppendLog "OracleTextBox", "MSForms.TextBox", "Enter", "no arguments"
End Sub

Private Sub OracleTextBox_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    Dim beforeValue As String
    beforeValue = ReturnHelperValueText(Cancel)
    AppendLog "OracleTextBox", "MSForms.TextBox", "Exit", "Cancel As MSForms.ReturnBoolean", cancelBefore:=beforeValue, cancelAfter:=ReturnHelperValueText(Cancel)
End Sub

Private Sub OracleTextBox_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    AppendKeyLog "OracleTextBox", "MSForms.TextBox", "KeyDown", KeyCode, Shift
End Sub

Private Sub OracleTextBox_KeyPress(ByVal KeyAscii As MSForms.ReturnInteger)
    AppendKeyPressLog "OracleTextBox", "MSForms.TextBox", "KeyPress", KeyAscii
End Sub

Private Sub OracleTextBox_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    AppendKeyLog "OracleTextBox", "MSForms.TextBox", "KeyUp", KeyCode, Shift
End Sub

Private Sub OracleTextBox_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "OracleTextBox", "MSForms.TextBox", "MouseDown", Button, Shift, X, Y
End Sub

Private Sub OracleTextBox_MouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "OracleTextBox", "MSForms.TextBox", "MouseMove", Button, Shift, X, Y
End Sub

Private Sub OracleTextBox_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendMouseLog "OracleTextBox", "MSForms.TextBox", "MouseUp", Button, Shift, X, Y
End Sub

Private Sub AppendMouseLog(ByVal targetName As String, ByVal targetKind As String, ByVal eventName As String, ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    AppendLog targetName, targetKind, eventName, "Button As Integer; Shift As Integer; X As Single; Y As Single", MOUSE_COORDINATE_SPACE, X, Y, Button, Shift
End Sub

Private Sub AppendKeyLog(ByVal targetName As String, ByVal targetKind As String, ByVal eventName As String, ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    AppendLog targetName, targetKind, eventName, "KeyCode As MSForms.ReturnInteger; Shift As Integer", shiftValue:=Shift, keyCodeValue:=ReturnHelperValueText(KeyCode)
End Sub

Private Sub AppendKeyPressLog(ByVal targetName As String, ByVal targetKind As String, ByVal eventName As String, ByVal KeyAscii As MSForms.ReturnInteger)
    AppendLog targetName, targetKind, eventName, "KeyAscii As MSForms.ReturnInteger", keyAsciiValue:=ReturnHelperValueText(KeyAscii)
End Sub

Private Sub AppendLog(ByVal targetName As String, ByVal targetKind As String, ByVal eventName As String, ByVal argumentSummary As String, Optional ByVal coordinateSpace As String = "", Optional ByVal xValue As Variant, Optional ByVal yValue As Variant, Optional ByVal buttonValue As Variant, Optional ByVal shiftValue As Variant, Optional ByVal keyCodeValue As Variant, Optional ByVal keyAsciiValue As Variant, Optional ByVal cancelBefore As Variant, Optional ByVal cancelAfter As Variant, Optional ByVal closeMode As Variant, Optional ByVal notes As String = "")
    Dim sheet As Worksheet
    Dim nextRow As Long

    Set sheet = GetOrCreateLogSheet()
    mSequence = mSequence + 1
    nextRow = sheet.Cells(sheet.Rows.Count, 1).End(xlUp).Row + 1

    sheet.Cells(nextRow, 1).Value = mSequence
    sheet.Cells(nextRow, 2).Value = mSequence
    sheet.Cells(nextRow, 3).Value = 0
    sheet.Cells(nextRow, 4).Value = ShowModeText()
    sheet.Cells(nextRow, 5).Value = targetName
    sheet.Cells(nextRow, 6).Value = targetKind
    sheet.Cells(nextRow, 7).Value = eventName
    sheet.Cells(nextRow, 8).Value = argumentSummary
    sheet.Cells(nextRow, 9).Value = coordinateSpace
    sheet.Cells(nextRow, 10).Value = OptionalText(xValue)
    sheet.Cells(nextRow, 11).Value = OptionalText(yValue)
    sheet.Cells(nextRow, 12).Value = OptionalText(buttonValue)
    sheet.Cells(nextRow, 13).Value = OptionalText(shiftValue)
    sheet.Cells(nextRow, 14).Value = OptionalText(keyCodeValue)
    sheet.Cells(nextRow, 15).Value = OptionalText(keyAsciiValue)
    sheet.Cells(nextRow, 16).Value = OptionalText(cancelBefore)
    sheet.Cells(nextRow, 17).Value = OptionalText(cancelAfter)
    sheet.Cells(nextRow, 18).Value = OptionalText(closeMode)
    sheet.Cells(nextRow, 19).Value = ActiveControlName()
    sheet.Cells(nextRow, 20).Value = ActiveWindowCaption()
    sheet.Cells(nextRow, 21).Value = SafeControlPropertyText("OracleProbeLabel", "Caption")
    sheet.Cells(nextRow, 22).Value = SafeControlPropertyText("OracleTextBox", "Text")
    sheet.Cells(nextRow, 23).Value = SafeControlPropertyText("OracleTextBox", "Value")
    sheet.Cells(nextRow, 24).Value = SafeControlPropertyText("OracleDefaultButton", "Enabled")
    sheet.Cells(nextRow, 25).Value = SafeControlPropertyText("OracleCancelButton", "Enabled")
    sheet.Cells(nextRow, 26).Value = notes
End Sub

Private Sub ResetLogSheet()
    Dim sheet As Worksheet
    Set sheet = GetOrCreateLogSheet()
    sheet.Cells.Clear
    WriteLogHeaders sheet
End Sub

Private Function GetOrCreateLogSheet() As Worksheet
    On Error Resume Next
    Set GetOrCreateLogSheet = ThisWorkbook.Worksheets(LOG_SHEET_NAME)
    On Error GoTo 0

    If GetOrCreateLogSheet Is Nothing Then
        Set GetOrCreateLogSheet = ThisWorkbook.Worksheets.Add
        GetOrCreateLogSheet.Name = LOG_SHEET_NAME
    End If

    If CStr(GetOrCreateLogSheet.Cells(1, 1).Value) <> "sequence" Then
        WriteLogHeaders GetOrCreateLogSheet
    End If
End Function

Private Sub WriteLogHeaders(ByVal sheet As Worksheet)
    sheet.Cells(1, 1).Value = "sequence"
    sheet.Cells(1, 2).Value = "logical_tick"
    sheet.Cells(1, 3).Value = "nesting_depth"
    sheet.Cells(1, 4).Value = "show_mode"
    sheet.Cells(1, 5).Value = "target_name"
    sheet.Cells(1, 6).Value = "target_kind"
    sheet.Cells(1, 7).Value = "event_name"
    sheet.Cells(1, 8).Value = "argument_summary"
    sheet.Cells(1, 9).Value = "coordinate_space"
    sheet.Cells(1, 10).Value = "x"
    sheet.Cells(1, 11).Value = "y"
    sheet.Cells(1, 12).Value = "button"
    sheet.Cells(1, 13).Value = "shift"
    sheet.Cells(1, 14).Value = "key_code"
    sheet.Cells(1, 15).Value = "key_ascii"
    sheet.Cells(1, 16).Value = "cancel_before"
    sheet.Cells(1, 17).Value = "cancel_after"
    sheet.Cells(1, 18).Value = "close_mode"
    sheet.Cells(1, 19).Value = "active_control"
    sheet.Cells(1, 20).Value = "active_window_caption"
    sheet.Cells(1, 21).Value = "label_caption"
    sheet.Cells(1, 22).Value = "textbox_text"
    sheet.Cells(1, 23).Value = "textbox_value"
    sheet.Cells(1, 24).Value = "default_button_enabled"
    sheet.Cells(1, 25).Value = "cancel_button_enabled"
    sheet.Cells(1, 26).Value = "notes"
End Sub

Private Function ShowModeText() As String
    On Error GoTo Failed
    If Len(CStr(Me.Tag)) = 0 Then
        ShowModeText = "unknown"
    Else
        ShowModeText = CStr(Me.Tag)
    End If
    Exit Function
Failed:
    ShowModeText = "unknown"
End Function

Private Function ActiveControlName() As String
    On Error GoTo Failed
    ActiveControlName = Me.ActiveControl.Name
    Exit Function
Failed:
    ActiveControlName = "<none>"
End Function

Private Function ActiveWindowCaption() As String
    On Error GoTo Failed
    ActiveWindowCaption = Application.ActiveWindow.Caption
    Exit Function
Failed:
    ActiveWindowCaption = "<unavailable>"
End Function

Private Function SafeControlPropertyText(ByVal controlName As String, ByVal propertyName As String) As String
    On Error GoTo Failed
    SafeControlPropertyText = CStr(CallByName(Me.Controls(controlName), propertyName, VbGet))
    Exit Function
Failed:
    SafeControlPropertyText = "<unavailable>"
End Function

Private Function ReturnHelperValueText(ByVal helper As Object) As String
    On Error GoTo Failed
    ReturnHelperValueText = CStr(helper.Value)
    Exit Function
Failed:
    ReturnHelperValueText = "<unavailable>"
End Function

Private Function OptionalText(Optional ByVal value As Variant) As String
    If IsMissing(value) Then
        OptionalText = ""
    Else
        OptionalText = ScalarToText(value)
    End If
End Function

Private Function ScalarToText(ByVal value As Variant) As String
    On Error GoTo Failed
    If IsObject(value) Then
        ScalarToText = ReturnHelperValueText(value)
    ElseIf IsEmpty(value) Or IsNull(value) Then
        ScalarToText = ""
    Else
        ScalarToText = CStr(value)
    End If
    Exit Function
Failed:
    ScalarToText = "<unavailable>"
End Function
