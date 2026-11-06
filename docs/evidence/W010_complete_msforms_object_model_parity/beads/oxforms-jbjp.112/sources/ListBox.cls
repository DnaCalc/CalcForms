Option Explicit
Implements IOxControl

' Representative MSForms-shaped ListBox. The list data and selected row live in the VBA
' object model; the reducer only routes input to this control and asks it to paint itself.
' MultiSelect and simple tab-separated columns are kept in VBA state; the renderer only
' receives row-selection rectangles and text.

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
Private Const OX_KEY_PAGE_UP As Integer = 33
Private Const OX_KEY_PAGE_DOWN As Integer = 34
Private Const OX_KEY_SPACE As Integer = 32
Private Const SHIFT_MASK As Integer = 1
Private Const CTRL_MASK As Integer = 2
Private Const ROW_INSET As Single = 1.5

Private mCore As OxControlCore
Private mItems As Collection
Private mListIndex As Long
Private mTopIndex As Long
Private mSelectedCsv As String
Private mMultiSelect As fmMultiSelect
Private mColumnCount As Long
Private mBoundColumn As Long
Private mAnchorIndex As Long
Private mFocused As Boolean
Private mEditDirty As Boolean

Private Sub Class_Initialize()
    Set mCore = Nothing
    Set mItems = Nothing
    Set mCore = New OxControlCore
    mCore.Init oxControlListBox
    Set mItems = New Collection
    mListIndex = -1
    mTopIndex = -1
    mSelectedCsv = ""
    mMultiSelect = fmMultiSelectSingle
    mColumnCount = 1
    mBoundColumn = 1
    mAnchorIndex = -1
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
    OxThemePaintListBox mCore, Surface, mListIndex, mFocused, mSelectedCsv, mItems.Count, RowHeight(), mTopIndex
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
    ClampTopIndex
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

Public Property Get TopIndex() As Long
    TopIndex = mTopIndex
End Property
Public Property Let TopIndex(ByVal Value As Long)
    If mItems.Count = 0 Then
        If Value >= 0 Then Err.Raise -2147467259, "ListBox", "No rows to scroll"
        Exit Property
    End If
    If Value < 0 Then Value = 0
    If Value > MaximumTopIndex() Then Value = MaximumTopIndex()
    If mTopIndex = Value Then Exit Property
    mTopIndex = Value
    mCore.MarkDirty
End Property

Public Property Get MultiSelect() As fmMultiSelect
    MultiSelect = mMultiSelect
End Property
Public Property Let MultiSelect(ByVal Value As fmMultiSelect)
    If Value < fmMultiSelectSingle Or Value > fmMultiSelectExtended Then Value = fmMultiSelectSingle
    If mMultiSelect <> Value Then
        mMultiSelect = Value
        If mMultiSelect = fmMultiSelectSingle Then
            SelectOnly mListIndex
        End If
        mCore.MarkDirty
    End If
End Property

Public Property Get ColumnCount() As Long
    ColumnCount = mColumnCount
End Property
Public Property Let ColumnCount(ByVal Value As Long)
    If Value < 1 Then Value = 1
    If mColumnCount <> Value Then
        mColumnCount = Value
        If mBoundColumn > mColumnCount Then mBoundColumn = mColumnCount
        SyncDisplayText
    End If
End Property

Public Property Get BoundColumn() As Long
    BoundColumn = mBoundColumn
End Property
Public Property Let BoundColumn(ByVal Value As Long)
    If Value < 1 Then Value = 1
    If Value > mColumnCount Then Value = mColumnCount
    mBoundColumn = Value
End Property

Public Property Get Value() As String
    If mListIndex >= 0 And mListIndex < mItems.Count Then
        Value = ListValue(mListIndex, mBoundColumn - 1)
    Else
        Value = ""
    End If
End Property
Public Property Let Value(ByVal NewValue As String)
    Dim I As Long
    For I = 1 To mItems.Count
        If ListValue(I - 1, mBoundColumn - 1) = NewValue Then
            SetListIndex I - 1, False
            Exit Property
        End If
    Next I
    SetListIndex -1, False
End Property

Public Property Get List(ByVal Index As Long) As String
    List = ListValue(Index, 0)
End Property

Public Property Get Column(ByVal Index As Long, ByVal ColumnIndex As Long) As String
    Column = ListValue(Index, ColumnIndex)
End Property

Public Property Get Selected(ByVal Index As Long) As Boolean
    Selected = IsSelected(Index)
End Property
Public Property Let Selected(ByVal Index As Long, ByVal Value As Boolean)
    If Index < 0 Or Index >= mItems.Count Then Exit Property
    If mMultiSelect = fmMultiSelectSingle Then
        If Value Then
            SetListIndex Index, False
        ElseIf mListIndex = Index Then
            SetListIndex -1, False
        End If
    Else
        SetSelected Index, Value
        If Value Then
            mListIndex = Index
            mAnchorIndex = Index
        ElseIf mListIndex = Index Then
            mListIndex = FirstSelectedIndex()
        End If
        mCore.MarkDirty
    End If
End Property

Private Property Get ListValue(ByVal Index As Long, ByVal ColumnIndex As Long) As String
    If Index < 0 Or Index >= mItems.Count Then
        ListValue = ""
    Else
        ListValue = ColumnValue(CStr(mItems.Item(Index + 1)), ColumnIndex)
    End If
End Property

Public Sub AddItem(ByVal Item As String)
    mItems.Add Item
    SyncDisplayText
End Sub

Public Sub AddRow(ByVal FirstColumn As String, ByVal SecondColumn As String)
    AddItem FirstColumn & vbTab & SecondColumn
End Sub

Public Sub Clear()
    Set mItems = New Collection
    mListIndex = -1
    mTopIndex = -1
    mSelectedCsv = ""
    mAnchorIndex = -1
    SyncDisplayText
End Sub

Public Function Diagnostics() As String
    Diagnostics = _
        "count=" & CStr(mItems.Count) & _
        ";index=" & CStr(mListIndex) & _
        ";value=" & Value & _
        ";multiselect=" & CStr(mMultiSelect) & _
        ";selected=" & SelectedSummary() & _
        ";columns=" & CStr(mColumnCount) & _
        ";bound_column=" & CStr(mBoundColumn) & _
        ";rows=" & JoinedItems("|") & _
        ";capabilities=" & mCore.CapabilityDescriptor
End Function

' --- IOxControl reducer input surface ---
Private Sub IOxControl_OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    PerformMouseDown Button, Shift, X, Y
    SelectRowAt Y, Shift
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
    If Post <> 0 Then
        Select Case Post
            Case OX_KEY_UP
                MoveSelection -1, Shift
            Case OX_KEY_DOWN
                MoveSelection 1, Shift
            Case OX_KEY_PAGE_UP
                MoveSelection -PageStep(), Shift
            Case OX_KEY_PAGE_DOWN
                MoveSelection PageStep(), Shift
            Case OX_KEY_HOME
                If mItems.Count > 0 Then SelectIndexFromUser 0, Shift
            Case OX_KEY_END
                If mItems.Count > 0 Then SelectIndexFromUser mItems.Count - 1, Shift
            Case OX_KEY_SPACE
                If mListIndex >= 0 Then ToggleCurrentFromKeyboard Shift
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
    IOxControl_AccessibilitySelectionLength = SelectedCount()
End Property

Private Property Get IOxControl_AccessibilitySelectionText() As String
    IOxControl_AccessibilitySelectionText = SelectedText()
End Property

Private Property Get IOxControl_AccessibilityPatterns() As String
    IOxControl_AccessibilityPatterns = "selection,value"
End Property

Private Property Get IOxControl_AccessibilityRowCount() As Long
    IOxControl_AccessibilityRowCount = mItems.Count
End Property

Private Property Get IOxControl_AccessibilityColumnCount() As Long
    IOxControl_AccessibilityColumnCount = mColumnCount
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

Private Function RowHeight() As Single
    ' Owned Tahoma 8.25: selected row measures 13px/19px solid blue at 100%/150%.
    RowHeight = mCore.FontSize + 1.5
End Function

Private Sub SelectRowAt(ByVal Y As Single, ByVal Shift As Integer)
    Dim Row As Long
    If Y < ROW_INSET Or Y >= mCore.Height - ROW_INSET Then Exit Sub
    Row = mTopIndex + CLng(Int((Y - ROW_INSET) / RowHeight()))
    If Row >= 0 And Row < mItems.Count Then SelectIndexFromUser Row, Shift
End Sub

' Full rows determine keyboard travel; a partially visible last row still limits
' the public TopIndex. Keep these separate, as observed at Height=72.
Private Function VisibleRows(ByVal IncludePartial As Boolean) As Long
    Dim Rows As Single
    Rows = (mCore.Height - ROW_INSET * 2) / RowHeight()
    VisibleRows = CLng(Int(Rows))
    If IncludePartial And Rows > VisibleRows Then VisibleRows = VisibleRows + 1
    If VisibleRows < 1 Then VisibleRows = 1
End Function

Private Function PageStep() As Long
    PageStep = VisibleRows(False) - 1
    If PageStep < 1 Then PageStep = 1
End Function

Private Function MaximumTopIndex() As Long
    MaximumTopIndex = mItems.Count - VisibleRows(True)
    If MaximumTopIndex < 0 Then MaximumTopIndex = 0
End Function

Private Sub ClampTopIndex()
    If mItems.Count = 0 Then
        mTopIndex = -1
    Else
        If mTopIndex < 0 Then mTopIndex = 0
        If mTopIndex > MaximumTopIndex() Then mTopIndex = MaximumTopIndex()
    End If
End Sub

Private Sub EnsureRowVisible(ByVal Index As Long, ByVal FromUser As Boolean)
    If Index < 0 Then Exit Sub
    Dim Rows As Long
    Rows = VisibleRows(Not FromUser)
    If Index < mTopIndex Then mTopIndex = Index
    If Index >= mTopIndex + Rows Then mTopIndex = Index - Rows + 1
    ClampTopIndex
End Sub

Private Sub MoveSelection(ByVal Delta As Long, ByVal Shift As Integer)
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

    SelectIndexFromUser NextIndex, Shift
End Sub

Private Sub SelectIndexFromUser(ByVal NewIndex As Long, ByVal Shift As Integer)
    EnsureRowVisible NewIndex, True
    If mMultiSelect = fmMultiSelectSingle Then
        SetListIndex NewIndex, True
    ElseIf mMultiSelect = fmMultiSelectMulti Then
        ToggleSelected NewIndex, True
    Else
        If (Shift And SHIFT_MASK) <> 0 Then
            SelectRange NewIndex, True
        ElseIf (Shift And CTRL_MASK) <> 0 Then
            mListIndex = NewIndex
            mCore.MarkDirty
        Else
            SelectOnlyFromUser NewIndex
        End If
    End If
End Sub

Private Sub ToggleCurrentFromKeyboard(ByVal Shift As Integer)
    If mMultiSelect = fmMultiSelectSingle Then Exit Sub
    If mMultiSelect = fmMultiSelectExtended And (Shift And CTRL_MASK) = 0 Then Exit Sub
    ToggleSelected mListIndex, True
End Sub

Private Sub SetListIndex(ByVal NewIndex As Long, ByVal FromUser As Boolean)
    If NewIndex < -1 Or NewIndex >= mItems.Count Then Err.Raise 380, "ListBox", "Invalid ListIndex"
    If mListIndex = NewIndex Then Exit Sub

    mListIndex = NewIndex
    EnsureRowVisible NewIndex, FromUser
    SelectOnly NewIndex
    If FromUser Then
        mEditDirty = True
    End If
    RaiseEvent Change
    If Not FromUser Then RaiseEvent Click
    mCore.MarkDirty
End Sub

Private Sub SyncDisplayText()
    mCore.DisplayText = JoinedDisplayText()
    Dim Parts As Collection, I As Long
    Set Parts = New Collection
    For I = 1 To mItems.Count
        Parts.Add RowDisplayText(CStr(mItems.Item(I)))
    Next I
    mCore.SetTextParts Parts
    If mListIndex >= mItems.Count Then mListIndex = -1
    TrimSelectedToCount
    ClampTopIndex
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

Private Function JoinedDisplayText() As String
    Dim Text As String
    Dim I As Long
    For I = 1 To mItems.Count
        If Len(Text) > 0 Then Text = Text & vbLf
        Text = Text & RowDisplayText(CStr(mItems.Item(I)))
    Next I
    JoinedDisplayText = Text
End Function

Private Function RowDisplayText(ByVal RowText As String) As String
    Dim Parts() As String
    Parts = Split(RowText, vbTab)
    Dim Text As String
    Dim I As Long
    For I = 0 To mColumnCount - 1
        If I > 0 Then Text = Text & "  "
        If I <= UBound(Parts) Then Text = Text & Parts(I)
    Next I
    RowDisplayText = Text
End Function

Private Function ColumnValue(ByVal RowText As String, ByVal ColumnIndex As Long) As String
    Dim Parts() As String
    Parts = Split(RowText, vbTab)
    If ColumnIndex < 0 Or ColumnIndex > UBound(Parts) Then
        ColumnValue = ""
    Else
        ColumnValue = Parts(ColumnIndex)
    End If
End Function

Private Sub SelectOnly(ByVal Index As Long)
    mSelectedCsv = ""
    If Index >= 0 And Index < mItems.Count Then SetSelected Index, True
    mAnchorIndex = Index
End Sub

Private Sub SelectOnlyFromUser(ByVal Index As Long)
    If IsOnlySelected(Index) And mListIndex = Index Then Exit Sub
    mListIndex = Index
    SelectOnly Index
    mEditDirty = True
    mCore.MarkDirty
    RaiseEvent Change
End Sub

Private Sub ToggleSelected(ByVal Index As Long, ByVal FromUser As Boolean)
    If Index < 0 Or Index >= mItems.Count Then Exit Sub
    SetSelected Index, Not IsSelected(Index)
    mListIndex = Index
    mAnchorIndex = Index
    If FromUser Then
        mEditDirty = True
        RaiseEvent Change
    End If
    mCore.MarkDirty
End Sub

Private Sub SelectRange(ByVal Index As Long, ByVal FromUser As Boolean)
    If Index < 0 Or Index >= mItems.Count Then Exit Sub
    If mAnchorIndex < 0 Then mAnchorIndex = mListIndex
    If mAnchorIndex < 0 Then mAnchorIndex = Index
    Dim StartIndex As Long, EndIndex As Long
    If mAnchorIndex < Index Then
        StartIndex = mAnchorIndex
        EndIndex = Index
    Else
        StartIndex = Index
        EndIndex = mAnchorIndex
    End If
    mSelectedCsv = ""
    Dim I As Long
    For I = StartIndex To EndIndex
        SetSelected I, True
    Next I
    mListIndex = Index
    If FromUser Then
        mEditDirty = True
        RaiseEvent Change
    End If
    mCore.MarkDirty
End Sub

Private Function IsSelected(ByVal Index As Long) As Boolean
    IsSelected = (InStr(1, mSelectedCsv, "," & CStr(Index) & ",", vbBinaryCompare) > 0)
End Function

Private Sub SetSelected(ByVal Index As Long, ByVal Value As Boolean)
    Dim Token As String
    Token = "," & CStr(Index) & ","
    If Value Then
        If Not IsSelected(Index) Then mSelectedCsv = mSelectedCsv & Token
    ElseIf IsSelected(Index) Then
        mSelectedCsv = Replace(mSelectedCsv, Token, "")
    End If
End Sub

Private Function IsOnlySelected(ByVal Index As Long) As Boolean
    IsOnlySelected = IsSelected(Index) And SelectedCount() = 1
End Function

Private Function FirstSelectedIndex() As Long
    Dim I As Long
    For I = 0 To mItems.Count - 1
        If IsSelected(I) Then
            FirstSelectedIndex = I
            Exit Function
        End If
    Next I
    FirstSelectedIndex = -1
End Function

Private Function SelectedCount() As Long
    Dim Count As Long
    Dim I As Long
    For I = 0 To mItems.Count - 1
        If IsSelected(I) Then Count = Count + 1
    Next I
    SelectedCount = Count
End Function

Private Function SelectedSummary() As String
    Dim Text As String
    Dim I As Long
    For I = 0 To mItems.Count - 1
        If IsSelected(I) Then
            If Len(Text) > 0 Then Text = Text & ","
            Text = Text & CStr(I)
        End If
    Next I
    SelectedSummary = Text
End Function

Private Function SelectedText() As String
    Dim Text As String
    Dim I As Long
    For I = 0 To mItems.Count - 1
        If IsSelected(I) Then
            If Len(Text) > 0 Then Text = Text & "|"
            Text = Text & ListValue(I, mBoundColumn - 1)
        End If
    Next I
    SelectedText = Text
End Function

Private Sub TrimSelectedToCount()
    Dim OldCsv As String
    OldCsv = mSelectedCsv
    mSelectedCsv = ""
    Dim I As Long
    For I = 0 To mItems.Count - 1
        If InStr(1, OldCsv, "," & CStr(I) & ",", vbBinaryCompare) > 0 Then SetSelected I, True
    Next I
End Sub
