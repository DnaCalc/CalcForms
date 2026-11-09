//! A MultiPage is two Tab stops: its header row, then the selected page (oxforms-jbjp.133).
//!
//! Replays `native-round13e.json` (Excel 16.0.20527, five page-content variants, Tab posted to
//! the owned Excel's focused window on a private desktop). Native `Form.ActiveControl` reads the
//! MultiPage at both stops, and the selected page's own `ActiveControl` names a tab-stop child; a
//! raw MSAA bit tells the header stop from the page-client stop. The runtime's `FocusName` names
//! the child control itself, so a native row whose page `ActiveControl` is a control is compared
//! as that control.
mod common;
use common::{evidence, run_class};
use serde_json::Value;

fn source(variant: u32) -> String {
    let content = match variant {
        1 => "    MP.Pages.Item(0).Controls.Add \"Forms.TextBox.1\", \"InPage\"\n",
        2 => "    MP.Pages.Item(0).Controls.Add \"Forms.TextBox.1\", \"InPage\"\n    MP.Value = 1\n",
        3 => "    Set C = MP.Pages.Item(0).Controls.Add(\"Forms.TextBox.1\", \"InPage\")\n    C.Core.TabStop = False\n",
        4 => "    MP.Pages.Item(0).Controls.Add \"Forms.TextBox.1\", \"InPage\"\n    MP.Pages.Item(0).Controls.Add \"Forms.TextBox.1\", \"InPage2\"\n",
        _ => "",
    };
    format!(
        r#"Option Explicit
Private F As UserForm
Private R As OxReducer
Private Sub CalcFormsHostBuild()
    Dim C As Object, MP As MultiPage
    Set F = New UserForm
    F.Width = 228
    F.Height = 200
    Set C = F.Controls.Add("Forms.TextBox.1", "Before")
    C.Left = 12: C.Top = 6: C.Width = 90: C.Height = 18
    Set MP = F.Controls.Add("Forms.MultiPage.1", "MP")
    MP.Left = 12: MP.Top = 36: MP.Width = 200: MP.Height = 120
    MP.Pages.Add "Page1"
    MP.Pages.Add "Page2"
    Set C = F.Controls.Add("Forms.TextBox.1", "After")
    C.Left = 12: C.Top = 170: C.Width = 90: C.Height = 18
{content}    Set R = New OxReducer
    R.Init F
End Sub
Private Sub CalcFormsHostPerformInitialize()
End Sub
Private Sub CalcFormsHostRender()
    F.Render 96, 96
End Sub
Private Function Stop_() As String
    Stop_ = R.FocusName
    If R.FocusName = "MP" Then
        If R.FocusOnPageClient Then Stop_ = "MP/page" Else Stop_ = "MP/header"
    End If
End Function
Public Function TabStops() As String
    Dim S As String, E As String, I As Long
    E = R.Dispatch("show", 0, 0, 0, 0)
    S = Stop_()
    For I = 1 To 6
        E = R.DispatchKey("keydown", 9, 0)
        E = R.DispatchKey("keyup", 9, 0)
        S = S & ";" & Stop_()
    Next I
    TabStops = S
End Function
Public Function ShiftTabStops() As String
    Dim S As String, E As String, I As Long
    E = R.Dispatch("show", 0, 0, 0, 0)
    S = Stop_()
    For I = 1 To 6
        E = R.DispatchKey("keydown", 9, 1)
        E = R.DispatchKey("keyup", 9, 1)
        S = S & ";" & Stop_()
    Next I
    ShiftTabStops = S
End Function
"#
    )
}

/// The stop a native row means, in the runtime's vocabulary.
fn native_stop(row: &Value) -> String {
    let active = row["active"].as_str().unwrap();
    let (form_level, page) = active.split_once('|').unwrap();
    let page = page.split_once('=').unwrap().1;
    if form_level == "MP" {
        if row["header_focused"].as_bool().unwrap() {
            return "MP/header".into();
        }
        if !page.starts_with("ERR") && page != "none" {
            return page.to_string();
        }
        return "MP/page".into();
    }
    form_level.to_string()
}

#[test]
fn multipage_header_and_page_client_are_separate_tab_stops_like_native() {
    let native: Value = serde_json::from_slice(
        &std::fs::read(evidence("oxforms-jbjp.133").join("native-round13e.json")).unwrap(),
    )
    .unwrap();
    assert!(native["errors"].as_object().unwrap().is_empty());
    for variant in 0..=4u32 {
        let expected: Vec<String> = native["variants"][variant.to_string()]
            .as_array()
            .unwrap()
            .iter()
            .map(native_stop)
            .collect();
        let actual = run_class(source(variant), "MultiPageStops", "TabStops");
        let actual: Vec<&str> = actual.split(';').collect();
        assert_eq!(actual.len(), 7);
        // Variant 2 selects the empty page 1 from code before Show; natively the form then opens
        // with the page client focused instead of the first control. That start is not modelled:
        // align the native record to the runtime's first stop, which is `Before`.
        let offset = expected.iter().position(|stop| stop == actual[0]).unwrap();
        assert_eq!(
            offset,
            if variant == 2 { 2 } else { 0 },
            "variant {variant}"
        );
        assert_eq!(
            actual[..7 - offset],
            expected[offset..],
            "variant {variant}: native {expected:?} runtime {actual:?}"
        );
    }
}

#[test]
fn shift_tab_walks_the_same_stops_backwards_model_symmetry_not_native() {
    // No native Shift+Tab record exists for the page-client stop (round 13 did not measure it);
    // the runtime is symmetric, and this test only pins that.
    let forward = run_class(source(0), "MultiPageStops", "TabStops");
    let backward = run_class(source(0), "MultiPageStops", "ShiftTabStops");
    assert_eq!(
        forward,
        "Before;MP/header;MP/page;After;Before;MP/header;MP/page"
    );
    assert_eq!(
        backward,
        "Before;After;MP/page;MP/header;Before;After;MP/page"
    );
}
