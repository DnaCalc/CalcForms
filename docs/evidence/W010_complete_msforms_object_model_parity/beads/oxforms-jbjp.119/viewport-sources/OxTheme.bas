Option Explicit

' CalcForms "classic MSForms" theme: the data table that maps a control's logical
' role and state to resolved colors and 3D-edge effects. This is the VBA home of
' the appearance logic that used to live in calcforms-core's probe render code
' (probe_face_color / probe_text_color / the border + edge colors). Per
' docs/specs/RENDERING_ARCHITECTURE.md s5, theming is *data*: an alternate theme is
' a different table touching no kernel and no control code. The Rust kernel never
' sees any of these decisions -- controls emit already-resolved colors as paint.
'
' Colors are CalcForms 0xRRGGBB Longs (NOT VBA's BGR RGB()); the OxSceneBuilder
' unpacks them into explicit red/green/blue paint bytes at the boundary.

' Control face fill, by kind / pressed / enabled. Reproduces the classic palette.
Public Function OxThemeFaceColor( _
        ByVal Kind As OxControlKind, _
        ByVal IsPressed As Boolean, _
        ByVal IsEnabled As Boolean) As Long
    If Not IsEnabled Then
        OxThemeFaceColor = &HF0F0F0
        Exit Function
    End If

    Select Case Kind
        Case oxControlLabel
            OxThemeFaceColor = &HF0F0F0
        Case oxControlTextBox
            OxThemeFaceColor = &HFFFFFF
        Case oxControlListBox, oxControlComboBox
            OxThemeFaceColor = &HFFFFFF
        Case oxControlImage
            OxThemeFaceColor = &HF0F0F0
        Case oxControlCommandButton
            If IsPressed Then
                OxThemeFaceColor = &HF8F8F8
            Else
                OxThemeFaceColor = &HF0F0F0
            End If
        Case oxControlToggleButton
            ' Native pressed toggles use a face/white checker. The solid
            ' approximation keeps the observed face class; pattern is separate.
            OxThemeFaceColor = &HF0F0F0
        Case oxControlSpinButton, oxControlScrollBar
            If IsPressed Then
                OxThemeFaceColor = &HB8C7DD
            Else
                OxThemeFaceColor = &HF0F0F0
            End If
        Case oxControlCheckBox, oxControlOptionButton
            If IsPressed Then
                OxThemeFaceColor = &HE8E8E8
            Else
                OxThemeFaceColor = &HFFFFFF
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

    OxThemeTextColor = &H0
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
    OxThemeSelectionBackColor = &H0078D7
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
        ByVal Core As OxControlCore, ByVal Surface As OxSceneBuilder, _
        Optional ByVal DefaultOutline As Boolean = False)
    Surface.FillRect Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, _
        OxThemeResolveFace(Core), 255

    Dim EdgeName As String
    EdgeName = OxThemeEdgeName(Core.SpecialEffect)
    Dim X As Single, Y As Single, W As Single, H As Single
    X = Core.PaintLeft
    Y = Core.PaintTop
    W = Core.Width
    H = Core.Height
    If DefaultOutline Then
        PaintEdgeLayer Surface, X, Y, W, H, &H0, &H0
        X = X + 0.75
        Y = Y + 0.75
        W = W - 1.5
        H = H - 1.5
    End If
    If EdgeName = "raised" Or EdgeName = "sunken" Then
        PaintBevel Surface, X, Y, W, H, EdgeName
    ElseIf Len(EdgeName) > 0 Then
        Surface.DrawEdge Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, _
            EdgeName, OxThemeEdgeLight(), OxThemeEdgeShadow()
    ElseIf Core.BorderStyle = fmBorderStyleSingle Then
        Surface.StrokeRect Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, _
            OxThemeResolveBorder(Core), 255, 1
    End If
End Sub

' Measured classic MSForms edges: two 0.75pt layers. The renderer receives
' only generic filled rectangles; palette and layer arrangement stay in VBA.
Private Sub PaintEdgeLayer(ByVal Surface As OxSceneBuilder, _
        ByVal X As Single, ByVal Y As Single, ByVal W As Single, ByVal H As Single, _
        ByVal TopLeft As Long, ByVal BottomRight As Long, _
        Optional ByVal T As Single = 0.75)
    If W <= 0 Or H <= 0 Then Exit Sub
    If T > W / 2 Then T = W / 2
    If T > H / 2 Then T = H / 2
    Surface.FillRect X, Y, W, T, TopLeft, 255
    Surface.FillRect X, Y, T, H, TopLeft, 255
    Surface.FillRect X, Y + H - T, W, T, BottomRight, 255
    Surface.FillRect X + W - T, Y, T, H, BottomRight, 255
End Sub

Private Sub PaintDropButtonEdge(ByVal Surface As OxSceneBuilder, _
        ByVal X As Single, ByVal Y As Single, ByVal W As Single, ByVal H As Single)
    If W < 4 Or H < 4 Then Exit Sub
    ' The native drop button has a thin enclosing highlight, then a raised
    ' white top/left and two shadow layers only on the bottom/right.
    PaintEdgeLayer Surface, X, Y, W, H, &HE3E3E3, &HE3E3E3, 0.5
    PaintEdgeLayer Surface, X + 0.5, Y + 0.5, W - 1, H - 1, &HFFFFFF, &H696969
    Surface.FillRect X + 1.25, Y + H - 2, W - 2.5, 0.75, &HA0A0A0, 255
    Surface.FillRect X + W - 2, Y + 1.25, 0.75, H - 2.5, &HA0A0A0, 255
End Sub

Private Sub PaintBevel(ByVal Surface As OxSceneBuilder, _
        ByVal X As Single, ByVal Y As Single, ByVal W As Single, ByVal H As Single, _
        ByVal Effect As String)
    If Effect <> "raised" And Effect <> "sunken" Then
        Surface.DrawEdge X, Y, W, H, Effect, OxThemeEdgeLight(), OxThemeEdgeShadow()
        Exit Sub
    End If
    If Effect = "sunken" Then
        PaintEdgeLayer Surface, X, Y, W, H, &HA0A0A0, &HFFFFFF
        PaintEdgeLayer Surface, X + 0.75, Y + 0.75, W - 1.5, H - 1.5, &H696969, &HE3E3E3
    Else
        PaintEdgeLayer Surface, X, Y, W, H, &HFFFFFF, &H696969
        PaintEdgeLayer Surface, X + 0.75, Y + 0.75, W - 1.5, H - 1.5, &HE3E3E3, &HA0A0A0
    End If
End Sub

Public Sub OxThemePaintToggleButton( _
        ByVal Core As OxControlCore, _
        ByVal Surface As OxSceneBuilder, _
        ByVal Focused As Boolean, _
        ByVal Latched As Boolean)
    Dim IsPressed As Boolean
    IsPressed = Latched Or Core.Pressed

    Surface.OpenNode Core.NodeId, True, Core.PaintParentId, Core.ZOrder, _
        Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, Core.Visible

    Surface.FillRect Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, _
        OxThemeFaceColor(Core.Kind, IsPressed, Core.Enabled), 255

    Dim EdgeName As String
    If IsPressed Then
        EdgeName = "sunken"
    Else
        ' Native ToggleButton has no callable SpecialEffect property.
        EdgeName = "raised"
    End If
    PaintBevel Surface, Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, EdgeName

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
        OxThemePaintTextRun Core, Surface, Tx, Ty, Tw, Th, RunId, "center", False, True, False
    End If

    If Focused And Core.Enabled Then
        Surface.StrokeRect Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, _
            OxThemeFocusAdornerColor(), 255, 1
    End If

    Surface.CloseNode
End Sub

Public Sub OxThemePaintListBox( _
        ByVal Core As OxControlCore, _
        ByVal Surface As OxSceneBuilder, _
        ByVal ListIndex As Long, _
        ByVal Focused As Boolean, _
        ByVal SelectedRowsCsv As String, _
        ByVal RowCount As Long, ByVal RowHeight As Single, ByVal TopIndex As Long, ByVal ViewportHeight As Single)
    Const Inset As Single = 1.5

    Surface.OpenNode Core.NodeId, True, Core.PaintParentId, Core.ZOrder, _
        Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, Core.Visible

    OxThemePaintControlFrame Core, Surface

    Dim RowsNode As Long
    RowsNode = Core.NodeId * 1000 + 903
    Surface.AddChild RowsNode
    Surface.CloseNode

    If RowCount < 0 Then RowCount = 0
    Dim I As Long
    Dim SelY As Single, SelW As Single, Selected As Boolean, TextColor As Long
    SelW = Core.Width - (Inset * 2)
    If SelW < 0 Then SelW = 0
    Dim InnerHeight As Single, TextW As Single
    InnerHeight = ViewportHeight - (Inset * 2)
    If InnerHeight > Core.Height - (Inset * 2) Then InnerHeight = Core.Height - (Inset * 2)
    If InnerHeight < 0 Then InnerHeight = 0
    TextW = Core.Width - 9.75
    If TextW < 0 Then TextW = 0
    Surface.OpenNodeClipped RowsNode, True, Core.NodeId, 0, _
        Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, Core.Visible, _
        Core.PaintLeft + Inset, Core.PaintTop + Inset, SelW, InnerHeight
    If TopIndex < 0 Then TopIndex = 0
    For I = TopIndex To RowCount - 1
        SelY = Core.PaintTop + Inset + ((I - TopIndex) * RowHeight)
        If SelY >= Core.PaintTop + Inset + InnerHeight Then Exit For
        Selected = InStr(1, SelectedRowsCsv, "," & CStr(I) & ",", vbBinaryCompare) > 0 _
            Or (Len(SelectedRowsCsv) = 0 And I = ListIndex)
        TextColor = OxThemeResolveText(Core)
        If Selected Then
            Surface.FillRect Core.PaintLeft + Inset, SelY, SelW, RowHeight, _
                OxThemeSelectionBackColor(), 255
            TextColor = OxThemeSelectionTextColor()
        End If
        Dim RunId As String
        RunId = Core.TextPartRunId(I)
        If Len(RunId) > 0 And TextW > 0 Then
            Surface.DrawText Core.PaintLeft + 8.25, SelY, TextW, _
                RowHeight, RunId, "left", False, True, TextColor, 255, False, Not Core.Enabled
        End If
    Next I
    If Focused And Core.Enabled And ListIndex >= TopIndex Then
        Surface.StrokeRect Core.PaintLeft + Inset, Core.PaintTop + Inset + (ListIndex - TopIndex) * RowHeight, SelW, RowHeight, _
            OxThemeFocusAdornerColor(), 255, 1
    End If

    Surface.CloseNode
End Sub

Public Sub OxThemePaintComboBox( _
        ByVal Core As OxControlCore, _
        ByVal Surface As OxSceneBuilder, _
        ByVal ListIndex As Long, _
        ByVal Focused As Boolean, _
        ByVal DropDownOpen As Boolean, _
        ByVal RowCount As Long, _
        ByVal ButtonWidth As Single)
    Const Inset As Single = 3
    Const TextInsetX As Single = 9
    Const RowHeight As Single = 14

    Dim PopupHeight As Single
    PopupHeight = 0
    If DropDownOpen Then PopupHeight = RowHeight * RowCount

    Surface.OpenNode Core.NodeId, True, Core.PaintParentId, Core.ZOrder, _
        Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height + PopupHeight, Core.Visible

    OxThemePaintControlFrame Core, Surface

    Dim ButtonLeft As Single
    ButtonLeft = Core.PaintLeft + Core.Width - ButtonWidth
    Surface.FillRect ButtonLeft, Core.PaintTop + 1.5, ButtonWidth - 1, Core.Height - 2.5, _
        OxThemeFaceColor(oxControlCommandButton, False, Core.Enabled), 255
    PaintDropButtonEdge Surface, ButtonLeft, Core.PaintTop + 1.5, ButtonWidth - 1, Core.Height - 2.5

    Dim ArrowX As Single
    Dim ArrowY As Single
    ArrowX = ButtonLeft + (ButtonWidth - 1 - 5.25) / 2 - 0.5
    ArrowY = Core.PaintTop + (Core.Height / 2) - 1.5
    Surface.FillRect ArrowX, ArrowY, 5.25, 0.75, OxThemeResolveText(Core), 255
    Surface.FillRect ArrowX + 0.75, ArrowY + 0.75, 3.75, 0.75, OxThemeResolveText(Core), 255
    Surface.FillRect ArrowX + 1.5, ArrowY + 1.5, 2.25, 0.75, OxThemeResolveText(Core), 255
    Surface.FillRect ArrowX + 2.25, ArrowY + 2.25, 0.75, 0.75, OxThemeResolveText(Core), 255

    If Focused Then
        Surface.StrokeRect Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, _
            OxThemeFocusAdornerColor(), 255, 1
    End If

    If Len(Core.DisplayText) > 0 Then
        Dim RunId As String
        RunId = Core.RunId
        If Len(RunId) = 0 Then RunId = "0"
        Dim TextW As Single, TextH As Single
        TextW = Core.Width - ButtonWidth - TextInsetX - Inset
        If TextW < 1 Then TextW = 1
        TextH = Core.MeasuredHeight
        If TextH > Core.Height - Inset - 1.5 Then TextH = Core.Height - Inset - 1.5
        If TextH < 1 Then TextH = 1
        OxThemePaintTextRun Core, Surface, _
            Core.PaintLeft + TextInsetX, Core.PaintTop + Inset, TextW, TextH, _
            RunId, "left", False, True, False
    End If

    If DropDownOpen Then
        Dim PopupTop As Single
        PopupTop = Core.PaintTop + Core.Height
        Surface.FillRect Core.PaintLeft, PopupTop, Core.Width, PopupHeight, OxThemeResolveFace(Core), 255
        Surface.DrawEdge Core.PaintLeft, PopupTop, Core.Width, PopupHeight, "sunken", _
            OxThemeEdgeLight(), OxThemeEdgeShadow()
        If ListIndex >= 0 Then
            Surface.FillRect Core.PaintLeft + Inset, PopupTop + Inset + (ListIndex * RowHeight), _
                Core.Width - (Inset * 2), RowHeight, OxThemeSelectionBackColor(), 255
        End If
        Dim I As Long
        For I = 1 To RowCount - 1
            Surface.FillRect Core.PaintLeft + 1, PopupTop + (I * RowHeight), _
                Core.Width - 2, 1, &HE8E8E8, 255
        Next I
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
    ' Owned Excel/Tahoma greeter at 100% and 150%: 13px and 19px glyphs,
    ' caption starts 13.5pt after the control's left edge. The site remains the
    ' full hit target; the keyboard focus adorner encloses only the caption.
    Const BoxSize As Single = 9.5

    Surface.OpenNode Core.NodeId, True, Core.PaintParentId, Core.ZOrder, _
        Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, Core.Visible

    Dim BoxX As Single, BoxY As Single
    BoxX = Core.PaintLeft + 0.5
    BoxY = Core.PaintTop + (Core.Height - BoxSize) / 2 - 0.5

    Surface.FillRect BoxX, BoxY, BoxSize, BoxSize, OxThemeResolveFace(Core), 255
    Surface.DrawEdge BoxX, BoxY, BoxSize, BoxSize, _
        "sunken", OxThemeEdgeLight(), OxThemeEdgeShadow()
    If Checked Then
        Surface.Polygon OxThemeResolveText(Core), 255, _
            BoxX + 2.25, BoxY + 3.75, BoxX + 3.75, BoxY + 5.25, _
            BoxX + 6.75, BoxY + 2.25, BoxX + 6.75, BoxY + 3.75, _
            BoxX + 3.75, BoxY + 6.75, BoxX + 2.25, BoxY + 5.25
    End If

    If Len(Core.DisplayText) > 0 Then
        Dim Tx As Single, Ty As Single, Tw As Single, Th As Single
        Tx = Core.PaintLeft + 13.5
        Ty = Core.PaintTop + 3
        Tw = Core.Width - 15
        If Tw < 1 Then Tw = 1
        Th = Core.Height - 6
        If Th < 1 Then Th = 1
        Dim RunId As String
        RunId = Core.RunId
        If Len(RunId) = 0 Then RunId = "0"
        OxThemePaintTextRun Core, Surface, Tx, Ty, Tw, Th, RunId, "left", False, True, False
    End If

    If Focused And Core.Enabled Then
        Dim FocusW As Single, FocusH As Single
        FocusW = Core.MeasuredWidth + 3
        If FocusW > Core.Width - 12 Then FocusW = Core.Width - 12
        If FocusW < 1 Then FocusW = 1
        FocusH = Core.MeasuredHeight + 3
        If FocusH > Core.Height Then FocusH = Core.Height
        Surface.StrokeRect Core.PaintLeft + 12, Core.PaintTop + (Core.Height - FocusH) / 2, FocusW, FocusH, _
            OxThemeFocusAdornerColor(), 255, 1
    End If

    Surface.CloseNode
End Sub

Public Sub OxThemePaintOptionButton( _
        ByVal Core As OxControlCore, _
        ByVal Surface As OxSceneBuilder, _
        ByVal Checked As Boolean, _
        ByVal Focused As Boolean)
    Const DotSize As Single = 4.5
    Const GlyphSize As Single = 9.75

    Surface.OpenNode Core.NodeId, True, Core.PaintParentId, Core.ZOrder, _
        Core.PaintLeft, Core.PaintTop, Core.Width, Core.Height, Core.Visible

    Dim GlyphX As Single, GlyphY As Single
    GlyphX = Core.PaintLeft + 1.5
    GlyphY = Core.PaintTop + (Core.Height - GlyphSize) / 2 - 0.75

    Surface.Ellipse GlyphX, GlyphY, GlyphSize, GlyphSize, _
        OxThemeEdgeLight(), 255, OxThemeEdgeLight(), 255, 0
    Surface.Ellipse GlyphX, GlyphY, GlyphSize - 1.5, GlyphSize - 1.5, _
        OxThemeResolveFace(Core), 255, OxThemeEdgeShadow(), 255, 0.75
    If Checked Then
        Surface.Ellipse GlyphX + 2.25, GlyphY + 2.25, DotSize, DotSize, _
            OxThemeResolveText(Core), 255, OxThemeResolveText(Core), 255, 0
    End If

    If Len(Core.DisplayText) > 0 Then
        Dim Tx As Single, Ty As Single, Tw As Single, Th As Single
        Tx = Core.PaintLeft + 13.5
        Ty = Core.PaintTop + 3
        Tw = Core.Width - 15
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
