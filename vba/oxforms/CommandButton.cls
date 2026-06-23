Option Explicit
Implements IOxControl

' MSForms-shaped CommandButton. Focusable; Caption, Click, mouse, keyboard, and
' focus-exit events. Demonstrates all event-argument shapes the framework
' supports: no-arg (Click), scalar (MouseDown), mutable ReturnInteger (KeyDown),
' and mutable ReturnBoolean (BeforeUpdate). See docs/specs/RENDERING_ARCHITECTURE.md.

Public Event Click()
Public Event MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event KeyDown(ByVal KeyCode As OxReturnInteger, ByVal Shift As Integer)
' Note: the FM20 focus-exit event is literally named "Exit", which OxVba cannot
' yet bind (collides with the Exit statement keyword); tracked as an OxVba
' follow-up. BeforeUpdate is a real FM20 cancelable event and establishes the
' same mutable-ReturnBoolean pattern in the meantime.
Public Event BeforeUpdate(ByVal Cancel As OxReturnBoolean)

Private mCore As OxControlCore

Private Sub Class_Initialize()
    Set mCore = New OxControlCore
    mCore.Init oxControlCommandButton
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

' Raises KeyDown with a mutable KeyCode helper and returns the post-handler key
' code (0 if the handler swallowed it).
Public Function PerformKeyDown(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    Dim helper As OxReturnInteger
    Set helper = New OxReturnInteger
    helper.Value = KeyCode
    RaiseEvent KeyDown(helper, Shift)
    PerformKeyDown = helper.Value
End Function

' Raises BeforeUpdate with a mutable Cancel helper and returns whether the handler
' cancelled the update.
Public Function PerformBeforeUpdate() As Boolean
    Dim cancel As OxReturnBoolean
    Set cancel = New OxReturnBoolean
    RaiseEvent BeforeUpdate(cancel)
    PerformBeforeUpdate = cancel.Value
End Function
