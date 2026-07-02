Option Explicit

' Uniform handle that every OxForms control exposes so the runtime can treat all
' controls polymorphically (materialization, property sync, hit-testing,
' invalidation) without knowing each concrete control type.
'
' Concrete controls do: Implements IOxControl, return their composed
' OxControlCore from IOxControl_Core, render themselves, and expose the small
' reducer-facing input/policy surface below. All shared control state lives on
' OxControlCore; concrete classes keep the type-specific event/property behavior.

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
' The VBA InteractionManager (through the OxReducer facade) does the geometric routing
' (hit-test, capture, pressed) control-type-agnostically, then delivers the routed input here so the CONTROL
' raises its own ordered FM20 events. Polymorphic interface dispatch (like Render) — the
' reducer never switches on or late-binds a concrete control type. Each control delegates to
' its concrete Perform* surface; a control that does not fire an event implements an empty
' body (e.g. TextBox.OnClick — a TextBox has no Click). X/Y are control-local points.
Public Sub OnMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
End Sub

Public Sub OnMouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
End Sub

Public Sub OnMouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
End Sub

Public Sub OnClick()
End Sub

' --- Reducer interaction policy (control self-knowledge, read by OxInteractionManager) ---
' Whether this control fires a Click event when a captured press releases inside it
' (CommandButton/Label/CheckBox do; TextBox does not). Declared by the control so the reducer
' decides Click without switching on a control-type enum.
Public Property Get SupportsClick() As Boolean
End Property

' Whether this control shows an armed "pressed" visual on mouse-down (CommandButton/CheckBox).
' The reducer arms Core.Pressed only for these; capture is taken for every press regardless.
Public Property Get HasPressedVisual() As Boolean
End Property

' --- Reducer keyboard surface (delivered to the focused control) ---
' Raise KeyDown (a handler may swallow by setting KeyCode = 0) and perform the control's own
' default key behavior (a TextBox edits; others do nothing). Returns the post-handler key code
' (0 = swallowed) so the reducer can link a swallow to the following character.
Public Function OnKeyDown(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
End Function

Public Function OnKeyUp(ByVal KeyCode As Integer, ByVal Shift As Integer) As Integer
End Function

' Raise KeyPress for the typed text and apply the control's default character behavior (a
' TextBox inserts the text and raises Change; others only raise KeyPress).
Public Sub OnCharacterInput(ByVal Text As String)
End Sub

' --- Reducer focus / validation surface ---
' Raise the focus-enter event (no readback) when this control gains focus.
Public Sub OnEnter()
End Sub

' Raise the focus-exit event; return True if the handler vetoed the focus change (Cancel=True).
Public Function OnExit() As Boolean
End Function

' Raise BeforeUpdate on a dirty focus-out; return True if the handler vetoed the value commit.
Public Function OnBeforeUpdate() As Boolean
End Function

' Raise AfterUpdate after a committed value change, and clear the control's edit-dirty state.
Public Sub OnAfterUpdate()
End Sub

' Whether this control has an uncommitted user edit. Gates the two-stage focus-out validation:
' a dirty control fires BeforeUpdate/AfterUpdate, a clean one goes straight to Exit.
Public Property Get IsDirty() As Boolean
End Property

' --- Reducer default/cancel/accelerator surface ---
' Whether this control is the form default button (Enter activates it) / cancel button (Escape
' activates it). Only a CommandButton can be either; everything else returns False.
Public Property Get IsDefault() As Boolean
End Property

Public Property Get IsCancel() As Boolean
End Property

' The control's Alt-accelerator letter (uppercased) parsed from its caption '&X' mnemonic, or
' "" if none. Used by the reducer to resolve Alt+letter to a CommandButton.
Public Property Get AcceleratorKey() As String
End Property

' Give the FOCUSED control first refusal on a Space/Enter key: a CheckBox toggles (and returns
' True) on Space, or on Enter when no default button exists; other controls return False so the
' reducer falls through to default-button / accelerator handling. The toggle (Change/Click) fires
' BEFORE the reducer raises KeyDown (value-first, oracle CheckBox keyboard order).
Public Function TryKeyboardActivate(ByVal KeyCode As Integer, ByVal Shift As Integer, ByVal HasDefaultButton As Boolean) As Boolean
End Function

' --- Reducer paste surface (clipboard Ctrl+V or drag-drop) ---
' Apply a paste of Text to the control: a TextBox raises BeforeDropOrPaste (a handler may veto by
' setting Cancel=True) and, if not vetoed, inserts the text and raises Change; other controls
' ignore it. Action is the fmAction (2 = paste); Shift is the modifier state. Returns True if the
' control consumed the paste (i.e. is a text target), regardless of veto.
Public Function OnPaste(ByVal Text As String, ByVal Action As Integer, ByVal Shift As Integer) As Boolean
End Function

' Copy/cut selected control text for host clipboard shortcuts. TextBox returns the current
' selection; Cut also deletes it and raises Change. Non-text controls return "".
Public Function OnCopy() As String
End Function

Public Function OnCut() As String
End Function
