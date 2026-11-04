# Workbook UserForm on VM3

Status: in progress. This checkpoint loads the genuine, owned Excel workbook
in `fixtures/workbooks/greeter/` through pinned `calcvba-office`, decodes its
MS-OFORMS streams, and runs its original procedure bodies on VM3. No Office
process is started by the Rust tests.

`excel-observations.json` records six states from round 1's owned Excel 16.0
build 20527 (PID 24196, two launches). The owner closed that process after round
1. `cargo test -p calcforms-calcvba-adapter --test workbook_userform` compares
those states with reducer-driven text/button/checkbox input. Excel used public
Text/Value setters; this proves handler/state agreement, not identical input
event sequences or pixel parity.

The source provider adds private host entrypoints and designer control fields
to the selected form class. Application procedure bodies are preserved. This
checkpoint supports a self-contained form, not arbitrary workbook modules,
qualified MSForms references, default instances, or full Show/Hide/Unload.
The VBA library owns behavior and rendering; the Rust decoder supplies persisted
properties, and the existing Windows backend consumes its retained Scene.

The decoder supports flat Label, TextBox, CommandButton and boolean CheckBox
sites with the fixture's text/font subset. Nested sites, custom classes,
pictures, bindings, and unsupported stream layouts produce errors. Full
persistence/member/render parity remains W010 work.

`captures/excel/window-capture-manifest.json` is round 1's **failed** capture;
it contains no screenshot and is not visible comparison evidence. Do not rerun
its recorded foreground-activation command on the owner's desktop. Round 2
must use only in-process calls or window messages without taking input/focus.

Remaining acceptance: run the workbook form through a real Windows window,
compare it with one owned and reused Excel, record the method and differences,
and close every Excel process started by the harness. Full W010 remains open.
