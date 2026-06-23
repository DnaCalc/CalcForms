Option Explicit

Private Const LOG_SHEET_NAME As String = "W006TransferEventLog"
Private Const TRANSFER_COORDINATE_SPACE As String = "msforms_event_args"
Private Const CLIPBOARD_SEED_ID As String = "repo_owned_text_seed_v1"
Private Const CLIPBOARD_SEED_TEXT As String = "OXFORMS_W006_CLIPBOARD_TEXT"

Private mSequence As Long

Private Sub UserForm_Initialize()
    mSequence = 0
    ResetLogSheet
    AppendLog "UserForm", "MSForms.UserForm", "Initialize", "no arguments"
End Sub

Private Sub UserForm_Activate()
    AppendLog "UserForm", "MSForms.UserForm", "Activate", "no arguments"
End Sub

Private Sub UserForm_QueryClose(Cancel As Integer, CloseMode As Integer)
    AppendLog "UserForm", "MSForms.UserForm", "QueryClose", _
        "Cancel As Integer; CloseMode As Integer", _
        cancelBefore:=Cancel, cancelAfter:=Cancel, _
        notes:="CloseMode=" & ScalarToText(CloseMode)
End Sub

Private Sub UserForm_Terminate()
    AppendLog "UserForm", "MSForms.UserForm", "Terminate", "no arguments"
End Sub

Private Sub OracleCloseButton_Click()
    AppendLog "OracleCloseButton", "MSForms.CommandButton", "Click", "no arguments"
    Unload Me
End Sub

Private Sub OracleTextBox_Change()
    AppendLog "OracleTextBox", "MSForms.TextBox", "Change", "no arguments"
End Sub

Private Sub OracleTextBox_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    Dim beforeValue As String
    beforeValue = ReturnHelperValueText(KeyCode)
    AppendLog "OracleTextBox", "MSForms.TextBox", "KeyDown", _
        "KeyCode As MSForms.ReturnInteger; Shift As Integer", _
        shiftValue:=Shift, keyCodeBefore:=beforeValue, _
        keyCodeAfter:=ReturnHelperValueText(KeyCode)
End Sub

Private Sub OracleTextBox_KeyPress(ByVal KeyAscii As MSForms.ReturnInteger)
    Dim beforeValue As String
    beforeValue = ReturnHelperValueText(KeyAscii)
    AppendLog "OracleTextBox", "MSForms.TextBox", "KeyPress", _
        "KeyAscii As MSForms.ReturnInteger", _
        keyAsciiBefore:=beforeValue, _
        keyAsciiAfter:=ReturnHelperValueText(KeyAscii)
End Sub

Private Sub OracleTextBox_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    Dim beforeValue As String
    beforeValue = ReturnHelperValueText(KeyCode)
    AppendLog "OracleTextBox", "MSForms.TextBox", "KeyUp", _
        "KeyCode As MSForms.ReturnInteger; Shift As Integer", _
        shiftValue:=Shift, keyCodeBefore:=beforeValue, _
        keyCodeAfter:=ReturnHelperValueText(KeyCode)
End Sub

Private Sub OracleTextBox_BeforeDragOver( _
    ByVal Cancel As MSForms.ReturnBoolean, _
    ByVal Data As MSForms.DataObject, _
    ByVal X As Single, _
    ByVal Y As Single, _
    ByVal DragState As MSForms.fmDragState, _
    ByVal Effect As MSForms.ReturnEffect, _
    ByVal Shift As Integer)
    Dim cancelBefore As String
    Dim effectBefore As String
    cancelBefore = ReturnHelperValueText(Cancel)
    effectBefore = ReturnHelperValueText(Effect)
    AppendLog "OracleTextBox", "MSForms.TextBox", "BeforeDragOver", _
        "Cancel As MSForms.ReturnBoolean; Data As MSForms.DataObject; X As Single; Y As Single; DragState As MSForms.fmDragState; Effect As MSForms.ReturnEffect; Shift As Integer", _
        TRANSFER_COORDINATE_SPACE, X, Y, _
        shiftValue:=Shift, _
        cancelBefore:=cancelBefore, cancelAfter:=ReturnHelperValueText(Cancel), _
        effectBefore:=effectBefore, effectAfter:=ReturnHelperValueText(Effect), _
        actionOrDragState:=DragState, _
        dataObjectObservation:=DataObjectObservationText(Data)
End Sub

Private Sub OracleTextBox_BeforeDropOrPaste( _
    ByVal Cancel As MSForms.ReturnBoolean, _
    ByVal Action As MSForms.fmAction, _
    ByVal Data As MSForms.DataObject, _
    ByVal X As Single, _
    ByVal Y As Single, _
    ByVal Effect As MSForms.ReturnEffect, _
    ByVal Shift As Integer)
    Dim cancelBefore As String
    Dim effectBefore As String
    cancelBefore = ReturnHelperValueText(Cancel)
    effectBefore = ReturnHelperValueText(Effect)
    AppendLog "OracleTextBox", "MSForms.TextBox", "BeforeDropOrPaste", _
        "Cancel As MSForms.ReturnBoolean; Action As MSForms.fmAction; Data As MSForms.DataObject; X As Single; Y As Single; Effect As MSForms.ReturnEffect; Shift As Integer", _
        TRANSFER_COORDINATE_SPACE, X, Y, _
        shiftValue:=Shift, _
        cancelBefore:=cancelBefore, cancelAfter:=ReturnHelperValueText(Cancel), _
        effectBefore:=effectBefore, effectAfter:=ReturnHelperValueText(Effect), _
        actionOrDragState:=Action, _
        dataObjectObservation:=DataObjectObservationText(Data)
End Sub

Private Sub AppendLog( _
    ByVal targetName As String, _
    ByVal targetKind As String, _
    ByVal eventName As String, _
    ByVal argumentSummary As String, _
    Optional ByVal coordinateSpace As String = "", _
    Optional ByVal xValue As Variant, _
    Optional ByVal yValue As Variant, _
    Optional ByVal shiftValue As Variant, _
    Optional ByVal keyCodeBefore As Variant, _
    Optional ByVal keyCodeAfter As Variant, _
    Optional ByVal keyAsciiBefore As Variant, _
    Optional ByVal keyAsciiAfter As Variant, _
    Optional ByVal cancelBefore As Variant, _
    Optional ByVal cancelAfter As Variant, _
    Optional ByVal effectBefore As Variant, _
    Optional ByVal effectAfter As Variant, _
    Optional ByVal actionOrDragState As Variant, _
    Optional ByVal dataObjectObservation As Variant, _
    Optional ByVal notes As String = "")
    Dim sheet As Worksheet
    Dim nextRow As Long

    Set sheet = GetOrCreateLogSheet()
    mSequence = mSequence + 1
    nextRow = sheet.Cells(sheet.Rows.Count, 1).End(xlUp).Row + 1

    sheet.Cells(nextRow, 1).Value = mSequence
    sheet.Cells(nextRow, 2).Value = ShowModeText()
    sheet.Cells(nextRow, 3).Value = targetName
    sheet.Cells(nextRow, 4).Value = targetKind
    sheet.Cells(nextRow, 5).Value = eventName
    sheet.Cells(nextRow, 6).Value = argumentSummary
    sheet.Cells(nextRow, 7).Value = coordinateSpace
    sheet.Cells(nextRow, 8).Value = OptionalText(xValue)
    sheet.Cells(nextRow, 9).Value = OptionalText(yValue)
    sheet.Cells(nextRow, 10).Value = OptionalText(shiftValue)
    sheet.Cells(nextRow, 11).Value = OptionalText(keyCodeBefore)
    sheet.Cells(nextRow, 12).Value = OptionalText(keyCodeAfter)
    sheet.Cells(nextRow, 13).Value = OptionalText(keyAsciiBefore)
    sheet.Cells(nextRow, 14).Value = OptionalText(keyAsciiAfter)
    sheet.Cells(nextRow, 15).Value = OptionalText(cancelBefore)
    sheet.Cells(nextRow, 16).Value = OptionalText(cancelAfter)
    sheet.Cells(nextRow, 17).Value = OptionalText(effectBefore)
    sheet.Cells(nextRow, 18).Value = OptionalText(effectAfter)
    sheet.Cells(nextRow, 19).Value = OptionalText(actionOrDragState)
    sheet.Cells(nextRow, 20).Value = OptionalText(dataObjectObservation)
    sheet.Cells(nextRow, 21).Value = SafeControlPropertyText("OracleTextBox", "Text")
    sheet.Cells(nextRow, 22).Value = SafeControlPropertyText("OracleTextBox", "Value")
    sheet.Cells(nextRow, 23).Value = CLIPBOARD_SEED_ID
    sheet.Cells(nextRow, 24).Value = notes
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
    sheet.Cells(1, 2).Value = "show_mode"
    sheet.Cells(1, 3).Value = "target_name"
    sheet.Cells(1, 4).Value = "target_kind"
    sheet.Cells(1, 5).Value = "event_name"
    sheet.Cells(1, 6).Value = "argument_summary"
    sheet.Cells(1, 7).Value = "coordinate_space"
    sheet.Cells(1, 8).Value = "x"
    sheet.Cells(1, 9).Value = "y"
    sheet.Cells(1, 10).Value = "shift"
    sheet.Cells(1, 11).Value = "key_code_before"
    sheet.Cells(1, 12).Value = "key_code_after"
    sheet.Cells(1, 13).Value = "key_ascii_before"
    sheet.Cells(1, 14).Value = "key_ascii_after"
    sheet.Cells(1, 15).Value = "cancel_before"
    sheet.Cells(1, 16).Value = "cancel_after"
    sheet.Cells(1, 17).Value = "effect_before"
    sheet.Cells(1, 18).Value = "effect_after"
    sheet.Cells(1, 19).Value = "action_or_drag_state"
    sheet.Cells(1, 20).Value = "data_object_observation"
    sheet.Cells(1, 21).Value = "textbox_text"
    sheet.Cells(1, 22).Value = "textbox_value"
    sheet.Cells(1, 23).Value = "clipboard_seed_id"
    sheet.Cells(1, 24).Value = "notes"
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

Private Function DataObjectObservationText(ByVal data As MSForms.DataObject) As String
    On Error GoTo Failed

    If data Is Nothing Then
        DataObjectObservationText = "data_object=nothing"
        Exit Function
    End If

    Dim hasText As String
    Dim textSummary As String
    hasText = PublicDataObjectFormatText(data, 1)
    textSummary = PublicDataObjectTextSummary(data)

    DataObjectObservationText = "data_object=present; public_getformat_1=" & hasText & "; " & textSummary
    Exit Function
Failed:
    DataObjectObservationText = "data_object_observation_error=" & Err.Number & ":" & Err.Description
End Function

Private Function PublicDataObjectFormatText(ByVal data As MSForms.DataObject, ByVal formatId As Integer) As String
    On Error GoTo Failed
    PublicDataObjectFormatText = CStr(data.GetFormat(formatId))
    Exit Function
Failed:
    PublicDataObjectFormatText = "error:" & Err.Number & ":" & Err.Description
End Function

Private Function PublicDataObjectTextSummary(ByVal data As MSForms.DataObject) As String
    On Error GoTo Failed
    Dim payload As String
    payload = data.GetText(1)
    If payload = CLIPBOARD_SEED_TEXT Then
        PublicDataObjectTextSummary = "text_payload=repo_seed:" & CLIPBOARD_SEED_ID
    Else
        PublicDataObjectTextSummary = "text_payload_unrecorded_length=" & Len(payload)
    End If
    Exit Function
Failed:
    PublicDataObjectTextSummary = "text_payload_error=" & Err.Number & ":" & Err.Description
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
