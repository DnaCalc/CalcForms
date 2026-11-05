# Label word wrapping

Recovered from the interrupted run and reviewed before committing. The native
probe enlarges the authored Clipped label to 70 by 30pt so both lines are
visible. Native Tahoma 8.25 wraps `Long clipped label AgjpQy` into
`Long clipped label` and `AgjpQy`, with the next word beginning at offset 19.
The saved before/after native image hashes agree at both 100% and 150%.

VBA Label now defaults WordWrap to True, measures caption tokens in the form's
existing single batch, and lays out words and explicit CR/LF/CRLF breaks.
Workbook loading preserves its persisted WordWrap flag. Width changes reflow;
clearing removes old runs; explicit lines remain supported when WordWrap=False.
The regression checks these state changes and the single measurement crossing.

`label_wrap_reference.py` checks both scale inputs, retained source runs,
native image identity, exact break offset and report replay. The after reports
pass the two visible lines and exact break/wrap offset. Their measured ink
bounds remain failed because text advances differ. No font rendering parity,
arbitrary long-word breaking, tab expansion or mixed-script claim is made.

Native observations came from the interrupted run's one owned Excel PID 23192
on private desktop CalcFormsOracle_41abe35c61bd; this recovery replay launches
no Excel. No pointer, keyboard, input focus, Computer Use, Office security or
registration changes are involved. `.100` tracks partial native text capture;
`.101` tracks font advances for the future rendering stack.

Recovery verification: fmt/clippy passed; 208 Rust tests passed, seven existing
ignored; aggregate evidence 54/54, whitespace and dependency-cycle checks passed.
Fresh review inspected both saved native/runtime clients and preserved the
separate font-width failure. JSON inputs retain LF for stable image/report hashes.
