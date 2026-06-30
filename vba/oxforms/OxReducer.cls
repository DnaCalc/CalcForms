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

Private mForm As UserForm
Private mCaptureName As String   ' control holding the mouse capture ("" = none)
Private mPressedName As String   ' control whose pressed visual is armed ("" = none)
Private mFocusName As String     ' the focused control ("" = form / no control focused)
Private mDpiX As Long
Private mDpiY As Long
Private mEffects As String       ' ordered '|'-joined effect log for the current Dispatch

Public Sub Init(ByVal Form As UserForm)
    Set mForm = Form
    mCaptureName = ""
    mPressedName = ""
    mFocusName = ""
    mDpiX = 96
    mDpiY = 96
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
    If Len(mFocusName) > 0 Then
        Dim Focused As IOxControl
        Set Focused = mForm.ControlByName(mFocusName)
        Select Case Kind
            Case "keydown"
                Focused.OnKeyDown KeyCode, Shift
                Emit "keydown:" & mFocusName
            Case "keyup"
                Focused.OnKeyUp KeyCode, Shift
                Emit "keyup:" & mFocusName
        End Select
        Repaint
    End If
    DispatchKey = mEffects
End Function

' THE VBA REDUCE for character input, routed to the focused control: it raises KeyPress and (a
' TextBox) inserts the text + raises Change. Returns the ordered effect log.
Public Function DispatchChar(ByVal Text As String) As String
    mEffects = ""
    If Len(mFocusName) > 0 Then
        mForm.ControlByName(mFocusName).OnCharacterInput Text
        Emit "char:" & mFocusName
        Repaint
    End If
    DispatchChar = mEffects
End Function

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
