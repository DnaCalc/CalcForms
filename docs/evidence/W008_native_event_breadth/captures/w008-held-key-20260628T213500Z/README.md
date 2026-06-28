# W008 Held-Key (CheckBox Space) Oracle Capture

Capture id: w008-held-key-20260628T213500Z
Bead: `oxforms-esq.12`
Status: `captured`

Black-box Excel/MSForms evidence for whether a held Space auto-repeats the keyboard CheckBox
toggle. Not an OxForms output comparison and not an exhaustive parity claim.

## Facts

- `held_space_checkbox`: holding Space on a focused, unchecked CheckBox for BOTH 1.0s and
  2.5s produced the IDENTICAL log -- exactly one KeyDown(32), one KeyUp(32), one
  Change(Value True), one Click(Value True) (4 toggle events; the 6-row log also has the
  Initialize + TextBox1 Enter setup rows). The toggle fires EXACTLY ONCE; it does not
  multiply with hold time. So oxforms-esq.8's toggle-on-every-KeyDown is safe against held
  keys, and oxforms-esq.12 gates the toggle on `!KeyRepeat.is_repeat` to guarantee it.
- **Consumed fact:** esq.12 consumes ONLY the toggle COUNT (one Change/Click regardless of
  hold time), not the intra-press dispatch order.
- Caveat (count): not separately confirmed that the genuine OS key-hold emitted repeat
  WM_KEYDOWNs; the identical 1.0s-vs-2.5s output is the evidence the toggle does not multiply.
- Caveat (order divergence): this held capture logged `KeyDown -> KeyUp -> Change -> Click`
  with value_after=False at KeyDown -- the INVERSE of the esq.8 discrete-press capture
  (`checkbox-keyboard-toggle-20260627T220935Z`: `Change -> Click -> KeyDown(value True) ->
  KeyUp`, value-first). esq.8 value-first stands for discrete keystrokes and is what the
  reducer implements; whether the held order is genuinely press-duration-dependent or an
  artifact of the vision-driven hold/release interleaving is UNSETTLED and not consumed here.

## Driving method (honest provenance)

Driven by computer-use hold_key (a genuine OS key-hold) on a background-COM-hosted Excel.
`generated_workbook` is null -- the throwaway workbook was not retained; the fixture sources
+ `tools/office-oracle/Capture-W008HeldKey.ps1` regenerate it deterministically.

The held default-button Enter (`held_enter_default`) was NOT captured this session and is
deferred to a follow-up bead.

## Clean-room Note

Repo-owned fixture sources, public Excel/VBIDE automation, a public OS key-hold, and worksheet
export only. No Office internals, decompilation, disassembly, or OxForms output comparison.