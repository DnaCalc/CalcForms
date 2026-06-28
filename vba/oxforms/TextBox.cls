Option Explicit
Implements IOxControl

' MSForms-shaped single-line TextBox. Focusable; Text value, Change/keyboard/
' mouse/focus events. Note the MSForms semantic split: setting .Text in code is
' programmatic and does NOT raise Change, while a user edit (ApplyUserText, driven
' by the runtime from real keystrokes) updates the text AND raises Change.

Public Event Change()
Public Event MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
Public Event KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
' KeyPress carries a mutable KeyAscii (ReturnInteger); a handler sets KeyAscii.Value
' = 0 to swallow the typed character (clean-room name; MS Learn uses KeyANSI).
Public Event KeyPress(ByVal KeyAscii As ReturnInteger)
' The FM20 focus-exit event is the reserved word "Exit", declared via the VBA
' bracketed-name form [Exit] (OxVba accepts bracketed RaiseEvent names as of
' baseline 366a40e). Carries a mutable Cancel (ReturnBoolean); a handler sets
' Cancel.Value = True to keep focus.
Public Event [Exit](ByVal Cancel As ReturnBoolean)
' The FM20 focus-enter event fires (no args) when the control receives focus,
' after the losing control's [Exit] (oxforms-esq.6).
Public Event Enter()
' BeforeUpdate fires on focus-out when the value changed (dirty), carrying a mutable
' Cancel (ReturnBoolean) -- a handler sets Cancel.Value = True to cancel the update and
' keep focus. AfterUpdate fires (no args) after a committed update (oxforms-esq.7).
Public Event BeforeUpdate(ByVal Cancel As ReturnBoolean)
Public Event AfterUpdate()

Private mCore As OxControlCore

Private Sub Class_Initialize()
    Set mCore = New OxControlCore
    mCore.Init oxControlTextBox
End Sub

' --- IOxControl ---
Private Property Get IOxControl_Core() As OxControlCore
    Set IOxControl_Core = mCore
End Property

' Public ergonomic/runtime handle to the shared core (the IOxControl
' implementation is Private, so the runtime reaches the core through this).
Public Property Get Core() As OxControlCore
    Set Core = mCore
End Property

' Sunken white field + left-aligned text (caret is a later sub-part node).
Private Sub IOxControl_Render(ByVal Surface As OxSceneBuilder)
    OxPaintStandardControl mCore, Surface, "left"
End Sub

' --- User-facing properties ---
' Programmatic assignment: updates the value and requests repaint, but does not
' raise Change (MSForms semantics).
Public Property Get Text() As String
    Text = mCore.DisplayText
End Property
Public Property Let Text(ByVal Value As String)
    mCore.DisplayText = Value
End Property

Public Property Get Name() As String
    Name = mCore.Name
End Property

Public Property Get Left() As Single
    Left = mCore.Left
End Property
Public Property Let Left(ByVal Value As Single)
    mCore.Left = Value
End Property

Public Property Get Top() As Single
    Top = mCore.Top
End Property
Public Property Let Top(ByVal Value As Single)
    mCore.Top = Value
End Property

Public Property Get Width() As Single
    Width = mCore.Width
End Property
Public Property Let Width(ByVal Value As Single)
    mCore.Width = Value
End Property

Public Property Get Height() As Single
    Height = mCore.Height
End Property
Public Property Let Height(ByVal Value As Single)
    mCore.Height = Value
End Property

Public Property Get Visible() As Boolean
    Visible = mCore.Visible
End Property
Public Property Let Visible(ByVal Value As Boolean)
    mCore.Visible = Value
End Property

Public Property Get Enabled() As Boolean
    Enabled = mCore.Enabled
End Property
Public Property Let Enabled(ByVal Value As Boolean)
    mCore.Enabled = Value
End Property

' --- Runtime-facing input surface (driven by the OxForms runtime, not form code) ---
' User edit path: set the text from a real keystroke/paste and raise Change.
Public Sub ApplyUserText(ByVal NewText As String)
    mCore.DisplayText = NewText
    RaiseEvent Change
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

' Raises KeyUp with a mutable KeyCode helper and returns the post-handler key code.
Public Function PerformKeyUp(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    Dim helper As ReturnInteger
    Set helper = New ReturnInteger
    helper.Value = KeyCode
    RaiseEvent KeyUp(helper, Shift)
    PerformKeyUp = helper.Value
End Function

' Raises KeyPress with a mutable KeyAscii helper and returns the post-handler value
' (0 if the handler swallowed the character).
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

' Raises the focus-enter event when the control gains focus (no readback).
Public Sub PerformEnter()
    RaiseEvent Enter
End Sub

' Raises BeforeUpdate with a mutable Cancel helper and returns whether the handler
' cancelled the update (True = veto).
Public Function PerformBeforeUpdate() As Boolean
    Dim cancel As ReturnBoolean
    Set cancel = New ReturnBoolean
    RaiseEvent BeforeUpdate(cancel)
    PerformBeforeUpdate = cancel.Value
End Function

' Raises AfterUpdate after a committed update (no args, no readback).
Public Sub PerformAfterUpdate()
    RaiseEvent AfterUpdate
End Sub
