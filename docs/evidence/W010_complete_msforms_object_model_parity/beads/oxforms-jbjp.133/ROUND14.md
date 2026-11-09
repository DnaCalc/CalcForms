# MultiPage header and page client as two Tab stops (round 14)

`OxInteractionManager` now builds the Tab list from tokens. A MultiPage contributes its own name (the header
row) and, when its selected page holds no tab-stop control, a second token `Name#page` (the page client).
Header, then the selected page's tab-stop controls, in tab order; a page with a tab-stop control has no
page-client stop. `FocusName` is the MultiPage at both stops (native `Form.ActiveControl` cannot tell them
apart); `FocusOnPageClient` (Friend, read by tests) says which one holds focus. Moving between the header
and the page client keeps the same control focused: no Exit or Enter is raised (the native event order for
that step could not be measured, see `../oxforms-jbjp.124/ROUND13.md`). The MultiPage draws its header focus
adorner only while the header holds focus.

`tests/multipage_tab_stops.rs` replays `native-round13e.json` (five page-content variants) against the
runtime: all five agree. Variant 2 (`Value = 1` set from code before Show) opens natively with the page
client focused; the runtime opens on the first control, so that record is compared from the first common
stop. Shift+Tab is the mirror image (model symmetry, no native record). Not modelled: arrow keys while the
page client holds focus, a mouse click that lands in an empty page's client area, and the focus adorner
pixels at the page-client stop.
