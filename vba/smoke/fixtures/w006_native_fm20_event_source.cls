Option Explicit

' W007 native FM20 class-event gate fixture (oxforms-4pn.2).
' Declares native FM20-named events and raises them through the ordinary OxVba
' RaiseEvent path. No generic carrier event is used; the Rust adapter invokes the
' Raise* methods directly.

Public Event Click()
Public Event Change()
Public Event MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)

Public Sub RaiseClick()
    RaiseEvent Click
End Sub

Public Sub RaiseChange()
    RaiseEvent Change
End Sub

Public Sub RaiseMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseDown(Button, Shift, X, Y)
End Sub

Public Sub RaiseMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseUp(Button, Shift, X, Y)
End Sub

Public Sub RaiseMouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseMove(Button, Shift, X, Y)
End Sub
