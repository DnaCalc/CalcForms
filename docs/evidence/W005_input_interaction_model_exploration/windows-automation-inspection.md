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

## Keyboard SendInput Follow-up

Follow-up bead `oxforms-8nj` evaluated whether the W005 Office oracle and
visible-smoke drivers should replace `System.Windows.Forms.SendKeys` text and
accelerator sequences with a diagnostics-only public `user32.SendInput`
keyboard helper. The decision is to defer that replacement and keep `SendKeys`
for the existing text/accelerator rows.

Reasons:

- The current committed W005 captures already validate the intended auxiliary
  coverage with `SendKeys` for text/accelerators and shared `SendInput` for
  mouse. No evidence in the existing action logs or validators shows that
  `SendKeys` is the source of a live-driver failure that would justify changing
  the input driver for the preserved captures.
- A robust keyboard `SendInput` wrapper is not just the existing mouse helper
  with a different flag. It needs a separate public interop surface for
  `KEYBDINPUT`, virtual-key versus scan-code versus Unicode packet behavior,
  modifier down/up ordering, key-up cleanup on partial failure, and action-log
  fields that distinguish text characters from physical accelerator chords.
- W005 must not infer keyboard parity from injected input alone. Replacing the
  current driver now would risk making the live automation look more precise
  than the evidence supports, especially for `{TAB}`, `+{TAB}`, `{ENTER}`,
  `{ESC}`, `%o`, `%c`, and `%{F4}` rows whose real behavioral facts still come
  from the MSForms event log or the OxForms normalized trace.
- The current helper already records the useful foreground/focus diagnostics
  around key actions through `Set-W005ForegroundWindow` and
  `Get-W005InputDiagnosticsSnapshot`. Those diagnostics explain delivery risk
  without adding a second keyboard injection semantics layer.

Migration criteria for a future bead:

- concrete evidence that `SendKeys` fails or is too nondeterministic for a
  required W005 text/accelerator row on a supported Windows session;
- non-live parse/import/type-size checks for the keyboard interop structs before
  any live injection is attempted;
- a diagnostics-only helper that records compatible additive fields
  (`input_driver`, `coordinates`, and `diagnostics`) while explicitly separating
  `text_unicode`, `virtual_key`, `scan_code`, `modifiers`, requested events,
  sent events, and cleanup results;
- isolated live validation, if needed, that proves only driver delivery into the
  test surface, not MSForms or OxForms keyboard parity.

Until those criteria are met, `SendKeys` remains the safer evidence driver for
W005 text/accelerator rows, and public `SendInput` remains limited to the
mouse-click and mouse-drag helper paths.

## Optional UIA/MSAA Metadata Probe

Follow-up bead `oxforms-xvx.22` added a diagnostics-only UI Automation metadata
probe at [`../../../tools/W005AccessibilityMetadataProbe.ps1`](../../../tools/W005AccessibilityMetadataProbe.ps1).
The probe is intentionally opt-in: it does not launch Excel, does not run the
OxForms visible smoke, does not drive live input, and does not change OxForms
runtime behavior. It selects a top-level window by explicit handle or by
title/process filters, records public Win32 top-level window metadata, and asks
the public .NET `UIAutomationClient` API for the selected window's root element
plus a bounded child-depth snapshot.

Typical optional invocations, to be run only against an already isolated live
oracle or smoke window, are:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\W005AccessibilityMetadataProbe.ps1 `
  -TitleContains "OxForms W005 Interaction Oracle" -ProcessName EXCEL -ChildrenDepth 1 `
  -OutFile docs\evidence\W005_input_interaction_model_exploration\captures\<capture>\uia-msforms-top-level.json

powershell -NoProfile -ExecutionPolicy Bypass -File tools\W005AccessibilityMetadataProbe.ps1 `
  -TitleContains "OxForms W005 Visible Input Smoke" -ProcessName w005_visible_input_smoke -ChildrenDepth 1 `
  -OutFile docs\evidence\W005_input_interaction_model_exploration\captures\<capture>\uia-oxforms-smoke-top-level.json
```

The output schema is `oxforms.w005.accessibility_metadata_probe.v1`. Its
`non_claims` field is part of the artifact contract: UIA metadata is public
discoverability evidence only, not a source of FM20 event ordering, not an
OxForms probe-control oracle, and not a runtime accessibility feature.

MSAA / `IAccessible` traversal is deferred for W005. The current W005 question is
whether public automation metadata can help diagnose top-level window
discoverability. Bounded UIA metadata is enough for that narrow diagnostic; an
MSAA traversal would add another COM surface without changing the W005 behavior
evidence, and could easily make the evidence look more authoritative than it is.
If accessibility becomes a product requirement, it should be designed as a
separate runtime/accessibility capability with its own semantics and tests.

### MSForms Oracle Window Probe Limits

For Excel/MSForms oracle windows, the optional probe may record whether the
top-level `ThunderDFrame` window and any public UIA children are discoverable on
the capture machine. That metadata is environment- and Office-version-specific.
The preserved behavioral truth remains the repo-owned fixture event log and the
existing window/screenshot/action manifests. UIA names, control types, supported
patterns, or child counts must not be promoted into FM20 control semantics.

### OxForms Visible Smoke Probe Limits

For OxForms visible smoke windows, the optional probe may record top-level
`minifb_window` discoverability. The W005 probe controls are raster-drawn inside
that window, so UIA should not be expected to expose a Label, CommandButton, or
TextBox tree. The authoritative OxForms evidence remains the repo-owned
`visible-input-trace.json`, screenshot/frame artifacts, and headless replay
goldens.

## Evidence Read

Current W005 evidence already uses public Windows desktop APIs:

- `tools/office-oracle/Capture-W005InteractionEvents.ps1` drives the Excel /
  MSForms oracle through public Excel/VBIDE automation, `EnumWindows`,
  `GetWindowRect`, screenshot capture through
  `tools/office-oracle/Capture-Window.ps1`, and the shared
  `tools/W005WindowsInputDiagnostics.psm1` helper for foreground/focus/window
  diagnostics plus public `SetCursorPos` / `SendInput` mouse injection.
- `tools/w005-visible-input/Invoke-W005VisibleInputSmoke.ps1` locates the
  OxForms `minifb` smoke window, records client geometry, drives mouse and key
  input, captures a screenshot, and records `visible-input-actions.json`. Mouse
  actions use the same shared `SendInput` helper as the MSForms oracle driver;
  text and accelerator input still use `System.Windows.Forms.SendKeys`.
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
emitted repo-owned trace artifacts. The shared diagnostics helper added by
`oxforms-xvx.23` standardizes the auxiliary action metadata that had previously
been split between the Office oracle and OxForms visible smoke drivers:

- foreground/window/focus snapshots before and after foreground transitions;
- target-thread GUI focus/capture/caret metadata through public
  `GetGUIThreadInfo`;
- cursor position and target window summaries around mouse and key actions;
- normalized additive action-log fields: `input_driver`, `coordinates`, and
  `diagnostics`, while preserving the existing required schema fields.

## Option Assessment

| Approach | Suitability now | Use in W005 evidence | Limitations |
|---|---|---|---|
| Top-level Win32 window enumeration and capture (`EnumWindows`, `GetWindowText`, `GetWindowRect`, process/class filters, DPI, screenshot) | Suitable and already in use. | Keep as the primary public inspection layer for both MSForms oracle windows and OxForms smoke windows. | It sees top-level windows, bounds, class/process/title/DPI, and pixels. It does not reveal MSForms control state or OxForms reducer state. |
| Public input injection (`SendInput`, `SetCursorPos`, `SendKeys`) | Suitable as an evidence driver around deterministic traces. | Use the shared helper for mouse actions in live desktop smoke/oracle runs; keep `SendKeys` only for text/accelerator sequences until a keyboard `SendInput` wrapper is separately justified. | It is focus-sensitive, desktop-session-sensitive, DPI/coordinate-sensitive, and should never be the only verification path. |
| `PostMessageW(WM_CLOSE)` / public close request | Suitable only for close-request evidence when a normal user accelerator is insufficient. | Acceptable for smoke shutdown after recording the attempted user path, as done by the visible input smoke. | Do not use posted messages as a substitute for normal click/key input or event-order evidence. They can bypass ordinary input routing. |
| Windows UI Automation | Limited for W005. Useful as optional metadata, not as the driver of truth. | May record top-level window/control-pattern availability in future diagnostics. Do not use it to define OxForms control semantics. | `minifb` exposes a native window but not an OxForms control tree, because W005 controls are drawn by the smoke surface. Excel/MSForms may expose some automation elements, but the live VBA event log remains the oracle for FM20 behavior. |
| Microsoft Active Accessibility / `IAccessible` | Limited and not needed for current W005 acceptance. | Possible diagnostic supplement for Office/MSForms window/control discoverability. Not useful for OxForms `minifb` probe internals unless OxForms intentionally implements accessibility later. | Adding accessibility semantics to OxForms controls is explicitly out of scope for this bead and should be a future runtime/accessibility design effort, not test scaffolding. |
| Foreground/focus inspection (`GetForegroundWindow`, `GetFocus`, `GetGUIThreadInfo`) | Accepted as harness diagnostics. | Record around foreground transitions and input actions in both W005 drivers. | Cross-process focus details can be timing-sensitive. Foreground/focus metadata explains delivery failures but does not prove control behavior. |
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
window/capture/action/event-log split. Foreground/focus diagnostics are now
recorded to explain delivery failures, not to replace VBA event logging.

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
  coordinate-space tags; mouse actions use public `SendInput` through
  `tools/W005WindowsInputDiagnostics.psm1`;
- public close requests for cleanup when the normal user accelerator has been
  attempted and recorded;
- foreground/focus diagnostics as harness troubleshooting metadata.

Rejected as current W005 verification authority:

- UI Automation or accessibility APIs as the source of OxForms control
  semantics;
- screen-coordinate automation as the only verification path;
- posted window messages as a general input substitute;
- private Windows or Office internals.

The hardened path remains auxiliary evidence plumbing: keep the existing live
drivers as supplementary evidence, keep headless trace/replay as the canonical
verification spine, and do not expand OxForms runtime semantics from these
helpers.

## Follow-up Candidates

- Consider a diagnostics-only `SendInput` keyboard wrapper if future evidence
  shows `SendKeys` is too flaky for text/accelerator rows. Keep it separate from
  runtime input semantics.
