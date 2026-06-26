# OxVba handover: bundle event-route collision for two forms with same-control-class WithEvents handlers

Status: OPEN at OxVba baseline `95be9ff2`. Worked around cleanly (one form per bundle); no hacky shim. Filed per the OxForms policy (don't hack around OxVba divergences — use a clean equivalent + hand over).

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
