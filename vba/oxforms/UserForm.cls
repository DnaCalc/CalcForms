Option Explicit
Implements IOxControlHost

' MSForms-shaped UserForm container. Owns the control set and is the host the
' controls notify on change. A user form (or, later, the .frm loader) builds its
' controls the Forms 2.0 way -- Controls.Add by ProgID -- which creates the control and
' calls RegisterControl here to wire its invalidation seam + assign its NodeId. The runtime
' enumerates Controls to materialize the tree and drains InvalidatedControls for repaints.

Private mName As String
Private mCaption As String
Private mLeft As Single
Private mTop As Single
Private mWidth As Single
Private mHeight As Single
Private mControls As Controls
Private mInvalidated As Collection
Private mNextNodeId As Long
Private mLastSceneToken As String
' Incremental render state (oxforms-rq5.2): once a resident scene exists, Render emits an
' incremental patch (Upsert only the invalidated controls; the kernel retains the rest)
' against mLastSceneToken instead of a full rebuild. mSuspendDepth gates the
' SuspendLayout/ResumeLayout coalescing band.
Private mHasResident As Boolean
Private mSuspendDepth As Long

' The single UI font id v1 registers (Microsoft Sans Serif / Tahoma). RegisterFont and
' multiple faces land later; until then every run measures against this one face id.
' MUST equal the Rust-side FONT_ID the backend registers the face under (oxforms-bootstrap
' `FONT_ID`, and the FontTable the rasterizer resolves against) — otherwise the run's
' font id would miss the FontTable and captions would be silently dropped. The end-to-end
' glyph-coverage test `vba_self_render_rasterizes_captions_through_the_real_shaper` pins it.
Private Const OX_DEFAULT_FONT_ID As Long = 1

' Sentinel SubmitPatch returns when an incremental patch's base no longer matches the
' resident frame; the form self-heals to a full rebuild. MUST equal the adapter's
' STALE_BASE_SENTINEL (surface.rs). See RENDERING_ARCHITECTURE.md §16.
Private Const OX_STALE_SENTINEL As String = "STALE"

Private Sub Class_Initialize()
    Set mControls = New Controls
    mControls.Bind Me
    Set mInvalidated = New Collection
    ' Node 0 is reserved for the form/root; controls intern from 1 upward. The id
    ' is a stable per-control serial (assigned once at Add, never reused), so a
    ' repaint diffs by identity rather than array position.
    mNextNodeId = 1
End Sub

' Bind a control to this form as its invalidation host and assign its stable NodeId.
' Called by Controls.Add (the Forms 2.0 creation path); the Controls collection owns
' tracking, the form owns identity + the host seam.
Public Sub RegisterControl(ByVal Control As IOxControl)
    Control.Core.Bind Me, Control
    Control.Core.NodeId = mNextNodeId
    mNextNodeId = mNextNodeId + 1
End Sub

' The Forms 2.0 Controls collection: callers create controls with
' Controls.Add "Forms.Label.1", "Name".
Public Property Get Controls() As Controls
    Set Controls = mControls
End Property

Public Function ControlByName(ByVal Name As String) As IOxControl
    Set ControlByName = mControls.Item(Name)
End Function

Public Property Get Count() As Long
    Count = mControls.Count
End Property

' Controls whose render-affecting state changed since the last drain. The runtime
' reads this to schedule repaints, then calls ClearInvalidations.
Public Property Get InvalidatedControls() As Collection
    Set InvalidatedControls = mInvalidated
End Property

Public Sub ClearInvalidations()
    Set mInvalidated = New Collection
End Sub

' Coalesce a bulk multi-setter update into a single re-emit (MSForms shape). While
' suspended, render-affecting setters still mark their control dirty (Core.Dirty) but the
' host is not notified, so no control is scheduled mid-update; ResumeLayout re-derives the
' invalidation set from the dirty controls once. Reentrant-safe via a depth counter.
Public Sub SuspendLayout()
    mSuspendDepth = mSuspendDepth + 1
End Sub

Public Sub ResumeLayout()
    If mSuspendDepth > 0 Then mSuspendDepth = mSuspendDepth - 1
    If mSuspendDepth = 0 Then
        Dim I As Long
        Dim Control As IOxControl
        For I = 1 To mControls.Count
            Set Control = mControls.Item(I)
            If Control.Core.Dirty Then RecordInvalidated Control
        Next I
    End If
End Sub

' Record a control in the invalidation set, DEDUPED by its stable NodeId: a control
' invalidated by several setters in one frame appears exactly once, so an incremental patch
' carries one node per changed control. The membership scan is over the (small) pending
' set, not all controls. (A keyed Collection + On Error Resume Next is the usual VBA dedup,
' but On Error is unproven on OxVba and unused elsewhere here, so this stays explicit.)
Private Sub RecordInvalidated(ByVal Control As IOxControl)
    Dim I As Long
    Dim Existing As IOxControl
    For I = 1 To mInvalidated.Count
        Set Existing = mInvalidated.Item(I)
        If Existing.Core.NodeId = Control.Core.NodeId Then Exit Sub
    Next I
    mInvalidated.Add Control
End Sub

' Build a FULL-rebuild ScenePatch for the whole form: the root/form node (its background
' fill plus the controls' paint-order child list) followed by every control measuring,
' laying out, and painting itself into its own node. The single batched payload
' OxForms.Surface.SubmitPatch consumes -- it crosses the boundary exactly once. BaseToken
' is the resident frame token BeginScene returned. Render uses this for the first frame
' and the STALE self-heal; render_scene_probe_form drives it directly.
Public Function BuildScenePatch( _
        ByVal BaseToken As String, _
        ByVal Builder As OxSceneBuilder, _
        ByVal Surface As Object, _
        ByVal DpiX As Long, _
        ByVal DpiY As Long) As String
    Builder.BeginPatch BaseToken, CLng(mWidth), CLng(mHeight), DpiX, DpiY

    Dim I As Long
    Dim Control As IOxControl

    ' Root/form node: client background plus the controls' paint-order children.
    Builder.OpenNode 0, False, 0, 0, 0, 0, mWidth, mHeight, True
    For I = 1 To mControls.Count
        Set Control = mControls.Item(I)
        Builder.AddChild Control.Core.NodeId
    Next I
    Builder.FillRect 0, 0, mWidth, mHeight, OxThemeFormBackColor(), 255
    Builder.CloseNode

    ' Each control measures -> lays out -> paints itself into its own node.
    For I = 1 To mControls.Count
        Set Control = mControls.Item(I)
        EmitControl Control, Builder, Surface
    Next I

    BuildScenePatch = Builder.ToPatchJson()
End Function

' Measure -> layout -> paint ONE control into the builder as an Upsert node. Shared by the
' full rebuild and the incremental path so a control's emitted node is byte-identical
' either way -- which is what lets an incremental patch reach the same resident scene a
' full rebuild would (determinism invariant (c), RENDERING_ARCHITECTURE.md §10).
'   measure: stamp the content-hash run id + measured size from OxForms.Surface.MeasureText
'     (the §8 cache-miss path; the caption crosses here, once) straight onto the live core.
'   layout: an AutoSize control shrink-wraps its caption (measured run + 4pt/3pt insets),
'     written WITHOUT MarkDirty (see SetAutoSizeBounds) so a re-render leaves no phantom dirty.
'   paint: the control emits its own node.
Private Sub EmitControl( _
        ByVal Control As IOxControl, ByVal Builder As OxSceneBuilder, ByVal Surface As Object)
    Dim Cap As String, Rid As String, MeasW As Single, MeasH As Single
    Cap = Control.Core.DisplayText
    If Len(Cap) > 0 Then
        ParseMeasure _
            Surface.MeasureText(OX_DEFAULT_FONT_ID, CLng(Control.Core.FontSize * 1000), Cap), _
            Rid, MeasW, MeasH
        Control.Core.RunId = Rid
        Control.Core.MeasuredWidth = MeasW
        Control.Core.MeasuredHeight = MeasH
    Else
        Control.Core.RunId = ""
        Control.Core.MeasuredWidth = 0
        Control.Core.MeasuredHeight = 0
    End If

    If Control.Core.AutoSize And Len(Control.Core.DisplayText) > 0 Then
        Control.Core.SetAutoSizeBounds _
            Control.Core.MeasuredWidth + 8, Control.Core.MeasuredHeight + 6
    End If

    Control.Render Builder

    ' The control's current state is now committed to the resident scene, so it is no
    ' longer dirty. Clearing it here (the render path) keeps Core.Dirty meaning "changed
    ' since last emitted" -- which is what ResumeLayout's dirty re-derive assumes. Without
    ' this, a render-only flow (no runtime dispatch, which is the only other ClearDirty
    ' caller) would let Core.Dirty accumulate, so each later ResumeLayout band would
    ' re-invalidate every control ever changed.
    Control.Core.ClearDirty
End Sub

' Re-render across the OxForms.Surface boundary -- the Re-render the runtime invokes each
' frame (RENDERING_ARCHITECTURE.md §16). The form self-renders: it knows its own size, so
' it drives the crossing itself. First frame (no resident scene) is a full rebuild against
' a fresh BeginScene; afterwards each frame emits an INCREMENTAL patch carrying only the
' invalidated controls against the resident token (oxforms-rq5.2) -- one control change
' crosses as a one-node patch (the §6 crossing budget), and an unchanged frame does no
' crossing at all. A stale base self-heals to a full rebuild.
'
' Scope note: the incremental path covers per-CONTROL changes (every render-affecting
' OxControlCore setter calls MarkDirty -> the control is invalidated -> re-emitted). The
' ROOT/form node (background, size, child list) is emitted only by a full rebuild, so a
' runtime form-size/background change or a control Add/Remove after the first frame is not
' yet reflected incrementally. That is dormant in W007 (form geometry + the control set are
' fixed at Build, before the first render); structural re-emit is future work.
Public Sub Render(ByVal DpiX As Long, ByVal DpiY As Long)
    Dim Surface As Object
    Set Surface = CreateObject("OxForms.Surface")

    If Not mHasResident Then
        RenderFull Surface, DpiX, DpiY
    ElseIf mInvalidated.Count > 0 Then
        If RenderIncremental(Surface, DpiX, DpiY) = OX_STALE_SENTINEL Then
            ' The resident base drifted (e.g. the surface was re-initialized): rebuild.
            RenderFull Surface, DpiX, DpiY
        End If
    Else
        ' Nothing changed since the last frame: no crossing, no new resident revision.
        Exit Sub
    End If

    ClearInvalidations
End Sub

' Full rebuild against a fresh BeginScene base; (re)establishes the resident scene. Used
' for the first frame and the STALE self-heal.
Private Sub RenderFull(ByVal Surface As Object, ByVal DpiX As Long, ByVal DpiY As Long)
    Dim BaseToken As String
    BaseToken = Surface.BeginScene(CLng(mWidth), CLng(mHeight), DpiX, DpiY)

    Dim Builder As OxSceneBuilder
    Set Builder = New OxSceneBuilder
    mLastSceneToken = Surface.SubmitPatch( _
        BuildScenePatch(BaseToken, Builder, Surface, DpiX, DpiY))
    mHasResident = True
End Sub

' Incremental patch against the resident token: Upsert only the invalidated controls. The
' root and unchanged controls are unmentioned, so the kernel RETAINS them. Returns the new
' frame token, or OX_STALE_SENTINEL if the base no longer matched (the caller rebuilds).
Private Function RenderIncremental( _
        ByVal Surface As Object, ByVal DpiX As Long, ByVal DpiY As Long) As String
    Dim Builder As OxSceneBuilder
    Set Builder = New OxSceneBuilder
    Builder.BeginPatch mLastSceneToken, CLng(mWidth), CLng(mHeight), DpiX, DpiY

    Dim I As Long, Control As IOxControl
    For I = 1 To mInvalidated.Count
        Set Control = mInvalidated.Item(I)
        EmitControl Control, Builder, Surface
    Next I

    Dim NewToken As String
    NewToken = Surface.SubmitPatch(Builder.ToPatchJson())
    If NewToken <> OX_STALE_SENTINEL Then mLastSceneToken = NewToken
    RenderIncremental = NewToken
End Function

' Parse a MeasureText result "id:advance:ascent:descent:linegap" (metrics in 1/1000 pt)
' into the run id (a String) and the caption's measured size in points (advance width;
' ascent+descent height). Avoids a Split dependency (InStr + Mid$ + Val). Uses Mid$ rather
' than Left$ ON PURPOSE: UserForm has a Left property and OxVba resolves the bare Left$
' intrinsic to that member (returning 0) — the Left/Left$ shadowing divergence in
' docs/handovers/HANDOVER_OxVba_left_intrinsic_shadowed.md. Val is locale-independent for
' the integer milli-pt fields. The 5-field shape is OxForms.Surface.MeasureText's contract.
Private Sub ParseMeasure( _
        ByVal S As String, ByRef RunId As String, _
        ByRef WidthPt As Single, ByRef HeightPt As Single)
    WidthPt = 0
    HeightPt = 0
    Dim p1 As Long, p2 As Long, p3 As Long, p4 As Long
    p1 = InStr(S, ":")
    If p1 = 0 Then
        ' No metrics (a bare id or unexpected shape): degrade gracefully — take the whole
        ' string as the id, zero metrics — rather than raise on a contract drift.
        RunId = S
        Exit Sub
    End If
    RunId = Mid$(S, 1, p1 - 1)
    p2 = InStr(p1 + 1, S, ":")
    p3 = InStr(p2 + 1, S, ":")
    p4 = InStr(p3 + 1, S, ":")
    If p2 = 0 Or p3 = 0 Or p4 = 0 Then Exit Sub
    WidthPt = Val(Mid$(S, p1 + 1, p2 - p1 - 1)) / 1000
    HeightPt = (Val(Mid$(S, p2 + 1, p3 - p2 - 1)) + Val(Mid$(S, p3 + 1, p4 - p3 - 1))) / 1000
End Sub

Public Property Get LastSceneToken() As String
    LastSceneToken = mLastSceneToken
End Property

Public Property Get Name() As String
    Name = mName
End Property
Public Property Let Name(ByVal Value As String)
    mName = Value
End Property

Public Property Get Caption() As String
    Caption = mCaption
End Property
Public Property Let Caption(ByVal Value As String)
    mCaption = Value
End Property

Public Property Get Left() As Single
    Left = mLeft
End Property
Public Property Let Left(ByVal Value As Single)
    mLeft = Value
End Property

Public Property Get Top() As Single
    Top = mTop
End Property
Public Property Let Top(ByVal Value As Single)
    mTop = Value
End Property

Public Property Get Width() As Single
    Width = mWidth
End Property
Public Property Let Width(ByVal Value As Single)
    mWidth = Value
End Property

Public Property Get Height() As Single
    Height = mHeight
End Property
Public Property Let Height(ByVal Value As Single)
    mHeight = Value
End Property

' --- IOxControlHost ---
' A control's render-affecting state changed. While a SuspendLayout band is open the
' notification is dropped (the control's Core.Dirty is still set, so ResumeLayout picks it
' up); otherwise it is recorded once (deduped by NodeId).
Private Sub IOxControlHost_OnControlInvalidated(ByVal Control As IOxControl)
    If mSuspendDepth = 0 Then RecordInvalidated Control
End Sub
