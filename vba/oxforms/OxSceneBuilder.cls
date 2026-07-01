Option Explicit

' The VBA-side scene builder: a control's Render method paints into it in immediate
' mode (OpenNode -> primitive recorders -> CloseNode), and it accumulates one
' batched ScenePatch that crosses the OxForms.Surface boundary exactly once per
' frame. None of these recorder calls cross the boundary -- only the serialized
' ToPatchJson result does (see docs/specs/RENDERING_ARCHITECTURE.md s6).
'
' The wire format is the serde-shaped JSON of oxforms_pal::scene::ScenePatch (full
' rebuild: every node is an Upsert). Geometry is emitted with a locale-independent
' numeric formatter so it round-trips to the same f32 the kernel hashes. NodeIds
' are small Longs (the form/root is 0; controls intern nonzero ids); base_hash is
' threaded verbatim as the opaque decimal token BeginScene/SubmitPatch returned, so
' VBA never does 64-bit arithmetic.

Private mBaseToken As String
Private mWidth As Long
Private mHeight As Long
Private mDpiX As Long
Private mDpiY As Long
Private mNodes As Collection

' State for the currently open node.
Private mOpen As Boolean
Private mCurId As Long
Private mCurHasParent As Boolean
Private mCurParent As Long
Private mCurZ As Long
Private mCurBx As Single
Private mCurBy As Single
Private mCurBw As Single
Private mCurBh As Single
Private mCurVisible As Boolean
Private mCurHasClip As Boolean
Private mCurClipX As Single
Private mCurClipY As Single
Private mCurClipW As Single
Private mCurClipH As Single
Private mCurPrims As String
Private mCurChildren As String

Private Sub Class_Initialize()
    Set mNodes = New Collection
End Sub

' Start a new full-rebuild patch against the resident frame token.
Public Sub BeginPatch( _
        ByVal BaseToken As String, _
        ByVal SurfaceWidth As Long, _
        ByVal SurfaceHeight As Long, _
        ByVal DpiX As Long, _
        ByVal DpiY As Long)
    mBaseToken = BaseToken
    mWidth = SurfaceWidth
    mHeight = SurfaceHeight
    mDpiX = DpiX
    mDpiY = DpiY
    Set mNodes = New Collection
    mOpen = False
End Sub

' Begin a node. Bounds are in parent space; v1 uses identity transforms, so prim
' coordinates and bounds are both surface-absolute.
Public Sub OpenNode( _
        ByVal Id As Long, _
        ByVal HasParent As Boolean, _
        ByVal ParentId As Long, _
        ByVal Z As Long, _
        ByVal BoundsX As Single, _
        ByVal BoundsY As Single, _
        ByVal BoundsW As Single, _
        ByVal BoundsH As Single, _
        ByVal Visible As Boolean)
    mCurId = Id
    mCurHasParent = HasParent
    mCurParent = ParentId
    mCurZ = Z
    mCurBx = BoundsX
    mCurBy = BoundsY
    mCurBw = BoundsW
    mCurBh = BoundsH
    mCurVisible = Visible
    mCurHasClip = False
    mCurPrims = ""
    mCurChildren = ""
    mOpen = True
End Sub

Public Sub OpenNodeClipped( _
        ByVal Id As Long, _
        ByVal HasParent As Boolean, _
        ByVal ParentId As Long, _
        ByVal Z As Long, _
        ByVal BoundsX As Single, _
        ByVal BoundsY As Single, _
        ByVal BoundsW As Single, _
        ByVal BoundsH As Single, _
        ByVal Visible As Boolean, _
        ByVal ClipX As Single, _
        ByVal ClipY As Single, _
        ByVal ClipW As Single, _
        ByVal ClipH As Single)
    mCurId = Id
    mCurHasParent = HasParent
    mCurParent = ParentId
    mCurZ = Z
    mCurBx = BoundsX
    mCurBy = BoundsY
    mCurBw = BoundsW
    mCurBh = BoundsH
    mCurVisible = Visible
    mCurHasClip = True
    mCurClipX = ClipX
    mCurClipY = ClipY
    mCurClipW = ClipW
    mCurClipH = ClipH
    mCurPrims = ""
    mCurChildren = ""
    mOpen = True
End Sub

' Record a child node id in the open node's paint-order children list.
Public Sub AddChild(ByVal ChildId As Long)
    AppendCsv mCurChildren, JsonNum(ChildId)
End Sub

Public Sub FillRect( _
        ByVal X As Single, ByVal Y As Single, ByVal W As Single, ByVal H As Single, _
        ByVal Rgb As Long, ByVal Alpha As Long)
    AppendCsv mCurPrims, _
        "{""op"":""fill_rect"",""rect"":" & JsonRect(X, Y, W, H) & _
        ",""paint"":" & JsonSolid(Rgb, Alpha) & "}"
End Sub

Public Sub StrokeRect( _
        ByVal X As Single, ByVal Y As Single, ByVal W As Single, ByVal H As Single, _
        ByVal Rgb As Long, ByVal Alpha As Long, ByVal Width As Single)
    AppendCsv mCurPrims, _
        "{""op"":""stroke_rect"",""rect"":" & JsonRect(X, Y, W, H) & _
        ",""stroke"":{""paint"":" & JsonSolid(Rgb, Alpha) & _
        ",""width"":" & JsonNum(Width) & "}}"
End Sub

' Generic 3D edge; EffectName is the kernel's snake_case edge ("raised"/"sunken"/...).
Public Sub DrawEdge( _
        ByVal X As Single, ByVal Y As Single, ByVal W As Single, ByVal H As Single, _
        ByVal EffectName As String, ByVal LightRgb As Long, ByVal ShadowRgb As Long)
    AppendCsv mCurPrims, _
        "{""op"":""draw_edge"",""rect"":" & JsonRect(X, Y, W, H) & _
        ",""effect"":""" & EffectName & """" & _
        ",""border"":{""left"":true,""top"":true,""right"":true,""bottom"":true}" & _
        ",""light"":" & JsonColor(LightRgb, 255) & _
        ",""shadow"":" & JsonColor(ShadowRgb, 255) & "}"
End Sub

' Text references a measured run by id. RunId is a decimal String (a content-hash u64
' from OxForms.Surface.MeasureBatch — it does not fit a VBA Long), emitted raw as the
' JSON number; "0" means an unmeasured/empty run. Align is "left"/"center"/"right".
Public Sub DrawText( _
        ByVal X As Single, ByVal Y As Single, ByVal W As Single, ByVal H As Single, _
        ByVal RunId As String, ByVal Align As String, ByVal Wrap As Boolean, ByVal Clip As Boolean, _
        ByVal Rgb As Long, ByVal Alpha As Long, _
        ByVal UnderlineAccelerator As Boolean, ByVal Disabled As Boolean)
    AppendCsv mCurPrims, _
        "{""op"":""draw_text"",""run"":" & RunId & _
        ",""rect"":" & JsonRect(X, Y, W, H) & _
        ",""align"":""" & Align & """" & _
        ",""wrap"":" & JsonBool(Wrap) & ",""clip"":" & JsonBool(Clip) & _
        ",""paint"":" & JsonSolid(Rgb, Alpha) & _
        ",""flags"":{""underline_accelerator"":" & JsonBool(UnderlineAccelerator) & _
        ",""disabled"":" & JsonBool(Disabled) & "}}"
End Sub

' Finish the open node and add it to the patch as an Upsert.
Public Sub CloseNode()
    Dim ParentJson As String
    If mCurHasParent Then
        ParentJson = JsonNum(mCurParent)
    Else
        ParentJson = "null"
    End If

    Dim ClipJson As String
    If mCurHasClip Then
        ClipJson = JsonRect(mCurClipX, mCurClipY, mCurClipW, mCurClipH)
    Else
        ClipJson = "null"
    End If

    Dim Node As String
    Node = "{""id"":" & JsonNum(mCurId) & _
        ",""parent"":" & ParentJson & _
        ",""z"":" & JsonNum(mCurZ) & _
        ",""transform"":{""sx"":1,""sy"":1,""tx"":0,""ty"":0}" & _
        ",""clip"":" & ClipJson & _
        ",""bounds"":" & JsonRect(mCurBx, mCurBy, mCurBw, mCurBh) & _
        ",""visible"":" & JsonBool(mCurVisible) & _
        ",""prims"":[" & mCurPrims & "]" & _
        ",""children"":[" & mCurChildren & "]}"
    mNodes.Add Node
    mOpen = False
End Sub

' Serialize the accumulated patch as the JSON OxForms.Surface.SubmitPatch expects.
Public Function ToPatchJson() As String
    Dim Edits As String
    Dim I As Long
    For I = 1 To mNodes.Count
        AppendCsv Edits, "{""upsert"":" & mNodes.Item(I) & "}"
    Next I

    ToPatchJson = "{""version"":1" & _
        ",""base_hash"":" & mBaseToken & _
        ",""surface"":{""width"":" & JsonNum(mWidth) & ",""height"":" & JsonNum(mHeight) & "}" & _
        ",""dpi"":{""dpi_x"":" & JsonNum(mDpiX) & ",""dpi_y"":" & JsonNum(mDpiY) & _
        ",""scale_x"":null,""scale_y"":null}" & _
        ",""edits"":[" & Edits & "]}"
End Function

' --- JSON encoding helpers (the only place that touches the wire format) ---

Private Sub AppendCsv(ByRef Target As String, ByVal Item As String)
    If Len(Target) > 0 Then
        Target = Target & "," & Item
    Else
        Target = Item
    End If
End Sub

' Locale-independent number formatting. Str$ always uses "." as the decimal
' separator and a leading space for non-negatives (trimmed here); we repair the
' VBA ".5"/"-.5" forms into JSON-legal "0.5"/"-0.5".
Private Function JsonNum(ByVal V As Double) As String
    Dim S As String
    S = Trim$(Str$(V))
    If Left$(S, 1) = "." Then
        S = "0" & S
    ElseIf Left$(S, 2) = "-." Then
        S = "-0" & Mid$(S, 2)
    End If
    JsonNum = S
End Function

Private Function JsonBool(ByVal B As Boolean) As String
    If B Then
        JsonBool = "true"
    Else
        JsonBool = "false"
    End If
End Function

Private Function JsonRect( _
        ByVal X As Single, ByVal Y As Single, ByVal W As Single, ByVal H As Single) As String
    JsonRect = "{""x"":" & JsonNum(X) & ",""y"":" & JsonNum(Y) & _
        ",""w"":" & JsonNum(W) & ",""h"":" & JsonNum(H) & "}"
End Function

' A scene Color object from a 0xRRGGBB Long + alpha byte.
Private Function JsonColor(ByVal Rgb As Long, ByVal Alpha As Long) As String
    Dim R As Long, G As Long, B As Long
    R = (Rgb \ 65536) And 255
    G = (Rgb \ 256) And 255
    B = Rgb And 255
    JsonColor = "{""red"":" & R & ",""green"":" & G & ",""blue"":" & B & _
        ",""alpha"":" & Alpha & "}"
End Function

' A Paint::Solid (externally tagged enum -> {"Solid": <color>}).
Private Function JsonSolid(ByVal Rgb As Long, ByVal Alpha As Long) As String
    JsonSolid = "{""Solid"":" & JsonColor(Rgb, Alpha) & "}"
End Function
