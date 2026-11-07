Option Explicit
Implements IOxControl

' Representative SpinButton for the W009 timer/repeat spike. It owns value, range,
' pressed half, and event order in VBA. HostServices owns the timer clock; form fixtures
' call PerformRepeatTick when the auto-repeat slot fires.

Public Event Change()
Public Event SpinUp()
Public Event SpinDown()
Public Event MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
Public Event KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
Public Event [Exit](ByVal Cancel As ReturnBoolean)
Public Event Enter()

Private Const OX_BUTTON_LEFT As Integer = 1
Private Const OX_KEY_UP As Integer = 38
Private Const OX_KEY_DOWN As Integer = 40

Private mCore As OxControlCore
Private mValue As Long
Private mMin As Long
Private mMax As Long
Private mSmallChange As Long
Private mPressedDirection As Long
Private mFocused As Boolean
Private mEditDirty As Boolean

Private Sub Class_Initialize()
    Set mCore = Nothing
    Set mCore = New OxControlCore
    mCore.Init oxControlSpinButton
    mValue = 0
    mMin = 0
    mMax = 100
    mSmallChange = 1
    mPressedDirection = 0
    mFocused = False
    mEditDirty = False
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

    Dim MidY As Single
    MidY = mCore.PaintTop + (mCore.Height / 2)
    Surface.Line mCore.PaintLeft, MidY, mCore.PaintLeft + mCore.Width, MidY, _
        OxThemeEdgeShadow(), 255, 1

    PaintArrow Surface, 1
    PaintArrow Surface, -1

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

Public Property Get Value() As Long
    Value = mValue
End Property
Public Property Let Value(ByVal NewValue As Long)
    If NewValue < mMin Or NewValue > mMax Then Err.Raise 380, "SpinButton", "Invalid property value"
    SetValue NewValue, False, 0
End Property

Public Property Get Min() As Long
    Min = mMin
End Property
Public Property Let Min(ByVal NewValue As Long)
    mMin = NewValue
    If mMax < mMin Then mMax = mMin
    SetValue mValue, False, 0
End Property

Public Property Get Max() As Long
    Max = mMax
End Property
Public Property Let Max(ByVal NewValue As Long)
    mMax = NewValue
    If mMin > mMax Then mMin = mMax
    SetValue mValue, False, 0
End Property

Public Property Get SmallChange() As Long
    SmallChange = mSmallChange
End Property
Public Property Let SmallChange(ByVal NewValue As Long)
    If NewValue < 1 Then NewValue = 1
    mSmallChange = NewValue
End Property

Public Property Get PressedDirection() As Long
    PressedDirection = mPressedDirection
End Property

Public Function Diagnostics() As String
    Diagnostics = _
        "value=" & CStr(mValue) & _
        ";min=" & CStr(mMin) & _
        ";max=" & CStr(mMax) & _
        ";small_change=" & CStr(mSmallChange) & _
        ";pressed_direction=" & CStr(mPressedDirection) & _
        ";dirty=" & CStr(mEditDirty) & _
        ";enabled=" & CStr(mCore.Enabled) & _
        ";visible=" & CStr(mCore.Visible) & _
        ";capabilities=" & mCore.CapabilityDescriptor
End Function

' Called by a form-document when HostServices reports timer.fire:auto_repeat.
Public Function PerformRepeatTick(ByVal Fires As Long) As String
    Dim I As Long
    For I = 1 To Fires
        If mPressedDirection <> 0 And mCore.Enabled And mCore.Visible Then
            StepBy mPressedDirection, True
        End If
    Next I
    PerformRepeatTick = Diagnostics
End Function

' --- IOxControl reducer input surface ---
Private Sub IOxControl_OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseDown(Button, Shift, X, Y)
    If Button <> OX_BUTTON_LEFT Then Exit Sub

    If Y < (mCore.Height / 2) Then
        mPressedDirection = 1
    Else
        mPressedDirection = -1
    End If
    mCore.MarkDirty
    StepBy mPressedDirection, True
End Sub

Private Sub IOxControl_OnMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseUp(Button, Shift, X, Y)
    If mPressedDirection <> 0 Then
        mPressedDirection = 0
        mCore.MarkDirty
    End If
End Sub

Private Sub IOxControl_OnMouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
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
            Case OX_KEY_UP
                StepBy 1, True
            Case OX_KEY_DOWN
                StepBy -1, True
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
    IOxControl_AccessibilityRole = "spinbutton"
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

Private Sub StepBy(ByVal Direction As Long, ByVal FromUser As Boolean)
    If Direction > 0 Then
        SetValue mValue + mSmallChange, FromUser, 1
    ElseIf Direction < 0 Then
        SetValue mValue - mSmallChange, FromUser, -1
    End If
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

Private Sub SetValue(ByVal NewValue As Long, ByVal FromUser As Boolean, ByVal Direction As Long)
    If NewValue < mMin Then NewValue = mMin
    If NewValue > mMax Then NewValue = mMax
    If mValue = NewValue Then Exit Sub

    mValue = NewValue
    If FromUser Then
        If Direction > 0 Then
            RaiseEvent SpinUp
        ElseIf Direction < 0 Then
            RaiseEvent SpinDown
        End If
        mEditDirty = True
    End If
    RaiseEvent Change
    mCore.MarkDirty
End Sub

Private Sub PaintArrow(ByVal Surface As OxSceneBuilder, ByVal Direction As Long)
    Dim TopY As Single, BottomY As Single, CenterX As Single, CenterY As Single
    If Direction > 0 Then
        TopY = mCore.PaintTop
        BottomY = mCore.PaintTop + (mCore.Height / 2)
    Else
        TopY = mCore.PaintTop + (mCore.Height / 2)
        BottomY = mCore.PaintTop + mCore.Height
    End If
    CenterX = mCore.PaintLeft + (mCore.Width / 2)
    CenterY = (TopY + BottomY) / 2

    Dim Fill As Long
    Fill = OxThemeResolveText(mCore)
    If Direction > 0 Then
        Surface.Polygon Fill, 255, _
            CenterX, CenterY - 4, _
            CenterX - 4, CenterY + 3, _
            CenterX + 4, CenterY + 3
    Else
        Surface.Polygon Fill, 255, _
            CenterX, CenterY + 4, _
            CenterX - 4, CenterY - 3, _
            CenterX + 4, CenterY - 3
    End If
End Sub
