Option Explicit

' The standard control paint: face fill + 3D edge (or flat single border) + text,
' resolved through OxTheme and the control's appearance band. Label/TextBox/
' CommandButton all paint this way, so their IOxControl_Render is a single call.
' A control with bespoke parts (a CheckBox glyph, a TextBox caret) gives those
' their own sub-part nodes in its own Render instead of calling this. See the
' "add a control" recipe in docs/specs/RENDERING_ARCHITECTURE.md s5.
'
' Geometry is surface-absolute (v1 identity transforms). Text references the content-
' hash run id the measure pre-pass stamped on Core.RunId (UserForm, via
' OxForms.Surface.MeasureText); color/edge selection is the only appearance the kernel
' ever receives, already resolved to bytes.

Public Sub OxPaintStandardControl( _
        ByVal Core As OxControlCore, _
        ByVal Surface As OxSceneBuilder, _
        ByVal Align As String)
    Surface.OpenNode Core.NodeId, True, 0, Core.ZOrder, _
        Core.Left, Core.Top, Core.Width, Core.Height, Core.Visible

    Surface.FillRect Core.Left, Core.Top, Core.Width, Core.Height, _
        ResolveFace(Core), 255

    Dim EdgeName As String
    EdgeName = OxThemeEdgeName(Core.SpecialEffect)
    If Len(EdgeName) > 0 Then
        Surface.DrawEdge Core.Left, Core.Top, Core.Width, Core.Height, _
            EdgeName, OxThemeEdgeLight(), OxThemeEdgeShadow()
    ElseIf Core.BorderStyle = fmBorderStyleSingle Then
        Surface.StrokeRect Core.Left, Core.Top, Core.Width, Core.Height, _
            ResolveBorder(Core), 255, 1
    End If

    If Len(Core.DisplayText) > 0 Then
        Dim Tx As Single, Ty As Single, Tw As Single, Th As Single
        Tx = Core.Left + 4
        Ty = Core.Top + 3
        Tw = Core.Width - 8
        If Tw < 1 Then Tw = 1
        Th = Core.Height - 6
        If Th < 1 Then Th = 1
        Dim RunId As String
        RunId = Core.RunId
        If Len(RunId) = 0 Then RunId = "0"
        Surface.DrawText Tx, Ty, Tw, Th, RunId, Align, False, True, _
            ResolveText(Core), 255, False, Not Core.Enabled
    End If

    Surface.CloseNode
End Sub

' Appearance-band resolution: an explicit band color wins; oxColorAuto defers to
' the classic theme for the role/state.
Private Function ResolveFace(ByVal Core As OxControlCore) As Long
    If Core.BackColor = oxColorAuto Then
        ResolveFace = OxThemeFaceColor(Core.Kind, False, Core.Enabled)
    Else
        ResolveFace = Core.BackColor
    End If
End Function

Private Function ResolveText(ByVal Core As OxControlCore) As Long
    If Core.ForeColor = oxColorAuto Then
        ResolveText = OxThemeTextColor(Core.Kind, Core.Enabled)
    Else
        ResolveText = Core.ForeColor
    End If
End Function

Private Function ResolveBorder(ByVal Core As OxControlCore) As Long
    If Core.BorderColor = oxColorAuto Then
        ResolveBorder = OxThemeBorderColor()
    Else
        ResolveBorder = Core.BorderColor
    End If
End Function
