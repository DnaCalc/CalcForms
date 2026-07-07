Option Explicit

' Forms 2.0 Controls collection. A UserForm owns one of these and exposes it as
' .Controls; callers create controls the MSForms way, by ProgID:
'
'     form.Controls.Add "Forms.Label.1", "Caption1"
'
' Add creates the control for the ProgID, asks the owning form to register it (bind the
' invalidation host + assign the stable NodeId), tracks it by Name, and returns it. Remove
' detaches the control and marks the form's structure dirty so the next render rebuilds the
' root child list. The form's render loop iterates this collection (Count / Item). This is the
' MSForms-shaped public surface; the ProgID->class factory (OxCreateControl) is OxForms-internal
' machinery.

Private mOwner As IOxControlContainer
Private mItems As Collection

Private Sub Class_Initialize()
    Set mItems = New Collection
End Sub

' Wire the collection to its owning container (called once by UserForm/Frame.Class_Initialize).
Public Sub Bind(ByVal Owner As IOxControlContainer)
    Set mOwner = Owner
End Sub

' Forms 2.0 Controls.Add: create the control for the ProgID ("Forms.Label.1", etc.),
' register it on the owning form, track it by Name, and return it.
Public Function Add(ByVal ProgId As String, ByVal Name As String) As IOxControl
    Dim Control As IOxControl
    Set Control = OxCreateControl(ProgId, Name)
    ' Unknown ProgID yields Nothing: return it cleanly rather than registering / tracking a
    ' Nothing (which would crash in RegisterControl). (Real MSForms raises on a bad ProgID;
    ' a precise Err.Raise is future work once OxVba error handling is proven.)
    If Control Is Nothing Then Exit Function
    mOwner.RegisterControl Control
    mItems.Add Control, Name
    Set Add = Control
End Function

' Forms 2.0 Controls.Remove by control name. The current representative slice removes by name;
' index removal and exact Err.Raise behavior for missing keys land with broader object-model
' parity. This method is deliberately structural: the owning UserForm detaches the control,
' invalidates interaction caches, and forces the next render to rebuild the retained root.
Public Sub Remove(ByVal Name As String)
    Dim I As Long
    Dim Control As IOxControl
    For I = 1 To mItems.Count
        Set Control = mItems.Item(I)
        If Control.Core.Name = Name Then
            mOwner.UnregisterControl Control
            mItems.Remove I
            Exit Sub
        End If
    Next I
End Sub

Public Property Get Count() As Long
    Count = mItems.Count
End Property

' Item by 1-based index or by control Name (MSForms Controls supports both). Name lookup resolves
' against live Core.Name values first, then falls back to the original Collection key/index path.
Public Function Item(ByVal IndexOrName As Variant) As IOxControl
    Dim ByName As IOxControl
    Set ByName = ItemByName(CStr(IndexOrName))
    If Not ByName Is Nothing Then
        Set Item = ByName
        Exit Function
    End If

    Set Item = mItems.Item(IndexOrName)
End Function

' Name lookup scans live Core.Name values instead of the collection's original Add key, so a
' representative runtime name mutation updates lookup and removal policy through the same
' object-model truth.
Public Function ItemByName(ByVal Name As String) As IOxControl
    Dim I As Long
    Dim Control As IOxControl
    For I = 1 To mItems.Count
        Set Control = mItems.Item(I)
        If Control.Core.Name = Name Then
            Set ItemByName = Control
            Exit Function
        End If
    Next I
End Function

Public Function Contains(ByVal Name As String) As Boolean
    Dim Found As IOxControl
    Set Found = ItemByName(Name)
    Contains = Not Found Is Nothing
End Function
