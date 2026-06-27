Option Explicit

' Standard module for the W006 held-reference residual oracle fixture. It owns the
' global held reference (gHeldRef), the log worksheet (sequence + held-reference
' state columns modeled on the terminate-lifetime fixture), the per-scenario flag
' setters the capture script calls before each scenario, the launcher show macro,
' the modeless-system-close start/finish/cleanup macros (modeless Show returns to
' COM so excel.Run is safe there), and the modal scenario runner invoked from the
' launcher button _Click handlers (where Show vbModal is event-driven and does NOT
' block the host COM thread).

Private Const W006_HELDREF_LOG_SHEET As String = "W006HeldRefResidualsLog"

Private gSequence As Long
Private gNextInstanceNumber As Long
Private gCurrentScenario As String
Private gCurrentShowMode As String
Private gCloseOrigin As String
Private gCurrentInstanceId As String
Private gLocalRefState As String
Private gHeldRefState As String
Private gDefaultInstanceState As String
Private gReleasePhase As String
Private gHeldRef As OxFormsW006HeldRefForm

Public Sub ClearW006HeldRefResidualsLog()
    Dim sheet As Worksheet

    gSequence = 0
    gNextInstanceNumber = 0
    gCurrentScenario = ""
    gCurrentShowMode = ""
    gCloseOrigin = ""
    gCurrentInstanceId = ""
    gLocalRefState = "none"
    gHeldRefState = "none"
    gDefaultInstanceState = "not_used"
    gReleasePhase = "none"
    Set gHeldRef = Nothing

    Set sheet = W006HeldRefGetOrCreateLogSheet()
    sheet.Cells.Clear
    W006HeldRefWriteLogHeaders sheet
End Sub

Public Sub ShowW006HeldRefLauncherModeless()
    W006HeldRefSetScenario "launcher_modeless", "modeless", ""
    OxFormsW006HeldRefLauncher.Tag = "form_identity=launcher;show_mode=modeless;scenario=launcher_modeless"
    OxFormsW006HeldRefLauncher.Show vbModeless
End Sub

' ---- per-scenario flag setters (capture script calls one before each scenario) ----

Public Sub SetW006HeldRefScenarioModalHideReturn()
    W006HeldRefSetScenario "modal_hide_return", "modal", "modal_hide_from_button"
End Sub

Public Sub SetW006HeldRefScenarioModalUnloadReturn()
    W006HeldRefSetScenario "modal_unload_return", "modal", "modal_unload_from_button"
End Sub

Public Sub SetW006HeldRefScenarioModelessSystemClose()
    W006HeldRefSetScenario "modeless_system_close", "modeless", "public_alt_f4"
End Sub

' ---- modeless system-close scenario (excel.Run safe: modeless Show returns) ----

Public Sub StartW006HeldRefModelessSystemCloseScenario()
    Dim f As OxFormsW006HeldRefForm

    W006HeldRefBeginScenario "modeless_system_close", "modeless", "public_alt_f4"
    Set f = W006HeldRefCreateScenarioForm("modeless_system_close", "modeless", "public_alt_f4")
    W006HeldRefAppendLog f, "fixture", "repo-owned VBA", "BeforeShowModeless", "fixture_action", "fixture action", actionName:="show_modeless", notes:="The global held reference is active before the modeless Show."
    f.Tag = "form_identity=held;show_mode=modeless;scenario=modeless_system_close;instance_id=" & gCurrentInstanceId
    f.Show vbModeless
    W006HeldRefAppendLog f, "fixture", "repo-owned VBA", "AfterShowModeless", "fixture_action", "fixture action", actionName:="show_modeless_return"

    ' Release the local reference so only the global held reference remains while
    ' the capture script sends a public system close to the held window.
    gReleasePhase = "local_ref_release_before_public_alt_f4"
    gLocalRefState = "releasing"
    Set f = Nothing
    gLocalRefState = "released"
    W006HeldRefAppendLog gHeldRef, "fixture", "repo-owned VBA", "ReadyForPublicSystemClose", "fixture_action", "fixture action", actionName:="await_public_alt_f4", closeOrigin:="public_alt_f4", notes:="Capture script sends public SendKeys Alt+F4 to the held window while only the global held reference remains in fixture state."
End Sub

Public Sub FinishW006HeldRefModelessSystemCloseScenario()
    W006HeldRefReleaseHeldReference "held_ref_release_after_public_alt_f4"
    W006HeldRefEndScenario "modeless_system_close"
End Sub

Public Sub CleanupW006HeldRefModelessSystemCloseScenario()
    ' Cleanup path only when the public close did not close the held window. Not
    ' used for parity claims; the residual is the held-reference state, not ordering.
    If gHeldRef Is Nothing Then
        W006HeldRefAppendLog Nothing, "fixture", "repo-owned VBA", "CleanupNoHeldReference", "fixture_action", "fixture action", actionName:="cleanup_no_held_ref"
        Exit Sub
    End If

    W006HeldRefAppendLog gHeldRef, "fixture", "repo-owned VBA", "BeforeCleanupUnload", "fixture_action", "fixture action", actionName:="cleanup_unload", notes:="Cleanup after a blocked public close attempt."
    Unload gHeldRef
    W006HeldRefAppendLog gHeldRef, "fixture", "repo-owned VBA", "AfterCleanupUnload", "fixture_action", "fixture action", actionName:="cleanup_unload_return"
End Sub

' ---- modal scenarios (entered ONLY from a launcher button _Click handler) ----

' Called from LauncherModal*Button_Click. Because it runs inside an MSForms event
' handler (not excel.Run), held.Show vbModal does not block the host COM thread:
' it returns to this Sub after injected input clicks the held Hide/Unload button.
' The global held-reference release happens here, after the modal returns.
Public Sub W006HeldRefRunModalHeldScenario(ByVal scenarioName As String, ByVal closeOrigin As String, ByVal returnKind As String)
    Dim f As OxFormsW006HeldRefForm

    W006HeldRefBeginScenario scenarioName, "modal", closeOrigin
    Set f = W006HeldRefCreateScenarioForm(scenarioName, "modal", closeOrigin)
    f.Tag = "form_identity=held;show_mode=modal;scenario=" & scenarioName & ";instance_id=" & gCurrentInstanceId
    W006HeldRefAppendLog f, "fixture", "repo-owned VBA", "BeforeShowModal", "fixture_action", "fixture action", actionName:="show_modal", closeOrigin:=closeOrigin, notes:="Calling held.Show vbModal from the launcher button Click handler; injected input will click the held " & returnKind & " button to return the modal."
    f.Show vbModal
    W006HeldRefAppendLog f, "fixture", "repo-owned VBA", "AfterShowModalReturn", "fixture_action", "fixture action", actionName:="modal_show_return", closeOrigin:=closeOrigin, notes:="Modal Show returned after the held " & returnKind & " path; the global held reference may still be active."

    gReleasePhase = "local_ref_release_after_" & returnKind & "_return"
    gLocalRefState = "releasing"
    Set f = Nothing
    gLocalRefState = "released"
    W006HeldRefAppendLog Nothing, "fixture", "repo-owned VBA", "AfterLocalReferenceRelease", "fixture_action", "fixture action", actionName:="release_local_ref", notes:="The global held reference remains active after the local reference release."
    W006HeldRefReleaseHeldReference "held_ref_release_after_" & returnKind & "_return"
    W006HeldRefEndScenario scenarioName
End Sub

' ---- shared helpers ----

Public Sub W006HeldRefReleaseHeldReference(ByVal releaseReason As String)
    If gHeldRef Is Nothing Then
        W006HeldRefAppendLog Nothing, "fixture", "repo-owned VBA", "NoHeldReferenceToRelease", "fixture_action", "fixture action", actionName:="release_held_ref", notes:="No global held reference existed when release was requested."
        gHeldRefState = "released"
        Exit Sub
    End If

    W006HeldRefAppendLog gHeldRef, "fixture", "repo-owned VBA", "BeforeHeldReferenceRelease", "fixture_action", "fixture action", actionName:="release_held_ref", notes:="About to set the global held reference to Nothing."
    gReleasePhase = releaseReason
    gHeldRefState = "releasing"
    Set gHeldRef = Nothing
    gHeldRefState = "released"
    W006HeldRefAppendLog Nothing, "fixture", "repo-owned VBA", "AfterHeldReferenceRelease", "fixture_action", "fixture action", actionName:="release_held_ref_return", notes:="VBA resumed after setting the global held reference to Nothing."
End Sub

Public Sub W006HeldRefSetCloseOrigin(ByVal closeOrigin As String)
    gCloseOrigin = closeOrigin
End Sub

Public Function W006HeldRefCurrentCloseOrigin() As String
    W006HeldRefCurrentCloseOrigin = gCloseOrigin
End Function

Private Sub W006HeldRefSetScenario(ByVal scenarioName As String, ByVal showMode As String, ByVal closeOrigin As String)
    gCurrentScenario = scenarioName
    gCurrentShowMode = showMode
    gCloseOrigin = closeOrigin
End Sub

Private Sub W006HeldRefBeginScenario(ByVal scenarioName As String, ByVal showMode As String, ByVal closeOrigin As String)
    gCurrentScenario = scenarioName
    gCurrentShowMode = showMode
    gCloseOrigin = closeOrigin
    gCurrentInstanceId = ""
    gLocalRefState = "none"
    gHeldRefState = "none"
    gDefaultInstanceState = "not_used"
    gReleasePhase = "none"
    Set gHeldRef = Nothing
    W006HeldRefAppendLog Nothing, "fixture", "repo-owned VBA", "ScenarioStart", "fixture_action", "fixture action", actionName:="scenario_start", closeOrigin:=closeOrigin
End Sub

Private Function W006HeldRefCreateScenarioForm(ByVal scenarioName As String, ByVal showMode As String, ByVal closeOrigin As String) As OxFormsW006HeldRefForm
    Dim f As OxFormsW006HeldRefForm

    gCurrentScenario = scenarioName
    gCurrentShowMode = showMode
    gCloseOrigin = closeOrigin
    gDefaultInstanceState = "not_used"
    gReleasePhase = "create_instance"
    gLocalRefState = "creating"
    gHeldRefState = "not_set"
    gNextInstanceNumber = gNextInstanceNumber + 1
    gCurrentInstanceId = "instance-" & Format$(gNextInstanceNumber, "000")

    Set f = New OxFormsW006HeldRefForm
    f.Tag = "instance_id=" & gCurrentInstanceId & ";scenario=" & scenarioName & ";show_mode=" & showMode
    gLocalRefState = "held"
    Set gHeldRef = f
    gHeldRefState = "held"

    W006HeldRefAppendLog f, "fixture", "repo-owned VBA", "AfterCreateInstance", "fixture_action", "fixture action", actionName:="create_instance", closeOrigin:=closeOrigin, notes:="New instance is held in both the local reference and the global held reference."
    Set W006HeldRefCreateScenarioForm = f
End Function

Private Sub W006HeldRefEndScenario(ByVal scenarioName As String)
    gReleasePhase = "scenario_end"
    W006HeldRefAppendLog Nothing, "fixture", "repo-owned VBA", "ScenarioEnd", "fixture_action", "fixture action", actionName:="scenario_end", notes:="Scenario ended after the explicit held-reference release sequence."
End Sub

Public Function W006HeldRefAppendLog(ByVal formObj As Object, ByVal formIdentity As String, ByVal targetName As String, ByVal targetKind As String, ByVal eventName As String, ByVal rowKind As String, ByVal argumentSummary As String, Optional ByVal handlerName As String = "", Optional ByVal actionName As String = "", Optional ByVal closeOrigin As String = "", Optional ByVal cancelBefore As Variant, Optional ByVal cancelAfter As Variant, Optional ByVal closeMode As Variant, Optional ByVal notes As String = "") As Long
    Dim sheet As Worksheet
    Dim nextRow As Long
    Dim instanceId As String
    Dim scenarioText As String
    Dim showModeText As String
    Dim originText As String

    Set sheet = W006HeldRefGetOrCreateLogSheet()
    gSequence = gSequence + 1
    nextRow = sheet.Cells(sheet.Rows.Count, 1).End(xlUp).Row + 1

    instanceId = W006HeldRefEffectiveTagPart(formObj, "instance_id", gCurrentInstanceId)
    scenarioText = W006HeldRefEffectiveTagPart(formObj, "scenario", gCurrentScenario)
    showModeText = W006HeldRefEffectiveTagPart(formObj, "show_mode", gCurrentShowMode)
    If Len(closeOrigin) > 0 Then
        originText = closeOrigin
    Else
        originText = gCloseOrigin
    End If

    sheet.Cells(nextRow, 1).Value = gSequence
    sheet.Cells(nextRow, 2).Value = gSequence
    sheet.Cells(nextRow, 3).Value = scenarioText
    sheet.Cells(nextRow, 4).Value = instanceId
    sheet.Cells(nextRow, 5).Value = showModeText
    sheet.Cells(nextRow, 6).Value = rowKind
    sheet.Cells(nextRow, 7).Value = formIdentity
    sheet.Cells(nextRow, 8).Value = targetName
    sheet.Cells(nextRow, 9).Value = targetKind
    sheet.Cells(nextRow, 10).Value = eventName
    sheet.Cells(nextRow, 11).Value = argumentSummary
    sheet.Cells(nextRow, 12).Value = handlerName
    sheet.Cells(nextRow, 13).Value = actionName
    sheet.Cells(nextRow, 14).Value = originText
    sheet.Cells(nextRow, 15).Value = W006HeldRefOptionalText(cancelBefore)
    sheet.Cells(nextRow, 16).Value = W006HeldRefOptionalText(cancelAfter)
    sheet.Cells(nextRow, 17).Value = W006HeldRefOptionalText(closeMode)
    sheet.Cells(nextRow, 18).Value = gLocalRefState
    sheet.Cells(nextRow, 19).Value = gHeldRefState
    sheet.Cells(nextRow, 20).Value = gDefaultInstanceState
    sheet.Cells(nextRow, 21).Value = gReleasePhase
    sheet.Cells(nextRow, 22).Value = W006HeldRefSafeFormProperty(formObj, "Visible")
    sheet.Cells(nextRow, 23).Value = W006HeldRefActiveControlName(formObj)
    sheet.Cells(nextRow, 24).Value = W006HeldRefActiveWindowCaption()
    sheet.Cells(nextRow, 25).Value = notes
    sheet.Cells(nextRow, 26).Value = Now

    W006HeldRefAppendLog = gSequence
End Function

Private Function W006HeldRefGetOrCreateLogSheet() As Worksheet
    On Error Resume Next
    Set W006HeldRefGetOrCreateLogSheet = ThisWorkbook.Worksheets(W006_HELDREF_LOG_SHEET)
    On Error GoTo 0

    If W006HeldRefGetOrCreateLogSheet Is Nothing Then
        Set W006HeldRefGetOrCreateLogSheet = ThisWorkbook.Worksheets.Add
        W006HeldRefGetOrCreateLogSheet.Name = W006_HELDREF_LOG_SHEET
    End If

    If CStr(W006HeldRefGetOrCreateLogSheet.Cells(1, 1).Value) <> "sequence" Then
        W006HeldRefWriteLogHeaders W006HeldRefGetOrCreateLogSheet
    End If
End Function

Private Sub W006HeldRefWriteLogHeaders(ByVal sheet As Worksheet)
    sheet.Cells(1, 1).Value = "sequence"
    sheet.Cells(1, 2).Value = "logical_tick"
    sheet.Cells(1, 3).Value = "scenario"
    sheet.Cells(1, 4).Value = "instance_id"
    sheet.Cells(1, 5).Value = "show_mode"
    sheet.Cells(1, 6).Value = "row_kind"
    sheet.Cells(1, 7).Value = "form_identity"
    sheet.Cells(1, 8).Value = "target_name"
    sheet.Cells(1, 9).Value = "target_kind"
    sheet.Cells(1, 10).Value = "event_name"
    sheet.Cells(1, 11).Value = "argument_summary"
    sheet.Cells(1, 12).Value = "handler_name"
    sheet.Cells(1, 13).Value = "action"
    sheet.Cells(1, 14).Value = "close_origin"
    sheet.Cells(1, 15).Value = "cancel_before"
    sheet.Cells(1, 16).Value = "cancel_after"
    sheet.Cells(1, 17).Value = "close_mode"
    sheet.Cells(1, 18).Value = "local_ref_state"
    sheet.Cells(1, 19).Value = "held_ref_state"
    sheet.Cells(1, 20).Value = "default_instance_state"
    sheet.Cells(1, 21).Value = "release_phase"
    sheet.Cells(1, 22).Value = "form_visible"
    sheet.Cells(1, 23).Value = "active_control"
    sheet.Cells(1, 24).Value = "active_window_caption"
    sheet.Cells(1, 25).Value = "notes"
    sheet.Cells(1, 26).Value = "wall_clock_local"
End Sub

Private Function W006HeldRefEffectiveTagPart(ByVal formObj As Object, ByVal key As String, ByVal defaultValue As String) As String
    If formObj Is Nothing Then
        W006HeldRefEffectiveTagPart = defaultValue
    Else
        W006HeldRefEffectiveTagPart = W006HeldRefTagPart(formObj, key, defaultValue)
    End If
End Function

Private Function W006HeldRefTagPart(ByVal formObj As Object, ByVal key As String, ByVal defaultValue As String) As String
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
            W006HeldRefTagPart = Mid$(CStr(part), Len(prefix) + 1)
            Exit Function
        End If
    Next
Failed:
    W006HeldRefTagPart = defaultValue
End Function

Private Function W006HeldRefSafeFormProperty(ByVal formObj As Object, ByVal propertyName As String) As String
    If formObj Is Nothing Then
        W006HeldRefSafeFormProperty = "<no form object>"
        Exit Function
    End If

    On Error GoTo Failed
    W006HeldRefSafeFormProperty = CStr(CallByName(formObj, propertyName, VbGet))
    Exit Function
Failed:
    W006HeldRefSafeFormProperty = "<unavailable>"
End Function

Private Function W006HeldRefActiveControlName(ByVal formObj As Object) As String
    If formObj Is Nothing Then
        W006HeldRefActiveControlName = "<no form object>"
        Exit Function
    End If

    On Error GoTo Failed
    W006HeldRefActiveControlName = formObj.ActiveControl.Name
    Exit Function
Failed:
    W006HeldRefActiveControlName = "<none>"
End Function

Private Function W006HeldRefActiveWindowCaption() As String
    On Error GoTo Failed
    W006HeldRefActiveWindowCaption = Application.ActiveWindow.Caption
    Exit Function
Failed:
    W006HeldRefActiveWindowCaption = "<unavailable>"
End Function

Private Function W006HeldRefOptionalText(Optional ByVal value As Variant) As String
    If IsMissing(value) Then
        W006HeldRefOptionalText = ""
    Else
        W006HeldRefOptionalText = W006HeldRefScalarToText(value)
    End If
End Function

Private Function W006HeldRefScalarToText(ByVal value As Variant) As String
    On Error GoTo Failed
    If IsObject(value) Then
        W006HeldRefScalarToText = "<object>"
    ElseIf IsEmpty(value) Or IsNull(value) Then
        W006HeldRefScalarToText = ""
    Else
        W006HeldRefScalarToText = CStr(value)
    End If
    Exit Function
Failed:
    W006HeldRefScalarToText = "<unavailable>"
End Function
