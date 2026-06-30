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

' --- Reducer input surface ---
' The VBA interaction reducer (OxReducer) does the geometric routing (hit-test, capture,
' pressed) control-type-agnostically, then delivers the routed input here so the CONTROL
' raises its own ordered FM20 events. Polymorphic interface dispatch (like Render) — the
' reducer never switches on or late-binds a concrete control type. Each control delegates to
' its concrete Perform* surface; a control that does not fire an event implements an empty
' body (e.g. TextBox.OnClick — a TextBox has no Click). X/Y are control-local points.
Public Sub OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
End Sub

Public Sub OnMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
End Sub

Public Sub OnClick()
End Sub

' --- Reducer interaction policy (control self-knowledge, read by OxReducer) ---
' Whether this control fires a Click event when a captured press releases inside it
' (CommandButton/Label/CheckBox do; TextBox does not). Declared by the control so the reducer
' decides Click without switching on a control-type enum.
Public Property Get SupportsClick() As Boolean
End Property

' Whether this control shows an armed "pressed" visual on mouse-down (CommandButton/CheckBox).
' The reducer arms Core.Pressed only for these; capture is taken for every press regardless.
Public Property Get HasPressedVisual() As Boolean
End Property
