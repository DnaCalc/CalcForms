# Container TabIndex: Image has no TabIndex and takes no slot

`native-round12.json` (Excel 16.0.20527, one owned hidden Excel, `tools/office-oracle/capture_round12_native.py`).
The LayoutContainers controls were created in corpus order two ways: with the UserForm Designer
and with `Controls.Add` in `UserForm_Initialize`. Both give the same indices:

Group (Frame) 0, Picture (Image) no TabIndex (reading it raises error -2147352573, member not
found), Spinner 1, Slider 2, TabsControl 3, PagesControl 4; inside the Frame NestedLabel 0 and
NestedInput 1.

So the retained native TabsControl 3 / PagesControl 4 are the plain Controls.Add sequence with
Image skipped. The runtime corpus generator and `Controls.Add` counted the Image, giving 4 and 5.
That was a fixture and Controls.Add translation fault, not a native quirk of the container
controls. Fixed in `vba/calcforms/Controls.cls` (an Image takes no TabIndex slot; replayed by
`container_tab_index.rs`, which fails on the old code). `tools/office-oracle/layout_corpus.py`
gains `native_tab_slots=True` for the native sequence; the default stays the historical
enumeration index because retained evidence pins the generated sources. The report rows
(TabsControl 3/4, PagesControl 4/5) therefore stay as recorded until a new paired layout run
uses the option; that run was not made.

The same file also holds a ListBox Height sweep (456 rows: zoom 100/150, three fonts, border
on/off, IntegralHeight on/off, 19 requested heights) for `.118`; see that bead's note.
