# OxVba handover: bundle event-route collision for two forms with same-control-class WithEvents handlers

Status: **RESOLVED in OxVba and ADOPTED by OxForms** (OxVba fix commit `2f0b5058`, now on `master`; was OPEN at baseline `95be9ff2`). OxForms bumped its pinned baseline to `5bc7246e` (which contains `2f0b5058`) and retired the one-form-per-bundle constraint in the test harness; a regression test now bundles two forms that each have a `WithEvents CommandButton_Click`. Worked around cleanly at the time (one form per bundle); no hacky shim. Filed per the OxForms policy (don't hack around OxVba divergences — use a clean equivalent + hand over). See **Resolution** and **Adoption** below.

## Resolution (OxVba commit `2f0b5058`)

Root cause was in the OxVba **binder**, not the runtime: WithEvents *binding* tokens were drawn from a per-class counter (`member_token` in `crates/oxvba-bind/src/ids.rs`) that resets per class module, so the first WithEvents field of each sink class got binding token `0`. The binding token is half of the bundle-wide `event_routes[(binding, event)]` dispatch key, so two sink classes watching the same source event collided on `(0, 0)` — one handler shadowed the other, and the `LoadedBundle::load` dedup invariant panicked.

Fix: allocate WithEvents binding tokens from a **bundle-global** counter (unique across all class modules in the bundle), so every WithEvents field gets a distinct token and `(binding, event)` is unambiguous per sink field. Field tokens stay per-class (they index per-instance storage; binding tokens never do). This matches the "key routes per host binding, not per control-class" intent in the original note. Two instances of one sink class still share a token (same handler proc; the owner instance disambiguates the live subscription); two distinct sink classes get distinct tokens. Regression tests cover both the two-sink-classes case and the same-class-twice case.

**OxForms impact:** none was forced — the one-form-per-bundle shape is also a correct app shape. The fix is the binder commit `2f0b5058` (bundle-global WithEvents binding tokens); it is independent of the vm3/OxIR work and is now on OxVba `master`. Once the pinned baseline includes `2f0b5058`, multiple forms sharing a bundle is safe, so relaxing the constraint is an allowed convenience. OxForms has since adopted it — see **Adoption** below.

## Adoption (OxForms, 2026-06-27)

OxForms bumped the pinned OxVba baseline `95be9ff2` → `5bc7246e` (`oxforms-ag6`); `5bc7246e`
contains `2f0b5058`, verified an ancestor. The one-form-per-bundle constraint is retired where
it was bug-driven:

- `crates/oxforms-oxvba-adapter/tests/oxvba_w007_render_frame.rs`: `prepare_session_with_surface`
  now takes a slice of demo forms (any number share one bundle). A new regression test,
  `two_forms_with_withevents_buttons_share_one_bundle`, bundles BOTH the probe form
  (`OkButton_Click`) and the AutoSize form (`GrowButton_Click`) — the exact former panic shape —
  and asserts prepare succeeds (the old `build_event_routes` panic site) and a button click still
  dispatches to its native handler.
- `crates/oxforms-bootstrap/src/main.rs`: still bundles only the SELECTED demo's form, but this is
  now a deliberate app shape (the bootstrap runs one demo at a time), not a workaround — the
  comments no longer cite the OxVba bug.

No further OxForms action; this note is closed.

## Symptom

Preparing/attaching a bundle that contains **two or more class modules that each declare a `WithEvents` handler for the same control class's event** panics:

```
bundle event_routes: (binding=1, event=0) bound to two different handlers (Some(195) then 199)
  — build_event_routes dedup invariant violated
  at crates/oxvba-vm2/src/lib.rs:311
```

## Minimal repro (in OxForms)

Bundle both W007 demo forms in one project:
- `vba/smoke/fixtures/w007_object_model_probe_form.cls` — has `Private WithEvents OkButton As CommandButton` + `Private Sub OkButton_Click()`.
- `vba/smoke/fixtures/autosize_interactive_form.cls` — has `Private WithEvents GrowButton As CommandButton` + `Private Sub GrowButton_Click()`.

`Engine::prepare_bundle_package_session` (or the first VBA entry) panics as above. Each form on its own bundles + runs fine.

The colliding key `(binding=1, event=0)` is the **control class** (CommandButton) + **event id** (Click), not the host form instance — so two distinct host classes that each handle their own button's Click are treated as a duplicate route.

## Expected (real VBA / MSForms)

Multiple UserForms in one project may each have a `CommandButton` (or any control) with its own `_Click` handler. Event sinks are per `WithEvents` field on a specific host instance; they do not collide across host classes. `build_event_routes` should key routes by (host binding/instance, source, event), not by (control-class, event) at bundle scope.

## Workaround in OxForms (clean, not a hack)

One form per bundle — which is also the correct app shape (a session bundles the forms it uses):
- `crates/oxforms-bootstrap/src/main.rs`: `Demo::form_module()` + `oxforms_modules(demo)` bundle only the selected demo's form (`cargo run -p oxforms-bootstrap` vs `-- autosize`).
- `crates/oxforms-oxvba-adapter/tests/oxvba_w007_render_frame.rs`: `prepare_session_with_surface((name, path))` takes one demo form; each test bundles its own.

When OxVba keys event routes per host instance, multiple forms can share a bundle and these one-form-per-bundle constraints can relax (no OxForms code change required — it would just be an allowed convenience).

## Pointer

`crates/oxvba-vm2/src/lib.rs:311` (`build_event_routes` dedup invariant). Assume OxVba will be made fully VBA-7.1 compatible; this note tracks the gap until then.
