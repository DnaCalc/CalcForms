Option Explicit
Implements IOxControl

' Representative MSForms-shaped ListBox. The list data and selected row live in the VBA
' object model; the reducer only routes input to this control and asks it to paint itself.
' This spike intentionally starts with single-select rows. Columns, multi-select, and
' virtualization remain future ListBox depth, but they can reuse the same seams.

Public Event Click()
Public Event Change()
Public Event MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
Public Event KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
Public Event KeyPress(ByVal KeyAscii As ReturnInteger)
Public Event [Exit](ByVal Cancel As ReturnBoolean)
Public Event Enter()
Public Event BeforeUpdate(ByVal Cancel As ReturnBoolean)
Public Event AfterUpdate()

Private Const OX_KEY_UP As Integer = 38
Private Const OX_KEY_DOWN As Integer = 40
Private Const OX_KEY_HOME As Integer = 36
Private Const OX_KEY_END As Integer = 35
Private Const ROW_HEIGHT As Single = 14
Private Const ROW_INSET As Single = 3

Private mCore As OxControlCore
Private mItems As Collection
Private mListIndex As Long
Private mFocused As Boolean
Private mEditDirty As Boolean

Private Sub Class_Initialize()
    Set mCore = New OxControlCore
    mCore.Init oxControlListBox
    Set mItems = New Collection
    mListIndex = -1
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
    OxThemePaintListBox mCore, Surface, mListIndex, mFocused
End Sub

Private Property Get IOxControl_HasChildren() As Boolean
    IOxControl_HasChildren = False
End Property

Private Property Get IOxControl_Children() As Controls
    Set IOxControl_Children = Nothing
End Property

' --- User-facing properties and methods ---
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

Public Property Get ListCount() As Long
    ListCount = mItems.Count
End Property

Public Property Get ListIndex() As Long
    ListIndex = mListIndex
End Property
Public Property Let ListIndex(ByVal Value As Long)
    SetListIndex Value, False
End Property

Public Property Get Value() As String
    If mListIndex >= 0 And mListIndex < mItems.Count Then
        Value = CStr(mItems.Item(mListIndex + 1))
    Else
        Value = ""
    End If
End Property
Public Property Let Value(ByVal NewValue As String)
    Dim I As Long
    For I = 1 To mItems.Count
        If CStr(mItems.Item(I)) = NewValue Then
            SetListIndex I - 1, False
            Exit Property
        End If
    Next I
    SetListIndex -1, False
End Property

Public Property Get List(ByVal Index As Long) As String
    If Index < 0 Or Index >= mItems.Count Then
        List = ""
    Else
        List = CStr(mItems.Item(Index + 1))
    End If
End Property

Public Sub AddItem(ByVal Item As String)
    mItems.Add Item
    SyncDisplayText
End Sub

Public Sub Clear()
    Set mItems = New Collection
    mListIndex = -1
    SyncDisplayText
End Sub

Public Function Diagnostics() As String
    Diagnostics = _
        "count=" & CStr(mItems.Count) & _
        ";index=" & CStr(mListIndex) & _
        ";value=" & Value & _
        ";rows=" & JoinedItems("|") & _
        ";capabilities=" & mCore.CapabilityDescriptor
End Function

' --- IOxControl reducer input surface ---
Private Sub IOxControl_OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    PerformMouseDown Button, Shift, X, Y
    SelectRowAt Y
End Sub

Private Sub IOxControl_OnMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    PerformMouseUp Button, Shift, X, Y
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
    If Post <> 0 And Shift = 0 Then
        Select Case Post
            Case OX_KEY_UP
                MoveSelection -1
            Case OX_KEY_DOWN
                MoveSelection 1
            Case OX_KEY_HOME
                If mItems.Count > 0 Then SetListIndex 0, True
            Case OX_KEY_END
                If mItems.Count > 0 Then SetListIndex mItems.Count - 1, True
        End Select
    End If
    IOxControl_OnKeyDown = Post
End Function

Private Function IOxControl_OnKeyUp(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    IOxControl_OnKeyUp = PerformKeyUp(KeyCode, Shift)
End Function

Private Sub IOxControl_OnCharacterInput(ByVal Text As String)
    If Len(Text) > 0 Then PerformKeyPress Asc(Left$(Text, 1))
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
    IOxControl_OnPaste = False
End Function

Private Function IOxControl_OnCopy() As String
    IOxControl_OnCopy = ""
End Function

Private Function IOxControl_OnCut() As String
    IOxControl_OnCut = ""
End Function

Private Property Get IOxControl_AccessibilityRole() As String
    IOxControl_AccessibilityRole = "listbox"
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
    If mListIndex >= 0 Then
        IOxControl_AccessibilitySelectionLength = 1
    Else
        IOxControl_AccessibilitySelectionLength = 0
    End If
End Property

Private Property Get IOxControl_AccessibilitySelectionText() As String
    IOxControl_AccessibilitySelectionText = Value
End Property

Private Property Get IOxControl_AccessibilityPatterns() As String
    IOxControl_AccessibilityPatterns = "selection,value"
End Property

Private Property Get IOxControl_AccessibilityRowCount() As Long
    IOxControl_AccessibilityRowCount = mItems.Count
End Property

Private Property Get IOxControl_AccessibilityColumnCount() As Long
    IOxControl_AccessibilityColumnCount = 1
End Property

' --- Runtime-facing event helpers ---
Public Sub PerformMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseDown(Button, Shift, X, Y)
End Sub

Public Sub PerformMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseUp(Button, Shift, X, Y)
End Sub

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

Private Sub SelectRowAt(ByVal Y As Single)
    Dim Row As Long
    Row = CLng(Int((Y - ROW_INSET) / ROW_HEIGHT))
    If Row >= 0 And Row < mItems.Count Then SetListIndex Row, True
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
    If FromUser Then
        mEditDirty = True
        RaiseEvent Change
    End If
    mCore.MarkDirty
End Sub

Private Sub SyncDisplayText()
    mCore.DisplayText = JoinedItems(vbLf)
    If mListIndex >= mItems.Count Then mListIndex = -1
    mCore.MarkDirty
End Sub

Private Function JoinedItems(ByVal Separator As String) As String
    Dim Text As String
    Dim I As Long
    For I = 1 To mItems.Count
        If Len(Text) > 0 Then Text = Text & Separator
        Text = Text & CStr(mItems.Item(I))
    Next I
    JoinedItems = Text
End Function
