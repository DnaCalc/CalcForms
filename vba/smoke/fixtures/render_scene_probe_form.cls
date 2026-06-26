Option Explicit

' W007 render proving fixture (oxforms-rq5 step 4). Test infrastructure, not the
' OxForms library. It exercises the self-render path the way the runtime will: build
' a small UserForm + controls through the object model, ask the form to paint itself
' into an OxSceneBuilder, and submit the one batched ScenePatch across the injected
' OxForms.Surface boundary. The Rust side then proves the retained scene rasterizes
' to the intended pixels.

Private mResultToken As String

Public Sub Run()
    Dim DemoForm As UserForm
    Set DemoForm = New UserForm
    DemoForm.Name = "demo"
    DemoForm.Width = 200
    DemoForm.Height = 120

    Dim InputField As TextBox
    Set InputField = DemoForm.Controls.Add("Forms.TextBox.1", "InputField")
    InputField.Left = 12
    InputField.Top = 12
    InputField.Width = 120
    InputField.Height = 18
    InputField.Text = "Hi"

    Dim OkButton As CommandButton
    Set OkButton = DemoForm.Controls.Add("Forms.CommandButton.1", "OkButton")
    OkButton.Left = 140
    OkButton.Top = 12
    OkButton.Width = 48
    OkButton.Height = 20
    OkButton.Caption = "OK"

    Dim OutputLabel As Label
    Set OutputLabel = DemoForm.Controls.Add("Forms.Label.1", "OutputLabel")
    OutputLabel.Left = 12
    OutputLabel.Top = 44
    OutputLabel.Width = 176
    OutputLabel.Height = 18
    OutputLabel.Caption = "Ready"

    ' One BeginScene + one batched SubmitPatch crossing for the whole form.
    Dim Surface As Object
    Set Surface = CreateObject("OxForms.Surface")
    Dim BaseToken As String
    BaseToken = Surface.BeginScene(200, 120, 96, 96)

    Dim Builder As OxSceneBuilder
    Set Builder = New OxSceneBuilder
    Dim PatchJson As String
    PatchJson = DemoForm.BuildScenePatch(BaseToken, Builder, Surface, 96, 96)

    mResultToken = Surface.SubmitPatch(PatchJson)
End Sub

Public Property Get ResultToken() As String
    ResultToken = mResultToken
End Property
