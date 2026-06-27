# Blocked Capture Note (lightweight template)

Use this single-file note for a capture that is **blocked by the environment or
by a tooling/automation capability** before any oracle rows could be produced --
instead of generating a full capture directory (manifest + run-summary +
checksums + command/progress logs) that records no observed behavior. A full
evidence directory is for captures that produced rows, or for a blocker that is
itself a load-bearing, reproduced finding worth checksumming.

Copy this file to
`docs/evidence/<workset>/captures/<capture-id>/BLOCKED.md` (a directory with
only this one file is fine -- no checksums.sha256 is required for a note-only
block), fill every field, and delete the guidance comments. Keep it honest:
record the exact blocker, never infer MSForms behavior from missing rows.

When a capture *partially* succeeds (some scenarios exported, others blocked),
do **not** use this note -- record the blockers inline in that capture's
manifest/run-summary `blockers[]` array (see the W006 nested-modal and
terminate captures), which keeps the precise blocker next to the real rows.

---

- **capture_id:** `<workset>/<capture-id>`
- **bead:** `oxforms-<id>`
- **surface:** `<what was being captured>`
- **status:** `blocked`
- **attempted_at_utc:** `<ISO-8601, e.g. 2026-06-27T14:00:00Z>`
- **reason:** `<one or two sentences: the exact Excel/VBIDE/COM/Windows/tooling
  condition that prevented recording. Name the API/dialog/error, not a vague
  "Excel was slow".>`
- **last_progress:** `<the furthest step reached, e.g. "workbook_opened" or
  "before first input">`
- **what_a_full_capture_would_have_recorded:** `<the fields that remain
  unobserved, e.g. event sequence, QueryClose values, Terminate rows>`
- **ordering_covered_elsewhere:** `<cross-reference any capture that already
  observed the same ordering, e.g. "modal Terminate ordering: oxforms-0a0.24
  nested-modal-lifecycle-20260627T141239Z"; else "none">`
- **path_forward:** `<the concrete change that would unblock it, e.g. "drive the
  close with SendKeys Alt+F4 instead of PostMessage(WM_CLOSE)">`
- **non_claims:**
  - No OxForms runtime behavior is implemented or claimed by this note.
  - Missing/absent rows are unobserved in this attempt, not negative facts about
    MSForms.
- **clean_room:** Repo-owned fixture input + public Excel/VBIDE/Windows
  automation only. No Office internals, decompilation, disassembly, non-public
  source, or OxForms output comparison.
