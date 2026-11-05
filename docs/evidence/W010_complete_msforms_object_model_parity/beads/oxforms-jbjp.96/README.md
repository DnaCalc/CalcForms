# Forms parity report

Owner run 6 replaces pixel priorities with measured forms parity. The JSON and
[readable report](forms-parity.md) replay the existing `.79` comparison inputs:
four forms, both 100% and 150%, every intrinsic kind and nested Frame controls.
Image identity is checked before measurement. No Excel launch or input is used
for replay. New live captures use the same reporter.

Every reported item is pass/fail and records native/runtime values, units,
tolerance, maximum difference and measurement count. Missing observations fail
coverage with count 0. Logical control bounds and their rounded pixel edges,
client sizes, colour classes, foreground ink bounds, line counts, measured
insets and available list-row spacing are read from facts/images. Captions and
list rows have separate ink rows when the saved image can separate them.

Baseline, exact clipping/wrap offsets, exact line breaks, unmeasured spacing and
ordered behaviour stay failed until paired measurements exist. A matching
TabIndex does not prove traversal. Colour masks are not OCR, and do not claim
glyph identity. Nested native parent paint origins were not recorded, so nested
image checks fail coverage. Historical qualification flags remain absent.

The failures describe the old `.79` binaries. They correctly put the old tab
caption layout and ListBox row layout first; later `.87`/`.88` already corrected
those subsets. Fresh captures must establish the next implementation priority.
Pixels remain a 40% whole-client coarse guard, outside the priority list.

Verification: `tools/evidence/Test-W010IntrinsicLayout.ps1` checks deterministic
report replay and adversarial cases for missing values, vector/line changes,
selected text, image hashes, client metadata, duplicates and absent scale.
Fresh review corrected categorical/vector-length tolerance handling and kept
white selected ink distinct from white space outside the selected row.
It also separates detected dotted focus rectangles and long straight borders
from ink. Detected focus positions and dominant text/fill colour classes have
their own rows; missing or ambiguous measurements remain failed coverage.
The complete existing evidence suite passed 54/54 after the startup fingerprint
repair. The report's targeted replay and six adversarial tests also pass.
