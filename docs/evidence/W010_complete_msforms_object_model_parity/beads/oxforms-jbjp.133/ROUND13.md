# Repeated MultiPage Tab positions: header stop, then the page (round 13)

Sources: `native-round13b.json`, `native-round13c.json` and `native-round13e.json` (Excel 16.0.20527, one owned Excel
each on a private desktop; guard output 0 windows, 0 foreground hits on the owner desktop). Tab is posted with
`WM_KEYDOWN`/`WM_KEYUP` to the focused window of the owned Excel (no cursor, keyboard or foreground call of the owner's
desktop). The form is made the thread's active window from inside Excel's UI thread, see `../oxforms-jbjp.124/ROUND13.md`.
`Form.ActiveControl` is read at every stop, together with the raw IAccessible state of the MultiPage (`accState` of each
child) and, in 13e, the selected page's own `ActiveControl`.

LayoutContainers control set, built with `Controls.Add` in corpus order (13b/13c): the cycle is
`Group (NestedInput), Spinner, Slider, TabsControl, PagesControl, PagesControl, Group, ...`, repeated. This is the
retained `.130` native record (`PagesControl` at positions 4 and 5) reproduced independently.

What the two `PagesControl` stops are, from MSAA: at the first one the MultiPage's child 1 (the tab header row) has the
FOCUSED state bit (`accState` 1048580 = focusable + focused); at the second one that bit is clear and `accFocus` returns an
object (the page). `Form.ActiveControl` reports the MultiPage at both, so `ActiveControl` cannot tell them apart. Header
focus and page-client focus are different stops.

13e varies the selected page's content (each cycle starts after the form is active; `Before` and `After` are TextBoxes
outside the MultiPage; "header" = the MSAA header bit):

| Selected page holds | Stops after `Before` |
|---|---|
| nothing | MP header, MP page client, `After` |
| one TextBox with TabStop True | MP header, `InPage` (page `ActiveControl` = InPage), `After` |
| two such TextBoxes | MP header, `InPage`, `InPage2`, `After` |
| one TextBox with TabStop False | MP header, MP page client, `After` |
| Value = 1 (empty page selected; the TextBox is on page 0) | MP header, MP page client, `After` (here the initial focus after Show was already the page client, not `Before`) |

So the rule is: a MultiPage contributes its header as one stop, then the tab-stop controls of the selected page in tab
order; when the selected page has no tab-stop control it contributes one stop for the page client itself. Both read as
the MultiPage through `Form.ActiveControl`.

Runtime today: one stop for the MultiPage and then the page's tab-stop children. The runtime therefore matches the first
stop and lacks the page-client stop for a page without tab-stop controls, which is why `PagesControl` has one native
position more than the runtime in the retained `tab_order` rows at both scales. Not changed in the runtime: the tab list
is a name-to-next-name map (`OxInteractionManager.mTabNextByName`), so one control name cannot appear twice, and the
page-client stop needs its own focus state (adorner, Shift+Tab symmetry, which is not measured). `.133` stays open with
this rule as its specification.
