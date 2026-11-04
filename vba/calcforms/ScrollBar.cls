Option Explicit
Implements IOxControl

' W009 ScrollBar local lane. VBA owns range, value, event order, hit zones, and
' thumb drag state; host timers/native repeat cadence remain a later blocker.

Public Event Change()
Public Event Scroll()
Public Event MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
Public Event KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
Public Event [Exit](ByVal Cancel As ReturnBoolean)
Public Event Enter()

Private Const OX_BUTTON_LEFT As Integer = 1
Private Const OX_KEY_LEFT As Integer = 37
Private Const OX_KEY_UP As Integer = 38
Private Const OX_KEY_RIGHT As Integer = 39
Private Const OX_KEY_DOWN As Integer = 40
Private Const OX_KEY_HOME As Integer = 36
Private Const OX_KEY_END As Integer = 35

Private mCore As OxControlCore
Private mValue As Long
Private mMin As Long
Private mMax As Long
Private mSmallChange As Long
Private mLargeChange As Long
Private mPressedPart As String
Private mDraggingThumb As Boolean
Private mFocused As Boolean
Private mEditDirty As Boolean

Private Sub Class_Initialize()
    Set mCore = Nothing
    Set mCore = New OxControlCore
    mCore.Init oxControlScrollBar
    mValue = 0
    mMin = 0
    mMax = 100
    mSmallChange = 1
    mLargeChange = 10
    mPressedPart = ""
    mDraggingThumb = False
    mFocused = False
    mEditDirty = False
End Sub

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

    Dim Btn As Single
    Btn = ButtonExtent()
    Dim TrackLeft As Single, TrackWidth As Single
    TrackLeft = mCore.PaintLeft + Btn
    TrackWidth = mCore.Width - (Btn * 2)
    If TrackWidth < 1 Then TrackWidth = 1

    Surface.FillRect TrackLeft, mCore.PaintTop + 2, TrackWidth, mCore.Height - 4, &HE8E8E8, 255
    Surface.DrawEdge mCore.PaintLeft, mCore.PaintTop, Btn, mCore.Height, ButtonEdge("left"), _
        OxThemeEdgeLight(), OxThemeEdgeShadow()
    Surface.DrawEdge mCore.PaintLeft + mCore.Width - Btn, mCore.PaintTop, Btn, mCore.Height, ButtonEdge("right"), _
        OxThemeEdgeLight(), OxThemeEdgeShadow()

    PaintArrow Surface, -1, mCore.PaintLeft + (Btn / 2), mCore.PaintTop + (mCore.Height / 2)
    PaintArrow Surface, 1, mCore.PaintLeft + mCore.Width - (Btn / 2), mCore.PaintTop + (mCore.Height / 2)

    Dim ThumbLeft As Single, ThumbWidth As Single
    ThumbWidth = ThumbExtent(TrackWidth)
    ThumbLeft = TrackLeft + ThumbOffset(TrackWidth, ThumbWidth)
    Surface.FillRect ThumbLeft, mCore.PaintTop + 2, ThumbWidth, mCore.Height - 4, _
        OxThemeFaceColor(oxControlScrollBar, (mPressedPart = "thumb"), mCore.Enabled), 255
    Surface.DrawEdge ThumbLeft, mCore.PaintTop + 2, ThumbWidth, mCore.Height - 4, ButtonEdge("thumb"), _
        OxThemeEdgeLight(), OxThemeEdgeShadow()

    If mFocused And mCore.Enabled Then
        Surface.StrokeRect mCore.PaintLeft, mCore.PaintTop, mCore.Width, mCore.Height, _
            OxThemeFocusAdornerColor(), 255, 1
    End If

    Surface.CloseNode
End Sub

Private Property Get IOxControl_HasChildren() As Boolean
    IOxControl_HasChildren = False
End Property

Private Property Get IOxControl_Children() As Controls
    Set IOxControl_Children = Nothing
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

Public Property Get Value() As Long
    Value = mValue
End Property
Public Property Let Value(ByVal NewValue As Long)
    SetValue NewValue, False
End Property

Public Property Get Min() As Long
    Min = mMin
End Property
Public Property Let Min(ByVal NewValue As Long)
    mMin = NewValue
    If mMax < mMin Then mMax = mMin
    SetValue mValue, False
    mCore.MarkDirty
End Property

Public Property Get Max() As Long
    Max = mMax
End Property
Public Property Let Max(ByVal NewValue As Long)
    mMax = NewValue
    If mMin > mMax Then mMin = mMax
    SetValue mValue, False
    mCore.MarkDirty
End Property

Public Property Get SmallChange() As Long
    SmallChange = mSmallChange
End Property
Public Property Let SmallChange(ByVal NewValue As Long)
    If NewValue < 1 Then NewValue = 1
    mSmallChange = NewValue
End Property

Public Property Get LargeChange() As Long
    LargeChange = mLargeChange
End Property
Public Property Let LargeChange(ByVal NewValue As Long)
    If NewValue < 1 Then NewValue = 1
    mLargeChange = NewValue
End Property

Public Property Get PressedPart() As String
    PressedPart = mPressedPart
End Property

Public Function Diagnostics() As String
    Diagnostics = _
        "value=" & CStr(mValue) & _
        ";min=" & CStr(mMin) & _
        ";max=" & CStr(mMax) & _
        ";small_change=" & CStr(mSmallChange) & _
        ";large_change=" & CStr(mLargeChange) & _
        ";pressed_part=" & mPressedPart & _
        ";dragging=" & CStr(mDraggingThumb) & _
        ";dirty=" & CStr(mEditDirty) & _
        ";enabled=" & CStr(mCore.Enabled) & _
        ";visible=" & CStr(mCore.Visible) & _
        ";capabilities=" & mCore.CapabilityDescriptor
End Function

Private Sub IOxControl_OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseDown(Button, Shift, X, Y)
    If Button <> OX_BUTTON_LEFT Then Exit Sub

    mPressedPart = PartFromX(X)
    mDraggingThumb = (mPressedPart = "thumb")
    mCore.MarkDirty

    Select Case mPressedPart
        Case "left"
            StepBy -mSmallChange
        Case "right"
            StepBy mSmallChange
        Case "page_left"
            StepBy -mLargeChange
        Case "page_right"
            StepBy mLargeChange
    End Select
End Sub

Private Sub IOxControl_OnMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseUp(Button, Shift, X, Y)
    If Len(mPressedPart) > 0 Or mDraggingThumb Then
        mPressedPart = ""
        mDraggingThumb = False
        mCore.MarkDirty
    End If
End Sub

Private Sub IOxControl_OnMouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    If Not mDraggingThumb Then Exit Sub
    SetValue ValueFromX(X), True
End Sub

Private Sub IOxControl_OnClick()
End Sub

Private Property Get IOxControl_SupportsClick() As Boolean
    IOxControl_SupportsClick = False
End Property

Private Property Get IOxControl_HasPressedVisual() As Boolean
    IOxControl_HasPressedVisual = mCore.HasPressedVisual
End Property

Private Function IOxControl_OnKeyDown(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    Dim Post As Integer
    Post = PerformKeyDown(KeyCode, Shift)
    If Post <> 0 Then
        Select Case Post
            Case OX_KEY_LEFT, OX_KEY_UP
                StepBy -mSmallChange
            Case OX_KEY_RIGHT, OX_KEY_DOWN
                StepBy mSmallChange
            Case OX_KEY_HOME
                SetValue mMin, True
            Case OX_KEY_END
                SetValue mMax, True
        End Select
    End If
    IOxControl_OnKeyDown = Post
End Function

Private Function IOxControl_OnKeyUp(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    IOxControl_OnKeyUp = PerformKeyUp(KeyCode, Shift)
End Function

Private Sub IOxControl_OnCharacterInput(ByVal Text As String)
End Sub

Private Sub IOxControl_OnEnter()
    If Not mFocused Then
        mFocused = True
        mCore.MarkDirty
    End If
    RaiseEvent Enter
End Sub

Private Function IOxControl_OnExit() As Boolean
    Dim Cancel As ReturnBoolean
    Set Cancel = New ReturnBoolean
    RaiseEvent [Exit](Cancel)
    IOxControl_OnExit = Cancel.Value
    If Not IOxControl_OnExit Then
        If mFocused Then
            mFocused = False
            mCore.MarkDirty
        End If
    End If
End Function

Private Function IOxControl_OnBeforeUpdate() As Boolean
    IOxControl_OnBeforeUpdate = False
End Function

Private Sub IOxControl_OnAfterUpdate()
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
    IOxControl_AccessibilityRole = "scrollbar"
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
    IOxControl_AccessibilityPatterns = "range,value"
End Property

Private Property Get IOxControl_AccessibilityRowCount() As Long
    IOxControl_AccessibilityRowCount = 0
End Property

Private Property Get IOxControl_AccessibilityColumnCount() As Long
    IOxControl_AccessibilityColumnCount = 0
End Property

Private Sub StepBy(ByVal Delta As Long)
    SetValue mValue + Delta, True
End Sub

Private Sub SetValue(ByVal NewValue As Long, ByVal FromUser As Boolean)
    If NewValue < mMin Then NewValue = mMin
    If NewValue > mMax Then NewValue = mMax
    If mValue = NewValue Then Exit Sub

    mValue = NewValue
    If FromUser Then
        RaiseEvent Scroll
        RaiseEvent Change
        mEditDirty = True
    End If
    mCore.MarkDirty
End Sub

Private Function PerformKeyDown(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    Dim MutableKey As ReturnInteger
    Set MutableKey = New ReturnInteger
    MutableKey.Value = KeyCode
    RaiseEvent KeyDown(MutableKey, Shift)
    PerformKeyDown = MutableKey.Value
End Function

Private Function PerformKeyUp(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    Dim MutableKey As ReturnInteger
    Set MutableKey = New ReturnInteger
    MutableKey.Value = KeyCode
    RaiseEvent KeyUp(MutableKey, Shift)
    PerformKeyUp = MutableKey.Value
End Function

Private Function ButtonExtent() As Single
    ButtonExtent = mCore.Height
    If ButtonExtent < 8 Then ButtonExtent = 8
    If ButtonExtent > mCore.Width / 2 Then ButtonExtent = mCore.Width / 2
End Function

Private Function ThumbExtent(ByVal TrackWidth As Single) As Single
    ThumbExtent = mCore.Height
    If ThumbExtent < 8 Then ThumbExtent = 8
    If ThumbExtent > TrackWidth Then ThumbExtent = TrackWidth
End Function

Private Function ThumbOffset(ByVal TrackWidth As Single, ByVal ThumbWidth As Single) As Single
    Dim Span As Single
    Span = TrackWidth - ThumbWidth
    If Span <= 0 Or mMax = mMin Then
        ThumbOffset = 0
    Else
        ThumbOffset = Span * CSng(mValue - mMin) / CSng(mMax - mMin)
    End If
End Function

Private Function PartFromX(ByVal X As Single) As String
    Dim Btn As Single
    Btn = ButtonExtent()
    If X < Btn Then
        PartFromX = "left"
        Exit Function
    End If
    If X >= mCore.Width - Btn Then
        PartFromX = "right"
        Exit Function
    End If

    Dim TrackWidth As Single, ThumbWidth As Single, ThumbLeftLocal As Single
    TrackWidth = mCore.Width - (Btn * 2)
    If TrackWidth < 1 Then TrackWidth = 1
    ThumbWidth = ThumbExtent(TrackWidth)
    ThumbLeftLocal = Btn + ThumbOffset(TrackWidth, ThumbWidth)
    If X >= ThumbLeftLocal And X <= ThumbLeftLocal + ThumbWidth Then
        PartFromX = "thumb"
    ElseIf X < ThumbLeftLocal Then
        PartFromX = "page_left"
    Else
        PartFromX = "page_right"
    End If
End Function

Private Function ValueFromX(ByVal X As Single) As Long
    Dim Btn As Single, TrackWidth As Single, ThumbWidth As Single, Span As Single
    Btn = ButtonExtent()
    TrackWidth = mCore.Width - (Btn * 2)
    If TrackWidth < 1 Then TrackWidth = 1
    ThumbWidth = ThumbExtent(TrackWidth)
    Span = TrackWidth - ThumbWidth
    If Span <= 0 Or mMax = mMin Then
        ValueFromX = mMin
        Exit Function
    End If

    Dim Pos As Single
    Pos = X - Btn - (ThumbWidth / 2)
    If Pos < 0 Then Pos = 0
    If Pos > Span Then Pos = Span
    ValueFromX = CLng(mMin + ((mMax - mMin) * (Pos / Span)))
End Function

Private Function ButtonEdge(ByVal Part As String) As String
    If mPressedPart = Part Then
        ButtonEdge = "sunken"
    Else
        ButtonEdge = "raised"
    End If
End Function

Private Sub PaintArrow(ByVal Surface As OxSceneBuilder, ByVal Direction As Long, ByVal CenterX As Single, ByVal CenterY As Single)
    Dim Fill As Long
    Fill = OxThemeResolveText(mCore)
    If Direction < 0 Then
        Surface.Polygon Fill, 255, _
            CenterX - 4, CenterY, _
            CenterX + 3, CenterY - 4, _
            CenterX + 3, CenterY + 4
    Else
        Surface.Polygon Fill, 255, _
            CenterX + 4, CenterY, _
            CenterX - 3, CenterY - 4, _
            CenterX - 3, CenterY + 4
    End If
End Sub
