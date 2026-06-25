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
' resident frame token SubmitPatch reported (or "STALE" if the base no longer matched).
Public Sub Render(ByVal DpiX As Long, ByVal DpiY As Long)
    Dim Surface As Object
    Set Surface = CreateObject("OxForms.Surface")

    Dim BaseToken As String
    BaseToken = Surface.BeginScene(CLng(mWidth), CLng(mHeight), DpiX, DpiY)

    Dim Builder As OxSceneBuilder
    Set Builder = New OxSceneBuilder
    Dim PatchJson As String
    PatchJson = BuildScenePatch(BaseToken, Builder, DpiX, DpiY)

    mLastSceneToken = Surface.SubmitPatch(PatchJson)
    ClearInvalidations
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
