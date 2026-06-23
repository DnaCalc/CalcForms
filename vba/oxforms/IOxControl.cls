Option Explicit

' Uniform handle that every OxForms control exposes so the runtime can treat all
' controls polymorphically (materialization, property sync, hit-testing,
' invalidation) without knowing each concrete control type.
'
' Concrete controls do: Implements IOxControl, then return their composed
' OxControlCore from IOxControl_Core. All shared control state lives on
' OxControlCore, so this interface stays a single member as the control set grows.

Public Property Get Core() As OxControlCore
End Property
