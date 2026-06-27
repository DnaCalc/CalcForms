Option Explicit

' W008 mutable Return* stand-in (oxforms-esq.1). Mirrors the MSForms Return*
' helpers (MSForms.ReturnInteger / MSForms.ReturnBoolean are objects exposing a
' settable .Value that an event handler mutates). A single Long .Value covers a
' KeyCode and a 0/-1 Cancel flag. The point of the gate is the mutation-readback
' mechanism through RaiseEvent, not the Integer-vs-Boolean distinction.

Private mValue As Long

Public Property Get Value() As Long
    Value = mValue
End Property

Public Property Let Value(ByVal NewValue As Long)
    mValue = NewValue
End Property
