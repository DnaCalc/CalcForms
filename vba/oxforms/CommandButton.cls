Option Explicit
Implements IOxControl

' MSForms-shaped CommandButton. Focusable; Caption, Click, mouse, keyboard, and
' focus-exit events. Demonstrates all event-argument shapes the framework
' supports: no-arg (Click), scalar (MouseDown), mutable ReturnInteger (KeyDown),
' and mutable ReturnBoolean (Exit). See docs/specs/RENDERING_ARCHITECTURE.md.

Public Event Click()
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

Private mCore As OxControlCore
' MSForms Default/Cancel: at most one button per form is the default (Enter activates) and one
' the cancel (Escape activates). Set at build time; the reducer scans for them.
Private mDefault As Boolean
Private mCancel As Boolean

Private Sub Class_Initialize()
    Set mCore = New OxControlCore
    mCore.Init oxControlCommandButton
    mDefault = False
    mCancel = False
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

' Raised button face + centered caption.
Private Sub IOxControl_Render(ByVal Surface As OxSceneBuilder)
    OxPaintStandardControl mCore, Surface, "center"
End Sub

' --- User-facing properties ---
Public Property Get Caption() As String
    Caption = mCore.DisplayText
End Property
Public Property Let Caption(ByVal Value As String)
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

' The form default button (activated by Enter when no other control consumes it).
Public Property Get Default() As Boolean
    Default = mDefault
End Property
Public Property Let Default(ByVal Value As Boolean)
    mDefault = Value
End Property

' The form cancel button (activated by Escape).
Public Property Get Cancel() As Boolean
    Cancel = mCancel
End Property
Public Property Let Cancel(ByVal Value As Boolean)
    mCancel = Value
End Property

' --- Runtime-facing input surface (driven by the OxForms runtime, not form code) ---
Public Sub PerformClick()
    RaiseEvent Click
End Sub

Public Sub PerformMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseDown(Button, Shift, X, Y)
End Sub

Public Sub PerformMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseUp(Button, Shift, X, Y)
End Sub

' Raises KeyDown with a mutable KeyCode helper and returns the post-handler key
' code (0 if the handler swallowed it).
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

' Raises the focus-exit event with a mutable Cancel helper and returns whether the
' handler cancelled the focus change.
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

' --- IOxControl reducer input surface (delegates to the concrete Perform*) ---
Private Sub IOxControl_OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    PerformMouseDown Button, Shift, X, Y
End Sub

Private Sub IOxControl_OnMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    PerformMouseUp Button, Shift, X, Y
End Sub

Private Sub IOxControl_OnClick()
    PerformClick
End Sub

' A CommandButton fires Click and shows a pressed face on mouse-down.
Private Property Get IOxControl_SupportsClick() As Boolean
    IOxControl_SupportsClick = True
End Property

Private Property Get IOxControl_HasPressedVisual() As Boolean
    IOxControl_HasPressedVisual = True
End Property

' Keyboard + focus surface. A CommandButton fires keys and Enter/Exit but has no editable
' value, so it is never dirty and never fires BeforeUpdate/AfterUpdate.
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
    IOxControl_OnBeforeUpdate = False
End Function

Private Sub IOxControl_OnAfterUpdate()
End Sub

Private Property Get IOxControl_IsDirty() As Boolean
    IOxControl_IsDirty = False
End Property

Private Property Get IOxControl_IsDefault() As Boolean
    IOxControl_IsDefault = mDefault
End Property

Private Property Get IOxControl_IsCancel() As Boolean
    IOxControl_IsCancel = mCancel
End Property

' Parse the caption's '&X' accelerator mnemonic (uppercased); "" if none. '&&' is a literal
' ampersand, not a mnemonic.
Private Property Get IOxControl_AcceleratorKey() As String
    Dim Caption As String, I As Long, Ch As String
    Caption = mCore.DisplayText
    I = 1
    Do While I < Len(Caption)
        Ch = Mid$(Caption, I, 1)
        If Ch = "&" Then
            Dim NextCh As String
            NextCh = Mid$(Caption, I + 1, 1)
            If NextCh = "&" Then
                I = I + 2   ' escaped '&&' -- skip both
            Else
                IOxControl_AcceleratorKey = UCase$(NextCh)
                Exit Property
            End If
        Else
            I = I + 1
        End If
    Loop
    IOxControl_AcceleratorKey = ""
End Property

' A focused CommandButton's Enter/Space is handled via the form default-button path, not here.
Private Function IOxControl_TryKeyboardActivate(ByVal KeyCode As Integer, ByVal Shift As Integer, ByVal HasDefaultButton As Boolean) As Boolean
    IOxControl_TryKeyboardActivate = False
End Function

Private Function IOxControl_OnPaste(ByVal Text As String, ByVal Action As Integer, ByVal Shift As Integer) As Boolean
    IOxControl_OnPaste = False
End Function
