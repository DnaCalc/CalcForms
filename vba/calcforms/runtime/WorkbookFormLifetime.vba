Private CalcFormsHostLoaded As Boolean
Private CalcFormsHostVisible As Boolean
Private CalcFormsHostClosing As Boolean
Private CalcFormsHostActive As Boolean

Private Sub Class_Initialize()
    Set CalcFormsHostForm = Nothing
    Set CalcFormsHostReducer = Nothing
    CalcFormsHostLoad
End Sub

Private Sub CalcFormsHostLoad()
    If CalcFormsHostLoaded Then Exit Sub
    CalcFormsHostLoaded = True
    CalcFormsHostBuild
    CalcFormsHostPerformInitialize
End Sub

Public Sub Show(Optional ByVal Modal As Long = 1)
    If Modal <> 0 Then Err.Raise 5, "CalcForms", "Modal form pumps are not implemented"
    CalcFormsHostLoad
    If CalcFormsHostVisible Then Exit Sub
    CalcFormsHostVisible = True
End Sub

Public Sub Hide()
    If Not CalcFormsHostVisible Then Exit Sub
    CalcFormsHostVisible = False
    CalcFormsHostPerformDeactivate
End Sub

Public Property Get Visible() As Boolean
    Visible = CalcFormsHostVisible
End Property

Private Property Get CalcFormsHostIsLoaded() As Boolean
    CalcFormsHostIsLoaded = CalcFormsHostLoaded
End Property

Private Function CalcFormsHostUnload(ByVal CloseMode As Integer) As Boolean
    If Not CalcFormsHostLoaded Or CalcFormsHostClosing Then Exit Function
    CalcFormsHostClosing = True
    If CalcFormsHostPerformQueryClose(CloseMode) <> 0 Then
        CalcFormsHostClosing = False
        Exit Function
    End If
    Hide
    CalcFormsHostLoaded = False
    If Me Is %FORM_NAME% Then Set %FORM_NAME% = Nothing
    CalcFormsHostClosing = False
    CalcFormsHostUnload = True
End Function

Private Sub Class_Terminate()
    CalcFormsHostPerformTerminate
End Sub
