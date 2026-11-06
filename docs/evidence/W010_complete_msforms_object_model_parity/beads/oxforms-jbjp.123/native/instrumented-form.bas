Option Explicit
Private WithEvents PickList As MSForms.ListBox
Private mTrace As String
Private mFailure As String
Private mSaved As Long
Private mTotal As Long

Private Sub UserForm_Initialize()
    On Error GoTo Failed
    mTrace = "Initialize"
    mSaved = 0
    mTotal = 0
    QtyInput.Text = "1"
    Set PickList = Me.Controls.Add("Forms.ListBox.1", "PickList")
    PickList.Left = 12
    PickList.Top = 24
    PickList.Width = 144
    PickList.Height = 72
    Dim I As Long
    For I = 1 To 23
        PickList.AddItem "Part " & CStr(I)
    Next I
    PickList.ListIndex = 0
    PickList.TopIndex = 0
    StatusLabel.Caption = "Ready"
    Exit Sub
Failed:
    mFailure = "initialize:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub PickList_Change()
    On Error GoTo Failed
    SelectedLabel.Caption = PickList.Value
    mTrace = mTrace & "|part=" & CStr(PickList.ListIndex)
    Exit Sub
Failed:
    mFailure = "part-change:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub QtyInput_Change()
    On Error GoTo Failed
    mTrace = mTrace & "|qty=" & QtyInput.Text
    Exit Sub
Failed:
    mFailure = "quantity-change:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Function QuantityValue() As Long
    Dim Text As String, I As Long, Code As Long
    Text = Trim$(QtyInput.Text)
    If Len(Text) = 0 Or Len(Text) > 3 Then Exit Function
    For I = 1 To Len(Text)
        Code = Asc(Mid$(Text, I, 1))
        If Code < 48 Or Code > 57 Then Exit Function
    Next I
    QuantityValue = CLng(Text)
End Function

Private Sub SubmitButton_Click()
    On Error GoTo Failed
    Dim Quantity As Long
    Quantity = QuantityValue()
    If Quantity = 0 Then
        StatusLabel.Caption = "Enter 1 to 999"
        mTrace = mTrace & "|invalid"
        Exit Sub
    End If
    mSaved = mSaved + 1
    mTotal = Quantity * (PickList.ListIndex + 1) * 5
    StatusLabel.Caption = "Saved " & PickList.Value
    mTrace = mTrace & "|saved=" & CStr(mTotal)
    Exit Sub
Failed:
    mFailure = "submit:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub CancelButton_Click()
    On Error GoTo Failed
    EscapeLog = EscapeLog & "|Cancel.Click"
    mTrace = mTrace & "|cancel"
    Me.Hide
    Exit Sub
Failed:
    mFailure = "cancel:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Public Function State() As String
    On Error GoTo Failed
    If Len(mFailure) > 0 Then Err.Raise 5, "Inventory", mFailure
    State = "index=" & CStr(PickList.ListIndex) & ";top=" & CStr(PickList.TopIndex) & ";part=" & SelectedLabel.Caption & ";qty=" & QtyInput.Text & ";saved=" & CStr(mSaved) & ";total=" & CStr(mTotal) & ";status=" & StatusLabel.Caption & ";visible=" & CStr(Me.Visible)
    Exit Function
Failed:
    State = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function

Public Function Trace() As String
    On Error GoTo Failed
    If Len(mFailure) > 0 Then Err.Raise 5, "Inventory", mFailure
    Trace = mTrace
    Exit Function
Failed:
    Trace = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function

Private Sub QtyInput_BeforeUpdate(ByVal Cancel As MSForms.ReturnBoolean)
    EscapeLog = EscapeLog & "|Qty.BeforeUpdate"
    If EscapeMode = "before_veto" Then Cancel.Value = True
End Sub
Private Sub QtyInput_AfterUpdate()
    EscapeLog = EscapeLog & "|Qty.AfterUpdate"
End Sub
Private Sub QtyInput_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    EscapeLog = EscapeLog & "|Qty.Exit"
    If EscapeMode = "exit_veto" Then Cancel.Value = True
End Sub
Private Sub SubmitButton_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    EscapeLog = EscapeLog & "|Submit.Exit"
End Sub
Private Sub CancelButton_Enter()
    EscapeLog = EscapeLog & "|Cancel.Enter"
End Sub
