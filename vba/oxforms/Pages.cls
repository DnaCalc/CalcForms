Option Explicit

' Representative MSForms Pages collection for MultiPage.

Private mOwner As MultiPage
Private mItems As Collection

Private Sub Class_Initialize()
    Set mItems = New Collection
End Sub

Public Sub Init(ByVal Owner As MultiPage)
    Set mOwner = Owner
End Sub

Public Function Add(ByVal Caption As String) As Page
    Dim P As Page
    Set P = New Page
    P.Init mOwner, mItems.Count, Caption
    mItems.Add P
    mOwner.RegisterPage P
    Set Add = P
End Function

Public Sub Clear()
    Set mItems = New Collection
    mOwner.NotifyPagesCleared
End Sub

Public Property Get Count() As Long
    Count = mItems.Count
End Property

Public Function Item(ByVal Index As Long) As Page
    Set Item = mItems.Item(Index + 1)
End Function

Public Function CaptionAt(ByVal Index As Long) As String
    If Index < 0 Or Index >= mItems.Count Then Exit Function
    CaptionAt = Item(Index).Caption
End Function

Public Function JoinedCaptions(ByVal Separator As String) As String
    Dim Text As String
    Dim I As Long
    For I = 0 To mItems.Count - 1
        If Len(Text) > 0 Then Text = Text & Separator
        Text = Text & CaptionAt(I)
    Next I
    JoinedCaptions = Text
End Function
