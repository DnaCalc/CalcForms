Status: Resolved
Target: OxVba
Ask: Accept a bracketed identifier as the event name in a `RaiseEvent` statement (and, ideally, resolve a bare reserved-word event name), so MSForms-faithful control events whose names are VBA reserved words — notably the FM20 `Exit` event — can be declared and raised.

Context: OxForms intrinsic controls must expose MSForms event names, some of which are VBA reserved words. The canonical case is the FM20 focus `Exit` event (`Private Sub TextBox1_Exit(ByVal Cancel As MSForms.ReturnBoolean)`). In VBA, reserved words are used as identifiers via the bracketed/foreign-name form `[Exit]` (MS-VBAL foreign-name). OxVba already supports bracketed identifiers in the lexer/parser and already binds a `Public Event [Exit]()` declaration and wires a `Private WithEvents` `Src_Exit` handler to it. The single remaining gap is the `RaiseEvent` statement parser, which does not accept a bracketed identifier as the event name.

Evidence (probed against pinned baseline `366896f` via a package-session bind):

- `Public Event [Exit]()` + `Private WithEvents Src As S` + `Private Sub Src_Exit()` → binds OK. The declaration and WithEvents handler wiring already handle the bracketed reserved name.
- `RaiseEvent [Exit]` → bind `Malformed("RaiseEvent without an event name")`. **This is the gap** — the RaiseEvent parser rejects a `BracketedIdent` event name even though OxVba accepts bracketed identifiers elsewhere.
- `Public Event Exit()` (unbracketed) → bind `Unresolved { name: "Exit", context: "event" }`. Consistent with `Exit` being a reserved keyword (bare reserved words are not valid identifiers); a clean parse-time "reserved word; bracket it as `[Exit]`" diagnostic would be friendlier, but rejecting the bare form is defensible.
- Control: a normal event name (e.g. `Quitting`) binds and raises for all shapes (baseline).

Net: declaring and handling `[Exit]` works; only `RaiseEvent [Exit]` is blocked. Fixing the RaiseEvent parser to accept a bracketed event name (mirroring the bracketed-identifier support already present in declarations/handlers) unblocks the real FM20 `Exit` event and any other reserved-word event names.

Until fixed, OxForms uses `BeforeUpdate` (a real FM20 cancelable `ReturnBoolean` event, not a reserved word) as a stand-in to establish the mutable-helper event pattern; see `vba/oxforms/CommandButton.cls` / `TextBox.cls`. Tracked as `oxforms-0rj`.

## Resolution (OxVba + OxForms, 2026-06-24)

OxVba fixed it at commit `366a40e38f805d3adcb558df01c280398afa2a2f` ("Accept
bracketed RaiseEvent names"): `RaiseEvent [Exit]` now parses, `Public Event [Exit]()`
is accepted, and bind normalizes `[Exit]` to `Exit`. OxForms bumped the pinned
baseline `366896f` → `366a40e` and switched `CommandButton`/`TextBox` from the
`BeforeUpdate` stand-in to the native `[Exit]` event. `oxvba_w007_object_model.rs`
now exercises `Public Event [Exit](ByVal Cancel As ReturnBoolean)` +
`RaiseEvent [Exit](cancel)` + a `Private WithEvents` `InputField_Exit` handler with
a `ReturnBoolean` cancel round-trip, green on `366a40e`. Closed `oxforms-0rj`.
