Option Explicit

' OxForms stand-in for MSForms.ReturnInteger: a mutable helper object passed by
' value into KeyDown/KeyUp/KeyPress handlers. The handler reads and may overwrite
' .Value (for example KeyCode.Value = 0 to swallow a key); the runtime reads the
' post-handler value back. This is the canonical pattern for every event whose
' FM20 argument is an MSForms.Return* helper (see docs/specs/FM20_EVENT_FACTS.md).

Private mValue As Integer

Public Property Get Value() As Integer
    Value = mValue
End Property

Public Property Let Value(ByVal NewValue As Integer)
    mValue = NewValue
End Property
