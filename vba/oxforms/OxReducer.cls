Option Explicit

' The OxForms interaction reducer: the control behavior the Rust crate oxforms-core's
' reduce() used to own, now in VBA (memory oxforms-reducer-home-decision; design in
' docs/specs/MESSAGE_HANDLING_AND_UPDATE_FLOW.md). It owns the form-level interaction state
' (mouse capture + the armed pressed control), routes a normalized pointer event over the
' form's controls by pure geometry (HitTest), and lets each control raise its own ordered
' FM20 events through the IOxControl input surface (OnMouseDown/OnMouseUp/OnClick). No Rust
' reducer is in the loop.
'
' Scope so far (epic oxforms-ih6):
'   ih6.1 -- CommandButton mouse activation (MouseDown -> capture+press -> MouseUp -> Click);
'   ih6.2 -- CheckBox mouse toggle (via the control's OnClick);
'   ih6.3 -- focus + keyboard routing: a focusable control gains focus on mouse-down BEFORE the
'            MouseDown (synchronous two-stage focus-out validation reproduces the oracle order
'            Exit/Enter/MouseDown, or BeforeUpdate/AfterUpdate/Exit/Enter/MouseDown when dirty,
'            with no fold-back); KeyDown/KeyUp/character input route to the focused control.
' Still to land: Tab navigation, default/cancel buttons, accelerators, the keyboard
' swallow->character linkage, caret/selection edit keys, clipboard + drag-drop paste,
' lifecycle + QueryClose.

' MSForms Button arg: the left mouse button.
Private Const OX_BUTTON_LEFT As Integer = 1
' Virtual key codes the reducer routes specially.
Private Const OX_KEY_TAB As Integer = 9
Private Const OX_KEY_ENTER As Integer = 13
Private Const OX_KEY_ESCAPE As Integer = 27
Private Const OX_KEY_V As Integer = 86
' MSForms Shift-arg bitmask: 1 = Shift, 2 = Ctrl, 4 = Alt.
Private Const OX_SHIFT_CTRL As Integer = 2
Private Const OX_SHIFT_ALT As Integer = 4
' fmAction: 2 = paste (the Action arg of BeforeDropOrPaste).
Private Const OX_ACTION_PASTE As Integer = 2

Private mForm As UserForm
Private mCaptureName As String    ' control holding the mouse capture ("" = none)
Private mPressedName As String    ' control whose pressed visual is armed ("" = none)
Private mFocusName As String      ' the focused control ("" = form / no control focused)
Private mSwallowNextChar As Boolean ' a swallowed KeyDown suppresses the following character
Private mClipboardText As String  ' the current clipboard text (the host pushes it; "" = empty)
Private mDpiX As Long
Private mDpiY As Long
Private mEffects As String        ' ordered '|'-joined effect log for the current Dispatch

Public Sub Init(ByVal Form As UserForm)
    Set mForm = Form
    mCaptureName = ""
    mPressedName = ""
    mFocusName = ""
    mSwallowNextChar = False
    mClipboardText = ""
    mDpiX = 96
    mDpiY = 96
End Sub

' The host pushes the current clipboard text before dispatching a Ctrl+V (the live OS clipboard
' read is the host's job; the reducer treats it as already-resolved text). "" = empty clipboard.
Public Sub SetClipboardText(ByVal Text As String)
    mClipboardText = Text
End Sub

' The currently focused control's name ("" = none). Test/diagnostic surface.
Public Property Get FocusName() As String
    FocusName = mFocusName
End Property

' THE VBA REDUCE for pointer input. Kind is "mousedown" | "mouseup" (others ignored in
' increment 1). X/Y are form-logical points; Button/Shift are the MSForms scalar args. Routes
' geometrically, mutates interaction state, raises the control's FM20 events in order, and
' repaints. Returns the ordered effect log: a '|'-joined sequence such as
'   "mousedown:Btn1|press:Btn1|repaint"  then  "mouseup:Btn1|click:Btn1|release:Btn1|repaint".
Public Function Dispatch( _
        ByVal Kind As String, ByVal X As Long, ByVal Y As Long, _
        ByVal Button As Integer, ByVal Shift As Integer) As String
    mEffects = ""
    Select Case Kind
        Case "mousedown"
            ReduceMouseDown X, Y, Button, Shift
        Case "mouseup"
            ReduceMouseUp X, Y, Button, Shift
    End Select
    Dispatch = mEffects
End Function

Private Sub ReduceMouseDown(ByVal X As Long, ByVal Y As Long, ByVal Button As Integer, ByVal Shift As Integer)
    If Button <> OX_BUTTON_LEFT Then Exit Sub

    Dim Hit As IOxControl
    Set Hit = HitTest(X, Y)
    If Hit Is Nothing Then Exit Sub

    ' Focus moves to a focusable control BEFORE the MouseDown fires. Running the focus-out
    ' validation synchronously here reproduces the oracle order (Exit -> Enter -> MouseDown, or
    ' BeforeUpdate -> AfterUpdate -> Exit -> Enter -> MouseDown when the losing control is dirty)
    ' with no fold-back. If validation vetoes, the click is absorbed: focus stays and no MouseDown
    ' fires (oracle "veto absorbs the deferred press").
    If Hit.Core.Focusable And Hit.Core.Name <> mFocusName Then
        If Not TransferFocusTo(Hit.Core.Name) Then
            Repaint
            Exit Sub
        End If
    End If

    Hit.OnMouseDown Button, Shift, CSng(X - Hit.Core.Left), CSng(Y - Hit.Core.Top)
    Emit "mousedown:" & Hit.Core.Name

    ' Any press on a control takes the mouse capture (matches the oracle apply_mouse_press,
    ' which captures unconditionally): a later up/drag routes back to this control even if the
    ' pointer drifts off it. Capture, not the pressed visual, is what gates the eventual Click.
    mCaptureName = Hit.Core.Name

    ' Controls with a pressed visual (CommandButton/CheckBox) also arm it until the matching up.
    If Hit.HasPressedVisual Then
        mPressedName = Hit.Core.Name
        Hit.Core.Pressed = True
        Emit "press:" & Hit.Core.Name
        Repaint
    End If
End Sub

Private Sub ReduceMouseUp(ByVal X As Long, ByVal Y As Long, ByVal Button As Integer, ByVal Shift As Integer)
    If Button <> OX_BUTTON_LEFT Then Exit Sub

    ' A capture (set on the press) routes the up to the originating control even if the pointer
    ' drifted out; otherwise hit-test where the up landed.
    Dim Target As IOxControl
    If Len(mCaptureName) > 0 Then
        Set Target = mForm.ControlByName(mCaptureName)
    Else
        Set Target = HitTest(X, Y)
    End If
    If Target Is Nothing Then Exit Sub

    Target.OnMouseUp Button, Shift, CSng(X - Target.Core.Left), CSng(Y - Target.Core.Top)
    Emit "mouseup:" & Target.Core.Name

    ' Click fires only when the release lands inside the SAME control that took the capture and
    ' that control fires Click (oracle reduce_mouse_up: gated on the captured target, not the
    ' pressed visual). Decide before clearing capture.
    Dim FireClick As Boolean
    FireClick = (Len(mCaptureName) > 0) And (mCaptureName = Target.Core.Name) _
        And ContainsPoint(Target, X, Y) And Target.SupportsClick
    mCaptureName = ""

    ' MSForms order (oracle-backed oxforms-core reduce_mouse_up): MouseUp -> Click -> release
    ' the pressed visual -> repaint. Click fires before the visual pops up.
    If FireClick Then
        Target.OnClick
        Emit "click:" & Target.Core.Name
    End If

    ReleasePressed
    Repaint
End Sub

' THE VBA REDUCE for keyboard input, routed to the focused control. Kind is "keydown" |
' "keyup". Returns the ordered effect log. (Tab navigation, default/cancel buttons, accelerators
' and the swallow->character linkage land in later increments; this routes a key to the focused
' control so it raises KeyDown/KeyUp and performs its default key behavior.)
Public Function DispatchKey(ByVal Kind As String, ByVal KeyCode As Integer, ByVal Shift As Integer) As String
    mEffects = ""
    Select Case Kind
        Case "keydown"
            ReduceKeyDown KeyCode, Shift
        Case "keyup"
            If Len(mFocusName) > 0 Then
                mForm.ControlByName(mFocusName).OnKeyUp KeyCode, Shift
                Emit "keyup:" & mFocusName
            End If
    End Select
    DispatchKey = mEffects
End Function

Private Sub ReduceKeyDown(ByVal KeyCode As Integer, ByVal Shift As Integer)
    If Len(mFocusName) = 0 Then
        ' No control focused: a Tab moves focus to the first/last control in tab order.
        If KeyCode = OX_KEY_TAB Then FocusFirstTab Shift
        Exit Sub
    End If

    Dim Focused As IOxControl
    Set Focused = mForm.ControlByName(mFocusName)

    ' The focused control gets first refusal on Space/Enter: a CheckBox toggles (Change/Click)
    ' BEFORE the KeyDown event -- value-first, the oracle keyboard order. If it self-activates,
    ' raise KeyDown afterwards and stop (no default-button / navigation handling).
    If Focused.TryKeyboardActivate(KeyCode, Shift, Len(DefaultButtonName()) > 0) Then
        Emit "activate:" & mFocusName
        Focused.OnKeyDown KeyCode, Shift
        Emit "keydown:" & mFocusName
        Exit Sub
    End If

    Dim Post As Integer
    Post = Focused.OnKeyDown(KeyCode, Shift)
    Emit "keydown:" & mFocusName

    ' Swallow linkage: a KeyDown handler that zeroed the key code suppresses the character that
    ' would otherwise follow (consumed by the next DispatchChar). A swallowed key also performs
    ' no navigation/activation.
    mSwallowNextChar = (Post = 0)
    If Post = 0 Then Exit Sub

    ' After the KeyDown fired (oracle order KeyDown -> [validation/activation]): Tab navigation,
    ' Alt+accelerator, Enter -> default button, Escape -> cancel button.
    If KeyCode = OX_KEY_TAB Then
        Dim NextName As String
        NextName = TabTarget(mFocusName, Shift)
        If Len(NextName) > 0 Then TransferFocusTo NextName
    ElseIf (Shift And OX_SHIFT_CTRL) <> 0 And KeyCode = OX_KEY_V Then
        ' Ctrl+V: paste the host clipboard text into the focused control (BeforeDropOrPaste ->
        ' Change), AFTER the V KeyDown fired. Empty clipboard is a no-op. No KeyPress for Ctrl+V.
        If Len(mClipboardText) > 0 Then
            Focused.OnPaste mClipboardText, OX_ACTION_PASTE, Shift
            Emit "paste:" & mFocusName
        End If
    ElseIf (Shift And OX_SHIFT_ALT) <> 0 Then
        ActivateAccelerator KeyCode
    ElseIf KeyCode = OX_KEY_ENTER And Shift = 0 Then
        ActivateDefaultButton
    ElseIf KeyCode = OX_KEY_ESCAPE And Shift = 0 Then
        ActivateCancelButton
    End If
End Sub

' THE VBA REDUCE for a drag-drop text drop, routed to the focused control: BeforeDropOrPaste ->
' (if not vetoed) insert + Change -- the same paste path as Ctrl+V, different origin. Returns the
' ordered effect log.
Public Function DispatchDrop(ByVal Text As String) As String
    mEffects = ""
    If Len(mFocusName) > 0 And Len(Text) > 0 Then
        mForm.ControlByName(mFocusName).OnPaste Text, OX_ACTION_PASTE, 0
        Emit "drop:" & mFocusName
        Repaint
    End If
    DispatchDrop = mEffects
End Function

' The visible+enabled form default button's name ("" if none).
Private Function DefaultButtonName() As String
    Dim I As Long, Ctl As IOxControl
    For I = 1 To mForm.Controls.Count
        Set Ctl = mForm.Controls.Item(I)
        If Ctl.IsDefault And Ctl.Core.Visible And Ctl.Core.Enabled Then
            DefaultButtonName = Ctl.Core.Name
            Exit Function
        End If
    Next I
End Function

' The visible+enabled form cancel button's name ("" if none).
Private Function CancelButtonName() As String
    Dim I As Long, Ctl As IOxControl
    For I = 1 To mForm.Controls.Count
        Set Ctl = mForm.Controls.Item(I)
        If Ctl.IsCancel And Ctl.Core.Visible And Ctl.Core.Enabled Then
            CancelButtonName = Ctl.Core.Name
            Exit Function
        End If
    Next I
End Function

' Enter on a control that did not consume it activates the default button: move focus to it
' (validation runs on the loser) then fire its Click. A validation veto absorbs the activation.
Private Sub ActivateDefaultButton()
    Dim Name As String
    Name = DefaultButtonName()
    If Len(Name) = 0 Then Exit Sub
    If Name <> mFocusName Then
        If Not TransferFocusTo(Name) Then Exit Sub
    End If
    mForm.ControlByName(Name).OnClick
    Emit "click:" & Name
End Sub

' Escape fires the cancel button's Click in place (no focus change), matching the oracle.
Private Sub ActivateCancelButton()
    Dim Name As String
    Name = CancelButtonName()
    If Len(Name) = 0 Then Exit Sub
    mForm.ControlByName(Name).OnClick
    Emit "click:" & Name
End Sub

' Alt+letter focuses then clicks the CommandButton whose caption mnemonic matches.
Private Sub ActivateAccelerator(ByVal KeyCode As Integer)
    Dim Want As String
    Want = UCase$(Chr$(KeyCode))
    If Len(Want) = 0 Then Exit Sub

    Dim I As Long, Ctl As IOxControl, Name As String
    For I = 1 To mForm.Controls.Count
        Set Ctl = mForm.Controls.Item(I)
        If Ctl.Core.Visible And Ctl.Core.Enabled And Ctl.AcceleratorKey = Want Then
            Name = Ctl.Core.Name
            Exit For
        End If
    Next I
    If Len(Name) = 0 Then Exit Sub

    If Name <> mFocusName Then
        If Not TransferFocusTo(Name) Then Exit Sub
    End If
    mForm.ControlByName(Name).OnClick
    Emit "click:" & Name
End Sub

' THE VBA REDUCE for character input, routed to the focused control: it raises KeyPress and (a
' TextBox) inserts the text + raises Change. A character whose KeyDown was swallowed is dropped
' (no KeyPress, no Change), matching the oracle swallow linkage. Returns the ordered effect log.
Public Function DispatchChar(ByVal Text As String) As String
    mEffects = ""
    If mSwallowNextChar Then
        mSwallowNextChar = False
        Emit "char-swallowed"
        DispatchChar = mEffects
        Exit Function
    End If
    If Len(mFocusName) > 0 Then
        mForm.ControlByName(mFocusName).OnCharacterInput Text
        Emit "char:" & mFocusName
        Repaint
    End If
    DispatchChar = mEffects
End Function

' Whether a control takes part in Tab navigation: focusable, a tab stop, visible and enabled
' (ports oxforms-core participates_in_tab_order).
Private Function Participates(ByVal Control As IOxControl) As Boolean
    Dim C As OxControlCore
    Set C = Control.Core
    Participates = C.Focusable And C.TabStop And C.Visible And C.Enabled
End Function

' A sortable tab key: TabIndex first, then declaration (add) order as the tie-break -- the same
' (tab_index, index) ordering the kernel's next_tab_focus_target uses.
Private Function TabKey(ByVal Control As IOxControl, ByVal DeclIndex As Long) As Long
    TabKey = Control.Core.TabIndex * 100000 + DeclIndex
End Function

' The next (or, with Shift, previous) participating control in tab order after CurrentName,
' wrapping around. Returns "" if there is no other participating control.
Private Function TabTarget(ByVal CurrentName As String, ByVal Shift As Boolean) As String
    Dim CurKey As Long, HaveCur As Boolean
    Dim I As Long, Ctl As IOxControl
    For I = 1 To mForm.Controls.Count
        Set Ctl = mForm.Controls.Item(I)
        If Ctl.Core.Name = CurrentName Then
            CurKey = TabKey(Ctl, I - 1)
            HaveCur = True
            Exit For
        End If
    Next I
    If Not HaveCur Then Exit Function

    Dim BestName As String, BestKey As Long, HaveBest As Boolean
    Dim WrapName As String, WrapKey As Long, HaveWrap As Boolean
    For I = 1 To mForm.Controls.Count
        Set Ctl = mForm.Controls.Item(I)
        If Participates(Ctl) And Ctl.Core.Name <> CurrentName Then
            Dim K As Long
            K = TabKey(Ctl, I - 1)
            If Not Shift Then
                If K > CurKey Then
                    If Not HaveBest Or K < BestKey Then BestName = Ctl.Core.Name: BestKey = K: HaveBest = True
                End If
                If Not HaveWrap Or K < WrapKey Then WrapName = Ctl.Core.Name: WrapKey = K: HaveWrap = True
            Else
                If K < CurKey Then
                    If Not HaveBest Or K > BestKey Then BestName = Ctl.Core.Name: BestKey = K: HaveBest = True
                End If
                If Not HaveWrap Or K > WrapKey Then WrapName = Ctl.Core.Name: WrapKey = K: HaveWrap = True
            End If
        End If
    Next I

    If HaveBest Then
        TabTarget = BestName
    ElseIf HaveWrap Then
        TabTarget = WrapName
    End If
End Function

' Focus the first (or, with Shift, last) participating control when nothing is focused yet.
Private Sub FocusFirstTab(ByVal Shift As Boolean)
    Dim BestName As String, BestKey As Long, HaveBest As Boolean
    Dim I As Long, Ctl As IOxControl
    For I = 1 To mForm.Controls.Count
        Set Ctl = mForm.Controls.Item(I)
        If Participates(Ctl) Then
            Dim K As Long
            K = TabKey(Ctl, I - 1)
            If Not HaveBest _
                Or (Not Shift And K < BestKey) _
                Or (Shift And K > BestKey) Then
                BestName = Ctl.Core.Name: BestKey = K: HaveBest = True
            End If
        End If
    Next I
    If HaveBest Then TransferFocusTo BestName
End Sub

' Transfer focus to NewName, running the losing control's two-stage focus-out validation inline
' (the synchronous equivalent of the oracle's validation fold-back). Returns True if the transfer
' committed; False if the losing control's BeforeUpdate or Exit handler vetoed (focus stays).
' Emits beforeupdate/afterupdate/exit on the losing control then enter on the gaining one -- the
' exact oracle order -- because each On* raises its FM20 event before the matching Emit.
Private Function TransferFocusTo(ByVal NewName As String) As Boolean
    If Len(mFocusName) > 0 Then
        Dim Losing As IOxControl
        Set Losing = mForm.ControlByName(mFocusName)

        ' Dirty controls fire the two-stage BeforeUpdate (can veto the commit) then AfterUpdate.
        If Losing.IsDirty Then
            Dim BeforeUpdateCancelled As Boolean
            BeforeUpdateCancelled = Losing.OnBeforeUpdate()
            Emit "beforeupdate:" & mFocusName
            If BeforeUpdateCancelled Then
                TransferFocusTo = False
                Exit Function
            End If
            Losing.OnAfterUpdate
            Emit "afterupdate:" & mFocusName
        End If

        ' Exit can veto the focus change (the value, if dirty, was already committed above).
        Dim ExitCancelled As Boolean
        ExitCancelled = Losing.OnExit()
        Emit "exit:" & mFocusName
        If ExitCancelled Then
            TransferFocusTo = False
            Exit Function
        End If
    End If

    mFocusName = NewName
    If Len(NewName) > 0 Then
        mForm.ControlByName(NewName).OnEnter
        Emit "enter:" & NewName
    End If
    TransferFocusTo = True
End Function

' Pure-geometry hit-test over the form's controls (ports oxforms-core hit_test_control_tree):
' the visible+enabled control whose half-open bounds contain the point, highest z-order then
' last-added winning. Returns Nothing on a miss.
Private Function HitTest(ByVal X As Long, ByVal Y As Long) As IOxControl
    Dim Best As IOxControl
    Dim BestZ As Long
    Dim I As Long, Control As IOxControl
    For I = 1 To mForm.Controls.Count
        Set Control = mForm.Controls.Item(I)
        If ContainsPoint(Control, X, Y) Then
            ' >= keeps the later control on a z tie (last-added wins, matching the kernel).
            If Best Is Nothing Or Control.Core.ZOrder >= BestZ Then
                Set Best = Control
                BestZ = Control.Core.ZOrder
            End If
        End If
    Next I
    Set HitTest = Best
End Function

' Half-open rect test [Left, Left+Width) x [Top, Top+Height) for a visible, enabled control
' (the standard graphics convention; matches the Rust kernel + lex_reduce_spike).
Private Function ContainsPoint(ByVal Control As IOxControl, ByVal X As Long, ByVal Y As Long) As Boolean
    Dim C As OxControlCore
    Set C = Control.Core
    ContainsPoint = C.Visible And C.Enabled _
        And (X >= C.Left) And (X < C.Left + C.Width) _
        And (Y >= C.Top) And (Y < C.Top + C.Height)
End Function

' Clear the armed pressed visual (if any) and log the release.
Private Sub ReleasePressed()
    If Len(mPressedName) = 0 Then Exit Sub
    Dim Ctl As IOxControl
    Set Ctl = mForm.ControlByName(mPressedName)
    Ctl.Core.Pressed = False
    Emit "release:" & mPressedName
    mPressedName = ""
End Sub

' Re-render the form across the OxForms.Surface boundary (the reducer's RequestRepaint
' effect). The form self-renders the invalidated controls incrementally.
Private Sub Repaint()
    mForm.Render mDpiX, mDpiY
    Emit "repaint"
End Sub

Private Sub Emit(ByVal Effect As String)
    If Len(mEffects) > 0 Then mEffects = mEffects & "|"
    mEffects = mEffects & Effect
End Sub
