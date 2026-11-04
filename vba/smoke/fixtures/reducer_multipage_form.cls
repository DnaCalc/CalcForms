Option Explicit

' W009 MultiPage fixture: proves Pages/Page collection state, selected page,
' page-local child controls, Change order, focus scope, and accessibility through
' the normal OxReducer route.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mPages As MultiPage
Private WithEvents mAlphaField As TextBox
Private WithEvents mBetaField As TextBox
Private mLog As String

Private Sub Class_Initialize()
    Set mForm = Nothing
    Set mReducer = Nothing
    Set mPages = Nothing
    Set mAlphaField = Nothing
    Set mBetaField = Nothing
End Sub

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "multipageform"
    mForm.Width = 280
    mForm.Height = 150

    Set mPages = mForm.Controls.Add("Forms.MultiPage.1", "WizardPages")
    mPages.Left = 20
    mPages.Top = 20
    mPages.Width = 210
    mPages.Height = 94
    mPages.Core.TabIndex = 0

    Dim Alpha As Page
    Set Alpha = mPages.Pages.Add("Alpha")
    Set mAlphaField = Alpha.Controls.Add("Forms.TextBox.1", "AlphaField")
    mAlphaField.Left = 10
    mAlphaField.Top = 10
    mAlphaField.Width = 80
    mAlphaField.Height = 20
    mAlphaField.Text = "alpha"
    mAlphaField.Core.TabIndex = 0

    Dim Beta As Page
    Set Beta = mPages.Pages.Add("Beta")
    Set mBetaField = Beta.Controls.Add("Forms.TextBox.1", "BetaField")
    mBetaField.Left = 110
    mBetaField.Top = 10
    mBetaField.Width = 80
    mBetaField.Height = 20
    mBetaField.Text = "beta"
    mBetaField.Core.TabIndex = 0

    mPages.Value = 0

    Set mReducer = New OxReducer
    mReducer.Init mForm
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

Public Property Get PageValue() As Long
    PageValue = mPages.Value
End Property

Public Property Get PageCaption() As String
    PageCaption = mPages.SelectedCaption
End Property

Public Property Get PageCount() As Long
    PageCount = mPages.Pages.Count
End Property

Public Property Get FirstCaption() As String
    FirstCaption = mPages.Pages.Item(0).Caption
End Property

Public Property Get SecondSelected() As Boolean
    SecondSelected = mPages.Pages.Item(1).Selected
End Property

Public Property Get AlphaText() As String
    AlphaText = mAlphaField.Text
End Property

Public Property Get BetaText() As String
    BetaText = mBetaField.Text
End Property

Public Property Get MultiPageDiagnostics() As String
    MultiPageDiagnostics = mPages.Diagnostics
End Property

Public Property Get SelectedPageDiagnostics() As String
    SelectedPageDiagnostics = mPages.SelectedPage.Diagnostics
End Property

Public Property Get InteractionIndexSummary() As String
    InteractionIndexSummary = mReducer.InteractionIndexSummary
End Property

Public Property Get AccessibilitySnapshot() As String
    AccessibilitySnapshot = mReducer.AccessibilitySnapshot
End Property

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Private Sub mPages_Enter()
    Append "MultiPage.Enter"
End Sub
Private Sub mPages_Exit(ByVal Cancel As ReturnBoolean)
    Append "MultiPage.Exit"
End Sub
Private Sub mPages_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "MultiPage.MouseDown:" & CStr(CLng(X)) & "," & CStr(CLng(Y))
End Sub
Private Sub mPages_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "MultiPage.MouseUp"
End Sub
Private Sub mPages_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "MultiPage.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mPages_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "MultiPage.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mPages_Change()
    Append "MultiPage.Change=" & CStr(mPages.Value) & ":" & mPages.SelectedCaption
End Sub

Private Sub mAlphaField_Enter()
    Append "AlphaField.Enter"
End Sub
Private Sub mAlphaField_Change()
    Append "AlphaField.Change=" & mAlphaField.Text
End Sub
Private Sub mBetaField_Enter()
    Append "BetaField.Enter"
End Sub
Private Sub mBetaField_Change()
    Append "BetaField.Change=" & mBetaField.Text
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
End Sub
