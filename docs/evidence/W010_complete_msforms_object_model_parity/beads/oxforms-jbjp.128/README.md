# ToggleButton / CheckBox / OptionButton numeric and Null Value coercion: 448 of 448 native rows match

Native FM20 `Value` on ToggleButton, CheckBox and OptionButton is a Variant that holds
Boolean or Null. The earlier planner run showed a Long -1 assigned to ToggleButton.Value
producing Null (error 94 in `CStr(Value)`); this folder measures the whole mapping.

Excel 16.0.20527, one owned hidden Excel on a private desktop (`native-coercion.json`,
`native-coercion-round2.json`; capture script `tools/office-oracle/capture_toggle_coercion.py`).
Each row sets a Variant of a given subtype from a known starting state (False, True, or Null)
and records the error, the Value read back (subtype and value) and the Change/Click log.

Measured rule (identical for ToggleButton and CheckBox; TripleState does not change it):

- Null and Empty give Null. Boolean passes through.
- Integer and Long: 0 gives False, 1 gives True, every other number (-1, 2, 100, 65536,
  2147483647, -32768) gives Null. A literal `-1` is an Integer, so `Value = -1` gives Null.
- Byte, Single, Double, Currency, Decimal, Date: zero gives False, anything else True
  (Double -1 gives True, Double 0.4 gives True).
- Strings: "True"/"False" (any case, trimmed) by name; numeric text is rounded to an integer
  then mapped like Integer ("0", "0.5", "0.0" False; "1", "1.0", " 1 " True; "2", "-1" Null);
  other text and "" give Null.
- Events: a change of state raises Change; Click follows only when the new value is not Null.
  Assigning the current value raises nothing (Null to Null is silent).
- OptionButton differs only in that deselection raises Change without Click (existing
  option-group behaviour).

The runtime ToggleButton, CheckBox and OptionButton now hold a Variant Value with this
coercion (`Private CoerceValue` in each class). `check_value_coercion.rs` replays all 448
rows (382 ToggleButton/CheckBox, 66 OptionButton) against the runtime classes in the planner
workbook project: **448 pass / 0 fail**. Not measured and therefore not claimed: user click or Space activation
from the Null state (the runtime goes to True), the rendered face for Null (drawn unpressed),
numeric strings beyond banker's-rounded integers (for example "0.6", "1.5"), objects and arrays
(Null here), and OptionButton Null inside a group with peers (the single measured button has none).
