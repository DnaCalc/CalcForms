//! The input is a workbook saved by owned Excel, not a hand-written .frm projection.
//! This test starts no Office process and runs the original event-handler bodies.
use std::path::{Path, PathBuf};
use std::sync::Arc;

use calcforms_calcvba_adapter::host_services::HostServices;
use calcforms_calcvba_adapter::office::{ControlKind, WorkbookForm};
use calcforms_calcvba_adapter::runtime::{
    OxRuntime, RuntimeInput, RuntimeKeyKind, RuntimeMouseKind,
};
use calcforms_pal::scene::StubShaper;
use calcvba_bundle::ProjectMemberKind;
use serde_json::Value;

fn root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..")
}
fn workbook() -> WorkbookForm {
    WorkbookForm::open(
        root().join("fixtures/workbooks/greeter/workbook-greeter.xlsm"),
        "WorkbookGreeter",
    )
    .expect("read real workbook using calcvba-office")
}
fn state(runtime: &mut OxRuntime) -> String {
    let form = runtime.form();
    runtime
        .session_mut()
        .invoke_member_values(form, "State", Some(ProjectMemberKind::Method), vec![])
        .expect("original VBA State function")
        .as_bstr()
        .expect("String state")
        .as_str()
}
fn click(runtime: &mut OxRuntime, x: i32, y: i32) {
    for kind in [RuntimeMouseKind::Down, RuntimeMouseKind::Up] {
        runtime
            .dispatch_event_turn(RuntimeInput::Mouse {
                kind,
                x,
                y,
                button: 1,
                shift: 0,
            })
            .expect("real VBA reducer input");
    }
}

#[test]
fn workbook_controls_and_original_handlers_match_owned_excel_headlessly() {
    let form = workbook();
    assert_eq!(form.controls.len(), 5);
    assert_eq!(
        form.controls
            .iter()
            .map(|control| control.name.as_str())
            .collect::<Vec<_>>(),
        ["Prompt", "InputName", "Greet", "Loud", "Output"]
    );
    assert_eq!(form.controls[1].kind, ControlKind::TextBox);
    assert_eq!(form.controls[1].value, "Ada");
    assert!(form.controls[2].default_button);
    assert_eq!(form.controls[4].caption, "(ready)");
    assert_eq!(
        form.font_name().expect("homogeneous persisted face"),
        "Tahoma"
    );
    assert!(form
        .controls
        .iter()
        .all(|c| c.font_name == "Tahoma" && c.font_size == 8.25));
    let original = std::fs::read_to_string(root().join("fixtures/workbooks/greeter/form-code.bas"))
        .expect("owned original source");
    assert!(
        form.original_source
            .replace("\r\n", "\n")
            .trim_end()
            .ends_with(original.trim_end()),
        "the Office reader must retrieve the actual fixture code"
    );
    let module = form.module().expect("compose the VBA host implementation");
    assert!(module.source.contains("Private Sub CalcFormsHostBuild()"));
    assert!(!module.source.contains("Public Sub CalcFormsHost"));
    let original_procedures = original
        .split("Private Sub UserForm_Initialize()")
        .nth(1)
        .expect("source procedures");
    assert!(
        module.source.contains(original_procedures.trim_end()),
        "procedure bodies must remain application source"
    );

    let expected: Value = serde_json::from_slice(&std::fs::read(root().join("docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.74/excel-observations.json")).expect("owned native Excel observations")).expect("oracle JSON");
    let expected: Vec<_> = expected["observations"]
        .as_array()
        .expect("observations")
        .iter()
        .map(|row| row["state"].as_str().expect("native state").to_owned())
        .collect();
    let (mut runtime, surface) = form
        .runtime(Arc::new(StubShaper), HostServices::headless())
        .expect("run the actual workbook form on VM3");
    let initial_revision = surface.snapshot().expect("initial Scene").revision;
    let mut observed = vec![state(&mut runtime)];
    click(&mut runtime, 220, 45);
    observed.push(state(&mut runtime));
    click(&mut runtime, 25, 45);
    for kind in [RuntimeKeyKind::Down, RuntimeKeyKind::Up] {
        runtime
            .dispatch_event_turn(RuntimeInput::Key {
                kind,
                key_code: 65,
                shift: 2,
            })
            .expect("select text");
    }
    runtime
        .dispatch_event_turn(RuntimeInput::CharacterInput("Lin".into()))
        .expect("edit text");
    observed.push(state(&mut runtime));
    click(&mut runtime, 220, 45);
    observed.push(state(&mut runtime));
    click(&mut runtime, 20, 75);
    observed.push(state(&mut runtime));
    click(&mut runtime, 220, 45);
    observed.push(state(&mut runtime));
    assert_eq!(observed, expected, "same form state and handler sequence as native MSForms; native inputs use public setters and runtime inputs use the reducer");
    runtime.render().expect("render the final handler state");
    let snapshot = surface.snapshot().expect("final resident Scene");
    assert!(snapshot.revision > initial_revision);
    assert!(snapshot.node_count >= 8);
    assert!(snapshot.scene.is_some());
}

#[test]
fn missing_form_has_a_precise_diagnostic() {
    let error = WorkbookForm::open(
        root().join("fixtures/workbooks/greeter/workbook-greeter.xlsm"),
        "MissingForm",
    )
    .expect_err("no invented default form");
    assert!(error.contains("no UserForm"), "{error}");
}

#[test]
fn mixed_persisted_faces_are_rejected_before_source_composition() {
    let mut form = workbook();
    form.controls[0].font_name = "Microsoft Sans Serif".into();
    assert!(form
        .module()
        .expect_err("one face is currently registered per form")
        .contains("mixed font faces"));
}
