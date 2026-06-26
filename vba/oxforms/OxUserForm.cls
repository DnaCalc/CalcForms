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

    ' Measure pre-pass: stamp each text control's content-hash run id from
    ' OxForms.Surface.MeasureText (the §8 cache-miss path; the string crosses here, once).
    ' OxControlPaint then emits Core.RunId by reference. v1 re-measures every render and
    ' lets the Rust store de-dup by id; a VBA-side memo is a later optimization.
    ' The id is written straight onto the live core (as Add does for NodeId), not via a
    ' ByVal-object helper, so the mutation persists into the paint pass.
    Dim Cap As String
    For I = 1 To mControls.Count
        Set Control = mControls.Item(I)
        Cap = Control.Core.DisplayText
        If Len(Cap) > 0 Then
            Control.Core.RunId = FirstField( _
                Surface.MeasureText(OX_DEFAULT_FONT_ID, CLng(Control.Core.FontSize * 1000), Cap))
        Else
            Control.Core.RunId = ""
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

' The first ':'-delimited field of a MeasureText result (the run id). Avoids a Split
' dependency. Uses Mid$ rather than Left$ ON PURPOSE: OxUserForm has a Left property, and
' OxVba resolves the bare Left$ intrinsic to that member (returning 0) — the Left/Left$
' shadowing divergence from docs/handovers/HANDOVER_OxVba_left_intrinsic_shadowed.md,
' recurring here for a class that has a Left member. Mid$(S, 1, n) is the unaffected
' equivalent of Left$(S, n).
Private Function FirstField(ByVal S As String) As String
    Dim P As Long
    P = InStr(S, ":")
    If P > 0 Then
        FirstField = Mid$(S, 1, P - 1)
    Else
        FirstField = S
    End If
End Function

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
