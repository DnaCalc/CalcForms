# Current CalcForms source comparison

Regenerated with the existing W010 tools for the 2026-11-04 rename and CalcVBA
update (oxforms-jbjp.73). The September .4 artifact remains byte-for-byte intact
for the .5 captured oracle and .6 facade contract. This report is still red;
renaming and building grant no additional MSForms parity credit.

Verified: 188 Rust tests passed (7 existing ignored performance/diagnostic tests),
format and clippy with warnings denied, and all 44 existing evidence checks.
Fresh review covered nullable VBA references, UTF-16 caret positions and Long
literals, input-only portable calls, live event-sink lifetime and historical
capture preservation. Remaining CalcVBA defects are oxforms-o0fp and oxforms-jbjp.75.

## Round 13: the ledger reads the repository

Until round 12 `parity_ledger.py` fixed the `oracle` and `tests` dimension of every public member row to
`missing`, so no evidence could attach and the verified count could not move whatever was built. It now derives both
from the repository (`tools/msforms-parity/member_evidence.py`, method in
[`MSFORMS_OBJECT_MODEL_PARITY.md`](../../../../specs/MSFORMS_OBJECT_MODEL_PARITY.md) section 3): a member has test
evidence when a committed, non-ignored Rust test file drives it on a typed variable, and oracle evidence when that file
also replays a committed native Excel measurement that names it. Dimensions with nothing to derive from
(`error_coercion`, `render`, and `persistence` on callable rows) were dropped rather than kept at a constant.
`refresh_ledger.py` regenerates the pins, manifest and ledger after any test, fixture, measurement or VBA change.

| | Before | After |
|---|---|---|
| Rows verified | 2,452 | 2,469 |
| Gap rows | 4,682 | 4,665 |
| Unexpected-public rows | 622 | 622 |
| Gating dimension cells | 20,055 | 15,330 |

What moved the 17 verified rows: 11 event rows and four member rows (`TextBox.Text`, `ListBox.IntegralHeight`,
`ListBox.ListCount`, `ListBox.Clear`) because committed tests drive them and replay native measurements, plus
`CheckBox.Value` and `ToggleButton.Value`, which also needed real work: nine controls had no default member, and
`Attribute Value.VB_UserMemId = 0` (`Caption` on Label) plus `default_member.rs` (fails without it with error 424) now
cover the bare-variable read and Let. Two rules were corrected because they held every writable property open for a
reason no caller can observe: the assigned-value parameter of a property Let/Set is no longer compared by name or
passing mode, and a compatible declaration exposed by a manual loader profile (the one the headless runner,
bootstrap and adapter tests use) counts as implemented instead of waiting for the clean `basproj` path.

The drop in gating cells (4,725) is mostly the dropped dimensions, not capability; the capability number is the
verified count. Still open on tested rows, each a real gap: native measurements that name the member (most rows),
typed shape differences (`ListBox.ListIndex`/`TopIndex`/`Value` are Long/String where FM20 has Variant, `AddItem` lacks
its Index), `OptionButton` implemented as `OptionButtonControl`, and read paths that no test drives.
