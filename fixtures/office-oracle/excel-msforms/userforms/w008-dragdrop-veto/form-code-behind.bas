Option Explicit

' W008 drag-drop veto oracle UserForm code-behind (oxforms-4f8).
'
' Load-bearing question: esq.17 proved a vetoing BeforeDropOrPaste (Cancel = True) suppresses a
' KEYBOARD Ctrl+V paste, and OxForms honors it via a two-stage paste; the DRAG-DROP origin still
' inserts synchronously (veto recorded-not-honored). Does a vetoing BeforeDropOrPaste suppress a
' DRAG-DROP drop the same way a keyboard paste? And what Action value does a drag-drop carry (vs
' Action=2 for a keyboard paste)?
'
' SourceBox holds draggable seed text (DragBehavior enabled at runtime). The capture selects the
' SourceBox text and drags it onto TargetBox. Each handler logs one W008DragDropVetoLog row via
' W008DdvLog(control, event, argName, argBefore, argAfter, focusOwnerAfter, valueAfter, notes).
' For the Return* helper args argBefore/argAfter are .Value at handler entry/exit, so the Cancel
' veto mutation (False -> True) is observable. valueAfter is TargetBox.Value read at handler
' entry, so a suppressed drop shows the value did NOT change. The BeforeDropOrPaste veto is gated
' on the Public gVetoDrop flag (set by SetW008ScenarioDragDropVeto). No OxForms runtime behaviour
' is implied.

Private Function FocusOwnerName() As String
    If Me.ActiveControl Is Nothing Then
        FocusOwnerName = ""
    Else
        FocusOwnerName = Me.ActiveControl.Name
    End If
End Function

Private Sub UserForm_Initialize()
    ' Seed + enable dragging at RUNTIME (never as a design-time fixture property). DragBehavior
    ' = fmDragBehaviorEnabled (1) lets the SourceBox selection be dragged; EnterFieldBehavior =
    ' fmEnterFieldBehaviorRecallSelection (1) keeps a recalled selection so a re-focus before the
    ' drag does not collapse it.
    SourceBox.Text = "OxFormsDragSeed"
    SourceBox.DragBehavior = fmDragBehaviorEnabled
    SourceBox.EnterFieldBehavior = fmEnterFieldBehaviorRecallSelection
    W008DdvLog "SourceBox", "Initialize", "", "", "", FocusOwnerName(), CStr(TargetBox.Value), "form initialize"
End Sub

' ---- SourceBox (drag source) ----

Private Sub SourceBox_Enter()
    W008DdvLog "SourceBox", "Enter", "", "", "", FocusOwnerName(), CStr(TargetBox.Value), ""
End Sub

Private Sub SourceBox_Change()
    W008DdvLog "SourceBox", "Change", "", "", "", FocusOwnerName(), CStr(SourceBox.Value), "SourceBox value=" & CStr(SourceBox.Value)
End Sub

Private Sub SourceBox_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    W008DdvLog "SourceBox", "MouseDown", "Button", CStr(Button), CStr(Button), FocusOwnerName(), CStr(TargetBox.Value), "drag origin; Shift=" & CStr(Shift)
End Sub

' ---- TargetBox (drop target) ----

Private Sub TargetBox_Enter()
    W008DdvLog "TargetBox", "Enter", "", "", "", FocusOwnerName(), CStr(TargetBox.Value), ""
End Sub

' Plain TextBox (MdcTextEvents): BeforeDropOrPaste has NO leading Index argument; the public
' order is Cancel, Action, Data, X, Y, Effect, Shift (matches the committed paste-veto fixture).
' When gVetoDrop is armed the handler sets Cancel.Value = True so the capture records whether the
' drop is suppressed.
Private Sub TargetBox_BeforeDropOrPaste( _
        ByVal Cancel As MSForms.ReturnBoolean, _
        ByVal Action As MSForms.fmAction, _
        ByVal Data As MSForms.DataObject, _
        ByVal X As Single, _
        ByVal Y As Single, _
        ByVal Effect As MSForms.ReturnEffect, _
        ByVal Shift As Integer)
    Dim cancelBefore As String
    cancelBefore = ReturnHelperValueText(Cancel)
    If gVetoDrop Then
        Cancel.Value = True
    End If
    W008DdvLog "TargetBox", "BeforeDropOrPaste", "Cancel", cancelBefore, ReturnHelperValueText(Cancel), _
        FocusOwnerName(), CStr(TargetBox.Value), _
        "Action=" & CStr(Action) & "; Effect=" & ReturnHelperValueText(Effect) & "; X=" & CStr(X) & _
        "; Y=" & CStr(Y) & "; Shift=" & CStr(Shift) & "; " & DataObjectObservationText(Data)
End Sub

Private Sub TargetBox_Change()
    W008DdvLog "TargetBox", "Change", "", "", "", FocusOwnerName(), CStr(TargetBox.Value), "Change handler; .Value read at handler entry"
End Sub

Private Function ReturnHelperValueText(ByVal helper As Object) As String
    On Error GoTo Failed
    ReturnHelperValueText = CStr(helper.Value)
    Exit Function
Failed:
    ReturnHelperValueText = "<unavailable>"
End Function

Private Function DataObjectObservationText(ByVal Data As MSForms.DataObject) As String
    On Error GoTo Failed
    If Data Is Nothing Then
        DataObjectObservationText = "data_object=nothing"
        Exit Function
    End If
    DataObjectObservationText = "data_object=present; public_getformat_1=" & CStr(Data.GetFormat(1))
    Exit Function
Failed:
    DataObjectObservationText = "data_object_observation_error=" & Err.Number & ":" & Err.Description
End Function
