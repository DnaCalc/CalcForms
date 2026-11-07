Option Explicit
Private Function ReadHeld(ByVal C As Object, ByVal Member As String) As String
    On Error GoTo Failed
    ReadHeld = CStr(CallByName(C, Member, VbGet)) & "~0"
    Exit Function
Failed:
    ReadHeld = "~" & CStr(Err.Number)
End Function
Private Function LifeSnapshot(ByVal StepName As String, ByVal F As WorkbookGreeter, ByVal Loaded As Boolean, ByVal P As Object, ByVal O As Object, ByVal T As Object, ByVal C As Object, ByVal B As Object) As String
    Dim S As String
    S = "@" & StepName & "~~" & vbLf
    If Loaded Then S = "@" & StepName & "~" & CStr(F.Visible) & "~" & F.State() & vbLf
    S = S & "Prompt~Caption~" & ReadHeld(P, "Caption") & vbLf
    S = S & "Output~Caption~" & ReadHeld(O, "Caption") & vbLf
    S = S & "InputName~Text~" & ReadHeld(T, "Text") & vbLf
    S = S & "Loud~Value~" & ReadHeld(C, "Value") & vbLf
    S = S & "Greet~Caption~" & ReadHeld(B, "Caption") & vbLf
    LifeSnapshot = S
End Function
Public Function GreeterLifeRun(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload WorkbookGreeter
    Dim F As WorkbookGreeter, G As WorkbookGreeter
    Dim T As MSForms.TextBox, P As MSForms.Label, O As MSForms.Label
    Dim B As MSForms.CommandButton, C As MSForms.CheckBox
    Set F = WorkbookGreeter
    F.Zoom = Zoom
    F.Show vbModeless
    Set T = F.InputName
    Set P = F.Prompt
    Set O = F.Output
    Set B = F.Greet
    Set C = F.Loud
    T.Text = "Lin"
    C.Value = True
    O.Caption = "(modified)"
    Dim S As String
    S = LifeSnapshot("modified", F, True, P, O, T, C, B)
    F.Hide
    S = S & LifeSnapshot("hidden", F, True, P, O, T, C, B)
    F.Show vbModeless
    S = S & LifeSnapshot("shown", F, True, P, O, T, C, B)
    Unload F
    S = S & LifeSnapshot("unloaded-held-controls", F, False, P, O, T, C, B)
    Set G = WorkbookGreeter
    G.Show vbModeless
    S = S & LifeSnapshot("fresh-default", G, True, G.Prompt, G.Output, G.InputName, G.Loud, G.Greet)
    S = S & LifeSnapshot("old-controls-after-reload", F, False, P, O, T, C, B)
    GreeterLifeRun = S
    Exit Function
Failed:
    GreeterLifeRun = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
