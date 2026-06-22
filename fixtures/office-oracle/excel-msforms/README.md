# Excel MSForms Oracle Inputs

This directory is for repo-owned inputs that create or open Excel-hosted
MSForms oracle fixtures.

Expected future shape:

- `userforms/` for tiny UserForm fixture sources and their property notes.
- Optional generation/opening scripts only when they are explicit about local
  Excel prerequisites and clean-room boundaries.

The first real fixture is intentionally deferred to `oxforms-fg9.4`. This bead
only establishes where that fixture belongs.

Do not commit opaque generated workbooks here as the only source of truth. If a
future bead must preserve a generated binary workbook, place it with the W003
evidence manifest and hashes, or justify the exception in text.
