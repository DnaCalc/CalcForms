# Literal ampersands and explicit accelerators

Native Excel preserves `&`, `&&` and trailing `&` in captions as well as edit
and list strings. Caption markup was an incorrect assumption. Accelerator is
a separate property: observed assignments `b`, `BC`, `&`, empty read back as
`b`, `B`, `&`, empty. Native TextBox selection of character 1 reads `&`.

The [before](before/forms-parity.md) and [after](after/forms-parity.md) reports
cover Label, TextBox, CommandButton, CheckBox, OptionButton, ToggleButton,
ListBox and ComboBox in two forms at 100% and 150%. Every retained literal
source and character count now agrees; geometry/behaviour coverage failures
remain visible. `literal_text_reference.py` replays image hashes, raw retained
runs, the twenty text fragments per build, and the native property observations.

Shaping now preserves every source character. TextKey has an optional explicit
accelerator index in its content identity. The typed batched request carries
Accelerator independently. CommandButton stores the observed first character
and registers that key; ampersands create no implicit key. A VM3 regression
checks selection of `&`, all list rows, nine characters/ten caret stops,
property readback and explicit key activation. Kernel/font tests preserve
literal strings and prove that explicit underlining remains available.

One owned Excel PID 23192 on private desktop CalcFormsOracle_41abe35c61bd is
reused. Its private windows can paint, and remain hidden from the input desktop.
No desktop switch, owner input/focus, Computer Use, security or registration
change. Workbook bytes remain unchanged. Setting Excel.Visible=False made a
native client blank; that capture is excluded. The valid replacement uses the
same private process. Adding the first probe module reset the native form;
a subsequent stale geometry read raised error 91. Its owned dialog was ended
through the native accessibility action after UI Automation Invoke was
unavailable, then the form was recreated. No real mouse/keyboard was used.

Fresh review removed the incorrect marker parser rather than retaining two
caption interpretations. Native property mapping adds two accepted source
accessors; the wire record adds one internal field. The strict ledger census
was updated to 834 declarations/10 type fields with exact partitions retained.
It remains red: 2,452 verified / 4,682 gaps / 620 unexpected-public rows.
