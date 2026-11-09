# Font object on every font-bearing control (round 14)

Native source: `../oxforms-jbjp.105/native-round14.json`, script `font` (414 lines; Excel 16.0.20527, one owned hidden Excel
on a private desktop, 0 windows and 0 foreground hits on the owner desktop). Replay:
`crates/calcforms-calcvba-adapter/tests/round14_replay.rs`.

## Measured

* Every font-bearing control (Label, TextBox, CommandButton, CheckBox, OptionButton, ToggleButton, ListBox, ComboBox,
  Frame, TabStrip, MultiPage) and the UserForm has a `Font` object: Name "Tahoma", Size 8.25 (Currency), Bold, Italic,
  Underline and Strikethrough False, Weight 400 and Charset 0 (Integer). Image, SpinButton and ScrollBar have none.
* Size accepts 0 and any positive number up to at least 4000, converts text that is not a number to error 13 and
  Null to 13, and raises 380 for a negative number. Name takes any text (also a family that does not exist); Null raises 13.
  Weight takes 0 to 1000 (380 outside); Bold is True from Weight 600 (500 gives False, 600 gives True); Bold True writes
  Weight 700 and Bold False writes 400. Charset takes 0 to 255 (380 outside). Italic, Underline and Strikethrough are plain
  Booleans.
* The Font objects of two controls are independent. `Set A.Font = B.Font` copies the values; a later change to B does not
  reach A.
* The UserForm's Font differs: Size is held in whole pixels (8.3 gives 8.25, 10 gives 9.75) and a Size of 0 raises 380.
  The runtime has no UserForm Font yet; those lines are listed as differences.

## Runtime

`Font` (new class) is returned by `Font` on the eleven control classes and holds the values; a write that changes the
name or size reaches the core (`OxControlCore.NoteFontChanged`) so `FontSize`, the one value the painters read, follows
(a Size of 0 is kept on the Font but never reaches the painters). The renderer still has one UI face: the name changes no
glyphs and Bold, Italic, Underline and Strikethrough change no painting yet. The ListBox whole-row snap (`.118`) is the
one consumer of the name today.

## Ledger

Before round 14: 2,469 verified / 4,665 gaps / 622 unexpected-public rows (7,756 rows). After the Font work and `.105`:
2,492 / 4,650 / 753 (7,895 rows, dimension cells 15,330 to 15,648 because the 8 Font members and 130 new public
IControl declarations add rows). The 8 members of the new Font class (Name, Size, Bold, Italic, Underline, Strikethrough,
Weight, Charset: mapped through a `Font` direct-facade entry in `surface_policy.v1.json`, 8 new rows) and `Font` on ten
control classes (all but MultiPage, whose type row still reports a partial bind) are verified from typed access in
`round14_replay.rs` and the native names in `native-round14.json`.
