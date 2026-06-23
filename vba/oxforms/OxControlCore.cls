Option Explicit

' Shared state and behavior for every OxForms control.
'
' Controls compose exactly one OxControlCore and expose it through
' IOxControl.Core. This is how the object model gets "inheritance" without VBA
' class inheritance: common identity, geometry, flags, the generic display text,
' dirty tracking, and the host-invalidation seam all live here once, so each
' concrete control stays thin (typed sugar properties + native events only).
'
' Geometry is in points (MSForms units). The runtime maps this core 1:1 onto the
' oxforms-core ControlNode during materialization.

Private mName As String
Private mKind As OxControlKind
Private mLeft As Single
Private mTop As Single
Private mWidth As Single
Private mHeight As Single
Private mZOrder As Long
Private mVisible As Boolean
Private mEnabled As Boolean
Private mFocusable As Boolean
Private mTabStop As Boolean
Private mTabIndex As Long
Private mDisplayText As String
Private mDirty As Boolean
Private mHost As IOxControlHost
Private mOwner As IOxControl

' Called by the concrete control's Class_Initialize with its intrinsic kind.
Public Sub Init(ByVal Kind As OxControlKind)
    mKind = Kind
    mVisible = True
    mEnabled = True
    mZOrder = 0
    mTabIndex = 0
    mDisplayText = ""

    Select Case Kind
        Case oxControlLabel
            mFocusable = False
            mTabStop = False
        Case Else
            mFocusable = True
            mTabStop = True
    End Select
End Sub

' Called by the container when the control is added, wiring the invalidation seam.
Public Sub Bind(ByVal Host As IOxControlHost, ByVal Owner As IOxControl)
    Set mHost = Host
    Set mOwner = Owner
End Sub

Public Property Get Kind() As OxControlKind
    Kind = mKind
End Property

Public Property Get Name() As String
    Name = mName
End Property
Public Property Let Name(ByVal Value As String)
    mName = Value
End Property

Public Property Get Left() As Single
    Left = mLeft
End Property
Public Property Let Left(ByVal Value As Single)
    mLeft = Value
    MarkDirty
End Property

Public Property Get Top() As Single
    Top = mTop
End Property
Public Property Let Top(ByVal Value As Single)
    mTop = Value
    MarkDirty
End Property

Public Property Get Width() As Single
    Width = mWidth
End Property
Public Property Let Width(ByVal Value As Single)
    mWidth = Value
    MarkDirty
End Property

Public Property Get Height() As Single
    Height = mHeight
End Property
Public Property Let Height(ByVal Value As Single)
    mHeight = Value
    MarkDirty
End Property

Public Property Get ZOrder() As Long
    ZOrder = mZOrder
End Property
Public Property Let ZOrder(ByVal Value As Long)
    mZOrder = Value
    MarkDirty
End Property

Public Property Get Visible() As Boolean
    Visible = mVisible
End Property
Public Property Let Visible(ByVal Value As Boolean)
    mVisible = Value
    MarkDirty
End Property

Public Property Get Enabled() As Boolean
    Enabled = mEnabled
End Property
Public Property Let Enabled(ByVal Value As Boolean)
    mEnabled = Value
    MarkDirty
End Property

Public Property Get Focusable() As Boolean
    Focusable = mFocusable
End Property

Public Property Get TabStop() As Boolean
    TabStop = mTabStop
End Property
Public Property Let TabStop(ByVal Value As Boolean)
    mTabStop = Value
End Property

Public Property Get TabIndex() As Long
    TabIndex = mTabIndex
End Property
Public Property Let TabIndex(ByVal Value As Long)
    mTabIndex = Value
End Property

' Generic render text projected by each control (Label/CommandButton Caption,
' TextBox Text). Keeping it on the core lets the runtime read display text
' uniformly without switching on control kind.
Public Property Get DisplayText() As String
    DisplayText = mDisplayText
End Property
Public Property Let DisplayText(ByVal Value As String)
    mDisplayText = Value
    MarkDirty
End Property

Public Property Get Dirty() As Boolean
    Dirty = mDirty
End Property

Public Sub ClearDirty()
    mDirty = False
End Sub

' Flag the control as needing repaint and notify the host (if bound). Render
' affecting setters above call this; the runtime drains host invalidations.
Public Sub MarkDirty()
    mDirty = True
    If Not mHost Is Nothing Then
        mHost.OnControlInvalidated mOwner
    End If
End Sub
