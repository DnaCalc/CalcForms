Private Const W006_TERMINATE_LOG_SHEET As String = "W006TerminateLog"

Private gSequence As Long
Private gNextInstanceNumber As Long
Private gCurrentScenario As String
Private gCurrentShowMode As String
Private gCurrentCloseOrigin As String
Private gCurrentInstanceId As String
Private gLocalRefState As String
Private gHeldRefState As String
Private gDefaultInstanceState As String
Private gReleasePhase As String
Private gAutoAction As String
Private gHeldRef As OxFormsW006TerminateForm

Public Sub ClearW006TerminateLog()
    Dim sheet As Worksheet

    gSequence = 0
    gNextInstanceNumber = 0
    gCurrentScenario = ""
    gCurrentShowMode = ""
    gCurrentCloseOrigin = ""
    gCurrentInstanceId = ""
    gLocalRefState = "none"
    gHeldRefState = "none"
    gDefaultInstanceState = "not_used"
    gReleasePhase = "none"
    gAutoAction = ""
    Set gHeldRef = Nothing

    Set sheet = W006TerminateGetOrCreateLogSheet()
    sheet.Cells.Clear
    W006TerminateWriteLogHeaders sheet
End Sub

Public Sub RunW006TerminateHideHeldScenario()
    Dim f As OxFormsW006TerminateForm

    W006TerminateBeginScenario "hide_held_release", "modeless", "fixture_hide"
    Set f = W006TerminateCreateScenarioForm("hide_held_release", "modeless", "fixture_hide", True)
    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "BeforeShowModeless", "fixture_action", "fixture action", actionName:="show_modeless", notes:="Local and global held references are both active before modeless Show."
    f.Show vbModeless
    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "AfterShowModeless", "fixture_action", "fixture action", actionName:="show_modeless_return"
    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "BeforeHide", "fixture_action", "fixture action", actionName:="hide", notes:="Calling f.Hide while local and global held references are active."
    f.Hide
    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "AfterHide", "fixture_action", "fixture action", actionName:="hide_return", notes:="VBA resumed after f.Hide; this row does not imply Terminate."

    gReleasePhase = "local_ref_release_after_hide"
    gLocalRefState = "releasing"
    Set f = Nothing
    gLocalRefState = "released"
    W006TerminateAppendLog Nothing, "fixture", "repo-owned VBA", "AfterLocalReferenceRelease", "fixture_action", "fixture action", actionName:="release_local_ref", notes:="The global held reference remains active after the local reference release."
    W006TerminateReleaseHeldReference "held_ref_release_after_hide"
    W006TerminateEndScenario "hide_held_release"
End Sub

Public Sub RunW006TerminateUnloadHeldScenario()
    Dim f As OxFormsW006TerminateForm

    W006TerminateBeginScenario "unload_held_release", "modeless", "fixture_unload"
    Set f = W006TerminateCreateScenarioForm("unload_held_release", "modeless", "fixture_unload", True)
    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "BeforeShowModeless", "fixture_action", "fixture action", actionName:="show_modeless"
    f.Show vbModeless
    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "AfterShowModeless", "fixture_action", "fixture action", actionName:="show_modeless_return"
    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "BeforeUnload", "fixture_action", "fixture action", actionName:="unload", notes:="Calling Unload f while local and global held references are active."
    Unload f
    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "AfterUnload", "fixture_action", "fixture action", actionName:="unload_return", notes:="This row is present only if VBA resumes after Unload f."

    gReleasePhase = "local_ref_release_after_unload"
    gLocalRefState = "releasing"
    Set f = Nothing
    gLocalRefState = "released"
    W006TerminateAppendLog Nothing, "fixture", "repo-owned VBA", "AfterLocalReferenceRelease", "fixture_action", "fixture action", actionName:="release_local_ref", notes:="The global held reference remains active after the local reference release."
    W006TerminateReleaseHeldReference "held_ref_release_after_unload"
    W006TerminateEndScenario "unload_held_release"
End Sub

Public Sub StartW006TerminateModelessCloseHeldScenario()
    Dim f As OxFormsW006TerminateForm

    W006TerminateBeginScenario "modeless_system_close_held_release", "modeless", "public_wm_close"
    Set f = W006TerminateCreateScenarioForm("modeless_system_close_held_release", "modeless", "public_wm_close", True)
    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "BeforeShowModeless", "fixture_action", "fixture action", actionName:="show_modeless"
    f.Show vbModeless
    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "AfterShowModeless", "fixture_action", "fixture action", actionName:="show_modeless_return"

    gReleasePhase = "local_ref_release_before_public_wm_close"
    gLocalRefState = "releasing"
    Set f = Nothing
    gLocalRefState = "released"
    W006TerminateAppendLog gHeldRef, "fixture", "repo-owned VBA", "ReadyForPublicWindowClose", "fixture_action", "fixture action", actionName:="await_public_wm_close", closeOrigin:="public_wm_close", notes:="PowerShell capture script sends public WM_CLOSE while only the global held reference remains in fixture state."
End Sub

Public Sub FinishW006TerminateModelessCloseHeldScenario()
    W006TerminateReleaseHeldReference "held_ref_release_after_public_wm_close"
    W006TerminateEndScenario "modeless_system_close_held_release"
End Sub

Public Sub CleanupW006TerminateHeldForm()
    If gHeldRef Is Nothing Then
        W006TerminateAppendLog Nothing, "fixture", "repo-owned VBA", "CleanupNoHeldReference", "fixture_action", "fixture action", actionName:="cleanup_no_held_ref"
        Exit Sub
    End If

    W006TerminateAppendLog gHeldRef, "fixture", "repo-owned VBA", "BeforeCleanupUnload", "fixture_action", "fixture action", actionName:="cleanup_unload", notes:="Cleanup path after a blocked public close attempt; not used for parity claims."
    Unload gHeldRef
    W006TerminateAppendLog gHeldRef, "fixture", "repo-owned VBA", "AfterCleanupUnload", "fixture_action", "fixture action", actionName:="cleanup_unload_return"
End Sub

Public Sub RunW006TerminateModalHideHeldScenario()
    Dim f As OxFormsW006TerminateForm

    W006TerminateBeginScenario "modal_hide_return_held_release", "modal", "modal_hide_from_activate"
    Set f = W006TerminateCreateScenarioForm("modal_hide_return_held_release", "modal", "modal_hide_from_activate", True)
    gAutoAction = "hide_on_activate"
    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "BeforeShowModal", "fixture_action", "fixture action", actionName:="show_modal", notes:="Activate handler will call Hide so the modal Show can return."
    f.Show vbModal
    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "AfterShowModalReturn", "fixture_action", "fixture action", actionName:="modal_show_return", notes:="Modal Show returned after the fixture Hide path."

    gReleasePhase = "local_ref_release_after_modal_hide_return"
    gLocalRefState = "releasing"
    Set f = Nothing
    gLocalRefState = "released"
    W006TerminateAppendLog Nothing, "fixture", "repo-owned VBA", "AfterLocalReferenceRelease", "fixture_action", "fixture action", actionName:="release_local_ref"
    W006TerminateReleaseHeldReference "held_ref_release_after_modal_hide_return"
    W006TerminateEndScenario "modal_hide_return_held_release"
End Sub

Public Sub RunW006TerminateModalUnloadHeldScenario()
    Dim f As OxFormsW006TerminateForm

    W006TerminateBeginScenario "modal_unload_return_held_release", "modal", "modal_unload_from_activate"
    Set f = W006TerminateCreateScenarioForm("modal_unload_return_held_release", "modal", "modal_unload_from_activate", True)
    gAutoAction = "unload_on_activate"
    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "BeforeShowModal", "fixture_action", "fixture action", actionName:="show_modal", notes:="Activate handler will call Unload so the modal Show can return."
    f.Show vbModal
    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "AfterShowModalReturn", "fixture_action", "fixture action", actionName:="modal_show_return", notes:="Modal Show returned after the fixture Unload path."

    gReleasePhase = "local_ref_release_after_modal_unload_return"
    gLocalRefState = "releasing"
    Set f = Nothing
    gLocalRefState = "released"
    W006TerminateAppendLog Nothing, "fixture", "repo-owned VBA", "AfterLocalReferenceRelease", "fixture_action", "fixture action", actionName:="release_local_ref"
    W006TerminateReleaseHeldReference "held_ref_release_after_modal_unload_return"
    W006TerminateEndScenario "modal_unload_return_held_release"
End Sub

Public Sub W006TerminateMaybeRunAutoAction(ByVal formObj As OxFormsW006TerminateForm)
    Dim action As String

    action = gAutoAction
    If Len(action) = 0 Then
        Exit Sub
    End If
    gAutoAction = ""

    If action = "hide_on_activate" Then
        W006TerminateAppendLog formObj, "fixture", "repo-owned VBA", "BeforeAutoHide", "fixture_action", "fixture action", actionName:="hide_from_activate", closeOrigin:=gCurrentCloseOrigin, notes:="Calling formObj.Hide from UserForm_Activate."
        formObj.Hide
        W006TerminateAppendLog formObj, "fixture", "repo-owned VBA", "AfterAutoHide", "fixture_action", "fixture action", actionName:="hide_from_activate_return", closeOrigin:=gCurrentCloseOrigin, notes:="VBA resumed after formObj.Hide inside Activate."
    ElseIf action = "unload_on_activate" Then
        W006TerminateAppendLog formObj, "fixture", "repo-owned VBA", "BeforeAutoUnload", "fixture_action", "fixture action", actionName:="unload_from_activate", closeOrigin:=gCurrentCloseOrigin, notes:="Calling Unload formObj from UserForm_Activate."
        Unload formObj
        W006TerminateAppendLog formObj, "fixture", "repo-owned VBA", "AfterAutoUnload", "fixture_action", "fixture action", actionName:="unload_from_activate_return", closeOrigin:=gCurrentCloseOrigin, notes:="This row is present only if VBA resumes after Unload inside Activate."
    Else
        W006TerminateAppendLog formObj, "fixture", "repo-owned VBA", "UnknownAutoAction", "fixture_action", "fixture action", actionName:=action, notes:="Unknown auto action was ignored."
    End If
End Sub

Public Function W006TerminateCurrentCloseOrigin() As String
    W006TerminateCurrentCloseOrigin = gCurrentCloseOrigin
End Function

Public Sub W006TerminateReleaseHeldReference(ByVal releaseReason As String)
    If gHeldRef Is Nothing Then
        W006TerminateAppendLog Nothing, "fixture", "repo-owned VBA", "NoHeldReferenceToRelease", "fixture_action", "fixture action", actionName:="release_held_ref", notes:="No global held reference existed when release was requested."
        gHeldRefState = "released"
        Exit Sub
    End If

    W006TerminateAppendLog gHeldRef, "fixture", "repo-owned VBA", "BeforeHeldReferenceRelease", "fixture_action", "fixture action", actionName:="release_held_ref", notes:="About to set the global held reference to Nothing."
    gReleasePhase = releaseReason
    gHeldRefState = "releasing"
    Set gHeldRef = Nothing
    gHeldRefState = "released"
    W006TerminateAppendLog Nothing, "fixture", "repo-owned VBA", "AfterHeldReferenceRelease", "fixture_action", "fixture action", actionName:="release_held_ref_return", notes:="VBA resumed after setting the global held reference to Nothing."
End Sub

Private Sub W006TerminateBeginScenario(ByVal scenarioName As String, ByVal showMode As String, ByVal closeOrigin As String)
    gCurrentScenario = scenarioName
    gCurrentShowMode = showMode
    gCurrentCloseOrigin = closeOrigin
    gCurrentInstanceId = ""
    gLocalRefState = "none"
    gHeldRefState = "none"
    gDefaultInstanceState = "not_used"
    gReleasePhase = "none"
    gAutoAction = ""
    Set gHeldRef = Nothing
    W006TerminateAppendLog Nothing, "fixture", "repo-owned VBA", "ScenarioStart", "fixture_action", "fixture action", actionName:="scenario_start", closeOrigin:=closeOrigin
End Sub

Private Function W006TerminateCreateScenarioForm(ByVal scenarioName As String, ByVal showMode As String, ByVal closeOrigin As String, ByVal holdGlobal As Boolean) As OxFormsW006TerminateForm
    Dim f As OxFormsW006TerminateForm

    gCurrentScenario = scenarioName
    gCurrentShowMode = showMode
    gCurrentCloseOrigin = closeOrigin
    gDefaultInstanceState = "not_used"
    gReleasePhase = "create_instance"
    gLocalRefState = "creating"
    gHeldRefState = "not_set"
    gNextInstanceNumber = gNextInstanceNumber + 1
    gCurrentInstanceId = "instance-" & Format$(gNextInstanceNumber, "000")

    Set f = New OxFormsW006TerminateForm
    f.Tag = "instance_id=" & gCurrentInstanceId & ";scenario=" & scenarioName & ";show_mode=" & showMode
    gLocalRefState = "held"
    If holdGlobal Then
        Set gHeldRef = f
        gHeldRefState = "held"
    Else
        gHeldRefState = "not_set"
    End If

    W006TerminateAppendLog f, "fixture", "repo-owned VBA", "AfterCreateInstance", "fixture_action", "fixture action", actionName:="create_instance", closeOrigin:=closeOrigin
    Set W006TerminateCreateScenarioForm = f
End Function

Private Sub W006TerminateEndScenario(ByVal scenarioName As String)
    gReleasePhase = "scenario_end"
    W006TerminateAppendLog Nothing, "fixture", "repo-owned VBA", "ScenarioEnd", "fixture_action", "fixture action", actionName:="scenario_end", notes:="Scenario ended after the explicit release sequence."
End Sub

Public Sub W006TerminateAppendLog(ByVal formObj As Object, ByVal targetName As String, ByVal targetKind As String, ByVal eventName As String, ByVal rowKind As String, ByVal argumentSummary As String, Optional ByVal handlerName As String = "", Optional ByVal actionName As String = "", Optional ByVal closeOrigin As String = "", Optional ByVal cancelBefore As Variant, Optional ByVal cancelAfter As Variant, Optional ByVal closeMode As Variant, Optional ByVal notes As String = "")
    Dim sheet As Worksheet
    Dim nextRow As Long
    Dim instanceId As String
    Dim scenarioText As String
    Dim showModeText As String
    Dim originText As String

    Set sheet = W006TerminateGetOrCreateLogSheet()
    gSequence = gSequence + 1
    nextRow = sheet.Cells(sheet.Rows.Count, 1).End(xlUp).Row + 1

    instanceId = W006TerminateEffectiveTagPart(formObj, "instance_id", gCurrentInstanceId)
    scenarioText = W006TerminateEffectiveTagPart(formObj, "scenario", gCurrentScenario)
    showModeText = W006TerminateEffectiveTagPart(formObj, "show_mode", gCurrentShowMode)
    If Len(closeOrigin) > 0 Then
        originText = closeOrigin
    Else
        originText = gCurrentCloseOrigin
    End If

    sheet.Cells(nextRow, 1).Value = gSequence
    sheet.Cells(nextRow, 2).Value = gSequence
    sheet.Cells(nextRow, 3).Value = scenarioText
    sheet.Cells(nextRow, 4).Value = instanceId
    sheet.Cells(nextRow, 5).Value = showModeText
    sheet.Cells(nextRow, 6).Value = rowKind
    sheet.Cells(nextRow, 7).Value = targetName
    sheet.Cells(nextRow, 8).Value = targetKind
    sheet.Cells(nextRow, 9).Value = eventName
    sheet.Cells(nextRow, 10).Value = argumentSummary
    sheet.Cells(nextRow, 11).Value = handlerName
    sheet.Cells(nextRow, 12).Value = actionName
    sheet.Cells(nextRow, 13).Value = originText
    sheet.Cells(nextRow, 14).Value = W006TerminateOptionalText(cancelBefore)
    sheet.Cells(nextRow, 15).Value = W006TerminateOptionalText(cancelAfter)
    sheet.Cells(nextRow, 16).Value = W006TerminateOptionalText(closeMode)
    sheet.Cells(nextRow, 17).Value = gLocalRefState
    sheet.Cells(nextRow, 18).Value = gHeldRefState
    sheet.Cells(nextRow, 19).Value = gDefaultInstanceState
    sheet.Cells(nextRow, 20).Value = gReleasePhase
    sheet.Cells(nextRow, 21).Value = W006TerminateSafeFormProperty(formObj, "Visible")
    sheet.Cells(nextRow, 22).Value = W006TerminateActiveControlName(formObj)
    sheet.Cells(nextRow, 23).Value = W006TerminateActiveWindowCaption()
    sheet.Cells(nextRow, 24).Value = notes
    sheet.Cells(nextRow, 25).Value = Now
End Sub

Private Function W006TerminateGetOrCreateLogSheet() As Worksheet
    On Error Resume Next
    Set W006TerminateGetOrCreateLogSheet = ThisWorkbook.Worksheets(W006_TERMINATE_LOG_SHEET)
    On Error GoTo 0

    If W006TerminateGetOrCreateLogSheet Is Nothing Then
        Set W006TerminateGetOrCreateLogSheet = ThisWorkbook.Worksheets.Add
        W006TerminateGetOrCreateLogSheet.Name = W006_TERMINATE_LOG_SHEET
    End If

    If CStr(W006TerminateGetOrCreateLogSheet.Cells(1, 1).Value) <> "sequence" Then
        W006TerminateWriteLogHeaders W006TerminateGetOrCreateLogSheet
    End If
End Function

Private Sub W006TerminateWriteLogHeaders(ByVal sheet As Worksheet)
    sheet.Cells(1, 1).Value = "sequence"
    sheet.Cells(1, 2).Value = "logical_tick"
    sheet.Cells(1, 3).Value = "scenario"
    sheet.Cells(1, 4).Value = "instance_id"
    sheet.Cells(1, 5).Value = "show_mode"
    sheet.Cells(1, 6).Value = "row_kind"
    sheet.Cells(1, 7).Value = "target_name"
    sheet.Cells(1, 8).Value = "target_kind"
    sheet.Cells(1, 9).Value = "event_name"
    sheet.Cells(1, 10).Value = "argument_summary"
    sheet.Cells(1, 11).Value = "handler_name"
    sheet.Cells(1, 12).Value = "action"
    sheet.Cells(1, 13).Value = "close_origin"
    sheet.Cells(1, 14).Value = "cancel_before"
    sheet.Cells(1, 15).Value = "cancel_after"
    sheet.Cells(1, 16).Value = "close_mode"
    sheet.Cells(1, 17).Value = "local_ref_state"
    sheet.Cells(1, 18).Value = "held_ref_state"
    sheet.Cells(1, 19).Value = "default_instance_state"
    sheet.Cells(1, 20).Value = "release_phase"
    sheet.Cells(1, 21).Value = "form_visible"
    sheet.Cells(1, 22).Value = "active_control"
    sheet.Cells(1, 23).Value = "active_window_caption"
    sheet.Cells(1, 24).Value = "notes"
    sheet.Cells(1, 25).Value = "wall_clock_local"
End Sub

Private Function W006TerminateEffectiveTagPart(ByVal formObj As Object, ByVal key As String, ByVal defaultValue As String) As String
    If formObj Is Nothing Then
        W006TerminateEffectiveTagPart = defaultValue
    Else
        W006TerminateEffectiveTagPart = W006TerminateTagPart(formObj, key, defaultValue)
    End If
End Function

Private Function W006TerminateTagPart(ByVal formObj As Object, ByVal key As String, ByVal defaultValue As String) As String
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
            W006TerminateTagPart = Mid$(CStr(part), Len(prefix) + 1)
            Exit Function
        End If
    Next
Failed:
    W006TerminateTagPart = defaultValue
End Function

Private Function W006TerminateSafeFormProperty(ByVal formObj As Object, ByVal propertyName As String) As String
    If formObj Is Nothing Then
        W006TerminateSafeFormProperty = "<no form object>"
        Exit Function
    End If

    On Error GoTo Failed
    W006TerminateSafeFormProperty = CStr(CallByName(formObj, propertyName, VbGet))
    Exit Function
Failed:
    W006TerminateSafeFormProperty = "<unavailable>"
End Function

Private Function W006TerminateActiveControlName(ByVal formObj As Object) As String
    If formObj Is Nothing Then
        W006TerminateActiveControlName = "<no form object>"
        Exit Function
    End If

    On Error GoTo Failed
    W006TerminateActiveControlName = formObj.ActiveControl.Name
    Exit Function
Failed:
    W006TerminateActiveControlName = "<none>"
End Function

Private Function W006TerminateActiveWindowCaption() As String
    On Error GoTo Failed
    W006TerminateActiveWindowCaption = Application.ActiveWindow.Caption
    Exit Function
Failed:
    W006TerminateActiveWindowCaption = "<unavailable>"
End Function

Private Function W006TerminateOptionalText(Optional ByVal value As Variant) As String
    If IsMissing(value) Then
        W006TerminateOptionalText = ""
    Else
        W006TerminateOptionalText = W006TerminateScalarToText(value)
    End If
End Function

Private Function W006TerminateScalarToText(ByVal value As Variant) As String
    On Error GoTo Failed
    If IsObject(value) Then
        W006TerminateScalarToText = "<object>"
    ElseIf IsEmpty(value) Or IsNull(value) Then
        W006TerminateScalarToText = ""
    Else
        W006TerminateScalarToText = CStr(value)
    End If
    Exit Function
Failed:
    W006TerminateScalarToText = "<unavailable>"
End Function
