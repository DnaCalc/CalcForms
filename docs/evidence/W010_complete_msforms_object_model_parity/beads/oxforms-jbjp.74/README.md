# Workbook UserForm on VM3

Status: implemented subset. This checkpoint loads the genuine, owned Excel workbook
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

## Windows result (round 2)

[`windows-session-20261104b/comparison-1/comparison.json`](windows-session-20261104b/comparison-1/comparison.json)
records six equal states from Windows/VM3 and Excel 16.0 build 20527, with twelve
PrintWindow screenshots and the runtime input/effect/readback trace. The original
Initialize, Change, Greet Click and CheckBox Click handlers ran in both engines.
The Windows edits clear `Ada` with three backspaces and type `Lin`; Excel's public
Text setters reproduce each intermediate edit. All six full handler logs agree.

The harness creates a private desktop and **never switches the input desktop**.
Excel is driven by in-memory VBA calls via NativeOM, with its exact PID checked.
The runtime receives PostMessage input addressed to its owned HWND. No pointer,
physical keyboard, focus takeover, Computer Use, clipboard writes, registry or
security changes are used. Windows now show without activation by default.
The selected String function can be observed with `--observe-member State`.

Round 2 started two Excel processes: setup PID 60992 closed before comparison
because tool stdin ended (owned handle terminated); PID 58680 is the reused
session. Round 1 had two launches, so the known total is four. Ownership files
record final cleanup when each session ends. The fixture hash is unchanged.
The comparison manifest's schema field was repaired after capture: Python's
ownership dictionary had overwritten that discriminator; observed rows and PNGs
were unchanged. The corrected writer puts the comparison discriminator last.

Visible differences remain: blue/white Label defaults, CheckBox glyph/caption
geometry, focus outlines, text metrics/antialiasing and native window decoration.
`oxforms-jbjp.76` owns the common-control paint correction. This proves a real
workbook form runs and responds on Windows; it does not claim pixel parity,
default instances, general workbook entry macros, or complete lifecycle parity.

Verify with `pwsh -File tools/evidence/Test-W010WorkbookComparison.ps1`, the
headless workbook regression and the normal workspace/evidence floor. Reproduce
by building `calcforms-workbook`, starting
`python -B tools/office-oracle/workbook_comparison_session.py --out <fresh-dir>`,
then appending `{"command":"compare"}` and finally `{"command":"close"}` as
separate lines to that directory's `commands.jsonl`. Pass `--round-launch` with
the actual count when continuing a round; never reopen a prior ownership file.
The harness has a bounded session lifetime and closes only owned process handles.
