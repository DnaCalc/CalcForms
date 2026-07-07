Option Explicit

' Minimal shared owner interface for controls collections. UserForm and Frame both own a
' Controls collection, but the collection only needs register/unregister hooks.

Public Sub RegisterControl(ByVal Control As IOxControl)
End Sub

Public Sub UnregisterControl(ByVal Control As IOxControl)
End Sub
