Option Explicit
Private mParityEvents As String
Private mParityFailure As String
Private Sub UserForm_Initialize()
    Choices.AddItem "Alpha"
    Choices.AddItem "Beta"
    Choices.AddItem "Gamma"
    Choices.ListIndex = 1
    Dropdown.AddItem "Alpha"
    Dropdown.AddItem "Beta"
    Dropdown.AddItem "Gamma"
    Dropdown.ListIndex = 1
End Sub
Public Function ParityMeasurements() As String
    On Error GoTo Failed
    Dim S As String
    S = S & Parity_Unchecked()
    S = S & Parity_Checked()
    S = S & Parity_OptionOne()
    S = S & Parity_OptionTwo()
    S = S & Parity_ToggleOff()
    S = S & Parity_ToggleOn()
    S = S & Parity_Choices()
    S = S & Parity_Dropdown()
    ParityMeasurements = S
    Exit Function
Failed:
    ParityMeasurements = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function

Private Function Parity_Unchecked() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = Unchecked.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "Unchecked~value_changes~initial~" & CStr(Unchecked.Value) & vbLf
    S = S & "Unchecked~event_order~initial~" & mParityEvents & vbLf
    Unchecked.Value = Not CBool(Original)
    S = S & "Unchecked~value_changes~set~" & CStr(Unchecked.Value) & vbLf
    S = S & "Unchecked~event_order~set~" & mParityEvents & vbLf
    Unchecked.Value = Not CBool(Original)
    S = S & "Unchecked~value_changes~repeat~" & CStr(Unchecked.Value) & vbLf
    S = S & "Unchecked~event_order~repeat~" & mParityEvents & vbLf
    Unchecked.Value = Original
    S = S & "Unchecked~value_changes~restore~" & CStr(Unchecked.Value) & vbLf
    S = S & "Unchecked~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_Unchecked = S
    Exit Function
Failed:
    Parity_Unchecked = "CALCFORMS_NATIVE_ERROR:Unchecked:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_Checked() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = Checked.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "Checked~value_changes~initial~" & CStr(Checked.Value) & vbLf
    S = S & "Checked~event_order~initial~" & mParityEvents & vbLf
    Checked.Value = Not CBool(Original)
    S = S & "Checked~value_changes~set~" & CStr(Checked.Value) & vbLf
    S = S & "Checked~event_order~set~" & mParityEvents & vbLf
    Checked.Value = Not CBool(Original)
    S = S & "Checked~value_changes~repeat~" & CStr(Checked.Value) & vbLf
    S = S & "Checked~event_order~repeat~" & mParityEvents & vbLf
    Checked.Value = Original
    S = S & "Checked~value_changes~restore~" & CStr(Checked.Value) & vbLf
    S = S & "Checked~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_Checked = S
    Exit Function
Failed:
    Parity_Checked = "CALCFORMS_NATIVE_ERROR:Checked:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_OptionOne() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = OptionOne.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "OptionOne~value_changes~initial~" & CStr(OptionOne.Value) & vbLf
    S = S & "OptionOne~event_order~initial~" & mParityEvents & vbLf
    OptionOne.Value = Not CBool(Original)
    S = S & "OptionOne~value_changes~set~" & CStr(OptionOne.Value) & vbLf
    S = S & "OptionOne~event_order~set~" & mParityEvents & vbLf
    OptionOne.Value = Not CBool(Original)
    S = S & "OptionOne~value_changes~repeat~" & CStr(OptionOne.Value) & vbLf
    S = S & "OptionOne~event_order~repeat~" & mParityEvents & vbLf
    OptionOne.Value = Original
    S = S & "OptionOne~value_changes~restore~" & CStr(OptionOne.Value) & vbLf
    S = S & "OptionOne~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_OptionOne = S
    Exit Function
Failed:
    Parity_OptionOne = "CALCFORMS_NATIVE_ERROR:OptionOne:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_OptionTwo() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = OptionTwo.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "OptionTwo~value_changes~initial~" & CStr(OptionTwo.Value) & vbLf
    S = S & "OptionTwo~event_order~initial~" & mParityEvents & vbLf
    OptionTwo.Value = Not CBool(Original)
    S = S & "OptionTwo~value_changes~set~" & CStr(OptionTwo.Value) & vbLf
    S = S & "OptionTwo~event_order~set~" & mParityEvents & vbLf
    OptionTwo.Value = Not CBool(Original)
    S = S & "OptionTwo~value_changes~repeat~" & CStr(OptionTwo.Value) & vbLf
    S = S & "OptionTwo~event_order~repeat~" & mParityEvents & vbLf
    OptionTwo.Value = Original
    S = S & "OptionTwo~value_changes~restore~" & CStr(OptionTwo.Value) & vbLf
    S = S & "OptionTwo~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_OptionTwo = S
    Exit Function
Failed:
    Parity_OptionTwo = "CALCFORMS_NATIVE_ERROR:OptionTwo:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_ToggleOff() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = ToggleOff.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "ToggleOff~value_changes~initial~" & CStr(ToggleOff.Value) & vbLf
    S = S & "ToggleOff~event_order~initial~" & mParityEvents & vbLf
    ToggleOff.Value = Not CBool(Original)
    S = S & "ToggleOff~value_changes~set~" & CStr(ToggleOff.Value) & vbLf
    S = S & "ToggleOff~event_order~set~" & mParityEvents & vbLf
    ToggleOff.Value = Not CBool(Original)
    S = S & "ToggleOff~value_changes~repeat~" & CStr(ToggleOff.Value) & vbLf
    S = S & "ToggleOff~event_order~repeat~" & mParityEvents & vbLf
    ToggleOff.Value = Original
    S = S & "ToggleOff~value_changes~restore~" & CStr(ToggleOff.Value) & vbLf
    S = S & "ToggleOff~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_ToggleOff = S
    Exit Function
Failed:
    Parity_ToggleOff = "CALCFORMS_NATIVE_ERROR:ToggleOff:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_ToggleOn() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = ToggleOn.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "ToggleOn~value_changes~initial~" & CStr(ToggleOn.Value) & vbLf
    S = S & "ToggleOn~event_order~initial~" & mParityEvents & vbLf
    ToggleOn.Value = Not CBool(Original)
    S = S & "ToggleOn~value_changes~set~" & CStr(ToggleOn.Value) & vbLf
    S = S & "ToggleOn~event_order~set~" & mParityEvents & vbLf
    ToggleOn.Value = Not CBool(Original)
    S = S & "ToggleOn~value_changes~repeat~" & CStr(ToggleOn.Value) & vbLf
    S = S & "ToggleOn~event_order~repeat~" & mParityEvents & vbLf
    ToggleOn.Value = Original
    S = S & "ToggleOn~value_changes~restore~" & CStr(ToggleOn.Value) & vbLf
    S = S & "ToggleOn~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_ToggleOn = S
    Exit Function
Failed:
    Parity_ToggleOn = "CALCFORMS_NATIVE_ERROR:ToggleOn:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_Choices() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = Choices.ListIndex
    mParityEvents = ""
    mParityFailure = ""
    S = S & "Choices~value_changes~initial~" & CStr(Choices.ListIndex) & ";value=" & CStr(Choices.Value) & vbLf
    S = S & "Choices~event_order~initial~" & mParityEvents & vbLf
    Choices.ListIndex = 2
    S = S & "Choices~value_changes~set~" & CStr(Choices.ListIndex) & ";value=" & CStr(Choices.Value) & vbLf
    S = S & "Choices~event_order~set~" & mParityEvents & vbLf
    Choices.ListIndex = 2
    S = S & "Choices~value_changes~repeat~" & CStr(Choices.ListIndex) & ";value=" & CStr(Choices.Value) & vbLf
    S = S & "Choices~event_order~repeat~" & mParityEvents & vbLf
    Choices.ListIndex = Original
    S = S & "Choices~value_changes~restore~" & CStr(Choices.ListIndex) & ";value=" & CStr(Choices.Value) & vbLf
    S = S & "Choices~event_order~restore~" & mParityEvents & vbLf
    Choices.ListIndex = 1
    S = S & "Choices~selection~select~" & CStr(Choices.ListIndex) & vbLf
    Choices.ListIndex = Original
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_Choices = S
    Exit Function
Failed:
    Parity_Choices = "CALCFORMS_NATIVE_ERROR:Choices:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_Dropdown() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = Dropdown.ListIndex
    mParityEvents = ""
    mParityFailure = ""
    S = S & "Dropdown~value_changes~initial~" & CStr(Dropdown.ListIndex) & ";value=" & CStr(Dropdown.Value) & vbLf
    S = S & "Dropdown~event_order~initial~" & mParityEvents & vbLf
    Dropdown.ListIndex = 2
    S = S & "Dropdown~value_changes~set~" & CStr(Dropdown.ListIndex) & ";value=" & CStr(Dropdown.Value) & vbLf
    S = S & "Dropdown~event_order~set~" & mParityEvents & vbLf
    Dropdown.ListIndex = 2
    S = S & "Dropdown~value_changes~repeat~" & CStr(Dropdown.ListIndex) & ";value=" & CStr(Dropdown.Value) & vbLf
    S = S & "Dropdown~event_order~repeat~" & mParityEvents & vbLf
    Dropdown.ListIndex = Original
    S = S & "Dropdown~value_changes~restore~" & CStr(Dropdown.ListIndex) & ";value=" & CStr(Dropdown.Value) & vbLf
    S = S & "Dropdown~event_order~restore~" & mParityEvents & vbLf
    Dropdown.ListIndex = 1
    S = S & "Dropdown~selection~select~" & CStr(Dropdown.ListIndex) & vbLf
    Dropdown.ListIndex = Original
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_Dropdown = S
    Exit Function
Failed:
    Parity_Dropdown = "CALCFORMS_NATIVE_ERROR:Dropdown:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Sub Unchecked_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Unchecked.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Unchecked_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Unchecked.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Checked_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Checked.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Checked_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Checked.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub OptionOne_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "OptionOne.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub OptionOne_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "OptionOne.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub OptionTwo_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "OptionTwo.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub OptionTwo_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "OptionTwo.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub ToggleOff_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "ToggleOff.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub ToggleOff_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "ToggleOff.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub ToggleOn_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "ToggleOn.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub ToggleOn_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "ToggleOn.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Choices_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Choices.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Choices_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Choices.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Dropdown_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Dropdown.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Dropdown_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Dropdown.Click|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub
