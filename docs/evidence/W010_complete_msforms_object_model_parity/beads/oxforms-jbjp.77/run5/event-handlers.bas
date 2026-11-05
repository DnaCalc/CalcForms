Private Sub UserForm_Activate()
    Run5EventLog = Run5EventLog & "|Activate"
End Sub
Private Sub UserForm_Deactivate()
    Run5EventLog = Run5EventLog & "|Deactivate"
End Sub
Private Sub UserForm_QueryClose(Cancel As Integer, CloseMode As Integer)
    Run5EventLog = Run5EventLog & "|QueryClose:" & CStr(CloseMode)
    If InputName.Text = "veto" Then Cancel = -1
End Sub
