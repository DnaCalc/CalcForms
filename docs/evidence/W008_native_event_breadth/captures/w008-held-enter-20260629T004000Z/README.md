# W008 Held default-button Enter Oracle Capture

Capture id: w008-held-enter-20260629T004000Z
Bead: `oxforms-esq.15`
Status: `captured`

Black-box Excel/MSForms evidence for whether a held Enter re-activates a Default CommandButton
per OS auto-repeat. Not an OxForms output comparison and not an exhaustive parity claim.

## Facts

- `held_enter_default`: a sustained computer-use Enter hold on a focused TextBox host with a
  Default OkButton produced ONE `TextBox1` KeyDown(13), then the default button's
  `Enter -> Click -> KeyUp(13)`. The default button activates EXACTLY ONCE for the captured
  hold. oxforms-esq.15 gates the default-button Enter activation on `!KeyRepeat.is_repeat` so
  OS auto-repeat Enter KeyDowns neither re-transfer focus nor re-Click (mirrors the CheckBox
  toggle gate, esq.12).
- **Consumed fact:** esq.15 consumes ONLY the activation COUNT (one Click for the captured
  hold).
- Caveat (duration): the ~2.5s hold is operator-applied input metadata (`input-actions.json`),
  not a worksheet observation -- the event log has no timestamp column.
- Caveat (single duration): unlike esq.12 (which ran BOTH 1.0s and 2.5s to demonstrate
  invariance over hold time), this is a single hold; the single non-multiplying KeyDown is
  consistent with single activation but does not independently measure hold-time invariance.
- Caveat (repeats): it is not separately confirmed that the OS key-hold emitted repeat
  WM_KEYDOWNs; the single logged KeyDown is the evidence the activation does not multiply.

## Driving method (honest provenance)

Driven by computer-use hold_key (a genuine OS key-hold) on a background-COM-hosted Excel
running the committed `w008-held-key` fixture (it already carries a Default OkButton set at
runtime plus OkButton Enter/Click/KeyDown/KeyUp handlers). `generated_workbook` is null --
the throwaway workbook was not retained; the fixture sources + `Capture-W008HeldKey.ps1`
regenerate it deterministically.

Held Escape (cancel button) and held Alt+accelerator activation repeat behavior were NOT
captured this session and are not claimed.

## Clean-room Note

Repo-owned fixture sources, public Excel/VBIDE automation, a public OS key-hold, and worksheet
export only. No Office internals, decompilation, disassembly, or OxForms output comparison.