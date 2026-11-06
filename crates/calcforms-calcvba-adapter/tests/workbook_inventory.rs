//! A saved Excel workbook, its original handlers, and independent private-window input.
use std::{path::Path, sync::Arc};

use calcforms_calcvba_adapter::{
    host_services::HostServices,
    office::WorkbookForm,
    runtime::{OxRuntime, RuntimeInput, RuntimeKeyKind, RuntimeMouseKind},
};
use calcforms_pal::scene::StubShaper;
use calcvba_bundle::ProjectMemberKind;
use calcvba_runtime::{ObjectRef, Variant};
use serde_json::{json, Value};

fn call(runtime: &mut OxRuntime, member: &str) -> String {
    let object = runtime.form();
    runtime
        .session_mut()
        .invoke_member_values(object, member, Some(ProjectMemberKind::Method), vec![])
        .unwrap()
        .as_bstr()
        .unwrap()
        .as_str()
}

fn control(runtime: &mut OxRuntime, name: &str) -> ObjectRef {
    let object = runtime.form();
    let controls = runtime
        .session_mut()
        .invoke_member_values(
            object,
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
            vec![Variant::from_string(name)],
        )
        .unwrap()
        .as_object_ref()
        .unwrap()
}

fn put(runtime: &mut OxRuntime, name: &str, member: &str, value: Variant) {
    let object = control(runtime, name);
    runtime
        .session_mut()
        .invoke_member_values(
            object,
            member,
            Some(ProjectMemberKind::PropertyLet),
            vec![value],
        )
        .unwrap();
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

#[test]
fn genuine_inventory_workbook_replays_retained_runtime_observations() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let directory = root.join("fixtures/workbooks/inventory");
    let form = WorkbookForm::open(directory.join("inventory.xlsm"), "InventoryForm").unwrap();
    assert_eq!(form.controls.len(), 6);
    assert!(form.original_source.contains("As MSForms.ListBox"));
    let original = std::fs::read_to_string(directory.join("form-code.bas")).unwrap();
    let application = form
        .original_source
        .lines()
        .filter(|line| !line.starts_with("Attribute "))
        .collect::<Vec<_>>()
        .join("\n");
    assert!(application.trim_end().ends_with(original.trim_end()));
    let observed: Value = serde_json::from_slice(&std::fs::read(root.join("docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.119/observations.json")).unwrap()).unwrap();
    let cases = observed["observations"].as_array().unwrap();
    assert_eq!(cases[0]["observations"], cases[1]["observations"]);
    assert_eq!(cases[0]["initial_focus"], "QtyInput");
    assert_eq!(cases[1]["initial_focus"], "QtyInput");
    let (mut runtime, _) = form
        .runtime_with_entry(
            Arc::new(StubShaper),
            HostServices::headless(),
            Some("OpenInventory"),
        )
        .unwrap();
    assert_eq!(runtime.read_string("FocusName").unwrap(), "QtyInput");
    let mut rows = Vec::new();
    let mut snapshot = |runtime: &mut OxRuntime, step: &str| {
        let state = call(runtime, "State");
        let trace = call(runtime, "Trace");
        let focus = runtime.read_string("FocusName").unwrap();
        assert!(
            !state.contains("CALCFORMS_NATIVE_ERROR:"),
            "{step}: {state}"
        );
        rows.push(json!({"step":step,"state":state,"trace":trace,"focus":focus}));
    };
    snapshot(&mut runtime, "initial");
    key(&mut runtime, 13);
    snapshot(&mut runtime, "initial_submit");
    // Focus the already selected first row through normalized reducer input.
    for kind in [RuntimeMouseKind::Down, RuntimeMouseKind::Up] {
        runtime
            .dispatch_event_turn(RuntimeInput::Mouse {
                kind,
                x: 24,
                y: 30,
                button: 1,
                shift: 0,
            })
            .unwrap();
    }
    key(&mut runtime, 34);
    snapshot(&mut runtime, "page_down_1");
    key(&mut runtime, 34);
    snapshot(&mut runtime, "page_down_2");
    for (quantity_step, value, submit_step) in [
        ("zero_quantity", "0", "reject_zero"),
        ("quantity_three", "3", "submit_three"),
    ] {
        put(
            &mut runtime,
            "QtyInput",
            "Text",
            Variant::from_string(value),
        );
        snapshot(&mut runtime, quantity_step);
        key(&mut runtime, 13);
        snapshot(&mut runtime, submit_step);
    }
    put(&mut runtime, "PickList", "ListIndex", Variant::from_i32(22));
    snapshot(&mut runtime, "last_part");
    put(&mut runtime, "PickList", "ListIndex", Variant::from_i32(22));
    snapshot(&mut runtime, "repeat_last");
    for (quantity_step, value, submit_step) in [
        ("invalid_text", "12a", "reject_text"),
        ("quantity_two", "2", "submit_two"),
    ] {
        put(
            &mut runtime,
            "QtyInput",
            "Text",
            Variant::from_string(value),
        );
        snapshot(&mut runtime, quantity_step);
        key(&mut runtime, 13);
        snapshot(&mut runtime, submit_step);
    }
    key(&mut runtime, 27);
    snapshot(&mut runtime, "cancel");
    runtime.show_modeless().unwrap();
    snapshot(&mut runtime, "reshow");
    println!(
        "CALCFORMS_INVENTORY_RUNTIME {}",
        json!({"observations":rows})
    );
    // Compare every observed runtime field exactly. The independent native
    // differential report retains the four cancel-focus failures (.123).
    // No product parity claim follows from this replay check being green.
    let retained: Value = serde_json::from_slice(&std::fs::read(root.join("docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.119/runtime.json")).unwrap()).unwrap();
    assert_eq!(json!(rows), retained["observations"]);
    for (actual, expected) in rows
        .iter()
        .zip(cases[0]["observations"].as_array().unwrap())
    {
        assert_eq!(
            actual["state"], expected["state"],
            "{} State",
            actual["step"]
        );
        assert_eq!(
            actual["trace"], expected["trace"],
            "{} Trace",
            actual["step"]
        );
    }
}
