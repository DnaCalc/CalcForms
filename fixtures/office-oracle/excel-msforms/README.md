# Excel MSForms Oracle Inputs

This directory is for repo-owned inputs that create or open Excel-hosted
MSForms oracle fixtures.

Fixture shape:

- `userforms/` for tiny UserForm fixture sources and their property notes.
- `member-probes/` for immutable, ledger-linked declarative member batches.
- Optional generation/opening scripts only when they are explicit about local
  Excel prerequisites and clean-room boundaries.

Current fixtures:

- `userforms/rectangle-label/` contains the first stable Excel/MSForms
  UserForm oracle fixture input from `oxforms-fg9.4`.
- `userforms/rectangle-label-text/` contains the W004 text-bearing Label
  oracle fixture input from `oxforms-kgn.3`.
- `userforms/interaction-events/` contains the W005 interaction/event oracle
  fixture input from `oxforms-xvx.2`.
- `member-probes/representative-v1.json` and its selected-row ledger slice
  drive the reusable W010 property/method/error/event oracle introduced by
  `oxforms-jbjp.5`.

Do not commit opaque generated workbooks here as the only source of truth. If a
future bead must preserve a generated binary workbook, place it with the
owning workset/bead evidence manifest and hashes, or justify the exception in
text.
