Option Explicit
Implements IOxControl

' MSForms-shaped TextBox. Focusable; Text value, selection, undo/redo,
' composition-preedit state, Change/keyboard/mouse/focus events. Note the
' Assigning a different Text/Value raises Change, including programmatic edits.
' Only user edits mark the value dirty for focus-out validation and undo.

Public Event Change()
Public Event MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
Public Event KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
' KeyPress carries a mutable KeyAscii (ReturnInteger); a handler sets KeyAscii.Value
' = 0 to swallow the typed character (clean-room name; MS Learn uses KeyANSI).
Public Event KeyPress(ByVal KeyAscii As ReturnInteger)
' The FM20 focus-exit event is the reserved word "Exit", declared via the VBA
' bracketed-name form [Exit] (CalcVBA accepts bracketed RaiseEvent names as of
' baseline 366a40e). Carries a mutable Cancel (ReturnBoolean); a handler sets
' Cancel.Value = True to keep focus.
Public Event [Exit](ByVal Cancel As ReturnBoolean)
' The FM20 focus-enter event fires (no args) when the control receives focus,
' after the losing control's [Exit] (oxforms-esq.6).
Public Event Enter()
' BeforeUpdate fires on focus-out when the value changed (dirty), carrying a mutable
' Cancel (ReturnBoolean) -- a handler sets Cancel.Value = True to cancel the update and
' keep focus. AfterUpdate fires (no args) after a committed update (oxforms-esq.7).
Public Event BeforeUpdate(ByVal Cancel As ReturnBoolean)
Public Event AfterUpdate()
' BeforeDropOrPaste fires before a clipboard paste (Ctrl+V) or drag-drop applies,
' carrying a mutable Cancel (ReturnBoolean) -- a handler sets Cancel.Value = True to
' cancel the paste -- plus the Action (fmAction; 2 = fmActionPaste) and Shift state.
' The live MSForms event also carries Data/X/Y/Effect; the clean-room model surfaces
' Cancel, Action, and Shift (oxforms-esq.9).
Public Event BeforeDropOrPaste(ByVal Cancel As ReturnBoolean, ByVal Action As Integer, ByVal Shift As Integer)

Private mCore As OxControlCore
' Uncommitted-edit flag for two-stage focus-out validation: set by a user edit (typed text),
' cleared on AfterUpdate. Programmatic .Text assignment does not set it.
Private mEditDirty As Boolean
Private mEditOriginalText As String
Private mAnchor As Long
Private mCaret As Long
Private mHideSelection As Boolean
Private mFocused As Boolean
Private mTextService As OxTextService
Private mScrollX As Single
Private mMultiLine As Boolean
Private mUndoStack As Collection
Private mRedoStack As Collection
Private mHistoryApplying As Boolean
Private mCompositionActive As Boolean
Private mCompositionText As String
Private mCompositionStart As Long
Private mCompositionLength As Long

Private Const OX_SHIFT_MASK As Integer = 1
Private Const OX_CTRL_MASK As Integer = 2
Private Const OX_KEY_BACKSPACE As Integer = 8
Private Const OX_KEY_ENTER As Integer = 13
Private Const OX_KEY_ESCAPE As Integer = 27
Private Const OX_KEY_HOME As Integer = 36
Private Const OX_KEY_END As Integer = 35
Private Const OX_KEY_LEFT As Integer = 37
Private Const OX_KEY_RIGHT As Integer = 39
Private Const OX_KEY_DELETE As Integer = 46
Private Const OX_KEY_A As Integer = 65
Private Const OX_KEY_Y As Integer = 89
Private Const OX_KEY_Z As Integer = 90
Private Const OX_BUTTON_LEFT As Integer = 1
' Default MSForms SelectionMargin=True: 3pt base plus a 6pt selection area.
' Configurable SelectionMargin is still a separate public-parity task.
Private Const OX_TEXT_INSET_LEFT As Single = 9
Private Const OX_TEXT_INSET_RIGHT As Single = 3
Private Const OX_TEXT_INSET_Y As Single = 3

Private Sub Class_Initialize()
    Set mCore = Nothing
    Set mTextService = Nothing
    Set mUndoStack = Nothing
    Set mRedoStack = Nothing
    Set mCore = New OxControlCore
    mCore.Init oxControlTextBox
    ' MSForms default size of a TextBox added by Controls.Add (native, round 14).
    mCore.Width = 72
    mCore.Height = 18
    Set mTextService = New OxTextService
    mAnchor = 0
    mCaret = 0
    mHideSelection = True
    mFocused = False
    mScrollX = 0
    mMultiLine = False
    Set mUndoStack = New Collection
    Set mRedoStack = New Collection
    mHistoryApplying = False
    mCompositionActive = False
    mCompositionText = ""
    mCompositionStart = 0
    mCompositionLength = 0
End Sub

' --- IOxControl ---
Private Property Get IOxControl_Core() As OxControlCore
    Set IOxControl_Core = mCore
End Property

' Public ergonomic/runtime handle to the shared core (the IOxControl
' implementation is Private, so the runtime reaches the core through this).
Public Property Get Core() As OxControlCore
    Set Core = mCore
End Property

' Sunken white field + left-aligned text plus first-class editing adorners. Caret,
' selection, hit-test, and horizontal-scroll geometry are driven through OxTextService
' from the shaped text-run caret stops returned by the Surface text service.
Private Sub IOxControl_Render(ByVal Surface As OxSceneBuilder)
    EnsureCaretVisible False

    Surface.OpenNode mCore.NodeId, True, mCore.PaintParentId, mCore.ZOrder, _
        mCore.PaintLeft, mCore.PaintTop, mCore.Width, mCore.Height, mCore.Visible
    Surface.AddChild TextNodeId()
    Surface.AddChild SelectionOverlayNodeId()

    OxThemePaintControlFrame mCore, Surface

    Dim Tx As Single, Ty As Single, Tw As Single, Th As Single
    Tx = mCore.PaintLeft + OX_TEXT_INSET_LEFT
    Ty = mCore.PaintTop + OX_TEXT_INSET_Y
    Tw = TextViewportWidth()
    If Tw < 1 Then Tw = 1
    ' A single text line starts at the inset; it is not centered in a tall field.
    Th = mCore.MeasuredHeight
    If Th > mCore.Height - (OX_TEXT_INSET_Y * 2) Then Th = mCore.Height - (OX_TEXT_INSET_Y * 2)
    If Th < 1 Then Th = 1

    Dim SelectionVisible As Boolean
    Dim Sx As Single, Sw As Single, RawSx As Single, RawEx As Single
    Sx = Tx
    Sw = 0
    SelectionVisible = (SelectionLength() > 0 And (mFocused Or Not mHideSelection))
    If SelectionVisible Then
        RawSx = Tx + SelectionX() - mScrollX
        RawEx = RawSx + SelectionWidth()
        Sx = RawSx
        If Sx < Tx Then Sx = Tx
        If RawEx > Tx + Tw Then RawEx = Tx + Tw
        Sw = RawEx - Sx
        If Sw > 0 Then
            If Sw < 1 Then Sw = 1
            Surface.FillRect Sx, Ty, Sw, Th, OxThemeSelectionBackColor(), 255
        End If
    End If

    If mFocused And mCore.Enabled And SelectionLength() = 0 Then
        Dim Cx As Single
        Cx = Tx + CaretX(mCaret) - mScrollX
        If Cx >= Tx And Cx <= Tx + Tw Then
            Surface.FillRect Cx, Ty + 1, 1, Th - 2, OxThemeCaretColor(), 255
        End If
    End If

    Surface.CloseNode

    Dim TextW As Single
    TextW = mTextService.TextWidth(mCore, TextLength())
    If TextW < Tw Then TextW = Tw

    Surface.OpenNodeClipped TextNodeId(), True, mCore.NodeId, 0, _
        mCore.PaintLeft, mCore.PaintTop, mCore.Width, mCore.Height, _
        Len(mCore.DisplayText) > 0, Tx, Ty, Tw, Th
    If Len(mCore.DisplayText) > 0 Then
        Dim RunId As String
        RunId = mCore.RunId
        If Len(RunId) = 0 Then RunId = "0"
        OxThemePaintTextRun mCore, Surface, _
            Tx - mScrollX, Ty, TextW, Th, RunId, "left", False, False, False
    End If
    Surface.CloseNode

    Surface.OpenNodeClipped SelectionOverlayNodeId(), True, mCore.NodeId, 1, _
        mCore.PaintLeft, mCore.PaintTop, mCore.Width, mCore.Height, SelectionVisible And Sw > 0, _
        Sx, Ty, Sw, Th
    If SelectionVisible And Sw > 0 And Len(mCore.DisplayText) > 0 Then
        Dim OverlayRunId As String
        OverlayRunId = mCore.RunId
        If Len(OverlayRunId) = 0 Then OverlayRunId = "0"
        Surface.DrawText Tx - mScrollX, Ty, TextW, Th, OverlayRunId, "left", False, False, _
            OxThemeSelectionTextColor(), 255, False, Not mCore.Enabled
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
' Programmatic edits notify the same WithEvents sink as user edits.
Public Property Get Text() As String
    Text = mCore.DisplayText
End Property
Public Property Let Text(ByVal Value As String)
    If mCore.DisplayText = Value Then Exit Property
    mCore.DisplayText = Value
    ClampSelectionToText
    EnsureCaretVisible
    RaiseEvent Change
End Property

Public Property Get Value() As String
    Value = mCore.DisplayText
End Property
Attribute Value.VB_UserMemId = 0
Public Property Let Value(ByVal NewValue As String)
    Text = NewValue
End Property

Public Property Get SelStart() As Long
    SelStart = SelectionStart()
End Property
Public Property Let SelStart(ByVal Value As Long)
    SetSelection Value, SelectionLength()
End Property

Public Property Get SelLength() As Long
    SelLength = SelectionLength()
End Property
Public Property Let SelLength(ByVal Value As Long)
    SetSelection SelectionStart(), Value
End Property

Public Property Get SelText() As String
    Dim Start As Long, Length As Long
    Start = SelectionStart()
    Length = SelectionLength()
    If Length <= 0 Then
        SelText = ""
    Else
        SelText = Mid$(mCore.DisplayText, Start + 1, Length)
    End If
End Property
Public Property Let SelText(ByVal Value As String)
    ReplaceSelection Value, False
End Property

Public Property Get HideSelection() As Boolean
    HideSelection = mHideSelection
End Property
Public Property Let HideSelection(ByVal Value As Boolean)
    If mHideSelection <> Value Then
        mHideSelection = Value
        mCore.MarkDirty
    End If
End Property

Public Property Get MultiLine() As Boolean
    MultiLine = mMultiLine
End Property
Public Property Let MultiLine(ByVal Value As Boolean)
    If mMultiLine <> Value Then
        mMultiLine = Value
        mCore.MarkDirty
        EnsureCaretVisible
    End If
End Property

Public Property Get CanUndo() As Boolean
    CanUndo = (mUndoStack.Count > 0)
End Property

Public Property Get CanRedo() As Boolean
    CanRedo = (mRedoStack.Count > 0)
End Property

Public Sub Undo()
    If mUndoStack.Count = 0 Then Exit Sub
    ApplyHistoryState PopText(mUndoStack), mRedoStack
End Sub

Public Sub Redo()
    If mRedoStack.Count = 0 Then Exit Sub
    ApplyHistoryState PopText(mRedoStack), mUndoStack
End Sub

Public Property Get CompositionActive() As Boolean
    CompositionActive = mCompositionActive
End Property

Public Property Get CompositionText() As String
    CompositionText = mCompositionText
End Property

Public Sub BeginComposition()
    mCompositionActive = True
    mCompositionText = ""
    mCompositionStart = SelectionStart()
    mCompositionLength = SelectionLength()
    mCore.MarkDirty
End Sub

Public Sub UpdateComposition(ByVal PreeditText As String)
    If Not mCompositionActive Then BeginComposition
    mCompositionText = PreeditText
    mCore.MarkDirty
End Sub

Public Sub CommitComposition(Optional ByVal CommitText As String = "")
    Dim TextToCommit As String
    If Not mCompositionActive Then
        If Len(CommitText) > 0 Then InsertText CommitText
        Exit Sub
    End If
    TextToCommit = CommitText
    If Len(TextToCommit) = 0 Then TextToCommit = mCompositionText
    mCompositionActive = False
    mCompositionText = ""
    SetSelection mCompositionStart, mCompositionLength
    mCompositionLength = 0
    InsertText TextToCommit
End Sub

Public Sub CancelComposition()
    If Not mCompositionActive Then Exit Sub
    mCompositionActive = False
    mCompositionText = ""
    mCompositionLength = 0
    CollapseSelection mCompositionStart
End Sub

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

' --- Runtime-facing input surface (driven by the CalcForms runtime, not form code) ---
' User edit path: set the text from a real keystroke/paste and raise Change.
Public Sub ApplyUserText(ByVal NewText As String)
    If Not mEditDirty Then mEditOriginalText = mCore.DisplayText
    mCore.DisplayText = NewText
    CollapseSelection Len(NewText)
    mEditDirty = True
    RaiseEvent Change
End Sub

' Insert typed text at the current selection/caret and raise Change; marks the value dirty
' for two-stage focus-out validation.
Public Sub InsertText(ByVal NewText As String)
    If Len(NewText) = 0 Then Exit Sub
    ReplaceSelection NewText, True
End Sub

Private Function TextLength() As Long
    TextLength = Len(mCore.DisplayText)
End Function

Private Function ClampIndex(ByVal Value As Long) As Long
    If Value < 0 Then
        ClampIndex = 0
    ElseIf Value > TextLength() Then
        ClampIndex = TextLength()
    Else
        ClampIndex = Value
    End If
End Function

Private Function ClampLength(ByVal Start As Long, ByVal Value As Long) As Long
    If Value < 0 Then
        ClampLength = 0
    ElseIf Start + Value > TextLength() Then
        ClampLength = TextLength() - Start
    Else
        ClampLength = Value
    End If
End Function

Private Function SelectionStart() As Long
    If mAnchor < mCaret Then
        SelectionStart = mAnchor
    Else
        SelectionStart = mCaret
    End If
End Function

Private Function SelectionLength() As Long
    SelectionLength = Abs(mCaret - mAnchor)
End Function

Private Sub SetSelection(ByVal Start As Long, ByVal Length As Long)
    Dim NewStart As Long, NewLength As Long
    NewStart = ClampIndex(Start)
    NewLength = ClampLength(NewStart, Length)
    If mAnchor <> NewStart Or mCaret <> NewStart + NewLength Then
        mAnchor = NewStart
        mCaret = NewStart + NewLength
        mCore.MarkDirty
        EnsureCaretVisible
    End If
End Sub

Private Sub CollapseSelection(ByVal Index As Long)
    Dim NewIndex As Long
    NewIndex = ClampIndex(Index)
    If mAnchor <> NewIndex Or mCaret <> NewIndex Then
        mAnchor = NewIndex
        mCaret = NewIndex
        mCore.MarkDirty
        EnsureCaretVisible
    End If
End Sub

Private Sub ClampSelectionToText()
    Dim Start As Long, Length As Long
    Start = SelectionStart()
    Length = SelectionLength()
    If Start > TextLength() Then
        CollapseSelection TextLength()
    ElseIf Start + Length > TextLength() Then
        SetSelection Start, TextLength() - Start
    End If
End Sub

Private Sub ReplaceSelection(ByVal NewText As String, ByVal IsUserEdit As Boolean)
    Dim Start As Long, Length As Long
    Dim OldText As String, NextText As String
    Start = SelectionStart()
    Length = SelectionLength()
    OldText = mCore.DisplayText
    NextText = Left$(OldText, Start) & NewText & Mid$(OldText, Start + Length + 1)
    If NextText = OldText And Length = 0 And Len(NewText) = 0 Then Exit Sub
    If IsUserEdit Then RecordUndoState OldText
    mCore.DisplayText = NextText
    CollapseSelection Start + Len(NewText)
    If IsUserEdit Then
        mEditDirty = True
    End If
    If NextText <> OldText Then RaiseEvent Change
End Sub

Private Sub DeleteBack()
    If SelectionLength() > 0 Then
        ReplaceSelection "", True
    ElseIf mCaret > 0 Then
        mAnchor = PreviousTextBoundary(mCaret)
        ReplaceSelection "", True
    End If
End Sub

Private Sub DeleteForward()
    If SelectionLength() > 0 Then
        ReplaceSelection "", True
    ElseIf mCaret < TextLength() Then
        mAnchor = NextTextBoundary(mCaret)
        ReplaceSelection "", True
    End If
End Sub

Private Sub MoveCaretTo(ByVal Index As Long, ByVal ExtendSelection As Boolean)
    Dim NewIndex As Long
    NewIndex = ClampIndex(Index)
    If ExtendSelection Then
        If mCaret <> NewIndex Then
            mCaret = NewIndex
            mCore.MarkDirty
            EnsureCaretVisible
        End If
    Else
        CollapseSelection NewIndex
    End If
End Sub

Private Sub SelectAll()
    SetSelection 0, TextLength()
End Sub

Private Function IndexFromPoint(ByVal X As Single) As Long
    IndexFromPoint = mTextService.IndexFromX(mCore, X - OX_TEXT_INSET_LEFT + mScrollX, TextLength())
End Function

Private Function TextViewportWidth() As Single
    TextViewportWidth = mCore.Width - OX_TEXT_INSET_LEFT - OX_TEXT_INSET_RIGHT
    If TextViewportWidth < 1 Then TextViewportWidth = 1
End Function

Private Function TextNodeId() As Long
    TextNodeId = (mCore.NodeId * 1000) + 900
End Function

Private Function SelectionOverlayNodeId() As Long
    SelectionOverlayNodeId = (mCore.NodeId * 1000) + 901
End Function

Private Function CaretX(ByVal Index As Long) As Single
    CaretX = mTextService.CaretX(mCore, Index, TextLength())
End Function

Private Function SelectionX() As Single
    SelectionX = mTextService.SelectionX(mCore, SelectionStart(), TextLength())
End Function

Private Function SelectionWidth() As Single
    SelectionWidth = mTextService.SelectionWidth(mCore, SelectionStart(), SelectionLength(), TextLength())
End Function

Private Sub EnsureCaretVisible(Optional ByVal MarkDirty As Boolean = True)
    Dim NewScroll As Single
    NewScroll = mTextService.ScrollForCaret( _
        mCore, mScrollX, TextViewportWidth(), mCaret, TextLength())
    If Abs(NewScroll - mScrollX) > 0.01 Then
        mScrollX = NewScroll
        If MarkDirty Then mCore.MarkDirty
    End If
End Sub

Private Sub RecordUndoState(ByVal OldText As String)
    If mHistoryApplying Then Exit Sub
    If Not mEditDirty Then mEditOriginalText = OldText
    mUndoStack.Add OldText
    Set mRedoStack = New Collection
End Sub

Private Function PopText(ByVal Stack As Collection) As String
    PopText = CStr(Stack.Item(Stack.Count))
    Stack.Remove Stack.Count
End Function

Private Sub ApplyHistoryState(ByVal TargetText As String, ByVal OppositeStack As Collection)
    If Not mEditDirty Then mEditOriginalText = mCore.DisplayText
    mHistoryApplying = True
    OppositeStack.Add mCore.DisplayText
    mCore.DisplayText = TargetText
    CollapseSelection Len(TargetText)
    mEditDirty = True
    mCompositionActive = False
    mCompositionText = ""
    mCompositionLength = 0
    mHistoryApplying = False
    RaiseEvent Change
End Sub

Private Function PreviousTextBoundary(ByVal Index As Long) As Long
    Dim Pos As Long
    Pos = ClampIndex(Index)
    If Pos <= 0 Then
        PreviousTextBoundary = 0
        Exit Function
    End If

    Dim Text As String
    Text = mCore.DisplayText
    If Pos >= 2 Then
        If Mid$(Text, Pos - 1, 2) = vbCrLf Then
            PreviousTextBoundary = Pos - 2
            Exit Function
        End If
    End If

    Pos = Pos - 1
    Do While Pos > 0 And IsCombiningCodeUnit(CodeUnitAt(Text, Pos + 1))
        Pos = Pos - 1
    Loop
    If Pos > 0 Then
        If IsLowSurrogate(CodeUnitAt(Text, Pos + 1)) And IsHighSurrogate(CodeUnitAt(Text, Pos)) Then
            Pos = Pos - 1
        End If
    End If
    PreviousTextBoundary = Pos
End Function

Private Function NextTextBoundary(ByVal Index As Long) As Long
    Dim Pos As Long
    Pos = ClampIndex(Index)
    If Pos >= TextLength() Then
        NextTextBoundary = TextLength()
        Exit Function
    End If

    Dim Text As String
    Text = mCore.DisplayText
    If Pos + 1 < Len(Text) Then
        If Mid$(Text, Pos + 1, 2) = vbCrLf Then
            NextTextBoundary = Pos + 2
            Exit Function
        End If
    End If

    Pos = Pos + 1
    If Pos < Len(Text) Then
        If IsHighSurrogate(CodeUnitAt(Text, Pos)) And IsLowSurrogate(CodeUnitAt(Text, Pos + 1)) Then
            Pos = Pos + 1
        End If
    End If
    Do While Pos < Len(Text) And IsCombiningCodeUnit(CodeUnitAt(Text, Pos + 1))
        Pos = Pos + 1
    Loop
    NextTextBoundary = Pos
End Function

Private Function LineStartFor(ByVal Index As Long) As Long
    Dim Pos As Long
    Pos = ClampIndex(Index)
    Do While Pos > 0
        If Mid$(mCore.DisplayText, Pos, 2) = vbCrLf Then
            LineStartFor = Pos + 1
            Exit Function
        End If
        Pos = Pos - 1
    Loop
    LineStartFor = 0
End Function

Private Function LineEndFor(ByVal Index As Long) As Long
    Dim Pos As Long
    Pos = ClampIndex(Index)
    Do While Pos < TextLength()
        If Mid$(mCore.DisplayText, Pos + 1, 2) = vbCrLf Then
            LineEndFor = Pos
            Exit Function
        End If
        Pos = Pos + 1
    Loop
    LineEndFor = TextLength()
End Function

Private Function CodeUnitAt(ByVal Text As String, ByVal OneBasedIndex As Long) As Long
    If OneBasedIndex < 1 Or OneBasedIndex > Len(Text) Then
        CodeUnitAt = 0
        Exit Function
    End If
    CodeUnitAt = AscW(Mid$(Text, OneBasedIndex, 1))
    If CodeUnitAt < 0 Then CodeUnitAt = CodeUnitAt + 65536
End Function

Private Function IsHighSurrogate(ByVal CodeUnit As Long) As Boolean
    IsHighSurrogate = (CodeUnit >= &HD800& And CodeUnit <= &HDBFF&)
End Function

Private Function IsLowSurrogate(ByVal CodeUnit As Long) As Boolean
    IsLowSurrogate = (CodeUnit >= &HDC00& And CodeUnit <= &HDFFF&)
End Function

Private Function IsCombiningCodeUnit(ByVal CodeUnit As Long) As Boolean
    IsCombiningCodeUnit = _
        (CodeUnit >= &H300 And CodeUnit <= &H36F) Or _
        (CodeUnit >= &H1AB0 And CodeUnit <= &H1AFF) Or _
        (CodeUnit >= &H1DC0 And CodeUnit <= &H1DFF) Or _
        (CodeUnit >= &H20D0 And CodeUnit <= &H20FF) Or _
        (CodeUnit >= &HFE00& And CodeUnit <= &HFE0F&)
End Function

Public Sub PerformMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseDown(Button, Shift, X, Y)
End Sub

Public Sub PerformMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseUp(Button, Shift, X, Y)
End Sub

Public Sub PerformMouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseMove(Button, Shift, X, Y)
End Sub

Public Function PerformKeyDown(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    Dim helper As ReturnInteger
    Set helper = New ReturnInteger
    helper.Value = KeyCode
    RaiseEvent KeyDown(helper, Shift)
    PerformKeyDown = helper.Value
End Function

' Raises KeyUp with a mutable KeyCode helper and returns the post-handler key code.
Public Function PerformKeyUp(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    Dim helper As ReturnInteger
    Set helper = New ReturnInteger
    helper.Value = KeyCode
    RaiseEvent KeyUp(helper, Shift)
    PerformKeyUp = helper.Value
End Function

' Raises KeyPress with a mutable KeyAscii helper and returns the post-handler value
' (0 if the handler swallowed the character).
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

' Raises the focus-enter event when the control gains focus (no readback).
Public Sub PerformEnter()
    RaiseEvent Enter
End Sub

' Raises BeforeUpdate with a mutable Cancel helper and returns whether the handler
' cancelled the update (True = veto).
Public Function PerformBeforeUpdate() As Boolean
    Dim cancel As ReturnBoolean
    Set cancel = New ReturnBoolean
    RaiseEvent BeforeUpdate(cancel)
    PerformBeforeUpdate = cancel.Value
End Function

' Raises AfterUpdate after a committed update (no args, no readback).
Public Sub PerformAfterUpdate()
    RaiseEvent AfterUpdate
End Sub

' Raises BeforeDropOrPaste with a mutable Cancel helper and returns whether the handler
' cancelled the paste (True = cancel). Action 2 = fmActionPaste; IOxControl_OnPaste
' honors the returned veto before inserting text.
Public Function PerformBeforeDropOrPaste(ByVal Action As Integer, ByVal Shift As Integer) As Boolean
    Dim cancel As ReturnBoolean
    Set cancel = New ReturnBoolean
    RaiseEvent BeforeDropOrPaste(cancel, Action, Shift)
    PerformBeforeDropOrPaste = cancel.Value
End Function

' --- IOxControl reducer input surface (delegates to the concrete Perform*) ---
Private Sub IOxControl_OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    If (Shift And OX_SHIFT_MASK) <> 0 Then
        MoveCaretTo IndexFromPoint(X), True
    Else
        CollapseSelection IndexFromPoint(X)
    End If
    PerformMouseDown Button, Shift, X, Y
End Sub

Private Sub IOxControl_OnMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    PerformMouseUp Button, Shift, X, Y
End Sub

Private Sub IOxControl_OnMouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    If (Button And OX_BUTTON_LEFT) <> 0 Then
        MoveCaretTo IndexFromPoint(X), True
    End If
    PerformMouseMove Button, Shift, X, Y
End Sub

' A TextBox does not fire Click (only CheckBox/Label/CommandButton do); the reducer never
' calls OnClick on a TextBox, but the interface requires the member, so it is a no-op.
Private Sub IOxControl_OnClick()
End Sub

' Keyboard + focus surface. A TextBox raises keys, inserts typed characters (KeyPress then
' Change), and runs the two-stage focus-out validation when a typed edit left it dirty.
Private Function IOxControl_OnKeyDown(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    Dim Post As Integer
    Post = PerformKeyDown(KeyCode, Shift)
    IOxControl_OnKeyDown = Post
    If Post = 0 Then Exit Function

    Dim ExtendSelection As Boolean
    ExtendSelection = ((Shift And OX_SHIFT_MASK) <> 0)

    Select Case Post
        Case OX_KEY_BACKSPACE
            DeleteBack
        Case OX_KEY_DELETE
            DeleteForward
        Case OX_KEY_LEFT
            If SelectionLength() > 0 And Not ExtendSelection Then
                MoveCaretTo SelectionStart(), False
            Else
                MoveCaretTo PreviousTextBoundary(mCaret), ExtendSelection
            End If
        Case OX_KEY_RIGHT
            If SelectionLength() > 0 And Not ExtendSelection Then
                MoveCaretTo SelectionStart() + SelectionLength(), False
            Else
                MoveCaretTo NextTextBoundary(mCaret), ExtendSelection
            End If
        Case OX_KEY_HOME
            If mMultiLine Then
                MoveCaretTo LineStartFor(mCaret), ExtendSelection
            Else
                MoveCaretTo 0, ExtendSelection
            End If
        Case OX_KEY_END
            If mMultiLine Then
                MoveCaretTo LineEndFor(mCaret), ExtendSelection
            Else
                MoveCaretTo TextLength(), ExtendSelection
            End If
        Case OX_KEY_ENTER
            If mMultiLine Then InsertText vbCrLf
        Case OX_KEY_ESCAPE
            CancelPendingEdit
        Case OX_KEY_A
            If (Shift And OX_CTRL_MASK) <> 0 Then SelectAll
        Case OX_KEY_Z
            If (Shift And OX_CTRL_MASK) <> 0 Then Undo
        Case OX_KEY_Y
            If (Shift And OX_CTRL_MASK) <> 0 Then Redo
    End Select
End Function

Private Sub CancelPendingEdit()
    If Not mEditDirty Then Exit Sub
    Dim Changed As Boolean
    Changed = (mCore.DisplayText <> mEditOriginalText)
    mEditDirty = False
    mCore.DisplayText = mEditOriginalText
    ClampSelectionToText
    EnsureCaretVisible
    If Changed Then RaiseEvent Change
End Sub

Private Function IOxControl_OnKeyUp(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    IOxControl_OnKeyUp = PerformKeyUp(KeyCode, Shift)
End Function

Private Sub IOxControl_OnCharacterInput(ByVal Text As String)
    ' KeyPress fires before the value changes. A handler may swallow the character by setting
    ' KeyAscii.Value = 0 (then nothing inserts, no Change) or remap it to another code; otherwise
    ' the character inserts and raises Change. (Multi-char input bypasses the per-char KeyPress
    ' remap and inserts verbatim -- KeyPress is a single-character event.)
    If Len(Text) = 0 Then Exit Sub
    Dim Post As Integer
    Post = PerformKeyPress(Asc(Left$(Text, 1)))
    If Post = 0 Then Exit Sub
    If Len(Text) = 1 Then
        InsertText Chr$(Post)
    Else
        InsertText Text
    End If
End Sub

Private Sub IOxControl_OnEnter()
    If Not mFocused Then
        mFocused = True
        mCore.MarkDirty
    End If
    PerformEnter
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
    PerformAfterUpdate
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

' A TextBox never self-activates on Space/Enter; Enter falls through to the form default button.
Private Function IOxControl_TryKeyboardActivate(ByVal KeyCode As Integer, ByVal Shift As Integer, ByVal HasDefaultButton As Boolean) As Boolean
    IOxControl_TryKeyboardActivate = False
End Function

' Clipboard / drag-drop paste: BeforeDropOrPaste fires before the value changes; a veto
' (Cancel=True) suppresses the insert + Change. Returns True (a TextBox is a text paste target).
Private Function IOxControl_OnPaste(ByVal Text As String, ByVal Action As Integer, ByVal Shift As Integer) As Boolean
    If Not mCore.AcceptsPaste Then
        IOxControl_OnPaste = False
        Exit Function
    End If
    If Not PerformBeforeDropOrPaste(Action, Shift) Then
        InsertText Text
    End If
    IOxControl_OnPaste = True
End Function

Private Function IOxControl_OnCopy() As String
    IOxControl_OnCopy = SelText
End Function

Private Function IOxControl_OnCut() As String
    IOxControl_OnCut = SelText
    If Len(IOxControl_OnCut) > 0 Then ReplaceSelection "", True
End Function

' A TextBox neither fires Click nor shows a pressed visual (it takes capture + the caret).
Private Property Get IOxControl_SupportsClick() As Boolean
    IOxControl_SupportsClick = mCore.SupportsClick
End Property

Private Property Get IOxControl_HasPressedVisual() As Boolean
    IOxControl_HasPressedVisual = mCore.HasPressedVisual
End Property

Private Property Get IOxControl_AccessibilityRole() As String
    IOxControl_AccessibilityRole = "textbox"
End Property

Private Property Get IOxControl_AccessibilityName() As String
    IOxControl_AccessibilityName = mCore.Name
End Property

Private Property Get IOxControl_AccessibilityValue() As String
    IOxControl_AccessibilityValue = mCore.DisplayText
End Property

Private Property Get IOxControl_AccessibilitySelected() As Boolean
    IOxControl_AccessibilitySelected = (SelectionLength() > 0)
End Property

Private Property Get IOxControl_AccessibilitySelectionStart() As Long
    IOxControl_AccessibilitySelectionStart = SelectionStart()
End Property

Private Property Get IOxControl_AccessibilitySelectionLength() As Long
    IOxControl_AccessibilitySelectionLength = SelectionLength()
End Property

Private Property Get IOxControl_AccessibilitySelectionText() As String
    IOxControl_AccessibilitySelectionText = SelText
End Property

Private Property Get IOxControl_AccessibilityPatterns() As String
    IOxControl_AccessibilityPatterns = "text,value,selection"
End Property

Private Property Get IOxControl_AccessibilityRowCount() As Long
    IOxControl_AccessibilityRowCount = 0
End Property

Private Property Get IOxControl_AccessibilityColumnCount() As Long
    IOxControl_AccessibilityColumnCount = 0
End Property

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
