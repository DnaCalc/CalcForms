use oxforms_headless_runner::{
    repo_root_from_crate, DrainPolicy, FixtureModule, FormSpec, HeadlessRunner, InputAction,
    RepaintPolicy, RunnerOptions, VK_BACKSPACE, VK_SPACE, VK_TAB,
};
use oxvba_bundle::ProjectMemberKind;

const VK_A: i16 = 65;
const VK_B: i16 = 66;
const VK_C: i16 = 67;
const VK_D: i16 = 68;
const VK_E: i16 = 69;
const VK_F: i16 = 70;

fn showcase_spec() -> FormSpec {
    FormSpec::new("FullSurfaceShowcaseForm", "Build").with_fixture(FixtureModule::class(
        "FullSurfaceShowcaseForm",
        "vba/smoke/fixtures/full_surface_showcase_form.cls",
    ))
}

#[test]
fn runner_attaches_renders_and_records_trace_rows() {
    let repo = repo_root_from_crate();
    let mut runner = HeadlessRunner::attach(&repo, &showcase_spec()).expect("attach showcase");

    runner.render().expect("initial render");
    let snap = runner.snapshot().expect("snapshot");
    assert_eq!(
        snap.node_count, 15,
        "root plus 13 showcase controls plus the TextBox selection overlay"
    );

    let capabilities = runner
        .read_string("CapabilityCatalog")
        .expect("CapabilityCatalog");
    assert!(
        capabilities.contains("InputField:kind=TextBox")
            && capabilities.contains("CheckBox:kind=CheckBox"),
        "showcase should expose current capability descriptors: {capabilities}"
    );
    let index = runner
        .read_string("InteractionIndexSummary")
        .expect("InteractionIndexSummary");
    assert!(
        index.contains(";first=InputField;last=CheckBox;")
            && index.contains(";default=OkButton;cancel=CancelButton;"),
        "showcase should expose the reducer interaction index: {index}"
    );

    let jsonl = runner.trace_jsonl().expect("trace jsonl");
    assert!(
        jsonl.contains("\"action\":\"render\""),
        "trace should include the explicit render row: {jsonl}"
    );
}

#[test]
fn runner_drains_key_turns_against_the_current_vba_state() {
    let repo = repo_root_from_crate();
    let mut runner = HeadlessRunner::attach(&repo, &showcase_spec()).expect("attach showcase");
    runner.render().expect("initial render");

    let mut script = Vec::new();
    script.extend(InputAction::key_turn(VK_A, "a"));
    script.extend(InputAction::key_turn(VK_B, "b"));
    let reports = runner
        .drain(&mut script, DrainPolicy::All)
        .expect("drain script");

    assert!(script.is_empty(), "all queued actions should drain");
    assert!(
        reports
            .iter()
            .any(|report| report.effects.contains("char:")),
        "character input should reduce through the VBA TextBox path"
    );
    assert_eq!(
        runner.read_string("InputText").expect("InputText"),
        "ab",
        "each key turn must mutate before the next turn is reduced"
    );
    assert!(
        runner.trace().len() >= 7,
        "initial render plus six input actions should be traced"
    );
}

#[test]
fn runner_can_step_a_burst_one_action_at_a_time() {
    let repo = repo_root_from_crate();
    let options = RunnerOptions {
        repaint_policy: RepaintPolicy::AfterNonEmptyEffect,
        ..RunnerOptions::default()
    };
    let mut runner =
        HeadlessRunner::attach_with_options(&repo, &showcase_spec(), options).expect("attach");
    runner.render().expect("initial render");

    let mut script = vec![
        InputAction::KeyDown {
            key_code: VK_TAB,
            shift: 0,
        },
        InputAction::KeyUp {
            key_code: VK_TAB,
            shift: 0,
        },
    ];
    let first = runner
        .drain(&mut script, DrainPolicy::One)
        .expect("drain one");
    assert_eq!(first.len(), 1);
    assert_eq!(script.len(), 1, "one queued action should remain");
    assert!(
        runner.trace_jsonl().unwrap().contains("key_down:9:0"),
        "key-down row should be recorded"
    );
}

#[test]
fn runner_handles_rapid_letter_sequence_and_backspace_repeat() {
    let repo = repo_root_from_crate();
    let options = RunnerOptions {
        repaint_policy: RepaintPolicy::Manual,
        ..RunnerOptions::default()
    };
    let mut runner =
        HeadlessRunner::attach_with_options(&repo, &showcase_spec(), options).expect("attach");
    runner.render().expect("initial render");

    let mut script = Vec::new();
    for (vk, text) in [
        (VK_A, "a"),
        (VK_B, "b"),
        (VK_C, "c"),
        (VK_D, "d"),
        (VK_E, "e"),
        (VK_F, "f"),
    ] {
        script.extend(InputAction::key_turn(vk, text));
    }
    for _ in 0..3 {
        script.push(InputAction::KeyDown {
            key_code: VK_BACKSPACE,
            shift: 0,
        });
    }
    script.push(InputAction::KeyUp {
        key_code: VK_BACKSPACE,
        shift: 0,
    });

    let reports = runner
        .drain(&mut script, DrainPolicy::All)
        .expect("drain rapid typing script");

    assert!(script.is_empty(), "all queued actions should drain");
    assert_eq!(
        runner.read_string("InputText").expect("InputText"),
        "abc",
        "rapid letters followed by repeated Backspace keydowns must reduce in order"
    );
    assert!(
        reports
            .iter()
            .filter(|report| report.effects.contains("keydown:InputField"))
            .count()
            >= 9,
        "letter keydowns plus Backspace repeats should all reach the focused TextBox"
    );
    assert!(
        !runner
            .trace_jsonl()
            .expect("trace jsonl")
            .contains("char-swallowed"),
        "rapid ordinary typing must not trip stale KeyDown swallow state"
    );
}

#[test]
fn runner_keyboard_space_toggles_focused_checkbox() {
    let repo = repo_root_from_crate();
    let mut runner = HeadlessRunner::attach(&repo, &showcase_spec()).expect("attach showcase");
    runner.render().expect("initial render");

    assert!(
        runner.read_bool("CheckValue").expect("CheckValue"),
        "showcase CheckBox starts checked"
    );

    let mut tab_to_checkbox = Vec::new();
    for _ in 0..4 {
        tab_to_checkbox.push(InputAction::KeyDown {
            key_code: VK_TAB,
            shift: 0,
        });
        tab_to_checkbox.push(InputAction::KeyUp {
            key_code: VK_TAB,
            shift: 0,
        });
    }
    let focus_reports = runner
        .drain(&mut tab_to_checkbox, DrainPolicy::All)
        .expect("tab to checkbox");
    assert!(tab_to_checkbox.is_empty(), "all Tab turns should drain");
    assert_eq!(
        runner.read_string("FocusName").expect("FocusName"),
        "CheckBox"
    );
    assert!(
        focus_reports
            .iter()
            .any(|report| report.effects.contains("enter:CheckBox")),
        "Tab traversal should focus the CheckBox through the reducer"
    );

    runner
        .invoke_string("ClearLog", ProjectMemberKind::Method)
        .expect("clear log");
    let down = runner
        .dispatch(InputAction::KeyDown {
            key_code: VK_SPACE,
            shift: 0,
        })
        .expect("space down");
    assert_eq!(down.effects, "activate:CheckBox|keydown:CheckBox|repaint");
    assert!(
        !runner.read_bool("CheckValue").expect("CheckValue"),
        "Space toggles the focused CheckBox off"
    );

    let up = runner
        .dispatch(InputAction::KeyUp {
            key_code: VK_SPACE,
            shift: 0,
        })
        .expect("space up");
    assert_eq!(up.effects, "keyup:CheckBox");
    assert_eq!(
        runner
            .read_string("HandlerLog")
            .expect("HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec![
            "CheckBox.Change=False",
            "CheckBox.Click=False",
            "CheckBox.KeyDown:32",
            "CheckBox.KeyUp:32",
        ],
        "Space activation should toggle value before KeyDown, then raise KeyUp"
    );

    let jsonl = runner.trace_jsonl().expect("trace jsonl");
    assert!(
        jsonl.contains("\"action\":\"key_down:32:0\"")
            && jsonl.contains("\"action\":\"key_up:32:0\""),
        "keyboard checkbox toggle should be visible in the headless trace: {jsonl}"
    );
}

#[test]
fn runner_mouse_drag_selects_textbox_text_through_mousemove() {
    let repo = repo_root_from_crate();
    let mut runner = HeadlessRunner::attach(&repo, &showcase_spec()).expect("attach showcase");
    runner.render().expect("initial render");

    let mut script = Vec::new();
    for (vk, text) in [
        (VK_A, "a"),
        (VK_B, "b"),
        (VK_C, "c"),
        (VK_D, "d"),
        (VK_E, "e"),
        (VK_F, "f"),
    ] {
        script.extend(InputAction::key_turn(vk, text));
    }
    runner
        .drain(&mut script, DrainPolicy::All)
        .expect("type text");
    assert_eq!(
        runner.read_string("InputText").expect("InputText"),
        "abcdef"
    );

    let down = runner
        .dispatch(InputAction::MouseDown {
            x: 24,
            y: 98,
            button: 1,
            shift: 0,
        })
        .expect("mouse down");
    assert!(
        down.effects.contains("mousedown:InputField"),
        "press should route to the TextBox: {}",
        down.effects
    );

    let drag = runner
        .dispatch(InputAction::MouseMove {
            x: 35,
            y: 98,
            button: 1,
            shift: 0,
        })
        .expect("mouse move");
    assert_eq!(drag.effects, "mousemove:InputField|repaint");
    assert_eq!(runner.read_i32("InputSelStart").expect("InputSelStart"), 1);
    assert_eq!(
        runner.read_i32("InputSelLength").expect("InputSelLength"),
        3
    );
    assert_eq!(
        runner.read_string("InputSelText").expect("InputSelText"),
        "bcd"
    );

    runner
        .dispatch(InputAction::MouseUp {
            x: 35,
            y: 98,
            button: 1,
            shift: 0,
        })
        .expect("mouse up");
    assert!(
        runner
            .trace_jsonl()
            .expect("trace jsonl")
            .contains("\"action\":\"mouse_move:35,98\""),
        "mousemove should be a first-class trace row"
    );
}
