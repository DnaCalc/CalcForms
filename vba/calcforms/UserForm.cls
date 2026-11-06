Option Explicit
Implements IOxControlHost
Implements IOxControlContainer

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
Private mInteractionRevision As Long
Private mStructureDirty As Boolean
' Incremental render state (oxforms-rq5.2): once a resident scene exists, Render emits an
' incremental patch (Upsert only the invalidated controls; the kernel retains the rest)
' against mLastSceneToken instead of a full rebuild. mSuspendDepth gates the
' SuspendLayout/ResumeLayout coalescing band.
Private mHasResident As Boolean
Private mSuspendDepth As Long

' The single UI font id v1 registers (Microsoft Sans Serif / Tahoma). RegisterFont and
' multiple faces land later; until then every run measures against this one face id.
' MUST equal the Rust-side FONT_ID the backend registers the face under (calcforms-bootstrap
' `FONT_ID`, and the FontTable the rasterizer resolves against) — otherwise the run's
' font id would miss the FontTable and captions would be silently dropped. The end-to-end
' glyph-coverage test `vba_self_render_rasterizes_captions_through_the_real_shaper` pins it.
Private Const OX_DEFAULT_FONT_ID As Long = 1

' Sentinel SubmitPatch returns when an incremental patch's base no longer matches the
' resident frame; the form self-heals to a full rebuild. MUST equal the adapter's
' STALE_BASE_SENTINEL (surface.rs). See RENDERING_ARCHITECTURE.md §16.
Private Const OX_STALE_SENTINEL As String = "STALE"

Private Sub Class_Initialize()
    Set mControls = Nothing
    Set mInvalidated = Nothing
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
    Control.Core.NodeId = IOxControlHost_AllocateNodeId()
    mStructureDirty = True
    RecordInteractionInvalidated Control
End Sub

' Called by Controls.Remove. The removed control keeps its stable NodeId as historical identity
' but loses its host binding, so later writes through a stale user reference cannot dirty this
' form. The next render is a full rebuild because the root child list changed.
Public Sub UnregisterControl(ByVal Control As IOxControl)
    Control.Core.Unbind
    mStructureDirty = True
    RecordInteractionInvalidated Control
End Sub

' The Forms 2.0 Controls collection: callers create controls with
' Controls.Add "Forms.Label.1", "Name".
Public Property Get Controls() As Controls
    Set Controls = mControls
End Property

Public Function ControlByName(ByVal Name As String) As IOxControl
    Set ControlByName = ControlByNameIn(mControls, Name)
End Function

Public Function HasControl(ByVal Name As String) As Boolean
    Dim Found As IOxControl
    Set Found = ControlByName(Name)
    HasControl = Not Found Is Nothing
End Function

Private Function ControlByNameIn(ByVal List As Controls, ByVal Name As String) As IOxControl
    Dim Found As IOxControl
    Set Found = List.ItemByName(Name)
    If Not Found Is Nothing Then
        Set ControlByNameIn = Found
        Exit Function
    End If

    Dim I As Long
    Dim Control As IOxControl
    For I = 1 To List.Count
        Set Control = List.Item(I)
        If Control.HasChildren Then
            Set Found = ControlByNameIn(Control.Children, Name)
            If Not Found Is Nothing Then
                Set ControlByNameIn = Found
                Exit Function
            End If
        End If
    Next I
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
' but On Error is unproven on CalcVBA and unused elsewhere here, so this stays explicit.)
Private Sub RecordInvalidated(ByVal Control As IOxControl)
    If Control.HasChildren Then mStructureDirty = True

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
' CalcForms.Surface.SubmitPatch consumes -- it crosses the boundary exactly once. BaseToken
' is the resident frame token BeginScene returned. Render uses this for the first frame
' and the STALE self-heal; render_scene_probe_form drives it directly.
Public Function BuildScenePatch( _
        ByVal BaseToken As String, _
        ByVal Builder As OxSceneBuilder, _
        ByVal Surface As Object, _
        ByVal DpiX As Long, _
        ByVal DpiY As Long) As String
    OxProfileMark "vba_build_full_patch_start"
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

    ' Measure every caption in ONE batched crossing, then lay out + paint each control.
    EmitControls mControls, Builder, Surface

    BuildScenePatch = Builder.ToPatchJson()
    OxProfileMark "vba_after_build_full_patch"
End Function

' Emit a set of controls into the builder in two passes that share one batched text-measure
' crossing (oxforms-98v). Pass 1 (MeasureControls) crosses CalcForms.Surface.MeasureBatch ONCE
' for every caption in the set; pass 2 (PaintControls) lays out + paints each control with no
' further crossing. A control's emitted node is byte-identical to the old per-control path, so
' an incremental patch still reaches the same resident scene a full rebuild would (determinism
' invariant (c), RENDERING_ARCHITECTURE.md §10) -- only the measure FAN-OUT changed (N crossings
' -> 1). Both BuildScenePatch (all controls) and RenderIncremental (the invalidated set) use it.
Private Sub EmitControls( _
        ByVal List As Object, ByVal Builder As OxSceneBuilder, ByVal Surface As Object)
    OxProfileMark "vba_emit_controls_start"
    Dim MeasureList As Collection
    Set MeasureList = New Collection
    AddControlsRecursive List, MeasureList
    MeasureControls MeasureList, Surface
    OxProfileMark "vba_after_measure_controls"
    PaintControls List, Builder
    OxProfileMark "vba_after_paint_controls"
End Sub

Private Sub AddControlsRecursive(ByVal Source As Object, ByVal Target As Collection)
    Dim I As Long
    Dim Control As IOxControl
    For I = 1 To Source.Count
        Set Control = Source.Item(I)
        Target.Add Control
        If Control.HasChildren Then AddControlsRecursive Control.Children, Target
    Next I
End Sub

' Pass 1 -- measure: stamp each text control's content-hash run id + measured size from a
' SINGLE CalcForms.Surface.MeasureBatch crossing (the §8 measure step, batched per §6). Captions
' ride to Rust as native String record fields and metrics return as typed Longs (OxMeasureRequest
' / OxMeasureResult in CalcFormsModel) -- no string packing or parsing. Controls with no caption
' need no measurement (empty run, zero size), except TextBox: an empty field still
' needs the real font line height for its caret. If no control needs metrics,
' no crossing happens.
Private Sub MeasureControls(ByVal List As Object, ByVal Surface As Object)
    Dim I As Long, Control As IOxControl, TextCount As Long, Part As Long
    Dim Core As OxControlCore
    For I = 1 To List.Count
        Set Control = List.Item(I)
        Set Core = Control.Core
        If Core.MeasureTextCount > 0 Then
            TextCount = TextCount + Core.MeasureTextCount
        Else
            Control.Core.RunId = ""
            Control.Core.MeasuredWidth = 0
            Control.Core.MeasuredHeight = 0
            Control.Core.CaretStopsMilliPtCsv = ""
        End If
    Next I
    If TextCount = 0 Then Exit Sub

    Dim Reqs() As OxMeasureRequest
    ReDim Reqs(0 To TextCount - 1)
    Dim J As Long
    For I = 1 To List.Count
        Set Control = List.Item(I)
        Set Core = Control.Core
        For Part = 0 To Core.MeasureTextCount - 1
            Reqs(J).FontId = OX_DEFAULT_FONT_ID
            Reqs(J).SizeMilliPt = CLng(Core.FontSize * 1000)
            Reqs(J).Caption = Core.MeasureText(Part)
            Reqs(J).Accelerator = Core.Accelerator
            J = J + 1
        Next Part
    Next I

    Dim Res() As OxMeasureResult
    Res = Surface.MeasureBatch((Reqs))

    J = 0
    For I = 1 To List.Count
        Set Control = List.Item(I)
        Set Core = Control.Core
        For Part = 0 To Core.MeasureTextCount - 1
            Core.SetMeasuredText Part, Res(J).RunId, Res(J).AdvanceMilliPt / 1000, _
                (Res(J).AscentMilliPt + Res(J).DescentMilliPt) / 1000, Res(J).CaretStopsMilliPtCsv
            J = J + 1
        Next Part
    Next I
End Sub

' Pass 2 -- layout + paint: no crossing. An AutoSize control with a caption shrink-wraps its
' measured run (measured size + 4pt/3pt insets per side = +8pt/+6pt total), written WITHOUT
' MarkDirty (see SetAutoSizeBounds) so a re-render leaves no phantom dirty. Then it emits its node.
Private Sub PaintControls(ByVal List As Object, ByVal Builder As OxSceneBuilder)
    Dim I As Long, Control As IOxControl
    For I = 1 To List.Count
        Set Control = List.Item(I)
        If Control.Core.AutoSize And Len(Control.Core.DisplayText) > 0 Then
            Control.Core.SetAutoSizeBounds _
                Control.Core.MeasuredWidth + 8, Control.Core.MeasuredHeight + 6
        End If

        Control.Core.SetRenderOffset 0, 0
        Control.Core.SetRenderParentId 0
        Control.Render Builder

        ' The control's current state is now committed to the resident scene, so it is no
        ' longer dirty. Clearing it here (the render path) keeps Core.Dirty meaning "changed
        ' since last emitted" -- which is what ResumeLayout's dirty re-derive assumes. Without
        ' this, a render-only flow (no runtime dispatch, which is the only other ClearDirty
        ' caller) would let Core.Dirty accumulate, so each later ResumeLayout band would
        ' re-invalidate every control ever changed.
        Control.Core.ClearDirty
    Next I
End Sub

' Re-render across the CalcForms.Surface boundary -- the Re-render the runtime invokes each
' frame (RENDERING_ARCHITECTURE.md §16). The form self-renders: it knows its own size, so
' it drives the crossing itself. First frame (no resident scene) is a full rebuild against
' a fresh BeginScene; afterwards each frame emits an INCREMENTAL patch carrying only the
' invalidated controls against the resident token (oxforms-rq5.2) -- one control change
' crosses as a one-node patch (the §6 crossing budget), and an unchanged frame does no
' crossing at all. A stale base self-heals to a full rebuild.
'
' Scope note: the incremental path covers per-CONTROL changes (every render-affecting
' OxControlCore setter calls MarkDirty -> the control is invalidated -> re-emitted). A
' structural change (control Add/Remove or render-derived AutoSize root membership effects)
' forces a full rebuild so the root/form node's child list and the retained Scene agree.
Public Sub Render(ByVal DpiX As Long, ByVal DpiY As Long)
    OxProfileMark "vba_render_start"
    Dim Surface As Object
    Set Surface = CreateObject("CalcForms.Surface")

    If Not mHasResident Or mStructureDirty Then
        OxProfileMark "vba_render_full_start"
        RenderFull Surface, DpiX, DpiY
    ElseIf mInvalidated.Count > 0 Then
        OxProfileMark "vba_render_incremental_start"
        If RenderIncremental(Surface, DpiX, DpiY) = OX_STALE_SENTINEL Then
            ' The resident base drifted (e.g. the surface was re-initialized): rebuild.
            OxProfileMark "vba_render_stale_full_start"
            RenderFull Surface, DpiX, DpiY
        End If
    Else
        ' Nothing changed since the last frame: no crossing, no new resident revision.
        OxProfileMark "vba_render_noop"
        Exit Sub
    End If

    ClearInvalidations
    OxProfileMark "vba_after_render"
End Sub

' Full rebuild against a fresh BeginScene base; (re)establishes the resident scene. Used
' for the first frame and the STALE self-heal.
Private Sub RenderFull(ByVal Surface As Object, ByVal DpiX As Long, ByVal DpiY As Long)
    Dim BaseToken As String
    BaseToken = Surface.BeginScene(CLng(mWidth), CLng(mHeight), (DpiX), (DpiY))

    Dim Builder As OxSceneBuilder
    Set Builder = New OxSceneBuilder
    mLastSceneToken = Surface.SubmitPatch( _
        BuildScenePatch(BaseToken, Builder, Surface, DpiX, DpiY))
    mHasResident = True
    mStructureDirty = False
End Sub

' Incremental patch against the resident token: Upsert only the invalidated controls. The
' root and unchanged controls are unmentioned, so the kernel RETAINS them. Returns the new
' frame token, or OX_STALE_SENTINEL if the base no longer matched (the caller rebuilds).
Private Function RenderIncremental( _
        ByVal Surface As Object, ByVal DpiX As Long, ByVal DpiY As Long) As String
    Dim Builder As OxSceneBuilder
    Set Builder = New OxSceneBuilder
    OxProfileMark "vba_build_incremental_patch_start"
    Builder.BeginPatch mLastSceneToken, CLng(mWidth), CLng(mHeight), DpiX, DpiY

    EmitControls mInvalidated, Builder, Surface

    Dim NewToken As String
    OxProfileMark "vba_before_incremental_to_json"
    NewToken = Surface.SubmitPatch(Builder.ToPatchJson())
    OxProfileMark "vba_after_incremental_submit"
    If NewToken <> OX_STALE_SENTINEL Then mLastSceneToken = NewToken
    RenderIncremental = NewToken
End Function

Public Property Get LastSceneToken() As String
    LastSceneToken = mLastSceneToken
End Property

' Monotonic routing-policy revision. OxInteractionManager compares this before using cached
' tab/default/cancel/accelerator/cursor maps, so property-side effects and runtime
' add/remove work through the same host seam as rendering invalidation.
Public Property Get InteractionRevision() As Long
    InteractionRevision = mInteractionRevision
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

Private Function IOxControlHost_AllocateNodeId() As Long
    ' Slots 900..999 in each block belong to control-local paint parts.
    If mNextNodeId Mod 1000 >= 900 Then mNextNodeId = (mNextNodeId \ 1000 + 1) * 1000
    If mNextNodeId > 2147482 Then Err.Raise 6, "CalcForms", "Form node capacity exceeded"
    IOxControlHost_AllocateNodeId = mNextNodeId
    mNextNodeId = mNextNodeId + 1
End Function

Private Sub IOxControlHost_OnInteractionInvalidated(ByVal Control As IOxControl)
    RecordInteractionInvalidated Control
End Sub

Private Sub IOxControlContainer_RegisterControl(ByVal Control As IOxControl)
    RegisterControl Control
End Sub

Private Sub IOxControlContainer_UnregisterControl(ByVal Control As IOxControl)
    UnregisterControl Control
End Sub

Private Sub RecordInteractionInvalidated(ByVal Control As IOxControl)
    mInteractionRevision = mInteractionRevision + 1
End Sub
