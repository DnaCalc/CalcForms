# W005 Windows Automation And Inspection Exploration

Status: evidence/test-infrastructure exploration.
Owning bead: `oxforms-xvx.15`.
Owning workset: `W005_input_interaction_model_exploration`.

This note evaluates public Windows automation and inspection options for W005
interaction evidence. It is not OxForms runtime architecture, does not add
accessibility semantics to OxForms controls, and does not change the canonical
input model. The durable verification path remains headless reducer tests and
trace/replay; live Windows automation is an auxiliary evidence driver and
diagnostic layer.

## Evidence Read

Current W005 evidence already uses public Windows desktop APIs:

- `tools/office-oracle/Capture-W005InteractionEvents.ps1` drives the Excel /
  MSForms oracle through public Excel/VBIDE automation, `EnumWindows`,
  `GetWindowRect`, `SetForegroundWindow`, `SetCursorPos`, `mouse_event`,
  `System.Windows.Forms.SendKeys`, and screenshot capture through
  `tools/office-oracle/Capture-Window.ps1`.
- `tools/w005-visible-input/Invoke-W005VisibleInputSmoke.ps1` locates the
  OxForms `minifb` smoke window, records client geometry, drives mouse and key
  input, captures a screenshot, and records `visible-input-actions.json`.
- The authoritative modeless MSForms capture is
  [`captures/interaction-events-20260623T004914Z/`](captures/interaction-events-20260623T004914Z/).
  Its manifest records automated public Windows input and live MSForms event
  rows, including mouse, keyboard, focus/update, click, and lifecycle events.
- The visible OxForms smoke capture is
  [`captures/visible-input-smoke-20260623T035500Z/`](captures/visible-input-smoke-20260623T035500Z/).
  Its manifest records 18 normalized input rows, 43 reducer effects, final
  TextBox text `ab`, and a public `WM_CLOSE` close request.

Those tools are sufficient for W005's current evidence needs: find a visible
window, capture screen/window metadata, drive a fixed scenario, and validate the
emitted repo-owned trace artifacts. A new diagnostic script would mostly
duplicate this capability unless it also standardizes foreground/focus/UIA
metadata across both Office and OxForms windows; that is better filed as
follow-up harness hardening.

## Option Assessment

| Approach | Suitability now | Use in W005 evidence | Limitations |
|---|---|---|---|
| Top-level Win32 window enumeration and capture (`EnumWindows`, `GetWindowText`, `GetWindowRect`, process/class filters, DPI, screenshot) | Suitable and already in use. | Keep as the primary public inspection layer for both MSForms oracle windows and OxForms smoke windows. | It sees top-level windows, bounds, class/process/title/DPI, and pixels. It does not reveal MSForms control state or OxForms reducer state. |
| Public input injection (`SendInput`, current `SetCursorPos` plus `mouse_event`, `SendKeys`) | Suitable as an evidence driver around deterministic traces. | Continue using it for live desktop smoke/oracle runs, but prefer a future `SendInput` wrapper over legacy `mouse_event` for durable mouse and keyboard injection. | It is focus-sensitive, desktop-session-sensitive, DPI/coordinate-sensitive, and should never be the only verification path. |
| `PostMessageW(WM_CLOSE)` / public close request | Suitable only for close-request evidence when a normal user accelerator is insufficient. | Acceptable for smoke shutdown after recording the attempted user path, as done by the visible input smoke. | Do not use posted messages as a substitute for normal click/key input or event-order evidence. They can bypass ordinary input routing. |
| Windows UI Automation | Limited for W005. Useful as optional metadata, not as the driver of truth. | May record top-level window/control-pattern availability in future diagnostics. Do not use it to define OxForms control semantics. | `minifb` exposes a native window but not an OxForms control tree, because W005 controls are drawn by the smoke surface. Excel/MSForms may expose some automation elements, but the live VBA event log remains the oracle for FM20 behavior. |
| Microsoft Active Accessibility / `IAccessible` | Limited and not needed for current W005 acceptance. | Possible diagnostic supplement for Office/MSForms window/control discoverability. Not useful for OxForms `minifb` probe internals unless OxForms intentionally implements accessibility later. | Adding accessibility semantics to OxForms controls is explicitly out of scope for this bead and should be a future runtime/accessibility design effort, not test scaffolding. |
| WinEvent hooks / foreground/focus inspection (`GetForegroundWindow`, thread focus, focus events) | Promising as harness diagnostics. | File follow-up if future flaky runs need active-window/focus evidence around every input action. | Cross-process focus details can be timing-sensitive. Foreground/focus metadata explains delivery failures but does not prove control behavior. |
| Screenshot/pixel inspection | Suitable for capture metadata and visible-state evidence. | Keep for window geometry, rendered frame, and screenshot artifacts. Use coordinate-space tags from `COORDINATE_MODEL.md`. | Pixel evidence is theme/DPI/session-sensitive and cannot identify event ordering by itself. |

## MSForms Oracle Window Limitations

For Excel/MSForms oracle windows, the public automation path is acceptable for
driving a black-box scenario and collecting event logs:

- Excel/VBIDE automation creates and opens repo-owned fixtures, but event facts
  must come from public metadata or the fixture's own observed event log.
- Window enumeration and screenshot capture can record top-level `ThunderDFrame`
  metadata, bounds, DPI, and pixels.
- Mouse and key injection can drive representative scenarios if every injected
  action records the source coordinate space and raw action metadata.
- UI Automation or accessibility may expose Office/MSForms details on some
  systems, but W005 must not treat that as stable FM20 behavior unless it is
  captured as black-box evidence with source/tool/version notes.
- The event log, not the injected coordinate script, is the behavioral oracle.
  Missing rows are unobserved rows, not negative facts about MSForms.

Practical consequence: future MSForms oracle runs should keep the current
window/capture/action/event-log split. Add foreground/focus diagnostics only to
explain delivery failures, not to replace VBA event logging.

## OxForms Visible Smoke Limitations

For OxForms W005 visible smoke windows, public Windows automation should remain
even narrower:

- The `minifb` window is a raster surface. Windows UI Automation and
  accessibility cannot inspect Label, CommandButton, or TextBox probe state
  inside the surface unless OxForms later implements a real accessibility
  provider.
- The useful public inspection layer is therefore top-level window metadata,
  client geometry, screenshot/frame artifacts, and the repo-owned
  `visible-input-trace.json` emitted by the smoke.
- Coordinates in the current smoke intentionally use `client_pixels` to
  `form_logical` 1:1-with-scale projection for the test surface. This is useful
  W005 smoke evidence, not an MSForms DPI/chrome parity claim.
- Input injection should only prove that real Windows input reaches the same
  normalized `UiEvent` path. The reducer trace and headless replay remain the
  authoritative regression artifacts.

Practical consequence: do not attempt to make UI Automation inspect the W005
probe controls in this workset. If accessibility becomes a product requirement,
design it as a runtime feature later and test it separately.

## Decision

Accepted for W005 evidence infrastructure:

- public top-level window enumeration and screenshot capture;
- public input injection as a live smoke/oracle driver, with action logs and
  coordinate-space tags;
- public close requests for cleanup when the normal user accelerator has been
  attempted and recorded;
- optional foreground/focus diagnostics as harness troubleshooting metadata.

Rejected as current W005 verification authority:

- UI Automation or accessibility APIs as the source of OxForms control
  semantics;
- screen-coordinate automation as the only verification path;
- posted window messages as a general input substitute;
- private Windows or Office internals.

Recommended next path: keep the existing live drivers as auxiliary evidence,
add a small shared diagnostics layer only if future flakiness requires it, and
prefer `SendInput` for a durable replacement of the current `mouse_event`
calls. Do not expand OxForms runtime semantics in this bead.

## Follow-up Candidates

- Harden the public Windows input driver around `SendInput`, shared
  focus/foreground diagnostics, and common action-log schema for MSForms and
  OxForms W005 windows.
- Add an optional UI Automation / accessibility metadata probe that records
  discoverability for top-level Office/MSForms and OxForms smoke windows without
  using those APIs as behavioral truth.
