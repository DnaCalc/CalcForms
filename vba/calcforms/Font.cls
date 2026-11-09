Option Explicit

' FM20 Font (the stdole font shape every MSForms control returns from its Font property):
' Name, Size (Currency), Bold, Italic, Underline, Strikethrough, Weight, Charset. A control
' owns one; a write that changes a value tells the owner. Writing the value a property already
' holds is quiet (native: no layout effect). The default is the MSForms default, Tahoma 8.25.

Private mName As String
Private mSize As Currency
Private mBold As Boolean
Private mItalic As Boolean
Private mUnderline As Boolean
Private mStrikethrough As Boolean
Private mWeight As Integer
Private mCharset As Integer
Private mOwner As OxControlCore

Private Sub Class_Initialize()
    Set mOwner = Nothing
    mName = "Tahoma"
    mSize = 8.25
    mBold = False
    mItalic = False
    mUnderline = False
    mStrikethrough = False
    mWeight = 400
    mCharset = 1
End Sub

' Called by the owning control's core when it creates the control's Font.
Friend Sub Attach(ByVal Owner As OxControlCore)
    Set mOwner = Owner
End Sub

' Bring the object up to date with the core's font state without telling the owner (the core
' keeps the name and size; the control may also have been sized through Core.FontSize).
Friend Sub Sync(ByVal NewName As String, ByVal NewSize As Single)
    mName = NewName
    mSize = NewSize
End Sub

Public Property Get Name() As String
    Name = mName
End Property
Public Property Let Name(ByVal Value As String)
    If mName = Value Then Exit Property
    mName = Value
    Changed
End Property

Public Property Get Size() As Currency
    Size = mSize
End Property
Public Property Let Size(ByVal Value As Currency)
    If mSize = Value Then Exit Property
    mSize = Value
    Changed
End Property

Public Property Get Bold() As Boolean
    Bold = mBold
End Property
Public Property Let Bold(ByVal Value As Boolean)
    If mBold = Value Then Exit Property
    mBold = Value
    If Value Then mWeight = 700 Else mWeight = 400
    Changed
End Property

Public Property Get Italic() As Boolean
    Italic = mItalic
End Property
Public Property Let Italic(ByVal Value As Boolean)
    If mItalic = Value Then Exit Property
    mItalic = Value
    Changed
End Property

Public Property Get Underline() As Boolean
    Underline = mUnderline
End Property
Public Property Let Underline(ByVal Value As Boolean)
    If mUnderline = Value Then Exit Property
    mUnderline = Value
    Changed
End Property

Public Property Get Strikethrough() As Boolean
    Strikethrough = mStrikethrough
End Property
Public Property Let Strikethrough(ByVal Value As Boolean)
    If mStrikethrough = Value Then Exit Property
    mStrikethrough = Value
    Changed
End Property

Public Property Get Weight() As Integer
    Weight = mWeight
End Property
Public Property Let Weight(ByVal Value As Integer)
    If mWeight = Value Then Exit Property
    mWeight = Value
    mBold = (Value >= 700)
    Changed
End Property

Public Property Get Charset() As Integer
    Charset = mCharset
End Property
Public Property Let Charset(ByVal Value As Integer)
    If mCharset = Value Then Exit Property
    mCharset = Value
    Changed
End Property

' Copy every value from another Font (Set Control.Font = Other) and tell the owner once.
Friend Sub Assign(ByVal Source As Font)
    mName = Source.Name
    mSize = Source.Size
    mBold = Source.Bold
    mItalic = Source.Italic
    mUnderline = Source.Underline
    mStrikethrough = Source.Strikethrough
    mWeight = Source.Weight
    mCharset = Source.Charset
    Changed
End Sub

Private Sub Changed()
    If Not mOwner Is Nothing Then mOwner.NoteFontChanged Me
End Sub
