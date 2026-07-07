Option Explicit

' OxForms "classic MSForms" theme: the data table that maps a control's logical
' role and state to resolved colors and 3D-edge effects. This is the VBA home of
' the appearance logic that used to live in oxforms-core's probe render code
' (probe_face_color / probe_text_color / the border + edge colors). Per
' docs/specs/RENDERING_ARCHITECTURE.md s5, theming is *data*: an alternate theme is
' a different table touching no kernel and no control code. The Rust kernel never
' sees any of these decisions -- controls emit already-resolved colors as paint.
'
' Colors are OxForms 0xRRGGBB Longs (NOT VBA's BGR RGB()); the OxSceneBuilder
' unpacks them into explicit red/green/blue paint bytes at the boundary.

' Control face fill, by kind / pressed / enabled. Reproduces the classic palette.
Public Function OxThemeFaceColor( _
        ByVal Kind As OxControlKind, _
        ByVal IsPressed As Boolean, _
        ByVal IsEnabled As Boolean) As Long
    If Not IsEnabled Then
        OxThemeFaceColor = &HD9D9D9
        Exit Function
    End If

    Select Case Kind
        Case oxControlLabel
            OxThemeFaceColor = &H2070C0
        Case oxControlTextBox
            OxThemeFaceColor = &HFFFFFF
        Case oxControlListBox
            OxThemeFaceColor = &HFFFFFF
        Case oxControlCommandButton
            If IsPressed Then
                OxThemeFaceColor = &HB8C7DD
            Else
                OxThemeFaceColor = &HDCDCDC
            End If
        Case oxControlCheckBox
            If IsPressed Then
                OxThemeFaceColor = &HE8E8E8
            Else
                OxThemeFaceColor = &HF8F8F8
            End If
        Case Else
            OxThemeFaceColor = &HF0F0F0
    End Select
End Function

' Control text color, by kind / enabled.
Public Function OxThemeTextColor( _
        ByVal Kind As OxControlKind, _
        ByVal IsEnabled As Boolean) As Long
    If Not IsEnabled Then
        OxThemeTextColor = &H808080
        Exit Function
    End If

    If Kind = oxControlLabel Then
        OxThemeTextColor = &HFFFFFF
    Else
        OxThemeTextColor = &H0
    End If
End Function

' Flat single-line border color (fmBorderStyleSingle).
Public Function OxThemeBorderColor() As Long
    OxThemeBorderColor = &H646464
End Function

' UserForm client-area background.
Public Function OxThemeFormBackColor() As Long
    OxThemeFormBackColor = &HF0F0F0
End Function

' 3D edge light/shadow for raised/sunken effects (classic button highlight/shadow).
Public Function OxThemeEdgeLight() As Long
    OxThemeEdgeLight = &HFFFFFF
End Function

Public Function OxThemeEdgeShadow() As Long
    OxThemeEdgeShadow = &H808080
End Function

' Map a SpecialEffect to the generic edge name the kernel understands. Returning
' an empty string means "no edge" (Flat) -- the control then omits DrawEdge.
Public Function OxThemeEdgeName(ByVal Effect As fmSpecialEffect) As String
    Select Case Effect
        Case fmSpecialEffectRaised
            OxThemeEdgeName = "raised"
        Case fmSpecialEffectSunken
            OxThemeEdgeName = "sunken"
        Case fmSpecialEffectEtched
            OxThemeEdgeName = "etched"
        Case fmSpecialEffectBump
            OxThemeEdgeName = "bump"
        Case Else
            OxThemeEdgeName = ""
    End Select
End Function

' --- ThemePainter seam -------------------------------------------------------
'
' These helpers are the representative ThemeTokens/ThemePainter v1 surface. They
' resolve MSForms property bands + runtime state into concrete classic tokens and
' emit common Scene primitives. Tokens are internal implementation vocabulary; the
' controls still own MSForms properties, state, and event behavior.

Public Function OxThemeResolveFace(ByVal Core As OxControlCore) As Long
    If Core.BackColor = oxColorAuto Then
        OxThemeResolveFace = OxThemeFaceColor(Core.Kind, Core.Pressed, Core.Enabled)
    Else
        OxThemeResolveFace = Core.BackColor
    End If
End Function

Public Function OxThemeResolveText(ByVal Core As OxControlCore) As Long
    If Core.ForeColor = oxColorAuto Then
        OxThemeResolveText = OxThemeTextColor(Core.Kind, Core.Enabled)
    Else
        OxThemeResolveText = Core.ForeColor
    End If
End Function

Public Function OxThemeResolveBorder(ByVal Core As OxControlCore) As Long
    If Core.BorderColor = oxColorAuto Then
        OxThemeResolveBorder = OxThemeBorderColor()
    Else
        OxThemeResolveBorder = Core.BorderColor
    End If
End Function

Public Function OxThemeSelectionBackColor() As Long
    OxThemeSelectionBackColor = &H0A246A
End Function

Public Function OxThemeSelectionTextColor() As Long
    OxThemeSelectionTextColor = &HFFFFFF
End Function

Public Function OxThemeCaretColor() As Long
    OxThemeCaretColor = &H0
End Function

Public Function OxThemeFocusAdornerColor() As Long
    OxThemeFocusAdornerColor = &H0
End Function

Public Sub OxThemePaintControlFrame( _
        ByVal Core As OxControlCore, ByVal Surface As OxSceneBuilder)
    Surface.FillRect Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, _
        OxThemeResolveFace(Core), 255

    Dim EdgeName As String
    EdgeName = OxThemeEdgeName(Core.SpecialEffect)
    If Len(EdgeName) > 0 Then
        Surface.DrawEdge Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, _
            EdgeName, OxThemeEdgeLight(), OxThemeEdgeShadow()
    ElseIf Core.BorderStyle = fmBorderStyleSingle Then
        Surface.StrokeRect Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, _
            OxThemeResolveBorder(Core), 255, 1
    End If
End Sub

Public Sub OxThemePaintListBox( _
        ByVal Core As OxControlCore, _
        ByVal Surface As OxSceneBuilder, _
        ByVal ListIndex As Long, _
        ByVal Focused As Boolean)
    Const Inset As Single = 3
    Const RowHeight As Single = 14

    Surface.OpenNode Core.NodeId, True, Core.PaintParentId, Core.ZOrder, _
        Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, Core.Visible

    OxThemePaintControlFrame Core, Surface

    If ListIndex >= 0 Then
        Dim SelY As Single
        SelY = Core.PaintTop + Inset + (ListIndex * RowHeight)
        If SelY < Core.PaintTop + Core.Height - Inset Then
            Dim SelW As Single
            SelW = Core.Width - (Inset * 2)
            If SelW < 1 Then SelW = 1
            Surface.FillRect Core.PaintLeft + Inset, SelY, SelW, RowHeight, _
                OxThemeSelectionBackColor(), 255
        End If
    End If

    If Len(Core.DisplayText) > 0 Then
        Dim RunId As String
        RunId = Core.RunId
        If Len(RunId) = 0 Then RunId = "0"
        Dim TextW As Single, TextH As Single
        TextW = Core.Width - ((Inset + 2) * 2)
        If TextW < 1 Then TextW = 1
        TextH = Core.Height - (Inset * 2)
        If TextH < 1 Then TextH = 1
        OxThemePaintTextRun Core, Surface, _
            Core.PaintLeft + Inset + 2, Core.PaintTop + Inset, _
            TextW, TextH, _
            RunId, "left", True, True, False
    End If

    If Focused And Core.Enabled Then
        Surface.StrokeRect Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, _
            OxThemeFocusAdornerColor(), 255, 1
    End If

    Surface.CloseNode
End Sub

Public Sub OxThemePaintTextRun( _
        ByVal Core As OxControlCore, _
        ByVal Surface As OxSceneBuilder, _
        ByVal X As Single, ByVal Y As Single, ByVal W As Single, ByVal H As Single, _
        ByVal RunId As String, ByVal Align As String, ByVal Wrap As Boolean, ByVal Clip As Boolean, _
        ByVal UnderlineAccelerator As Boolean)
    Surface.DrawText X, Y, W, H, RunId, Align, Wrap, Clip, _
        OxThemeResolveText(Core), 255, UnderlineAccelerator, Not Core.Enabled
End Sub

Public Sub OxThemePaintCheckBox( _
        ByVal Core As OxControlCore, _
        ByVal Surface As OxSceneBuilder, _
        ByVal Checked As Boolean, _
        ByVal Focused As Boolean)
    Const BoxSize As Single = 12

    Surface.OpenNode Core.NodeId, True, Core.PaintParentId, Core.ZOrder, _
        Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, Core.Visible

    Dim BoxX As Single, BoxY As Single
    BoxX = Core.PaintLeft
    BoxY = Core.PaintTop + (Core.Height - BoxSize) / 2

    Surface.FillRect BoxX, BoxY, BoxSize, BoxSize, OxThemeResolveFace(Core), 255
    Surface.DrawEdge BoxX, BoxY, BoxSize, BoxSize, _
        "sunken", OxThemeEdgeLight(), OxThemeEdgeShadow()
    If Checked Then
        Surface.FillRect BoxX + 3, BoxY + 3, BoxSize - 6, BoxSize - 6, _
            OxThemeResolveText(Core), 255
    End If

    If Len(Core.DisplayText) > 0 Then
        Dim Tx As Single, Ty As Single, Tw As Single, Th As Single
        Tx = Core.PaintLeft + BoxSize + 4
        Ty = Core.PaintTop + 3
        Tw = Core.Width - BoxSize - 8
        If Tw < 1 Then Tw = 1
        Th = Core.Height - 6
        If Th < 1 Then Th = 1
        Dim RunId As String
        RunId = Core.RunId
        If Len(RunId) = 0 Then RunId = "0"
        OxThemePaintTextRun Core, Surface, Tx, Ty, Tw, Th, RunId, "left", False, True, False
    End If

    If Focused And Core.Enabled Then
        Surface.StrokeRect Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, _
            OxThemeFocusAdornerColor(), 255, 1
    End If

    Surface.CloseNode
End Sub
