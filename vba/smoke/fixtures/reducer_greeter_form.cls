Option Explicit

' The W007 greeter as a VBA-reducer form-document (oxforms-ih6.7; test + demo infrastructure).
' Replaces the old oxforms-core materialized RuntimeForm: a TextBox (InputField), a default
' CommandButton (OkButton), and a Label (OutputLabel), driven entirely by OxReducer. The OK
' Click handler reads the typed text and sets the label -- the exact W007 demo behavior -- with
' no Rust reducer in the loop. Exposes the reducer facade the Rust OxRuntime drives
' (Dispatch/DispatchKey/DispatchChar/DispatchDrop/SetClipboardText/Render) plus the form-level
' lifecycle Perform* members.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mInput As TextBox
Private WithEvents mOk As CommandButton
Private mOutput As Label
Private mLog As String

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "greeter"
    mForm.Caption = "Greeter"
    mForm.Width = 220
    mForm.Height = 120

    Set mInput = mForm.Controls.Add("Forms.TextBox.1", "InputField")
    mInput.Left = 12
    mInput.Top = 12
    mInput.Width = 120
    mInput.Height = 18

    Set mOk = mForm.Controls.Add("Forms.CommandButton.1", "OkButton")
    mOk.Caption = "OK"
    mOk.Default = True
    mOk.Left = 144
    mOk.Top = 12
    mOk.Width = 60
    mOk.Height = 20

    Set mOutput = mForm.Controls.Add("Forms.Label.1", "OutputLabel")
    mOutput.Caption = "(idle)"
    mOutput.Left = 12
    mOutput.Top = 44
    mOutput.Width = 192
    mOutput.Height = 18

    Set mReducer = New OxReducer
    mReducer.Init mForm
    mForm.Render 96, 96
End Sub

' --- Reducer facade (driven by the Rust OxRuntime) ---
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

Public Sub Render()
    mForm.Render 96, 96
End Sub

Public Property Get FocusName() As String
    FocusName = mReducer.FocusName
End Property

Public Property Get OutputCaption() As String
    OutputCaption = mOutput.Caption
End Property

Public Property Get InputText() As String
    InputText = mInput.Text
End Property

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Public Sub ClearLog()
    mLog = ""
End Sub

' --- Form-level lifecycle dispatch surface (the OxRuntime invokes these for form events) ---
Public Sub PerformInitialize()
    UserForm_Initialize
End Sub
Public Sub PerformActivate()
    UserForm_Activate
End Sub
Public Sub PerformDeactivate()
    UserForm_Deactivate
End Sub
Public Sub PerformTerminate()
    UserForm_Terminate
End Sub
Public Function PerformQueryClose(ByVal CloseMode As Integer) As Integer
    Dim Cancel As ReturnInteger
    Set Cancel = New ReturnInteger
    Cancel.Value = 0
    UserForm_QueryClose Cancel, CloseMode
    PerformQueryClose = Cancel.Value
End Function

' --- The user-facing handlers ---
Private Sub mOk_Click()
    Append "OkButton_Click"
    mOutput.Caption = "Hello, " & mInput.Text
End Sub

Private Sub UserForm_Initialize()
    Append "UserForm_Initialize"
End Sub
Private Sub UserForm_Activate()
    Append "UserForm_Activate"
End Sub
Private Sub UserForm_Deactivate()
    Append "UserForm_Deactivate"
End Sub
Private Sub UserForm_Terminate()
    Append "UserForm_Terminate"
End Sub
' Veto a user/control-menu close (CloseMode 0); allow a code Unload (CloseMode 1).
Private Sub UserForm_QueryClose(ByVal Cancel As ReturnInteger, ByVal CloseMode As Integer)
    Append "UserForm_QueryClose;CloseMode=" & CloseMode
    If CloseMode = 0 Then Cancel.Value = -1
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
