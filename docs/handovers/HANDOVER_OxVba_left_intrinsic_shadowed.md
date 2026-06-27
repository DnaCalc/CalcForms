Status: Resolved (cross-class case); OPEN for a same-class sub-case — re-verified still open
at OxVba `5bc7246e` (see the 2026-06-27 verification under the Addendum below)
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

## Addendum 2026-06-26 — same-class recurrence (still open at `95be9ff2`)

The `95be9ff2` fix covered an **unrelated** class's `Left` member shadowing the
intrinsic (project-name lookup). A **second, distinct** path survives: when the
**same class** that owns a `Left` property calls the bare `Left$` intrinsic in one of
its own methods, OxVba resolves `Left$` to that class's own `Left` property (implicit
`Me`), not to `VBA.Strings.Left`.

Found in `oxforms-4pn.13`: `UserForm` has a `Public Property Get Left()` (MSForms
surface) and a helper (now `ParseMeasure`) that called `Left$(s, n)` to take the leading
characters of a `MeasureText` result. At `95be9ff2`, that `Left$` returned the value
of `Me.Left` (the form's left, `0`) coerced to a string ("0") instead of the leading
substring — no runtime 424 this time, just a **silently wrong value** (the property
get succeeds and is type-coerced). Probed via the real OxVba session:

- In a class with **no** `Left` member (the test `RenderProbeForm`): `Left$(R, n)`
  returns the correct leading substring. ✓
- In `UserForm` (which **has** a `Left` property): the *identical* `Left$(R, n)`
  expression yields `Me.Left` → `"0"`. ✗

Expected (VBA 7.1): `Left$` (with the `$` type-declaration char) is the string
intrinsic and is a **distinct identifier** from a `Left` property (which has no `$`),
so it must resolve to `VBA.Strings.Left` even inside a class that defines `Left`. A
member named `Left` is reachable only through qualification (`Me.Left`).

Likely root cause: the same-class/implicit-`Me` member-resolution path (separate from
the project-name lookup `95be9ff2` corrected) still treats the `$`-suffixed intrinsic
name `Left$` as matching the bare member `Left`. Fix should keep `Left$` (and the
plain `Left` at an argument-bearing call site) routed to the intrinsic unless a
genuine same-named, same-arity local/member is the intended target.

Impact / current handling: `UserForm.ParseMeasure` uses `Mid$(s, 1, n)` (the
unaffected equivalent of `Left$(s, n)`) so the self-render path is unblocked today; this
is a local equivalent, not an architectural change. Once OxVba routes `Left$` to the
intrinsic for same-class scopes too, the `Mid$` choice can stay or revert freely; no
OxForms version bump is required to adopt. The broader guidance stands: any forms
class that both owns a `Left` property and needs the string intrinsic is affected.

### Verification 2026-06-27 — STILL OPEN at OxVba `5bc7246e`

Re-verified after bumping OxForms onto OxVba `master` `5bc7246e` (the M0–M2 OxIR/vm3
overhaul + the multi-form event-route fix). The same-class case is **not fixed**:
reverting `UserForm.ParseMeasure` line `RunId = Mid$(S, 1, p1 - 1)` to the idiomatic
`RunId = Left$(S, p1 - 1)` and running the adapter suite fails
`vba_self_render_crosses_the_surface_and_matches_the_canonical_scene` and
`vba_self_render_rasterizes_captions_through_the_real_shaper` — `Left$` still resolves
to the form's own `Left` property (`Me.Left` → `"0"`), so the parsed run id is wrong and
no caption shapes into `Scene.text`. The `Mid$` workaround is therefore **kept**; this
addendum remains the open ask. (The cross-class case from the body stays resolved.)
