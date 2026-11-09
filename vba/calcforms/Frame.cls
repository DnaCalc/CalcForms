Option Explicit
Implements IOxControl
Implements IOxControlHost
Implements IOxControlContainer

Public Event MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)

' Representative MSForms-shaped Frame. The Frame is a control and a child owner:
' its children keep local Left/Top object-model coordinates, while render/input
' use OxControlCore's transient paint offset to place them in the parent form.

Private Const CLIENT_LEFT As Single = 1.5
Private Const CLIENT_RIGHT As Single = 1.5
Private Const CLIENT_BOTTOM As Single = 1.5

Private mCore As OxControlCore
Private mControls As Controls

Private Sub Class_Initialize()
    Set mCore = Nothing
    Set mControls = Nothing
    Set mCore = New OxControlCore
    mCore.Init oxControlFrame
    mCore.SetChildClipMargins CLIENT_LEFT, ClientTopMargin(), CLIENT_RIGHT, CLIENT_BOTTOM
    Set mControls = New Controls
    mControls.Bind Me
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
    mCore.SetChildClipMargins CLIENT_LEFT, ClientTopMargin(), CLIENT_RIGHT, CLIENT_BOTTOM
    ' The frame paint uses its whole site. Only the child group uses the client clip.
    Surface.OpenNodeClipped mCore.NodeId, True, mCore.PaintParentId, mCore.ZOrder, _
        mCore.PaintLeft, mCore.PaintTop, mCore.Width, mCore.Height, mCore.Visible, _
        mCore.PaintLeft, mCore.PaintTop, mCore.Width, mCore.Height
    Surface.AddChild ClientNodeId()

    Dim I As Long
    Dim Child As IOxControl
    Surface.FillRect mCore.PaintLeft, mCore.PaintTop, mCore.Width, mCore.Height, OxThemeResolveFace(mCore), 255
    Dim BorderTop As Single, BorderHeight As Single, EdgeName As String
    BorderTop = mCore.PaintTop + mCore.FontSize / 2
    BorderHeight = mCore.Height - mCore.FontSize / 2
    If BorderHeight < 1 Then BorderHeight = 1
    EdgeName = OxThemeEdgeName(mCore.SpecialEffect)
    If Len(EdgeName) > 0 Then
        Surface.DrawEdge mCore.PaintLeft, BorderTop, mCore.Width, BorderHeight, _
            EdgeName, OxThemeEdgeLight(), OxThemeEdgeShadow()
    ElseIf mCore.BorderStyle = fmBorderStyleSingle Then
        Surface.StrokeRect mCore.PaintLeft, BorderTop, mCore.Width, BorderHeight, OxThemeResolveBorder(mCore), 255, 1
    End If
    If Len(mCore.DisplayText) > 0 Then
        Dim RunId As String, CaptionWidth As Single, CaptionHeight As Single, TextWidth As Single
        RunId = mCore.RunId
        If Len(RunId) = 0 Then RunId = "0"
        ' Native caption exclusion has 3pt padding on each side. Text origin stays 10.5pt.
        CaptionWidth = mCore.MeasuredWidth + 6
        If CaptionWidth > mCore.Width - 15 Then CaptionWidth = mCore.Width - 15
        If CaptionWidth < 1 Then CaptionWidth = 1
        CaptionHeight = mCore.MeasuredHeight
        If CaptionHeight < 1 Then CaptionHeight = 1
        TextWidth = CaptionWidth - 4.5
        If TextWidth < 1 Then TextWidth = 1
        Surface.FillRect mCore.PaintLeft + 7.5, mCore.PaintTop, CaptionWidth, CaptionHeight + 1.5, OxThemeResolveFace(mCore), 255
        OxThemePaintTextRun mCore, Surface, _
            mCore.PaintLeft + 10.5, mCore.PaintTop + 0.75, _
            TextWidth, CaptionHeight, _
            RunId, "left", False, True, False
    End If
    Surface.CloseNode

    Surface.OpenNodeClipped ClientNodeId(), True, mCore.NodeId, 0, _
        ClientPaintLeft(), ClientPaintTop(), ClientWidth(), ClientHeight(), mCore.Visible, _
        ClientPaintLeft(), ClientPaintTop(), ClientWidth(), ClientHeight()
    For I = 1 To mControls.Count
        Set Child = mControls.Item(I)
        Surface.AddChild Child.Core.NodeId
    Next I
    Surface.CloseNode
    For I = 1 To mControls.Count
        Set Child = mControls.Item(I)
        Child.Core.SetRenderOffset ClientPaintLeft(), ClientPaintTop()
        Child.Core.SetRenderParentId ClientNodeId()
        Child.Render Surface
        Child.Core.ClearDirty
    Next I
End Sub

Private Function ClientNodeId() As Long
    ClientNodeId = mCore.NodeId * 1000 + 902
End Function

Private Function ClientTopMargin() As Single
    ' Owned Tahoma 8.25 Frame: InsideWidth=Width-3, InsideHeight=Height-7.15.
    ' The half-em plus border gives 5.625pt top, within 0.025pt of native rounding.
    ClientTopMargin = mCore.FontSize / 2 + 1.5
End Function

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
    mCore.Left = mCore.Twips(Value)
End Property

Public Property Get Top() As Single
    Top = mCore.Top
End Property
Public Property Let Top(ByVal Value As Single)
    mCore.Top = mCore.Twips(Value)
End Property

Public Property Get Width() As Single
    Width = mCore.Width
End Property
Public Property Let Width(ByVal Value As Single)
    If Value < 0 Then Err.Raise 380, "CalcForms", "Could not set the Width property. Invalid property value"
    mCore.Width = mCore.Twips(Value)
End Property

Public Property Get Height() As Single
    Height = mCore.Height
End Property
Public Property Let Height(ByVal Value As Single)
    If Value < 0 Then Err.Raise 380, "CalcForms", "Could not set the Height property. Invalid property value"
    mCore.Height = mCore.Twips(Value)
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
        ";client_left=" & CStr(mCore.ChildClipLeft) & _
        ";client_top=" & CStr(mCore.ChildClipTop) & _
        ";client_width=" & CStr(mCore.ChildClipWidth) & _
        ";client_height=" & CStr(mCore.ChildClipHeight) & _
        ";capabilities=" & mCore.CapabilityDescriptor
End Function

' --- IOxControl reducer input surface ---
Private Sub IOxControl_OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseDown(Button, Shift, X, Y)
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
    Control.Core.NodeId = mCore.AllocateNodeId()
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

Private Function IOxControlHost_AllocateNodeId() As Long
    IOxControlHost_AllocateNodeId = mCore.AllocateNodeId()
End Function

Private Function IOxControlHost_Zoom() As Long
    IOxControlHost_Zoom = mCore.HostZoom()
End Function

Private Sub IOxControlHost_OnInteractionInvalidated(ByVal Control As IOxControl)
    mCore.MarkInteractionDirty
End Sub

Private Function ClientPaintLeft() As Single
    ClientPaintLeft = mCore.ChildClipLeft
End Function

Private Function ClientPaintTop() As Single
    ClientPaintTop = mCore.ChildClipTop
End Function

Private Function ClientWidth() As Single
    ClientWidth = mCore.ChildClipWidth
End Function

Private Function ClientHeight() As Single
    ClientHeight = mCore.ChildClipHeight
End Function

' --- IControl members common to every control (native, round 14) ---
Public Property Get Tag() As String
    Tag = mCore.Tag
End Property
Public Property Let Tag(ByVal Value As String)
    mCore.Tag = Value
End Property

Public Property Get ControlTipText() As String
    ControlTipText = mCore.ControlTipText
End Property
Public Property Let ControlTipText(ByVal Value As String)
    mCore.ControlTipText = Value
End Property

Public Property Get HelpContextID() As Long
    HelpContextID = mCore.HelpContextID
End Property
Public Property Let HelpContextID(ByVal Value As Long)
    mCore.HelpContextID = Value
End Property

Public Property Get TabStop() As Boolean
    TabStop = mCore.TabStop
End Property
Public Property Let TabStop(ByVal Value As Boolean)
    mCore.TabStop = Value
End Property

Public Property Get TabIndex() As Integer
    TabIndex = mCore.TabIndexValue
End Property
Public Property Let TabIndex(ByVal Value As Integer)
    mCore.TabIndexValue = Value
End Property

Public Property Get Font() As Font
    Set Font = mCore.FontObject()
End Property
Public Property Set Font(ByVal Value As Font)
    mCore.FontObject().Assign Value
End Property
