Option Explicit

' Implemented by a control container (OxUserForm) so a control can report that a
' render-affecting property changed without depending on the runtime or the
' window backend. The host collects invalidations; the OxForms runtime drains
' them to schedule repaints.

Public Sub OnControlInvalidated(ByVal Control As IOxControl)
End Sub
