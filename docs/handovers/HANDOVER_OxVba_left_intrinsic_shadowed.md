Status: Resolved
Target: OxVba
Ask: Resolve an unqualified call to an intrinsic VBA function (confirmed: the
string functions `Left` / `Left$`) to the VBA library intrinsic, not to a
same-named member (e.g. a `Left` property) defined on some *other* class in the
project. In VBA 7.1 the intrinsics live in the global VBA namespace and are not
shadowed by unrelated class members; only an in-scope local/module-level symbol of
the same name shadows them.

## Context

OxForms is a VBA-first MSForms-compatible forms runtime. Every control exposes a
`Left` property (also `Top`/`Width`/`Height`) — this is core MSForms surface. The
VBA library also needs the intrinsic VBA string function `Left`/`Left$` (e.g. "take
the leading N characters of a string") in unrelated code.

In OxVba (baseline `366a40e`), an **unqualified** call to the intrinsic `Left` /
`Left$` from *any* module — including a module that has no `Left` member of its own
— fails at runtime with error **424 "Object required"** as soon as the project also
contains a class with a `Left` property. The intrinsic is being resolved to the
member rather than to the VBA library function.

Other intrinsic string/conversion functions whose names do **not** collide with a
project member work correctly in the very same project and call site:
`Mid` / `Mid$`, `Str` / `Str$`, `Trim` / `Trim$`, `Len`, `CStr`, and `&`.

## Evidence (probed against baseline `366a40e` via a bound package session)

A class `RenderProbeForm` with a `Run` method (no `Left` member of its own), in a
project that also binds the OxForms control object model (`OxControlCore`/`Label`/
`TextBox`/`CommandButton` each expose `Public Property Get/Let Left`):

- `CStr(200)` → "200" ✓
- `Str(200)` → " 200", `Trim$(Str$(123))` → "123" ✓
- `Mid("hello", 2)` → "ello", `Mid$("hello", 1, 1)` → "h" ✓
- `Trim(" z ")` → "z" ✓
- `Left("hello", 2)` → **runtime 424 "Object required"** (expected: "he")
- `Left$(s, 1)` → **runtime 424 "Object required"** (expected: leading char)

Binding succeeds in all cases (the names are in the symbol catalog as library
members); the divergence is purely at **runtime resolution/lowering**. The 424
text matches `oxvba-vm2`'s member-dispatch path (`arg_object` →
`Fault::new(424, "Object required")`), i.e. the call is being lowered/dispatched as
an object-member access rather than routed through `invoke_native_lib`
(`oxvba_lib::invoke` *does* implement `pure::left`, so the body exists and is
reachable for a correctly-routed call).

Minimal repro shape:

```vba
' Class A (like every MSForms control):
Public Property Get Left() As Single
End Property

' Module/Class B, no Left member of its own:
Public Function Probe() As String
    Probe = Left$("hello", 2)   ' VBA 7.1 => "he"; OxVba 366a40e => runtime 424
End Function
```

## Expected (VBA 7.1 as in Office)

`Left("hello", 2)` / `Left$("hello", 2)` return `"he"` regardless of any other
class in the project defining a `Left` property. A class member named `Left` is
reachable only through qualification (`obj.Left` / `Me.Left`); it does not shadow
the global intrinsic at an unqualified call site in a different scope.

## Scope / likely root cause

Confirmed only for `Left` / `Left$` (the only intrinsic whose primary name collides
with the universal control `.Left` property). The general risk is any intrinsic
whose catalog name matches a project-defined member; the fix should make unqualified
intrinsic resolution prefer the VBA global namespace over unrelated class members,
matching VBA scoping. `Top` / `Width` / `Height` are control properties too but have
no intrinsic-function counterparts, so they are not affected as call targets.

## Impact on OxForms / current handling

The VBA scene encoder (`vba/oxforms/OxSceneBuilder.cls`, `JsonNum`) wanted `Left$`
to read leading characters; it uses the equivalent `Mid$(s, 1, n)` instead, which
OxVba resolves correctly, so the W007 self-render path is unblocked today. This is
a local equivalent, not an architectural change. The broader concern stands: a
forms library defines `.Left` on every control, so the intrinsic `Left`/`Left$`
is effectively unusable project-wide until this is fixed. No OxForms version bump
is required to adopt the fix; once landed, `Left$` becomes usable again and the
`Mid$` choice in `JsonNum` can stay or revert freely.

## Resolution (OxVba + OxForms, 2026-06-24)

OxVba fixed it at commit `95be9ff2190caa3c74257c2b59f290a7dfd798ba` ("Keep class
members out of bare intrinsic lookup"): `ProjectProvider` no longer exposes public
class/document/form members as bare unqualified project names, so an unrelated
class's `Left` property no longer shadows the intrinsic; standard-module public
members still participate in bare lookup (and can still shadow intrinsics, matching
VBA). `Left`/`Left$` now resolve to `VBA.Strings.Left`. No public API change.

Verified for OxForms: with a local path override onto the sibling `../OxVba`
checkout at `95be9ff2`, `OxSceneBuilder.JsonNum` reverted to the idiomatic `Left$`,
the full workspace suite is green — including `oxvba_surface_render_smoke`, which
exercises `Left$` inside a project whose controls all expose a `.Left` property.

Adopted: OxVba pushed `95be9ff2` to `origin/master`, and OxForms bumped the pinned
baseline `366a40e…` → `95be9ff2…` (`Cargo.toml`
`[workspace.metadata.oxforms.oxvba_baseline]`, the eight `oxvba-*` git deps in
`crates/oxforms-oxvba-adapter/Cargo.toml`, and `Cargo.lock`) and switched
`OxSceneBuilder.JsonNum` back to the idiomatic `Left$`. The full floor is green on
the bumped baseline (`oxvba_surface_render_smoke` now exercises `Left$` against a
project whose controls all expose a `.Left` property). No OxForms-side workaround
remains. Closed.
