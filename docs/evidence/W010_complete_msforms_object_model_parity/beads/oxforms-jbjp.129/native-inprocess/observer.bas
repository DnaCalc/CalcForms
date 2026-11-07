Option Explicit
Private Function ReadHeld(ByVal C As Object, ByVal Member As String) As String
    On Error GoTo Failed
    ReadHeld = CStr(CallByName(C, Member, VbGet)) & "~0"
    Exit Function
Failed:
    ReadHeld = "~" & CStr(Err.Number)
End Function
Public Function HeldReload(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload WorkbookGreeter
    Dim F As WorkbookGreeter, T As MSForms.TextBox, P As MSForms.Label
    Dim O As MSForms.Label, B As MSForms.CommandButton, C As MSForms.CheckBox
    Set F = WorkbookGreeter
    F.Zoom = Zoom
    Set T = F.InputName
    Set P = F.Prompt
    Set O = F.Output
    Set B = F.Greet
    Set C = F.Loud
    T.Text = "Lin"
    Unload F
    Dim S As String
    S = "InputName~unload~" & ReadHeld(T, "Text") & vbLf
    S = S & "Prompt~unload~" & ReadHeld(P, "Caption") & vbLf
    S = S & "Output~unload~" & ReadHeld(O, "Caption") & vbLf
    S = S & "Greet~unload~" & ReadHeld(B, "Caption") & vbLf
    S = S & "Loud~unload~" & ReadHeld(C, "Value") & vbLf
    ShowGreeter
    S = S & "InputName~reload~" & ReadHeld(T, "Text") & vbLf
    S = S & "Prompt~reload~" & ReadHeld(P, "Caption") & vbLf
    S = S & "Output~reload~" & ReadHeld(O, "Caption") & vbLf
    S = S & "Greet~reload~" & ReadHeld(B, "Caption") & vbLf
    S = S & "Loud~reload~" & ReadHeld(C, "Value") & vbLf
    HeldReload = S
    Exit Function
Failed:
    HeldReload = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
