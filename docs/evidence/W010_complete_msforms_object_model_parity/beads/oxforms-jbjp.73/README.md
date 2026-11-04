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
