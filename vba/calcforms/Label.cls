Option Explicit
Implements IOxControl

' MSForms-shaped Label. Display-only control: a Caption, no focus, Click and
' mouse events. See docs/specs/RENDERING_ARCHITECTURE.md (§5) for the control template.

Public Event Click()
Public Event MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)

Private mCore As OxControlCore
Private mTokens As Collection
Private mWordWrap As Boolean

Private Sub Class_Initialize()
    Set mCore = Nothing
    Set mCore = New OxControlCore
    mCore.Init oxControlLabel
    Set mTokens = New Collection
    mWordWrap = True
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

' Display-only flat face + left-aligned caption (no edge: Label defaults Flat).
Private Sub IOxControl_Render(ByVal Surface As OxSceneBuilder)
    If InStr(1, Caption, vbCr) = 0 And InStr(1, Caption, vbLf) = 0 Then
        If Not mWordWrap Or mCore.MeasuredWidth <= mCore.Width Or mCore.AutoSize Then
            OxPaintStandardControl mCore, Surface, "left"
            Exit Sub
        End If
    End If
    PaintLines Surface
End Sub

Private Property Get IOxControl_HasChildren() As Boolean
    IOxControl_HasChildren = False
End Property

Private Property Get IOxControl_Children() As Controls
    Set IOxControl_Children = Nothing
End Property

' --- User-facing properties ---
Public Property Get Caption() As String
    Caption = mCore.DisplayText
End Property
Public Property Let Caption(ByVal Value As String)
    If mCore.DisplayText = Value Then Exit Property
    mCore.DisplayText = Value
    RebuildTextParts
End Property

Public Property Get WordWrap() As Boolean
    WordWrap = mWordWrap
End Property
Public Property Let WordWrap(ByVal Value As Boolean)
    If mWordWrap = Value Then Exit Property
    mWordWrap = Value
    mCore.MarkDirty
End Property

' The whole caption remains part 0 for AutoSize and the common unwrapped path.
' Tokens share the form's one measurement batch; layout stays in the VBA control.
Private Sub RebuildTextParts()
    Set mTokens = New Collection
    Dim I As Long, Ch As String, Token As String, Space As Boolean, WasSpace As Boolean
    I = 1
    Do While I <= Len(Caption)
        Ch = Mid$(Caption, I, 1)
        If Ch = vbCr Or Ch = vbLf Then
            If Len(Token) > 0 Then mTokens.Add Token
            Token = ""
            If Ch = vbCr And Mid$(Caption, I + 1, 1) = vbLf Then
                Ch = vbCrLf
                I = I + 1
            End If
            mTokens.Add Ch
        Else
            Space = (Ch = " " Or Ch = vbTab)
            If Len(Token) > 0 And Space <> WasSpace Then
                mTokens.Add Token
                Token = ""
            End If
            Token = Token & Ch
            WasSpace = Space
        End If
        I = I + 1
    Loop
    If Len(Token) > 0 Then mTokens.Add Token
    Dim Parts As Collection
    Set Parts = New Collection
    If Len(Caption) > 0 Then
        Parts.Add Caption
        For I = 1 To mTokens.Count
            Parts.Add CStr(mTokens.Item(I))
        Next I
    End If
    mCore.SetTextParts Parts
End Sub

Private Sub PaintLines(ByVal Surface As OxSceneBuilder)
    Surface.OpenNode mCore.NodeId, True, mCore.PaintParentId, mCore.ZOrder, _
        mCore.PaintLeft, mCore.PaintTop, mCore.Width, mCore.Height, mCore.Visible
    OxThemePaintControlFrame mCore, Surface
    Dim I As Long, Token As String, X As Single, Y As Single, Pending As Single
    Dim W As Single, HasWord As Boolean, LineHeight As Single
    Y = mCore.PaintTop + 0.75
    LineHeight = mCore.MeasuredHeight
    If LineHeight < 1 Then LineHeight = 1
    For I = 1 To mTokens.Count
        Token = CStr(mTokens.Item(I))
        If Token = vbCr Or Token = vbLf Or Token = vbCrLf Then
            X = 0
            Pending = 0
            HasWord = False
            Y = Y + LineHeight
        ElseIf Left$(Token, 1) = " " Or Left$(Token, 1) = vbTab Then
            If HasWord Then
                Pending = Pending + mCore.TextPartWidth(I)
            Else
                X = X + mCore.TextPartWidth(I)
            End If
        Else
            W = mCore.TextPartWidth(I)
            If mWordWrap And HasWord And X + Pending + W > mCore.Width Then
                X = 0
                Pending = 0
                HasWord = False
                Y = Y + LineHeight
            End If
            X = X + Pending
            Pending = 0
            If Y < mCore.PaintTop + mCore.Height And W > 0 Then
                OxThemePaintTextRun mCore, Surface, mCore.PaintLeft + X, Y, W, LineHeight, _
                    mCore.TextPartRunId(I), "left", False, True, False
            End If
            X = X + W
            HasWord = True
        End If
    Next I
    Surface.CloseNode
End Sub

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

' --- Runtime-facing input surface (driven by the CalcForms runtime, not form code) ---
Public Sub PerformClick()
    RaiseEvent Click
End Sub

Public Sub PerformMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseDown(Button, Shift, X, Y)
End Sub

Public Sub PerformMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseUp(Button, Shift, X, Y)
End Sub

' --- IOxControl reducer input surface (delegates to the concrete Perform*) ---
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

' A Label fires Click but has no pressed visual (display-only, no press feedback).
Private Property Get IOxControl_SupportsClick() As Boolean
    IOxControl_SupportsClick = mCore.SupportsClick
End Property

Private Property Get IOxControl_HasPressedVisual() As Boolean
    IOxControl_HasPressedVisual = mCore.HasPressedVisual
End Property

' A Label is not focusable, so the reducer never routes keyboard or focus to it; the interface
' members are required, so they are inert.
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
    IOxControl_AccessibilityRole = "label"
End Property

Private Property Get IOxControl_AccessibilityName() As String
    IOxControl_AccessibilityName = mCore.Name
End Property

Private Property Get IOxControl_AccessibilityValue() As String
    IOxControl_AccessibilityValue = mCore.DisplayText
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
    IOxControl_AccessibilityPatterns = "static-text"
End Property

Private Property Get IOxControl_AccessibilityRowCount() As Long
    IOxControl_AccessibilityRowCount = 0
End Property

Private Property Get IOxControl_AccessibilityColumnCount() As Long
    IOxControl_AccessibilityColumnCount = 0
End Property
