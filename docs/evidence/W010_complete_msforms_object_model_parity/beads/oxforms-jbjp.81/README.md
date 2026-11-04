# Preserve repaint changes until presentation

Real clicks moved the greeter's reducer focus correctly but left old textbox
selection/caret and checkbox focus pixels visible. The workbook regression
proves that VBA removes the old caret and checkbox StrokeRect primitives.
The Windows consumer had replaced the damage from mouse-down with mouse-up's
damage before winit delivered RedrawRequested.

The consumer now combines all regions not yet presented, even if a later
snapshot contains no changes, and clears them after successful presentation.
It still repaints only damaged regions. No control behavior or forced full
repaint was added. A regression submits two independent producer snapshots and
an empty resubmit before one 150% frame. It failed before this fix and now
matches a full raster byte for byte.

2026-11-05 physical clicks in the rebuilt Windows/VM3 greeter move focus from
InputName to Loud to Greet. The old caret and checkbox outline disappear;
native Excel and CalcForms both end with the original-handler state
`Initialize|Check:True|Click:HELLO, ADA;text=Ada;caption=HELLO, ADA;loud=True`.
The before image uses Adaj from the earlier letter/Tab/drag sequence; its text
differs, so no whole-image before/after pixel score is claimed. Inspect the
old selection/checkbox outline and their absence after the fix. Solid versus
dotted active focus and other font/border differences remain `.76` work.

`comparison.json` and four compact client images retain hashes and equal states
within each native/runtime pair. Raw Windows captures and real-input logs remain
under `C:/Work/DnaCalc/codex-runs/forms-captures/round3-input-final/` and
`round3-focus-fixed/`. Both sessions attach to the same owned Excel PID 49844,
launch zero additional Excel processes, close their own runtimes, and retain
Excel for the original session. Every physical action used desktop.lock.

Fresh review checked producer versus consumer damage, empty resubmits, resize/
first-frame behavior, presentation failure handling, actual original-handler
state, and the captured focus changes. Focus remains VBA-owned; the PAL only
retains generic rectangles until their pixels have been presented.
Validation: 195 Rust tests passed (seven existing ignored), format and clippy
passed, and all 48 evidence checks passed. The aggregate first reported a stale
byte fingerprint for the added evidence-check entry. After its reviewed refresh,
the failed ledger check passed all 95 tests, regeneration and checksums; the
other 47 checks had passed. No ledger row statuses changed.
