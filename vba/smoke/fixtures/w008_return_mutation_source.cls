Option Explicit

' W008 ByRef Return* helper-mutation gate source (oxforms-esq.1). Models the
' MSForms Return* pattern: a mutable helper OBJECT is passed into a native event,
' a WithEvents handler writes its .Value, and the value is read back after
' RaiseEvent returns. The Rust adapter creates the helper, invokes Raise*, then
' reads the helper's .Value -- mirroring what the OxForms runtime must do for
' Cancel/KeyCode helper-mutation semantics (QueryClose, key events).

Public Event KeyDownLike(ByVal KeyCode As W008ReturnValue, ByVal Shift As Integer)
Public Event QueryCloseLike(ByVal Cancel As W008ReturnValue)

Public Sub RaiseKeyDownLike(ByVal KeyCode As W008ReturnValue, ByVal StartCode As Long, ByVal Shift As Integer)
    KeyCode.Value = StartCode
    RaiseEvent KeyDownLike(KeyCode, Shift)
End Sub

Public Sub RaiseQueryCloseLike(ByVal Cancel As W008ReturnValue, ByVal StartCancel As Long)
    Cancel.Value = StartCancel
    RaiseEvent QueryCloseLike(Cancel)
End Sub
