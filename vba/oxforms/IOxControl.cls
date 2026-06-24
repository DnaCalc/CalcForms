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

' Paint the control in immediate mode into the scene builder: open the control's
' node, ask OxTheme for the role's resolved colors/edge, emit the primitive
' vocabulary, close the node. The kernel never learns the control type; only
' geometry/color/edge primitives cross the boundary. See
' docs/specs/RENDERING_ARCHITECTURE.md s5.
Public Sub Render(ByVal Surface As OxSceneBuilder)
End Sub
