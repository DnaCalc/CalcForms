//! The workbook's own code creates the container controls and handles validation.
use std::path::Path;
use std::sync::Arc;

use calcforms_calcvba_adapter::runtime::{OxRuntime, RuntimeInput, RuntimeKeyKind};
use calcforms_calcvba_adapter::{host_services::HostServices, office::WorkbookForm};
use calcforms_pal::scene::StubShaper;
use calcvba_bundle::ProjectMemberKind;
use calcvba_runtime::Variant;
use serde_json::Value;

fn call(runtime: &mut OxRuntime, member: &str, args: Vec<Variant>) -> Variant {
    let instance = runtime.form();
    runtime
        .session_mut()
        .invoke_member_values(instance, member, Some(ProjectMemberKind::Method), args)
        .unwrap()
}

fn state(runtime: &mut OxRuntime) -> String {
    call(runtime, "State", vec![]).as_bstr().unwrap().as_str()
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
fn real_data_entry_workbook_initializes_qualified_forms_and_original_handlers() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let directory = root.join("fixtures/workbooks/data-entry");
    let form = WorkbookForm::open(directory.join("order-entry.xlsm"), "OrderEntryForm").unwrap();
    assert_eq!(
        form.controls.len(),
        5,
        "other controls come from the original Initialize code"
    );
    assert!(
        (form.width - 414.00005).abs() < 0.001,
        "native fractional twips stay finite and retain precision"
    );
    assert!(form.original_source.contains("As MSForms.ComboBox"));
    let original = std::fs::read_to_string(directory.join("form-code.bas")).unwrap();
    let application_source = form
        .original_source
        .lines()
        .filter(|line| !line.starts_with("Attribute "))
        .collect::<Vec<_>>()
        .join("\n");
    assert!(
        application_source.trim_end().ends_with(original.trim_end()),
        "original application handlers must survive Office import"
    );
    let expected: Value =
        serde_json::from_slice(&std::fs::read(directory.join("authoring.json")).unwrap()).unwrap();
    let (mut runtime, surface) = form
        .runtime_with_entry(
            Arc::new(StubShaper),
            HostServices::headless(),
            Some("OpenOrderEntry"),
        )
        .unwrap();
    let instance = runtime.form();
    for (member, key) in [("State", "initial_state"), ("Trace", "initial_trace")] {
        let value = runtime
            .session_mut()
            .invoke_member_values(
                instance.clone(),
                member,
                Some(ProjectMemberKind::Method),
                vec![],
            )
            .unwrap();
        assert_eq!(
            value.as_bstr().unwrap().as_str(),
            expected[key].as_str().unwrap(),
            "{member}"
        );
    }
    assert!(surface.snapshot().unwrap().node_count > 20);

    // The later scenarios are runtime regression checks; only initial State/Trace
    // above have a paired native observation in this fixture.
    key(&mut runtime, 9); // Establish reducer focus without using the real keyboard.
    key(&mut runtime, 13);
    let invalid = state(&mut runtime);
    assert!(
        invalid.contains("saved=0;status=Name is required"),
        "{invalid}; trace={:?}",
        call(&mut runtime, "Trace", vec![])
    );
    call(&mut runtime, "SetName", vec![Variant::from_string("Ada")]);
    call(&mut runtime, "SetTeam", vec![Variant::from_i32(1)]);
    call(&mut runtime, "SetProduct", vec![Variant::from_i32(2)]);
    call(&mut runtime, "ChoosePriority", vec![]);
    call(&mut runtime, "ChoosePrepaid", vec![]);
    call(&mut runtime, "SelectPage", vec![Variant::from_i32(1)]);
    key(&mut runtime, 13);
    assert_eq!(state(&mut runtime), "name=Ada;team=Engineering;product=Washer;standard=False;priority=True;invoice=False;prepaid=True;page=1;notes=Leave at reception;saved=1;status=Saved Ada: Washer;visible=True");
    key(&mut runtime, 27);
    assert!(state(&mut runtime).ends_with("visible=False"));
    let trace = call(&mut runtime, "Trace", vec![])
        .as_bstr()
        .unwrap()
        .as_str();
    assert!(trace.contains("Save.Click|Save.Invalid"), "{trace}");
    assert!(
        trace.ends_with("Save.Click|Save.Valid|Cancel.Click"),
        "{trace}"
    );
}
