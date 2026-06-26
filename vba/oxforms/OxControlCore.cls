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
Private mNodeId As Long
Private mBackColor As Long
Private mForeColor As Long
Private mBorderColor As Long
Private mSpecialEffect As OxSpecialEffect
Private mBorderStyle As OxBorderStyle
Private mFontSize As Single
' Transient per-render scratch: the content-hash text-run id the measure pre-pass
' obtained from OxForms.Surface.MeasureText (a decimal u64 as a String, since it does
' not fit a Long). Set each render, read by OxControlPaint; never persisted state.
Private mRunId As String

' Called by the concrete control's Class_Initialize with its intrinsic kind. Sets
' the per-kind appearance defaults from [MS-OFORMS] s5.6: morph controls (TextBox)
' default Sunken; Form/Label/Image default Flat. CommandButton is not a morph
' control and has no MS-OFORMS SpecialEffect; OxForms gives its button face a
' Raised default. The color band starts at oxColorAuto (theme-resolved).
Public Sub Init(ByVal Kind As OxControlKind)
    mKind = Kind
    mVisible = True
    mEnabled = True
    mZOrder = 0
    mTabIndex = 0
    mDisplayText = ""
    mNodeId = 0
    mBackColor = oxColorAuto
    mForeColor = oxColorAuto
    mBorderColor = oxColorAuto
    mBorderStyle = oxBorderNone
    ' MSForms default font is 8pt (Microsoft Sans Serif / Tahoma).
    mFontSize = 8
    mRunId = ""

    Select Case Kind
        Case oxControlLabel
            mFocusable = False
            mTabStop = False
            mSpecialEffect = oxEffectFlat
        Case oxControlCommandButton
            mFocusable = True
            mTabStop = True
            mSpecialEffect = oxEffectRaised
        Case oxControlTextBox
            mFocusable = True
            mTabStop = True
            mSpecialEffect = oxEffectSunken
        Case Else
            mFocusable = True
            mTabStop = True
            mSpecialEffect = oxEffectSunken
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

' Font size in points (MSForms units; default 8). Part of the text-run identity, so a
' change re-measures and re-renders.
Public Property Get FontSize() As Single
    FontSize = mFontSize
End Property
Public Property Let FontSize(ByVal Value As Single)
    mFontSize = Value
    MarkDirty
End Property

' Transient render scratch (see the field comment): the text-run id string the measure
' pre-pass stamped this frame. Not dirty-tracked — it is derived render output.
Public Property Get RunId() As String
    RunId = mRunId
End Property
Public Property Let RunId(ByVal Value As String)
    mRunId = Value
End Property

' Stable, control-derived scene identity (the kernel's NodeId). Assigned once by
' the container at Add time and never reused, so a repaint diffs by identity rather
' than array position. The form/root is always node 0; controls intern nonzero ids.
Public Property Get NodeId() As Long
    NodeId = mNodeId
End Property
Public Property Let NodeId(ByVal Value As Long)
    mNodeId = Value
End Property

' --- Appearance band (owned in VBA; the kernel never sees control appearance) ---
' Colors are OxForms 0xRRGGBB Longs, or oxColorAuto to defer to the theme. (The
' OLE_COLOR 0x80000000 system-index form and Surface.ResolveSysColor land with the
' system-color crossing; until then the classic theme supplies concrete colors.)
Public Property Get BackColor() As Long
    BackColor = mBackColor
End Property
Public Property Let BackColor(ByVal Value As Long)
    mBackColor = Value
    MarkDirty
End Property

Public Property Get ForeColor() As Long
    ForeColor = mForeColor
End Property
Public Property Let ForeColor(ByVal Value As Long)
    mForeColor = Value
    MarkDirty
End Property

Public Property Get BorderColor() As Long
    BorderColor = mBorderColor
End Property
Public Property Let BorderColor(ByVal Value As Long)
    mBorderColor = Value
    MarkDirty
End Property

Public Property Get SpecialEffect() As OxSpecialEffect
    SpecialEffect = mSpecialEffect
End Property
Public Property Let SpecialEffect(ByVal Value As OxSpecialEffect)
    mSpecialEffect = Value
    MarkDirty
End Property

Public Property Get BorderStyle() As OxBorderStyle
    BorderStyle = mBorderStyle
End Property
Public Property Let BorderStyle(ByVal Value As OxBorderStyle)
    mBorderStyle = Value
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
