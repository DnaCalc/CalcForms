Option Explicit

Private Const RESULT_SHEET As String = "W010ProbeResults"
Private Const EVENT_SHEET As String = "W010EventLog"
Private mSequence As Long
Private mCurrentStep As String
Private mHarnessError As String
Private mRecordingEnabled As Boolean

Public Sub RunMemberOracle()
    Dim failureNumber As Long
    Dim failureDescription As String
    Dim failureSource As String
    On Error GoTo HarnessFailed
    ResetOracleSheets
    mCurrentStep = "ShowForm"
    W010MemberOracleForm.Show vbModeless
    DoEvents
    mCurrentStep = "LabelCaptionRoundtrip"
    Probe_LabelCaptionRoundtrip
    mCurrentStep = "TextMaxLengthCoercion"
    Probe_TextMaxLengthCoercion
    mCurrentStep = "ListAddItemDefaultIndex"
    Probe_ListAddItemDefaultIndex
    mCurrentStep = "ListCountAfterDefaultAdd"
    Probe_ListCountAfterDefaultAdd
    mCurrentStep = "ListAddItemExplicitIndex"
    Probe_ListAddItemExplicitIndex
    mCurrentStep = "ListFirstItemRead"
    Probe_ListFirstItemRead
    mCurrentStep = "FocusTextForExit"
    On Error Resume Next
    Err.Clear
    W010MemberOracleForm.ProbeTextBox.SetFocus
    failureNumber = Err.number
    failureDescription = Err.Description
    failureSource = Err.Source
    Err.Clear
    On Error GoTo HarnessFailed
    If failureNumber <> 0 Then
        Err.Raise vbObjectError + 2048, "OxForms.MemberOracle", "Focus step FocusTextForExit observed an unexpected outcome" & vbTab & CStr(failureNumber) & vbTab & failureDescription & vbTab & failureSource
    End If
    DoEvents
    mCurrentStep = "TextValueForEvents"
    Probe_TextValueForEvents
    mCurrentStep = "DrainTextChange"
    DoEvents
    mCurrentStep = "TextDefaultValueRead"
    Probe_TextDefaultValueRead
    mCurrentStep = "AttemptExitTransfer"
    On Error Resume Next
    Err.Clear
    W010MemberOracleForm.ProbeCommandButton.SetFocus
    failureNumber = Err.number
    failureDescription = Err.Description
    failureSource = Err.Source
    Err.Clear
    On Error GoTo HarnessFailed
    If failureNumber <> &H80004005 Or failureDescription <> "Unspecified error." Or failureSource <> "Forms.Form.1" Then
        Err.Raise vbObjectError + 2048, "OxForms.MemberOracle", "Focus step AttemptExitTransfer observed an unexpected outcome" & vbTab & CStr(failureNumber) & vbTab & failureDescription & vbTab & failureSource
    End If
    DoEvents
    mCurrentStep = "DrainExitEvent"
    DoEvents
    mCurrentStep = "CheckValueCoercion"
    Probe_CheckValueCoercion
    mCurrentStep = "TextMaxLengthInvalid"
    Probe_TextMaxLengthInvalid
    mCurrentStep = "ButtonCaptionRead"
    Probe_ButtonCaptionRead
    Exit Sub
HarnessFailed:
    failureNumber = Err.number
    failureDescription = Err.Description
    failureSource = Err.Source
    mHarnessError = CStr(failureNumber) & vbTab & failureDescription & vbTab & failureSource & vbTab & mCurrentStep
    mRecordingEnabled = False
    On Error Resume Next
    UnloadMemberOracleIfLoaded
    On Error GoTo 0
End Sub

Private Sub UnloadMemberOracleIfLoaded()
    Dim loadedForm As Object
    For Each loadedForm In UserForms
        If StrComp(TypeName(loadedForm), "W010MemberOracleForm", vbBinaryCompare) = 0 Then
            Unload loadedForm
            Exit For
        End If
    Next loadedForm
End Sub

Public Sub CloseMemberOracle()
    mRecordingEnabled = False
    UnloadMemberOracleIfLoaded
    DoEvents
End Sub

Public Function GetMemberOracleHarnessError() As String
    GetMemberOracleHarnessError = mHarnessError
End Function

Public Function OracleRecordingEnabled() As Boolean
    OracleRecordingEnabled = mRecordingEnabled
End Function

Private Sub ResetOracleSheets()
    Dim resultSheet As Worksheet
    Dim eventSheet As Worksheet
    mSequence = 0
    mHarnessError = ""
    mRecordingEnabled = True
    Set resultSheet = GetOrCreateOracleSheet(RESULT_SHEET)
    Set eventSheet = GetOrCreateOracleSheet(EVENT_SHEET)
    resultSheet.Cells.Clear
    eventSheet.Cells.Clear
    WriteOracleHeaders resultSheet, Array("sequence", "probe_id", "ledger_row_id", "target_id", "operation", "member", "outcome", "value_text", "type_name", "var_type", "is_object", "is_array", "error_number", "error_last_dll_error", "error_hex", "error_description", "error_description_utf16_hex", "error_source", "error_help_file", "error_help_context", "error_line", "error_stage")
    WriteOracleHeaders eventSheet, Array("sequence", "event_id", "ledger_row_id", "target_id", "target_kind", "event_name", "arguments_before", "arguments_after", "trigger_step_id")
End Sub

Private Function GetOrCreateOracleSheet(ByVal sheetName As String) As Worksheet
    On Error Resume Next
    Set GetOrCreateOracleSheet = ThisWorkbook.Worksheets(sheetName)
    On Error GoTo 0
    If GetOrCreateOracleSheet Is Nothing Then
        Set GetOrCreateOracleSheet = ThisWorkbook.Worksheets.Add
        GetOrCreateOracleSheet.Name = sheetName
    End If
End Function

Private Sub WriteOracleHeaders(ByVal sheet As Worksheet, ByVal headers As Variant)
    Dim index As Long
    For index = LBound(headers) To UBound(headers)
        sheet.Cells(1, index + 1).value = CStr(headers(index))
    Next index
End Sub

Private Sub AppendOracleProbe(ByVal probeId As String, ByVal ledgerRowId As String, ByVal targetId As String, ByVal operation As String, ByVal memberName As String, ByVal resultValue As Variant, ByVal errorNumber As Long, ByVal errorLastDllError As Long, ByVal errorHex As String, ByVal errorDescription As String, ByVal errorDescriptionUtf16Hex As String, ByVal errorSource As String, ByVal errorHelpFile As String, ByVal errorHelpContext As Long, ByVal errorLine As Long, ByVal errorStage As String)
    Dim sheet As Worksheet
    Dim rowNumber As Long
    Set sheet = GetOrCreateOracleSheet(RESULT_SHEET)
    mSequence = mSequence + 1
    rowNumber = sheet.Cells(sheet.Rows.Count, 1).End(xlUp).Row + 1
    sheet.Cells(rowNumber, 1).value = mSequence
    sheet.Cells(rowNumber, 2).value = probeId
    sheet.Cells(rowNumber, 3).value = ledgerRowId
    sheet.Cells(rowNumber, 4).value = targetId
    sheet.Cells(rowNumber, 5).value = operation
    sheet.Cells(rowNumber, 6).value = memberName
    If errorNumber = 0 Then
        sheet.Cells(rowNumber, 7).value = "success"
        sheet.Cells(rowNumber, 8).value = OracleValueText(resultValue)
        sheet.Cells(rowNumber, 9).value = TypeName(resultValue)
        sheet.Cells(rowNumber, 10).value = CStr(VarType(resultValue))
        sheet.Cells(rowNumber, 11).value = CStr(IsObject(resultValue))
        sheet.Cells(rowNumber, 12).value = CStr(IsArray(resultValue))
    Else
        sheet.Cells(rowNumber, 7).value = "error"
        sheet.Cells(rowNumber, 8).value = ""
        sheet.Cells(rowNumber, 9).value = ""
        sheet.Cells(rowNumber, 10).value = ""
        sheet.Cells(rowNumber, 11).value = ""
        sheet.Cells(rowNumber, 12).value = ""
    End If
    sheet.Cells(rowNumber, 13).value = errorNumber
    sheet.Cells(rowNumber, 14).value = errorLastDllError
    sheet.Cells(rowNumber, 15).value = errorHex
    sheet.Cells(rowNumber, 16).value = errorDescription
    sheet.Cells(rowNumber, 17).value = errorDescriptionUtf16Hex
    sheet.Cells(rowNumber, 18).value = errorSource
    sheet.Cells(rowNumber, 19).value = errorHelpFile
    sheet.Cells(rowNumber, 20).value = errorHelpContext
    sheet.Cells(rowNumber, 21).value = errorLine
    sheet.Cells(rowNumber, 22).value = errorStage
End Sub

Public Sub RecordOracleEvent(ByVal eventId As String, ByVal ledgerRowId As String, ByVal targetId As String, ByVal targetKind As String, ByVal eventName As String, ByVal argumentsBefore As String, ByVal argumentsAfter As String)
    Dim sheet As Worksheet
    Dim rowNumber As Long
    If Not mRecordingEnabled Then Exit Sub
    Set sheet = GetOrCreateOracleSheet(EVENT_SHEET)
    mSequence = mSequence + 1
    rowNumber = sheet.Cells(sheet.Rows.Count, 1).End(xlUp).Row + 1
    sheet.Cells(rowNumber, 1).value = mSequence
    sheet.Cells(rowNumber, 2).value = eventId
    sheet.Cells(rowNumber, 3).value = ledgerRowId
    sheet.Cells(rowNumber, 4).value = targetId
    sheet.Cells(rowNumber, 5).value = targetKind
    sheet.Cells(rowNumber, 6).value = eventName
    sheet.Cells(rowNumber, 7).value = argumentsBefore
    sheet.Cells(rowNumber, 8).value = argumentsAfter
    sheet.Cells(rowNumber, 9).value = mCurrentStep
End Sub

Public Function OracleValueText(ByVal value As Variant) As String
    On Error GoTo Failed
    If IsObject(value) Then
        OracleValueText = TypeName(value)
    ElseIf IsEmpty(value) Then
        OracleValueText = ""
    ElseIf IsNull(value) Then
        OracleValueText = "<Null>"
    Else
        OracleValueText = CStr(value)
    End If
    Exit Function
Failed:
    OracleValueText = "<unavailable>"
End Function

Public Function OracleEscapePair(ByVal value As String) As String
    OracleEscapePair = Replace(Replace(Replace(value, "\", "\\"), ";", "\;"), "=", "\=")
End Function

Public Function OracleErrorHex(ByVal number As Long) As String
    OracleErrorHex = "0x" & Right$("00000000" & Hex$(number), 8)
End Function

Public Function OracleUtf16Hex(ByVal value As String) As String
    Dim index As Long
    Dim codeUnit As Long
    Dim encoded As String
    For index = 1 To Len(value)
        codeUnit = CLng(AscW(Mid$(value, index, 1))) And &HFFFF&
        If index > 1 Then encoded = encoded & " "
        encoded = encoded & Right$("0000" & Hex$(codeUnit), 4)
    Next index
    OracleUtf16Hex = encoded
End Function

Public Function OracleWorksheetSafeErrorDescription(ByVal value As String) As String
    If Len(value) > 0 Then
        If AscW(Right$(value, 1)) = 0 Then
            OracleWorksheetSafeErrorDescription = Left$(value, Len(value) - 1)
            Exit Function
        End If
    End If
    OracleWorksheetSafeErrorDescription = value
End Function

Private Sub Probe_LabelCaptionRoundtrip()
    Dim resultValue As Variant
    Dim errorNumber As Long
    Dim errorLastDllError As Long
    Dim errorHex As String
    Dim errorDescription As String
    Dim errorDescriptionUtf16Hex As String
    Dim errorSource As String
    Dim errorHelpFile As String
    Dim errorHelpContext As Long
    Dim errorLine As Long
    Dim errorStage As String
    On Error Resume Next
    Err.Clear
    errorStage = "set"
    W010MemberOracleForm.ProbeLabel.Caption = "Live MSForms round-trip"
    errorLastDllError = Err.LastDllError
    errorNumber = Err.number
    errorDescription = Err.Description
    errorSource = Err.Source
    errorHelpFile = Err.HelpFile
    errorHelpContext = Err.HelpContext
    errorLine = Erl
    errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
    errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
    errorHex = OracleErrorHex(errorNumber)
    If errorNumber = 0 Then
        Err.Clear
        errorStage = "get"
        resultValue = W010MemberOracleForm.ProbeLabel.Caption
        errorLastDllError = Err.LastDllError
        errorNumber = Err.number
        errorDescription = Err.Description
        errorSource = Err.Source
        errorHelpFile = Err.HelpFile
        errorHelpContext = Err.HelpContext
        errorLine = Erl
        errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
        errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
        errorHex = OracleErrorHex(errorNumber)
    End If
    Err.Clear
    On Error GoTo 0
    AppendOracleProbe "LabelCaptionRoundtrip", "surface:{0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|91|primary|impl=0|decl={0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|65|primary|memid=0", "label_probe", "property_roundtrip", "Caption", resultValue, errorNumber, errorLastDllError, errorHex, errorDescription, errorDescriptionUtf16Hex, errorSource, errorHelpFile, errorHelpContext, errorLine, errorStage
End Sub

Private Sub Probe_TextMaxLengthCoercion()
    Dim resultValue As Variant
    Dim errorNumber As Long
    Dim errorLastDllError As Long
    Dim errorHex As String
    Dim errorDescription As String
    Dim errorDescriptionUtf16Hex As String
    Dim errorSource As String
    Dim errorHelpFile As String
    Dim errorHelpContext As Long
    Dim errorLine As Long
    Dim errorStage As String
    On Error Resume Next
    Err.Clear
    errorStage = "set"
    W010MemberOracleForm.ProbeTextBox.MaxLength = "12"
    errorLastDllError = Err.LastDllError
    errorNumber = Err.number
    errorDescription = Err.Description
    errorSource = Err.Source
    errorHelpFile = Err.HelpFile
    errorHelpContext = Err.HelpContext
    errorLine = Erl
    errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
    errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
    errorHex = OracleErrorHex(errorNumber)
    If errorNumber = 0 Then
        Err.Clear
        errorStage = "get"
        resultValue = W010MemberOracleForm.ProbeTextBox.MaxLength
        errorLastDllError = Err.LastDllError
        errorNumber = Err.number
        errorDescription = Err.Description
        errorSource = Err.Source
        errorHelpFile = Err.HelpFile
        errorHelpContext = Err.HelpContext
        errorLine = Erl
        errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
        errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
        errorHex = OracleErrorHex(errorNumber)
    End If
    Err.Clear
    On Error GoTo 0
    AppendOracleProbe "TextMaxLengthCoercion", "surface:{0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|95|primary|impl=0|decl={0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|68|primary|memid=-533", "text_probe", "property_roundtrip", "MaxLength", resultValue, errorNumber, errorLastDllError, errorHex, errorDescription, errorDescriptionUtf16Hex, errorSource, errorHelpFile, errorHelpContext, errorLine, errorStage
End Sub

Private Sub Probe_ListAddItemDefaultIndex()
    Dim resultValue As Variant
    Dim errorNumber As Long
    Dim errorLastDllError As Long
    Dim errorHex As String
    Dim errorDescription As String
    Dim errorDescriptionUtf16Hex As String
    Dim errorSource As String
    Dim errorHelpFile As String
    Dim errorHelpContext As Long
    Dim errorLine As Long
    Dim errorStage As String
    On Error Resume Next
    Err.Clear
    resultValue = Empty
    errorStage = "method"
    W010MemberOracleForm.ProbeListBox.AddItem "tail"
    errorLastDllError = Err.LastDllError
    errorNumber = Err.number
    errorDescription = Err.Description
    errorSource = Err.Source
    errorHelpFile = Err.HelpFile
    errorHelpContext = Err.HelpContext
    errorLine = Erl
    errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
    errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
    errorHex = OracleErrorHex(errorNumber)
    Err.Clear
    On Error GoTo 0
    AppendOracleProbe "ListAddItemDefaultIndex", "surface:{0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|97|primary|impl=0|decl={0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|69|primary|memid=-553", "list_probe", "method", "AddItem", resultValue, errorNumber, errorLastDllError, errorHex, errorDescription, errorDescriptionUtf16Hex, errorSource, errorHelpFile, errorHelpContext, errorLine, errorStage
End Sub

Private Sub Probe_ListCountAfterDefaultAdd()
    Dim resultValue As Variant
    Dim errorNumber As Long
    Dim errorLastDllError As Long
    Dim errorHex As String
    Dim errorDescription As String
    Dim errorDescriptionUtf16Hex As String
    Dim errorSource As String
    Dim errorHelpFile As String
    Dim errorHelpContext As Long
    Dim errorLine As Long
    Dim errorStage As String
    On Error Resume Next
    Err.Clear
    errorStage = "get"
    resultValue = W010MemberOracleForm.ProbeListBox.ListCount
    errorLastDllError = Err.LastDllError
    errorNumber = Err.number
    errorDescription = Err.Description
    errorSource = Err.Source
    errorHelpFile = Err.HelpFile
    errorHelpContext = Err.HelpContext
    errorLine = Erl
    errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
    errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
    errorHex = OracleErrorHex(errorNumber)
    Err.Clear
    On Error GoTo 0
    AppendOracleProbe "ListCountAfterDefaultAdd", "surface:{0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|97|primary|impl=0|decl={0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|69|primary|memid=-531", "list_probe", "property_get", "ListCount", resultValue, errorNumber, errorLastDllError, errorHex, errorDescription, errorDescriptionUtf16Hex, errorSource, errorHelpFile, errorHelpContext, errorLine, errorStage
End Sub

Private Sub Probe_ListAddItemExplicitIndex()
    Dim resultValue As Variant
    Dim errorNumber As Long
    Dim errorLastDllError As Long
    Dim errorHex As String
    Dim errorDescription As String
    Dim errorDescriptionUtf16Hex As String
    Dim errorSource As String
    Dim errorHelpFile As String
    Dim errorHelpContext As Long
    Dim errorLine As Long
    Dim errorStage As String
    On Error Resume Next
    Err.Clear
    resultValue = Empty
    errorStage = "method"
    W010MemberOracleForm.ProbeListBox.AddItem "head", 0
    errorLastDllError = Err.LastDllError
    errorNumber = Err.number
    errorDescription = Err.Description
    errorSource = Err.Source
    errorHelpFile = Err.HelpFile
    errorHelpContext = Err.HelpContext
    errorLine = Erl
    errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
    errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
    errorHex = OracleErrorHex(errorNumber)
    Err.Clear
    On Error GoTo 0
    AppendOracleProbe "ListAddItemExplicitIndex", "surface:{0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|97|primary|impl=0|decl={0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|69|primary|memid=-553", "list_probe", "method", "AddItem", resultValue, errorNumber, errorLastDllError, errorHex, errorDescription, errorDescriptionUtf16Hex, errorSource, errorHelpFile, errorHelpContext, errorLine, errorStage
End Sub

Private Sub Probe_ListFirstItemRead()
    Dim resultValue As Variant
    Dim errorNumber As Long
    Dim errorLastDllError As Long
    Dim errorHex As String
    Dim errorDescription As String
    Dim errorDescriptionUtf16Hex As String
    Dim errorSource As String
    Dim errorHelpFile As String
    Dim errorHelpContext As Long
    Dim errorLine As Long
    Dim errorStage As String
    On Error Resume Next
    Err.Clear
    errorStage = "get"
    resultValue = W010MemberOracleForm.ProbeListBox.List(0)
    errorLastDllError = Err.LastDllError
    errorNumber = Err.number
    errorDescription = Err.Description
    errorSource = Err.Source
    errorHelpFile = Err.HelpFile
    errorHelpContext = Err.HelpContext
    errorLine = Erl
    errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
    errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
    errorHex = OracleErrorHex(errorNumber)
    Err.Clear
    On Error GoTo 0
    AppendOracleProbe "ListFirstItemRead", "surface:{0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|97|primary|impl=0|decl={0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|69|primary|memid=-528", "list_probe", "property_get", "List", resultValue, errorNumber, errorLastDllError, errorHex, errorDescription, errorDescriptionUtf16Hex, errorSource, errorHelpFile, errorHelpContext, errorLine, errorStage
End Sub

Private Sub Probe_TextValueForEvents()
    Dim resultValue As Variant
    Dim errorNumber As Long
    Dim errorLastDllError As Long
    Dim errorHex As String
    Dim errorDescription As String
    Dim errorDescriptionUtf16Hex As String
    Dim errorSource As String
    Dim errorHelpFile As String
    Dim errorHelpContext As Long
    Dim errorLine As Long
    Dim errorStage As String
    On Error Resume Next
    Err.Clear
    errorStage = "set"
    W010MemberOracleForm.ProbeTextBox.value = "event payload"
    errorLastDllError = Err.LastDllError
    errorNumber = Err.number
    errorDescription = Err.Description
    errorSource = Err.Source
    errorHelpFile = Err.HelpFile
    errorHelpContext = Err.HelpContext
    errorLine = Erl
    errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
    errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
    errorHex = OracleErrorHex(errorNumber)
    If errorNumber = 0 Then
        Err.Clear
        errorStage = "get"
        resultValue = W010MemberOracleForm.ProbeTextBox.value
        errorLastDllError = Err.LastDllError
        errorNumber = Err.number
        errorDescription = Err.Description
        errorSource = Err.Source
        errorHelpFile = Err.HelpFile
        errorHelpContext = Err.HelpContext
        errorLine = Erl
        errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
        errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
        errorHex = OracleErrorHex(errorNumber)
    End If
    Err.Clear
    On Error GoTo 0
    AppendOracleProbe "TextValueForEvents", "surface:{0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|95|primary|impl=0|decl={0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|68|primary|memid=0", "text_probe", "property_roundtrip", "Value", resultValue, errorNumber, errorLastDllError, errorHex, errorDescription, errorDescriptionUtf16Hex, errorSource, errorHelpFile, errorHelpContext, errorLine, errorStage
End Sub

Private Sub Probe_TextDefaultValueRead()
    Dim resultValue As Variant
    Dim errorNumber As Long
    Dim errorLastDllError As Long
    Dim errorHex As String
    Dim errorDescription As String
    Dim errorDescriptionUtf16Hex As String
    Dim errorSource As String
    Dim errorHelpFile As String
    Dim errorHelpContext As Long
    Dim errorLine As Long
    Dim errorStage As String
    On Error Resume Next
    Err.Clear
    errorStage = "default_get"
    resultValue = W010MemberOracleForm.ProbeTextBox
    errorLastDllError = Err.LastDllError
    errorNumber = Err.number
    errorDescription = Err.Description
    errorSource = Err.Source
    errorHelpFile = Err.HelpFile
    errorHelpContext = Err.HelpContext
    errorLine = Erl
    errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
    errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
    errorHex = OracleErrorHex(errorNumber)
    Err.Clear
    On Error GoTo 0
    AppendOracleProbe "TextDefaultValueRead", "surface:{0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|95|primary|impl=0|decl={0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|68|primary|memid=0", "text_probe", "default_get", "Value", resultValue, errorNumber, errorLastDllError, errorHex, errorDescription, errorDescriptionUtf16Hex, errorSource, errorHelpFile, errorHelpContext, errorLine, errorStage
End Sub

Private Sub Probe_CheckValueCoercion()
    Dim resultValue As Variant
    Dim errorNumber As Long
    Dim errorLastDllError As Long
    Dim errorHex As String
    Dim errorDescription As String
    Dim errorDescriptionUtf16Hex As String
    Dim errorSource As String
    Dim errorHelpFile As String
    Dim errorHelpContext As Long
    Dim errorLine As Long
    Dim errorStage As String
    On Error Resume Next
    Err.Clear
    errorStage = "set"
    W010MemberOracleForm.ProbeCheckBox.value = "True"
    errorLastDllError = Err.LastDllError
    errorNumber = Err.number
    errorDescription = Err.Description
    errorSource = Err.Source
    errorHelpFile = Err.HelpFile
    errorHelpContext = Err.HelpContext
    errorLine = Erl
    errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
    errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
    errorHex = OracleErrorHex(errorNumber)
    If errorNumber = 0 Then
        Err.Clear
        errorStage = "get"
        resultValue = W010MemberOracleForm.ProbeCheckBox.value
        errorLastDllError = Err.LastDllError
        errorNumber = Err.number
        errorDescription = Err.Description
        errorSource = Err.Source
        errorHelpFile = Err.HelpFile
        errorHelpContext = Err.HelpContext
        errorLine = Erl
        errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
        errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
        errorHex = OracleErrorHex(errorNumber)
    End If
    Err.Clear
    On Error GoTo 0
    AppendOracleProbe "CheckValueCoercion", "surface:{0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|103|primary|impl=0|decl={0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|71|primary|memid=0", "check_probe", "property_roundtrip", "Value", resultValue, errorNumber, errorLastDllError, errorHex, errorDescription, errorDescriptionUtf16Hex, errorSource, errorHelpFile, errorHelpContext, errorLine, errorStage
End Sub

Private Sub Probe_TextMaxLengthInvalid()
    Dim resultValue As Variant
    Dim errorNumber As Long
    Dim errorLastDllError As Long
    Dim errorHex As String
    Dim errorDescription As String
    Dim errorDescriptionUtf16Hex As String
    Dim errorSource As String
    Dim errorHelpFile As String
    Dim errorHelpContext As Long
    Dim errorLine As Long
    Dim errorStage As String
    On Error Resume Next
    Err.Clear
    errorStage = "set"
    W010MemberOracleForm.ProbeTextBox.MaxLength = -1
    errorLastDllError = Err.LastDllError
    errorNumber = Err.number
    errorDescription = Err.Description
    errorSource = Err.Source
    errorHelpFile = Err.HelpFile
    errorHelpContext = Err.HelpContext
    errorLine = Erl
    errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
    errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
    errorHex = OracleErrorHex(errorNumber)
    If errorNumber = 0 Then
        Err.Clear
        errorStage = "get"
        resultValue = W010MemberOracleForm.ProbeTextBox.MaxLength
        errorLastDllError = Err.LastDllError
        errorNumber = Err.number
        errorDescription = Err.Description
        errorSource = Err.Source
        errorHelpFile = Err.HelpFile
        errorHelpContext = Err.HelpContext
        errorLine = Erl
        errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
        errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
        errorHex = OracleErrorHex(errorNumber)
    End If
    Err.Clear
    On Error GoTo 0
    AppendOracleProbe "TextMaxLengthInvalid", "surface:{0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|95|primary|impl=0|decl={0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|68|primary|memid=-533", "text_probe", "property_roundtrip", "MaxLength", resultValue, errorNumber, errorLastDllError, errorHex, errorDescription, errorDescriptionUtf16Hex, errorSource, errorHelpFile, errorHelpContext, errorLine, errorStage
End Sub

Private Sub Probe_ButtonCaptionRead()
    Dim resultValue As Variant
    Dim errorNumber As Long
    Dim errorLastDllError As Long
    Dim errorHex As String
    Dim errorDescription As String
    Dim errorDescriptionUtf16Hex As String
    Dim errorSource As String
    Dim errorHelpFile As String
    Dim errorHelpContext As Long
    Dim errorLine As Long
    Dim errorStage As String
    On Error Resume Next
    Err.Clear
    errorStage = "get"
    resultValue = W010MemberOracleForm.ProbeCommandButton.Caption
    errorLastDllError = Err.LastDllError
    errorNumber = Err.number
    errorDescription = Err.Description
    errorSource = Err.Source
    errorHelpFile = Err.HelpFile
    errorHelpContext = Err.HelpContext
    errorLine = Erl
    errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)
    errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)
    errorHex = OracleErrorHex(errorNumber)
    Err.Clear
    On Error GoTo 0
    AppendOracleProbe "ButtonCaptionRead", "surface:{0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|93|primary|impl=0|decl={0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|66|primary|memid=-518", "button_probe", "property_get", "Caption", resultValue, errorNumber, errorLastDllError, errorHex, errorDescription, errorDescriptionUtf16Hex, errorSource, errorHelpFile, errorHelpContext, errorLine, errorStage
End Sub
