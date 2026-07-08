use oxforms_headless_runner::{
    repo_root_from_crate, DrainPolicy, FixtureModule, FormSpec, HeadlessRunner, InputAction,
    RepaintPolicy, RunnerOptions, VK_BACKSPACE, VK_SPACE, VK_TAB,
};
use oxforms_oxvba_adapter::host_services::{HostCursor, HostTimerRequest, HostTimerSlot};
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

fn reentrancy_spec() -> FormSpec {
    FormSpec::new("ReducerReentrancyForm", "Build").with_fixture(FixtureModule::class(
        "ReducerReentrancyForm",
        "vba/smoke/fixtures/reducer_reentrancy_form.cls",
    ))
}

#[test]
fn runner_attaches_renders_and_records_trace_rows() {
    let repo = repo_root_from_crate();
    let mut runner = HeadlessRunner::attach(&repo, &showcase_spec()).expect("attach showcase");

    runner.render().expect("initial render");
    let snap = runner.snapshot().expect("snapshot");
    assert_eq!(
        snap.node_count, 29,
        "root plus 23 showcase controls, container children, and the TextBox text/selection nodes"
    );

    let capabilities = runner
        .read_string("CapabilityCatalog")
        .expect("CapabilityCatalog");
    assert!(
        capabilities.contains("InputField:kind=TextBox")
            && capabilities.contains("CheckBox:kind=CheckBox")
            && capabilities.contains("OptionButton:kind=OptionButton")
            && capabilities.contains("ToggleButton:kind=ToggleButton")
            && capabilities.contains("ChoicesList:kind=ListBox")
            && capabilities.contains("ChoiceCombo:kind=ComboBox")
            && capabilities.contains("FrameGroup:kind=Frame")
            && capabilities.contains("LogoImage:kind=Image")
            && capabilities.contains("RepeatSpin:kind=SpinButton")
            && capabilities.contains("AmountScroll:kind=ScrollBar")
            && capabilities.contains("ModeTabs:kind=TabStrip")
            && capabilities.contains("ModePages:kind=MultiPage"),
        "showcase should expose current capability descriptors: {capabilities}"
    );
    let index = runner
        .read_string("InteractionIndexSummary")
        .expect("InteractionIndexSummary");
    assert!(
        index.contains(";first=InputField;last=ChoiceCombo;")
            && index.contains(";default=OkButton;cancel=CancelButton;"),
        "showcase should expose the reducer interaction index: {index}"
    );
    let state = runner
        .read_string("InteractionStateSummary")
        .expect("InteractionStateSummary");
    assert!(
        state.contains(
            "focus=InputField;capture=;pressed=;hover=InputField;cursor_target=InputField;cursor=3"
        ),
        "showcase should expose first-class InteractionManager state: {state}"
    );
    let accessibility = runner
        .read_string("AccessibilitySnapshot")
        .expect("AccessibilitySnapshot");
    assert!(
        accessibility.contains(
            "role=form;name=full_surface_showcase;value=OxForms Full Surface Showcase"
        ) && accessibility.contains(
            "role=textbox;name=InputField;value=;enabled=True;visible=True;focused=True;selected=False"
        ) && accessibility.contains(
            "role=checkbox;name=CheckBox;value=True;enabled=True;visible=True;focused=False"
        ) && accessibility.contains(
            "role=radio;name=OptionButton;value=True;enabled=True;visible=True;focused=False"
        ) && accessibility.contains(
            "role=togglebutton;name=ToggleButton;value=True;enabled=True;visible=True;focused=False"
        ) && accessibility.contains(
            "role=listbox;name=ChoicesList;value=Red;enabled=True;visible=True;focused=False"
        ) && accessibility.contains(
            "role=combobox;name=ChoiceCombo;value=Small;enabled=True;visible=True;focused=False"
        ) && accessibility.contains(
            "role=group;name=FrameGroup;value=Frame;enabled=True;visible=True;focused=False"
        ) && accessibility.contains(
            "role=label;name=FrameLabel;value=Nested child"
        ) && accessibility.contains(
            "role=image;name=LogoImage;value=showcase-inline;enabled=True;visible=True;focused=False"
        ) && accessibility.contains(
            "role=spinbutton;name=RepeatSpin;value=2;enabled=True;visible=True;focused=False"
        ) && accessibility.contains(
            "role=scrollbar;name=AmountScroll;value=40;enabled=True;visible=True;focused=False"
        ) && accessibility.contains(
            "role=tabstrip;name=ModeTabs;value=One;enabled=True;visible=True;focused=False"
        ) && accessibility.contains(
            "role=multipage;name=ModePages;value=First;enabled=True;visible=True;focused=False"
        ) && accessibility.contains(
            "role=page;name=ModePages.Page0;value=First;enabled=True;visible=True"
        ),
        "showcase should expose a representative accessibility snapshot: {accessibility}"
    );

    let jsonl = runner.trace_jsonl().expect("trace jsonl");
    assert!(
        jsonl.contains("\"action\":\"render\"")
            && jsonl.contains("\"accessibility_snapshot\"")
            && jsonl.contains("role=textbox;name=InputField"),
        "trace should include the explicit render row and accessibility snapshot: {jsonl}"
    );
}

#[test]
fn runner_reads_showcase_conformance_dashboard_through_oxruntime() {
    let repo = repo_root_from_crate();
    let mut runner = HeadlessRunner::attach(&repo, &showcase_spec()).expect("attach showcase");
    runner.render().expect("initial render");

    let dashboard = runner
        .read_string("ConformanceDashboard")
        .expect("ConformanceDashboard");
    for expected in [
        "OXFORMS_CONFORMANCE_DASHBOARD version=1",
        "runtime=OxRuntime/OxReducer/OxForms.Surface/Scene",
        "supported.controls=UserForm,Controls,Label,TextBox,CommandButton,CheckBox,OptionButton,ToggleButton,ListBox,ComboBox,Frame,Image,SpinButton,ScrollBar,TabStrip,Tabs,Tab,MultiPage,Pages,Page",
        "supported.properties=TextBox.Text,TextBox.Value,TextBox.SelStart",
        "supported.methods=Controls.Add,Controls.Item,UserForm.Render,Dispatch,DispatchKey,DispatchChar,DispatchDrop,SetClipboardText,DispatchTimer,RunSelfTest",
        "supported.events=Initialize,Activate,Deactivate,Terminate,QueryClose,Enter,Exit,BeforeUpdate,AfterUpdate,Change,Scroll,Click,MouseDown,MouseUp,KeyDown,KeyPress,KeyUp,BeforeDropOrPaste,DropButtonClick,SpinUp,SpinDown",
        "first=InputField;last=ChoiceCombo;default=OkButton;cancel=CancelButton;",
        "cursor=focus=InputField;capture=;pressed=;hover=InputField;cursor_target=InputField;cursor=3",
        "host.services=clipboard,text-dataobject,cursor,timer,dpi,metrics,colors,image-decode,drag-drop",
        "accessibility.snapshot=role=form;name=full_surface_showcase",
        "perf.report=docs/evidence/W009_first_class_runtime_foundation/perf/w009-ideal-architecture-budget-20260707.json",
        "pending.controls=",
    ] {
        assert!(
            dashboard.contains(expected),
            "dashboard should include {expected:?}; dashboard was:\n{dashboard}"
        );
    }
    assert!(
        !dashboard.contains("pending.controls=Frame"),
        "Frame is live and must not be listed as pending: {dashboard}"
    );

    let supported = runner
        .read_string("SupportedSurfaceSummary")
        .expect("SupportedSurfaceSummary");
    assert!(
        supported.contains("controls=UserForm,Controls,Label,TextBox,CommandButton,CheckBox,OptionButton,ToggleButton,ListBox,ComboBox,Frame,Image,SpinButton,ScrollBar,TabStrip,Tabs,Tab,MultiPage,Pages,Page")
            && supported.contains("methods=Controls.Add,Controls.Item,Render,Dispatch")
            && supported.contains("events=Initialize,Activate,Deactivate,Terminate,QueryClose"),
        "supported surface summary should be a compact dashboard row: {supported}"
    );

    let pending = runner
        .read_string("PendingSurfaceSummary")
        .expect("PendingSurfaceSummary");
    assert!(
        pending.contains("controls=")
            && pending.contains("Accessibility Windows UIA/MSAA provider")
            && pending.contains("scaled hit-test indexing"),
        "pending summary should include both controls and known follow-ups: {pending}"
    );

    let perf = runner
        .read_string("PerfBudgetSummary")
        .expect("PerfBudgetSummary");
    assert!(
        perf.contains("representative_p95_us=32356")
            && perf.contains("scaled_hit_test_p95_100_controls_us=432473")
            && perf.contains("followup=oxforms-bqr"),
        "perf summary should stay tied to the committed W009 report: {perf}"
    );
}

#[test]
fn runner_accessibility_snapshot_tracks_focus_value_and_selection() {
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

    runner
        .dispatch(InputAction::MouseDown {
            x: 24,
            y: 98,
            button: 1,
            shift: 0,
        })
        .expect("mouse down");
    runner
        .dispatch(InputAction::MouseMove {
            x: 35,
            y: 98,
            button: 1,
            shift: 0,
        })
        .expect("mouse move");

    let selected = runner
        .read_string("AccessibilitySnapshot")
        .expect("AccessibilitySnapshot after selection");
    assert!(
        selected.contains(
            "role=textbox;name=InputField;value=abcdef;enabled=True;visible=True;focused=True;selected=True;sel_start=1;sel_length=3;sel_text=bcd;patterns=text,value,selection"
        ),
        "TextBox accessibility row should expose value, focus, and selection: {selected}"
    );

    runner
        .dispatch(InputAction::MouseUp {
            x: 35,
            y: 98,
            button: 1,
            shift: 0,
        })
        .expect("mouse up");

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
    runner
        .drain(&mut tab_to_checkbox, DrainPolicy::All)
        .expect("tab to checkbox");
    runner
        .dispatch(InputAction::KeyDown {
            key_code: VK_SPACE,
            shift: 0,
        })
        .expect("space down");

    let toggled = runner
        .read_string("AccessibilitySnapshot")
        .expect("AccessibilitySnapshot after checkbox toggle");
    assert!(
        toggled.contains(
            "role=checkbox;name=CheckBox;value=False;enabled=True;visible=True;focused=True;selected=False;sel_start=0;sel_length=0;sel_text=;patterns=toggle,value"
        ),
        "CheckBox accessibility row should expose focus and value changes: {toggled}"
    );

    let jsonl = runner.trace_jsonl().expect("trace jsonl");
    assert!(
        jsonl.contains("role=textbox;name=InputField;value=abcdef")
            && jsonl.contains("focused=True;selected=True;sel_start=1;sel_length=3;sel_text=bcd")
            && jsonl.contains("role=checkbox;name=CheckBox;value=False;enabled=True;visible=True;focused=True"),
        "headless trace rows should carry accessibility snapshots for value/focus/selection changes: {jsonl}"
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
fn runner_records_service_effect_and_same_turn_readback_repaint() {
    let repo = repo_root_from_crate();
    let mut runner = HeadlessRunner::attach(&repo, &showcase_spec()).expect("attach showcase");
    runner.render().expect("initial render");
    let before_revision = runner.snapshot().expect("snapshot").revision;

    let report = runner
        .dispatch(InputAction::PasteText("svc".to_string()))
        .expect("paste text");

    assert_eq!(report.service_effects, vec!["clipboard.set_text:3"]);
    assert!(
        report.effects.contains("paste:InputField") && report.effects.contains("repaint"),
        "paste should flow through clipboard service, reducer paste, and repaint: {}",
        report.effects
    );
    assert_eq!(
        runner.read_string("InputText").expect("InputText"),
        "svc",
        "VBA object-model readback should observe the paste in the same event turn"
    );
    assert!(
        report.rendered && report.revision > before_revision,
        "the same event turn should render a newer Scene revision"
    );
    assert_eq!(
        runner.trace().last().expect("paste trace row").render_us,
        0,
        "the reducer already repainted; the runner must not issue a second render"
    );

    let jsonl = runner.trace_jsonl().expect("trace jsonl");
    assert!(
        jsonl.contains("\"action\":\"paste:svc\"")
            && jsonl.contains("\"host_service_effects\":[\"clipboard.set_text:3\"]"),
        "service effect trace should stay attached to the paste turn: {jsonl}"
    );
}

#[test]
fn runner_host_services_probe_covers_representative_spine() {
    let repo = repo_root_from_crate();
    let mut runner = HeadlessRunner::attach(&repo, &showcase_spec()).expect("attach showcase");

    let report = runner
        .dispatch(InputAction::HostServiceProbe)
        .expect("host service probe");
    assert!(
        report.effects.is_empty(),
        "service probe must not reduce VBA"
    );
    assert!(
        !report.rendered,
        "service probe should not render the Scene"
    );

    let joined = report.service_effects.join("|");
    for expected in [
        "host_services.backend:headless",
        "clipboard.formats:text",
        "data_object.skeleton:text",
        "cursor.current:default",
        "timer.slot:caret_blink",
        "timer.slot:auto_repeat",
        "metrics.system:",
        "colors.system:",
        "dpi.current:96x96",
        "image.decode:stub",
        "drag_drop.trace:",
    ] {
        assert!(
            joined.contains(expected),
            "probe trace should contain {expected}: {joined}"
        );
    }
}

#[test]
fn runner_virtual_timer_and_clipboard_pass_through_oxruntime() {
    let repo = repo_root_from_crate();
    let mut runner = HeadlessRunner::attach(&repo, &showcase_spec()).expect("attach showcase");
    runner.render().expect("initial render");

    let armed = runner
        .dispatch(InputAction::ArmTimer(HostTimerRequest::new(
            HostTimerSlot::CaretBlink,
            25,
            true,
        )))
        .expect("arm timer");
    assert_eq!(
        armed.service_effects,
        vec!["timer.arm:caret_blink:25:repeat=true"]
    );

    let early = runner
        .dispatch(InputAction::Tick { advance_ms: 24 })
        .expect("advance before due");
    assert_eq!(early.service_effects, vec!["time.advance:24:now=24"]);

    let fired = runner
        .dispatch(InputAction::Tick { advance_ms: 1 })
        .expect("advance to due");
    assert_eq!(
        fired.service_effects,
        vec!["time.advance:1:now=25", "timer.fire:caret_blink:1:at=25"]
    );
    assert_eq!(
        runner.trace().last().expect("timer trace row").at_ms,
        25,
        "virtual clock should advance through the OxRuntime turn"
    );

    let pasted = runner
        .dispatch(InputAction::PasteText("timer".to_string()))
        .expect("paste after timer");
    assert_eq!(pasted.service_effects, vec!["clipboard.set_text:5"]);
    assert_eq!(
        runner.read_string("InputText").expect("InputText"),
        "timer",
        "clipboard paste should still mutate VBA through OxRuntime"
    );
}

#[test]
fn runner_spinbutton_held_repeat_uses_virtual_auto_repeat_timer() {
    let repo = repo_root_from_crate();
    let mut runner = HeadlessRunner::attach(&repo, &showcase_spec()).expect("attach showcase");
    runner.render().expect("initial render");

    assert_eq!(runner.read_i32("SpinValue").expect("SpinValue"), 2);

    let down = runner
        .dispatch(InputAction::MouseDown {
            x: 546,
            y: 174,
            button: 1,
            shift: 0,
        })
        .expect("spin mouse down");
    assert!(
        down.effects.contains("mousedown:RepeatSpin") && down.effects.contains("repaint"),
        "press should route to the SpinButton and render its pressed state: {}",
        down.effects
    );
    assert_eq!(
        runner.read_i32("SpinValue").expect("SpinValue after press"),
        3,
        "the initial press performs exactly one SpinUp step"
    );

    runner
        .dispatch(InputAction::ArmTimer(HostTimerRequest::new(
            HostTimerSlot::AutoRepeat,
            25,
            true,
        )))
        .expect("arm auto-repeat");

    let early = runner
        .dispatch(InputAction::Tick { advance_ms: 24 })
        .expect("tick before due");
    assert_eq!(early.service_effects, vec!["time.advance:24:now=24"]);
    assert_eq!(
        runner.read_i32("SpinValue").expect("SpinValue before due"),
        3,
        "early virtual time must not mutate the held SpinButton"
    );

    let fired = runner
        .dispatch(InputAction::Tick { advance_ms: 1 })
        .expect("tick first fire");
    assert_eq!(
        fired.service_effects,
        vec!["time.advance:1:now=25", "timer.fire:auto_repeat:1:at=25"]
    );
    assert_eq!(fired.effects, "repeat:RepeatSpin:1|repaint");
    assert_eq!(
        runner.read_i32("SpinValue").expect("SpinValue after fire"),
        4,
        "one timer fire performs one repeat step"
    );

    let burst = runner
        .dispatch(InputAction::Tick { advance_ms: 50 })
        .expect("tick burst");
    assert_eq!(
        burst.service_effects,
        vec!["time.advance:50:now=75", "timer.fire:auto_repeat:2:at=75"]
    );
    assert_eq!(burst.effects, "repeat:RepeatSpin:2|repaint");
    assert_eq!(
        runner.read_i32("SpinValue").expect("SpinValue after burst"),
        6,
        "batched timer fires perform ordered repeat steps"
    );

    let up = runner
        .dispatch(InputAction::MouseUp {
            x: 546,
            y: 174,
            button: 1,
            shift: 0,
        })
        .expect("spin mouse up");
    assert!(
        up.effects.contains("mouseup:RepeatSpin") && up.effects.contains("repaint"),
        "release should clear repeat press state: {}",
        up.effects
    );
    let canceled = runner
        .dispatch(InputAction::CancelTimer(HostTimerSlot::AutoRepeat))
        .expect("cancel auto-repeat");
    assert_eq!(canceled.service_effects, vec!["timer.cancel:auto_repeat"]);
    runner
        .dispatch(InputAction::Tick { advance_ms: 100 })
        .expect("tick after cancel");
    assert_eq!(
        runner
            .read_i32("SpinValue")
            .expect("SpinValue after cancel"),
        6,
        "cancelled repeat timer must not mutate value"
    );

    runner
        .dispatch(InputAction::MouseDown {
            x: 546,
            y: 174,
            button: 1,
            shift: 0,
        })
        .expect("spin mouse down before disable");
    assert_eq!(runner.read_i32("SpinValue").expect("SpinValue"), 7);
    let disabled = runner
        .invoke_string("DisableSpin", ProjectMemberKind::Method)
        .expect("disable spin");
    assert!(
        disabled.contains("value=7") && disabled.contains("pressed_direction=1"),
        "disabling should preserve diagnostic repeat state without mutating value: {disabled}"
    );
    runner
        .dispatch(InputAction::ArmTimer(HostTimerRequest::new(
            HostTimerSlot::AutoRepeat,
            25,
            true,
        )))
        .expect("arm auto-repeat while disabled");
    let disabled_fire = runner
        .dispatch(InputAction::Tick { advance_ms: 25 })
        .expect("tick disabled repeat");
    assert_eq!(
        disabled_fire.service_effects,
        vec!["time.advance:25:now=200", "timer.fire:auto_repeat:1:at=200"]
    );
    assert_eq!(
        disabled_fire.effects, "",
        "disabling the captured SpinButton should clear the repeat route"
    );
    assert_eq!(
        runner.read_i32("SpinValue").expect("SpinValue disabled"),
        7,
        "disabled controls must ignore held repeat mutations"
    );

    let mut hidden_runner = HeadlessRunner::attach(&repo, &showcase_spec()).expect("attach hidden");
    hidden_runner.render().expect("initial render hidden");
    hidden_runner
        .dispatch(InputAction::MouseDown {
            x: 546,
            y: 174,
            button: 1,
            shift: 0,
        })
        .expect("spin mouse down before hide");
    assert_eq!(hidden_runner.read_i32("SpinValue").expect("SpinValue"), 3);
    let hidden = hidden_runner
        .invoke_string("HideSpin", ProjectMemberKind::Method)
        .expect("hide spin");
    assert!(
        hidden.contains("value=3")
            && hidden.contains("pressed_direction=1")
            && hidden.contains("visible=False"),
        "hiding should preserve diagnostic repeat state without mutating value: {hidden}"
    );
    hidden_runner
        .dispatch(InputAction::ArmTimer(HostTimerRequest::new(
            HostTimerSlot::AutoRepeat,
            25,
            true,
        )))
        .expect("arm hidden auto-repeat");
    let hidden_fire = hidden_runner
        .dispatch(InputAction::Tick { advance_ms: 25 })
        .expect("tick hidden repeat");
    assert_eq!(
        hidden_fire.service_effects,
        vec!["time.advance:25:now=25", "timer.fire:auto_repeat:1:at=25"]
    );
    assert_eq!(
        hidden_fire.effects, "",
        "hiding the captured SpinButton should clear the repeat route"
    );
    assert_eq!(
        hidden_runner
            .read_i32("SpinValue")
            .expect("SpinValue hidden"),
        3,
        "hidden controls must ignore held repeat mutations"
    );

    let log = runner.read_string("HandlerLog").expect("HandlerLog");
    for expected in [
        "SpinButton.Enter",
        "SpinButton.MouseDown",
        "SpinButton.SpinUp=3",
        "SpinButton.Change=3",
        "SpinButton.SpinUp=4",
        "SpinButton.Change=4",
        "SpinButton.SpinUp=5",
        "SpinButton.Change=5",
        "SpinButton.SpinUp=6",
        "SpinButton.Change=6",
        "SpinButton.MouseUp",
    ] {
        assert!(
            log.lines().any(|line| line == expected),
            "SpinButton repeat log missing {expected:?}; log was:\n{log}"
        );
    }

    let jsonl = runner.trace_jsonl().expect("trace jsonl");
    assert!(
        jsonl.contains("\"action\":\"tick:1\"")
            && jsonl.contains("timer.fire:auto_repeat:1:at=25")
            && jsonl.contains("\"effect_log\":\"repeat:RepeatSpin:2|repaint\""),
        "repeat timing and effect trace should be visible in JSONL: {jsonl}"
    );
}

#[test]
fn runner_reentrant_handler_mutation_and_lifecycle_stay_coherent() {
    let repo = repo_root_from_crate();
    let mut runner = HeadlessRunner::attach(&repo, &reentrancy_spec()).expect("attach reentrant");
    runner.render().expect("initial render");
    let initial_revision = runner.snapshot().expect("initial snapshot").revision;

    runner
        .dispatch(InputAction::MouseDown {
            x: 152,
            y: 32,
            button: 1,
            shift: 0,
        })
        .expect("button down");
    let up = runner
        .dispatch(InputAction::MouseUp {
            x: 152,
            y: 32,
            button: 1,
            shift: 0,
        })
        .expect("button up");
    assert_eq!(
        up.effects, "mouseup:Reenter|click:Reenter|release:Reenter|repaint",
        "nested dispatch must not clobber the outer mouse-up effect log"
    );
    assert_eq!(
        runner.read_string("FieldText").expect("FieldText"),
        "r",
        "nested DispatchKey/DispatchChar inside the button handler mutates the TextBox"
    );
    assert_eq!(
        runner.read_string("FocusName").expect("FocusName"),
        "Field",
        "nested Tab dispatch should leave focus on Field coherently"
    );
    assert_eq!(
        runner.read_string("StatusCaption").expect("StatusCaption"),
        "nested:r",
        "handler-side label mutation and repaint should be observable after the turn"
    );
    assert!(
        runner.snapshot().expect("after nested snapshot").revision > initial_revision,
        "handler repaint and runner turn should advance the resident Scene"
    );

    let log = runner.read_string("HandlerLog").expect("HandlerLog");
    for expected in [
        "Reenter.Enter",
        "Reenter.Click.Begin",
        "Reenter.Exit",
        "Field.Enter",
        "NestedKey=keydown:Reenter|exit:Reenter|enter:Field|repaint",
        "NestedChar=char:Field|repaint",
        "Field.Change=r",
        "Field.Change.Render",
        "Reenter.Click.Render",
        "Reenter.Click.End",
    ] {
        assert!(
            log.lines()
                .any(|line| line == expected || line.contains(expected)),
            "reentrant handler log missing {expected:?}; log was:\n{log}"
        );
    }

    runner
        .invoke_string("ClearLog", ProjectMemberKind::Method)
        .expect("clear log");
    runner
        .invoke_string("ArmBeforeUpdateVeto", ProjectMemberKind::Method)
        .expect("arm veto");
    let veto = runner
        .dispatch(InputAction::KeyDown {
            key_code: VK_TAB,
            shift: 0,
        })
        .expect("tab with veto");
    assert_eq!(veto.effects, "keydown:Field|beforeupdate:Field");
    assert_eq!(
        runner.read_string("FocusName").expect("FocusName"),
        "Field",
        "BeforeUpdate veto inside a later queued turn keeps focus stable"
    );
    assert_eq!(
        runner
            .read_string("HandlerLog")
            .expect("HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["Field.BeforeUpdate"],
        "veto turn should not leak AfterUpdate/Exit/Enter"
    );

    runner
        .invoke_string("PerformInitialize", ProjectMemberKind::Method)
        .expect("initialize");
    runner
        .invoke_string("PerformActivate", ProjectMemberKind::Method)
        .expect("activate");
    assert_eq!(
        runner
            .invoke_string("QueryCloseAllowed", ProjectMemberKind::Method)
            .expect("query close allowed"),
        "cancel=0"
    );
    assert_eq!(
        runner
            .invoke_string("QueryCloseVetoed", ProjectMemberKind::Method)
            .expect("query close vetoed"),
        "cancel=1"
    );
    let hide = runner
        .invoke_string("RequestHide", ProjectMemberKind::Method)
        .expect("hide");
    assert!(
        hide.contains("hidden=True") && hide.contains("unloaded=False"),
        "hide should be represented separately from unload: {hide}"
    );
    let unload = runner
        .invoke_string("RequestUnload", ProjectMemberKind::Method)
        .expect("unload");
    assert!(
        unload.contains("hidden=True") && unload.contains("unloaded=True"),
        "unload should update lifecycle state and render after mutation: {unload}"
    );
    runner
        .invoke_string("PerformDeactivate", ProjectMemberKind::Method)
        .expect("deactivate");
    runner
        .invoke_string("PerformTerminate", ProjectMemberKind::Method)
        .expect("terminate");
    assert_eq!(
        runner
            .invoke_string("ModalProbe", ProjectMemberKind::Method)
            .expect("modal probe"),
        "BLOCKED:no nested modal pump in OxRuntime yet"
    );

    let lifecycle_log = runner.read_string("HandlerLog").expect("HandlerLog");
    for expected in [
        "UserForm.Initialize",
        "UserForm.Activate",
        "UserForm.QueryClose:1",
        "UserForm.QueryClose:0",
        "Form.HideRequested",
        "Form.UnloadRequested",
        "UserForm.Deactivate",
        "UserForm.Terminate",
    ] {
        assert!(
            lifecycle_log.lines().any(|line| line == expected),
            "lifecycle log missing {expected:?}; log was:\n{lifecycle_log}"
        );
    }

    let jsonl = runner.trace_jsonl().expect("trace jsonl");
    assert!(
        jsonl.contains("\"action\":\"mouse_up:152,32\"")
            && jsonl.contains("\"action\":\"key_down:9:0\"")
            && jsonl.contains("role=textbox;name=Field;value=r"),
        "trace should preserve outer click, queued Tab turn, and post-reentrant TextBox state: {jsonl}"
    );
}

#[test]
fn runner_traces_cursor_dpi_image_and_drag_drop_services() {
    let repo = repo_root_from_crate();
    let mut runner = HeadlessRunner::attach(&repo, &showcase_spec()).expect("attach showcase");
    runner.render().expect("initial render");

    assert_eq!(
        runner
            .dispatch(InputAction::SetCursor(HostCursor::IBeam))
            .expect("set cursor")
            .service_effects,
        vec!["cursor.set:ibeam"]
    );
    assert_eq!(
        runner
            .dispatch(InputAction::DpiChanged {
                dpi_x: 120,
                dpi_y: 144,
            })
            .expect("dpi")
            .service_effects,
        vec!["dpi.set:120x144"]
    );
    let decoded = runner
        .dispatch(InputAction::DecodeImage {
            image_id: "fixture-image".to_string(),
            bytes_sha256: "abc123".to_string(),
        })
        .expect("decode image");
    assert!(
        decoded
            .service_effects
            .iter()
            .any(|effect| effect.contains("image.decode:fixture-image:sha256=abc123")),
        "image decode handle shape should be traced: {:?}",
        decoded.service_effects
    );

    let dropped = runner
        .dispatch(InputAction::DropText("DROP".to_string()))
        .expect("drop text");
    assert_eq!(
        dropped.service_effects,
        vec!["data_object.snapshot:text:4", "drag_drop.drop_text:4"]
    );
    assert!(
        dropped.effects.contains("drop:InputField"),
        "drop should still reduce through the focused TextBox: {}",
        dropped.effects
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
