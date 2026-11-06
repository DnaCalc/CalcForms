# FORMS PARITY: Enter, Escape and real overflow

**1,055 pass / 555 fail, including 428 missing measurements.** This capture fills
94 more missing rows after `.107`, bringing run 7 to 476 of the original 904.
It precedes the production corrections in `.111` and remains reproducible.

`keyboard/` holds literal native/VM3 transcripts, generated sources and hashes
for six form/zoom cases. Interior clicks establish each target, then Enter and
Escape record command/value notifications in order. Native visibility is kept
separately; these authored runtime forms expose no equivalent public Visible
property. The rows claim these notifications, not complete lifecycle parity.

The real ListBox has 23 rows and receives PageDown twice then Home. Native
ListIndex is 1/7/13/0 and TopIndex is 0/1/7/0. The runtime remains at index 1 on
PageDown and reports error 438 for TopIndex. These are measured failures. Native
Enter with no default button leaves Boolean controls unchanged; the runtime's
twelve Boolean Enter failures become the next correction, alongside `.107`'s
22 programmatic setter failures. Pixels supply only historical coarse guards.

All native input is posted to the owned private window; no real keyboard,
pointer, focus call or desktop switch is used. Recovery Excel 29860 is reused.
Replay with `python -B tools/office-oracle/validate_keyboard_reference.py`.
Fresh review rejects missing, duplicated or reordered phases and observer errors;
an observed unsupported property stays a result rather than missing evidence.
