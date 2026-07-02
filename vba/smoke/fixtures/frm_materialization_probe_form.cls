Option Explicit

' Test fixture for the W009 .frm/.frx materialization path. It accepts .frm text from the
' harness, asks OxFrmMaterializer to build the real VBA UserForm object model, and exposes
' deterministic readback surfaces for assertions.

Private mMaterializer As OxFrmMaterializer
Private mForm As UserForm

Public Sub BuildFromText(ByVal FrmText As String)
    Set mMaterializer = New OxFrmMaterializer
    Set mForm = mMaterializer.Materialize(FrmText)
End Sub

Public Sub Render()
    mForm.Render 96, 96
End Sub

Public Property Get ControlCount() As Long
    ControlCount = mForm.Controls.Count
End Property

Public Property Get MaterializationCatalog() As String
    MaterializationCatalog = mMaterializer.MaterializationCatalog
End Property

Public Property Get FrxReferences() As String
    FrxReferences = mMaterializer.FrxReferences
End Property

Public Property Get UnsupportedControls() As String
    UnsupportedControls = mMaterializer.UnsupportedControls
End Property

Public Property Get ImageMetadata() As String
    ImageMetadata = mMaterializer.ImageMetadata
End Property

Public Property Get AccessibilitySnapshot() As String
    Dim Service As OxAccessibilityService
    Set Service = New OxAccessibilityService
    AccessibilitySnapshot = Service.Snapshot(mForm, "")
End Property
