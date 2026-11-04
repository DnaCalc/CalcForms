# Windows form layout comparison

The compatibility reference is the same owned/authored form in Excel MSForms.
Capture each engine's complete window with PrintWindow and crop the client area
using GetClientRect and ClientToScreen. Store both coordinate descriptions;
never infer the client origin from a screenshot border or compare differently
sized client areas by stretching them.

Compare 100% and a second form zoom on the same desktop DPI. The initial second
zoom is 150%. Excel's Zoom scales contents; enlarge its client area separately
using InsideWidth/InsideHeight. The CalcForms host's `--scale` changes window
size while the retained Scene remains in form points. This checks form zoom,
not a change in Windows monitor DPI. The workbook's twips and persisted
HIMETRIC control bounds remain the source geometry.

Record client and outer sizes, origins, styles, source control bounds, fonts,
tab indices, original-handler state, image hashes, fraction of different
pixels and mean absolute channel errors. Keep title bars separate from client
metrics. A lower pixel error is an improvement, not a parity claim. Keep focus,
caret, active/inactive state and input method explicit when interpreting pixels.

`tools/office-oracle/layout_compare.py` currently captures the real workbook
greeter at both scales in one owned Excel session. The authored all-intrinsic
corpus and complete physical-input comparison are `.79` work. The Windows host
can optionally emit its resident Scene using `--dump-scene`; this is an
observation of the production runtime, not an alternate control implementation.

The theme/control VBA owns paint and control layout; the PAL retains generic
primitives, text metrics, rasterization and window services. The November
greeter correction uses form-background/black labels, top-aligned label text,
smaller white checkbox glyphs with a check mark, a 13.5pt caption offset and a
caption-sized focus rectangle. Border style, font rasterization and exact
focus-dot matching remain separate measured differences.

Real Ctrl+A exposed a Windows text normalization error: winit's `KeyEvent.text`
ignores Control, so a correct select-all KeyDown was followed by an unwanted
`a` CharacterInput. The backend now uses `text_with_all_modifiers()` and filters
non-printing control characters. Printable AltGr text remains eligible. This
normalizes platform input; shortcut/edit semantics continue to belong to VBA.

On the owner's input desktop, use the exclusive shared desktop.lock for every
operation that may activate or inject input. Fail while a live lock exists;
only a lock older than five minutes is stale. Keep each hold below two minutes
and perform no input outside the owner window (stop by 06:55 machine time).
Prefer private-desktop batch capture when physical input is unnecessary. Never
change Office security, registrations or another process's state. Record the
owned Excel launch count and final exact-process cleanup.
