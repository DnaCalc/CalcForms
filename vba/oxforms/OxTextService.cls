Option Explicit

' Single-line TextBox geometry service. The Rust/PAL side shapes text and returns
' typed metrics + caret stops through MeasureBatch; this VBA seam consumes those
' results for caret placement, hit testing, selection geometry, clipping, and
' horizontal scroll. Future versions extend this boundary for IME/dead keys,
' multiline layout, undo/redo, and grapheme-aware editing.

Public Function TextWidth( _
        ByVal Core As OxControlCore, ByVal TextLength As Long) As Single
    If Core.MeasuredWidth > 0 Then
        TextWidth = Core.MeasuredWidth
    Else
        TextWidth = ApproxTextX(Core, TextLength, TextLength)
    End If
End Function

Public Function CaretX( _
        ByVal Core As OxControlCore, ByVal Index As Long, ByVal TextLength As Long) As Single
    Dim Found As Boolean
    CaretX = CaretStopFromCsv(Core.CaretStopsMilliPtCsv, Index, TextLength, Found)
    If Not Found Then CaretX = ApproxTextX(Core, Index, TextLength)
End Function

Public Function SelectionX( _
        ByVal Core As OxControlCore, _
        ByVal StartIndex As Long, _
        ByVal TextLength As Long) As Single
    SelectionX = CaretX(Core, StartIndex, TextLength)
End Function

Public Function SelectionWidth( _
        ByVal Core As OxControlCore, _
        ByVal StartIndex As Long, _
        ByVal Length As Long, _
        ByVal TextLength As Long) As Single
    Dim LeftX As Single, RightX As Single
    LeftX = CaretX(Core, StartIndex, TextLength)
    RightX = CaretX(Core, StartIndex + Length, TextLength)
    SelectionWidth = RightX - LeftX
End Function

Public Function IndexFromX( _
        ByVal Core As OxControlCore, _
        ByVal X As Single, _
        ByVal TextLength As Long) As Long
    If X <= 0 Or TextLength <= 0 Then
        IndexFromX = 0
        Exit Function
    End If

    Dim Found As Boolean
    Dim PrevStop As Single
    PrevStop = CaretStopFromCsv(Core.CaretStopsMilliPtCsv, 0, TextLength, Found)
    If Not Found Then
        IndexFromX = ClampIndex(CLng(Fix((X / ApproxCharWidth(Core, TextLength)) + 0.5)), TextLength)
        Exit Function
    End If

    Dim I As Long, StopX As Single, MidPoint As Single
    For I = 1 To TextLength
        StopX = CaretStopFromCsv(Core.CaretStopsMilliPtCsv, I, TextLength, Found)
        If Not Found Then Exit For
        MidPoint = (PrevStop + StopX) / 2
        If X < MidPoint Then
            IndexFromX = I - 1
            Exit Function
        End If
        PrevStop = StopX
    Next I

    If Found Then
        IndexFromX = TextLength
    Else
        IndexFromX = ClampIndex(CLng(Fix((X / ApproxCharWidth(Core, TextLength)) + 0.5)), TextLength)
    End If
End Function

Public Function MaxScrollX( _
        ByVal Core As OxControlCore, _
        ByVal ViewWidth As Single, _
        ByVal TextLength As Long) As Single
    MaxScrollX = TextWidth(Core, TextLength) - ViewWidth
    If MaxScrollX < 0 Then MaxScrollX = 0
End Function

Public Function ScrollForCaret( _
        ByVal Core As OxControlCore, _
        ByVal CurrentScrollX As Single, _
        ByVal ViewWidth As Single, _
        ByVal CaretIndex As Long, _
        ByVal TextLength As Long) As Single
    Dim NewScroll As Single
    NewScroll = CurrentScrollX
    If NewScroll < 0 Then NewScroll = 0

    Dim MaxX As Single
    MaxX = MaxScrollX(Core, ViewWidth, TextLength)
    If NewScroll > MaxX Then NewScroll = MaxX

    If ViewWidth <= 1 Then
        ScrollForCaret = MaxX
        Exit Function
    End If

    Dim CaretPos As Single
    CaretPos = CaretX(Core, CaretIndex, TextLength)
    If CaretPos < NewScroll Then
        NewScroll = CaretPos
    ElseIf CaretPos > NewScroll + ViewWidth - 1 Then
        NewScroll = CaretPos - ViewWidth + 1
    End If

    If NewScroll < 0 Then NewScroll = 0
    If NewScroll > MaxX Then NewScroll = MaxX
    ScrollForCaret = NewScroll
End Function

Private Function ApproxTextX( _
        ByVal Core As OxControlCore, _
        ByVal Index As Long, _
        ByVal TextLength As Long) As Single
    ApproxTextX = ClampIndex(Index, TextLength) * ApproxCharWidth(Core, TextLength)
End Function

Private Function ApproxCharWidth( _
        ByVal Core As OxControlCore, ByVal TextLength As Long) As Single
    If TextLength > 0 And Core.MeasuredWidth > 0 Then
        ApproxCharWidth = Core.MeasuredWidth / TextLength
    Else
        ApproxCharWidth = Core.FontSize * 0.5
    End If
    If ApproxCharWidth < 1 Then ApproxCharWidth = 1
End Function

Private Function ClampIndex(ByVal Value As Long, ByVal TextLength As Long) As Long
    If Value < 0 Then
        ClampIndex = 0
    ElseIf Value > TextLength Then
        ClampIndex = TextLength
    Else
        ClampIndex = Value
    End If
End Function

Private Function CaretStopFromCsv( _
        ByVal Csv As String, _
        ByVal Index As Long, _
        ByVal TextLength As Long, _
        ByRef Found As Boolean) As Single
    Dim Target As Long
    Target = ClampIndex(Index, TextLength)
    Found = False
    If Len(Csv) = 0 Then Exit Function

    Dim Pos As Long, Current As Long, Token As String, Ch As String
    Token = ""
    For Pos = 1 To Len(Csv) + 1
        If Pos <= Len(Csv) Then
            Ch = Mid$(Csv, Pos, 1)
        Else
            Ch = ","
        End If

        If Ch = "," Then
            If Current = Target Then
                If Len(Token) > 0 Then
                    CaretStopFromCsv = CSng(CLng(Token)) / 1000
                    Found = True
                End If
                Exit Function
            End If
            Current = Current + 1
            Token = ""
        Else
            Token = Token & Ch
        End If
    Next Pos
End Function
