//! ListBox keeps two heights and snaps to whole rows (oxforms-jbjp.118).
//!
//! Replays `native-round13.json` (160 ordered operation sequences, Excel 16.0.20527, 100% and
//! 150% form zoom, private desktop) and the 456-row `native-round12.json` sweep against the
//! production ListBox: the public Height H, the layout height L, the snap on a Font or
//! BorderStyle change or IntegralHeight False to True, the restore of L at the first Show, and
//! the zoom-aware row height. Heights compare within 0.26pt (native keeps pixel and twip
//! residuals up to 0.25pt); the few rows that differ by more are listed by name below, so a
//! change in what is modelled shows up as a changed list.
mod common;
use calcvba_runtime::Variant;
use common::{call_text, evidence, runtime_for};
use serde_json::Value;

const HARNESS: &str = r#"Option Explicit
Private F As UserForm
Private R As OxReducer
Private L As ListBox
Private Sub CalcFormsHostBuild()
    Set F = New UserForm
End Sub
Private Sub CalcFormsHostPerformInitialize()
End Sub
Private Sub CalcFormsHostRender()
    F.Render 96, 96
End Sub
Private Function Hundredths(ByVal V As Single) As String
    Hundredths = CStr(CLng(V * 100))
End Function
Private Sub NewList(ByVal Zoom As Long)
    Dim K As Long
    Set F = New UserForm
    Set L = F.Controls.Add("Forms.ListBox.1", "L")
    L.Left = 6
    L.Top = 6
    L.Width = 120
    L.Height = 72
    For K = 0 To 29
        L.AddItem "Row " & CStr(K)
    Next K
    F.Zoom = Zoom
    Set R = New OxReducer
    R.Init F
End Sub
' The native SeqRun macro (capture_round13_native.py), one operation at a time.
Public Function SeqRun(ByVal Zoom As Long, ByVal Ops As String) As String
    Dim S As String, Parts() As String, I As Long, Op As String, Arg As String, E As String
    NewList Zoom
    S = "start=" & Hundredths(L.Height) & ";"
    Parts = Split(Ops, ",")
    For I = 0 To UBound(Parts)
        Op = Left(Parts(I), 1)
        Arg = Mid(Parts(I), 2)
        Select Case Op
            Case "F"
                L.Font.Name = "Tahoma"
                L.Font.Size = Val(Arg)
            Case "A"
                L.Font.Name = "Arial"
                L.Font.Size = Val(Arg)
            Case "B"
                L.BorderStyle = CLng(Arg)
            Case "I"
                L.IntegralHeight = (Arg = "1")
            Case "H"
                L.Height = Val(Arg)
            Case "S"
                E = R.Dispatch("show", 0, 0, 0, 0)
            Case "T"
                L.ListIndex = 29
            Case "Z"
                L.ListIndex = 0
        End Select
        If Op = "T" Or Op = "Z" Then
            S = S & Parts(I) & "=top" & CStr(L.TopIndex) & ";"
        Else
            S = S & Parts(I) & "=" & Hundredths(L.Height) & ";"
        End If
    Next I
    SeqRun = S
End Function
Private Function State() As String
    State = "index=" & CStr(L.ListIndex) & ";top=" & CStr(L.TopIndex) & ";count=" & CStr(L.ListCount) & ";height=" & CStr(L.Height)
End Function
Private Function DynSet(ByVal Member As String, ByVal Value As Long) As String
    On Error Resume Next
    Select Case Member
        Case "top"
            L.TopIndex = Value
        Case "index"
            L.ListIndex = Value
        Case "height"
            L.Height = Value
    End Select
    DynSet = "err=" & CStr(Err.Number) & ";" & State()
End Function
' The run-8 viewport sequence (capture_list_viewport.py) on a ListBox created by Controls.Add, as
' DynPrepare / DynSet in capture_round14_native.py.
Public Function DynRun(ByVal Count As Long, ByVal DoClear As Boolean, ByVal DoShow As Boolean) As String
    Dim I As Long, S As String, E As String
    Set F = New UserForm
    Set L = F.Controls.Add("Forms.ListBox.1", "Choices")
    L.Left = 12
    L.Top = 114
    L.Width = 130
    L.Height = 72
    L.AddItem "Alpha"
    L.AddItem "Beta"
    L.AddItem "Gamma"
    F.Zoom = 100
    Set R = New OxReducer
    R.Init F
    If DoClear Then L.Clear
    L.Height = 72
    For I = 0 To Count - 1
        L.AddItem "Row " & CStr(I)
    Next I
    L.ListIndex = 1
    L.TopIndex = 0
    If DoShow Then E = R.Dispatch("show", 0, 0, 0, 0)
    S = State() & vbLf
    S = S & "top=16:" & DynSet("top", 16) & vbLf
    S = S & "top=99:" & DynSet("top", 99) & vbLf
    S = S & "index=7:" & DynSet("index", 7) & vbLf
    S = S & "index=22:" & DynSet("index", 22) & vbLf
    S = S & "index=29:" & DynSet("index", 29) & vbLf
    S = S & "height=120:" & DynSet("height", 120) & vbLf
    S = S & "top=99:" & DynSet("top", 99) & vbLf
    S = S & "height=30:" & DynSet("height", 30) & vbLf
    DynRun = S
End Function
' The native ListRun macro (capture_round12_native.py).
Public Function ListRun(ByVal Zoom As Long, ByVal FontName As String, ByVal FontSize As Single, ByVal Border As Long, ByVal IH As Boolean, ByVal H As Single) As String
    Dim S As String, E As String
    NewList Zoom
    L.Font.Name = FontName
    L.Font.Size = FontSize
    L.BorderStyle = Border
    L.IntegralHeight = IH
    S = "init=" & Hundredths(L.Height)
    L.Height = H
    S = S & ";set=" & Hundredths(L.Height)
    E = R.Dispatch("show", 0, 0, 0, 0)
    S = S & ";shown=" & Hundredths(L.Height)
    L.Height = H
    S = S & ";reset=" & Hundredths(L.Height)
    L.ListIndex = 29
    S = S & ";top=" & CStr(L.TopIndex)
    L.ListIndex = 0
    S = S & ";top0=" & CStr(L.TopIndex)
    ListRun = S
End Function
"#;

/// Split "a=1;b=2;" into pairs.
fn pairs(text: &str) -> Vec<(String, String)> {
    text.split(';')
        .filter(|part| !part.is_empty())
        .map(|part| {
            let (key, value) = part.split_once('=').unwrap();
            (key.to_string(), value.to_string())
        })
        .collect()
}

/// True when the native text value and the runtime hundredths agree within 0.26pt, or both are the
/// same `top` reading.
fn agree(native: &str, runtime: &str) -> bool {
    if native.starts_with("top") {
        return native == runtime;
    }
    let native: f64 = native.parse().unwrap();
    let runtime: f64 = runtime.parse::<f64>().unwrap() / 100.0;
    (native - runtime).abs() <= 0.26
}

#[test]
fn ordered_sequences_match_native_heights_and_scroll_origins() {
    let native: Value = serde_json::from_slice(
        &std::fs::read(evidence("oxforms-jbjp.118").join("native-round13.json")).unwrap(),
    )
    .unwrap();
    let mut runtime = runtime_for(HARNESS.to_string(), "ListHeightProbe");
    let mut total = 0;
    let mut differences = Vec::new();
    for row in native["list_sequences"].as_array().unwrap() {
        let zoom = row["zoom"].as_i64().unwrap() as i32;
        let ops = row["ops"].as_str().unwrap();
        let actual = call_text(
            &mut runtime,
            "SeqRun",
            vec![Variant::from_i32(zoom), Variant::from_string(ops)],
        );
        let (native_steps, actual_steps) = (pairs(row["result"].as_str().unwrap()), pairs(&actual));
        assert_eq!(
            native_steps.len(),
            actual_steps.len(),
            "{zoom} {ops}: {actual}"
        );
        for (n, a) in native_steps.iter().zip(&actual_steps) {
            assert_eq!(n.0, a.0);
            total += 1;
            if !agree(&n.1, &a.1) {
                differences.push(format!(
                    "{zoom} {ops} {}: native {} runtime {}",
                    n.0, n.1, a.1
                ));
                break; // later steps start from a different height
            }
        }
    }
    assert!(total > 1000);
    differences.sort();
    assert_eq!(differences, expected_sequence_differences());
}

/// Not modelled, five Height values of one configuration: after Font 10pt, a border change that snaps
/// at 96 dpi and then Font 8.25pt back, a 150% form returns 61.00 natively and 58.00 here (the native
/// snap reads the row of the font being left). No other sequence differs.
fn expected_sequence_differences() -> Vec<String> {
    let mut all: Vec<String> = [30, 50, 72, 100, 120]
        .iter()
        .map(|h| format!("150 S,F10,R,H{h},R,B0,R,B1,R,F8.25,R F8.25: native 61 runtime 5800"))
        .collect();
    all.sort();
    all
}

#[test]
fn font_border_integral_height_sweep_matches_native() {
    let native: Value = serde_json::from_slice(
        &std::fs::read(evidence("oxforms-jbjp.131").join("native-round12.json")).unwrap(),
    )
    .unwrap();
    let mut runtime = runtime_for(HARNESS.to_string(), "ListHeightProbe");
    let mut differences = Vec::new();
    let rows = native["list"].as_array().unwrap();
    assert_eq!(rows.len(), 456);
    for row in rows {
        let actual = call_text(
            &mut runtime,
            "ListRun",
            vec![
                Variant::from_i32(row["zoom"].as_i64().unwrap() as i32),
                Variant::from_string(row["font"].as_str().unwrap()),
                Variant::from_f32(row["size"].as_f64().unwrap() as f32),
                Variant::from_i32(row["border"].as_i64().unwrap() as i32),
                Variant::from_bool(row["integral"].as_bool().unwrap()),
                Variant::from_f32(row["height"].as_f64().unwrap() as f32),
            ],
        );
        let label = format!(
            "{} {} {} b{} i{} h{}",
            row["zoom"], row["font"], row["size"], row["border"], row["integral"], row["height"]
        );
        let (n, a) = (pairs(row["result"].as_str().unwrap()), pairs(&actual));
        assert_eq!(n.len(), a.len(), "{label}: {actual}");
        for (n, a) in n.iter().zip(&a) {
            assert_eq!(n.0, a.0);
            let same = if n.0.starts_with("top") {
                n.1 == a.1
            } else {
                agree(&n.1, &a.1)
            };
            if !same {
                differences.push(format!("{label} {}: native {} runtime {}", n.0, n.1, a.1));
            }
        }
    }
    // Group by configuration (height dropped) so the unmodelled families are few and named.
    let mut groups: std::collections::BTreeMap<String, usize> = Default::default();
    for difference in &differences {
        let (label, rest) = difference.split_once(" h").unwrap();
        let measure = rest.split_once(' ').unwrap().1;
        let key = format!("{label}: {}", measure.split(':').next().unwrap());
        *groups.entry(key).or_default() += 1;
    }
    assert_eq!(groups, expected_sweep_groups());
}

/// Not modelled, all in the scroll range (`top`; every height value matches): a 150% form with
/// IntegralHeight False and a single-line border reads one row more natively (19 Height values each
/// for Tahoma 10 and Arial 12), and the exact-multiple case Height 60 at Tahoma 8.25 without border
/// (57pt of rows over 9.5pt is 6.0 rows; native shows 7, the 100% case Height 120 shows 12).
fn expected_sweep_groups() -> std::collections::BTreeMap<String, usize> {
    [
        ("150 \"Arial\" 12 b1 ifalse: top", 19),
        ("150 \"Tahoma\" 10 b1 ifalse: top", 19),
        ("150 \"Tahoma\" 8.25 b0 ifalse: top", 1),
    ]
    .into_iter()
    .map(|(k, v)| (k.to_string(), v))
    .collect()
}

#[test]
fn run_eight_viewport_sequence_on_a_dynamic_listbox_matches_native() {
    // native-round14.json: the run-8 sequence (Clear or not, Height 72, 23 or 30 rows of "Row n",
    // ListIndex 1, TopIndex 0, Show or not) on a ListBox created by Controls.Add, 8 configurations.
    // It scrolls Height 72 as 7 rows (TopIndex 99 gives 16 of 23); the designer ListBox of run 8
    // scrolls it as 8 rows (15 of 23), which the runtime reproduces for a ListBox the FRM
    // materializer creates (`MarkFromDesigner`).
    let native: Value = serde_json::from_slice(
        &std::fs::read(evidence("oxforms-jbjp.105").join("native-round14.json")).unwrap(),
    )
    .unwrap();
    let mut runtime = runtime_for(HARNESS.to_string(), "ListHeightProbe");
    let mut differing = Vec::new();
    let mut total = 0;
    for case in native["listbox_dynamic"].as_array().unwrap() {
        let actual = call_text(
            &mut runtime,
            "DynRun",
            vec![
                Variant::from_i32(case["count"].as_i64().unwrap() as i32),
                Variant::from_bool(case["clear"].as_bool().unwrap()),
                Variant::from_bool(case["show"].as_bool().unwrap()),
            ],
        );
        let actual: Vec<&str> = actual.lines().collect();
        let expected = case["rows"].as_array().unwrap();
        assert_eq!(actual.len(), expected.len());
        for (a, n) in actual.iter().zip(expected) {
            total += 1;
            if *a != n.as_str().unwrap() {
                differing.push(format!(
                    "{} {}: native {n} runtime {a}",
                    case["count"], case["clear"]
                ));
            }
        }
    }
    assert_eq!(total, 72);
    assert_eq!(differing, Vec::<String>::new());
}
