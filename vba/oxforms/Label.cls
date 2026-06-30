Option Explicit
Implements IOxControl

' MSForms-shaped Label. Display-only control: a Caption, no focus, Click and
' mouse events. See docs/specs/RENDERING_ARCHITECTURE.md (§5) for the control template.

Public Event Click()
Public Event MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)

Private mCore As OxControlCore

Private Sub Class_Initialize()
    Set mCore = New OxControlCore
    mCore.Init oxControlLabel
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

' Display-only flat face + left-aligned caption (no edge: Label defaults Flat).
Private Sub IOxControl_Render(ByVal Surface As OxSceneBuilder)
    OxPaintStandardControl mCore, Surface, "left"
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

' A Label fires Click but has no pressed visual (display-only, no press feedback).
Private Property Get IOxControl_SupportsClick() As Boolean
    IOxControl_SupportsClick = True
End Property

Private Property Get IOxControl_HasPressedVisual() As Boolean
    IOxControl_HasPressedVisual = False
End Property

' A Label is not focusable, so the reducer never routes keyboard or focus to it; the interface
' members are required, so they are inert.
Private Function IOxControl_OnKeyDown(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    IOxControl_OnKeyDown = KeyCode
End Function

Private Function IOxControl_OnKeyUp(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    IOxControl_OnKeyUp = KeyCode
End Function

Private Sub IOxControl_OnCharacterInput(ByVal Text As String)
End Sub

Private Sub IOxControl_OnEnter()
End Sub

Private Function IOxControl_OnExit() As Boolean
    IOxControl_OnExit = False
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
    IOxControl_IsDefault = False
End Property

Private Property Get IOxControl_IsCancel() As Boolean
    IOxControl_IsCancel = False
End Property

Private Property Get IOxControl_AcceleratorKey() As String
    IOxControl_AcceleratorKey = ""
End Property

Private Function IOxControl_TryKeyboardActivate(ByVal KeyCode As Integer, ByVal Shift As Integer, ByVal HasDefaultButton As Boolean) As Boolean
    IOxControl_TryKeyboardActivate = False
End Function
