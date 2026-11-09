//! Native Excel 16.0.20527 Variant Value coercion for ToggleButton and CheckBox (oxforms-jbjp.128).
//! Replays every retained native row (assignment kind, starting state, Value read back, Change/Click
//! order) against the runtime classes. OptionButton rows differ only by native Click suppression on
//! deselection and are covered by the existing option-group evidence.
use calcforms_calcvba_adapter::{
    host_services::HostServices, office::WorkbookForm, runtime::OxRuntime,
};
use calcforms_pal::scene::StubShaper;
use calcvba_bundle::ProjectMemberKind;
use calcvba_runtime::{ObjectRef, Variant};
use calcvba_symbol::manifest::{ModuleAttributes, ModuleKind, ModuleUnit};
use serde_json::Value;
use std::{path::Path, sync::Arc};

const DRIVER_HEAD: &str = r#"Option Explicit
Private WithEvents T As MSForms.ToggleButton
Private WithEvents C As MSForms.CheckBox
Private Log As String
Private Function V(x As Variant) As String
    If IsNull(x) Then
        V = "Null"
    ElseIf IsEmpty(x) Then
        V = "Empty"
    Else
        V = TypeName(x) & "=" & CStr(x)
    End If
End Function
Public Sub Attach()
    Set T = PlannerForm.Controls.Add("Forms.ToggleButton.1", "ProbeT")
    Set C = PlannerForm.Controls.Add("Forms.CheckBox.1", "ProbeC")
End Sub
Private Sub T_Change(): Log = Log & "T.Change(" & V(T.Value) & ");": End Sub
Private Sub T_Click(): Log = Log & "T.Click(" & V(T.Value) & ");": End Sub
Private Sub C_Change(): Log = Log & "C.Change(" & V(C.Value) & ");": End Sub
Private Sub C_Click(): Log = Log & "C.Click(" & V(C.Value) & ");": End Sub
Public Function Reset(ByVal Kind As String, ByVal Init As Long) As String
    If Kind = "T" Then
        Select Case Init
            Case 0: T.Value = False
            Case 1: T.Value = True
            Case 2: T.Value = Null
        End Select
        Log = ""
        Reset = "init=" & V(T.Value)
    Else
        Select Case Init
            Case 0: C.Value = False
            Case 1: C.Value = True
            Case 2: C.Value = Null
        End Select
        Log = ""
        Reset = "init=" & V(C.Value)
    End If
End Function
Public Function SetCode(ByVal Kind As String, ByVal Code As Long) As String
    Dim X As Variant, E As Long, D As String
    Log = ""
    X = MakeVal(Code)
    On Error Resume Next
    If Kind = "T" Then T.Value = X Else C.Value = X
    E = Err.Number
    D = Err.Description
    Err.Clear
    On Error GoTo 0
    If Kind = "T" Then
        SetCode = "err=" & CStr(E) & "|" & D & "|after=" & V(T.Value) & "|log=" & Log
    Else
        SetCode = "err=" & CStr(E) & "|" & D & "|after=" & V(C.Value) & "|log=" & Log
    End If
End Function
Public Function SetLiteral(ByVal Kind As String, ByVal Which As Long) As String
    Dim E As Long, D As String
    Log = ""
    On Error Resume Next
    If Kind = "T" Then
        Select Case Which
            Case 0: T.Value = -1
            Case 1: T.Value = 1
            Case 2: T.Value = 0
            Case 3: T.Value = Null
        End Select
    Else
        Select Case Which
            Case 0: C.Value = -1
            Case 1: C.Value = 1
            Case 2: C.Value = 0
            Case 3: C.Value = Null
        End Select
    End If
    E = Err.Number
    D = Err.Description
    Err.Clear
    On Error GoTo 0
    If Kind = "T" Then
        SetLiteral = "err=" & CStr(E) & "|" & D & "|after=" & V(T.Value) & "|log=" & Log
    Else
        SetLiteral = "err=" & CStr(E) & "|" & D & "|after=" & V(C.Value) & "|log=" & Log
    End If
End Function
"#;

fn make_val(root: &Path) -> String {
    let probe =
        std::fs::read_to_string(root.join("tools/office-oracle/capture_toggle_coercion.py"))
            .unwrap();
    let start = probe.find("Private Function MakeVal").unwrap();
    let end = probe[start..].find("End Function").unwrap() + start + "End Function".len();
    probe[start..end].replace("\r\n", "\n")
}

fn call(runtime: &mut OxRuntime, driver: &ObjectRef, name: &str, args: Vec<Variant>) -> String {
    runtime
        .session_mut()
        .invoke_member_values(driver.clone(), name, Some(ProjectMemberKind::Method), args)
        .unwrap()
        .as_bstr()
        .map(|text| text.as_str())
        .unwrap_or_default()
}

#[test]
fn native_variant_value_coercion_rows_match_for_toggle_button_and_check_box() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let evidence =
        root.join("docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.128");
    let mut rows = Vec::new();
    for file in ["native-coercion.json", "native-coercion-round2.json"] {
        let native: Value =
            serde_json::from_slice(&std::fs::read(evidence.join(file)).unwrap()).unwrap();
        rows.extend(native["cases"].as_array().unwrap().clone());
    }
    let mut form = WorkbookForm::open(
        root.join("fixtures/workbooks/planner/planner.xlsm"),
        "PlannerForm",
    )
    .unwrap();
    let source = format!("{DRIVER_HEAD}{}\n", make_val(&root));
    form.project_modules.push(ModuleUnit {
        module_name: "CheckValueDriver".into(),
        module_kind: ModuleKind::Class,
        attributes: ModuleAttributes::named("CheckValueDriver"),
        source,
    });
    let (mut runtime, _) = form
        .runtime_with_entry(
            Arc::new(StubShaper),
            HostServices::headless(),
            Some("OpenPlanner"),
        )
        .unwrap();
    let driver = runtime
        .session_mut()
        .create_class_instance("CheckValueDriver")
        .unwrap();
    call(&mut runtime, &driver, "Attach", vec![]);
    let mut compared = 0;
    let mut mismatches = Vec::new();
    for row in &rows {
        let Some(kind) = row["control"].as_str() else {
            continue;
        };
        if row.get("step").is_some() || !matches!(kind, "T" | "C") {
            continue;
        }
        let init = row["init"].as_i64().unwrap() as i32;
        let reset = call(
            &mut runtime,
            &driver,
            "Reset",
            vec![Variant::from_string(kind), Variant::from_i32(init)],
        );
        assert_eq!(reset, row["reset"].as_str().unwrap(), "reset {row}");
        let actual = if let Some(code) = row.get("code") {
            call(
                &mut runtime,
                &driver,
                "SetCode",
                vec![
                    Variant::from_string(kind),
                    Variant::from_i32(code.as_i64().unwrap() as i32),
                ],
            )
        } else {
            call(
                &mut runtime,
                &driver,
                "SetLiteral",
                vec![
                    Variant::from_string(kind),
                    Variant::from_i32(row["literal"].as_i64().unwrap() as i32),
                ],
            )
        };
        let expected = row["result"].as_str().unwrap();
        compared += 1;
        if actual != expected {
            mismatches.push(format!("{row}\n  runtime: {actual}"));
        }
    }
    assert!(
        mismatches.is_empty(),
        "{} of {compared} native rows differ:\n{}",
        mismatches.len(),
        mismatches.join("\n")
    );
    // ToggleButton and CheckBox rows, both TripleState settings (not yet modelled; assignment
    // results are identical) and the Null starting state.
    assert_eq!(compared, 382);
}
