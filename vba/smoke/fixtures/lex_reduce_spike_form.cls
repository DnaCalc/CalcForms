Option Explicit

' oxforms-lex feasibility spike (test infrastructure, not the OxForms library).
'
' Proves a VBA-side REDUCE runs on OxVba vm3 with the intended path
'   input -> VBA reduce -> effects -> pal Scene
' and NO Rust reducer (oxforms-core) anywhere in the loop. The form owns one button
' rect plus a Pressed boolean. Reduce(X, Y) hit-tests the click IN VBA, toggles Pressed
' when the point is inside the button, and re-renders through the injected OxForms.Surface.
' The button paints gray (up) / blue (pressed), so the resident Scene reflects the
' VBA-decided state change and the Rust harness can read the FillRect colour back.
'
' This is the smallest faithful demonstration of moving the reducer (hit-test + state
' transition + effect) into VBA. See memory oxforms-reducer-home-decision; per
' oxvba-vm3-handover-policy any vm3 limitation hit here is filed as an OxVba handover,
' not worked around.

Private Const SURFACE_W As Long = 120
Private Const SURFACE_H As Long = 80

' The single hit-target rect, in form-logical points.
Private Const BTN_X As Long = 20
Private Const BTN_Y As Long = 20
Private Const BTN_W As Long = 80
Private Const BTN_H As Long = 40

' Packed 0xRRGGBB faces: gray when up, blue when pressed.
Private Const FACE_UP As Long = &H808080
Private Const FACE_PRESSED As Long = &H2060C0

Private mPressed As Boolean
Private mSurface As Object

Private Sub Class_Initialize()
    Set mSurface = CreateObject("OxForms.Surface")
    mPressed = False
End Sub

' Initial render (Pressed = False) -- the runtime's "first frame".
Public Sub Build()
    RenderFull
End Sub

' THE VBA REDUCE. A normalized mouse-down at (X, Y) in form-logical points: hit-test the
' button IN VBA; if hit, toggle Pressed and re-render. Returns 1 if it repainted, else 0.
Public Function Reduce(ByVal X As Long, ByVal Y As Long) As Long
    If HitButton(X, Y) Then
        mPressed = Not mPressed
        RenderFull
        Reduce = 1
    Else
        Reduce = 0
    End If
End Function

Public Property Get Pressed() As Boolean
    Pressed = mPressed
End Property

' VBA-side hit-test -- the capability the Rust reducer used to own (HitTest is a deferred
' Surface crossing; here it lives in VBA where the control geometry does). Half-open rect: the
' right/bottom edges are exclusive (the standard graphics convention), so the hit area is
' [BTN_X, BTN_X+BTN_W) x [BTN_Y, BTN_Y+BTN_H).
Private Function HitButton(ByVal X As Long, ByVal Y As Long) As Boolean
    HitButton = (X >= BTN_X) And (X < BTN_X + BTN_W) And _
                (Y >= BTN_Y) And (Y < BTN_Y + BTN_H)
End Function

' Render the current state as one batched ScenePatch across OxForms.Surface.
Private Sub RenderFull()
    Dim BaseToken As String
    BaseToken = mSurface.BeginScene(SURFACE_W, SURFACE_H, 96, 96)

    Dim Face As Long
    If mPressed Then
        Face = FACE_PRESSED
    Else
        Face = FACE_UP
    End If

    Dim Builder As OxSceneBuilder
    Set Builder = New OxSceneBuilder
    Builder.BeginPatch BaseToken, SURFACE_W, SURFACE_H, 96, 96
    ' Root node 0 = the form surface, carrying the single button FillRect.
    Builder.OpenNode 0, False, 0, 0, 0, 0, SURFACE_W, SURFACE_H, True
    Builder.FillRect BTN_X, BTN_Y, BTN_W, BTN_H, Face, 255
    Builder.CloseNode

    mSurface.SubmitPatch Builder.ToPatchJson()
End Sub
