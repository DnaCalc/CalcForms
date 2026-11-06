//! Independent native observations fill the existing real greeter's input rows.
use std::{path::Path, sync::Arc};

use calcforms_calcvba_adapter::{
    host_services::HostServices,
    office::WorkbookForm,
    runtime::{OxRuntime, RuntimeInput, RuntimeKeyKind, RuntimeMouseKind},
};
use calcforms_pal::scene::StubShaper;
use calcvba_bundle::ProjectMemberKind;
use calcvba_runtime::Variant;
use serde_json::{json, Value};

fn call(runtime: &mut OxRuntime, member: &str, arguments: Vec<Variant>) -> String {
    let object = runtime.form();
    runtime
        .session_mut()
        .invoke_member_values(object, member, Some(ProjectMemberKind::Method), arguments)
        .unwrap()
        .as_bstr()
        .unwrap()
        .as_str()
}

fn key(runtime: &mut OxRuntime, key_code: i16) {
    for kind in [RuntimeKeyKind::Down, RuntimeKeyKind::Up] {
        runtime
            .dispatch_event_turn(RuntimeInput::Key {
                kind,
                key_code,
                shift: 0,
            })
            .unwrap();
    }
}

fn cycle(runtime: &mut OxRuntime) -> Vec<String> {
    let first = runtime.read_string("FocusName").unwrap();
    let mut names = vec![first.clone()];
    for _ in 0..8 {
        key(runtime, 9);
        let next = runtime.read_string("FocusName").unwrap();
        names.push(next.clone());
        if next == first {
            break;
        }
    }
    assert_eq!(names.first(), names.last(), "closed Tab cycle");
    names
}

#[test]
fn real_greeter_tab_hits_enter_and_escape_match_independent_native_observations() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let directory =
        root.join("docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.122");
    let native: Value =
        serde_json::from_slice(&std::fs::read(directory.join("native.json")).unwrap()).unwrap();
    let instrumentation = std::fs::read_to_string(directory.join("instrumentation.bas")).unwrap();
    let mut cases = Vec::new();
    let mut expected = Vec::new();
    for case in native["observations"].as_array().unwrap() {
        let mut form = WorkbookForm::open(
            root.join("fixtures/workbooks/greeter/workbook-greeter.xlsm"),
            "WorkbookGreeter",
        )
        .unwrap();
        let original = form.original_source.clone();
        form.original_source.push('\n');
        form.original_source.push_str(&instrumentation);
        assert!(
            form.original_source.starts_with(&original),
            "original handlers remain unchanged"
        );
        let (mut runtime, _) = form
            .runtime_with_entry(
                Arc::new(StubShaper),
                HostServices::headless(),
                Some("ShowGreeter"),
            )
            .unwrap();
        let initial = runtime.read_string("FocusName").unwrap();
        let first_cycle = cycle(&mut runtime);
        let second_cycle = cycle(&mut runtime);
        let mut points = Vec::new();
        let mut native_points = Vec::new();
        for point in case["points"].as_array().unwrap() {
            call(
                &mut runtime,
                "ParityInputTrace",
                vec![Variant::from_bool(true)],
            );
            let x = point["point_pt"][0].as_i64().unwrap() as i32;
            let y = point["point_pt"][1].as_i64().unwrap() as i32;
            for kind in [RuntimeMouseKind::Down, RuntimeMouseKind::Up] {
                runtime
                    .dispatch_event_turn(RuntimeInput::Mouse {
                        kind,
                        x,
                        y,
                        button: 1,
                        shift: 0,
                    })
                    .unwrap();
            }
            let trace = call(
                &mut runtime,
                "ParityInputTrace",
                vec![Variant::from_bool(false)],
            );
            let mut keys = serde_json::Map::new();
            for (metric, code) in [("enter_default", 13), ("escape_cancel", 27)] {
                let before = call(&mut runtime, "State", vec![]);
                key(&mut runtime, code);
                let after = call(&mut runtime, "State", vec![]);
                let before_log = before.split(";text=").next().unwrap();
                let after_log = after.split(";text=").next().unwrap();
                let events = after_log
                    .strip_prefix(before_log)
                    .unwrap()
                    .split('|')
                    .filter(|s| !s.is_empty())
                    .collect::<Vec<_>>();
                keys.insert(
                    metric.into(),
                    json!({"before":before,"after":after,"events":events}),
                );
            }
            points.push(json!({"control":point["control"],"point_pt":point["point_pt"],"trace":trace,"keys":keys}));
            native_points.push(json!({"control":point["control"],"point_pt":point["point_pt"],"trace":point["trace"],"keys":point["keys"]}));
        }
        cases.push(json!({"zoom":case["zoom"],"initial_focus":initial,"tab_cycle":first_cycle,"repeated_tab_cycle":second_cycle,"points":points}));
        expected.push(json!({"zoom":case["zoom"],"initial_focus":case["initial_focus"],"tab_cycle":case["tab_cycle"],"repeated_tab_cycle":case["repeated_tab_cycle"],"points":native_points}));
    }
    println!(
        "CALCFORMS_GREETER_INPUT_RUNTIME {}",
        json!({"observations":cases})
    );
    assert_eq!(cases, expected);
}
