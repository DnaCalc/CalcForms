# W006 IME / Dead-Key Oracle — Capability Blocker

Bead: `oxforms-0a0.18`
Status: **precisely blocked** (capability + environment), with a concrete path forward.
Date: 2026-06-27

This note records why deterministic Excel/MSForms IME-composition and dead-key
preedit oracle evidence is **not** captured by public automation in the current
environment, per the bead's "design and, if public Windows/Office setup permits,
capture … or preserve exact tooling/environment blockers." It does not infer
MSForms behavior from missing rows and implements no OxForms runtime behavior.

## Start-reading / scope

- `docs/evidence/W006_control_implementation_rollout/text-service-transfer-oracle.md`
- `docs/specs/INPUT_INTERACTION_MODEL.md` §5.4 (deferred IME/composition surface)
- `docs/specs/FM20_EVENT_FACTS.md` (W006 deferred input-surface fact split)
- W006 TextBox fixture: `fixtures/office-oracle/excel-msforms/userforms/text-service-transfer/`

The target was: against the W006 TextBox fixture, record the live
`KeyDown` / `KeyPress` / `KeyUp` / `Change` ordering and any
composition / preedit rows that MSForms raises for (a) an IME composition and
(b) a dead-key (accent) sequence, with the active input method/keyboard layout
explicit and reproducible **before** any parity claim.

## Capability blocker (the load-bearing finding)

1. **IME composition is not reproducibly drivable by public input injection.**
   IME composition (`WM_IME_STARTCOMPOSITION` / `WM_IME_COMPOSITION` /
   `WM_IME_ENDCOMPOSITION` and the candidate UI) is produced by the **IME engine**
   in response to its own state machine, not by raw scancodes. `SendInput` (the
   public injection path used by the other W006 captures) delivers virtual-key /
   scancode events; it does **not** synthesize an IME composition session, and
   there is no public, reproducible way to drive a specific IME's
   compose/convert/commit sequence headlessly. So the composition/preedit rows
   the bead asks for cannot be produced honestly by this harness.

2. **Dead-key (accent) sequences are tractable but environment-dependent.**
   A dead-key sequence (e.g. US-International `´` then `e` → `é`) is ordinary
   keystroke input once the right keyboard layout is the active layout for the
   form's input thread. This *could* be captured with `SendInput` — but only if a
   specific layout (e.g. US-International, `00020409`) is installed and activated
   for the session, which is an explicit environment precondition this host does
   not guarantee, and which must be pinned for the result to be reproducible.

3. **The interactive desktop must be unlocked.** Like every other W006 SendInput
   capture, this needs an interactive, unlocked desktop session
   (`SetForegroundWindow` + `SetCursorPos`/`SendInput` fail on a locked/secure
   desktop). During this bead's window the session idle-locked, which on its own
   prevents any input-driven attempt.

## What a future capture would record (design)

If run on an interactive desktop with a **pinned** keyboard layout:

- **Dead-key path:** activate the layout via public `LoadKeyboardLayout` /
  `ActivateKeyboardLayout` (recording the KLID in the manifest), focus the
  TextBox, inject the dead-key + base-letter scancodes via `SendInput`, and
  export the fixture's `KeyDown` / `KeyPress` / `KeyUp` / `Change` rows. The
  expectation to test is whether MSForms raises a single combined `KeyPress`
  for the composed character and the `Change` ordering around it.
- **IME composition path:** remains a documented limitation — record the exact
  IME and note that composition is engine-driven and not reproducibly injectable
  by public automation; any future evidence would need an IME-specific test
  harness or manual operation, which is out of scope for the clean-room public
  automation contract.

## Non-claims / clean-room

- No OxForms runtime IME, composition, dead-key, or text-service behavior is
  implemented or claimed by this note.
- Absence of rows is unobserved capability, not a negative fact about MSForms.
- No Office internals, decompilation, disassembly, non-public source, or OxForms
  output comparison were used.
