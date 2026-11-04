# Intrinsic layout comparison

2026-11-05, Windows, Excel 16.0 build 20527, CalcVBA VM3. The command compares
the real workbook with its original handlers, plus three authored forms with
23 controls covering all 14 intrinsic kinds and nested Frame children. Both
engines request Tahoma 8.25. The authored cases construct production VBA controls;
they grant no binary-persistence or full API parity credit.

| Form | Client pixels at 100% / 150%, both engines | Different pixels at 100% / 150% | Largest bounds difference |
|---|---|---|---|
| Workbook greeter | 384×174 / 576×261 | 4.77% / 3.75% | 0.0126pt |
| Common and fractional sites | 400×240 / 600×360 | 7.65% / 6.11% | 0.025pt |
| Selection and lists | 440×280 / 660×420 | 12.43% / 11.83% | 0.75pt |
| Containers and navigation | 520×380 / 780×570 | 9.16% / 9.16% | 0pt |

Native ComboBox coerces requested Height=21 to 21.75pt. Fractional Label bounds
12.375/74.625/123.375/17.625 become 12.4/74.65/123.35/17.65 in Excel. The tool
reports these differences; no unproved universal rounding rule was added.
Greeter source bounds retain the small persisted HIMETRIC conversion difference.
At 150%, the native Frame reports Font.Size=8.5 after Zoom (8.25 at 100%).
Native Image has no tab index; consequently TabStrip/MultiPage report 3/4 while
their VBA Core values are 4/5. The comparison retains this difference. Active
focus/caret and native repaint timing affect exact pixel counts between runs.

The saved workbook face was previously discarded and Windows loaded micross.
`.82` retains Tahoma and converts design-em points for both ab_glyph shaping and
painting. Correcting the font alone slightly increased pixel differences
(7.87→7.99% / 7.04→7.14%); it fixes the font contract, not GDI hinting. Combined
with the measured palette corrections, the greeter now differs by 4.77%/3.75%,
versus the original 26.80%/25.93%. No new W010 ledger rows receive parity credit.

Inspect the compact references beside `comparison.json`. It records image
hashes, window styles/titlebar offsets, native control/font/tab facts, live VBA
control bounds/tab indices, text-run metrics, pixel errors and process ownership.
Raw full windows, differences, Scenes, generated forms, executables and logs
remain under `C:/Work/DnaCalc/codex-runs/forms-captures/round3-composited/`.
Earlier parent-only ListBox captures that omitted native owner-drawn rows are
excluded; these references composite captures of visible owned child HWNDs in
z order, clipped to each parent client. They show all three rows at both scales.

Known visible gaps: textbox inset/baseline, border and dotted focus details;
square radio glyphs; concatenated ListBox rows and tab captions; missing Frame
caption/border, nested input clipping and missing MultiPage painting. Existing
W010 control lanes own these gaps. Titlebar styles also differ. Initial tab
indices are measured; this capture is not a complete physical tab/accelerator/
drag test. Real greeter click/Ctrl+A/clipboard-paste results live in `.80`.
`real-input.json` adds actual letter-key, Tab/Return and drag observations.
Typing `j` changes Ada to Adaj in both original handlers; Tab reaches Greet,
and Return produces Hello, Adaj in both. Dragging responds in both controls and
does not change application state; equal selection ranges are not established.
The original greeter has no accelerator, so this is not an accelerator test.
The retained runtime trace distinguishes CharacterInput and key events from
the earlier Ctrl+V clipboard insertion. Every input used the shared lock.

Reproduce using the build and command in
[the comparison contract](../../../../specs/LAYOUT_COMPARISON.md). This batch
attached to the one original owned Excel PID 49844 and launched zero additional
Excel processes. It closed all eight CalcForms windows and its authored book,
then retained Excel for the original session's final cleanup. No Office security,
registry, original workbook bytes or unrelated processes were changed.

Fresh review checked both scales visually, nested names/parents, ListBox content,
raw versus compact hashes, geometry parsing, named font loading, design-unit
scaling and exact-process cleanup paths. The comparator tests reject duplicate
native descendants and retain native size coercion/missing controls as failures
to compare, rather than silently dropping them. Pixel parity is not claimed.
The reviewed adapter token changes only export the existing library roster and
host prefix configuration for the authored driver. Source fingerprints were
regenerated; the ledger remains 7,753 rows, 2,452 verified, 4,682 gaps and 619
unexpected-public rows, green=false. Validation: Rust format/clippy, 193 passed
tests (seven existing ignored), comparator tests and 47/47 evidence checks.
