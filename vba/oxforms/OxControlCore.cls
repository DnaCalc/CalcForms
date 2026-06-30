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
' Transient interaction visual: True while a press is armed on this control (mouse-down
' inside a pressable control until the matching up). Render-affecting (the classic theme
' paints a pressed CommandButton/CheckBox face), so a change marks the control dirty. Owned
' by the interaction reducer (OxReducer), never by user code; not persisted form state.
Private mPressed As Boolean
Private mHost As IOxControlHost
Private mOwner As IOxControl
Private mNodeId As Long
Private mBackColor As Long
Private mForeColor As Long
Private mBorderColor As Long
Private mSpecialEffect As fmSpecialEffect
Private mBorderStyle As fmBorderStyle
Private mFontSize As Single
Private mAutoSize As Boolean
' Transient per-render scratch: the content-hash text-run id the measure pre-pass
' obtained from OxForms.Surface.MeasureBatch (a decimal u64 as a String, since it does
' not fit a Long). Set each render, read by OxControlPaint; never persisted state.
Private mRunId As String
' Transient per-render scratch: the caption's measured size in points (advance width,
' and ascent+descent height), from the MeasureBatch result. The layout pass reads
' these to shrink-wrap an AutoSize control before it paints.
Private mMeasuredWidth As Single
Private mMeasuredHeight As Single

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
    mBorderStyle = fmBorderStyleNone
    ' MSForms default font is 8pt (Microsoft Sans Serif / Tahoma).
    mFontSize = 8
    mAutoSize = False
    mPressed = False
    mRunId = ""
    mMeasuredWidth = 0
    mMeasuredHeight = 0

    Select Case Kind
        Case oxControlLabel
            mFocusable = False
            mTabStop = False
            mSpecialEffect = fmSpecialEffectFlat
        Case oxControlCommandButton
            mFocusable = True
            mTabStop = True
            mSpecialEffect = fmSpecialEffectRaised
        Case oxControlTextBox
            mFocusable = True
            mTabStop = True
            mSpecialEffect = fmSpecialEffectSunken
        Case Else
            mFocusable = True
            mTabStop = True
            mSpecialEffect = fmSpecialEffectSunken
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

' AutoSize (MSForms): when True, the control shrink-wraps its caption — the layout pass
' derives Width/Height from the measured run plus padding before it paints. A font-size
' or caption change re-measures and re-fits.
Public Property Get AutoSize() As Boolean
    AutoSize = mAutoSize
End Property
Public Property Let AutoSize(ByVal Value As Boolean)
    mAutoSize = Value
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

' Render-internal geometry write for the AutoSize layout pass: set Width/Height WITHOUT
' MarkDirty, because shrink-wrap bounds are render-DERIVED, not user/handler state.
' Routing them through the dirty channel would leave the control dirty after every render,
' so the runtime's sync_properties would see a phantom dirty for an untouched AutoSize
' control. (Mirrors how RunId is set — render output, not tracked state.)
Public Sub SetAutoSizeBounds(ByVal NewWidth As Single, ByVal NewHeight As Single)
    mWidth = NewWidth
    mHeight = NewHeight
End Sub

' Transient render scratch: the caption's measured size (points), set by the measure
' pre-pass, read by the AutoSize layout pass.
Public Property Get MeasuredWidth() As Single
    MeasuredWidth = mMeasuredWidth
End Property
Public Property Let MeasuredWidth(ByVal Value As Single)
    mMeasuredWidth = Value
End Property
Public Property Get MeasuredHeight() As Single
    MeasuredHeight = mMeasuredHeight
End Property
Public Property Let MeasuredHeight(ByVal Value As Single)
    mMeasuredHeight = Value
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

Public Property Get SpecialEffect() As fmSpecialEffect
    SpecialEffect = mSpecialEffect
End Property
Public Property Let SpecialEffect(ByVal Value As fmSpecialEffect)
    mSpecialEffect = Value
    MarkDirty
End Property

Public Property Get BorderStyle() As fmBorderStyle
    BorderStyle = mBorderStyle
End Property
Public Property Let BorderStyle(ByVal Value As fmBorderStyle)
    mBorderStyle = Value
    MarkDirty
End Property

' Transient pressed visual (see the field comment). Set by OxReducer on mouse-down inside a
' pressable control and cleared on the matching up. A change is render-affecting, so it marks
' the control dirty (guarded so a no-op write does not invalidate).
Public Property Get Pressed() As Boolean
    Pressed = mPressed
End Property
Public Property Let Pressed(ByVal Value As Boolean)
    If mPressed <> Value Then
        mPressed = Value
        MarkDirty
    End If
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
