Option Explicit

' Implemented by a control container (UserForm) so a control can report that a
' render-affecting property changed without depending on the runtime or the
' window backend. The host collects invalidations; the CalcForms runtime drains
' them to schedule repaints.
'
' The separate interaction invalidation lets controls report routing-affecting
' changes (bounds, tab order, enabled/visible, accelerator/default/cancel state)
' without forcing a repaint. OxInteractionManager compares this monotonic revision
' before using its cached interaction maps.

Public Sub OnControlInvalidated(ByVal Control As IOxControl)
End Sub

Public Sub OnInteractionInvalidated(ByVal Control As IOxControl)
End Sub

' One form-wide allocation domain, independent of container depth.
Public Function AllocateNodeId() As Long
End Function
