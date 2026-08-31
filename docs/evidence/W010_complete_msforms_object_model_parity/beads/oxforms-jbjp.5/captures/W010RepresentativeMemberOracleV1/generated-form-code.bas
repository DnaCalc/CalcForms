Option Explicit

Private Sub ProbeTextBox_Change()
    Dim argumentsBefore As String
    Dim argumentsAfter As String
    If Not OracleRecordingEnabled() Then Exit Sub
    argumentsBefore = ""
    argumentsAfter = ""
    RecordOracleEvent "TextChangeEvent", "event:{0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|95|primary|impl=1|source={0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|94|primary|function=2", "text_probe", "TextBox", "Change", argumentsBefore, argumentsAfter
End Sub

Private Sub ProbeTextBox_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    Dim argumentsBefore As String
    Dim argumentsAfter As String
    If Not OracleRecordingEnabled() Then Exit Sub
    argumentsBefore = "Cancel=" & OracleEscapePair(OracleValueText(Cancel.value))
    Cancel.value = True
    argumentsAfter = "Cancel=" & OracleEscapePair(OracleValueText(Cancel.value))
    RecordOracleEvent "TextExitMutation", "host-event:{0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|95|primary|source={0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1|42|primary|memid=-2147384829", "text_probe", "TextBox", "Exit", argumentsBefore, argumentsAfter
End Sub
