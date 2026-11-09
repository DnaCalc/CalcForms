Option Explicit
Implements IOxControl

' MSForms-shaped Forms.OptionButton.1 control. Value is a Boolean radio selection owned by VBA object
' state; selecting True clears peer OptionButtons in the same Controls collection with
' the same GroupName. Exact FM20 event ordering for peer deselection is still oracle-gated.

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

Private mCore As OxControlCore
Private mValue As Variant
Private mGroupName As String
Private mEditDirty As Boolean
Private mFocused As Boolean

Private Sub Class_Initialize()
    Set mCore = Nothing
    EnsureCore
End Sub

Private Sub EnsureCore()
    If Not mCore Is Nothing Then Exit Sub
    Set mCore = New OxControlCore
    mCore.Init oxControlOptionButton
    mValue = False
    mGroupName = ""
    mEditDirty = False
    mFocused = False
End Sub

Private Property Get IOxControl_Core() As OxControlCore
    EnsureCore
    Set IOxControl_Core = mCore
End Property

Public Property Get Core() As OxControlCore
    EnsureCore
    Set Core = mCore
End Property

Private Sub IOxControl_Render(ByVal Surface As OxSceneBuilder)
    EnsureCore
    OxThemePaintOptionButton mCore, Surface, IsOn(), mFocused
End Sub

Private Property Get IOxControl_HasChildren() As Boolean
    IOxControl_HasChildren = False
End Property

Private Property Get IOxControl_Children() As Controls
    Set IOxControl_Children = Nothing
End Property

Public Property Get Value() As Variant
    Value = mValue
End Property
Attribute Value.VB_UserMemId = 0
Public Property Let Value(ByVal NewValue As Variant)
    Dim Coerced As Variant
    Coerced = CoerceValue(NewValue)
    If IsNull(Coerced) Then
        If Not IsNull(mValue) Then
            mValue = Null
            mCore.MarkDirty
            RaiseEvent Change
        End If
    Else
        SetValue CBool(Coerced), False, True
    End If
End Property

' Native FM20 Value is a Variant holding Boolean or Null (measured in Excel 16.0.20527, see
' docs/evidence/.../oxforms-jbjp.128): Null and Empty give Null; Boolean passes through; Integer and
' Long give False for 0, True for 1, otherwise Null; Byte, Single, Double, Currency, Decimal and Date
' give False for zero and True otherwise; strings are True/False by name or by numeric text rounded
' to 0 or 1, otherwise Null.
Private Function CoerceValue(ByVal V As Variant) As Variant
    Dim Text As String
    Dim Number As Double
    Select Case VarType(V)
        Case vbBoolean
            CoerceValue = V
        Case vbInteger, vbLong
            If V = 0 Then
                CoerceValue = False
            ElseIf V = 1 Then
                CoerceValue = True
            Else
                CoerceValue = Null
            End If
        Case vbByte, vbSingle, vbDouble, vbCurrency, vbDecimal, vbDate
            CoerceValue = (V <> 0)
        Case vbString
            Text = LCase$(Trim$(V))
            If Text = "true" Then
                CoerceValue = True
            ElseIf Text = "false" Then
                CoerceValue = False
            ElseIf IsNumeric(Text) Then
                Number = CDbl(Text)
                If Abs(Number) > 1000000# Then
                    CoerceValue = Null
                ElseIf CLng(Number) = 0 Then
                    CoerceValue = False
                ElseIf CLng(Number) = 1 Then
                    CoerceValue = True
                Else
                    CoerceValue = Null
                End If
            Else
                CoerceValue = Null
            End If
        Case Else
            CoerceValue = Null
    End Select
End Function

Private Function IsOn() As Boolean
    If IsNull(mValue) Then
        IsOn = False
    Else
        IsOn = CBool(mValue)
    End If
End Function

Public Property Get GroupName() As String
    GroupName = mGroupName
End Property
Public Property Let GroupName(ByVal NewValue As String)
    If mGroupName <> NewValue Then
        mGroupName = NewValue
        If IsOn() Then ClearGroupPeers False
        mCore.MarkDirty
    End If
End Property

Public Property Get Caption() As String
    Caption = mCore.DisplayText
End Property
Public Property Let Caption(ByVal NewCaption As String)
    mCore.DisplayText = NewCaption
End Property

Public Property Get Name() As String
    Name = mCore.Name
End Property

Public Property Get Left() As Single
    Left = mCore.Left
End Property
Public Property Let Left(ByVal NewValue As Single)
    mCore.Left = NewValue
End Property

Public Property Get Top() As Single
    Top = mCore.Top
End Property
Public Property Let Top(ByVal NewValue As Single)
    mCore.Top = NewValue
End Property

Public Property Get Width() As Single
    Width = mCore.Width
End Property
Public Property Let Width(ByVal NewValue As Single)
    mCore.Width = NewValue
End Property

Public Property Get Height() As Single
    Height = mCore.Height
End Property
Public Property Let Height(ByVal NewValue As Single)
    mCore.Height = NewValue
End Property

Public Property Get Visible() As Boolean
    Visible = mCore.Visible
End Property
Public Property Let Visible(ByVal NewValue As Boolean)
    mCore.Visible = NewValue
End Property

Public Property Get Enabled() As Boolean
    Enabled = mCore.Enabled
End Property
Public Property Let Enabled(ByVal NewValue As Boolean)
    mCore.Enabled = NewValue
End Property

Private Sub IOxControl_OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    PerformMouseDown Button, Shift, X, Y
End Sub

Private Sub IOxControl_OnMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    PerformMouseUp Button, Shift, X, Y
End Sub

Private Sub IOxControl_OnMouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
End Sub

Private Sub IOxControl_OnClick()
    SelectForUser
End Sub

Private Property Get IOxControl_SupportsClick() As Boolean
    IOxControl_SupportsClick = mCore.SupportsClick
End Property

Private Property Get IOxControl_HasPressedVisual() As Boolean
    IOxControl_HasPressedVisual = mCore.HasPressedVisual
End Property

Private Function IOxControl_OnKeyDown(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
    IOxControl_OnKeyDown = PerformKeyDown(KeyCode, Shift)
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

Private Function IOxControl_TryKeyboardActivate(ByVal KeyCode As Integer, ByVal Shift As Integer, ByVal HasDefaultButton As Boolean) As Boolean
    If Not mCore.Toggleable Then Exit Function
    If Shift <> 0 Then Exit Function
    If KeyCode = 32 Then
        SelectForUser
        IOxControl_TryKeyboardActivate = True
    End If
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
    IOxControl_AccessibilityRole = "radio"
End Property

Private Property Get IOxControl_AccessibilityName() As String
    IOxControl_AccessibilityName = mCore.Name
End Property

Private Property Get IOxControl_AccessibilityValue() As String
    If IsNull(mValue) Then
        IOxControl_AccessibilityValue = ""
    Else
        IOxControl_AccessibilityValue = CStr(mValue)
    End If
End Property

Private Property Get IOxControl_AccessibilitySelected() As Boolean
    IOxControl_AccessibilitySelected = IsOn()
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
    IOxControl_AccessibilityPatterns = "selection,value"
End Property

Private Property Get IOxControl_AccessibilityRowCount() As Long
    IOxControl_AccessibilityRowCount = 0
End Property

Private Property Get IOxControl_AccessibilityColumnCount() As Long
    IOxControl_AccessibilityColumnCount = 0
End Property

Public Sub PerformSelect()
    SelectForUser
End Sub

Public Sub SetValueFromGroup(ByVal NewValue As Boolean, ByVal RaiseChange As Boolean)
    SetValue NewValue, False, RaiseChange
End Sub

Private Sub SelectForUser()
    If Not IsOn() Then
        SetValue True, True, True
    Else
        RaiseEvent Click
    End If
End Sub

Private Sub SetValue(ByVal NewValue As Boolean, ByVal UserEdit As Boolean, ByVal RaiseChange As Boolean)
    Dim Changed As Boolean
    If NewValue And Not IsOn() Then ClearGroupPeers RaiseChange
    If IsNull(mValue) Then
        Changed = True
    Else
        Changed = (mValue <> NewValue)
    End If
    If Changed Then
        mValue = NewValue
        If UserEdit Then mEditDirty = True
        mCore.MarkDirty
        If RaiseChange Then
            RaiseEvent Change
            If NewValue And Not UserEdit Then RaiseEvent Click
        End If
    End If
    If UserEdit Then RaiseEvent Click
End Sub

Private Sub ClearGroupPeers(ByVal RaiseChange As Boolean)
    Dim Peers As Controls
    Set Peers = mCore.PeerControls
    If Peers Is Nothing Then Exit Sub
    Dim I As Long
    Dim Control As IOxControl
    For I = 1 To Peers.Count
        Set Control = Peers.Item(I)
        If Control.Core.Kind = oxControlOptionButton Then
            If Control.Core.NodeId <> mCore.NodeId Then
                Dim Peer As OptionButtonControl
                Set Peer = Control
                If StrComp(Peer.GroupName, mGroupName, vbTextCompare) = 0 Then
                    Peer.SetValueFromGroup False, RaiseChange
                End If
            End If
        End If
    Next I
End Sub

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

Public Sub PerformEnter()
    RaiseEvent Enter
End Sub

Public Function PerformBeforeUpdate() As Boolean
    Dim cancel As ReturnBoolean
    Set cancel = New ReturnBoolean
    RaiseEvent BeforeUpdate(cancel)
    PerformBeforeUpdate = cancel.Value
End Function

Public Sub PerformAfterUpdate()
    RaiseEvent AfterUpdate
End Sub
