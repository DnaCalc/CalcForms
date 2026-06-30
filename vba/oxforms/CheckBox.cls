Option Explicit
Implements IOxControl

' MSForms-shaped CheckBox. Focusable; a Boolean Value, a Caption, and the full FM20 event
' surface (Click, Change, mouse, keyboard, focus-exit/enter, BeforeUpdate/AfterUpdate). The
' MSForms activation semantics live here as control self-knowledge: a click (or a keyboard
' Space/Enter) flips the value FIRST, then raises Change, then Click (value-before-Click, the
' oracle order from oxforms-core toggle_check_box). Programmatic .Value assignment updates the
' value and requests repaint but raises no Change (the same code-vs-user split as TextBox.Text).
'
' Render: a sunken box glyph (filled when checked) plus the caption to its right -- a bespoke
' part, so it paints itself rather than calling OxPaintStandardControl.

Public Event Click()
Public Event Change()
Public Event MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
Public Event KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
Public Event KeyPress(ByVal KeyAscii As ReturnInteger)
Public Event [Exit](ByVal Cancel As ReturnBoolean)
Public Event Enter()
Public Event BeforeUpdate(ByVal Cancel As ReturnBoolean)
Public Event AfterUpdate()

Private mCore As OxControlCore
Private mValue As Boolean
' Uncommitted-edit flag for two-stage focus-out validation: set by a user toggle, cleared on
' AfterUpdate (the value-committed signal). Programmatic .Value assignment does not set it.
Private mEditDirty As Boolean

' The check-box glyph: a fixed sunken square at the left, vertically centered; the caption
' paints to its right. Points (MSForms units).
Private Const OX_BOX_SIZE As Single = 12

Private Sub Class_Initialize()
    Set mCore = New OxControlCore
    mCore.Init oxControlCheckBox
    mValue = False
    mEditDirty = False
End Sub

' --- IOxControl ---
Private Property Get IOxControl_Core() As OxControlCore
    Set IOxControl_Core = mCore
End Property

Public Property Get Core() As OxControlCore
    Set Core = mCore
End Property

' Bespoke render: the box glyph (sunken square, filled when checked) + the caption to its
' right. The pressed visual tints the box face (OxThemeFaceColor IsPressed).
Private Sub IOxControl_Render(ByVal Surface As OxSceneBuilder)
    Surface.OpenNode mCore.NodeId, True, 0, mCore.ZOrder, _
        mCore.Left, mCore.Top, mCore.Width, mCore.Height, mCore.Visible

    Dim BoxX As Single, BoxY As Single
    BoxX = mCore.Left
    BoxY = mCore.Top + (mCore.Height - OX_BOX_SIZE) / 2

    Surface.FillRect BoxX, BoxY, OX_BOX_SIZE, OX_BOX_SIZE, BoxFace(), 255
    Surface.DrawEdge BoxX, BoxY, OX_BOX_SIZE, OX_BOX_SIZE, _
        "sunken", OxThemeEdgeLight(), OxThemeEdgeShadow()
    If mValue Then
        ' Check mark approximated by a filled inner square (a deterministic primitive; a
        ' true glyph is a later rendering refinement, not behavior).
        Surface.FillRect BoxX + 3, BoxY + 3, OX_BOX_SIZE - 6, OX_BOX_SIZE - 6, _
            OxThemeTextColor(oxControlCheckBox, mCore.Enabled), 255
    End If

    If Len(mCore.DisplayText) > 0 Then
        Dim Tx As Single, Ty As Single, Tw As Single, Th As Single
        Tx = mCore.Left + OX_BOX_SIZE + 4
        Ty = mCore.Top + 3
        Tw = mCore.Width - OX_BOX_SIZE - 8
        If Tw < 1 Then Tw = 1
        Th = mCore.Height - 6
        If Th < 1 Then Th = 1
        Dim RunId As String
        RunId = mCore.RunId
        If Len(RunId) = 0 Then RunId = "0"
        Surface.DrawText Tx, Ty, Tw, Th, RunId, "left", False, True, _
            OxThemeTextColor(oxControlCheckBox, mCore.Enabled), 255, False, Not mCore.Enabled
    End If

    Surface.CloseNode
End Sub

Private Function BoxFace() As Long
    If mCore.BackColor = oxColorAuto Then
        BoxFace = OxThemeFaceColor(oxControlCheckBox, mCore.Pressed, mCore.Enabled)
    Else
        BoxFace = mCore.BackColor
    End If
End Function

' --- User-facing properties ---
' The checked state. Programmatic assignment updates + repaints but raises no Change.
Public Property Get Value() As Boolean
    Value = mValue
End Property
Public Property Let Value(ByVal NewValue As Boolean)
    If mValue <> NewValue Then
        mValue = NewValue
        mCore.MarkDirty
    End If
End Property

Public Property Get Caption() As String
    Caption = mCore.DisplayText
End Property
Public Property Let Caption(ByVal NewCaption As String)
    mCore.DisplayText = NewCaption
End Property

Public Property Get Name() As String
    Name = mCore.Name
End Property

Public Property Get Left() As Single
    Left = mCore.Left
End Property
Public Property Let Left(ByVal NewValue As Single)
    mCore.Left = NewValue
End Property

Public Property Get Top() As Single
    Top = mCore.Top
End Property
Public Property Let Top(ByVal NewValue As Single)
    mCore.Top = NewValue
End Property

Public Property Get Width() As Single
    Width = mCore.Width
End Property
Public Property Let Width(ByVal NewValue As Single)
    mCore.Width = NewValue
End Property

Public Property Get Height() As Single
    Height = mCore.Height
End Property
Public Property Let Height(ByVal NewValue As Single)
    mCore.Height = NewValue
End Property

Public Property Get Visible() As Boolean
    Visible = mCore.Visible
End Property
Public Property Let Visible(ByVal NewValue As Boolean)
    mCore.Visible = NewValue
End Property

Public Property Get Enabled() As Boolean
    Enabled = mCore.Enabled
End Property
Public Property Let Enabled(ByVal NewValue As Boolean)
    mCore.Enabled = NewValue
End Property

' --- IOxControl reducer input surface ---
Private Sub IOxControl_OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    PerformMouseDown Button, Shift, X, Y
End Sub

Private Sub IOxControl_OnMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    PerformMouseUp Button, Shift, X, Y
End Sub

' A CheckBox click flips the value first, then Change, then Click (oracle order).
Private Sub IOxControl_OnClick()
    Toggle
End Sub

' A CheckBox fires Click and shows a pressed face on mouse-down (oracle has_pressed_visual).
Private Property Get IOxControl_SupportsClick() As Boolean
    IOxControl_SupportsClick = True
End Property

Private Property Get IOxControl_HasPressedVisual() As Boolean
    IOxControl_HasPressedVisual = True
End Property

' Keyboard + focus surface. A CheckBox has an editable value, so a toggle marks it dirty and a
' dirty focus-out fires the two-stage BeforeUpdate/AfterUpdate.
Private Function IOxControl_OnKeyDown(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    IOxControl_OnKeyDown = PerformKeyDown(KeyCode, Shift)
End Function

Private Function IOxControl_OnKeyUp(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    IOxControl_OnKeyUp = PerformKeyUp(KeyCode, Shift)
End Function

Private Sub IOxControl_OnCharacterInput(ByVal Text As String)
    If Len(Text) > 0 Then PerformKeyPress Asc(Left$(Text, 1))
End Sub

Private Sub IOxControl_OnEnter()
    PerformEnter
End Sub

Private Function IOxControl_OnExit() As Boolean
    IOxControl_OnExit = PerformExit()
End Function

Private Function IOxControl_OnBeforeUpdate() As Boolean
    IOxControl_OnBeforeUpdate = PerformBeforeUpdate()
End Function

Private Sub IOxControl_OnAfterUpdate()
    PerformAfterUpdate
    mEditDirty = False
End Sub

Private Property Get IOxControl_IsDirty() As Boolean
    IOxControl_IsDirty = mEditDirty
End Property

Private Property Get IOxControl_IsDefault() As Boolean
    IOxControl_IsDefault = False
End Property

Private Property Get IOxControl_IsCancel() As Boolean
    IOxControl_IsCancel = False
End Property

Private Property Get IOxControl_AcceleratorKey() As String
    IOxControl_AcceleratorKey = ""
End Property

' Space toggles the focused CheckBox; Enter toggles it only when there is no default button
' (otherwise Enter activates the default). No modifiers. The toggle (Change/Click) fires here,
' BEFORE the reducer raises KeyDown -- the oracle value-first keyboard order.
Private Function IOxControl_TryKeyboardActivate(ByVal KeyCode As Integer, ByVal Shift As Integer, ByVal HasDefaultButton As Boolean) As Boolean
    If Shift <> 0 Then Exit Function
    If KeyCode = 32 Then
        Toggle
        IOxControl_TryKeyboardActivate = True
    ElseIf KeyCode = 13 And Not HasDefaultButton Then
        Toggle
        IOxControl_TryKeyboardActivate = True
    End If
End Function

Private Function IOxControl_OnPaste(ByVal Text As String, ByVal Action As Integer, ByVal Shift As Integer) As Boolean
    IOxControl_OnPaste = False
End Function

' --- Runtime-facing input surface ---
' Activate the check box: flip the value, then Change, then Click (value-before-Click). This
' is both the mouse-click and keyboard Space/Enter activation path.
Public Sub PerformToggle()
    Toggle
End Sub

Private Sub Toggle()
    mValue = Not mValue
    mEditDirty = True
    mCore.MarkDirty
    RaiseEvent Change
    RaiseEvent Click
End Sub

Public Sub PerformMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseDown(Button, Shift, X, Y)
End Sub

Public Sub PerformMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseUp(Button, Shift, X, Y)
End Sub

Public Function PerformKeyDown(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    Dim helper As ReturnInteger
    Set helper = New ReturnInteger
    helper.Value = KeyCode
    RaiseEvent KeyDown(helper, Shift)
    PerformKeyDown = helper.Value
End Function

Public Function PerformKeyUp(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    Dim helper As ReturnInteger
    Set helper = New ReturnInteger
    helper.Value = KeyCode
    RaiseEvent KeyUp(helper, Shift)
    PerformKeyUp = helper.Value
End Function

Public Function PerformKeyPress(ByVal KeyAscii As Integer) As Integer
    Dim helper As ReturnInteger
    Set helper = New ReturnInteger
    helper.Value = KeyAscii
    RaiseEvent KeyPress(helper)
    PerformKeyPress = helper.Value
End Function

Public Function PerformExit() As Boolean
    Dim cancel As ReturnBoolean
    Set cancel = New ReturnBoolean
    RaiseEvent [Exit](cancel)
    PerformExit = cancel.Value
End Function

Public Sub PerformEnter()
    RaiseEvent Enter
End Sub

Public Function PerformBeforeUpdate() As Boolean
    Dim cancel As ReturnBoolean
    Set cancel = New ReturnBoolean
    RaiseEvent BeforeUpdate(cancel)
    PerformBeforeUpdate = cancel.Value
End Function

Public Sub PerformAfterUpdate()
    RaiseEvent AfterUpdate
End Sub
