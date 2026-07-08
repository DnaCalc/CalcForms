Option Explicit

' Representative selected-slice .frm/.frx materializer. It intentionally builds the real VBA
' object model (UserForm + Controls.Add + concrete IOxControl classes) instead of recreating the
' deleted Rust RuntimeForm/ControlNode projection.

Private mForm As UserForm
Private mCurrent As IOxControl
Private mInControl As Boolean
Private mCurrentType As String
Private mCurrentName As String
Private mUnsupportedControls As String
Private mFrxReferences As String
Private mImageMetadata As String
Private mImageLeft As Single
Private mImageTop As Single
Private mImageWidth As Single
Private mImageHeight As Single
Private mImagePicturePath As String
Private mImagePictureOffset As Long

Public Function Materialize(ByVal FrmText As String) As UserForm
    Set mForm = Nothing
    Set mCurrent = Nothing
    mInControl = False
    mCurrentType = ""
    mCurrentName = ""
    mUnsupportedControls = ""
    mFrxReferences = ""
    mImageMetadata = ""

    Dim Pos As Long
    Dim NextBreak As Long
    Dim Line As String
    Pos = 1
    Do While Pos <= Len(FrmText)
        NextBreak = InStr(Pos, FrmText, vbLf)
        If NextBreak = 0 Then
            Line = Mid$(FrmText, Pos)
            Pos = Len(FrmText) + 1
        Else
            Line = Mid$(FrmText, Pos, NextBreak - Pos)
            Pos = NextBreak + 1
        End If
        If Len(Line) > 0 Then
            If Mid$(Line, Len(Line), 1) = vbCr Then Line = Left$(Line, Len(Line) - 1)
        End If
        ParseLine Trim$(Line)
    Loop

    Set Materialize = mForm
End Function

Public Property Get LoadedForm() As UserForm
    Set LoadedForm = mForm
End Property

Public Property Get UnsupportedControls() As String
    UnsupportedControls = mUnsupportedControls
End Property

Public Property Get FrxReferences() As String
    FrxReferences = mFrxReferences
End Property

Public Property Get ImageMetadata() As String
    ImageMetadata = mImageMetadata
End Property

Public Property Get MaterializationCatalog() As String
    If mForm Is Nothing Then Exit Property

    Dim Text As String
    Text = "form;name=" & mForm.Name & _
        ";caption=" & mForm.Caption & _
        ";width=" & CStr(mForm.Width) & _
        ";height=" & CStr(mForm.Height) & _
        ";controls=" & CStr(mForm.Controls.Count)

    Dim I As Long
    Dim Control As IOxControl
    For I = 1 To mForm.Controls.Count
        Set Control = mForm.Controls.Item(I)
        Text = Text & vbLf & ControlCatalogRow(Control)
    Next I

    MaterializationCatalog = Text
End Property

Private Sub ParseLine(ByVal Line As String)
    If Len(Line) = 0 Then Exit Sub
    If StartsWith(Line, "VERSION ") Then Exit Sub
    If StartsWith(Line, "Attribute ") Then Exit Sub

    If StartsWith(Line, "Begin ") Then
        ParseBegin Trim$(Mid$(Line, 7))
    ElseIf Line = "End" Then
        ParseEnd
    Else
        ParseProperty Line
    End If
End Sub

Private Sub ParseBegin(ByVal Rest As String)
    Dim Sep As Long
    Sep = InStr(Rest, " ")
    If Sep = 0 Then Exit Sub

    Dim TypeName As String
    Dim ObjectName As String
    TypeName = Left$(Rest, Sep - 1)
    ObjectName = Trim$(Mid$(Rest, Sep + 1))

    If StartsWith(TypeName, "{") Then
        Set mForm = New UserForm
        mForm.Name = ObjectName
        Exit Sub
    End If

    If mForm Is Nothing Then Exit Sub

    mInControl = True
    mCurrentType = TypeName
    mCurrentName = ObjectName
    Set mCurrent = Nothing
    ResetImageScratch

    Dim ProgId As String
    ProgId = ProgIdForType(TypeName)
    If Len(ProgId) > 0 Then
        Set mCurrent = mForm.Controls.Add(ProgId, ObjectName)
    Else
        AppendLine mUnsupportedControls, "control=" & ObjectName & ";type=" & TypeName
    End If
End Sub

Private Sub ParseEnd()
    If mInControl Then
        If LCase$(mCurrentType) = "msforms.image" Then
            AppendLine mImageMetadata, ImageMetadataRow()
        End If
        Set mCurrent = Nothing
        mCurrentType = ""
        mCurrentName = ""
        mInControl = False
    End If
End Sub

Private Sub ParseProperty(ByVal Line As String)
    Dim Eq As Long
    Eq = InStr(Line, "=")
    If Eq = 0 Then Exit Sub

    Dim Key As String
    Dim Raw As String
    Key = Trim$(Left$(Line, Eq - 1))
    Raw = Trim$(Mid$(Line, Eq + 1))

    If mInControl Then
        If mCurrent Is Nothing Then
            ApplyUnsupportedProperty Key, Raw
        Else
            ApplyControlProperty Key, Raw
        End If
    ElseIf Not mForm Is Nothing Then
        ApplyFormProperty Key, Raw
    End If
End Sub

Private Sub ApplyFormProperty(ByVal Key As String, ByVal Raw As String)
    Select Case LCase$(Key)
        Case "caption"
            mForm.Caption = Unquote(Raw)
        Case "clientwidth"
            mForm.Width = TwipsToPoints(Raw)
        Case "clientheight"
            mForm.Height = TwipsToPoints(Raw)
        Case "left"
            mForm.Left = TwipsToPoints(Raw)
        Case "top"
            mForm.Top = TwipsToPoints(Raw)
    End Select
End Sub

Private Sub ApplyControlProperty(ByVal Key As String, ByVal Raw As String)
    Select Case LCase$(Key)
        Case "caption", "text"
            mCurrent.Core.DisplayText = Unquote(Raw)
        Case "left"
            mCurrent.Core.Left = TwipsToPoints(Raw)
        Case "top"
            mCurrent.Core.Top = TwipsToPoints(Raw)
        Case "width"
            mCurrent.Core.Width = TwipsToPoints(Raw)
        Case "height"
            mCurrent.Core.Height = TwipsToPoints(Raw)
        Case "tabindex"
            mCurrent.Core.TabIndex = CLng(Raw)
        Case "tabstop"
            mCurrent.Core.TabStop = BoolValue(Raw)
        Case "enabled"
            mCurrent.Core.Enabled = BoolValue(Raw)
        Case "visible"
            mCurrent.Core.Visible = BoolValue(Raw)
        Case "backcolor"
            mCurrent.Core.BackColor = CLng(Raw)
        Case "forecolor"
            mCurrent.Core.ForeColor = CLng(Raw)
        Case "bordercolor"
            mCurrent.Core.BorderColor = CLng(Raw)
        Case "borderstyle"
            mCurrent.Core.BorderStyle = CLng(Raw)
        Case "specialeffect"
            mCurrent.Core.SpecialEffect = CLng(Raw)
        Case "default"
            ApplyCommandDefault BoolValue(Raw)
        Case "cancel"
            ApplyCommandCancel BoolValue(Raw)
        Case "value"
            ApplyValue Raw
        Case "multiselect"
            ApplyListBoxMultiSelect CLng(Raw)
        Case "columncount"
            ApplyListBoxColumnCount CLng(Raw)
        Case "boundcolumn"
            ApplyListBoxBoundColumn CLng(Raw)
        Case "groupname"
            ApplyGroupName Unquote(Raw)
        Case "picture", "mouseicon"
            RecordFrxReference mCurrentName, Key, Raw
            ApplyImagePicture Key, Raw
        Case "picturesizemode"
            ApplyImageSizeMode CLng(Raw)
    End Select
End Sub

Private Sub ApplyUnsupportedProperty(ByVal Key As String, ByVal Raw As String)
    Select Case LCase$(Key)
        Case "left"
            mImageLeft = TwipsToPoints(Raw)
        Case "top"
            mImageTop = TwipsToPoints(Raw)
        Case "width"
            mImageWidth = TwipsToPoints(Raw)
        Case "height"
            mImageHeight = TwipsToPoints(Raw)
        Case "picture", "mouseicon"
            RecordFrxReference mCurrentName, Key, Raw
            mImagePicturePath = FrxPath(Raw)
            mImagePictureOffset = FrxOffset(Raw)
    End Select
End Sub

Private Sub ApplyCommandDefault(ByVal Value As Boolean)
    If LCase$(mCurrentType) <> "msforms.commandbutton" Then Exit Sub
    Dim Button As CommandButton
    Set Button = mCurrent
    Button.Default = Value
End Sub

Private Sub ApplyCommandCancel(ByVal Value As Boolean)
    If LCase$(mCurrentType) <> "msforms.commandbutton" Then Exit Sub
    Dim Button As CommandButton
    Set Button = mCurrent
    Button.Cancel = Value
End Sub

Private Sub ApplyCheckValue(ByVal Value As Boolean)
    If LCase$(mCurrentType) <> "msforms.checkbox" Then Exit Sub
    Dim Box As CheckBox
    Set Box = mCurrent
    Box.Value = Value
End Sub

Private Sub ApplyToggleValue(ByVal Value As Boolean)
    If LCase$(mCurrentType) <> "msforms.togglebutton" Then Exit Sub
    Dim Button As ToggleButton
    Set Button = mCurrent
    Button.Value = Value
End Sub

Private Sub ApplyOptionValue(ByVal Value As Boolean)
    If LCase$(mCurrentType) <> "msforms.optionbutton" Then Exit Sub
    Dim Button As OptionButtonControl
    Set Button = mCurrent
    Button.Value = Value
End Sub

Private Sub ApplyGroupName(ByVal Value As String)
    If LCase$(mCurrentType) <> "msforms.optionbutton" Then Exit Sub
    Dim Button As OptionButtonControl
    Set Button = mCurrent
    Button.GroupName = Value
End Sub

Private Sub ApplyListBoxMultiSelect(ByVal Value As Long)
    If LCase$(mCurrentType) <> "msforms.listbox" Then Exit Sub
    Dim Box As ListBox
    Set Box = mCurrent
    Box.MultiSelect = Value
End Sub

Private Sub ApplyListBoxColumnCount(ByVal Value As Long)
    If LCase$(mCurrentType) <> "msforms.listbox" Then Exit Sub
    Dim Box As ListBox
    Set Box = mCurrent
    Box.ColumnCount = Value
End Sub

Private Sub ApplyListBoxBoundColumn(ByVal Value As Long)
    If LCase$(mCurrentType) <> "msforms.listbox" Then Exit Sub
    Dim Box As ListBox
    Set Box = mCurrent
    Box.BoundColumn = Value
End Sub

Private Sub ApplyValue(ByVal Raw As String)
    Select Case LCase$(mCurrentType)
        Case "msforms.checkbox"
            ApplyCheckValue BoolValue(Raw)
        Case "msforms.togglebutton"
            ApplyToggleValue BoolValue(Raw)
        Case "msforms.optionbutton"
            ApplyOptionValue BoolValue(Raw)
        Case "msforms.textbox"
            Dim Box As TextBox
            Set Box = mCurrent
            Box.Value = Unquote(Raw)
    End Select
End Sub

Private Function ControlCatalogRow(ByVal Control As IOxControl) As String
    ControlCatalogRow = _
        "control;name=" & Control.Core.Name & _
        ";role=" & Control.AccessibilityRole & _
        ";value=" & Control.AccessibilityValue & _
        ";left=" & CStr(Control.Core.Left) & _
        ";top=" & CStr(Control.Core.Top) & _
        ";width=" & CStr(Control.Core.Width) & _
        ";height=" & CStr(Control.Core.Height) & _
        ";enabled=" & CStr(Control.Core.Enabled) & _
        ";visible=" & CStr(Control.Core.Visible) & _
        ";tabindex=" & CStr(Control.Core.TabIndex) & _
        ";tabstop=" & CStr(Control.Core.TabStop) & _
        ";backcolor=" & CStr(Control.Core.BackColor) & _
        ";forecolor=" & CStr(Control.Core.ForeColor) & _
        ";borderstyle=" & CStr(Control.Core.BorderStyle) & _
        ";default=" & CStr(Control.IsDefault) & _
        ";cancel=" & CStr(Control.IsCancel)
End Function

Private Function ProgIdForType(ByVal TypeName As String) As String
    Select Case LCase$(TypeName)
        Case "msforms.label"
            ProgIdForType = "Forms.Label.1"
        Case "msforms.textbox"
            ProgIdForType = "Forms.TextBox.1"
        Case "msforms.commandbutton"
            ProgIdForType = "Forms.CommandButton.1"
        Case "msforms.checkbox"
            ProgIdForType = "Forms.CheckBox.1"
        Case "msforms.togglebutton"
            ProgIdForType = "Forms.ToggleButton.1"
        Case "msforms.optionbutton"
            ProgIdForType = "Forms.OptionButton.1"
        Case "msforms.listbox"
            ProgIdForType = "Forms.ListBox.1"
        Case "msforms.image"
            ProgIdForType = "Forms.Image.1"
    End Select
End Function

Private Sub ApplyImagePicture(ByVal Key As String, ByVal Raw As String)
    If LCase$(mCurrentType) <> "msforms.image" Then Exit Sub
    If LCase$(Key) <> "picture" Then Exit Sub

    Dim Img As Image
    Set Img = mCurrent
    mImagePicturePath = FrxPath(Raw)
    mImagePictureOffset = FrxOffset(Raw)
    Img.SetPictureReference _
        mImagePicturePath, _
        mImagePictureOffset, _
        "", _
        CStr(9000 + Img.Core.NodeId)
End Sub

Private Sub ApplyImageSizeMode(ByVal Value As Long)
    If LCase$(mCurrentType) <> "msforms.image" Then Exit Sub
    Dim Img As Image
    Set Img = mCurrent
    Img.PictureSizeMode = Value
End Sub

Private Function ImageMetadataRow() As String
    If Not mCurrent Is Nothing Then
        Dim Img As Image
        Set Img = mCurrent
        ImageMetadataRow = _
            "image;name=" & Img.Core.Name & _
            ";left=" & CStr(Img.Core.Left) & _
            ";top=" & CStr(Img.Core.Top) & _
            ";width=" & CStr(Img.Core.Width) & _
            ";height=" & CStr(Img.Core.Height) & _
            ";picture_path=" & Img.Picture & _
            ";picture_offset=" & CStr(Img.PictureOffset) & _
            ";handle=" & Img.PictureHandle
        Exit Function
    End If

    ImageMetadataRow = _
        "image;name=" & mCurrentName & _
        ";left=" & CStr(mImageLeft) & _
        ";top=" & CStr(mImageTop) & _
        ";width=" & CStr(mImageWidth) & _
        ";height=" & CStr(mImageHeight) & _
        ";picture_path=" & mImagePicturePath & _
        ";picture_offset=" & CStr(mImagePictureOffset) & _
        ";handle="
End Function

Private Function TwipsToPoints(ByVal Raw As String) As Single
    TwipsToPoints = CSng(CLng(Raw)) / 20
End Function

Private Function BoolValue(ByVal Raw As String) As Boolean
    Dim Text As String
    Text = UCase$(Trim$(Raw))
    BoolValue = (Text = "-1" Or Text = "TRUE")
End Function

Private Function Unquote(ByVal Raw As String) As String
    Dim Text As String
    Text = Trim$(Raw)
    If Len(Text) >= 2 Then
        If Left$(Text, 1) = """" And Mid$(Text, Len(Text), 1) = """" Then
            Unquote = Mid$(Text, 2, Len(Text) - 2)
            Exit Function
        End If
    End If
    Unquote = Text
End Function

Private Sub RecordFrxReference(ByVal ControlName As String, ByVal PropertyName As String, ByVal Raw As String)
    Dim Path As String
    Path = FrxPath(Raw)
    If Len(Path) = 0 Then Exit Sub

    AppendLine mFrxReferences, _
        "control=" & ControlName & _
        ";property=" & PropertyName & _
        ";path=" & Path & _
        ";offset=" & CStr(FrxOffset(Raw))
End Sub

Private Function FrxPath(ByVal Raw As String) As String
    Dim Q1 As Long
    Dim Q2 As Long
    Q1 = InStr(Raw, """")
    If Q1 = 0 Then Exit Function
    Q2 = InStr(Q1 + 1, Raw, """")
    If Q2 = 0 Then Exit Function
    FrxPath = Mid$(Raw, Q1 + 1, Q2 - Q1 - 1)
End Function

Private Function FrxOffset(ByVal Raw As String) As Long
    Dim Q1 As Long
    Dim Q2 As Long
    Dim Colon As Long
    Q1 = InStr(Raw, """")
    If Q1 = 0 Then Exit Function
    Q2 = InStr(Q1 + 1, Raw, """")
    If Q2 = 0 Then Exit Function
    Colon = InStr(Q2 + 1, Raw, ":")
    If Colon = 0 Then Exit Function
    FrxOffset = HexToLong(Trim$(Mid$(Raw, Colon + 1)))
End Function

Private Function HexToLong(ByVal Text As String) As Long
    Dim I As Long
    Dim Ch As String
    Dim Digit As Long
    For I = 1 To Len(Text)
        Ch = UCase$(Mid$(Text, I, 1))
        If Ch >= "0" And Ch <= "9" Then
            Digit = Asc(Ch) - Asc("0")
        ElseIf Ch >= "A" And Ch <= "F" Then
            Digit = 10 + Asc(Ch) - Asc("A")
        Else
            Exit For
        End If
        HexToLong = HexToLong * 16 + Digit
    Next I
End Function

Private Function StartsWith(ByVal Text As String, ByVal Prefix As String) As Boolean
    If Len(Text) < Len(Prefix) Then Exit Function
    StartsWith = (Left$(Text, Len(Prefix)) = Prefix)
End Function

Private Sub AppendLine(ByRef Target As String, ByVal Line As String)
    If Len(Target) > 0 Then Target = Target & vbLf
    Target = Target & Line
End Sub

Private Sub ResetImageScratch()
    mImageLeft = 0
    mImageTop = 0
    mImageWidth = 0
    mImageHeight = 0
    mImagePicturePath = ""
    mImagePictureOffset = 0
End Sub
