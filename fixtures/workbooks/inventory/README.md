# Inventory workbook

`inventory.xlsm` was authored by Excel through the existing owned private session.
The original form/entry source is retained beside the qualified native export.
Six designer controls and a ListBox created by Initialize exercise selection,
quantity validation, totals, default Enter and Cancel/Hide behavior.

The complete differential is in `docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.119`.
It retains four failed cancel-focus fields; this fixture is not a full parity claim.
`author_inventory.py --owner <live ownership.json>` authors a fresh fixture only
when the saved workbook does not already exist. It never changes Office security.
