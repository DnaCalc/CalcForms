# CalcVBA / CalcForms restart review — 2026-11-04

The September contract is `oxforms-jbjp.6`; its generated facade ledger and
`HANDOVER_OxVba_w010_facade_binding.md` remain the compatibility reference.
Owner direction: VBA UserForms are in scope here, mainly implemented in VBA
running on CalcVBA. Product progress takes priority over further inventories.

What still holds:
- Preserve MSForms reference identity, defaults, Let/Set, events and control-site
  members without exposing runtime hooks as public compatibility members.
- The VBA reducer owns form behavior; Rust supplies platform and rendering services.
- W009 is a working subset, not full W010 parity. Keep the raw facts/captures.

What changed:
- CalcVBA is now `DnaCalc/CalcVBA`; crates use `calcvba-*`.
- `calcvba-host` is the former embedding API, while the existing object-session
  API (`ProjectRuntimeSession`) now lives in `calcvba-engine`.
- `calcvba-office` reads Office projects and preserves UserForms as `.frm`/`.frx`;
  it also owns workbook write-back. The old OxDoc-only boundary is obsolete.
- `docs/spec/BASPROJ_SPEC_V1.md` defines source attributes and FormModule items.
  Its explicit statement that persistence does not provide a runtime still holds.
- Reviewed published CalcVBA baseline: `1590c0895743a26f9a2e1147c5997d0f67f6f3c0`.
  The sibling working tree has another agent's changes; it remains read-only.

What blocks a real workbook form:
- CalcForms has not connected the Office form graph and unchanged code-behind
  to its VBA controls, event wiring, default instances and Windows bootstrap.
- September D006-01 (qualified cross-project defaults) and D006-02 (Friend
  visibility) still reproduce in the executable probes on the current baseline;
  passing discrepancy assertions are observations, not compatibility acceptance.
- Native FormModule inheritance/control fields, host-owned initialization,
  Show/Hide/Unload and event binding need a verified end-to-end ownership path.

First three steps:
1. Rename crates and active identifiers together, pin CalcVBA, restore green checks.
2. Load one existing Excel UserForm through `calcvba-office`; connect its persisted
   controls and original handlers to the VBA runtime, with a headless interaction test.
3. Run the same form on Windows/VM3 and in one owned, reused Excel instance;
   compare controls/events, then extend the controls real forms need first.

CalcVBA requests from the restart tests:
- Initialize typed object fields to Nothing: an untouched interface field currently
  reads as Empty, so `If field Is Nothing` raises 424. CalcForms now explicitly
  initializes nullable fields; its object-model tests pass through both host APIs.
- Portable dynamic calls with ByRef arguments bypass portable dispatch and report
  COM-E-DYNAMIC-NAME-UNRESOLVED. The input-only surface now passes values explicitly.
- Retain D006-01/default coercion and D006-02/Friend visibility as upstream asks.
  No runtime test is disabled or converted into a passing discrepancy test.

No changes to the sibling repository or Office security configuration are authorized.

Run 8 update (2026-11-06): the published dependency is now pinned to
`a4bf979239e1cb67326d13b760c04ecd13bbf55f`. Required-outcome VM3 regressions
confirm untouched qualified object fields/locals default to Nothing, variable
arguments reach the real portable Surface, qualified cross-project scalar
default coercion executes, and external typed/late-bound Friend access fails.
The existing same-library bridge and explicit Let/Set identity probes still pass.
See [the take-up evidence](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.75/README.md).
The paragraphs above preserve the restart observations; `.6`'s generated blocked
snapshot remains historical. This does not implement `.7`'s internal facade or
resolve `.95`'s non-creating default lookup and held-reference lifetime requests.
