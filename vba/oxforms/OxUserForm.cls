Option Explicit
Implements IOxControlHost

' MSForms-shaped UserForm container. Owns the control set and is the host the
' controls notify on change. A user form (or, later, the .frm loader) builds its
' controls through Add, which both registers the control and wires its
' invalidation seam back to this form. The runtime enumerates Controls to
' materialize the tree and drains InvalidatedControls to schedule repaints.

Private mName As String
Private mCaption As String
Private mLeft As Single
Private mTop As Single
Private mWidth As Single
Private mHeight As Single
Private mControls As Collection
Private mInvalidated As Collection
Private mNextNodeId As Long
Private mLastSceneToken As String

' The single UI font id v1 registers (Microsoft Sans Serif / Tahoma). RegisterFont and
' multiple faces land later; until then every run measures against this one face id.
' MUST equal the Rust-side FONT_ID the backend registers the face under (oxforms-bootstrap
' `FONT_ID`, and the FontTable the rasterizer resolves against) — otherwise the run's
' font id would miss the FontTable and captions would be silently dropped. The end-to-end
' glyph-coverage test `vba_self_render_rasterizes_captions_through_the_real_shaper` pins it.
Private Const OX_DEFAULT_FONT_ID As Long = 1

Private Sub Class_Initialize()
    Set mControls = New Collection
    Set mInvalidated = New Collection
    ' Node 0 is reserved for the form/root; controls intern from 1 upward. The id
    ' is a stable per-control serial (assigned once at Add, never reused), so a
    ' repaint diffs by identity rather than array position.
    mNextNodeId = 1
End Sub

' Create a control of the given kind, register it under Name, and bind it to this
' form as its invalidation host. This is the one call sites use to add controls;
' the factory in OxFormsModel keeps it control-agnostic.
Public Function Add(ByVal Kind As OxControlKind, ByVal Name As String) As IOxControl
    Dim Control As IOxControl
    Set Control = OxCreateControl(Kind, Name)
    Control.Core.Bind Me, Control
    Control.Core.NodeId = mNextNodeId
    mNextNodeId = mNextNodeId + 1
    mControls.Add Control, Name
    Set Add = Control
End Function

Public Property Get Controls() As Collection
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

' Build one full-rebuild ScenePatch for the whole form: the root/form node (its
' background fill plus the controls' paint-order child list) followed by each
' control painting itself into its own node. This is the single batched payload
' OxForms.Surface.SubmitPatch consumes -- it crosses the boundary exactly once.
' BaseToken is the resident frame token the prior BeginScene/SubmitPatch returned.
Public Function BuildScenePatch( _
        ByVal BaseToken As String, _
        ByVal Builder As OxSceneBuilder, _
        ByVal Surface As Object, _
        ByVal DpiX As Long, _
        ByVal DpiY As Long) As String
    Builder.BeginPatch BaseToken, CLng(mWidth), CLng(mHeight), DpiX, DpiY

    Dim I As Long
    Dim Control As IOxControl

    ' Measure pass (measure -> layout -> paint): stamp each text control's content-hash
    ' run id + measured size from OxForms.Surface.MeasureText (the §8 cache-miss path; the
    ' string crosses here, once). Written straight onto the live core (as Add does for
    ' NodeId), so the mutation persists into the paint pass. v1 re-measures every render
    ' and lets the Rust store de-dup by id; a VBA-side memo is a later optimization.
    Dim Cap As String
    Dim Rid As String, MeasW As Single, MeasH As Single
    For I = 1 To mControls.Count
        Set Control = mControls.Item(I)
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
    Next I

    ' Layout pass: an AutoSize control shrink-wraps its caption — Width/Height become the
    ' measured run plus padding (matching OxControlPaint's 4pt/3pt text insets), so its
    ' face, border, and node bounds hug the text. A font-size or caption change re-measures
    ' above and re-fits here, BEFORE any geometry is emitted — the metrics are load-bearing.
    For I = 1 To mControls.Count
        Set Control = mControls.Item(I)
        If Control.Core.AutoSize And Len(Control.Core.DisplayText) > 0 Then
            ' Render-derived geometry: set bounds WITHOUT MarkDirty (see SetAutoSizeBounds)
            ' so a re-render does not leave the control phantom-dirty for sync_properties.
            Control.Core.SetAutoSizeBounds _
                Control.Core.MeasuredWidth + 8, Control.Core.MeasuredHeight + 6
        End If
    Next I

    ' Root/form node: client background plus the controls' paint-order children.
    Builder.OpenNode 0, False, 0, 0, 0, 0, mWidth, mHeight, True
    For I = 1 To mControls.Count
        Set Control = mControls.Item(I)
        Builder.AddChild Control.Core.NodeId
    Next I
    Builder.FillRect 0, 0, mWidth, mHeight, OxThemeFormBackColor(), 255
    Builder.CloseNode

    ' Each control paints itself into its own node.
    For I = 1 To mControls.Count
        Set Control = mControls.Item(I)
        Control.Render Builder
    Next I

    BuildScenePatch = Builder.ToPatchJson()
End Function

' Re-render the whole form across the OxForms.Surface boundary -- the Re-render the
' runtime invokes each frame (RENDERING_ARCHITECTURE.md SS16). The form self-renders:
' it knows its own size, so it drives BeginScene + one batched SubmitPatch itself. This
' is the full-rebuild v1 (BeginScene every frame, so the patch always applies against a
' fresh base); incremental patching against a threaded token is oxforms-rq5.2. After
' submitting, the reconciled invalidation set is cleared. LastSceneToken exposes the
' resident frame token SubmitPatch reported. In this full-rebuild v1, BeginScene runs
' every frame so the patch's base always matches and SubmitPatch never returns "STALE";
' the STALE self-heal (re-BeginScene + resubmit) arrives with incremental patching
' (oxforms-rq5.2), which is the only path that threads a base token across frames.
Public Sub Render(ByVal DpiX As Long, ByVal DpiY As Long)
    Dim Surface As Object
    Set Surface = CreateObject("OxForms.Surface")

    Dim BaseToken As String
    BaseToken = Surface.BeginScene(CLng(mWidth), CLng(mHeight), DpiX, DpiY)

    Dim Builder As OxSceneBuilder
    Set Builder = New OxSceneBuilder
    Dim PatchJson As String
    PatchJson = BuildScenePatch(BaseToken, Builder, Surface, DpiX, DpiY)

    mLastSceneToken = Surface.SubmitPatch(PatchJson)
    ClearInvalidations
End Sub

' Parse a MeasureText result "id:advance:ascent:descent:linegap" (metrics in 1/1000 pt)
' into the run id (a String) and the caption's measured size in points (advance width;
' ascent+descent height). Avoids a Split dependency (InStr + Mid$ + Val). Uses Mid$ rather
' than Left$ ON PURPOSE: OxUserForm has a Left property and OxVba resolves the bare Left$
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
Private Sub IOxControlHost_OnControlInvalidated(ByVal Control As IOxControl)
    mInvalidated.Add Control
End Sub
