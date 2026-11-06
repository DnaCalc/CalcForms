Option Explicit
Implements IOxControl

' MSForms-shaped CheckBox. Focusable; a Boolean Value, a Caption, and the full FM20 event
' surface (Click, Change, mouse, keyboard, focus-exit/enter, BeforeUpdate/AfterUpdate). The
' MSForms activation semantics live here as control self-knowledge: a click (or a keyboard
' Space/Enter) flips the value FIRST, then raises Change, then Click (value-before-Click, the
' oracle order from calcforms-core toggle_check_box). Programmatic .Value assignment updates the
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
Private mFocused As Boolean

Private Sub Class_Initialize()
    Set mCore = Nothing
    Set mCore = New OxControlCore
    mCore.Init oxControlCheckBox
    mValue = False
    mEditDirty = False
    mFocused = False
End Sub

' --- IOxControl ---
Private Property Get IOxControl_Core() As OxControlCore
    Set IOxControl_Core = mCore
End Property

Public Property Get Core() As OxControlCore
    Set Core = mCore
End Property

' Bespoke state, shared theme paint: the control owns Value/focus/event semantics;
' OxTheme maps that state to generic Scene primitives.
Private Sub IOxControl_Render(ByVal Surface As OxSceneBuilder)
    OxThemePaintCheckBox mCore, Surface, mValue, mFocused
End Sub

Private Property Get IOxControl_HasChildren() As Boolean
    IOxControl_HasChildren = False
End Property

Private Property Get IOxControl_Children() As Controls
    Set IOxControl_Children = Nothing
End Property

' --- User-facing properties ---
' The checked state. Programmatic assignment updates + repaints but raises no Change.
Public Property Get Value() As Boolean
    Value = mValue
End Property
Public Property Let Value(ByVal NewValue As Boolean)
    If mValue <> NewValue Then
        mValue = NewValue
        mCore.MarkDirty
        RaiseEvent Change
        RaiseEvent Click
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

Private Sub IOxControl_OnMouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
End Sub

' A CheckBox click flips the value first, then Change, then Click (oracle order).
Private Sub IOxControl_OnClick()
    Toggle
End Sub

' A CheckBox fires Click and shows a pressed face on mouse-down (oracle has_pressed_visual).
Private Property Get IOxControl_SupportsClick() As Boolean
    IOxControl_SupportsClick = mCore.SupportsClick
End Property

Private Property Get IOxControl_HasPressedVisual() As Boolean
    IOxControl_HasPressedVisual = mCore.HasPressedVisual
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
    If Not mFocused Then
        mFocused = True
        mCore.MarkDirty
    End If
    PerformEnter
End Sub

Private Function IOxControl_OnExit() As Boolean
    IOxControl_OnExit = PerformExit()
    If Not IOxControl_OnExit Then
        If mFocused Then
            mFocused = False
            mCore.MarkDirty
        End If
    End If
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

' Space toggles the focused CheckBox. Enter belongs to form/default routing and does not
' toggle a checkbox when no default exists. No modifiers. Change/Click fire here,
' BEFORE the reducer raises KeyDown -- the oracle value-first keyboard order.
Private Function IOxControl_TryKeyboardActivate(ByVal KeyCode As Integer, ByVal Shift As Integer, ByVal HasDefaultButton As Boolean) As Boolean
    If Not mCore.Toggleable Then Exit Function
    If Shift <> 0 Then Exit Function
    If KeyCode = 32 Then
        Toggle
        IOxControl_TryKeyboardActivate = True
    End If
End Function

Private Function IOxControl_OnPaste(ByVal Text As String, ByVal Action As Integer, ByVal Shift As Integer) As Boolean
    IOxControl_OnPaste = False
End Function

Private Function IOxControl_OnCopy() As String
    IOxControl_OnCopy = ""
End Function

Private Function IOxControl_OnCut() As String
    IOxControl_OnCut = ""
End Function

Private Property Get IOxControl_AccessibilityRole() As String
    IOxControl_AccessibilityRole = "checkbox"
End Property

Private Property Get IOxControl_AccessibilityName() As String
    IOxControl_AccessibilityName = mCore.Name
End Property

Private Property Get IOxControl_AccessibilityValue() As String
    IOxControl_AccessibilityValue = CStr(mValue)
End Property

Private Property Get IOxControl_AccessibilitySelected() As Boolean
    IOxControl_AccessibilitySelected = False
End Property

Private Property Get IOxControl_AccessibilitySelectionStart() As Long
    IOxControl_AccessibilitySelectionStart = 0
End Property

Private Property Get IOxControl_AccessibilitySelectionLength() As Long
    IOxControl_AccessibilitySelectionLength = 0
End Property

Private Property Get IOxControl_AccessibilitySelectionText() As String
    IOxControl_AccessibilitySelectionText = ""
End Property

Private Property Get IOxControl_AccessibilityPatterns() As String
    IOxControl_AccessibilityPatterns = "toggle,value"
End Property

Private Property Get IOxControl_AccessibilityRowCount() As Long
    IOxControl_AccessibilityRowCount = 0
End Property

Private Property Get IOxControl_AccessibilityColumnCount() As Long
    IOxControl_AccessibilityColumnCount = 0
End Property

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
