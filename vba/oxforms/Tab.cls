Option Explicit

' Representative MSForms Tab object owned by a TabStrip Tabs collection.

Private mOwner As TabStrip
Private mIndex As Long
Private mCaption As String

Public Sub Init(ByVal Owner As TabStrip, ByVal Index As Long, ByVal Caption As String)
    Set mOwner = Owner
    mIndex = Index
    mCaption = Caption
End Sub

Public Property Get Index() As Long
    Index = mIndex
End Property

Public Sub SetIndex(ByVal Value As Long)
    mIndex = Value
End Sub

Public Property Get Caption() As String
    Caption = mCaption
End Property
Public Property Let Caption(ByVal Value As String)
    If mCaption <> Value Then
        mCaption = Value
        mOwner.NotifyTabChanged
    End If
End Property

Public Property Get Selected() As Boolean
    Selected = (mOwner.Value = mIndex)
End Property
Public Property Let Selected(ByVal Value As Boolean)
    If Value Then mOwner.Value = mIndex
End Property
