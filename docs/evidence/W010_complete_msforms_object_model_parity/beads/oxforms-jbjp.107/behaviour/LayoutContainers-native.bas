Option Explicit
Private mParityEvents As String
Private mParityFailure As String
Private Sub UserForm_Initialize()
End Sub
Public Function ParityMeasurements() As String
    On Error GoTo Failed
    Dim S As String
    S = S & Parity_NestedInput()
    S = S & Parity_Spinner()
    S = S & Parity_Slider()
    S = S & Parity_TabsControl()
    S = S & Parity_PagesControl()
    ParityMeasurements = S
    Exit Function
Failed:
    ParityMeasurements = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function

Private Function Parity_NestedInput() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = NestedInput.Text
    mParityEvents = ""
    mParityFailure = ""
    S = S & "Group.NestedInput~value_changes~initial~" & CStr(NestedInput.Text) & vbLf
    S = S & "Group.NestedInput~event_order~initial~" & mParityEvents & vbLf
    NestedInput.Text = "Parity probe"
    S = S & "Group.NestedInput~value_changes~set~" & CStr(NestedInput.Text) & vbLf
    S = S & "Group.NestedInput~event_order~set~" & mParityEvents & vbLf
    NestedInput.Text = "Parity probe"
    S = S & "Group.NestedInput~value_changes~repeat~" & CStr(NestedInput.Text) & vbLf
    S = S & "Group.NestedInput~event_order~repeat~" & mParityEvents & vbLf
    NestedInput.Text = Original
    S = S & "Group.NestedInput~value_changes~restore~" & CStr(NestedInput.Text) & vbLf
    S = S & "Group.NestedInput~event_order~restore~" & mParityEvents & vbLf
    NestedInput.Text = "Alpha Beta"
    NestedInput.SelStart = 2
    NestedInput.SelLength = 4
    S = S & "Group.NestedInput~selection~range~" & CStr(NestedInput.SelStart) & ";" & CStr(NestedInput.SelLength) & ";" & NestedInput.SelText & vbLf
    NestedInput.SelText = "X"
    S = S & "Group.NestedInput~selection~replace~" & NestedInput.Text & ";" & CStr(NestedInput.SelStart) & ";" & CStr(NestedInput.SelLength) & vbLf
    NestedInput.Text = Original
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_NestedInput = S
    Exit Function
Failed:
    Parity_NestedInput = "CALCFORMS_NATIVE_ERROR:Group.NestedInput:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_Spinner() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = Spinner.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "Spinner~value_changes~initial~" & CStr(Spinner.Value) & vbLf
    S = S & "Spinner~event_order~initial~" & mParityEvents & vbLf
    Spinner.Value = 1
    S = S & "Spinner~value_changes~set~" & CStr(Spinner.Value) & vbLf
    S = S & "Spinner~event_order~set~" & mParityEvents & vbLf
    Spinner.Value = 1
    S = S & "Spinner~value_changes~repeat~" & CStr(Spinner.Value) & vbLf
    S = S & "Spinner~event_order~repeat~" & mParityEvents & vbLf
    Spinner.Value = Original
    S = S & "Spinner~value_changes~restore~" & CStr(Spinner.Value) & vbLf
    S = S & "Spinner~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_Spinner = S
    Exit Function
Failed:
    Parity_Spinner = "CALCFORMS_NATIVE_ERROR:Spinner:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_Slider() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = Slider.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "Slider~value_changes~initial~" & CStr(Slider.Value) & vbLf
    S = S & "Slider~event_order~initial~" & mParityEvents & vbLf
    Slider.Value = 1
    S = S & "Slider~value_changes~set~" & CStr(Slider.Value) & vbLf
    S = S & "Slider~event_order~set~" & mParityEvents & vbLf
    Slider.Value = 1
    S = S & "Slider~value_changes~repeat~" & CStr(Slider.Value) & vbLf
    S = S & "Slider~event_order~repeat~" & mParityEvents & vbLf
    Slider.Value = Original
    S = S & "Slider~value_changes~restore~" & CStr(Slider.Value) & vbLf
    S = S & "Slider~event_order~restore~" & mParityEvents & vbLf
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_Slider = S
    Exit Function
Failed:
    Parity_Slider = "CALCFORMS_NATIVE_ERROR:Slider:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_TabsControl() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = TabsControl.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "TabsControl~value_changes~initial~" & CStr(TabsControl.Value) & vbLf
    S = S & "TabsControl~event_order~initial~" & mParityEvents & vbLf
    TabsControl.Value = 1
    S = S & "TabsControl~value_changes~set~" & CStr(TabsControl.Value) & vbLf
    S = S & "TabsControl~event_order~set~" & mParityEvents & vbLf
    TabsControl.Value = 1
    S = S & "TabsControl~value_changes~repeat~" & CStr(TabsControl.Value) & vbLf
    S = S & "TabsControl~event_order~repeat~" & mParityEvents & vbLf
    TabsControl.Value = Original
    S = S & "TabsControl~value_changes~restore~" & CStr(TabsControl.Value) & vbLf
    S = S & "TabsControl~event_order~restore~" & mParityEvents & vbLf
    TabsControl.Value = 1
    S = S & "TabsControl~selection~select~" & CStr(TabsControl.Value) & vbLf
    TabsControl.Value = Original
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_TabsControl = S
    Exit Function
Failed:
    Parity_TabsControl = "CALCFORMS_NATIVE_ERROR:TabsControl:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Function Parity_PagesControl() As String
    On Error GoTo Failed
    Dim Original As Variant, S As String
    Original = PagesControl.Value
    mParityEvents = ""
    mParityFailure = ""
    S = S & "PagesControl~value_changes~initial~" & CStr(PagesControl.Value) & vbLf
    S = S & "PagesControl~event_order~initial~" & mParityEvents & vbLf
    PagesControl.Value = 1
    S = S & "PagesControl~value_changes~set~" & CStr(PagesControl.Value) & vbLf
    S = S & "PagesControl~event_order~set~" & mParityEvents & vbLf
    PagesControl.Value = 1
    S = S & "PagesControl~value_changes~repeat~" & CStr(PagesControl.Value) & vbLf
    S = S & "PagesControl~event_order~repeat~" & mParityEvents & vbLf
    PagesControl.Value = Original
    S = S & "PagesControl~value_changes~restore~" & CStr(PagesControl.Value) & vbLf
    S = S & "PagesControl~event_order~restore~" & mParityEvents & vbLf
    PagesControl.Value = 1
    S = S & "PagesControl~selection~select~" & CStr(PagesControl.Value) & vbLf
    PagesControl.Value = Original
    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure
    Parity_PagesControl = S
    Exit Function
Failed:
    Parity_PagesControl = "CALCFORMS_NATIVE_ERROR:PagesControl:" & CStr(Err.Number) & ":" & Err.Description & vbLf
End Function

Private Sub NestedInput_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Group.NestedInput.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Spinner_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Spinner.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Spinner_SpinUp()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Spinner.SpinUp|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Spinner_SpinDown()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Spinner.SpinDown|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Slider_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Slider.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Slider_Scroll()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "Slider.Scroll|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub TabsControl_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "TabsControl.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub PagesControl_Change()
    On Error GoTo Failed
    mParityEvents = mParityEvents & "PagesControl.Change|"
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub
