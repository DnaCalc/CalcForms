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
fn original_workbook_entry_and_host_share_the_default_instance() {
    let (mut runtime, _) = workbook()
        .runtime_with_entry(
            Arc::new(StubShaper),
            HostServices::headless(),
            Some("ShowGreeter"),
        )
        .expect("original standard-module entry");
    let instance = runtime.form();
    let visible = runtime
        .session_mut()
        .invoke_member_values(
            instance,
            "Visible",
            Some(ProjectMemberKind::PropertyGet),
            vec![],
        )
        .unwrap();
    assert_eq!(visible.as_bool(), Some(true));
    assert_eq!(
        state(&mut runtime),
        "Initialize;text=Ada;caption=(ready);loud=False"
    );
}

#[test]
fn original_native_lifetime_observer_matches_on_vm3() {
    use calcvba_symbol::manifest::{ModuleAttributes, ModuleKind, ModuleUnit};
    let mut form = workbook();
    form.project_modules.push(ModuleUnit {
        module_name: "LifetimeObserver".into(), module_kind: ModuleKind::Class,
        attributes: ModuleAttributes::named("LifetimeObserver"),
        source: format!("{}\nPrivate Function Observe() As String\n    Observe = Run4Lifetime()\nEnd Function\n", std::fs::read_to_string(root().join("docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.77/observer.bas")).unwrap()),
    });
    let (mut runtime, _) = form
        .runtime(Arc::new(StubShaper), HostServices::headless())
        .expect("lifetime runtime");
    let observer = runtime
        .session_mut()
        .create_class_instance("LifetimeObserver")
        .unwrap();
    let result = runtime
        .session_mut()
        .invoke_member_values(observer, "Observe", Some(ProjectMemberKind::Method), vec![])
        .unwrap();
    let expected: Value = serde_json::from_slice(&std::fs::read(root().join("docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.77/observations.json")).unwrap()).unwrap();
    assert_eq!(
        result.as_bstr().unwrap().as_str(),
        expected["result"].as_str().unwrap()
    );
    runtime
        .render()
        .expect("host resolves a fresh default after workbook unload");
    assert_eq!(
        state(&mut runtime),
        "Initialize;text=Ada;caption=(ready);loud=False"
    );
}

fn run_native_probe(mut form: WorkbookForm, source: &str, procedure: &str) -> String {
    use calcvba_symbol::manifest::{ModuleAttributes, ModuleKind, ModuleUnit};
    form.project_modules.push(ModuleUnit {
        module_name: "Run5Probe".into(),
        module_kind: ModuleKind::Procedural,
        attributes: ModuleAttributes::named("Run5Probe"),
        source: source.into(),
    });
    form.project_modules.push(ModuleUnit {
        module_name: "Run5Driver".into(),
        module_kind: ModuleKind::Class,
        attributes: ModuleAttributes::named("Run5Driver"),
        source: format!(
            "Private Function Observe() As String\n    Observe = {procedure}()\nEnd Function\n"
        ),
    });
    let (mut runtime, _) = form
        .runtime(Arc::new(StubShaper), HostServices::headless())
        .unwrap();
    let driver = runtime
        .session_mut()
        .create_class_instance("Run5Driver")
        .unwrap();
    runtime
        .session_mut()
        .invoke_member_values(driver, "Observe", Some(ProjectMemberKind::Method), vec![])
        .unwrap()
        .as_bstr()
        .unwrap()
        .as_str()
}

#[test]
fn query_close_veto_and_allowed_unload_match_private_desktop_excel() {
    let directory = root()
        .join("docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.77/run5");
    let mut form = workbook();
    form.original_source
        .push_str(&std::fs::read_to_string(directory.join("event-handlers.bas")).unwrap());
    let source = std::fs::read_to_string(directory.join("query-close.bas")).unwrap();
    let expected = std::fs::read_to_string(directory.join("native-query-close.txt"))
        .unwrap()
        .replace("\r\n", "\n");
    assert_eq!(run_native_probe(form, &source, "Run5QueryClose"), expected);
}

#[test]
fn text_value_and_seltext_assignment_events_match_private_desktop_excel() {
    let directory = root()
        .join("docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.77/run5");
    let source = std::fs::read_to_string(directory.join("text-assignments.bas")).unwrap();
    let expected = std::fs::read_to_string(directory.join("native-text-assignments.txt"))
        .unwrap()
        .replace("\r\n", "\n");
    assert_eq!(
        run_native_probe(workbook(), &source, "Run5TextAssignments"),
        expected
    );
}

#[test]
fn code_behind_hide_and_unload_preserve_window_lifetime_readback() {
    for (statement, expected) in [("Me.Hide", (true, false)), ("Unload Me", (false, false))] {
        let mut form = workbook();
        form.original_source = form
            .original_source
            .replace("Output.Caption = \"Hello, \" & InputName.Text", statement);
        let (mut runtime, _) = form
            .runtime(Arc::new(StubShaper), HostServices::headless())
            .unwrap();
        runtime.show_modeless().unwrap();
        assert_eq!(runtime.form_window_state().unwrap(), Some((true, true)));
        click(&mut runtime, 220, 45);
        assert_eq!(
            runtime.form_window_state().unwrap(),
            Some(expected),
            "{statement} must not mint a replacement default while the window decides what to do"
        );
    }
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

#[test]
fn workbook_focus_transitions_remove_old_caret_and_checkbox_adorner_from_scene() {
    use calcforms_pal::scene::{NodeId, Paint, Prim};
    use calcforms_pal::Color;
    fn primitives(scene: &calcforms_pal::scene::Scene, id: u64) -> &[Prim] {
        &scene
            .nodes
            .iter()
            .find(|n| n.id == NodeId(id))
            .unwrap()
            .prims
    }
    let (mut runtime, surface) = workbook()
        .runtime(Arc::new(StubShaper), HostServices::headless())
        .expect("workbook runtime");
    click(&mut runtime, 25, 45);
    let caret_is_present = |scene: &calcforms_pal::scene::Scene| {
        primitives(scene, 2).iter().any(|p| {
            matches!(p, Prim::FillRect { paint: Paint::Solid(c), .. }
                if *c == Color::rgba(0, 0, 0, 255))
        })
    };
    let focused_text = surface.snapshot().unwrap().scene.unwrap();
    assert!(caret_is_present(&focused_text), "focused text owns a caret");
    click(&mut runtime, 20, 75);
    let focused_check = surface.snapshot().unwrap().scene.unwrap();
    assert!(
        !caret_is_present(&focused_check),
        "VBA removes the old caret"
    );
    assert!(primitives(&focused_check, 4)
        .iter()
        .any(|p| matches!(p, Prim::StrokeRect { .. })));
    click(&mut runtime, 220, 45);
    let focused_button = surface.snapshot().unwrap().scene.unwrap();
    assert!(
        !primitives(&focused_button, 4)
            .iter()
            .any(|p| matches!(p, Prim::StrokeRect { .. })),
        "VBA removes the old checkbox focus adorner"
    );
    assert!(!caret_is_present(&focused_button));
}
