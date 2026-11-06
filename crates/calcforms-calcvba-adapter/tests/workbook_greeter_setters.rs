//! Differential replay of original saved greeter handlers, without starting Office.
use calcforms_calcvba_adapter::{
    host_services::HostServices,
    office::WorkbookForm,
    runtime::{OxRuntime, RuntimeInput, RuntimeMouseKind},
};
use calcforms_pal::scene::StubShaper;
use calcvba_bundle::ProjectMemberKind;
use calcvba_runtime::{ObjectRef, Variant};
use serde_json::{json, Value};
use std::{path::Path, sync::Arc};

fn member(
    runtime: &mut OxRuntime,
    object: ObjectRef,
    name: &str,
    kind: ProjectMemberKind,
    args: Vec<Variant>,
) -> Variant {
    runtime
        .session_mut()
        .invoke_member_values(object, name, Some(kind), args)
        .unwrap()
}
fn control(runtime: &mut OxRuntime, name: &str) -> ObjectRef {
    let form = runtime.form();
    let controls = member(
        runtime,
        form,
        "Controls",
        ProjectMemberKind::PropertyGet,
        vec![],
    )
    .as_object_ref()
    .unwrap();
    member(
        runtime,
        controls,
        "Item",
        ProjectMemberKind::Method,
        vec![Variant::from_string(name)],
    )
    .as_object_ref()
    .unwrap()
}
fn put(runtime: &mut OxRuntime, name: &str, property: &str, value: Variant) {
    let object = control(runtime, name);
    member(
        runtime,
        object,
        property,
        ProjectMemberKind::PropertyLet,
        vec![value],
    );
}
fn get(runtime: &mut OxRuntime, name: &str, property: &str) -> Variant {
    let object = control(runtime, name);
    member(
        runtime,
        object,
        property,
        ProjectMemberKind::PropertyGet,
        vec![],
    )
}
fn string(value: Variant) -> String {
    if let Some(text) = value.as_bstr() {
        text.as_str()
    } else if value.as_bool().unwrap() {
        "True".into()
    } else {
        "False".into()
    }
}
fn state(runtime: &mut OxRuntime) -> String {
    let form = runtime.form();
    string(member(
        runtime,
        form,
        "State",
        ProjectMemberKind::Method,
        vec![],
    ))
}

#[test]
fn original_greeter_setters_selection_and_application_events_match_both_native_scales() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let observed: Value = serde_json::from_slice(&std::fs::read(root.join("docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.125/native/observations.json")).unwrap()).unwrap();
    let form = WorkbookForm::open(
        root.join("fixtures/workbooks/greeter/workbook-greeter.xlsm"),
        "WorkbookGreeter",
    )
    .unwrap();
    let (mut runtime, _) = form
        .runtime(Arc::new(StubShaper), HostServices::headless())
        .unwrap();
    runtime.show_modeless().unwrap();
    let mut rows = Vec::new();
    for expected in observed["cases"][0]["observations"].as_array().unwrap() {
        let name = expected["control"].as_str().unwrap();
        let step = expected["step"].as_str().unwrap();
        let property = expected["member"].as_str().unwrap();
        let before = state(&mut runtime);
        match (name, step) {
            ("Prompt", _) => put(
                &mut runtime,
                name,
                property,
                Variant::from_string("Name updated:"),
            ),
            ("Output", _) => put(
                &mut runtime,
                name,
                property,
                Variant::from_string("(changed)"),
            ),
            ("InputName", "text") => put(&mut runtime, name, "Text", Variant::from_string("Lin")),
            ("InputName", "select") => {
                put(&mut runtime, name, "SelStart", Variant::from_i32(1));
                put(&mut runtime, name, "SelLength", Variant::from_i32(1));
            }
            ("InputName", "replace") => {
                put(&mut runtime, name, "SelText", Variant::from_string("a"))
            }
            ("Loud", _) => put(&mut runtime, name, "Value", Variant::from_bool(true)),
            ("Greet", "invoke") => {
                for kind in [RuntimeMouseKind::Down, RuntimeMouseKind::Up] {
                    runtime
                        .dispatch_event_turn(RuntimeInput::Mouse {
                            kind,
                            x: 220,
                            y: 45,
                            button: 1,
                            shift: 0,
                        })
                        .unwrap();
                }
            }
            _ => panic!("unrecognized captured step"),
        }
        let after = state(&mut runtime);
        let old_log = before.split(';').next().unwrap();
        let log = after.split(';').next().unwrap();
        let events: Vec<_> = log
            .strip_prefix(old_log)
            .unwrap()
            .split('|')
            .filter(|s| !s.is_empty())
            .collect();
        let mut row = json!({"control":name,"step":step,"member":property,"value":string(get(&mut runtime,name,property)),"before":before,"after":after,"events":events});
        if expected.get("selection").is_some() {
            row["selection"] = json!({"start":get(&mut runtime,name,"SelStart").as_i32().unwrap(),"length":get(&mut runtime,name,"SelLength").as_i32().unwrap(),"text":string(get(&mut runtime,name,"SelText"))});
        }
        rows.push(row);
    }
    println!(
        "CALCFORMS_GREETER_SETTERS={}",
        json!({"schema":"calcforms.greeter_setters_runtime.v1","observations":rows})
    );
    assert_eq!(observed["cases"].as_array().unwrap().len(), 2);
    for case in observed["cases"].as_array().unwrap() {
        assert_eq!(
            json!(rows),
            case["observations"],
            "native zoom {}",
            case["zoom"]
        );
    }
}
