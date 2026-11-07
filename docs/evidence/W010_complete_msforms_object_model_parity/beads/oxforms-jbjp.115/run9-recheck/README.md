# CalcVBA 8840f391: independent current-pin recheck

The current VM3 driver, with the production CalcForms modules, returns:

`inline=0;multiline=22;chained=error:438:Object doesn't support 'MeasureTextCount';typed=3`

The inline and multiline Select Case functions perform the same scalar assignment
for Case 2; the required result is 22. The chained IOxControl.Core getter and
typed OxControlCore local refer to the same ListBox; the required count is 3.
These remain the precise `.117` and `.115` CalcVBA follow-ups.

`repro-only.bas` contains the four functions and result entry. `LayoutSelection.cls`
is the complete executable source, based on the archived production measurement
fixture. `provenance.json` pins source/result bytes, VM3 revision and driver hash.
No Office process was started, no window was opened and no OxVba file was edited.
The bad results are retained defects, with no language-parity credit.
