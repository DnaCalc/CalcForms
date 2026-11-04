Option Explicit
Private mLog As String

Private Sub UserForm_Initialize()
    mLog = "Initialize"
End Sub

Private Sub InputName_Change()
    mLog = mLog & "|Change:" & InputName.Text
End Sub

Private Sub Greet_Click()
    Output.Caption = "Hello, " & InputName.Text
    If Loud.Value Then Output.Caption = UCase$(Output.Caption)
    mLog = mLog & "|Click:" & Output.Caption
End Sub

Private Sub Loud_Click()
    mLog = mLog & "|Check:" & CStr(Loud.Value)
End Sub

Public Function State() As String
    State = mLog & ";text=" & InputName.Text & ";caption=" & Output.Caption & ";loud=" & CStr(Loud.Value)
End Function
