Option Explicit

' Forms 2.0 Controls collection. A UserForm owns one of these and exposes it as
' .Controls; callers create controls the MSForms way, by ProgID:
'
'     form.Controls.Add "Forms.Label.1", "Caption1"
'
' Add creates the control for the ProgID, asks the owning form to register it (bind the
' invalidation host + assign the stable NodeId), tracks it by Name, and returns it. The
' form's render loop iterates this collection (Count / Item). This is the MSForms-shaped
' public surface; the ProgID->class factory (OxCreateControl) is OxForms-internal machinery.

Private mForm As UserForm
Private mItems As Collection

Private Sub Class_Initialize()
    Set mItems = New Collection
End Sub

' Wire the collection to its owning form (called once by UserForm.Class_Initialize).
Public Sub Bind(ByVal Form As UserForm)
    Set mForm = Form
End Sub

' Forms 2.0 Controls.Add: create the control for the ProgID ("Forms.Label.1", etc.),
' register it on the owning form, track it by Name, and return it.
Public Function Add(ByVal ProgId As String, ByVal Name As String) As IOxControl
    Dim Control As IOxControl
    Set Control = OxCreateControl(ProgId, Name)
    ' Unknown ProgID, or one recognized but not yet implemented (e.g. "Forms.CheckBox.1"
    ' until CheckBox.cls lands), yields Nothing: return it cleanly rather than registering /
    ' tracking a Nothing (which would crash in RegisterControl). (Real MSForms raises on a
    ' bad ProgID; a precise Err.Raise is future work once OxVba error handling is proven.)
    If Control Is Nothing Then Exit Function
    mForm.RegisterControl Control
    mItems.Add Control, Name
    Set Add = Control
End Function

Public Property Get Count() As Long
    Count = mItems.Count
End Property

' Item by 1-based index or by control Name (MSForms Controls supports both).
Public Function Item(ByVal IndexOrName As Variant) As IOxControl
    Set Item = mItems.Item(IndexOrName)
End Function
