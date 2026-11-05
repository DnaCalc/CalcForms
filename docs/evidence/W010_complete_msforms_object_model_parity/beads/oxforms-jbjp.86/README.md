# Control pixel priorities

`control-ranking.json` recomputes every root-control region in the eight compact
`.79` references. It uses the union of native/runtime bounds, rounds outward to
pixels, clips to the client, and ranks by total absolute RGB error. Scale comes
from native form/client dimensions, so monitor DPI is not assumed. Regions can
overlap: a Frame region includes its children, and totals must not be added.
Nested sites are explicitly excluded until native parent client origins are
measured. Unequal clients and failed capture qualification produce no ranking.

| ListBox Choices | Different region pixels | Total absolute RGB error |
|---|---|---|
| 100% | 5,012 / 16,704 (30.00%) | 1,803,258 |
| 150% | 11,205 / 37,440 (29.93%) | 4,243,576 |

Choices has the largest total error in the recorded corpus at both scales.
These are historical `.79` pixels, preceding the later textbox and Frame fixes;
they are not a new live capture or a whole-control parity threshold. The absent
historical per-capture qualification flag remains null. `.84` separately
corroborates the grey native page and adds live qualification for future runs.
No additional Excel process or desktop input was needed for this analysis.

The source explains the visible list text: ListBox.JoinedDisplayText joins rows
with LF; UserForm.MeasureControls submits one request for that whole string;
OxThemePaintListBox paints its one RunId. AbGlyphShaper currently advances every
character horizontally, including LF. TabStrip.PaintTab also reuses its joined
caption run for every tab. Fix these in `.23`/`.33` with separate row/tab runs
through the existing batched measurement path. Measure native row spacing and
selection text colors before choosing layout; the current VBA 14pt row constant
is not a measured native fact. Control layout and selection remain VBA-owned.

Future `layout_compare.py` captures include `control_pixels` and the three
largest regions in the session summary. Replay this committed reference without
Office or desktop access:

```
python -B tools/office-oracle/layout_pixels.py --reference docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.79/comparison.json --check docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.86/control-ranking.json
```

Review checked union bounds, fractional rounding, offscreen clipping, independent
x/y scale, deterministic ranking, capture rejection and explicit nested skips.
Focused tests use known changed pixels and exact error totals; replay checks all
eight image pairs and their hashes. Existing `.79` observations are preserved.

Validation passed: five comparator tests, eight-case replay, both command help
paths, all 51 evidence checks, document links, whitespace and bead graph. The
production tree remains the 196-test passing tree (seven existing ignored)
with format/clippy green; this change touches comparison tools/docs only.
