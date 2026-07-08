# W008 follow-up oracle capture plan (oxforms-uvh + oxforms-4f8)

Two W008 follow-ups need a live Excel/MSForms desktop session (a disruptive foreground drive).
The repo-owned fixtures are authored + headlessly compile-checked; this is the drive runbook so
the live session is fast and the captures formalize the same way as esq.14/15/17.

**OUTCOME (live run, 2026-06-29):**
- **oxforms-4f8 — CAPTURED + IMPLEMENTED.** Both drag-drop scenarios captured
  (`docs/evidence/W008_native_event_breadth/captures/w008-dragdrop-veto-20260629T103500Z`): a
  vetoing `BeforeDropOrPaste` suppresses the target drop (no `Change`); a drop is `Action=3`
  (fmActionDragDrop) vs `Action=2` for a keyboard paste. `reduce_drop_or_paste` now routes through
  the same two-stage defer as the keyboard paste (esq.17); bead closed.
- **oxforms-uvh — CLOSED AS ORACLE-UNREACHABLE NON-CLAIM.** Both the modeless AND a purpose-built
  MODAL harness were driven; held + discrete Escape logged only `KeyUp(27)` (no KeyDown, no Cancel
  Click) while a MOUSE click on the same CancelButton fired Enter+Click, and Alt+A triggered Excel's
  ribbon. **Excel intercepts Escape/Alt at the app level, before any MSForms form regardless of
  modality** — so cancel/accelerator key-activation is not capturable in the Excel oracle. The
  reducer Escape/accelerator arms stay repeat-blind as a documented non-claim. The modal harness
  (`ShowW008HeldCancelAccelModal` + scratchpad `w008_modal_driver.ps1`) is kept as reusable infra
  for future non-Escape/Alt modal captures. See [[oxforms-excel-oracle-harness]]. The bead was
  closed on 2026-07-08 after this blocker was promoted into `FM20_EVENT_FACTS.md`.

**Prep note:** both fixtures build + VBA-compile clean headlessly (`-DryRun` then `-CompileCheck`).
Gotcha hit + fixed during prep: a `vbaModuleName` >31 chars hangs the invisible-Excel build (VBA's
component-name limit → an invalid-name modal that blocks COM with no exception);
`w008-held-cancel-accel`'s module name was shortened from 32 → 28 chars (recorded in the
harness-gotcha memory).

The drive runbook below is retained as the record of how each scenario was driven.

Drive method: the background-COM host (a PowerShell driver holding `Excel.Application`
`Visible = true` with a ready/done sentinel-file handshake) + **computer-use vision** for the
genuine OS gestures (real key holds / mouse drags). Then export the worksheet to CSV and
formalize (a scratchpad `gen_*.ps1` builds the committed evidence dir + a
`Test-W008*CaptureEvidence.ps1` verifier). SendInput is NOT reliable for these (foreground
contention; see [[oxforms-excel-oracle-harness]]).

## Common harness (per capture, per scenario)

1. Build + show: `tools/office-oracle/New-W008OracleWorkbook.ps1 -FixtureDir <dir> -Show`
   (builds the `.xlsm`, opens Excel **visible**, runs the ClearLog + Show macros → the modeless
   form on screen, leaves Excel running for the drive).
2. Per scenario: run the `ClearLog` macro → the `Show` macro → the `SetW008Scenario<Name>` macro
   → the `FocusControl<...>` macro → drive the gesture (computer-use) → read the worksheet →
   export CSV (one CSV per scenario; the worksheet sequence restarts at 1 per clear).
3. Close with **SendKeys Alt+F4** (NEVER `PostMessage(WM_CLOSE)` — it kills Excel COM, RPC
   `0x800706BA`). Confirm no surviving `EXCEL.EXE`.

Gotchas (baked into the fixtures already): no design-time fonts (SaveAs-dialog hang); the
`Cancel`/`DragBehavior` properties are set at RUNTIME in `UserForm_Initialize`; enter the form
only via the Show macro (modeless). Do NOT modify any *committed* fixture — these two are new.

---

## oxforms-uvh — held Escape (cancel) / held Alt+accelerator

Fixture: `fixtures/office-oracle/excel-msforms/userforms/w008-held-cancel-accel`
(form `OxFormsW008HeldCancelAccel`; worksheet `W008HeldCancelAccelLog`;
`TextBox1` focus host + `CancelButton` (Cancel=True at runtime) + `AccelButton` ("&Apply" → Alt+A)).

**Question:** does a held Escape re-activate the Cancel button per OS auto-repeat, or **once**?
Same for a held Alt+accelerator. Bonus fact: does Escape / Alt+A **transfer focus** to the button
(like a default-button Enter transfers to Ok, esq.15), or activate in place?

### Scenario `held_escape_cancel`
1. `SetW008ScenarioHeldEscapeCancel`; `FocusControlW008HeldCancelAccel "TextBox1"`.
2. computer-use `hold_key` **Escape** for ~2.5s (a genuine OS hold), then release.
3. Read: count `CancelButton` `Click` rows. **One** = single activation (→ gate the Escape arm on
   `!is_repeat`, matching esq.12/esq.15). **>1** = repeats activate. Note `focus_owner_after` on the
   activation rows (does focus move to `CancelButton`?). Expect a leading `TextBox1` `KeyDown(27)`.

### Scenario `held_alt_accelerator`
1. `ClearLog`; `Show`; `SetW008ScenarioHeldAltAccelerator`; focus `TextBox1`.
2. Genuine Alt+A hold: press-and-hold **Alt**, then hold **A** ~2.5s. CAVEAT: holding a two-key
   chord is awkward to inject cleanly. If a clean hold isn't reachable, a single Alt+A press still
   establishes the single-activation + focus-transfer facts — record in the run-summary that the
   accelerator's repeat-COUNT is single-press-only (the same caveat shape as the esq.15 held-Enter
   capture; the COUNT is what's consumed).
3. Read: count `AccelButton` `Click` rows.

**Implementation conclusion shape:** if held activation is once (matching esq.12/esq.15), gate
`reduce_key_down`'s `KeyCode::Escape` (cancel) arm and the `KeyCode::Character` + alt accelerator
arm on `!payload.repeat.is_repeat` + regression tests; record in `FM20_EVENT_FACTS.md`. If focus
transfers to the button, that is a separate emission fact — note it (esq.15 left both arms
repeat-blind; the scope comment at the Escape arm already points at this bead).

---

## oxforms-4f8 — drag-drop BeforeDropOrPaste veto

Fixture: `fixtures/office-oracle/excel-msforms/userforms/w008-dragdrop-veto`
(form `OxFormsW008DragDropVeto`; worksheet `W008DragDropVetoLog`; `SourceBox` seeds
"OxFormsDragSeed" + `DragBehavior` enabled at runtime; `TargetBox` has the armable
`BeforeDropOrPaste` veto via `gVetoDrop`).

**Question:** does a vetoing `BeforeDropOrPaste` (Cancel=True) suppress a **drag-drop** drop
(no `Change`, `TargetBox` unchanged), like the keyboard paste (esq.17)? What `Action` value does a
drop carry (vs `Action=2` for a keyboard paste)?

### Scenario `dragdrop_baseline`
1. `SetW008ScenarioDragDropBaseline`; `FocusControlW008DragDropVeto "SourceBox"`.
2. Select the SourceBox text (triple-click, or Home then Shift+End), then computer-use
   `left_click_drag` from inside `SourceBox` to inside `TargetBox` — **as discrete steps**
   (press inside SourceBox → move in increments across the gap → dwell → release inside TargetBox)
   so MSForms trips the drag threshold.
3. Expect: `TargetBox` `BeforeDropOrPaste`(Cancel False→False) → `Change`(value=OxFormsDragSeed) →
   `TargetBox` value updated. Records the drop's `Action` value (in `notes`).

### Scenario `dragdrop_veto`
1. `ClearLog`; `Show`; `SetW008ScenarioDragDropVeto`; focus `SourceBox`.
2. Select + drag `SourceBox` → `TargetBox` (gVetoDrop armed → `TargetBox_BeforeDropOrPaste` sets
   Cancel=True).
3. Expect: `TargetBox` `BeforeDropOrPaste`(Cancel False→True) → **NO** `Change` → `TargetBox`
   unchanged (suppressed).

CAVEATS (drag-drop is the finicky gesture):
- MSForms intra-form drag needs `DragBehavior` on the source (set) + a genuine press-move-release
  with enough travel + a dwell so the drag threshold trips; a single-shot drag call may not
  register — drive it as explicit press → stepped move → release.
- If the drag won't initiate (selection collapses / threshold not tripped), that is a DRIVE
  problem, not a behavior fact — iterate the gesture; **do not fabricate rows**.
- A drop's `Action` enum value is unknown until captured (paste=2; drag-drop likely differs) —
  record as observed, do not assume.

**Implementation conclusion (LANDED in esq.4f8):** the vetoing drag-drop `BeforeDropOrPaste` does
suppress the drop, so `reduce_drop_or_paste` was routed through the same two-stage defer as esq.17
(fire `BeforeDropOrPaste` first with the value unchanged, defer the insert to the shared
`pending_paste_commit`, drop on veto) + tests; `FM20_EVENT_FACTS.md` updated and the former
recorded-not-honored marker at `reduce_drop_or_paste` removed.

---

## Formalization (both, after the live capture)

Mirror esq.14/15/17 exactly:
1. A scratchpad `gen_<name>_capture.ps1` builds the committed
   `docs/evidence/W008_native_event_breadth/captures/<id>/` dir from the **genuine** captured CSV
   rows: `oracle-capture-manifest.json` + `run-summary.json` + event-log `.json`/`.csv` +
   `input-actions.json` + `README.md` + `.gitattributes` (`eol=crlf`) + `checksums.sha256`.
   `generated_workbook = null`; `capture_tool` = `tools/office-oracle/New-W008OracleWorkbook.ps1`;
   the fixture-input sha256s are re-hashed from the committed fixture sources.
2. A `Test-W008<Name>CaptureEvidence.ps1` verifier: re-hash the fixture inputs + capture_tool, the
   checksum manifest, the schema/bead strings, the declared scenarios, AND the **consumed
   behavioral facts** — uvh: exactly one `Click` per held scenario + the `KeyDown→…→Click` shape;
   4f8: `paste`/`dragdrop_veto` BeforeDropOrPaste `arg_after=True` + **zero** `Change`,
   `dragdrop_baseline` `arg_after=False` + exactly one `Change`.
3. `git add` the capture dir + verifier; `tools/Run-EvidenceChecks.ps1` (GitTrackedOnly picks up
   the new `checksums.sha256`). Then implement each bead to the evidence through the standing loop
   (implement → adversarial review → floor → commit → close).

Evidence-fidelity rules (from the esq.15 review): a `docs/specs/...` citation in a manifest/code
must be TRUE (update the doc in the same change); disclose author-added vs fixture-captured `notes`
fields and per-run sequence resets in the event-log `source.note`; `row_count` counts all CSV rows
incl. the per-run setup rows while `scenario_summaries` enumerate only scenario-tagged rows.
