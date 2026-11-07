//! A saved Excel workbook exercises four additional control/event families.
use calcforms_calcvba_adapter::{
    host_services::HostServices, office::WorkbookForm, runtime::OxRuntime,
};
use calcforms_pal::scene::StubShaper;
use calcvba_bundle::ProjectMemberKind;
use calcvba_runtime::Variant;
use calcvba_symbol::manifest::{ModuleAttributes, ModuleKind, ModuleUnit};
use serde_json::{json, Value};
use std::{path::Path, sync::Arc};

fn call(runtime: &mut OxRuntime, name: &str) -> String {
    let object = runtime.form();
    runtime
        .session_mut()
        .invoke_member_values(object, name, Some(ProjectMemberKind::Method), vec![])
        .unwrap()
        .as_bstr()
        .unwrap()
        .as_str()
}

#[test]
fn genuine_planner_handlers_values_repeat_and_native_errors_match_both_scales() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let evidence =
        root.join("docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.126");
    let native: Value =
        serde_json::from_slice(&std::fs::read(evidence.join("observations.json")).unwrap())
            .unwrap();
    let mut form = WorkbookForm::open(
        root.join("fixtures/workbooks/planner/planner.xlsm"),
        "PlannerForm",
    )
    .unwrap();
    let source =
        std::fs::read_to_string(root.join("fixtures/workbooks/planner/form-code.bas")).unwrap();
    let imported = form
        .original_source
        .lines()
        .filter(|line| !line.starts_with("Attribute "))
        .collect::<Vec<_>>()
        .join("\n");
    assert!(
        imported.trim_end().ends_with(source.trim_end()),
        "original workbook handlers are unchanged"
    );
    let observer = std::fs::read_to_string(evidence.join("observer-fixed.bas")).unwrap();
    // Native Prepare owns Zoom/window setup. Compile the unchanged setter
    // observer body; the host runs the original OpenPlanner entry separately.
    let setter = observer
        .split_once("Public Function PlannerSet")
        .unwrap()
        .1
        .split_once("End Function")
        .unwrap()
        .0;
    // The native observer uses the FM20 Controls default member. The adapter's
    // current facade exposes explicit Item; this changes only observation setup.
    let setter = setter.replace("    If ControlName", "    Dim C As Object\n    Set C = PlannerForm.Controls.Item(ControlName)\n    If ControlName").replace("PlannerForm.Controls(ControlName)", "C");
    let observer = format!("Public Function PlannerSet{setter}End Function\n");
    form.project_modules.push(ModuleUnit {
        module_name: "PlannerObserver".into(),
        module_kind: ModuleKind::Procedural,
        attributes: ModuleAttributes::named("PlannerObserver"),
        source: observer,
    });
    form.project_modules.push(ModuleUnit {module_name:"PlannerDriver".into(),module_kind:ModuleKind::Class,attributes:ModuleAttributes::named("PlannerDriver"),source:"Private Function SetValue(ByVal ControlName As String, ByVal Value As Long) As Long\n    SetValue = PlannerSet(ControlName, Value)\nEnd Function\n".into()});
    let (mut runtime, _) = form
        .runtime_with_entry(
            Arc::new(StubShaper),
            HostServices::headless(),
            Some("OpenPlanner"),
        )
        .unwrap();
    let driver = runtime
        .session_mut()
        .create_class_instance("PlannerDriver")
        .unwrap();
    let mut rows = vec![
        json!({"step":"initial","error":0,"state":call(&mut runtime,"State"),"trace":call(&mut runtime,"Trace")}),
    ];
    for (step, name, value) in [
        ("day-five", "DayPicker", 5),
        ("same-day", "DayPicker", 5),
        ("hour-fourteen", "HourPicker", 14),
        ("all-day", "AllDay", -1),
        ("same-all-day", "AllDay", -1),
        ("week", "ViewTabs", 1),
        ("timed", "AllDay", 0),
        ("last-day", "DayPicker", 30),
        ("last-hour", "HourPicker", 23),
        ("day-view", "ViewTabs", 0),
        ("day-out-of-range", "DayPicker", 31),
        ("hour-out-of-range", "HourPicker", 24),
    ] {
        let error = runtime
            .session_mut()
            .invoke_member_values(
                driver.clone(),
                "SetValue",
                Some(ProjectMemberKind::Method),
                vec![Variant::from_string(name), Variant::from_i32(value)],
            )
            .unwrap()
            .as_i32()
            .unwrap();
        rows.push(json!({"step":step,"error":error,"state":call(&mut runtime,"State"),"trace":call(&mut runtime,"Trace")}));
    }
    println!(
        "CALCFORMS_PLANNER={}",
        json!({"schema":"calcforms.planner_runtime.v1","observations":rows})
    );
    assert_eq!(native["cases"].as_array().unwrap().len(), 2);
    for case in native["cases"].as_array().unwrap() {
        assert_eq!(
            json!(rows),
            case["observations"],
            "complete state, trace and error at native zoom {}",
            case["zoom"]
        );
    }
}
