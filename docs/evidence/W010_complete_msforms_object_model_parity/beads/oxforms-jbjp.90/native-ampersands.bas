Option Explicit
Public Function Run6Ampersands(ByVal FormName As String) As String
    On Error GoTo Failed
    Dim S As String
    If FormName = "LayoutCommon" Then
        With LayoutCommon
            .Prompt.Caption = "A&B && C&"
            .Greet.Caption = "A&B && C&"
            .InputName.Text = "A&B && C&"
            .InputName.SelStart = 1
            .InputName.SelLength = 1
            S = "label=" & .Prompt.Caption & ";button=" & .Greet.Caption & ";accelerator=" & .Greet.Accelerator & ";text=" & .InputName.Text & ";selected=" & .InputName.SelText
            .Repaint
        End With
    Else
        With LayoutSelection
            .Unchecked.Caption = "A&B && C&"
            .OptionOne.Caption = "A&B && C&"
            .ToggleOff.Caption = "A&B && C&"
            .Choices.Clear
            .Choices.AddItem "A&B"
            .Choices.AddItem "A&&B"
            .Choices.AddItem "tail&"
            .Choices.ListIndex = 1
            .Dropdown.Clear
            .Dropdown.AddItem "A&B"
            .Dropdown.AddItem "A&&B"
            .Dropdown.AddItem "tail&"
            .Dropdown.ListIndex = 1
            S = "check=" & .Unchecked.Caption & ";accelerator=" & .Unchecked.Accelerator & ";list=" & .Choices.List(0) & "|" & .Choices.List(1) & "|" & .Choices.List(2) & ";combo=" & .Dropdown.Text
            .Repaint
        End With
    End If
    Run6Ampersands = S
    Exit Function
Failed:
    Run6Ampersands = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
