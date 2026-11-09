Option Explicit
' Shared by the native capture (a standard module in Excel) and the runtime test (a class body):
' one interpreter, so a script line produces the same text on both sides.
'   add <ProgId> <Name> [<Container>]   container: a control name, or <MultiPage>#<page>
'   get <Name> <Path>                   path: Prop or Font.Prop
'   let <Name> <Path> <T> <Literal>     T: d s l i b t n e c y (Double Single Long Integer Boolean Text Null Empty Currency Byte)
'   snap <Path> <Name> <Name> ...       one result with Name=value; for each name
'   remove <Name>
'   move <Name> <a> <b> <c> <d>         "_" leaves an argument out
'   copyfont <ToName> <FromName>        Set To.Font = From.Font
Private Reg As Collection

Private Function Describe(ByVal X As Variant) As String
    Dim T As String
    If IsNull(X) Then
        Describe = "Null"
        Exit Function
    End If
    If IsEmpty(X) Then
        Describe = "Empty"
        Exit Function
    End If
    T = TypeName(X)
    Select Case T
        Case "Single", "Double", "Currency"
            Describe = T & "=" & CStr(CLng(CDbl(X) * 1000)) & "m"
        Case "String"
            Describe = "String=" & X
        Case "Boolean"
            If X Then Describe = "Boolean=True" Else Describe = "Boolean=False"
        Case Else
            Describe = T & "=" & CStr(X)
    End Select
End Function

Private Function MakeValue(ByVal T As String, ByVal Lit As String) As Variant
    Select Case T
        Case "d": MakeValue = CDbl(Val(Lit))
        Case "s": MakeValue = CSng(Val(Lit))
        Case "l": MakeValue = CLng(Val(Lit))
        Case "i": MakeValue = CInt(Val(Lit))
        Case "y": MakeValue = CByte(Val(Lit))
        Case "c": MakeValue = CCur(Val(Lit))
        Case "b": MakeValue = CBool(Lit = "1")
        Case "t": MakeValue = Lit
        Case "n": MakeValue = Null
        Case "e": MakeValue = Empty
    End Select
End Function

Private Function Target(ByVal Name As String, ByVal Path As String) As Object
    Dim Obj As Object
    Set Obj = Reg.Item(Name)
    If Left(Path, 5) = "Font." Then Set Obj = CallByName(Obj, "Font", VbGet)
    Set Target = Obj
End Function

Private Function Leaf(ByVal Path As String) As String
    If Left(Path, 5) = "Font." Then Leaf = Mid(Path, 6) Else Leaf = Path
End Function

Private Function ReadProp(ByVal Name As String, ByVal Path As String) As String
    Dim X As Variant
    On Error Resume Next
    X = CallByName(Target(Name, Path), Leaf(Path), VbGet)
    If Err.Number <> 0 Then
        ReadProp = "err" & CStr(Err.Number)
        Err.Clear
    Else
        ReadProp = Describe(X)
    End If
End Function

Public Function RunScript(ByVal F As Object, ByVal Script As String) As String
    Dim Lines() As String, W() As String, I As Long, J As Long, Out As String, R As String
    Dim Obj As Object, Cont As Object, X As Variant
    Set Reg = New Collection
    Reg.Add F, "Form"
    Lines = Split(Script, vbLf)
    For I = 0 To UBound(Lines)
        If Len(Lines(I)) > 0 Then
            W = Split(Lines(I), " ")
            R = "ok"
            On Error Resume Next
            Select Case W(0)
                Case "add"
                    If UBound(W) >= 3 Then
                        If InStr(W(3), "#") > 0 Then
                            Set Cont = Reg.Item(Left(W(3), InStr(W(3), "#") - 1))
                            Set Cont = CallByName(Cont, "Pages", VbGet)
                            Set Cont = CallByName(Cont, "Item", VbMethod, CLng(Mid(W(3), InStr(W(3), "#") + 1)))
                        Else
                            Set Cont = Reg.Item(W(3))
                        End If
                    Else
                        Set Cont = F
                    End If
                    Set Obj = CallByName(CallByName(Cont, "Controls", VbGet), "Add", VbMethod, W(1), W(2))
                    If Err.Number = 0 Then Reg.Add Obj, W(2)
                Case "get"
                    R = ReadProp(W(1), W(2))
                Case "let"
                    X = MakeValue(W(3), W(4))
                    CallByName Target(W(1), W(2)), Leaf(W(2)), VbLet, X
                Case "snap"
                    R = ""
                    For J = 2 To UBound(W)
                        R = R & W(J) & "=" & ReadProp(W(J), W(1)) & ";"
                    Next J
                Case "remove"
                    CallByName CallByName(F, "Controls", VbGet), "Remove", VbMethod, W(1)
                    If Err.Number = 0 Then Reg.Remove W(1)
                Case "move"
                    Set Obj = Reg.Item(W(1))
                    If W(2) = "_" Then
                        CallByName Obj, "Move", VbMethod
                    End If
                Case "copyfont"
                    Set Obj = Reg.Item(W(1))
                    CallByName Obj, "Font", VbSet, CallByName(Reg.Item(W(2)), "Font", VbGet)
            End Select
            If Err.Number <> 0 And R = "ok" Then R = "err" & CStr(Err.Number)
            Err.Clear
            On Error GoTo 0
            Out = Out & Lines(I) & " => " & R & vbLf
        End If
    Next I
    RunScript = Out
End Function
