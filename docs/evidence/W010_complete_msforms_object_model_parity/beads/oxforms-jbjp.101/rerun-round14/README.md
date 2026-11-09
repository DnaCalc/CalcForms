# FORMS PARITY after round 14: 1,205 pass / 413 fail; 346 missing measurements

The behaviour, input and keyboard scenario transcripts (18 runs: three forms by two scales for each of the three suites) were executed again against the
build of the round 14 commit (`tools/office-oracle/run_runtime_measurements.py --zoom`, then `parity_rerun.py`; no Office).
`--zoom` sets `UserForm.Zoom` to the case zoom right after the scenario creates its form, as the native scenario does; a
second run without it (not retained) gives the same 1,205 / 413 / 346. Native facts, window captures and scenario sources
are unchanged from `.129`/`.130`; only the CalcForms transcripts are new (`runtime`, binary digest in
`versus-previous.json`).

Against the previous report (`../../oxforms-jbjp.130/forms-parity.json`, 1,203 / 415 / 346): two measured gains, no
regressions, no native fact changed. The gains are `tab_order` of `PagesControl` in LayoutContainers at 100% and 150%
(the MultiPage page-client stop, `.133`). The ListBox work of `.118` moves no row in this report: the ListBox rows that
fail here (`list_row_height`, `visible_line_count`) are measured on the retained CalcForms window image, which this
rerun does not render again.

Not rerun: the retained window images of CalcForms (the `*-calcforms.png` files are the earlier renders), so layout,
text and spacing rows are as before.
