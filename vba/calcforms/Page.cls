Option Explicit
Implements IOxControl
Implements IOxControlHost
Implements IOxControlContainer

' Representative MSForms Page object owned by a MultiPage Pages collection.
' A Page is a container: its child controls keep page-local coordinates while
' render/input use the Page client origin supplied by MultiPage.

Private mOwner As MultiPage
Private mCore As OxControlCore
Private mControls As Controls
Private mIndex As Long

Private Sub Class_Initialize()
    Set mOwner = Nothing
    Set mCore = Nothing
    Set mControls = Nothing
    Set mCore = New OxControlCore
    mCore.Init oxControlPage
    mCore.SetChildClipMargins 0, 0, 0, 0
    Set mControls = New Controls
    mControls.Bind Me
End Sub

Public Sub Init(ByVal Owner As MultiPage, ByVal Index As Long, ByVal Caption As String)
    Set mOwner = Owner
    mIndex = Index
    mCore.Name = Owner.Core.Name & ".Page" & CStr(Index)
    mCore.DisplayText = Caption
End Sub

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
        mCore.ChildClipLeft, mCore.ChildClipTop, mCore.ChildClipWidth, mCore.ChildClipHeight

    Dim I As Long
    Dim Child As IOxControl
    For I = 1 To mControls.Count
        Set Child = mControls.Item(I)
        Surface.AddChild Child.Core.NodeId
    Next I

    Surface.FillRect mCore.PaintLeft, mCore.PaintTop, _
        mCore.Width, mCore.Height, OxThemeFaceColor(oxControlFrame, False, mCore.Enabled), 255
    Surface.CloseNode

    For I = 1 To mControls.Count
        Set Child = mControls.Item(I)
        Child.Core.SetRenderOffset mCore.ChildClipLeft, mCore.ChildClipTop
        Child.Core.SetRenderParentId mCore.NodeId
        Child.Render Surface
        Child.Core.ClearDirty
    Next I
End Sub

Public Property Get Controls() As Controls
    Set Controls = mControls
End Property

Public Property Get Index() As Long
    Index = mIndex
End Property

Public Sub SetIndex(ByVal Value As Long)
    mIndex = Value
    mCore.Name = mOwner.Core.Name & ".Page" & CStr(Value)
End Sub

Public Property Get Caption() As String
    Caption = mCore.DisplayText
End Property
Public Property Let Caption(ByVal Value As String)
    mCore.DisplayText = Value
    mOwner.NotifyPageChanged
End Property

Public Property Get Selected() As Boolean
    Selected = (mOwner.Value = mIndex)
End Property
Public Property Let Selected(ByVal Value As Boolean)
    If Value Then mOwner.Value = mIndex
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
        "index=" & CStr(mIndex) & _
        ";caption=" & Caption & _
        ";selected=" & CStr(Selected) & _
        ";children=" & CStr(mControls.Count) & _
        ";capabilities=" & mCore.CapabilityDescriptor
End Function

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
    IOxControl_AccessibilityRole = "page"
End Property

Private Property Get IOxControl_AccessibilityName() As String
    IOxControl_AccessibilityName = mCore.Name
End Property

Private Property Get IOxControl_AccessibilityValue() As String
    IOxControl_AccessibilityValue = Caption
End Property

Private Property Get IOxControl_AccessibilitySelected() As Boolean
    IOxControl_AccessibilitySelected = Selected
End Property

Private Property Get IOxControl_AccessibilitySelectionStart() As Long
    IOxControl_AccessibilitySelectionStart = mIndex
End Property

Private Property Get IOxControl_AccessibilitySelectionLength() As Long
    If Selected Then IOxControl_AccessibilitySelectionLength = 1
End Property

Private Property Get IOxControl_AccessibilitySelectionText() As String
    If Selected Then IOxControl_AccessibilitySelectionText = Caption
End Property

Private Property Get IOxControl_AccessibilityPatterns() As String
    IOxControl_AccessibilityPatterns = "container"
End Property

Private Property Get IOxControl_AccessibilityRowCount() As Long
    IOxControl_AccessibilityRowCount = mControls.Count
End Property

Private Property Get IOxControl_AccessibilityColumnCount() As Long
    IOxControl_AccessibilityColumnCount = 1
End Property

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

Private Sub IOxControlHost_OnInteractionInvalidated(ByVal Control As IOxControl)
    mCore.MarkInteractionDirty
End Sub
