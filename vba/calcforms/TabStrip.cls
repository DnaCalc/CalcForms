Option Explicit
Implements IOxControl

' W009 TabStrip local lane. VBA owns the Tabs collection, selected index, input,
' event ordering, diagnostics, and accessibility; full MSForms Tab metadata,
' style variants, and exact oracle pixel parity remain later blockers.

Public Event Change()
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
Private Const TAB_HEIGHT As Single = 15
Private Const TAB_PADDING As Single = 10.5

Private mCore As OxControlCore
Private mTabs As Tabs
Private mValue As Long
Private mFocused As Boolean
Private mEditDirty As Boolean

Private Sub Class_Initialize()
    Set mCore = Nothing
    Set mTabs = Nothing
    Set mCore = New OxControlCore
    mCore.Init oxControlTabStrip
    Set mTabs = New Tabs
    mTabs.Init Me
    mValue = -1
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
    Surface.OpenNodeClipped mCore.NodeId, True, mCore.PaintParentId, mCore.ZOrder, _
        mCore.PaintLeft, mCore.PaintTop, mCore.Width, mCore.Height, mCore.Visible, _
        mCore.PaintLeft, mCore.PaintTop, mCore.Width, mCore.Height

    Surface.FillRect mCore.PaintLeft, mCore.PaintTop + TAB_HEIGHT, _
        mCore.Width, mCore.Height - TAB_HEIGHT, OxThemeFaceColor(oxControlFrame, False, mCore.Enabled), 255
    Surface.DrawEdge mCore.PaintLeft, mCore.PaintTop + TAB_HEIGHT, _
        mCore.Width, mCore.Height - TAB_HEIGHT, "raised", OxThemeEdgeLight(), OxThemeEdgeShadow()

    Dim I As Long
    For I = 0 To mTabs.Count - 1
        PaintTab Surface, I
    Next I

    If mFocused And mCore.Enabled Then
        Surface.StrokeRect mCore.PaintLeft, mCore.PaintTop, mCore.Width, TAB_HEIGHT, _
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

Public Property Get Tabs() As Tabs
    Set Tabs = mTabs
End Property

Public Property Get Value() As Long
    Value = mValue
End Property
Public Property Let Value(ByVal NewValue As Long)
    SetValue NewValue, False
End Property

Public Property Get ListIndex() As Long
    ListIndex = mValue
End Property
Public Property Let ListIndex(ByVal NewValue As Long)
    Value = NewValue
End Property

Public Property Get SelectedCaption() As String
    SelectedCaption = mTabs.CaptionAt(mValue)
End Property

Public Function Diagnostics() As String
    Diagnostics = _
        "count=" & CStr(mTabs.Count) & _
        ";value=" & CStr(mValue) & _
        ";caption=" & SelectedCaption & _
        ";tabs=" & mTabs.JoinedCaptions("|") & _
        ";dirty=" & CStr(mEditDirty) & _
        ";capabilities=" & mCore.CapabilityDescriptor
End Function

Public Sub NotifyTabAdded()
    If mValue < 0 Then mValue = 0
    SyncCaptions
End Sub

Public Sub NotifyTabChanged()
    SyncCaptions
End Sub

Public Sub NotifyTabsCleared()
    mValue = -1
    SyncCaptions
End Sub

Private Sub SyncCaptions()
    mCore.DisplayText = mTabs.JoinedCaptions(vbLf)
    Dim Parts As Collection, I As Long
    Set Parts = New Collection
    For I = 0 To mTabs.Count - 1
        Parts.Add mTabs.CaptionAt(I)
    Next I
    mCore.SetTextParts Parts
    mCore.MarkDirty
End Sub

Private Sub IOxControl_OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseDown(Button, Shift, X, Y)
    If Button <> OX_BUTTON_LEFT Then Exit Sub
    If Y >= 0 And Y < TAB_HEIGHT Then
        Dim Index As Long
        Index = TabIndexFromX(X)
        If Index >= 0 Then SelectFromUser Index
    End If
End Sub

Private Sub IOxControl_OnMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseUp(Button, Shift, X, Y)
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
    Dim Post As Integer
    Post = PerformKeyDown(KeyCode, Shift)
    If Post <> 0 Then
        Select Case Post
            Case OX_KEY_LEFT, OX_KEY_UP
                MoveSelection -1
            Case OX_KEY_RIGHT, OX_KEY_DOWN
                MoveSelection 1
            Case OX_KEY_HOME
                SelectFromUser 0
            Case OX_KEY_END
                SelectFromUser mTabs.Count - 1
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
    IOxControl_AccessibilityRole = "tabstrip"
End Property

Private Property Get IOxControl_AccessibilityName() As String
    IOxControl_AccessibilityName = mCore.Name
End Property

Private Property Get IOxControl_AccessibilityValue() As String
    IOxControl_AccessibilityValue = SelectedCaption
End Property

Private Property Get IOxControl_AccessibilitySelected() As Boolean
    IOxControl_AccessibilitySelected = (mValue >= 0)
End Property

Private Property Get IOxControl_AccessibilitySelectionStart() As Long
    IOxControl_AccessibilitySelectionStart = mValue
End Property

Private Property Get IOxControl_AccessibilitySelectionLength() As Long
    If mValue >= 0 Then IOxControl_AccessibilitySelectionLength = 1
End Property

Private Property Get IOxControl_AccessibilitySelectionText() As String
    IOxControl_AccessibilitySelectionText = SelectedCaption
End Property

Private Property Get IOxControl_AccessibilityPatterns() As String
    IOxControl_AccessibilityPatterns = "selection,value"
End Property

Private Property Get IOxControl_AccessibilityRowCount() As Long
    IOxControl_AccessibilityRowCount = mTabs.Count
End Property

Private Property Get IOxControl_AccessibilityColumnCount() As Long
    IOxControl_AccessibilityColumnCount = 1
End Property

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

Private Sub MoveSelection(ByVal Delta As Long)
    If mTabs.Count = 0 Then Exit Sub
    Dim NextIndex As Long
    If mValue < 0 Then
        NextIndex = 0
    Else
        NextIndex = mValue + Delta
        If NextIndex < 0 Then NextIndex = mTabs.Count - 1
        If NextIndex >= mTabs.Count Then NextIndex = 0
    End If
    SelectFromUser NextIndex
End Sub

Private Sub SelectFromUser(ByVal NewValue As Long)
    SetValue NewValue, True
End Sub

Private Sub SetValue(ByVal NewValue As Long, ByVal FromUser As Boolean)
    If mTabs.Count = 0 Then NewValue = -1
    If NewValue < 0 Then NewValue = -1
    If NewValue >= mTabs.Count Then NewValue = mTabs.Count - 1
    If mValue = NewValue Then Exit Sub

    mValue = NewValue
    If FromUser Then
        mEditDirty = True
        RaiseEvent Change
    End If
    mCore.MarkDirty
End Sub

Private Function TabIndexFromX(ByVal X As Single) As Long
    TabIndexFromX = -1
    If X < 0 Then Exit Function
    Dim I As Long, RightX As Single
    For I = 0 To mTabs.Count - 1
        RightX = RightX + TabWidth(I)
        If X < RightX Then
            TabIndexFromX = I
            Exit Function
        End If
    Next I
End Function

Private Function TabWidth(ByVal Index As Long) As Single
    TabWidth = mCore.TextPartWidth(Index) + TAB_PADDING
End Function

Private Sub PaintTab(ByVal Surface As OxSceneBuilder, ByVal Index As Long)
    Dim W As Single
    W = TabWidth(Index)
    Dim X As Single, I As Long
    X = mCore.PaintLeft
    For I = 0 To Index - 1
        X = X + TabWidth(I)
    Next I
    Dim Selected As Boolean
    Selected = (Index = mValue)
    Dim TopY As Single
    TopY = mCore.PaintTop + 2.25
    If Selected Then TopY = mCore.PaintTop + 0.75

    Surface.FillRect X, TopY, W, mCore.PaintTop + TAB_HEIGHT - TopY, OxThemeFormBackColor(), 255
    Surface.DrawEdge X, TopY, W, mCore.PaintTop + TAB_HEIGHT - TopY, "raised", OxThemeEdgeLight(), OxThemeEdgeShadow()
    If Selected Then Surface.FillRect X + 1.5, mCore.PaintTop + TAB_HEIGHT - 1.5, W - 3, 3, OxThemeFormBackColor(), 255

    Dim RunId As String
    RunId = mCore.TextPartRunId(Index)
    If Len(RunId) = 0 Then RunId = "0"
    OxThemePaintTextRun mCore, Surface, X + 1.5, TopY + 1.5, W - 3, mCore.TextPartHeight(Index), _
        RunId, "center", False, True, False
End Sub
