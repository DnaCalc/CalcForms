Option Explicit
Implements IOxControl

' Representative MSForms-shaped ComboBox. The editable text, list collection,
' selected row, and dropdown state live in VBA. The renderer draws the edit field,
' drop button, and a representative popup surface; exact native popup behavior
' remains oracle-gated.

Public Event DropButtonClick()
Public Event Change()
Public Event Click()
Public Event MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
Public Event KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
Public Event KeyPress(ByVal KeyAscii As ReturnInteger)
Public Event [Exit](ByVal Cancel As ReturnBoolean)
Public Event Enter()
Public Event BeforeUpdate(ByVal Cancel As ReturnBoolean)
Public Event AfterUpdate()
Public Event BeforeDropOrPaste(ByVal Cancel As ReturnBoolean, ByVal Action As Integer, ByVal Shift As Integer)

Private Const OX_KEY_ENTER As Integer = 13
Private Const OX_KEY_ESCAPE As Integer = 27
Private Const OX_KEY_UP As Integer = 38
Private Const OX_KEY_DOWN As Integer = 40
Private Const OX_KEY_F4 As Integer = 115
Private Const OX_SHIFT_ALT As Integer = 4
Private Const BUTTON_WIDTH As Single = 18
Private Const TEXT_INSET_X As Single = 4
Private Const TEXT_INSET_Y As Single = 3
Private Const ROW_HEIGHT As Single = 14

Private mCore As OxControlCore
Private mItems As Collection
Private mListIndex As Long
Private mDropDownOpen As Boolean
Private mFocused As Boolean
Private mEditDirty As Boolean

Private Sub Class_Initialize()
    Set mCore = Nothing
    Set mItems = Nothing
    Set mCore = New OxControlCore
    mCore.Init oxControlComboBox
    Set mItems = New Collection
    mListIndex = -1
    mDropDownOpen = False
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
    OxThemePaintComboBox mCore, Surface, mListIndex, mFocused, mDropDownOpen, mItems.Count
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

Public Property Get Text() As String
    Text = mCore.DisplayText
End Property
Public Property Let Text(ByVal Value As String)
    mCore.DisplayText = Value
    mListIndex = FindItem(Value)
    mCore.MarkDirty
End Property

Public Property Get Value() As String
    Value = Text
End Property
Public Property Let Value(ByVal NewValue As String)
    Text = NewValue
End Property

Public Property Get ListCount() As Long
    ListCount = mItems.Count
End Property

Public Property Get ListIndex() As Long
    ListIndex = mListIndex
End Property
Public Property Let ListIndex(ByVal Value As Long)
    SetListIndex Value, False
End Property

Public Property Get List(ByVal Index As Long) As String
    If Index < 0 Or Index >= mItems.Count Then
        List = ""
    Else
        List = CStr(mItems.Item(Index + 1))
    End If
End Property

Public Property Get DropDownOpen() As Boolean
    DropDownOpen = mDropDownOpen
End Property

Public Sub AddItem(ByVal Item As String)
    mItems.Add Item
    mCore.MarkDirty
End Sub

Public Sub Clear()
    Set mItems = New Collection
    mListIndex = -1
    mCore.MarkDirty
End Sub

Public Sub DropDown()
    SetDropDownOpen True, True
End Sub

Public Sub CloseDropDown()
    SetDropDownOpen False, True
End Sub

Public Function Diagnostics() As String
    Diagnostics = _
        "count=" & CStr(mItems.Count) & _
        ";index=" & CStr(mListIndex) & _
        ";text=" & Text & _
        ";value=" & Value & _
        ";dropdown=" & CStr(mDropDownOpen) & _
        ";rows=" & JoinedItems("|") & _
        ";capabilities=" & mCore.CapabilityDescriptor
End Function

Private Sub IOxControl_OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseDown(Button, Shift, X, Y)
    If X >= mCore.Width - BUTTON_WIDTH Then
        ToggleDropDown True
    Else
        CloseDropDown
    End If
End Sub

Private Sub IOxControl_OnMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseUp(Button, Shift, X, Y)
End Sub

Private Sub IOxControl_OnMouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
End Sub

Private Sub IOxControl_OnClick()
    RaiseEvent Click
End Sub

Private Property Get IOxControl_SupportsClick() As Boolean
    IOxControl_SupportsClick = mCore.SupportsClick
End Property

Private Property Get IOxControl_HasPressedVisual() As Boolean
    IOxControl_HasPressedVisual = mCore.HasPressedVisual
End Property

Private Function IOxControl_OnKeyDown(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    Dim Post As Integer
    Post = PerformKeyDown(KeyCode, Shift)
    If Post <> 0 Then
        Select Case Post
            Case OX_KEY_F4
                ToggleDropDown True
            Case OX_KEY_DOWN
                If (Shift And OX_SHIFT_ALT) <> 0 Then
                    SetDropDownOpen True, True
                Else
                    MoveSelection 1
                End If
            Case OX_KEY_UP
                MoveSelection -1
            Case OX_KEY_ENTER
                If mDropDownOpen Then SetDropDownOpen False, True
            Case OX_KEY_ESCAPE
                If mDropDownOpen Then SetDropDownOpen False, True
        End Select
    End If
    IOxControl_OnKeyDown = Post
End Function

Private Function IOxControl_OnKeyUp(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    IOxControl_OnKeyUp = PerformKeyUp(KeyCode, Shift)
End Function

Private Sub IOxControl_OnCharacterInput(ByVal Text As String)
    If Len(Text) = 0 Then Exit Sub
    Dim KeyAscii As Integer
    KeyAscii = Asc(Left$(Text, 1))
    KeyAscii = PerformKeyPress(KeyAscii)
    If KeyAscii = 0 Then Exit Sub
    ApplyUserText mCore.DisplayText & Chr$(KeyAscii)
End Sub

Private Sub IOxControl_OnEnter()
    If Not mFocused Then
        mFocused = True
        mCore.MarkDirty
    End If
    RaiseEvent Enter
End Sub

Private Function IOxControl_OnExit() As Boolean
    IOxControl_OnExit = PerformExit()
    If Not IOxControl_OnExit Then
        If mDropDownOpen Then SetDropDownOpen False, True
        If mFocused Then
            mFocused = False
            mCore.MarkDirty
        End If
    End If
End Function

Private Function IOxControl_OnBeforeUpdate() As Boolean
    IOxControl_OnBeforeUpdate = PerformBeforeUpdate()
End Function

Private Sub IOxControl_OnAfterUpdate()
    RaiseEvent AfterUpdate
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
    IOxControl_OnPaste = True
    If PerformBeforeDropOrPaste(Action, Shift) Then Exit Function
    ApplyUserText mCore.DisplayText & Text
End Function

Private Function IOxControl_OnCopy() As String
    IOxControl_OnCopy = mCore.DisplayText
End Function

Private Function IOxControl_OnCut() As String
    IOxControl_OnCut = mCore.DisplayText
    ApplyUserText ""
End Function

Private Property Get IOxControl_AccessibilityRole() As String
    IOxControl_AccessibilityRole = "combobox"
End Property

Private Property Get IOxControl_AccessibilityName() As String
    IOxControl_AccessibilityName = mCore.Name
End Property

Private Property Get IOxControl_AccessibilityValue() As String
    IOxControl_AccessibilityValue = Value
End Property

Private Property Get IOxControl_AccessibilitySelected() As Boolean
    IOxControl_AccessibilitySelected = (mListIndex >= 0)
End Property

Private Property Get IOxControl_AccessibilitySelectionStart() As Long
    IOxControl_AccessibilitySelectionStart = mListIndex
End Property

Private Property Get IOxControl_AccessibilitySelectionLength() As Long
    If mListIndex >= 0 Then IOxControl_AccessibilitySelectionLength = 1
End Property

Private Property Get IOxControl_AccessibilitySelectionText() As String
    If mListIndex >= 0 Then IOxControl_AccessibilitySelectionText = List(mListIndex)
End Property

Private Property Get IOxControl_AccessibilityPatterns() As String
    IOxControl_AccessibilityPatterns = "textbox/list/value,expand-collapse,selection"
End Property

Private Property Get IOxControl_AccessibilityRowCount() As Long
    IOxControl_AccessibilityRowCount = mItems.Count
End Property

Private Property Get IOxControl_AccessibilityColumnCount() As Long
    IOxControl_AccessibilityColumnCount = 1
End Property

Public Function PerformKeyDown(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    Dim helper As ReturnInteger
    Set helper = New ReturnInteger
    helper.Value = KeyCode
    RaiseEvent KeyDown(helper, Shift)
    PerformKeyDown = helper.Value
End Function

Public Function PerformKeyUp(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    Dim helper As ReturnInteger
    Set helper = New ReturnInteger
    helper.Value = KeyCode
    RaiseEvent KeyUp(helper, Shift)
    PerformKeyUp = helper.Value
End Function

Public Function PerformKeyPress(ByVal KeyAscii As Integer) As Integer
    Dim helper As ReturnInteger
    Set helper = New ReturnInteger
    helper.Value = KeyAscii
    RaiseEvent KeyPress(helper)
    PerformKeyPress = helper.Value
End Function

Public Function PerformExit() As Boolean
    Dim cancel As ReturnBoolean
    Set cancel = New ReturnBoolean
    RaiseEvent [Exit](cancel)
    PerformExit = cancel.Value
End Function

Public Function PerformBeforeUpdate() As Boolean
    Dim cancel As ReturnBoolean
    Set cancel = New ReturnBoolean
    RaiseEvent BeforeUpdate(cancel)
    PerformBeforeUpdate = cancel.Value
End Function

Public Function PerformBeforeDropOrPaste(ByVal Action As Integer, ByVal Shift As Integer) As Boolean
    Dim cancel As ReturnBoolean
    Set cancel = New ReturnBoolean
    RaiseEvent BeforeDropOrPaste(cancel, Action, Shift)
    PerformBeforeDropOrPaste = cancel.Value
End Function

Private Sub ApplyUserText(ByVal NewText As String)
    If mCore.DisplayText = NewText Then Exit Sub
    mCore.DisplayText = NewText
    mListIndex = FindItem(NewText)
    mEditDirty = True
    mCore.MarkDirty
    RaiseEvent Change
End Sub

Private Sub MoveSelection(ByVal Delta As Long)
    If mItems.Count = 0 Then Exit Sub
    Dim NextIndex As Long
    If mListIndex < 0 Then
        If Delta < 0 Then
            NextIndex = mItems.Count - 1
        Else
            NextIndex = 0
        End If
    Else
        NextIndex = mListIndex + Delta
        If NextIndex < 0 Then NextIndex = 0
        If NextIndex >= mItems.Count Then NextIndex = mItems.Count - 1
    End If
    SetListIndex NextIndex, True
End Sub

Private Sub SetListIndex(ByVal NewIndex As Long, ByVal FromUser As Boolean)
    If NewIndex < -1 Then NewIndex = -1
    If NewIndex >= mItems.Count Then NewIndex = -1
    If mListIndex = NewIndex Then Exit Sub
    mListIndex = NewIndex
    If mListIndex >= 0 Then
        mCore.DisplayText = List(mListIndex)
    End If
    If FromUser Then
        mEditDirty = True
        RaiseEvent Change
    End If
    mCore.MarkDirty
End Sub

Private Sub ToggleDropDown(ByVal RaiseDropEvent As Boolean)
    SetDropDownOpen Not mDropDownOpen, RaiseDropEvent
End Sub

Private Sub SetDropDownOpen(ByVal Value As Boolean, ByVal RaiseDropEvent As Boolean)
    If mDropDownOpen = Value Then Exit Sub
    mDropDownOpen = Value
    mCore.MarkDirty
    If RaiseDropEvent Then RaiseEvent DropButtonClick
End Sub

Private Function FindItem(ByVal Value As String) As Long
    Dim I As Long
    For I = 0 To mItems.Count - 1
        If List(I) = Value Then
            FindItem = I
            Exit Function
        End If
    Next I
    FindItem = -1
End Function

Private Function JoinedItems(ByVal Separator As String) As String
    Dim Text As String
    Dim I As Long
    For I = 1 To mItems.Count
        If Len(Text) > 0 Then Text = Text & Separator
        Text = Text & CStr(mItems.Item(I))
    Next I
    JoinedItems = Text
End Function
