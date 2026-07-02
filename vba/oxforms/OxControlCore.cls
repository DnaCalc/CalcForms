Option Explicit

' Shared state and behavior for every OxForms control.
'
' Controls compose exactly one OxControlCore and expose it through
' IOxControl.Core. This is how the object model gets "inheritance" without VBA
' class inheritance: common identity, geometry, flags, the generic display text,
' dirty tracking, and the host-invalidation seam all live here once, so each
' concrete control stays thin (typed sugar properties + native events only).
'
' Geometry is in points (MSForms units). Controls render this core directly into
' stable Scene nodes; no Rust control model materializes or owns the control state.

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
' Intrinsic capability descriptor. These are the control-policy facts OxInteractionManager reads
' through the OxReducer facade for routing/activation decisions; concrete controls may still carry
' dynamic state such as CommandButton.Default, but the kind-level axes live here once.
Private mSupportsClick As Boolean
Private mHasPressedVisual As Boolean
Private mAcceptsTextEditing As Boolean
Private mAcceptsPaste As Boolean
Private mValueEditable As Boolean
Private mToggleable As Boolean
Private mAcceleratorEligible As Boolean
Private mDefaultButtonEligible As Boolean
Private mCancelButtonEligible As Boolean
Private mMousePointer As Long
Private mDisplayText As String
Private mDirty As Boolean
' Transient interaction visual: True while a press is armed on this control (mouse-down
' inside a pressable control until the matching up). Render-affecting (the classic theme
' paints a pressed CommandButton/CheckBox face), so a change marks the control dirty. Owned
' by OxInteractionManager through the OxReducer facade, never by user code; not persisted form state.
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
Private mCaretStopsMilliPtCsv As String

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
    mSupportsClick = False
    mHasPressedVisual = False
    mAcceptsTextEditing = False
    mAcceptsPaste = False
    mValueEditable = False
    mToggleable = False
    mAcceleratorEligible = False
    mDefaultButtonEligible = False
    mCancelButtonEligible = False
    mMousePointer = 0
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
    mCaretStopsMilliPtCsv = ""

    Select Case Kind
        Case oxControlLabel
            mFocusable = False
            mTabStop = False
            mSupportsClick = True
            mSpecialEffect = fmSpecialEffectFlat
        Case oxControlCommandButton
            mFocusable = True
            mTabStop = True
            mSupportsClick = True
            mHasPressedVisual = True
            mAcceleratorEligible = True
            mDefaultButtonEligible = True
            mCancelButtonEligible = True
            mSpecialEffect = fmSpecialEffectRaised
        Case oxControlTextBox
            mFocusable = True
            mTabStop = True
            mAcceptsTextEditing = True
            mAcceptsPaste = True
            mValueEditable = True
            mMousePointer = 3
            mSpecialEffect = fmSpecialEffectSunken
        Case Else
            mFocusable = True
            mTabStop = True
            If Kind = oxControlCheckBox Then
                mSupportsClick = True
                mHasPressedVisual = True
                mValueEditable = True
                mToggleable = True
            End If
            mSpecialEffect = fmSpecialEffectSunken
    End Select
End Sub

' Called by the container when the control is added, wiring the invalidation seam.
Public Sub Bind(ByVal Host As IOxControlHost, ByVal Owner As IOxControl)
    Set mHost = Host
    Set mOwner = Owner
End Sub

' Called when a control is structurally removed from its form. Held references may still exist,
' but they no longer invalidate the removed form or its interaction indexes.
Public Sub Unbind()
    Set mHost = Nothing
    Set mOwner = Nothing
End Sub

Public Property Get Kind() As OxControlKind
    Kind = mKind
End Property

Public Property Get Name() As String
    Name = mName
End Property
Public Property Let Name(ByVal Value As String)
    If mName <> Value Then
        mName = Value
        MarkInteractionDirty
    End If
End Property

Public Property Get Left() As Single
    Left = mLeft
End Property
Public Property Let Left(ByVal Value As Single)
    If mLeft <> Value Then
        mLeft = Value
        MarkDirty
        MarkInteractionDirty
    End If
End Property

Public Property Get Top() As Single
    Top = mTop
End Property
Public Property Let Top(ByVal Value As Single)
    If mTop <> Value Then
        mTop = Value
        MarkDirty
        MarkInteractionDirty
    End If
End Property

Public Property Get Width() As Single
    Width = mWidth
End Property
Public Property Let Width(ByVal Value As Single)
    If mWidth <> Value Then
        mWidth = Value
        MarkDirty
        MarkInteractionDirty
    End If
End Property

Public Property Get Height() As Single
    Height = mHeight
End Property
Public Property Let Height(ByVal Value As Single)
    If mHeight <> Value Then
        mHeight = Value
        MarkDirty
        MarkInteractionDirty
    End If
End Property

Public Property Get ZOrder() As Long
    ZOrder = mZOrder
End Property
Public Property Let ZOrder(ByVal Value As Long)
    If mZOrder <> Value Then
        mZOrder = Value
        MarkDirty
        MarkInteractionDirty
    End If
End Property

Public Property Get Visible() As Boolean
    Visible = mVisible
End Property
Public Property Let Visible(ByVal Value As Boolean)
    If mVisible <> Value Then
        mVisible = Value
        MarkDirty
        MarkInteractionDirty
    End If
End Property

Public Property Get Enabled() As Boolean
    Enabled = mEnabled
End Property
Public Property Let Enabled(ByVal Value As Boolean)
    If mEnabled <> Value Then
        mEnabled = Value
        MarkDirty
        MarkInteractionDirty
    End If
End Property

Public Property Get Focusable() As Boolean
    Focusable = mFocusable
End Property

Public Property Get TabStop() As Boolean
    TabStop = mTabStop
End Property
Public Property Let TabStop(ByVal Value As Boolean)
    If mTabStop <> Value Then
        mTabStop = Value
        MarkInteractionDirty
    End If
End Property

Public Property Get TabIndex() As Long
    TabIndex = mTabIndex
End Property
Public Property Let TabIndex(ByVal Value As Long)
    If mTabIndex <> Value Then
        mTabIndex = Value
        MarkInteractionDirty
    End If
End Property

Public Property Get SupportsClick() As Boolean
    SupportsClick = mSupportsClick
End Property

Public Property Get HasPressedVisual() As Boolean
    HasPressedVisual = mHasPressedVisual
End Property

Public Property Get AcceptsTextEditing() As Boolean
    AcceptsTextEditing = mAcceptsTextEditing
End Property

Public Property Get AcceptsPaste() As Boolean
    AcceptsPaste = mAcceptsPaste
End Property

Public Property Get ValueEditable() As Boolean
    ValueEditable = mValueEditable
End Property

Public Property Get Toggleable() As Boolean
    Toggleable = mToggleable
End Property

Public Property Get AcceleratorEligible() As Boolean
    AcceleratorEligible = mAcceleratorEligible
End Property

Public Property Get DefaultButtonEligible() As Boolean
    DefaultButtonEligible = mDefaultButtonEligible
End Property

Public Property Get CancelButtonEligible() As Boolean
    CancelButtonEligible = mCancelButtonEligible
End Property

Public Property Get MousePointer() As Long
    MousePointer = mMousePointer
End Property

Public Function CapabilityDescriptor() As String
    CapabilityDescriptor = _
        "kind=" & KindName() & _
        ";focusable=" & CStr(mFocusable) & _
        ";tabstop=" & CStr(mTabStop) & _
        ";click=" & CStr(mSupportsClick) & _
        ";pressed=" & CStr(mHasPressedVisual) & _
        ";text=" & CStr(mAcceptsTextEditing) & _
        ";paste=" & CStr(mAcceptsPaste) & _
        ";value=" & CStr(mValueEditable) & _
        ";toggle=" & CStr(mToggleable) & _
        ";accelerator=" & CStr(mAcceleratorEligible) & _
        ";default=" & CStr(mDefaultButtonEligible) & _
        ";cancel=" & CStr(mCancelButtonEligible) & _
        ";cursor=" & CStr(mMousePointer)
End Function

Private Function KindName() As String
    Select Case mKind
        Case oxControlLabel
            KindName = "Label"
        Case oxControlTextBox
            KindName = "TextBox"
        Case oxControlCommandButton
            KindName = "CommandButton"
        Case oxControlCheckBox
            KindName = "CheckBox"
        Case Else
            KindName = "Unknown"
    End Select
End Function

' Generic render text projected by each control (Label/CommandButton Caption,
' TextBox Text). Keeping it on the core lets the runtime read display text
' uniformly without switching on control kind.
Public Property Get DisplayText() As String
    DisplayText = mDisplayText
End Property
Public Property Let DisplayText(ByVal Value As String)
    If mDisplayText <> Value Then
        mDisplayText = Value
        MarkDirty
        If mAcceleratorEligible Or mAutoSize Then MarkInteractionDirty
    End If
End Property

' Font size in points (MSForms units; default 8). Part of the text-run identity, so a
' change re-measures and re-renders.
Public Property Get FontSize() As Single
    FontSize = mFontSize
End Property
Public Property Let FontSize(ByVal Value As Single)
    If mFontSize <> Value Then
        mFontSize = Value
        MarkDirty
        If mAutoSize Then MarkInteractionDirty
    End If
End Property

' AutoSize (MSForms): when True, the control shrink-wraps its caption — the layout pass
' derives Width/Height from the measured run plus padding before it paints. A font-size
' or caption change re-measures and re-fits.
Public Property Get AutoSize() As Boolean
    AutoSize = mAutoSize
End Property
Public Property Let AutoSize(ByVal Value As Boolean)
    If mAutoSize <> Value Then
        mAutoSize = Value
        MarkDirty
        MarkInteractionDirty
    End If
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
    If mWidth <> NewWidth Or mHeight <> NewHeight Then
        mWidth = NewWidth
        mHeight = NewHeight
        MarkInteractionDirty
    End If
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

Public Property Get CaretStopsMilliPtCsv() As String
    CaretStopsMilliPtCsv = mCaretStopsMilliPtCsv
End Property
Public Property Let CaretStopsMilliPtCsv(ByVal Value As String)
    mCaretStopsMilliPtCsv = Value
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
    If mBackColor <> Value Then
        mBackColor = Value
        MarkDirty
    End If
End Property

Public Property Get ForeColor() As Long
    ForeColor = mForeColor
End Property
Public Property Let ForeColor(ByVal Value As Long)
    If mForeColor <> Value Then
        mForeColor = Value
        MarkDirty
    End If
End Property

Public Property Get BorderColor() As Long
    BorderColor = mBorderColor
End Property
Public Property Let BorderColor(ByVal Value As Long)
    If mBorderColor <> Value Then
        mBorderColor = Value
        MarkDirty
    End If
End Property

Public Property Get SpecialEffect() As fmSpecialEffect
    SpecialEffect = mSpecialEffect
End Property
Public Property Let SpecialEffect(ByVal Value As fmSpecialEffect)
    If mSpecialEffect <> Value Then
        mSpecialEffect = Value
        MarkDirty
    End If
End Property

Public Property Get BorderStyle() As fmBorderStyle
    BorderStyle = mBorderStyle
End Property
Public Property Let BorderStyle(ByVal Value As fmBorderStyle)
    If mBorderStyle <> Value Then
        mBorderStyle = Value
        MarkDirty
    End If
End Property

' Transient pressed visual (see the field comment). Set by OxInteractionManager on mouse-down
' inside a pressable control and cleared on the matching up. A change is render-affecting, so it
' marks the control dirty (guarded so a no-op write does not invalidate).
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

' Flag routing/tab/cursor/activation caches as stale without implying the pixels changed.
Public Sub MarkInteractionDirty()
    If Not mHost Is Nothing Then
        mHost.OnInteractionInvalidated mOwner
    End If
End Sub
