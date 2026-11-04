# CalcForms VBA Smoke Sources

This directory is reserved for procedural or class-based VBA smoke sources and
project fixtures used by W002.

`projects/rectangle_app/RectangleSmokeApp.basproj` is the W002 app fixture. It
references `vba/calcforms/CalcForms.basproj`, creates an CalcForms smoke form
through the library, and does not directly create the PAL canvas. The CalcForms
library owns the smoke-only `CreateObject("CalcForms.SmokeCanvas")` bridge to the
Rust PAL; the Rust harness registers that ProgID, the library calls
`CreateSurface`, `FillRect`, and `Flush`, and `Flush` invokes the CalcForms PAL
headless renderer.

Targeted command:

```powershell
cargo test -p calcforms-calcvba-adapter --test calcvba_rectangle_smoke -- --nocapture
```

The smoke API in this directory is temporary proof plumbing. It is not the final
MSForms compatibility surface.

`fixtures/full_surface_showcase_form.cls` is the living full-surface showcase.
It is a production-shaped VBA form-document driven by `OxRuntime`/`OxReducer`,
not a low-level smoke bridge: it renders every currently implemented intrinsic
control (`Label`, `TextBox`, `CommandButton`, `CheckBox`, `ToggleButton`,
`OptionButton`, `ListBox`, `ComboBox`, `Frame`, `Image`, `SpinButton`,
`ScrollBar`, `TabStrip`, and `MultiPage`/`Page`). Its W009 pending-control rows
are empty at the current representative subset depth, and it exposes
`RunSelfTest` plus dashboard diagnostics so the current method, property, event,
focus, service, accessibility, and perf surfaces can be proven headlessly.

Run it visibly:

```powershell
cargo run -p calcforms-bootstrap -- showcase
```

The bootstrap also exposes the W009 representative `.frm` materialization path
through the same visible runtime/TextBox reducer surface:

```powershell
cargo run -p calcforms-bootstrap -- materialized-w009
```

Both visible demos print stable marker lines to stdout:
`CALCFORMS_VISIBLE_READY`, `CALCFORMS_VISIBLE_TURN`, and `CALCFORMS_VISIBLE_CLOSE`.
The markers include the demo selector, window title, surface revision/node
counts, reducer effects, and `TextBoxDiagnostics` so an ad hoc desktop smoke can
pair a screenshot with machine-readable TextBox state.

The bootstrap launches the showcase by default; the older W007 greeter remains
available with:

```powershell
cargo run -p calcforms-bootstrap -- greeter
```

`fixtures/w005_probe_event_source.cls` and
`fixtures/w005_probe_event_harness.cls` are W005 event-dispatch smoke fixtures.
They prove reducer event effects can reach VBA handler code through CalcVBA
`RaiseEvent`/`WithEvents`. They use one generic `Dispatched` carrier event as
test infrastructure because direct FM20-named event raises are tracked in
`docs/handovers/HANDOVER_CalcVBA_w005_fm20_event_raise.md` and the W006 blocker
evidence at
`docs/evidence/W006_control_implementation_rollout/native-fm20-event-dispatch-blocker.md`;
this carrier must not be treated as the final forms event runtime.
