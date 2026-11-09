Option Explicit
Implements IOxControl
Implements IOxControlHost
Implements IOxControlContainer

' W009 MultiPage local lane. VBA owns the Pages/Page collection, selected page,
' page-local child controls, focus scope, diagnostics, and accessibility. Full
' serialized page-item materialization and exact MSForms visual/event parity are
' explicit later blockers.

Public Event Change()
Public Event MouseDown(ByVal Index As Long, ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseUp(ByVal Index As Long, ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
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
Private Const CLIENT_LEFT As Single = 1.5
Private Const CLIENT_RIGHT As Single = 1.5
Private Const CLIENT_BOTTOM As Single = 1.5
Private Const TAB_PADDING As Single = 9

Private mCore As OxControlCore
Private mPages As Pages
Private mPageControls As Controls
Private mValue As Long
Private mFocused As Boolean
Private mClientFocus As Boolean ' focus sits on the page client, not the header row
Private mEditDirty As Boolean

Private Sub Class_Initialize()
    Set mCore = Nothing
    Set mPages = Nothing
    Set mPageControls = Nothing
    Set mCore = New OxControlCore
    mCore.Init oxControlMultiPage
    mCore.SetChildClipMargins CLIENT_LEFT, TAB_HEIGHT + 0.75, CLIENT_RIGHT, CLIENT_BOTTOM
    Set mPages = New Pages
    mPages.Init Me
    Set mPageControls = New Controls
    mPageControls.Bind Me
    mValue = -1
    mFocused = False
    mClientFocus = False
    mEditDirty = False
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
    Set IOxControl_Children = mPageControls
End Property

Private Sub IOxControl_Render(ByVal Surface As OxSceneBuilder)
    SyncPageGeometry

    Surface.OpenNodeClipped mCore.NodeId, True, mCore.PaintParentId, mCore.ZOrder, _
        mCore.PaintLeft, mCore.PaintTop, mCore.Width, mCore.Height, mCore.Visible, _
        mCore.PaintLeft, mCore.PaintTop, mCore.Width, mCore.Height

    Dim SelectedPage As Page
    Set SelectedPage = CurrentPage()
    If Not SelectedPage Is Nothing Then Surface.AddChild SelectedPage.Core.NodeId

    Surface.FillRect mCore.PaintLeft, mCore.PaintTop + HeaderBodyTop(), _
        mCore.Width, mCore.Height - HeaderBodyTop(), OxThemeFaceColor(oxControlFrame, False, mCore.Enabled), 255
    Surface.DrawEdge mCore.PaintLeft, mCore.PaintTop + HeaderBodyTop(), _
        mCore.Width, mCore.Height - HeaderBodyTop(), "raised", OxThemeEdgeLight(), OxThemeEdgeShadow()

    Dim I As Long
    For I = 0 To mPages.Count - 1
        If I <> mValue Then PaintPageTab Surface, I
    Next I
    If mValue >= 0 Then PaintPageTab Surface, mValue

    If mFocused And Not mClientFocus And mCore.Enabled Then
        Surface.StrokeRect mCore.PaintLeft, mCore.PaintTop, mCore.Width, HeaderBodyTop(), _
            OxThemeFocusAdornerColor(), 255, 1
    End If

    Surface.CloseNode

    If Not SelectedPage Is Nothing Then
        SelectedPage.Core.SetRenderOffset mCore.PaintLeft, mCore.PaintTop
        SelectedPage.Core.SetRenderParentId mCore.NodeId
        Dim RenderPage As IOxControl
        Set RenderPage = SelectedPage
        RenderPage.Render Surface
        SelectedPage.Core.ClearDirty
    End If
End Sub

Public Property Get Pages() As Pages
    Set Pages = mPages
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
    SelectedCaption = mPages.CaptionAt(mValue)
End Property

Public Property Get SelectedPage() As Page
    Set SelectedPage = CurrentPage()
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
        "count=" & CStr(mPages.Count) & _
        ";value=" & CStr(mValue) & _
        ";caption=" & SelectedCaption & _
        ";pages=" & mPages.JoinedCaptions("|") & _
        ";selected_children=" & CStr(SelectedChildCount()) & _
        ";dirty=" & CStr(mEditDirty) & _
        ";capabilities=" & mCore.CapabilityDescriptor
End Function

Public Sub RegisterPage(ByVal Page As Page)
    Page.Core.Bind Me, Page
    Page.Core.NodeId = mCore.AllocateNodeId()
    mPageControls.AddExisting Page, Page.Core.Name
    If mValue < 0 Then mValue = 0
    NotifyPageChanged
End Sub

Public Sub NotifyPageChanged()
    SyncCaptions
    SyncPageGeometry
    mCore.MarkDirty
    mCore.MarkInteractionDirty
End Sub

Public Sub NotifyPagesCleared()
    mValue = -1
    Set mPageControls = New Controls
    mPageControls.Bind Me
    SyncCaptions
    mCore.MarkDirty
    mCore.MarkInteractionDirty
End Sub

Private Sub SyncCaptions()
    mCore.DisplayText = mPages.JoinedCaptions(vbLf)
    Dim Parts As Collection, I As Long
    Set Parts = New Collection
    For I = 0 To mPages.Count - 1
        Parts.Add mPages.CaptionAt(I)
    Next I
    mCore.SetTextParts Parts
End Sub

Private Sub IOxControl_OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseDown(PageMouseIndex(X, Y), Button, Shift, X, Y)
    If Button <> OX_BUTTON_LEFT Then Exit Sub
    If Y >= 0 And Y < HeaderBodyTop() + 1.5 Then
        Dim Index As Long
        Index = PageIndexFromX(X, Y)
        If Index >= 0 Then SelectFromUser Index
    End If
End Sub

Private Sub IOxControl_OnMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseUp(PageMouseIndex(X, Y), Button, Shift, X, Y)
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
                SelectFromUser mPages.Count - 1
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
            mClientFocus = False
            mCore.MarkDirty
        End If
    End If
End Function

' The interaction manager moves focus between the header row and the page client (two Tab
' stops, native round 13). The header focus adorner is drawn only while the header holds focus.
Friend Sub SetClientFocus(ByVal Value As Boolean)
    If mClientFocus = Value Then Exit Sub
    mClientFocus = Value
    mCore.MarkDirty
End Sub

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
    IOxControl_AccessibilityRole = "multipage"
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
    IOxControl_AccessibilityPatterns = "selection,container,value"
End Property

Private Property Get IOxControl_AccessibilityRowCount() As Long
    IOxControl_AccessibilityRowCount = mPages.Count
End Property

Private Property Get IOxControl_AccessibilityColumnCount() As Long
    IOxControl_AccessibilityColumnCount = 1
End Property

Public Sub RegisterControl(ByVal Control As IOxControl)
    Control.Core.Bind Me, Control
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
    If mPages.Count = 0 Then Exit Sub
    Dim NextIndex As Long
    If mValue < 0 Then
        NextIndex = 0
    Else
        NextIndex = mValue + Delta
        If NextIndex < 0 Then NextIndex = mPages.Count - 1
        If NextIndex >= mPages.Count Then NextIndex = 0
    End If
    SelectFromUser NextIndex
End Sub

Private Sub SelectFromUser(ByVal NewValue As Long)
    SetValue NewValue, True
End Sub

Private Sub SetValue(ByVal NewValue As Long, ByVal FromUser As Boolean)
    If mPages.Count = 0 Then NewValue = -1
    If NewValue < 0 Then NewValue = -1
    If NewValue >= mPages.Count Then NewValue = mPages.Count - 1
    If mValue = NewValue Then Exit Sub

    mValue = NewValue
    SyncPageGeometry
    If FromUser Then
        mEditDirty = True
    End If
    mCore.MarkDirty
    mCore.MarkInteractionDirty
    RaiseEvent Change
End Sub

Private Function CurrentPage() As Page
    If mValue < 0 Or mValue >= mPages.Count Then Exit Function
    Set CurrentPage = mPages.Item(mValue)
End Function

Private Function SelectedChildCount() As Long
    Dim P As Page
    Set P = CurrentPage()
    If Not P Is Nothing Then SelectedChildCount = P.Controls.Count
End Function

Private Sub SyncPageGeometry()
    Dim I As Long
    Dim P As Page
    For I = 0 To mPages.Count - 1
        Set P = mPages.Item(I)
        P.Left = CLIENT_LEFT
        P.Top = TAB_HEIGHT + 0.75
        P.Width = ClientWidth()
        P.Height = ClientHeight()
        P.Visible = (I = mValue)
        P.Enabled = mCore.Enabled
    Next I
End Sub

Private Function HeaderBodyTop() As Single
    Dim H As Single
    H = mCore.MeasuredHeight
    If H <= 0 Then H = mCore.FontSize + 1.5
    HeaderBodyTop = H + 4.5
End Function

Private Function PageTabLeft(ByVal Index As Long) As Single
    Dim I As Long
    PageTabLeft = 1.5
    For I = 0 To Index - 1
        PageTabLeft = PageTabLeft + PageTabWidth(I)
    Next I
End Function

Private Function PageMouseIndex(ByVal X As Single, ByVal Y As Single) As Long
    PageMouseIndex = PageIndexFromX(X, Y)
    If PageMouseIndex >= 0 Then Exit Function
    If X >= 0 And X < mCore.Width And Y >= HeaderBodyTop() + 1.5 And Y < mCore.Height Then PageMouseIndex = mValue
End Function

Private Function PageIndexFromX(ByVal X As Single, ByVal Y As Single) As Long
    PageIndexFromX = -1
    If X < 0 Or Y < 0 Then Exit Function
    Dim L As Single, R As Single, I As Long
    If mValue >= 0 Then
        L = PageTabLeft(mValue) - 1.5
        R = L + PageTabWidth(mValue) + 3
        If X >= L And X < R And Y < HeaderBodyTop() + 1.5 Then
            PageIndexFromX = mValue
            Exit Function
        End If
    End If
    If Y < 1.5 Or Y >= HeaderBodyTop() Then Exit Function
    For I = 0 To mPages.Count - 1
        L = PageTabLeft(I)
        If X >= L And X < L + PageTabWidth(I) Then
            PageIndexFromX = I
            Exit Function
        End If
    Next I
End Function

Private Function PageTabWidth(ByVal Index As Long) As Single
    PageTabWidth = mCore.TextPartWidth(Index) + TAB_PADDING
End Function

Private Sub PaintPageTab(ByVal Surface As OxSceneBuilder, ByVal Index As Long)
    Dim W As Single, X As Single, TopY As Single, BottomY As Single, TextTop As Single
    W = PageTabWidth(Index)
    X = mCore.PaintLeft + PageTabLeft(Index)
    TopY = mCore.PaintTop + 1.5
    BottomY = mCore.PaintTop + HeaderBodyTop()
    TextTop = mCore.PaintTop + 3
    If Index = mValue Then
        X = X - 1.5
        W = W + 3
        TopY = mCore.PaintTop
        BottomY = BottomY + 1.5
        TextTop = mCore.PaintTop + 1.5
    End If
    Surface.FillRect X, TopY, W, BottomY - TopY, OxThemeFormBackColor(), 255
    Surface.DrawEdge X, TopY, W, BottomY - TopY, "raised", OxThemeEdgeLight(), OxThemeEdgeShadow()
    If Index = mValue Then Surface.FillRect X + 1.5, BottomY - 1.5, W - 3, 3, OxThemeFormBackColor(), 255

    Dim RunId As String
    RunId = mCore.TextPartRunId(Index)
    If Len(RunId) = 0 Then RunId = "0"
    OxThemePaintTextRun mCore, Surface, X, TextTop, W, mCore.TextPartHeight(Index), _
        RunId, "center", False, True, False
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
