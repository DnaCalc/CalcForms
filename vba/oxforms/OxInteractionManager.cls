Option Explicit

' First-class OxForms interaction manager. The control behavior the Rust crate oxforms-core's
' reduce() used to own now lives here in VBA (memory oxforms-reducer-home-decision; design in
' docs/specs/MESSAGE_HANDLING_AND_UPDATE_FLOW.md). It owns the form-level interaction state
' (focus, mouse capture, armed pressed control, hover/cursor target, tab/default/cancel/
' accelerator indexes, and validation transfer), routes normalized input over the form's controls
' by pure geometry, and lets each control raise its own ordered FM20 events through IOxControl.
' No Rust reducer is in the loop; OxReducer is only the compatibility facade.
'
' Scope so far (epic oxforms-ih6): CommandButton/Label/TextBox/CheckBox route through this
' VBA reducer for mouse, focus, keyboard, two-stage validation, Tab traversal, default/cancel
' buttons, accelerators, KeyDown swallow linkage, clipboard paste/copy/cut, text drop, and
' the single-line TextBox caret/selection path. Still out of scope: IME/dead keys, full
' multiline TextBox parity, and broad control coverage.

' MSForms Button arg: the left mouse button.
Private Const OX_BUTTON_LEFT As Integer = 1
' Virtual key codes the reducer routes specially.
Private Const OX_KEY_TAB As Integer = 9
Private Const OX_KEY_ENTER As Integer = 13
Private Const OX_KEY_ESCAPE As Integer = 27
Private Const OX_KEY_C As Integer = 67
Private Const OX_KEY_V As Integer = 86
Private Const OX_KEY_X As Integer = 88
' MSForms Shift-arg bitmask: 1 = Shift, 2 = Ctrl, 4 = Alt.
Private Const OX_SHIFT_SHIFT As Integer = 1
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
Private mInteractionIndexDirty As Boolean
Private mIndexedInteractionRevision As Long
Private mInteractionIndexBuildCount As Long
Private mTabNextByName As Collection
Private mTabPrevByName As Collection
Private mFirstTabName As String
Private mLastTabName As String
Private mDefaultButtonName As String
Private mCancelButtonName As String
Private mHoverName As String
Private mCursorTargetName As String
Private mCursorPointer As Long
Private mAccelA As String
Private mAccelB As String
Private mAccelC As String
Private mAccelD As String
Private mAccelE As String
Private mAccelF As String
Private mAccelG As String
Private mAccelH As String
Private mAccelI As String
Private mAccelJ As String
Private mAccelK As String
Private mAccelL As String
Private mAccelM As String
Private mAccelN As String
Private mAccelO As String
Private mAccelP As String
Private mAccelQ As String
Private mAccelR As String
Private mAccelS As String
Private mAccelT As String
Private mAccelU As String
Private mAccelV As String
Private mAccelW As String
Private mAccelX As String
Private mAccelY As String
Private mAccelZ As String

Public Sub Init(ByVal Form As UserForm)
    Set mForm = Form
    mCaptureName = ""
    mPressedName = ""
    mFocusName = ""
    mSwallowNextChar = False
    mClipboardText = ""
    mDpiX = 96
    mDpiY = 96
    mInteractionIndexDirty = True
    mIndexedInteractionRevision = -1
    mInteractionIndexBuildCount = 0
    Set mTabNextByName = New Collection
    Set mTabPrevByName = New Collection
    mFirstTabName = ""
    mLastTabName = ""
    mDefaultButtonName = ""
    mCancelButtonName = ""
    mHoverName = ""
    mCursorTargetName = ""
    mCursorPointer = 0
End Sub

' The host pushes the current clipboard text before dispatching a Ctrl+V (the live OS clipboard
' read is the host's job; the reducer treats it as already-resolved text). "" = empty clipboard.
Public Sub SetClipboardText(ByVal Text As String)
    mClipboardText = Text
End Sub

Public Property Get ClipboardText() As String
    ClipboardText = mClipboardText
End Property

' The currently focused control's name ("" = none). Test/diagnostic surface.
Public Property Get FocusName() As String
    FocusName = mFocusName
End Property

Public Property Get CaptureName() As String
    CaptureName = mCaptureName
End Property

Public Property Get PressedName() As String
    PressedName = mPressedName
End Property

Public Property Get HoverName() As String
    HoverName = mHoverName
End Property

Public Property Get CursorTargetName() As String
    CursorTargetName = mCursorTargetName
End Property

Public Property Get CursorPointer() As Long
    CursorPointer = mCursorPointer
End Property

Public Property Get InteractionIndexBuildCount() As Long
    InteractionIndexBuildCount = mInteractionIndexBuildCount
End Property

Public Property Get InteractionStateSummary() As String
    EnsureInteractionIndex
    InteractionStateSummary = _
        "focus=" & mFocusName & _
        ";capture=" & mCaptureName & _
        ";pressed=" & mPressedName & _
        ";hover=" & mHoverName & _
        ";cursor_target=" & mCursorTargetName & _
        ";cursor=" & CStr(mCursorPointer) & _
        ";index_revision=" & CStr(mIndexedInteractionRevision) & _
        ";index_builds=" & CStr(mInteractionIndexBuildCount)
End Property

Public Sub InvalidateInteractionIndex()
    mInteractionIndexDirty = True
End Sub

Public Property Get InteractionIndexSummary() As String
    EnsureInteractionIndex

    Dim Text As String
    Text = "revision=" & CStr(mIndexedInteractionRevision) & _
        ";builds=" & CStr(mInteractionIndexBuildCount) & _
        ";first=" & mFirstTabName & _
        ";last=" & mLastTabName & _
        ";default=" & mDefaultButtonName & _
        ";cancel=" & mCancelButtonName & _
        ";hover=" & mHoverName & _
        ";cursor_target=" & mCursorTargetName & _
        ";cursor=" & CStr(mCursorPointer)

    Dim I As Long
    For I = 0 To 25
        If Len(AcceleratorName(I)) > 0 Then
            Text = Text & ";alt+" & Chr$(65 + I) & "=" & AcceleratorName(I)
        End If
    Next I
    InteractionIndexSummary = Text
End Property

' THE VBA REDUCE for pointer input. Kind is "mousedown" | "mousemove" | "mouseup".
' X/Y are form-logical points; Button/Shift are the MSForms scalar args. Routes
' geometrically, mutates interaction state, raises the control's FM20 events in order, and
' repaints. Returns the ordered effect log: a '|'-joined sequence such as
'   "mousedown:Btn1|press:Btn1|repaint"  then  "mouseup:Btn1|click:Btn1|release:Btn1|repaint".
Public Function Dispatch( _
        ByVal Kind As String, ByVal X As Long, ByVal Y As Long, _
        ByVal Button As Integer, ByVal Shift As Integer) As String
    mEffects = ""
    EnsureInteractionIndex
    Select Case Kind
        Case "mousedown"
            ReduceMouseDown X, Y, Button, Shift
        Case "mousemove"
            ReduceMouseMove X, Y, Button, Shift
        Case "mouseup"
            ReduceMouseUp X, Y, Button, Shift
    End Select
    Dispatch = mEffects
End Function

Private Sub ReduceMouseDown(ByVal X As Long, ByVal Y As Long, ByVal Button As Integer, ByVal Shift As Integer)
    If Button <> OX_BUTTON_LEFT Then Exit Sub

    Dim Hit As IOxControl
    Set Hit = HitTest(X, Y)
    If Hit Is Nothing Then
        ResolvePointerTarget Nothing
        Exit Sub
    End If
    ResolvePointerTarget Hit

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
    ElseIf Hit.Core.Dirty Then
        Repaint
    End If
End Sub

Private Sub ReduceMouseMove(ByVal X As Long, ByVal Y As Long, ByVal Button As Integer, ByVal Shift As Integer)
    Dim Target As IOxControl
    If Len(mCaptureName) > 0 Then
        Set Target = mForm.ControlByName(mCaptureName)
    Else
        Set Target = HitTest(X, Y)
    End If

    If Target Is Nothing Then
        ResolvePointerTarget Nothing
        Exit Sub
    End If

    ResolvePointerTarget Target
    Target.OnMouseMove Button, Shift, CSng(X - Target.Core.Left), CSng(Y - Target.Core.Top)
    Emit "mousemove:" & Target.Core.Name
    If Target.Core.Dirty Then Repaint
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
    ResolvePointerTarget Target

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
' "keyup". Returns the ordered effect log. Routes key events, tab navigation, default/cancel
' buttons, accelerators, clipboard shortcuts, and the swallow->character linkage through the
' focused control's IOxControl surface.
Public Function DispatchKey(ByVal Kind As String, ByVal KeyCode As Integer, ByVal Shift As Integer) As String
    mEffects = ""
    EnsureInteractionIndex
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
        If IsTabNavigation(KeyCode, Shift) Then FocusFirstTab IsShiftPressed(Shift)
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
        If Focused.Core.Dirty Then Repaint
        Exit Sub
    End If

    Dim Post As Integer
    Post = Focused.OnKeyDown(KeyCode, Shift)
    Emit "keydown:" & mFocusName

    ' Swallow linkage: a KeyDown handler that zeroed the key code suppresses the character that
    ' would otherwise follow (consumed by the next DispatchChar). A swallowed key also performs
    ' no navigation/activation.
    mSwallowNextChar = (Post = 0) And KeyMayProduceCharacter(KeyCode, Shift)
    If Post = 0 Then Exit Sub

    ' After the KeyDown fired (oracle order KeyDown -> [validation/activation]): Tab navigation,
    ' Alt+accelerator, Enter -> default button, Escape -> cancel button.
    If IsTabNavigation(KeyCode, Shift) Then
        Dim NextName As String
        NextName = TabTarget(mFocusName, IsShiftPressed(Shift))
        If Len(NextName) > 0 Then TransferFocusTo NextName
    ElseIf (Shift And OX_SHIFT_CTRL) <> 0 Then
        HandleClipboardShortcut Focused, KeyCode, Shift
    ElseIf (Shift And OX_SHIFT_ALT) <> 0 Then
        ActivateAccelerator KeyCode
    ElseIf KeyCode = OX_KEY_ENTER And Shift = 0 Then
        ActivateDefaultButton
    ElseIf KeyCode = OX_KEY_ESCAPE And Shift = 0 Then
        ActivateCancelButton
    End If

    If Focused.Core.Dirty Then Repaint
End Sub

Private Sub HandleClipboardShortcut(ByVal Focused As IOxControl, ByVal KeyCode As Integer, ByVal Shift As Integer)
    Select Case KeyCode
        Case OX_KEY_C
            Dim Copied As String
            Copied = Focused.OnCopy()
            If Len(Copied) > 0 Then
                mClipboardText = Copied
                Emit "copy:" & mFocusName
            End If
        Case OX_KEY_X
            Dim CutText As String
            CutText = Focused.OnCut()
            If Len(CutText) > 0 Then
                mClipboardText = CutText
                Emit "cut:" & mFocusName
            End If
        Case OX_KEY_V
            ' Ctrl+V: paste the host clipboard text into the focused control
            ' (BeforeDropOrPaste -> Change), AFTER the V KeyDown fired. Empty clipboard is
            ' a no-op. No KeyPress for Ctrl+V.
            If Len(mClipboardText) > 0 Then
                If Focused.OnPaste(mClipboardText, OX_ACTION_PASTE, Shift) Then
                    Emit "paste:" & mFocusName
                End If
            End If
    End Select
End Sub

Private Function IsShiftPressed(ByVal Shift As Integer) As Boolean
    IsShiftPressed = ((Shift And OX_SHIFT_SHIFT) <> 0)
End Function

' Plain Tab and Shift+Tab traverse controls. Ctrl+Tab / Alt+Tab must not be misread as
' Shift+Tab just because the MSForms Shift bitmask is nonzero.
Private Function IsTabNavigation(ByVal KeyCode As Integer, ByVal Shift As Integer) As Boolean
    If KeyCode <> OX_KEY_TAB Then Exit Function
    IsTabNavigation = ((Shift And (OX_SHIFT_CTRL Or OX_SHIFT_ALT)) = 0)
End Function

' Only a swallowed KeyDown that belongs to a printable key suppresses the paired CharacterInput.
' Swallowing Escape/Tab/Delete/arrows must not make the next ordinary typed character disappear.
Private Function KeyMayProduceCharacter(ByVal KeyCode As Integer, ByVal Shift As Integer) As Boolean
    If (Shift And (OX_SHIFT_CTRL Or OX_SHIFT_ALT)) <> 0 Then Exit Function
    KeyMayProduceCharacter = _
        (KeyCode = 32) _
        Or (KeyCode >= 48 And KeyCode <= 57) _
        Or (KeyCode >= 65 And KeyCode <= 90) _
        Or (KeyCode >= 186 And KeyCode <= 192) _
        Or (KeyCode >= 219 And KeyCode <= 222)
End Function

Private Sub EnsureInteractionIndex()
    If Not mInteractionIndexDirty _
        And mIndexedInteractionRevision = mForm.InteractionRevision Then
        ReconcileInteractionState
        Exit Sub
    End If

    BuildInteractionIndex
    ReconcileInteractionState
End Sub

Private Sub BuildInteractionIndex()
    Set mTabNextByName = New Collection
    Set mTabPrevByName = New Collection
    mFirstTabName = ""
    mLastTabName = ""
    mDefaultButtonName = ""
    mCancelButtonName = ""

    Dim I As Long
    ClearAccelerators

    Dim TabNames As Collection
    Dim TabKeys As Collection
    Set TabNames = New Collection
    Set TabKeys = New Collection

    Dim Ctl As IOxControl
    For I = 1 To mForm.Controls.Count
        Set Ctl = mForm.Controls.Item(I)

        If Participates(Ctl) Then
            AddSortedTabParticipant TabNames, TabKeys, Ctl.Core.Name, TabKey(Ctl, I - 1)
        End If

        If Len(mDefaultButtonName) = 0 _
            And Ctl.Core.Visible And Ctl.Core.Enabled And Ctl.IsDefault Then
            mDefaultButtonName = Ctl.Core.Name
        End If
        If Len(mCancelButtonName) = 0 _
            And Ctl.Core.Visible And Ctl.Core.Enabled And Ctl.IsCancel Then
            mCancelButtonName = Ctl.Core.Name
        End If

        If Ctl.Core.Visible And Ctl.Core.Enabled And Ctl.Core.AcceleratorEligible Then
            RegisterAccelerator Ctl
        End If
    Next I

    If TabNames.Count > 0 Then
        mFirstTabName = TabNames.Item(1)
        mLastTabName = TabNames.Item(TabNames.Count)
    End If

    For I = 1 To mForm.Controls.Count
        Set Ctl = mForm.Controls.Item(I)
        If Participates(Ctl) Then
            mTabNextByName.Add TabNeighbor(TabNames, Ctl.Core.Name, False), Ctl.Core.Name
            mTabPrevByName.Add TabNeighbor(TabNames, Ctl.Core.Name, True), Ctl.Core.Name
        Else
            mTabNextByName.Add "", Ctl.Core.Name
            mTabPrevByName.Add "", Ctl.Core.Name
        End If
    Next I

    mIndexedInteractionRevision = mForm.InteractionRevision
    mInteractionIndexDirty = False
    mInteractionIndexBuildCount = mInteractionIndexBuildCount + 1
End Sub

' Keep transient interaction owners coherent after object-model mutations. Exact MSForms event
' ordering for hide/disable/remove while focused is an oracle lane; this representative seam
' guarantees stale names do not keep receiving keyboard, capture, hover, or pressed state.
Private Sub ReconcileInteractionState()
    If Len(mFocusName) > 0 Then
        If Not CanHoldFocus(mFocusName) Then
            mFocusName = ""
            mSwallowNextChar = False
        End If
    End If

    If Len(mCaptureName) > 0 Then
        If Not CanReceivePointer(mCaptureName) Then mCaptureName = ""
    End If

    If Len(mPressedName) > 0 Then
        If Not CanReceivePointer(mPressedName) Then ClearPressedVisual
    End If

    If Len(mHoverName) > 0 Then
        If Not CanReceivePointer(mHoverName) Then ResolvePointerTarget Nothing
    ElseIf Len(mCursorTargetName) > 0 Then
        If Not CanReceivePointer(mCursorTargetName) Then ResolvePointerTarget Nothing
    End If
End Sub

Private Function CanReceivePointer(ByVal Name As String) As Boolean
    If Not mForm.HasControl(Name) Then Exit Function
    Dim Control As IOxControl
    Set Control = mForm.ControlByName(Name)
    CanReceivePointer = Control.Core.Visible And Control.Core.Enabled
End Function

Private Function CanHoldFocus(ByVal Name As String) As Boolean
    If Not mForm.HasControl(Name) Then Exit Function
    Dim Control As IOxControl
    Set Control = mForm.ControlByName(Name)
    CanHoldFocus = Control.Core.Focusable And Control.Core.Visible And Control.Core.Enabled
End Function

Private Sub ClearPressedVisual()
    If Len(mPressedName) = 0 Then Exit Sub
    If mForm.HasControl(mPressedName) Then
        mForm.ControlByName(mPressedName).Core.Pressed = False
    End If
    mPressedName = ""
End Sub

Private Sub AddSortedTabParticipant( _
        ByVal Names As Collection, ByVal Keys As Collection, _
        ByVal Name As String, ByVal Key As Long)
    Dim Pos As Long
    For Pos = 1 To Keys.Count
        If Key < CLng(Keys.Item(Pos)) Then
            Keys.Add Key, , Pos
            Names.Add Name, , Pos
            Exit Sub
        End If
    Next Pos

    Keys.Add Key
    Names.Add Name
End Sub

Private Function TabNeighbor( _
        ByVal Names As Collection, ByVal CurrentName As String, ByVal Shift As Boolean) As String
    If Names.Count <= 1 Then Exit Function

    Dim Pos As Long
    Pos = TabPosition(Names, CurrentName)
    If Pos = 0 Then Exit Function

    If Shift Then
        If Pos = 1 Then
            TabNeighbor = Names.Item(Names.Count)
        Else
            TabNeighbor = Names.Item(Pos - 1)
        End If
    Else
        If Pos = Names.Count Then
            TabNeighbor = Names.Item(1)
        Else
            TabNeighbor = Names.Item(Pos + 1)
        End If
    End If
End Function

Private Function TabPosition(ByVal Names As Collection, ByVal CurrentName As String) As Long
    Dim I As Long
    For I = 1 To Names.Count
        If Names.Item(I) = CurrentName Then
            TabPosition = I
            Exit Function
        End If
    Next I
End Function

Private Sub RegisterAccelerator(ByVal Ctl As IOxControl)
    Dim Accel As String
    Accel = Ctl.AcceleratorKey
    If Len(Accel) = 0 Then Exit Sub

    Dim Slot As Long
    Slot = AcceleratorSlot(Asc(UCase$(Left$(Accel, 1))))
    If Slot < 0 Then Exit Sub

    ' First enabled/visible control in declaration order wins for duplicate mnemonics.
    If Len(AcceleratorName(Slot)) = 0 Then SetAcceleratorName Slot, Ctl.Core.Name
End Sub

Private Function AcceleratorSlot(ByVal KeyCode As Integer) As Long
    Dim Code As Long
    Code = KeyCode
    If Code >= 97 And Code <= 122 Then Code = Code - 32

    If Code < 65 Or Code > 90 Then
        AcceleratorSlot = -1
    Else
        AcceleratorSlot = Code - 65
    End If
End Function

Private Sub ClearAccelerators()
    mAccelA = ""
    mAccelB = ""
    mAccelC = ""
    mAccelD = ""
    mAccelE = ""
    mAccelF = ""
    mAccelG = ""
    mAccelH = ""
    mAccelI = ""
    mAccelJ = ""
    mAccelK = ""
    mAccelL = ""
    mAccelM = ""
    mAccelN = ""
    mAccelO = ""
    mAccelP = ""
    mAccelQ = ""
    mAccelR = ""
    mAccelS = ""
    mAccelT = ""
    mAccelU = ""
    mAccelV = ""
    mAccelW = ""
    mAccelX = ""
    mAccelY = ""
    mAccelZ = ""
End Sub

Private Function AcceleratorName(ByVal Slot As Long) As String
    Select Case Slot
        Case 0
            AcceleratorName = mAccelA
        Case 1
            AcceleratorName = mAccelB
        Case 2
            AcceleratorName = mAccelC
        Case 3
            AcceleratorName = mAccelD
        Case 4
            AcceleratorName = mAccelE
        Case 5
            AcceleratorName = mAccelF
        Case 6
            AcceleratorName = mAccelG
        Case 7
            AcceleratorName = mAccelH
        Case 8
            AcceleratorName = mAccelI
        Case 9
            AcceleratorName = mAccelJ
        Case 10
            AcceleratorName = mAccelK
        Case 11
            AcceleratorName = mAccelL
        Case 12
            AcceleratorName = mAccelM
        Case 13
            AcceleratorName = mAccelN
        Case 14
            AcceleratorName = mAccelO
        Case 15
            AcceleratorName = mAccelP
        Case 16
            AcceleratorName = mAccelQ
        Case 17
            AcceleratorName = mAccelR
        Case 18
            AcceleratorName = mAccelS
        Case 19
            AcceleratorName = mAccelT
        Case 20
            AcceleratorName = mAccelU
        Case 21
            AcceleratorName = mAccelV
        Case 22
            AcceleratorName = mAccelW
        Case 23
            AcceleratorName = mAccelX
        Case 24
            AcceleratorName = mAccelY
        Case 25
            AcceleratorName = mAccelZ
    End Select
End Function

Private Sub SetAcceleratorName(ByVal Slot As Long, ByVal Name As String)
    Select Case Slot
        Case 0
            mAccelA = Name
        Case 1
            mAccelB = Name
        Case 2
            mAccelC = Name
        Case 3
            mAccelD = Name
        Case 4
            mAccelE = Name
        Case 5
            mAccelF = Name
        Case 6
            mAccelG = Name
        Case 7
            mAccelH = Name
        Case 8
            mAccelI = Name
        Case 9
            mAccelJ = Name
        Case 10
            mAccelK = Name
        Case 11
            mAccelL = Name
        Case 12
            mAccelM = Name
        Case 13
            mAccelN = Name
        Case 14
            mAccelO = Name
        Case 15
            mAccelP = Name
        Case 16
            mAccelQ = Name
        Case 17
            mAccelR = Name
        Case 18
            mAccelS = Name
        Case 19
            mAccelT = Name
        Case 20
            mAccelU = Name
        Case 21
            mAccelV = Name
        Case 22
            mAccelW = Name
        Case 23
            mAccelX = Name
        Case 24
            mAccelY = Name
        Case 25
            mAccelZ = Name
    End Select
End Sub

Private Sub ResolvePointerTarget(ByVal Control As IOxControl)
    If Control Is Nothing Then
        mHoverName = ""
        mCursorTargetName = ""
        mCursorPointer = 0
    Else
        mHoverName = Control.Core.Name
        mCursorTargetName = Control.Core.Name
        mCursorPointer = Control.Core.MousePointer
    End If
End Sub

' THE VBA REDUCE for a drag-drop text drop, routed to the focused control: BeforeDropOrPaste ->
' (if not vetoed) insert + Change -- the same paste path as Ctrl+V, different origin. Returns the
' ordered effect log.
Public Function DispatchDrop(ByVal Text As String) As String
    mEffects = ""
    EnsureInteractionIndex
    If Len(mFocusName) > 0 And Len(Text) > 0 Then
        mForm.ControlByName(mFocusName).OnPaste Text, OX_ACTION_PASTE, 0
        Emit "drop:" & mFocusName
        Repaint
    End If
    DispatchDrop = mEffects
End Function

' The visible+enabled form default button's name ("" if none).
Private Function DefaultButtonName() As String
    EnsureInteractionIndex
    DefaultButtonName = mDefaultButtonName
End Function

' The visible+enabled form cancel button's name ("" if none).
Private Function CancelButtonName() As String
    EnsureInteractionIndex
    CancelButtonName = mCancelButtonName
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
    EnsureInteractionIndex

    Dim Slot As Long
    Slot = AcceleratorSlot(KeyCode)
    If Slot < 0 Then Exit Sub

    Dim Name As String
    Name = AcceleratorName(Slot)
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
    EnsureInteractionIndex
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
    EnsureInteractionIndex
    If Shift Then
        TabTarget = mTabPrevByName.Item(CurrentName)
    Else
        TabTarget = mTabNextByName.Item(CurrentName)
    End If
End Function

' Focus the first (or, with Shift, last) participating control when nothing is focused yet.
Private Sub FocusFirstTab(ByVal Shift As Boolean)
    EnsureInteractionIndex
    If Shift Then
        If Len(mLastTabName) > 0 Then TransferFocusTo mLastTabName
    Else
        If Len(mFirstTabName) > 0 Then TransferFocusTo mFirstTabName
    End If
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
