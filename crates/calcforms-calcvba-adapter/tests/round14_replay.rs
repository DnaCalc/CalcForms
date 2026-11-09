//! Native Excel 16.0.20527 properties common to every control, fonts and geometry (oxforms-jbjp.101, .105).
//!
//! `native-round14.json` holds three scripts (Font object, TabStop/TabIndex/Tag/ControlTipText/
//! HelpContextID and renumbering, geometry readback) run by the shared interpreter in
//! `tools/office-oracle/round14_engine.bas` inside one owned hidden Excel on a private desktop. The
//! same interpreter and the same script lines run here against the production controls; every line
//! must give the same text. Lines that differ are grouped by script and property and pinned below,
//! so what is modelled and what is not stays visible. A second test drives the typed members of
//! every control class (`Dim X As TextBox`, `X.Tag`, `X.Font.Size`, ...) and compares them with
//! values read from the same native record.
mod common;
use calcvba_runtime::Variant;
use common::{call_text, evidence, runtime_for};
use serde_json::Value;
use std::{collections::BTreeMap, path::Path};

fn harness() -> String {
    let engine = std::fs::read_to_string(
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../../tools/office-oracle/round14_engine.bas"),
    )
    .unwrap()
    .replace("\r\n", "\n");
    format!(
        r#"Option Explicit
Private F As UserForm
Private Sub CalcFormsHostBuild()
    Set F = New UserForm
End Sub
Private Sub CalcFormsHostPerformInitialize()
End Sub
Private Sub CalcFormsHostRender()
    F.Render 96, 96
End Sub
Public Function Go(ByVal Script As String) As String
    Dim U As UserForm
    Set U = New UserForm
    Go = RunScript(U, Script)
End Function
{}"#,
        engine.replace("Option Explicit\n", "")
    )
}

fn native() -> Value {
    serde_json::from_slice(
        &std::fs::read(evidence("oxforms-jbjp.105").join("native-round14.json")).unwrap(),
    )
    .unwrap()
}

/// Replay one native script; returns (line count, differing (line, native, runtime)).
fn replay(key: &str) -> (usize, Vec<(String, String, String)>) {
    let native = native();
    let script = &native["scripts"][key];
    let lines: Vec<&str> = script["lines"]
        .as_array()
        .unwrap()
        .iter()
        .map(|l| l.as_str().unwrap())
        .collect();
    let expected: Vec<&str> = script["result"].as_str().unwrap().lines().collect();
    assert_eq!(
        lines.len(),
        expected.len(),
        "{key}: one native result per script line"
    );
    let mut runtime = runtime_for(harness(), "Round14Probe");
    let script_text = lines.join("\n") + "\n";
    let actual = call_text(
        &mut runtime,
        "Go",
        vec![Variant::from_string(script_text.as_str())],
    );
    let actual: Vec<&str> = actual.lines().collect();
    assert_eq!(
        actual.len(),
        expected.len(),
        "{key}: one runtime result per script line"
    );
    let mut differences = Vec::new();
    for (n, a) in expected.iter().zip(&actual) {
        if n != a {
            let (line, native) = n.split_once(" => ").unwrap();
            differences.push((
                line.to_string(),
                native.to_string(),
                a.split_once(" => ").unwrap().1.to_string(),
            ));
        }
    }
    (lines.len(), differences)
}

/// Group differing lines by the operation and property they touch.
fn groups(differences: &[(String, String, String)]) -> BTreeMap<String, usize> {
    let mut map = BTreeMap::new();
    for (line, _, _) in differences {
        let words: Vec<&str> = line.split(' ').collect();
        let key = match words[0] {
            "snap" => format!("snap {}", words[1]),
            "get" | "let" => format!("{} {}", words[0], words[2]),
            other => other.to_string(),
        };
        *map.entry(key).or_default() += 1;
    }
    map
}

fn check(key: &str, expected: &[(&str, usize)]) {
    let (total, differences) = replay(key);
    let found = groups(&differences);
    println!(
        "{key}: {total} lines, {} differ: {found:#?}",
        differences.len()
    );
    if std::env::var("ROUND14_SHOW").is_ok() {
        for (line, n, a) in &differences {
            println!("DIFF {line} | native {n} | runtime {a}");
        }
    }
    let expected: BTreeMap<String, usize> =
        expected.iter().map(|(k, v)| (k.to_string(), *v)).collect();
    assert_eq!(found, expected);
}

/// Differences kept visible (115 of 414 lines): every line about the UserForm's own Font (the runtime form has none; native
/// holds its size in whole pixels and its weight at 400 or 700, 103 lines including the form column of each `snap`), and
/// `Null` written to a Font name or size, which the runtime refuses with 94 where Excel gives 13 (CalcVBA, below). Every
/// control line agrees: defaults, ranges, coercions, the Weight and Bold link, independence, and copy by `Set`.
#[test]
fn font_object_matches_native() {
    check(
        "font",
        &[
            ("get Font.Bold", 11),
            ("get Font.Charset", 6),
            ("get Font.Italic", 2),
            ("get Font.Name", 5),
            ("get Font.Size", 13),
            ("get Font.Strikethrough", 2),
            ("get Font.Underline", 2),
            ("get Font.Weight", 11),
            ("let Font.Bold", 2),
            ("let Font.Charset", 6),
            ("let Font.Italic", 2),
            ("let Font.Name", 8),
            ("let Font.Size", 16),
            ("let Font.Strikethrough", 2),
            ("let Font.Underline", 2),
            ("let Font.Weight", 9),
            ("snap Font.Bold", 2),
            ("snap Font.Charset", 2),
            ("snap Font.Italic", 2),
            ("snap Font.Name", 2),
            ("snap Font.Size", 2),
            ("snap Font.Strikethrough", 2),
            ("snap Font.Underline", 2),
            ("snap Font.Weight", 2),
        ],
    );
}

/// Differences kept visible (19 of 110 lines): `Null` written to Tag, ControlTipText, HelpContextID or TabIndex gives 94
/// here and 13 natively, and to TabStop it is accepted here (CalcVBA); the text "1" written to the Integer TabIndex gives
/// 13 here and is accepted natively (CalcVBA); a MultiPage from `Controls.Add` has two pages natively and none here, so
/// the three page-child lines and the lines that follow them differ; `Controls.Remove` of a name raised 13 in Excel on this
/// call path and the control stayed, which the runtime does not reproduce, and the snapshots after it differ by that.
/// Every TabIndex line before those (defaults, the move, the clamp, the negative error, rounding, Frame children) agrees.
#[test]
fn tab_order_and_common_properties_match_native() {
    check(
        "tab",
        &[
            ("add", 3),
            ("let ControlTipText", 1),
            ("let HelpContextID", 1),
            ("let TabIndex", 3),
            ("let TabStop", 1),
            ("let Tag", 1),
            ("remove", 1),
            ("snap TabIndex", 8),
        ],
    );
}

/// Differences kept visible (2 of 390 lines): `Null` written to Left gives 94 here and 13 natively, and the text "150"
/// written to the Integer Zoom gives 13 here and is accepted natively (CalcVBA). Twip rounding, negative Left and Top, the
/// 380 for a negative Width or Height, large values, the default TextBox size and the UserForm's size, inside size,
/// minimum and Zoom range all agree.
#[test]
fn geometry_readback_matches_native() {
    check("geometry", &[("let Left", 1), ("let Zoom", 1)]);
}

// ---- typed members -------------------------------------------------------------------------
// CalcVBA behaviours behind the pinned differences above, for the report: a Null argument to a ByVal String, Currency,
// Single or Long parameter raises 94 (Excel: 13) and to a Boolean is accepted (Excel: 13); a late-bound call
// (`CallByName ... VbLet`) converts text to Long and Single but not to Integer.

struct Kind {
    ty: &'static str,
    name: &'static str,
    tab_stop: bool,
    tab_index: bool,
    help: bool,
    font: bool,
}

const KINDS: &[Kind] = &[
    Kind {
        ty: "Label",
        name: "Lbl",
        tab_stop: false,
        tab_index: true,
        help: false,
        font: true,
    },
    Kind {
        ty: "TextBox",
        name: "Txt",
        tab_stop: true,
        tab_index: true,
        help: true,
        font: true,
    },
    Kind {
        ty: "CommandButton",
        name: "Cmd",
        tab_stop: true,
        tab_index: true,
        help: true,
        font: true,
    },
    Kind {
        ty: "CheckBox",
        name: "Chk",
        tab_stop: true,
        tab_index: true,
        help: true,
        font: true,
    },
    Kind {
        ty: "OptionButtonControl",
        name: "Opt",
        tab_stop: true,
        tab_index: true,
        help: true,
        font: true,
    },
    Kind {
        ty: "ToggleButton",
        name: "Tog",
        tab_stop: true,
        tab_index: true,
        help: true,
        font: true,
    },
    Kind {
        ty: "ListBox",
        name: "Lst",
        tab_stop: true,
        tab_index: true,
        help: true,
        font: true,
    },
    Kind {
        ty: "ComboBox",
        name: "Cmb",
        tab_stop: true,
        tab_index: true,
        help: true,
        font: true,
    },
    Kind {
        ty: "Frame",
        name: "Frm",
        tab_stop: true,
        tab_index: true,
        help: true,
        font: true,
    },
    Kind {
        ty: "Image",
        name: "Img",
        tab_stop: false,
        tab_index: false,
        help: false,
        font: false,
    },
    Kind {
        ty: "SpinButton",
        name: "Spn",
        tab_stop: true,
        tab_index: true,
        help: true,
        font: false,
    },
    Kind {
        ty: "ScrollBar",
        name: "Scr",
        tab_stop: true,
        tab_index: true,
        help: true,
        font: false,
    },
    Kind {
        ty: "TabStrip",
        name: "Tab",
        tab_stop: true,
        tab_index: true,
        help: true,
        font: true,
    },
    Kind {
        ty: "MultiPage",
        name: "Mpg",
        tab_stop: true,
        tab_index: true,
        help: true,
        font: true,
    },
];

/// Typed access to every member of every control class, written out so each class and member is named in the source.
const TYPED_VBA: &str = r#"Option Explicit
Private F As UserForm
Private Sub CalcFormsHostBuild()
    Set F = New UserForm
End Sub
Private Sub CalcFormsHostPerformInitialize()
End Sub
Private Sub CalcFormsHostRender()
    F.Render 96, 96
End Sub
Public Function P_Lbl() As String
    Dim X As Label, S As String
    Dim FN As Font, FC As Font, T As String
    Set F = New UserForm
    Set X = F.Controls.Add("Forms.Label.1", "Lbl")
    X.Left = 10.37: X.Top = 12.5: X.Width = 33.33: X.Height = 100.123
    S = CStr(CLng(X.Left * 1000)) & "|" & CStr(CLng(X.Top * 1000)) & "|" & CStr(CLng(X.Width * 1000)) & "|" & CStr(CLng(X.Height * 1000))
    X.Tag = "abc": S = S & "|" & X.Tag
    X.ControlTipText = "tip": S = S & "|" & X.ControlTipText
    S = S & "|" & CStr(X.TabIndex)
    Set FN = X.Font
    FN.Size = 8.3: S = S & "|" & CStr(CLng(FN.Size * 1000))
    FN.Name = "Arial": S = S & "|" & FN.Name
    FN.Bold = True: S = S & "|" & CStr(FN.Weight)
    FN.Underline = True: S = S & "|" & CStr(FN.Underline)
    FN.Weight = 600: S = S & "|" & CStr(FN.Weight) & CStr(FN.Bold)
    FN = "Courier": T = FN: S = S & "|" & T
    FN.Italic = True: FN.Strikethrough = True: FN.Charset = 2
    S = S & "|" & CStr(FN.Italic) & CStr(FN.Strikethrough) & CStr(FN.Charset) & CStr(FN.Bold)
    Set FC = New Font
    Set X.Font = FC
    S = S & "|" & X.Font.Name & CStr(CLng(X.Font.Size * 1000))
    P_Lbl = S
End Function
Public Function P_Txt() As String
    Dim X As TextBox, S As String
    Dim FN As Font, FC As Font, T As String
    Set F = New UserForm
    Set X = F.Controls.Add("Forms.TextBox.1", "Txt")
    X.Left = 10.37: X.Top = 12.5: X.Width = 33.33: X.Height = 100.123
    S = CStr(CLng(X.Left * 1000)) & "|" & CStr(CLng(X.Top * 1000)) & "|" & CStr(CLng(X.Width * 1000)) & "|" & CStr(CLng(X.Height * 1000))
    X.Tag = "abc": S = S & "|" & X.Tag
    X.ControlTipText = "tip": S = S & "|" & X.ControlTipText
    X.HelpContextID = 5: S = S & "|" & CStr(X.HelpContextID)
    X.TabStop = False: S = S & "|" & CStr(X.TabStop)
    S = S & "|" & CStr(X.TabIndex)
    Set FN = X.Font
    FN.Size = 8.3: S = S & "|" & CStr(CLng(FN.Size * 1000))
    FN.Name = "Arial": S = S & "|" & FN.Name
    FN.Bold = True: S = S & "|" & CStr(FN.Weight)
    FN.Underline = True: S = S & "|" & CStr(FN.Underline)
    FN.Weight = 600: S = S & "|" & CStr(FN.Weight) & CStr(FN.Bold)
    FN = "Courier": T = FN: S = S & "|" & T
    FN.Italic = True: FN.Strikethrough = True: FN.Charset = 2
    S = S & "|" & CStr(FN.Italic) & CStr(FN.Strikethrough) & CStr(FN.Charset) & CStr(FN.Bold)
    Set FC = New Font
    Set X.Font = FC
    S = S & "|" & X.Font.Name & CStr(CLng(X.Font.Size * 1000))
    P_Txt = S
End Function
Public Function P_Cmd() As String
    Dim X As CommandButton, S As String
    Dim FN As Font, FC As Font, T As String
    Set F = New UserForm
    Set X = F.Controls.Add("Forms.CommandButton.1", "Cmd")
    X.Left = 10.37: X.Top = 12.5: X.Width = 33.33: X.Height = 100.123
    S = CStr(CLng(X.Left * 1000)) & "|" & CStr(CLng(X.Top * 1000)) & "|" & CStr(CLng(X.Width * 1000)) & "|" & CStr(CLng(X.Height * 1000))
    X.Tag = "abc": S = S & "|" & X.Tag
    X.ControlTipText = "tip": S = S & "|" & X.ControlTipText
    X.HelpContextID = 5: S = S & "|" & CStr(X.HelpContextID)
    X.TabStop = False: S = S & "|" & CStr(X.TabStop)
    S = S & "|" & CStr(X.TabIndex)
    Set FN = X.Font
    FN.Size = 8.3: S = S & "|" & CStr(CLng(FN.Size * 1000))
    FN.Name = "Arial": S = S & "|" & FN.Name
    FN.Bold = True: S = S & "|" & CStr(FN.Weight)
    FN.Underline = True: S = S & "|" & CStr(FN.Underline)
    FN.Weight = 600: S = S & "|" & CStr(FN.Weight) & CStr(FN.Bold)
    FN = "Courier": T = FN: S = S & "|" & T
    FN.Italic = True: FN.Strikethrough = True: FN.Charset = 2
    S = S & "|" & CStr(FN.Italic) & CStr(FN.Strikethrough) & CStr(FN.Charset) & CStr(FN.Bold)
    Set FC = New Font
    Set X.Font = FC
    S = S & "|" & X.Font.Name & CStr(CLng(X.Font.Size * 1000))
    P_Cmd = S
End Function
Public Function P_Chk() As String
    Dim X As CheckBox, S As String
    Dim FN As Font, FC As Font, T As String
    Set F = New UserForm
    Set X = F.Controls.Add("Forms.CheckBox.1", "Chk")
    X.Left = 10.37: X.Top = 12.5: X.Width = 33.33: X.Height = 100.123
    S = CStr(CLng(X.Left * 1000)) & "|" & CStr(CLng(X.Top * 1000)) & "|" & CStr(CLng(X.Width * 1000)) & "|" & CStr(CLng(X.Height * 1000))
    X.Tag = "abc": S = S & "|" & X.Tag
    X.ControlTipText = "tip": S = S & "|" & X.ControlTipText
    X.HelpContextID = 5: S = S & "|" & CStr(X.HelpContextID)
    X.TabStop = False: S = S & "|" & CStr(X.TabStop)
    S = S & "|" & CStr(X.TabIndex)
    Set FN = X.Font
    FN.Size = 8.3: S = S & "|" & CStr(CLng(FN.Size * 1000))
    FN.Name = "Arial": S = S & "|" & FN.Name
    FN.Bold = True: S = S & "|" & CStr(FN.Weight)
    FN.Underline = True: S = S & "|" & CStr(FN.Underline)
    FN.Weight = 600: S = S & "|" & CStr(FN.Weight) & CStr(FN.Bold)
    FN = "Courier": T = FN: S = S & "|" & T
    FN.Italic = True: FN.Strikethrough = True: FN.Charset = 2
    S = S & "|" & CStr(FN.Italic) & CStr(FN.Strikethrough) & CStr(FN.Charset) & CStr(FN.Bold)
    Set FC = New Font
    Set X.Font = FC
    S = S & "|" & X.Font.Name & CStr(CLng(X.Font.Size * 1000))
    P_Chk = S
End Function
Public Function P_Opt() As String
    Dim X As OptionButtonControl, S As String
    Dim FN As Font, FC As Font, T As String
    Set F = New UserForm
    Set X = F.Controls.Add("Forms.OptionButton.1", "Opt")
    X.Left = 10.37: X.Top = 12.5: X.Width = 33.33: X.Height = 100.123
    S = CStr(CLng(X.Left * 1000)) & "|" & CStr(CLng(X.Top * 1000)) & "|" & CStr(CLng(X.Width * 1000)) & "|" & CStr(CLng(X.Height * 1000))
    X.Tag = "abc": S = S & "|" & X.Tag
    X.ControlTipText = "tip": S = S & "|" & X.ControlTipText
    X.HelpContextID = 5: S = S & "|" & CStr(X.HelpContextID)
    X.TabStop = False: S = S & "|" & CStr(X.TabStop)
    S = S & "|" & CStr(X.TabIndex)
    Set FN = X.Font
    FN.Size = 8.3: S = S & "|" & CStr(CLng(FN.Size * 1000))
    FN.Name = "Arial": S = S & "|" & FN.Name
    FN.Bold = True: S = S & "|" & CStr(FN.Weight)
    FN.Underline = True: S = S & "|" & CStr(FN.Underline)
    FN.Weight = 600: S = S & "|" & CStr(FN.Weight) & CStr(FN.Bold)
    FN = "Courier": T = FN: S = S & "|" & T
    FN.Italic = True: FN.Strikethrough = True: FN.Charset = 2
    S = S & "|" & CStr(FN.Italic) & CStr(FN.Strikethrough) & CStr(FN.Charset) & CStr(FN.Bold)
    Set FC = New Font
    Set X.Font = FC
    S = S & "|" & X.Font.Name & CStr(CLng(X.Font.Size * 1000))
    P_Opt = S
End Function
Public Function P_Tog() As String
    Dim X As ToggleButton, S As String
    Dim FN As Font, FC As Font, T As String
    Set F = New UserForm
    Set X = F.Controls.Add("Forms.ToggleButton.1", "Tog")
    X.Left = 10.37: X.Top = 12.5: X.Width = 33.33: X.Height = 100.123
    S = CStr(CLng(X.Left * 1000)) & "|" & CStr(CLng(X.Top * 1000)) & "|" & CStr(CLng(X.Width * 1000)) & "|" & CStr(CLng(X.Height * 1000))
    X.Tag = "abc": S = S & "|" & X.Tag
    X.ControlTipText = "tip": S = S & "|" & X.ControlTipText
    X.HelpContextID = 5: S = S & "|" & CStr(X.HelpContextID)
    X.TabStop = False: S = S & "|" & CStr(X.TabStop)
    S = S & "|" & CStr(X.TabIndex)
    Set FN = X.Font
    FN.Size = 8.3: S = S & "|" & CStr(CLng(FN.Size * 1000))
    FN.Name = "Arial": S = S & "|" & FN.Name
    FN.Bold = True: S = S & "|" & CStr(FN.Weight)
    FN.Underline = True: S = S & "|" & CStr(FN.Underline)
    FN.Weight = 600: S = S & "|" & CStr(FN.Weight) & CStr(FN.Bold)
    FN = "Courier": T = FN: S = S & "|" & T
    FN.Italic = True: FN.Strikethrough = True: FN.Charset = 2
    S = S & "|" & CStr(FN.Italic) & CStr(FN.Strikethrough) & CStr(FN.Charset) & CStr(FN.Bold)
    Set FC = New Font
    Set X.Font = FC
    S = S & "|" & X.Font.Name & CStr(CLng(X.Font.Size * 1000))
    P_Tog = S
End Function
Public Function P_Lst() As String
    Dim X As ListBox, S As String
    Dim FN As Font, FC As Font, T As String
    Set F = New UserForm
    Set X = F.Controls.Add("Forms.ListBox.1", "Lst")
    X.Left = 10.37: X.Top = 12.5: X.Width = 33.33: X.Height = 100.123
    S = CStr(CLng(X.Left * 1000)) & "|" & CStr(CLng(X.Top * 1000)) & "|" & CStr(CLng(X.Width * 1000)) & "|" & CStr(CLng(X.Height * 1000))
    X.Tag = "abc": S = S & "|" & X.Tag
    X.ControlTipText = "tip": S = S & "|" & X.ControlTipText
    X.HelpContextID = 5: S = S & "|" & CStr(X.HelpContextID)
    X.TabStop = False: S = S & "|" & CStr(X.TabStop)
    S = S & "|" & CStr(X.TabIndex)
    Set FN = X.Font
    FN.Size = 8.3: S = S & "|" & CStr(CLng(FN.Size * 1000))
    FN.Name = "Arial": S = S & "|" & FN.Name
    FN.Bold = True: S = S & "|" & CStr(FN.Weight)
    FN.Underline = True: S = S & "|" & CStr(FN.Underline)
    FN.Weight = 600: S = S & "|" & CStr(FN.Weight) & CStr(FN.Bold)
    FN = "Courier": T = FN: S = S & "|" & T
    FN.Italic = True: FN.Strikethrough = True: FN.Charset = 2
    S = S & "|" & CStr(FN.Italic) & CStr(FN.Strikethrough) & CStr(FN.Charset) & CStr(FN.Bold)
    Set FC = New Font
    Set X.Font = FC
    S = S & "|" & X.Font.Name & CStr(CLng(X.Font.Size * 1000))
    P_Lst = S
End Function
Public Function P_Cmb() As String
    Dim X As ComboBox, S As String
    Dim FN As Font, FC As Font, T As String
    Set F = New UserForm
    Set X = F.Controls.Add("Forms.ComboBox.1", "Cmb")
    X.Left = 10.37: X.Top = 12.5: X.Width = 33.33: X.Height = 100.123
    S = CStr(CLng(X.Left * 1000)) & "|" & CStr(CLng(X.Top * 1000)) & "|" & CStr(CLng(X.Width * 1000)) & "|" & CStr(CLng(X.Height * 1000))
    X.Tag = "abc": S = S & "|" & X.Tag
    X.ControlTipText = "tip": S = S & "|" & X.ControlTipText
    X.HelpContextID = 5: S = S & "|" & CStr(X.HelpContextID)
    X.TabStop = False: S = S & "|" & CStr(X.TabStop)
    S = S & "|" & CStr(X.TabIndex)
    Set FN = X.Font
    FN.Size = 8.3: S = S & "|" & CStr(CLng(FN.Size * 1000))
    FN.Name = "Arial": S = S & "|" & FN.Name
    FN.Bold = True: S = S & "|" & CStr(FN.Weight)
    FN.Underline = True: S = S & "|" & CStr(FN.Underline)
    FN.Weight = 600: S = S & "|" & CStr(FN.Weight) & CStr(FN.Bold)
    FN = "Courier": T = FN: S = S & "|" & T
    FN.Italic = True: FN.Strikethrough = True: FN.Charset = 2
    S = S & "|" & CStr(FN.Italic) & CStr(FN.Strikethrough) & CStr(FN.Charset) & CStr(FN.Bold)
    Set FC = New Font
    Set X.Font = FC
    S = S & "|" & X.Font.Name & CStr(CLng(X.Font.Size * 1000))
    P_Cmb = S
End Function
Public Function P_Frm() As String
    Dim X As Frame, S As String
    Dim FN As Font, FC As Font, T As String
    Set F = New UserForm
    Set X = F.Controls.Add("Forms.Frame.1", "Frm")
    X.Left = 10.37: X.Top = 12.5: X.Width = 33.33: X.Height = 100.123
    S = CStr(CLng(X.Left * 1000)) & "|" & CStr(CLng(X.Top * 1000)) & "|" & CStr(CLng(X.Width * 1000)) & "|" & CStr(CLng(X.Height * 1000))
    X.Tag = "abc": S = S & "|" & X.Tag
    X.ControlTipText = "tip": S = S & "|" & X.ControlTipText
    X.HelpContextID = 5: S = S & "|" & CStr(X.HelpContextID)
    X.TabStop = False: S = S & "|" & CStr(X.TabStop)
    S = S & "|" & CStr(X.TabIndex)
    Set FN = X.Font
    FN.Size = 8.3: S = S & "|" & CStr(CLng(FN.Size * 1000))
    FN.Name = "Arial": S = S & "|" & FN.Name
    FN.Bold = True: S = S & "|" & CStr(FN.Weight)
    FN.Underline = True: S = S & "|" & CStr(FN.Underline)
    FN.Weight = 600: S = S & "|" & CStr(FN.Weight) & CStr(FN.Bold)
    FN = "Courier": T = FN: S = S & "|" & T
    FN.Italic = True: FN.Strikethrough = True: FN.Charset = 2
    S = S & "|" & CStr(FN.Italic) & CStr(FN.Strikethrough) & CStr(FN.Charset) & CStr(FN.Bold)
    Set FC = New Font
    Set X.Font = FC
    S = S & "|" & X.Font.Name & CStr(CLng(X.Font.Size * 1000))
    P_Frm = S
End Function
Public Function P_Img() As String
    Dim X As Image, S As String
    Set F = New UserForm
    Set X = F.Controls.Add("Forms.Image.1", "Img")
    X.Left = 10.37: X.Top = 12.5: X.Width = 33.33: X.Height = 100.123
    S = CStr(CLng(X.Left * 1000)) & "|" & CStr(CLng(X.Top * 1000)) & "|" & CStr(CLng(X.Width * 1000)) & "|" & CStr(CLng(X.Height * 1000))
    X.Tag = "abc": S = S & "|" & X.Tag
    X.ControlTipText = "tip": S = S & "|" & X.ControlTipText
    P_Img = S
End Function
Public Function P_Spn() As String
    Dim X As SpinButton, S As String
    Set F = New UserForm
    Set X = F.Controls.Add("Forms.SpinButton.1", "Spn")
    X.Left = 10.37: X.Top = 12.5: X.Width = 33.33: X.Height = 100.123
    S = CStr(CLng(X.Left * 1000)) & "|" & CStr(CLng(X.Top * 1000)) & "|" & CStr(CLng(X.Width * 1000)) & "|" & CStr(CLng(X.Height * 1000))
    X.Tag = "abc": S = S & "|" & X.Tag
    X.ControlTipText = "tip": S = S & "|" & X.ControlTipText
    X.HelpContextID = 5: S = S & "|" & CStr(X.HelpContextID)
    X.TabStop = False: S = S & "|" & CStr(X.TabStop)
    S = S & "|" & CStr(X.TabIndex)
    P_Spn = S
End Function
Public Function P_Scr() As String
    Dim X As ScrollBar, S As String
    Set F = New UserForm
    Set X = F.Controls.Add("Forms.ScrollBar.1", "Scr")
    X.Left = 10.37: X.Top = 12.5: X.Width = 33.33: X.Height = 100.123
    S = CStr(CLng(X.Left * 1000)) & "|" & CStr(CLng(X.Top * 1000)) & "|" & CStr(CLng(X.Width * 1000)) & "|" & CStr(CLng(X.Height * 1000))
    X.Tag = "abc": S = S & "|" & X.Tag
    X.ControlTipText = "tip": S = S & "|" & X.ControlTipText
    X.HelpContextID = 5: S = S & "|" & CStr(X.HelpContextID)
    X.TabStop = False: S = S & "|" & CStr(X.TabStop)
    S = S & "|" & CStr(X.TabIndex)
    P_Scr = S
End Function
Public Function P_Tab() As String
    Dim X As TabStrip, S As String
    Dim FN As Font, FC As Font, T As String
    Set F = New UserForm
    Set X = F.Controls.Add("Forms.TabStrip.1", "Tab")
    X.Left = 10.37: X.Top = 12.5: X.Width = 33.33: X.Height = 100.123
    S = CStr(CLng(X.Left * 1000)) & "|" & CStr(CLng(X.Top * 1000)) & "|" & CStr(CLng(X.Width * 1000)) & "|" & CStr(CLng(X.Height * 1000))
    X.Tag = "abc": S = S & "|" & X.Tag
    X.ControlTipText = "tip": S = S & "|" & X.ControlTipText
    X.HelpContextID = 5: S = S & "|" & CStr(X.HelpContextID)
    X.TabStop = False: S = S & "|" & CStr(X.TabStop)
    S = S & "|" & CStr(X.TabIndex)
    Set FN = X.Font
    FN.Size = 8.3: S = S & "|" & CStr(CLng(FN.Size * 1000))
    FN.Name = "Arial": S = S & "|" & FN.Name
    FN.Bold = True: S = S & "|" & CStr(FN.Weight)
    FN.Underline = True: S = S & "|" & CStr(FN.Underline)
    FN.Weight = 600: S = S & "|" & CStr(FN.Weight) & CStr(FN.Bold)
    FN = "Courier": T = FN: S = S & "|" & T
    FN.Italic = True: FN.Strikethrough = True: FN.Charset = 2
    S = S & "|" & CStr(FN.Italic) & CStr(FN.Strikethrough) & CStr(FN.Charset) & CStr(FN.Bold)
    Set FC = New Font
    Set X.Font = FC
    S = S & "|" & X.Font.Name & CStr(CLng(X.Font.Size * 1000))
    P_Tab = S
End Function
Public Function P_Mpg() As String
    Dim X As MultiPage, S As String
    Dim FN As Font, FC As Font, T As String
    Set F = New UserForm
    Set X = F.Controls.Add("Forms.MultiPage.1", "Mpg")
    X.Left = 10.37: X.Top = 12.5: X.Width = 33.33: X.Height = 100.123
    S = CStr(CLng(X.Left * 1000)) & "|" & CStr(CLng(X.Top * 1000)) & "|" & CStr(CLng(X.Width * 1000)) & "|" & CStr(CLng(X.Height * 1000))
    X.Tag = "abc": S = S & "|" & X.Tag
    X.ControlTipText = "tip": S = S & "|" & X.ControlTipText
    X.HelpContextID = 5: S = S & "|" & CStr(X.HelpContextID)
    X.TabStop = False: S = S & "|" & CStr(X.TabStop)
    S = S & "|" & CStr(X.TabIndex)
    Set FN = X.Font
    FN.Size = 8.3: S = S & "|" & CStr(CLng(FN.Size * 1000))
    FN.Name = "Arial": S = S & "|" & FN.Name
    FN.Bold = True: S = S & "|" & CStr(FN.Weight)
    FN.Underline = True: S = S & "|" & CStr(FN.Underline)
    FN.Weight = 600: S = S & "|" & CStr(FN.Weight) & CStr(FN.Bold)
    FN = "Courier": T = FN: S = S & "|" & T
    FN.Italic = True: FN.Strikethrough = True: FN.Charset = 2
    S = S & "|" & CStr(FN.Italic) & CStr(FN.Strikethrough) & CStr(FN.Charset) & CStr(FN.Bold)
    Set FC = New Font
    Set X.Font = FC
    S = S & "|" & X.Font.Name & CStr(CLng(X.Font.Size * 1000))
    P_Mpg = S
End Function
Public Function P_Form() As String
    Dim U As UserForm, S As String
    Set U = New UserForm
    S = CStr(CLng(U.Width * 1000)) & "|" & CStr(CLng(U.Height * 1000)) & "|" & CStr(CLng(U.InsideWidth * 1000)) & "|" & CStr(CLng(U.InsideHeight * 1000)) & "|" & CStr(U.Zoom)
    U.Width = 300.37: U.Height = 300.37
    S = S & "|" & CStr(CLng(U.Width * 1000)) & "|" & CStr(CLng(U.Height * 1000)) & "|" & CStr(CLng(U.InsideWidth * 1000)) & "|" & CStr(CLng(U.InsideHeight * 1000))
    U.Zoom = 150
    S = S & "|" & CStr(U.Zoom)
    U.Width = 10: U.Height = 10
    S = S & "|" & CStr(CLng(U.Width * 1000)) & "|" & CStr(CLng(U.Height * 1000))
    P_Form = S
End Function
"#;

/// The result of the `nth` (0-based) occurrence of a script line.
fn native_nth(script: &str, line: &str, nth: usize) -> String {
    let native = native();
    let lines = native["scripts"][script]["lines"].as_array().unwrap();
    let results: Vec<&str> = native["scripts"][script]["result"]
        .as_str()
        .unwrap()
        .lines()
        .collect();
    let index = lines
        .iter()
        .enumerate()
        .filter(|(_, l)| l.as_str().unwrap() == line)
        .map(|(i, _)| i)
        .nth(nth)
        .unwrap_or_else(|| panic!("native script {script} has no occurrence {nth} of {line}"));
    results[index].split_once(" => ").unwrap().1.to_string()
}

/// The value (text after "=> ") native returned for the line after `let_line`.
fn native_after(script: &str, let_line: &str) -> String {
    let native = native();
    let lines = native["scripts"][script]["lines"].as_array().unwrap();
    let results: Vec<&str> = native["scripts"][script]["result"]
        .as_str()
        .unwrap()
        .lines()
        .collect();
    let index = lines
        .iter()
        .position(|l| l.as_str().unwrap() == let_line)
        .unwrap_or_else(|| panic!("native script {script} has no line {let_line}"));
    results[index + 1].split_once(" => ").unwrap().1.to_string()
}

/// "Single=10350m" to 10350; "String=abc" to "abc"; "Boolean=True" to "True".
fn bare(value: &str) -> String {
    let (_, text) = value.split_once('=').unwrap();
    text.trim_end_matches('m').to_string()
}

#[test]
fn typed_members_of_every_control_class_match_the_native_record() {
    // Native values for the writes below, from the retained scripts.
    let left = bare(&native_after("geometry", "let Gx Left s 10.37"));
    let top = bare(&native_after("geometry", "let Gx Top s 12.5"));
    let width = bare(&native_after("geometry", "let Gx Width s 33.33"));
    let height = bare(&native_after("geometry", "let Gx Height s 100.123"));
    let tag = bare(&native_after("tab", "let Txt Tag t abc"));
    let tip = bare(&native_after("tab", "let Txt ControlTipText t tip"));
    let help = bare(&native_after("tab", "let Txt HelpContextID l 5"));
    let stop = bare(&native_after("tab", "let Txt TabStop b 0"));
    let size = bare(&native_after("font", "let Txt Font.Size d 8.3"));
    let name = bare(&native_after("font", "let Txt Font.Name t Arial"));
    let weight = bare(&native_after("font", "get Txt Font.Bold"));
    let underline = bare(&native_after("font", "let Txt Font.Underline b 1"));
    assert_eq!(
        (left.as_str(), top.as_str(), width.as_str(), height.as_str()),
        ("10350", "12500", "33350", "100100")
    );
    assert_eq!(
        (tag.as_str(), tip.as_str(), help.as_str(), stop.as_str()),
        ("abc", "tip", "5", "False")
    );
    assert_eq!((size.as_str(), name.as_str()), ("8300", "Arial"));
    assert_eq!((weight.as_str(), underline.as_str()), ("700", "True"));

    let mut runtime = runtime_for(TYPED_VBA.to_string(), "TypedMembers");
    // UserForm: defaults, a Width and Height of 300.37, the Zoom 150, and the minimum size, from the geometry script.
    let at = |line: &str, nth: usize| native_nth("geometry", line, nth);
    let form = [
        at("get Form Width", 0),
        at("get Form Height", 0),
        at("get Form InsideWidth", 0),
        at("get Form InsideHeight", 0),
        at("get Form Zoom", 0),
        native_after("geometry", "let Form Width s 300.37"),
        native_after("geometry", "let Form Height s 300.37"),
        at("get Form InsideWidth", 1),
        at("get Form InsideHeight", 1),
        native_after("geometry", "let Form Zoom d 150.5"),
        native_after("geometry", "let Form Width s 10"),
        native_after("geometry", "let Form Height s 10"),
    ]
    .map(|value| bare(&value))
    .join("|");
    assert_eq!(call_text(&mut runtime, "P_Form", vec![]), form);
    for kind in KINDS {
        let mut expected = format!("{left}|{top}|{width}|{height}|{tag}|{tip}");
        if kind.help {
            expected += &format!("|{help}");
        }
        if kind.tab_stop {
            expected += &format!("|{stop}");
        }
        if kind.tab_index {
            // The control is the first in a fresh form.
            expected += "|0";
        }
        if kind.font {
            // size 8.3, name, Weight 700 after Bold, Underline, then Italic/Strikethrough/Charset/Bold after the
            // writes, then a fresh Font assigned over the control's (Tahoma, 8.25).
            expected +=
                &format!("|{size}|{name}|700|True|600True|Courier|TrueTrue2True|Tahoma8250");
        }
        let actual = call_text(&mut runtime, &format!("P_{}", kind.name), vec![]);
        assert_eq!(actual, expected, "{}", kind.ty);
    }
}
