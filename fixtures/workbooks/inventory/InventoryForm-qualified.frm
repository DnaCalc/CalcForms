VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} InventoryForm 
   Caption         =   "CalcForms inventory"
   ClientHeight    =   4815
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   8760.001
   OleObjectBlob   =   "InventoryForm-qualified.frx":0000
   StartUpPosition =   1  'CenterOwner
End
Attribute VB_Name = "InventoryForm"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit
Private WithEvents PickList As MSForms.ListBox
Attribute PickList.VB_VarHelpID = -1
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

