Option Explicit
Implements IOxControl
Implements IOxControlHost
Implements IOxControlContainer

' Representative MSForms-shaped Frame. The Frame is a control and a child owner:
' its children keep local Left/Top object-model coordinates, while render/input
' use OxControlCore's transient paint offset to place them in the parent form.

Private Const CLIENT_LEFT As Single = 6
Private Const CLIENT_TOP As Single = 18
Private Const CLIENT_RIGHT As Single = 6
Private Const CLIENT_BOTTOM As Single = 6

Private mCore As OxControlCore
Private mControls As Controls
Private mNextChildNodeId As Long

Private Sub Class_Initialize()
    Set mCore = New OxControlCore
    mCore.Init oxControlFrame
    Set mControls = New Controls
    mControls.Bind Me
    mNextChildNodeId = 1
End Sub

' --- IOxControl ---
Private Property Get IOxControl_Core() As OxControlCore
    Set IOxControl_Core = mCore
End Property

Public Property Get Core() As OxControlCore
    Set Core = mCore
End Property

Private Property Get IOxControl_HasChildren() As Boolean
    IOxControl_HasChildren = True
End Property

Private Property Get IOxControl_Children() As Controls
    Set IOxControl_Children = mControls
End Property

Private Sub IOxControl_Render(ByVal Surface As OxSceneBuilder)
    Surface.OpenNodeClipped mCore.NodeId, True, mCore.PaintParentId, mCore.ZOrder, _
        mCore.PaintLeft, mCore.PaintTop, mCore.Width, mCore.Height, mCore.Visible, _
        ClientPaintLeft(), ClientPaintTop(), ClientWidth(), ClientHeight()

    Dim I As Long
    Dim Child As IOxControl
    For I = 1 To mControls.Count
        Set Child = mControls.Item(I)
        Surface.AddChild Child.Core.NodeId
    Next I

    OxThemePaintControlFrame mCore, Surface
    If Len(mCore.DisplayText) > 0 Then
        Dim RunId As String
        RunId = mCore.RunId
        If Len(RunId) = 0 Then RunId = "0"
        OxThemePaintTextRun mCore, Surface, _
            mCore.PaintLeft + CLIENT_LEFT, mCore.PaintTop + 3, _
            mCore.Width - CLIENT_LEFT - CLIENT_RIGHT, 12, _
            RunId, "left", False, True, False
    End If
    Surface.CloseNode

    For I = 1 To mControls.Count
        Set Child = mControls.Item(I)
        Child.Core.SetRenderOffset ClientPaintLeft(), ClientPaintTop()
        Child.Core.SetRenderParentId mCore.NodeId
        Child.Render Surface
        Child.Core.ClearDirty
    Next I
End Sub

' --- User-facing properties ---
Public Property Get Controls() As Controls
    Set Controls = mControls
End Property

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

Public Function Diagnostics() As String
    Diagnostics = _
        "caption=" & mCore.DisplayText & _
        ";children=" & CStr(mControls.Count) & _
        ";client_left=" & CStr(CLIENT_LEFT) & _
        ";client_top=" & CStr(CLIENT_TOP) & _
        ";capabilities=" & mCore.CapabilityDescriptor
End Function

' --- IOxControl reducer input surface ---
Private Sub IOxControl_OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
End Sub

Private Sub IOxControl_OnMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
End Sub

Private Sub IOxControl_OnMouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
End Sub

Private Sub IOxControl_OnClick()
End Sub

Private Property Get IOxControl_SupportsClick() As Boolean
    IOxControl_SupportsClick = False
End Property

Private Property Get IOxControl_HasPressedVisual() As Boolean
    IOxControl_HasPressedVisual = False
End Property

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
    IOxControl_AccessibilityRole = "group"
End Property

Private Property Get IOxControl_AccessibilityName() As String
    IOxControl_AccessibilityName = mCore.Name
End Property

Private Property Get IOxControl_AccessibilityValue() As String
    IOxControl_AccessibilityValue = mCore.DisplayText
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
    IOxControl_AccessibilityPatterns = "container"
End Property

Private Property Get IOxControl_AccessibilityRowCount() As Long
    IOxControl_AccessibilityRowCount = 0
End Property

Private Property Get IOxControl_AccessibilityColumnCount() As Long
    IOxControl_AccessibilityColumnCount = 0
End Property

' --- Child owner / invalidation host ---
Public Sub RegisterControl(ByVal Control As IOxControl)
    Control.Core.Bind Me, Control
    Control.Core.NodeId = mCore.NodeId * 1000 + mNextChildNodeId
    mNextChildNodeId = mNextChildNodeId + 1
    mCore.MarkDirty
    mCore.MarkInteractionDirty
End Sub

Public Sub UnregisterControl(ByVal Control As IOxControl)
    Control.Core.Unbind
    mCore.MarkDirty
    mCore.MarkInteractionDirty
End Sub

Private Sub IOxControlContainer_RegisterControl(ByVal Control As IOxControl)
    RegisterControl Control
End Sub

Private Sub IOxControlContainer_UnregisterControl(ByVal Control As IOxControl)
    UnregisterControl Control
End Sub

Private Sub IOxControlHost_OnControlInvalidated(ByVal Control As IOxControl)
    mCore.MarkDirty
End Sub

Private Sub IOxControlHost_OnInteractionInvalidated(ByVal Control As IOxControl)
    mCore.MarkInteractionDirty
End Sub

Private Function ClientPaintLeft() As Single
    ClientPaintLeft = mCore.PaintLeft + CLIENT_LEFT
End Function

Private Function ClientPaintTop() As Single
    ClientPaintTop = mCore.PaintTop + CLIENT_TOP
End Function

Private Function ClientWidth() As Single
    ClientWidth = mCore.Width - CLIENT_LEFT - CLIENT_RIGHT
    If ClientWidth < 1 Then ClientWidth = 1
End Function

Private Function ClientHeight() As Single
    ClientHeight = mCore.Height - CLIENT_TOP - CLIENT_BOTTOM
    If ClientHeight < 1 Then ClientHeight = 1
End Function
