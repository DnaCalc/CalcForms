Option Explicit
Private mParityEvents As String
Private mParityFailure As String
Private Sub UserForm_Initialize()
End Sub
Public Function ParityMeasurements() As String
    On Error GoTo Failed
    Dim S As String
    S = S & Parity_InputName()
    S = S & Parity_LongInput()
    ParityMeasurements = S
    Exit Function
Failed:
    ParityMeasurements = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function

Private Function Parity_InputName() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = InputName.Text
    mParityEvents = ""
    mParityFailure = ""
    S = S & "InputName~value_changes~initial~" & CStr(InputName.Text) & vbLf
    S = S & "InputName~event_order~initial~" & mParityEvents & vbLf
    InputName.Text = "Parity probe"
    S = S & "InputName~value_changes~set~" & CStr(InputName.Text) & vbLf
    S = S & "InputName~event_order~set~" & mParityEvents & vbLf
    InputName.Text = "Parity probe"
    S = S & "InputName~value_changes~repeat~" & CStr(InputName.Text) & vbLf
    S = S & "InputName~event_order~repeat~" & mParityEvents & vbLf
    InputName.Text = Original
    S = S & "InputName~value_changes~restore~" & CStr(InputName.Text) & vbLf
    S = S & "InputName~event_order~restore~" & mParityEvents & vbLf
    InputName.Text = "Alpha Beta"
    InputName.SelStart = 2
    InputName.SelLength = 4
    S = S & "InputName~selection~range~" & CStr(InputName.SelStart) & ";" & CStr(InputName.SelLength) & ";" & InputName.SelText & vbLf
    InputName.SelText = "X"
    S = S & "InputName~selection~replace~" & InputName.Text & ";" & CStr(InputName.SelStart) & ";" & CStr(InputName.SelLength) & vbLf
    InputName.Text = Original
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_InputName = S
    Exit Function
Failed:
    Parity_InputName = "CALCFORMS_NATIVE_ERROR:InputName:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_LongInput() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = LongInput.Text
    mParityEvents = ""
    mParityFailure = ""
    S = S & "LongInput~value_changes~initial~" & CStr(LongInput.Text) & vbLf
    S = S & "LongInput~event_order~initial~" & mParityEvents & vbLf
    LongInput.Text = "Parity probe"
    S = S & "LongInput~value_changes~set~" & CStr(LongInput.Text) & vbLf
    S = S & "LongInput~event_order~set~" & mParityEvents & vbLf
    LongInput.Text = "Parity probe"
    S = S & "LongInput~value_changes~repeat~" & CStr(LongInput.Text) & vbLf
    S = S & "LongInput~event_order~repeat~" & mParityEvents & vbLf
    LongInput.Text = Original
    S = S & "LongInput~value_changes~restore~" & CStr(LongInput.Text) & vbLf
    S = S & "LongInput~event_order~restore~" & mParityEvents & vbLf
    LongInput.Text = "Alpha Beta"
    LongInput.SelStart = 2
    LongInput.SelLength = 4
    S = S & "LongInput~selection~range~" & CStr(LongInput.SelStart) & ";" & CStr(LongInput.SelLength) & ";" & LongInput.SelText & vbLf
    LongInput.SelText = "X"
    S = S & "LongInput~selection~replace~" & LongInput.Text & ";" & CStr(LongInput.SelStart) & ";" & CStr(LongInput.SelLength) & vbLf
    LongInput.Text = Original
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_LongInput = S
    Exit Function
Failed:
    Parity_LongInput = "CALCFORMS_NATIVE_ERROR:LongInput:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Sub InputName_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "InputName.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub LongInput_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "LongInput.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub
