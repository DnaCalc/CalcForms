Option Explicit

' The standard control paint: face fill + 3D edge (or flat single border) + text,
' resolved through the internal ThemePainter seam. Label and CommandButton paint
' this way, so their IOxControl_Render is a single call.
' A control with bespoke parts (a CheckBox glyph, a TextBox caret) gives those
' their own sub-part nodes in its own Render instead of calling this. See the
' "add a control" recipe in docs/specs/RENDERING_ARCHITECTURE.md s5.
'
' Geometry is surface-absolute (v1 identity transforms). Text references the content-
' hash run id the measure pre-pass stamped on Core.RunId (UserForm, via
' OxForms.Surface.MeasureBatch); color/edge selection is the only appearance the kernel
' ever receives, already resolved to bytes.

Public Sub OxPaintStandardControl( _
        ByVal Core As OxControlCore, _
        ByVal Surface As OxSceneBuilder, _
        ByVal Align As String, _
        Optional ByVal Focused As Boolean = False)
    Surface.OpenNode Core.NodeId, True, Core.PaintParentId, Core.ZOrder, _
        Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, Core.Visible

    OxThemePaintControlFrame Core, Surface

    If Len(Core.DisplayText) > 0 Then
        Dim Tx As Single, Ty As Single, Tw As Single, Th As Single
        Tx = Core.PaintLeft + 4
        Ty = Core.PaintTop + 3
        Tw = Core.Width - 8
        If Tw < 1 Then Tw = 1
        Th = Core.Height - 6
        If Th < 1 Then Th = 1
        Dim RunId As String
        RunId = Core.RunId
        If Len(RunId) = 0 Then RunId = "0"
        OxThemePaintTextRun Core, Surface, Tx, Ty, Tw, Th, RunId, Align, False, True, False
    End If

    If Focused And Core.Enabled Then
        Surface.StrokeRect Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, _
            OxThemeFocusAdornerColor(), 255, 1
    End If

    Surface.CloseNode
End Sub

Public Sub OxPaintToggleButton( _
        ByVal Core As OxControlCore, _
        ByVal Surface As OxSceneBuilder, _
        ByVal Focused As Boolean, _
        ByVal Latched As Boolean)
    OxThemePaintToggleButton Core, Surface, Focused, Latched
End Sub

Public Sub OxPaintOptionButton( _
        ByVal Core As OxControlCore, _
        ByVal Surface As OxSceneBuilder, _
        ByVal Focused As Boolean, _
        ByVal Checked As Boolean)
    OxThemePaintOptionButton Core, Surface, Checked, Focused
End Sub
