# W006 Held-Reference Residuals Oracle Fixture

Bead: `oxforms-0a0.25`

Repo-owned Excel/MSForms inputs for the held-reference state residual that
`oxforms-0a0.21` (terminate-lifetime) left blocked. This fixture finishes the
held-reference dimension for three close paths; event ORDERING for those paths is
already captured in `oxforms-0a0.24` (nested-modal-lifecycle), so only the
held-reference state dimension is in scope here.

## Forms

- `OxFormsW006HeldRefLauncher` (identity `launcher`) — three CommandButtons. Its
  `LauncherModalHideButton_Click` and `LauncherModalUnloadButton_Click` handlers
  are the ONLY place a held form is entered with `Show vbModal`. Running
  `Show vbModal` from a button `_Click` is event-driven and does not block the
  host COM thread the way an `excel.Run`-driven `Show vbModal` would. After the
  held modal returns, the same `_Click` handler releases the global held reference
  and logs the held-reference state. `LauncherCloseButton` unloads the launcher.
- `OxFormsW006HeldRefForm` (identity `held`) — `HeldHideButton` / `HeldUnloadButton`
  drive the modal return when injected input clicks them; the lifecycle handlers
  log the held-reference state columns at handler entry.

## Standard module (`OxFormsW006HeldRefResidualsOracle`)

Owns the global held reference `gHeldRef`, the `W006HeldRefResidualsLog` worksheet
(sequence + the `local_ref_state` / `held_ref_state` / `default_instance_state` /
`release_phase` columns modeled on the terminate-lifetime fixture), the launcher
show macro, the modeless-system-close start/finish/cleanup macros, the modal
scenario runner called from the launcher button `_Click`, and per-scenario flag
setters.

## Scenarios

- `modeless_system_close` — held instance stashed in `gHeldRef` with the local
  reference released; held form shown modeless via `excel.Run` (modeless `Show`
  returns to COM); the capture script sends public `SendKeys Alt+F4` to the held
  window (never `PostMessage(WM_CLOSE)`), then `excel.Run` releases `gHeldRef`.
- `modal_hide_return` — injected click on the launcher Held-Modal-Hide button;
  the `_Click` handler runs `held.Show vbModal`; injected click on the held Hide
  button returns the modal; the `_Click` handler releases `gHeldRef` and logs.
- `modal_unload_return` — same, but the held Unload button returns the modal.

## Clean-room note

Repo-owned manifest and VBA source consumed through public Excel/VBIDE automation
and driven through public Windows input. No Office internals, decompilation,
disassembly, binary inspection, or OxForms output comparison.
