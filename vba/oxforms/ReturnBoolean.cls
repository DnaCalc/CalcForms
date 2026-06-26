Option Explicit

' OxForms stand-in for MSForms.ReturnBoolean: a mutable helper object passed by
' value into cancelable handlers (Exit, BeforeUpdate, DblClick, ...). The handler
' sets .Value = True to cancel; the runtime reads the post-handler value back.
' Same helper-object pattern as ReturnInteger.

Private mValue As Boolean

Public Property Get Value() As Boolean
    Value = mValue
End Property

Public Property Let Value(ByVal NewValue As Boolean)
    mValue = NewValue
End Property
