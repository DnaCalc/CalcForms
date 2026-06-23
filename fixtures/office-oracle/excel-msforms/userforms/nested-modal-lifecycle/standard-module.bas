Option Explicit

Private Const LOG_SHEET_NAME As String = "W006NestedModalLog"

Private gSequence As Long
Private gCurrentScenario As String
Private gCloseOrigin As String
Private gModalParentRowId As Long

Public Sub ClearW006NestedModalLog()
    Dim sheet As Worksheet

    gSequence = 0
    gCurrentScenario = ""
    gCloseOrigin = ""
    gModalParentRowId = 0

    Set sheet = W006NestedGetOrCreateLogSheet()
    sheet.Cells.Clear
    W006NestedWriteLogHeaders sheet
End Sub

Public Sub ShowW006NestedOuterModeless()
    W006NestedSetCurrentScenario "outer_modeless"
    W006NestedSetCloseOrigin ""
    gModalParentRowId = 0
    OxFormsW006NestedOuter.Tag = "form_identity=outer;show_mode=modeless;modal_depth=0;scenario=outer_modeless"
    OxFormsW006NestedOuter.Show vbModeless
End Sub

Public Sub W006NestedShowInnerModal(ByVal scenarioName As String)
    W006NestedSetCurrentScenario scenarioName
    OxFormsW006NestedInner.Tag = "form_identity=inner;show_mode=modal;modal_depth=1;scenario=" & scenarioName
    OxFormsW006NestedInner.Show vbModal
End Sub

Public Sub W006NestedSetCurrentScenario(ByVal scenarioName As String)
    gCurrentScenario = scenarioName
End Sub

Public Function W006NestedCurrentScenario() As String
    W006NestedCurrentScenario = gCurrentScenario
End Function

Public Sub W006NestedSetCloseOrigin(ByVal closeOrigin As String)
    gCloseOrigin = closeOrigin
End Sub

Public Function W006NestedCurrentCloseOrigin() As String
    W006NestedCurrentCloseOrigin = gCloseOrigin
End Function

Public Sub W006NestedSetModalParentRowId(ByVal rowId As Long)
    gModalParentRowId = rowId
End Sub

Public Sub W006NestedClearModalParentRowId()
    gModalParentRowId = 0
End Sub

Public Function W006NestedAppendLog(ByVal formObj As Object, ByVal formIdentity As String, ByVal targetName As String, ByVal targetKind As String, ByVal eventName As String, ByVal argumentSummary As String, Optional ByVal handlerName As String = "", Optional ByVal actionName As String = "", Optional ByVal closeOrigin As String = "", Optional ByVal cancelBefore As Variant, Optional ByVal cancelAfter As Variant, Optional ByVal closeMode As Variant, Optional ByVal notes As String = "", Optional ByVal parentRowId As Variant, Optional ByVal nestingDepth As Variant) As Long
    Dim sheet As Worksheet
    Dim nextRow As Long
    Dim rowParent As String
    Dim rowDepth As Long
    Dim rowCloseOrigin As String

    Set sheet = W006NestedGetOrCreateLogSheet()
    gSequence = gSequence + 1
    nextRow = sheet.Cells(sheet.Rows.Count, 1).End(xlUp).Row + 1

    If IsMissing(parentRowId) Then
        If formIdentity = "inner" And gModalParentRowId > 0 Then
            rowParent = CStr(gModalParentRowId)
        Else
            rowParent = ""
        End If
    Else
        rowParent = W006NestedScalarToText(parentRowId)
    End If

    If IsMissing(nestingDepth) Then
        If formIdentity = "inner" Then
            rowDepth = 1
        Else
            rowDepth = 0
        End If
    Else
        rowDepth = CLng(nestingDepth)
    End If

    If Len(closeOrigin) > 0 Then
        rowCloseOrigin = closeOrigin
    Else
        rowCloseOrigin = gCloseOrigin
    End If

    sheet.Cells(nextRow, 1).Value = gSequence
    sheet.Cells(nextRow, 2).Value = gSequence
    sheet.Cells(nextRow, 3).Value = rowParent
    sheet.Cells(nextRow, 4).Value = rowDepth
    sheet.Cells(nextRow, 5).Value = gCurrentScenario
    sheet.Cells(nextRow, 6).Value = formIdentity
    sheet.Cells(nextRow, 7).Value = W006NestedSafeFormProperty(formObj, "Name")
    sheet.Cells(nextRow, 8).Value = W006NestedSafeFormProperty(formObj, "Caption")
    sheet.Cells(nextRow, 9).Value = W006NestedTagPart(formObj, "show_mode", "unknown")
    sheet.Cells(nextRow, 10).Value = targetName
    sheet.Cells(nextRow, 11).Value = targetKind
    sheet.Cells(nextRow, 12).Value = eventName
    sheet.Cells(nextRow, 13).Value = argumentSummary
    sheet.Cells(nextRow, 14).Value = handlerName
    sheet.Cells(nextRow, 15).Value = actionName
    sheet.Cells(nextRow, 16).Value = rowCloseOrigin
    sheet.Cells(nextRow, 17).Value = W006NestedOptionalText(cancelBefore)
    sheet.Cells(nextRow, 18).Value = W006NestedOptionalText(cancelAfter)
    sheet.Cells(nextRow, 19).Value = W006NestedOptionalText(closeMode)
    sheet.Cells(nextRow, 20).Value = formIdentity
    sheet.Cells(nextRow, 21).Value = W006NestedActiveControlName(formObj)
    sheet.Cells(nextRow, 22).Value = W006NestedActiveWindowCaption()
    sheet.Cells(nextRow, 23).Value = W006NestedSafeFormProperty(formObj, "Visible")
    sheet.Cells(nextRow, 24).Value = notes
    sheet.Cells(nextRow, 25).Value = Now

    W006NestedAppendLog = gSequence
End Function

Private Function W006NestedGetOrCreateLogSheet() As Worksheet
    On Error Resume Next
    Set W006NestedGetOrCreateLogSheet = ThisWorkbook.Worksheets(LOG_SHEET_NAME)
    On Error GoTo 0

    If W006NestedGetOrCreateLogSheet Is Nothing Then
        Set W006NestedGetOrCreateLogSheet = ThisWorkbook.Worksheets.Add
        W006NestedGetOrCreateLogSheet.Name = LOG_SHEET_NAME
    End If

    If CStr(W006NestedGetOrCreateLogSheet.Cells(1, 1).Value) <> "sequence" Then
        W006NestedWriteLogHeaders W006NestedGetOrCreateLogSheet
    End If
End Function

Private Sub W006NestedWriteLogHeaders(ByVal sheet As Worksheet)
    sheet.Cells(1, 1).Value = "sequence"
    sheet.Cells(1, 2).Value = "logical_tick"
    sheet.Cells(1, 3).Value = "parent_row_id"
    sheet.Cells(1, 4).Value = "nesting_depth"
    sheet.Cells(1, 5).Value = "scenario"
    sheet.Cells(1, 6).Value = "form_identity"
    sheet.Cells(1, 7).Value = "form_name"
    sheet.Cells(1, 8).Value = "form_caption"
    sheet.Cells(1, 9).Value = "show_mode"
    sheet.Cells(1, 10).Value = "target_name"
    sheet.Cells(1, 11).Value = "target_kind"
    sheet.Cells(1, 12).Value = "event_name"
    sheet.Cells(1, 13).Value = "argument_summary"
    sheet.Cells(1, 14).Value = "handler_name"
    sheet.Cells(1, 15).Value = "action"
    sheet.Cells(1, 16).Value = "close_origin"
    sheet.Cells(1, 17).Value = "cancel_before"
    sheet.Cells(1, 18).Value = "cancel_after"
    sheet.Cells(1, 19).Value = "close_mode"
    sheet.Cells(1, 20).Value = "active_form_hint"
    sheet.Cells(1, 21).Value = "active_control"
    sheet.Cells(1, 22).Value = "active_window_caption"
    sheet.Cells(1, 23).Value = "current_form_visible"
    sheet.Cells(1, 24).Value = "notes"
    sheet.Cells(1, 25).Value = "wall_clock_local"
End Sub

Private Function W006NestedTagPart(ByVal formObj As Object, ByVal key As String, ByVal defaultValue As String) As String
    Dim tagText As String
    Dim parts As Variant
    Dim part As Variant
    Dim prefix As String

    On Error GoTo Failed
    tagText = CStr(formObj.Tag)
    prefix = key & "="
    parts = Split(tagText, ";")
    For Each part In parts
        If Left$(CStr(part), Len(prefix)) = prefix Then
            W006NestedTagPart = Mid$(CStr(part), Len(prefix) + 1)
            Exit Function
        End If
    Next
Failed:
    W006NestedTagPart = defaultValue
End Function

Private Function W006NestedSafeFormProperty(ByVal formObj As Object, ByVal propertyName As String) As String
    On Error GoTo Failed
    W006NestedSafeFormProperty = CStr(CallByName(formObj, propertyName, VbGet))
    Exit Function
Failed:
    W006NestedSafeFormProperty = "<unavailable>"
End Function

Private Function W006NestedActiveControlName(ByVal formObj As Object) As String
    On Error GoTo Failed
    W006NestedActiveControlName = formObj.ActiveControl.Name
    Exit Function
Failed:
    W006NestedActiveControlName = "<none>"
End Function

Private Function W006NestedActiveWindowCaption() As String
    On Error GoTo Failed
    W006NestedActiveWindowCaption = Application.ActiveWindow.Caption
    Exit Function
Failed:
    W006NestedActiveWindowCaption = "<unavailable>"
End Function

Private Function W006NestedOptionalText(Optional ByVal value As Variant) As String
    If IsMissing(value) Then
        W006NestedOptionalText = ""
    Else
        W006NestedOptionalText = W006NestedScalarToText(value)
    End If
End Function

Private Function W006NestedScalarToText(ByVal value As Variant) As String
    On Error GoTo Failed
    If IsObject(value) Then
        W006NestedScalarToText = "<object>"
    ElseIf IsEmpty(value) Or IsNull(value) Then
        W006NestedScalarToText = ""
    Else
        W006NestedScalarToText = CStr(value)
    End If
    Exit Function
Failed:
    W006NestedScalarToText = "<unavailable>"
End Function
