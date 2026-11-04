Option Explicit
Public Function ProbeSequence() As String
    Dim Held As LifecycleProbe
    Dim Other As LifecycleProbe
    Load LifecycleProbe
    AppendTrace "loaded:" & CStr(UserForms.Count) & ":" & CStr(LifecycleProbe.Visible)
    Set Held = LifecycleProbe
    AppendTrace "same:" & CStr(Held Is LifecycleProbe)
    LifecycleProbe.InputName.Text = "Lin"
    LifecycleProbe.Show vbModeless
    AppendTrace "shown:" & LifecycleProbe.State()
    LifecycleProbe.Hide
    AppendTrace "hidden:" & LifecycleProbe.State() & ":" & CStr(LifecycleProbe.Visible)
    LifecycleProbe.Show vbModeless
    LifecycleProbe.VetoNextClose
    Unload LifecycleProbe
    AppendTrace "veto:" & CStr(LifecycleProbe.Visible)
    Unload LifecycleProbe
    AppendTrace "unloaded:" & CStr(UserForms.Count)
    AppendTrace "held-generation:" & CStr(Held.Generation)
    Load LifecycleProbe
    AppendTrace "reload-same:" & CStr(Held Is LifecycleProbe)
    AppendTrace "reloaded:" & LifecycleProbe.State()
    Set Held = Nothing
    Unload LifecycleProbe
    Set Other = New LifecycleProbe
    AppendTrace "new:" & Other.State()
    Other.Show vbModeless
    Other.Hide
    Unload Other
    Set Other = Nothing
    ProbeSequence = Trace()
End Function
