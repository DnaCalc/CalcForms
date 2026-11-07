//! Public IntegralHeight coverage; exact remaining Height differences stay reported.
use calcforms_calcvba_adapter::{
    host_services::HostServices, office::WorkbookForm, runtime::OxRuntime,
};
use calcforms_pal::scene::StubShaper;
use calcvba_bundle::ProjectMemberKind;
use calcvba_runtime::{ObjectRef, Variant};
use serde_json::{json, Value};
use std::{path::Path, sync::Arc};

fn control(runtime: &mut OxRuntime) -> ObjectRef {
    let form = runtime.form();
    let controls = runtime
        .session_mut()
        .invoke_member_values(
            form,
            "Controls",
            Some(ProjectMemberKind::PropertyGet),
            vec![],
        )
        .unwrap()
        .as_object_ref()
        .unwrap();
    runtime
        .session_mut()
        .invoke_member_values(
            controls,
            "Item",
            Some(ProjectMemberKind::Method),
            vec![Variant::from_string("PickList")],
        )
        .unwrap()
        .as_object_ref()
        .unwrap()
}
fn put(runtime: &mut OxRuntime, property: &str, value: Variant) {
    let object = control(runtime);
    runtime
        .session_mut()
        .invoke_member_values(
            object,
            property,
            Some(ProjectMemberKind::PropertyLet),
            vec![value],
        )
        .unwrap();
}
fn get(runtime: &mut OxRuntime, property: &str) -> Variant {
    let object = control(runtime);
    runtime
        .session_mut()
        .invoke_member_values(
            object,
            property,
            Some(ProjectMemberKind::PropertyGet),
            vec![],
        )
        .unwrap()
}
fn snapshot(runtime: &mut OxRuntime, step: &str) -> Value {
    let height = get(runtime, "Height");
    let mut row = json!({"step":step,"height":height.as_f32().map(f64::from).or_else(||height.as_f64()).unwrap(),"integral":get(runtime,"IntegralHeight").as_bool().unwrap()});
    if step != "before-show" {
        put(runtime, "ListIndex", Variant::from_i32(22));
        put(runtime, "TopIndex", Variant::from_i32(99));
        row["top"] = json!(get(runtime, "TopIndex").as_i32().unwrap());
    }
    row
}

#[test]
fn public_integral_height_flag_and_whole_partial_viewports_match_native_observations() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let form = WorkbookForm::open(
        root.join("fixtures/workbooks/inventory/inventory.xlsm"),
        "InventoryForm",
    )
    .unwrap();
    let (mut runtime, _) = form
        .runtime(Arc::new(StubShaper), HostServices::headless())
        .unwrap();
    let mut rows = vec![snapshot(&mut runtime, "before-show")];
    runtime.show_modeless().unwrap();
    rows.push(snapshot(&mut runtime, "shown"));
    for (step, value) in [
        ("same-true", true),
        ("false", false),
        ("same-false", false),
        ("true", true),
        ("same-true-after-toggle", true),
    ] {
        let prior = get(&mut runtime, "IntegralHeight").as_bool().unwrap();
        let prior_top = get(&mut runtime, "TopIndex").as_i32().unwrap();
        put(&mut runtime, "IntegralHeight", Variant::from_bool(value));
        assert_eq!(
            get(&mut runtime, "TopIndex").as_i32().unwrap(),
            if prior == value { prior_top } else { 0 },
            "same value is quiet; changed flag resets native scroll origin"
        );
        rows.push(snapshot(&mut runtime, step));
    }
    put(&mut runtime, "IntegralHeight", Variant::from_bool(false));
    put(&mut runtime, "Height", Variant::from_f32(80.0));
    rows.push(snapshot(&mut runtime, "false-height-80"));
    put(&mut runtime, "IntegralHeight", Variant::from_bool(true));
    rows.push(snapshot(&mut runtime, "true-height-80"));
    put(&mut runtime, "Height", Variant::from_f32(72.0));
    rows.push(snapshot(&mut runtime, "true-height-72"));
    rows.push(snapshot(&mut runtime, "after-doevents"));
    let object = runtime.form();
    runtime
        .session_mut()
        .invoke_member_values(object, "Hide", Some(ProjectMemberKind::Method), vec![])
        .unwrap();
    runtime.show_modeless().unwrap();
    rows.push(snapshot(&mut runtime, "reshow"));
    let native:Value=serde_json::from_slice(&std::fs::read(root.join("docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.118/run9-native/observations.json")).unwrap()).unwrap();
    for case in native["observations"].as_array().unwrap() {
        let lines: Vec<_> = case["result"].as_str().unwrap().lines().collect();
        assert_eq!(lines.len(), rows.len());
        for (index, (line, row)) in lines.iter().zip(&rows).enumerate() {
            assert_eq!(
                line.split(';').next().unwrap(),
                row["step"].as_str().unwrap()
            );
            let integral = line
                .split(';')
                .find_map(|part| part.strip_prefix("integral="))
                .unwrap()
                == "True";
            assert_eq!(
                row["integral"],
                json!(integral),
                "public flag at {}",
                row["step"]
            );
            if (1..=6).contains(&index) {
                let top = line
                    .split(';')
                    .find_map(|part| part.strip_prefix("top="))
                    .unwrap()
                    .parse::<i32>()
                    .unwrap();
                assert_eq!(
                    row["top"],
                    json!(top),
                    "whole/partial rows at {}",
                    row["step"]
                );
            }
        }
    }
    println!(
        "CALCFORMS_INTEGRAL_HEIGHT={}",
        json!({"schema":"calcforms.integral_height_runtime.v1","observations":rows})
    );
}
