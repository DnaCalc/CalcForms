Option Explicit
Implements IOxControl

' Representative MSForms-shaped Image control. The object model owns the picture
' reference and sizing policy; rendering emits a control-blind DrawImage primitive
' with an opaque handle. Real decoded pixels stay behind the Rust image service lane.

Public Event Click()
Public Event MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)

Private Const fmPictureSizeModeClip As Long = 0
Private Const fmPictureSizeModeStretch As Long = 1
Private Const fmPictureSizeModeZoom As Long = 3

Private mCore As OxControlCore
Private mPicture As String
Private mPictureOffset As Long
Private mPictureSha256 As String
Private mPictureHandle As String
Private mPictureSizeMode As Long

Private Sub Class_Initialize()
    Set mCore = New OxControlCore
    mCore.Init oxControlImage
    mPicture = ""
    mPictureOffset = 0
    mPictureSha256 = ""
    mPictureHandle = ""
    mPictureSizeMode = fmPictureSizeModeStretch
End Sub

' --- IOxControl ---
Private Property Get IOxControl_Core() As OxControlCore
    Set IOxControl_Core = mCore
End Property

Public Property Get Core() As OxControlCore
    Set Core = mCore
End Property

Private Sub IOxControl_Render(ByVal Surface As OxSceneBuilder)
    Surface.OpenNode mCore.NodeId, True, mCore.PaintParentId, mCore.ZOrder, _
        mCore.PaintLeft, mCore.PaintTop, mCore.Width, mCore.Height, mCore.Visible

    OxThemePaintControlFrame mCore, Surface
    If Len(mPictureHandle) > 0 Then
        Dim Inset As Single
        If mCore.BorderStyle = fmBorderStyleSingle Then Inset = 1 Else Inset = 0
        Dim DstW As Single, DstH As Single
        DstW = mCore.Width - (Inset * 2)
        DstH = mCore.Height - (Inset * 2)
        If DstW < 1 Then DstW = 1
        If DstH < 1 Then DstH = 1
        Surface.DrawImage mPictureHandle, _
            0, 0, DstW, DstH, _
            mCore.PaintLeft + Inset, mCore.PaintTop + Inset, DstW, DstH, _
            DrawMode()
    End If

    Surface.CloseNode
End Sub

Private Property Get IOxControl_HasChildren() As Boolean
    IOxControl_HasChildren = False
End Property

Private Property Get IOxControl_Children() As Controls
    Set IOxControl_Children = Nothing
End Property

' --- User-facing properties ---
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

Public Property Get Picture() As String
    Picture = mPicture
End Property
Public Property Let Picture(ByVal Value As String)
    If mPicture <> Value Then
        mPicture = Value
        mCore.MarkDirty
    End If
End Property

Public Property Get PictureOffset() As Long
    PictureOffset = mPictureOffset
End Property
Public Property Let PictureOffset(ByVal Value As Long)
    If mPictureOffset <> Value Then
        mPictureOffset = Value
        mCore.MarkDirty
    End If
End Property

Public Property Get PictureSha256() As String
    PictureSha256 = mPictureSha256
End Property
Public Property Let PictureSha256(ByVal Value As String)
    If mPictureSha256 <> Value Then
        mPictureSha256 = Value
        mCore.MarkDirty
    End If
End Property

Public Property Get PictureHandle() As String
    PictureHandle = mPictureHandle
End Property
Public Property Let PictureHandle(ByVal Value As String)
    If mPictureHandle <> Value Then
        mPictureHandle = Value
        mCore.MarkDirty
    End If
End Property

Public Property Get PictureSizeMode() As Long
    PictureSizeMode = mPictureSizeMode
End Property
Public Property Let PictureSizeMode(ByVal Value As Long)
    If mPictureSizeMode <> Value Then
        mPictureSizeMode = Value
        mCore.MarkDirty
    End If
End Property

Public Function Diagnostics() As String
    Diagnostics = _
        "picture=" & mPicture & _
        ";offset=" & CStr(mPictureOffset) & _
        ";sha256=" & mPictureSha256 & _
        ";handle=" & mPictureHandle & _
        ";size_mode=" & CStr(mPictureSizeMode) & _
        ";draw_mode=" & DrawMode() & _
        ";capabilities=" & mCore.CapabilityDescriptor
End Function

Public Sub SetPictureReference( _
        ByVal Path As String, _
        ByVal Offset As Long, _
        ByVal BytesSha256 As String, _
        ByVal Handle As String)
    mPicture = Path
    mPictureOffset = Offset
    mPictureSha256 = BytesSha256
    mPictureHandle = Handle
    mCore.MarkDirty
End Sub

' --- Runtime-facing input surface ---
Public Sub PerformClick()
    RaiseEvent Click
End Sub

Public Sub PerformMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseDown(Button, Shift, X, Y)
End Sub

Public Sub PerformMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseUp(Button, Shift, X, Y)
End Sub

' --- IOxControl reducer input surface ---
Private Sub IOxControl_OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    PerformMouseDown Button, Shift, X, Y
End Sub

Private Sub IOxControl_OnMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    PerformMouseUp Button, Shift, X, Y
End Sub

Private Sub IOxControl_OnMouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
End Sub

Private Sub IOxControl_OnClick()
    PerformClick
End Sub

Private Property Get IOxControl_SupportsClick() As Boolean
    IOxControl_SupportsClick = mCore.SupportsClick
End Property

Private Property Get IOxControl_HasPressedVisual() As Boolean
    IOxControl_HasPressedVisual = mCore.HasPressedVisual
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
    IOxControl_AccessibilityRole = "image"
End Property

Private Property Get IOxControl_AccessibilityName() As String
    IOxControl_AccessibilityName = mCore.Name
End Property

Private Property Get IOxControl_AccessibilityValue() As String
    IOxControl_AccessibilityValue = mPicture
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
    IOxControl_AccessibilityPatterns = "image,invoke"
End Property

Private Property Get IOxControl_AccessibilityRowCount() As Long
    IOxControl_AccessibilityRowCount = 0
End Property

Private Property Get IOxControl_AccessibilityColumnCount() As Long
    IOxControl_AccessibilityColumnCount = 0
End Property

Private Function DrawMode() As String
    Select Case mPictureSizeMode
        Case fmPictureSizeModeClip
            DrawMode = "clip"
        Case fmPictureSizeModeZoom
            DrawMode = "zoom"
        Case Else
            DrawMode = "stretch"
    End Select
End Function
