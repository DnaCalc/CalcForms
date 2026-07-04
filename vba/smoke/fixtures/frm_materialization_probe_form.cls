Option Explicit

' Test fixture for the W009 .frm/.frx materialization path. It accepts .frm text from the
' harness, asks OxFrmMaterializer to build the real VBA UserForm object model, and exposes
' deterministic readback surfaces for assertions.

Private mMaterializer As OxFrmMaterializer
Private mForm As UserForm
Private mReducer As OxReducer
Private mInput As TextBox

Public Sub BuildFromText(ByVal FrmText As String)
    Set mMaterializer = New OxFrmMaterializer
    Set mForm = mMaterializer.Materialize(FrmText)
    Set mReducer = New OxReducer
    mReducer.Init mForm
    Set mInput = mForm.ControlByName("InputField")
    mForm.Render 96, 96
    FocusInputField
End Sub

Public Sub Render()
    mForm.Render 96, 96
End Sub

Public Function Dispatch( _
        ByVal Kind As String, ByVal X As Long, ByVal Y As Long, _
        ByVal Button As Integer, ByVal Shift As Integer) As String
    Dispatch = mReducer.Dispatch(Kind, X, Y, Button, Shift)
End Function

Public Function DispatchKey(ByVal Kind As String, ByVal KeyCode As Integer, ByVal Shift As Integer) As String
    DispatchKey = mReducer.DispatchKey(Kind, KeyCode, Shift)
End Function

Public Function DispatchChar(ByVal Text As String) As String
    DispatchChar = mReducer.DispatchChar(Text)
End Function

Public Function DispatchDrop(ByVal Text As String) As String
    DispatchDrop = mReducer.DispatchDrop(Text)
End Function

Public Sub SetClipboardText(ByVal Text As String)
    mReducer.SetClipboardText Text
End Sub

Public Property Get ControlCount() As Long
    ControlCount = mForm.Controls.Count
End Property

Public Property Get FocusName() As String
    FocusName = mReducer.FocusName
End Property

Public Property Get InputText() As String
    InputText = mInput.Text
End Property

Public Property Get InputValue() As String
    InputValue = mInput.Value
End Property

Public Property Get InputSelStart() As Long
    InputSelStart = mInput.SelStart
End Property

Public Property Get InputSelLength() As Long
    InputSelLength = mInput.SelLength
End Property

Public Property Get InputSelText() As String
    InputSelText = mInput.SelText
End Property

Public Property Get TextBoxDiagnostics() As String
    Dim Control As IOxControl
    Set Control = mInput
    TextBoxDiagnostics = _
        "text=" & mInput.Text & _
        ";value=" & mInput.Value & _
        ";sel_start=" & CStr(mInput.SelStart) & _
        ";sel_length=" & CStr(mInput.SelLength) & _
        ";sel_text=" & mInput.SelText & _
        ";hide_selection=" & CStr(mInput.HideSelection) & _
        ";capabilities=" & mInput.Core.CapabilityDescriptor & _
        ";accessibility=" & Control.AccessibilityRole & "/" & Control.AccessibilityPatterns
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
    AccessibilitySnapshot = Service.Snapshot(mForm, FocusName)
End Property

Public Function PerformQueryClose(ByVal CloseMode As Integer) As Integer
    PerformQueryClose = 0
End Function

Private Sub FocusInputField()
    Dim X As Long
    Dim Y As Long
    X = CLng(mInput.Core.Left + mInput.Core.Width - 4)
    Y = CLng(mInput.Core.Top + (mInput.Core.Height / 2))
    mReducer.Dispatch "mousedown", X, Y, 1, 0
    mReducer.Dispatch "mouseup", X, Y, 1, 0
    mInput.SelStart = Len(mInput.Text)
    mInput.SelLength = 0
    mForm.Render 96, 96
End Sub
