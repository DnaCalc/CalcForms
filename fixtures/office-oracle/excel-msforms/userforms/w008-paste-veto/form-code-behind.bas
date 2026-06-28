Option Explicit

' W008 paste-veto oracle UserForm code-behind (esq.17).
'
' Load-bearing question: does a VETOING BeforeDropOrPaste (Cancel = True) SUPPRESS a
' keyboard Ctrl+V paste -- i.e. no Change fires and TextBox1.Value stays unchanged --
' versus a non-vetoing paste which inserts the clipboard text (Change fires)? The
' committed ctrlv-keyboard-ordering capture only recorded a NON-vetoing paste, so the
' veto EFFECT is uncaptured; this fixture arms the veto so the capture can settle it.
'
' TextBox1 fills the form so a single window-centre click focuses it. The capture seeds
' the public Windows clipboard with a repo-owned text value, then sends Ctrl+V. Each
' handler logs one W008PasteVetoLog row via W008PvLog(control, event, argName,
' argBefore, argAfter, focusOwnerAfter, valueAfter, notes). For Return* helper args
' argBefore/argAfter are .Value at handler entry/exit, so the Cancel veto mutation
' (False -> True) is observable. valueAfter is TextBox1.Value read at handler entry, so
' a suppressed paste shows the value did NOT change. The BeforeDropOrPaste veto is gated
' on the Public gVetoPaste flag (set by SetW008ScenarioPasteVeto). No OxForms runtime
' behaviour is implied.

Private Function FocusOwnerName() As String
    If Me.ActiveControl Is Nothing Then
        FocusOwnerName = ""
    Else
        FocusOwnerName = Me.ActiveControl.Name
    End If
End Function

Private Sub UserForm_Initialize()
    W008PvLog "TextBox1", "Initialize", "", "", "", FocusOwnerName(), CStr(TextBox1.Value), "form initialize"
End Sub

Private Sub TextBox1_Enter()
    W008PvLog "TextBox1", "Enter", "", "", "", FocusOwnerName(), CStr(TextBox1.Value), ""
End Sub

Private Sub TextBox1_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    Dim before As String
    before = ReturnHelperValueText(KeyCode)
    W008PvLog "TextBox1", "KeyDown", "KeyCode", before, ReturnHelperValueText(KeyCode), _
        FocusOwnerName(), CStr(TextBox1.Value), "Shift=" & CStr(Shift)
End Sub

Private Sub TextBox1_KeyPress(ByVal KeyAscii As MSForms.ReturnInteger)
    Dim before As String
    before = ReturnHelperValueText(KeyAscii)
    W008PvLog "TextBox1", "KeyPress", "KeyAscii", before, ReturnHelperValueText(KeyAscii), _
        FocusOwnerName(), CStr(TextBox1.Value), ""
End Sub

Private Sub TextBox1_KeyUp(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    Dim before As String
    before = ReturnHelperValueText(KeyCode)
    W008PvLog "TextBox1", "KeyUp", "KeyCode", before, ReturnHelperValueText(KeyCode), _
        FocusOwnerName(), CStr(TextBox1.Value), "Shift=" & CStr(Shift)
End Sub

' Plain TextBox (MdcTextEvents): BeforeDropOrPaste has NO leading Index argument; the
' public order is Cancel, Action, Data, X, Y, Effect, Shift (matches the committed
' ctrlv-keyboard-ordering fixture). When gVetoPaste is armed the handler sets
' Cancel.Value = True so the capture records whether the paste is suppressed.
Private Sub TextBox1_BeforeDropOrPaste( _
        ByVal Cancel As MSForms.ReturnBoolean, _
        ByVal Action As MSForms.fmAction, _
        ByVal Data As MSForms.DataObject, _
        ByVal X As Single, _
        ByVal Y As Single, _
        ByVal Effect As MSForms.ReturnEffect, _
        ByVal Shift As Integer)
    Dim cancelBefore As String
    cancelBefore = ReturnHelperValueText(Cancel)
    If gVetoPaste Then
        Cancel.Value = True
    End If
    W008PvLog "TextBox1", "BeforeDropOrPaste", "Cancel", cancelBefore, ReturnHelperValueText(Cancel), _
        FocusOwnerName(), CStr(TextBox1.Value), _
        "Action=" & CStr(Action) & "; Effect=" & ReturnHelperValueText(Effect) & "; X=" & CStr(X) & _
        "; Y=" & CStr(Y) & "; Shift=" & CStr(Shift) & "; " & DataObjectObservationText(Data)
End Sub

Private Sub TextBox1_Change()
    W008PvLog "TextBox1", "Change", "", "", "", FocusOwnerName(), CStr(TextBox1.Value), "Change handler; .Value read at handler entry"
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
