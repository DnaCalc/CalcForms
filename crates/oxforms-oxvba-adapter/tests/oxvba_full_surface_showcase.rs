//! Living full-surface showcase proof. The VBA fixture renders the current intrinsic surface
//! (Label, TextBox, CommandButton, CheckBox), lists future FM20 controls as pending rows, and
//! exposes `RunSelfTest` so the supported method/event surface can be proven without launching a
//! desktop window.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use oxforms_oxvba_adapter::runtime::OxRuntime;
use oxforms_oxvba_adapter::surface::{register_surface, SurfaceFactory};
use oxforms_pal::scene::{ImageHandle, Prim, StubShaper};

use oxvba_bundle::ProjectMemberKind;
use oxvba_com::PortableComProjection;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, HostProfileProvider, ProjectRuntimeSession};
use oxvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..").join("..")
}

fn module_unit(name: &str, kind: ModuleKind, relative: &str) -> ModuleUnit {
    let path = repo_root().join(relative);
    let source = std::fs::read_to_string(&path)
        .unwrap_or_else(|err| panic!("read {}: {err}", path.display()));
    let mut attributes = ModuleAttributes::named(name);
    attributes.vb_exposed = true;
    attributes.vb_creatable = true;
    ModuleUnit {
        module_name: name.to_string(),
        module_kind: kind,
        attributes,
        source,
    }
}

fn build_session() -> (ProjectRuntimeSession, Arc<SurfaceFactory>) {
    let modules = vec![
        module_unit(
            "OxFormsModel",
            ModuleKind::Procedural,
            "vba/oxforms/OxFormsModel.bas",
        ),
        module_unit(
            "IOxControl",
            ModuleKind::Class,
            "vba/oxforms/IOxControl.cls",
        ),
        module_unit(
            "IOxControlHost",
            ModuleKind::Class,
            "vba/oxforms/IOxControlHost.cls",
        ),
        module_unit(
            "IOxControlContainer",
            ModuleKind::Class,
            "vba/oxforms/IOxControlContainer.cls",
        ),
        module_unit(
            "OxControlCore",
            ModuleKind::Class,
            "vba/oxforms/OxControlCore.cls",
        ),
        module_unit("Controls", ModuleKind::Class, "vba/oxforms/Controls.cls"),
        module_unit(
            "ReturnInteger",
            ModuleKind::Class,
            "vba/oxforms/ReturnInteger.cls",
        ),
        module_unit(
            "ReturnBoolean",
            ModuleKind::Class,
            "vba/oxforms/ReturnBoolean.cls",
        ),
        module_unit("Label", ModuleKind::Class, "vba/oxforms/Label.cls"),
        module_unit(
            "OxTextService",
            ModuleKind::Class,
            "vba/oxforms/OxTextService.cls",
        ),
        module_unit("TextBox", ModuleKind::Class, "vba/oxforms/TextBox.cls"),
        module_unit(
            "CommandButton",
            ModuleKind::Class,
            "vba/oxforms/CommandButton.cls",
        ),
        module_unit("CheckBox", ModuleKind::Class, "vba/oxforms/CheckBox.cls"),
        module_unit("ListBox", ModuleKind::Class, "vba/oxforms/ListBox.cls"),
        module_unit("ComboBox", ModuleKind::Class, "vba/oxforms/ComboBox.cls"),
        module_unit("Frame", ModuleKind::Class, "vba/oxforms/Frame.cls"),
        module_unit("Image", ModuleKind::Class, "vba/oxforms/Image.cls"),
        module_unit(
            "SpinButton",
            ModuleKind::Class,
            "vba/oxforms/SpinButton.cls",
        ),
        module_unit(
            "ToggleButton",
            ModuleKind::Class,
            "vba/oxforms/ToggleButton.cls",
        ),
        module_unit(
            "OptionButtonControl",
            ModuleKind::Class,
            "vba/oxforms/OptionButtonControl.cls",
        ),
        module_unit("UserForm", ModuleKind::Class, "vba/oxforms/UserForm.cls"),
        module_unit("OxTheme", ModuleKind::Procedural, "vba/oxforms/OxTheme.bas"),
        module_unit(
            "OxControlPaint",
            ModuleKind::Procedural,
            "vba/oxforms/OxControlPaint.bas",
        ),
        module_unit(
            "OxSceneBuilder",
            ModuleKind::Class,
            "vba/oxforms/OxSceneBuilder.cls",
        ),
        module_unit(
            "OxAccessibilityService",
            ModuleKind::Class,
            "vba/oxforms/OxAccessibilityService.cls",
        ),
        module_unit(
            "OxInteractionManager",
            ModuleKind::Class,
            "vba/oxforms/OxInteractionManager.cls",
        ),
        module_unit("OxReducer", ModuleKind::Class, "vba/oxforms/OxReducer.cls"),
        module_unit(
            "FullSurfaceShowcaseForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/full_surface_showcase_form.cls",
        ),
    ];

    let manifest = SymbolProjectManifest {
        project_name: "FullSurfaceShowcase".to_string(),
        project_kind: ProjectKind::Library,
        modules,
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
    };

    let program = oxvba_bind::bind_program(&manifest, &oxvba_symbol::CatalogTypeLibResolver)
        .expect("bind showcase project");
    let bundle = oxvba_oxir::elaborate::elaborate(&program).expect("elaborate showcase project");

    let projection = Arc::new(PortableComProjection::new());
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(StubShaper)));
    register_surface(&projection, surface.clone());

    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::interactive_dev());
    let engine = Engine::new(HostConfig { enable_jit: false }).with_host_profile_provider(profile);
    let session = engine
        .prepare_image_session(oxvba_oxir::OxImage::new(vec![bundle]))
        .expect("prepare showcase session");
    (session, surface)
}

fn attach_showcase() -> (OxRuntime, Arc<SurfaceFactory>) {
    let (session, surface) = build_session();
    let rt =
        OxRuntime::attach(session, "FullSurfaceShowcaseForm", "Build").expect("attach showcase");
    (rt, surface)
}

fn invoke_string(rt: &mut OxRuntime, member: &str, kind: ProjectMemberKind) -> String {
    let form = rt.form();
    rt.session_mut()
        .invoke_member_values(form, member, Some(kind), Vec::new())
        .unwrap_or_else(|err| panic!("invoke {member}: {}", err.message()))
        .as_bstr()
        .map(|s| s.as_str())
        .unwrap_or_default()
}

fn read_string(rt: &mut OxRuntime, member: &str) -> String {
    invoke_string(rt, member, ProjectMemberKind::PropertyGet)
}

fn read_i32(rt: &mut OxRuntime, member: &str) -> i32 {
    let form = rt.form();
    rt.session_mut()
        .invoke_member_values(
            form,
            member,
            Some(ProjectMemberKind::PropertyGet),
            Vec::new(),
        )
        .unwrap_or_else(|err| panic!("read {member}: {}", err.message()))
        .as_i32()
        .unwrap_or_else(|| panic!("{member} should return a Long-compatible integer"))
}

fn read_bool(rt: &mut OxRuntime, member: &str) -> bool {
    let form = rt.form();
    rt.session_mut()
        .invoke_member_values(
            form,
            member,
            Some(ProjectMemberKind::PropertyGet),
            Vec::new(),
        )
        .unwrap_or_else(|err| panic!("read {member}: {}", err.message()))
        .as_bool()
        .unwrap_or_else(|| panic!("{member} should return a Boolean"))
}

fn assert_log_contains(log: &str, expected: &str) {
    assert!(
        log.lines().any(|line| line == expected),
        "showcase log missing {expected:?}; log was:\n{log}"
    );
}

#[test]
fn showcase_catalog_lists_current_live_surface_and_future_rows() {
    let (mut rt, surface) = attach_showcase();

    assert_eq!(
        read_i32(&mut rt, "ControlCount"),
        20,
        "the showcase renders live controls plus pending catalog rows"
    );

    let catalog = invoke_string(&mut rt, "SurfaceCatalog", ProjectMemberKind::Method);
    for live in [
        "LIVE UserForm",
        "LIVE Controls",
        "LIVE Label",
        "LIVE TextBox",
        "LIVE CommandButton",
        "LIVE CheckBox",
        "LIVE ListBox",
        "LIVE ComboBox",
        "LIVE Frame",
        "LIVE Image",
        "LIVE SpinButton",
    ] {
        assert!(
            catalog.contains(live),
            "catalog should include {live:?}; catalog was:\n{catalog}"
        );
    }
    assert!(
        catalog.contains("first-class InteractionManager diagnostics")
            && catalog.contains("accessibility snapshots"),
        "catalog should name the InteractionManager and accessibility diagnostic surfaces"
    );
    assert!(
        catalog.contains("LIVE TextBox: Text, Value, SelStart, SelLength, SelText, HideSelection")
            && catalog.contains("TextBoxDiagnostics"),
        "catalog should expose the representative TextBox property/diagnostic surface"
    );
    let textbox_diagnostics = read_string(&mut rt, "TextBoxDiagnostics");
    assert!(
        textbox_diagnostics.contains("text=;value=;sel_start=0;sel_length=0")
            && textbox_diagnostics.contains("capabilities=kind=TextBox")
            && textbox_diagnostics.contains(";text=True;paste=True;value=True")
            && textbox_diagnostics.contains(";accessibility=textbox/text,value,selection"),
        "TextBox diagnostics should carry value, selection, capability, and accessibility shape: {textbox_diagnostics}"
    );
    let accessibility = read_string(&mut rt, "AccessibilitySnapshot");
    assert!(
        accessibility.contains("role=form;name=full_surface_showcase")
            && accessibility.contains(
                "role=textbox;name=InputField;value=;enabled=True;visible=True;focused=True"
            )
            && accessibility
                .contains("role=checkbox;name=CheckBox;value=True;enabled=True;visible=True")
            && accessibility
                .contains("role=listbox;name=ChoicesList;value=Red;enabled=True;visible=True")
            && accessibility
                .contains("role=combobox;name=ChoiceCombo;value=Small;enabled=True;visible=True")
            && accessibility.contains("role=group;name=FrameGroup;value=Frame")
            && accessibility.contains("role=label;name=FrameLabel;value=Nested child")
            && accessibility.contains(
                "role=image;name=LogoImage;value=showcase-inline;enabled=True;visible=True"
            )
            && accessibility
                .contains("role=spinbutton;name=RepeatSpin;value=2;enabled=True;visible=True")
            && accessibility.contains(";patterns=selection,value;row_count=3;column_count=1"),
        "showcase should expose representative accessibility rows: {accessibility}"
    );
    let listbox_diagnostics = read_string(&mut rt, "ListBoxDiagnostics");
    assert!(
        listbox_diagnostics.contains("count=3;index=0;value=Red")
            && listbox_diagnostics.contains(";multiselect=0;selected=0;columns=1;bound_column=1;")
            && listbox_diagnostics.contains("rows=Red|Green|Blue")
            && listbox_diagnostics.contains("capabilities=kind=ListBox"),
        "ListBox diagnostics should expose list data and capability shape: {listbox_diagnostics}"
    );
    let combobox_diagnostics = read_string(&mut rt, "ComboBoxDiagnostics");
    assert!(
        combobox_diagnostics.contains("count=3;index=0;text=Small;value=Small;dropdown=False")
            && combobox_diagnostics.contains("rows=Small|Medium|Large")
            && combobox_diagnostics.contains("capabilities=kind=ComboBox"),
        "ComboBox diagnostics should expose editable value, list data, dropdown state, and capability shape: {combobox_diagnostics}"
    );
    let frame_diagnostics = read_string(&mut rt, "FrameDiagnostics");
    assert!(
        frame_diagnostics.contains("caption=Frame;children=1")
            && frame_diagnostics.contains("capabilities=kind=Frame"),
        "Frame diagnostics should expose container state: {frame_diagnostics}"
    );
    let image_diagnostics = read_string(&mut rt, "ImageDiagnostics");
    assert!(
        image_diagnostics.contains("picture=showcase-inline;offset=0")
            && image_diagnostics.contains(";handle=4242;")
            && image_diagnostics.contains("draw_mode=stretch")
            && image_diagnostics.contains("capabilities=kind=Image"),
        "Image diagnostics should expose picture identity, handle, mode, and capabilities: {image_diagnostics}"
    );
    let spin_diagnostics = read_string(&mut rt, "SpinButtonDiagnostics");
    assert!(
        spin_diagnostics.contains("value=2;min=0;max=9;small_change=1;pressed_direction=0")
            && spin_diagnostics.contains("capabilities=kind=SpinButton"),
        "SpinButton diagnostics should expose range, value, repeat state, and capabilities: {spin_diagnostics}"
    );
    for pending in ["ScrollBar", "MultiPage"] {
        assert!(
            catalog.contains(pending),
            "catalog should keep future control {pending:?} visible"
        );
    }
    assert!(
        catalog.contains("LIVE ToggleButton:"),
        "ToggleButton should be listed as live: {catalog}"
    );
    assert!(
        catalog.contains("LIVE OptionButton:"),
        "OptionButton should be listed as live: {catalog}"
    );
    assert!(
        !catalog.contains("PENDING OptionButton, ToggleButton"),
        "OptionButton, ToggleButton, Image, and ComboBox should be listed as live, not pending"
    );
    assert!(
        !catalog.contains("ScrollBar, SpinButton"),
        "SpinButton should be listed as live, not pending"
    );

    rt.render().expect("render showcase");
    let snap = surface.snapshot().expect("surface snapshot");
    assert_eq!(
        snap.node_count, 24,
        "root node plus 20 root controls, one Frame child, and the TextBox text/selection nodes should be resident"
    );
    assert!(
        snap.scene
            .as_ref()
            .expect("resident scene")
            .nodes
            .iter()
            .flat_map(|node| &node.prims)
            .any(|prim| matches!(
                prim,
                Prim::DrawImage {
                    image: ImageHandle(4242),
                    ..
                }
            )),
        "showcase Image should emit DrawImage with the expected opaque handle"
    );
}

#[test]
fn showcase_conformance_dashboard_rolls_up_runtime_surface_and_gaps() {
    let (mut rt, _surface) = attach_showcase();

    let dashboard = read_string(&mut rt, "ConformanceDashboard");
    for expected in [
        "OXFORMS_CONFORMANCE_DASHBOARD version=1",
        "runtime=OxRuntime/OxReducer/OxForms.Surface/Scene",
        "supported.controls=UserForm,Controls,Label,TextBox,CommandButton,CheckBox,OptionButton,ToggleButton,ListBox,ComboBox,Frame,Image,SpinButton",
        "supported.properties=TextBox.Text,TextBox.Value,TextBox.SelStart",
        "supported.methods=Controls.Add,Controls.Item,UserForm.Render,Dispatch,DispatchKey,DispatchChar,DispatchDrop,SetClipboardText,DispatchTimer,RunSelfTest",
        "supported.events=Initialize,Activate,Deactivate,Terminate,QueryClose,Enter,Exit,BeforeUpdate,AfterUpdate,Change,Click,MouseDown,MouseUp,KeyDown,KeyPress,KeyUp,BeforeDropOrPaste,DropButtonClick,SpinUp,SpinDown",
        "first=InputField;last=ChoiceCombo;default=OkButton;cancel=CancelButton;",
        "cursor=focus=InputField;capture=;pressed=;hover=InputField;cursor_target=InputField;cursor=3",
        "host.services=clipboard,text-dataobject,cursor,timer,dpi,metrics,colors,image-decode,drag-drop",
        "accessibility.snapshot=role=form;name=full_surface_showcase",
        "perf.report=docs/evidence/W009_first_class_runtime_foundation/perf/w009-ideal-architecture-budget-20260707.json",
        "top_followup=oxforms-bqr scaled-hit-test",
        "selftest=RunSelfTest returns PASS",
        "pending.controls=ScrollBar,TabStrip,MultiPage/Page",
    ] {
        assert!(
            dashboard.contains(expected),
            "dashboard should include {expected:?}; dashboard was:\n{dashboard}"
        );
    }
    assert!(
        !dashboard.contains("pending.controls=Frame"),
        "Frame is live and must not remain in pending rows: {dashboard}"
    );

    let supported = read_string(&mut rt, "SupportedSurfaceSummary");
    assert!(
        supported.contains("controls=UserForm,Controls,Label,TextBox,CommandButton,CheckBox,OptionButton,ToggleButton,ListBox,ComboBox,Frame,Image,SpinButton")
            && supported.contains("properties=Text,Value,SelStart,SelLength,SelText,HideSelection")
            && supported.contains("events=Initialize,Activate,Deactivate,Terminate,QueryClose"),
        "supported summary should list current controls/properties/events: {supported}"
    );

    let pending = read_string(&mut rt, "PendingSurfaceSummary");
    assert!(
        pending.contains("controls=ScrollBar,TabStrip,MultiPage/Page",)
            && pending.contains("scaled hit-test indexing"),
        "pending summary should keep future controls and follow-ups visible: {pending}"
    );

    let perf = read_string(&mut rt, "PerfBudgetSummary");
    assert!(
        perf.contains("representative_p95_us=32356")
            && perf.contains("scaled_hit_test_p95_100_controls_us=432473")
            && perf.contains("followup=oxforms-bqr"),
        "perf summary should point at the committed budget report and ranked follow-up: {perf}"
    );

    let selftest = read_string(&mut rt, "SelfTestSummary");
    assert!(
        selftest.contains("method=RunSelfTest;expected=PASS controls=20")
            && selftest.contains("coverage=Label/TextBox/CommandButton/CheckBox/OptionButton/ToggleButton/ListBox/ComboBox/Frame/Image/SpinButton/lifecycle"),
        "self-test summary should name the deterministic dashboard gate: {selftest}"
    );
}

#[test]
fn showcase_selftest_drives_current_methods_and_events() {
    let (mut rt, _surface) = attach_showcase();

    let result = invoke_string(&mut rt, "RunSelfTest", ProjectMemberKind::Method);
    assert!(
        result.starts_with("PASS controls=20;"),
        "self-test should report PASS, got {result:?}"
    );

    let log = read_string(&mut rt, "HandlerLog");
    for expected in [
        "SELFTEST.Begin",
        "UserForm.Initialize",
        "UserForm.Activate",
        "Label.MouseDown",
        "Label.MouseUp",
        "Label.Click",
        "Image.MouseDown",
        "Image.MouseUp",
        "Image.Click",
        "SpinButton.Enter",
        "SpinButton.MouseDown",
        "SpinButton.SpinUp=3",
        "SpinButton.Change=3",
        "SpinButton.MouseUp",
        "SpinButton.Exit",
        "TextBox.Enter",
        "TextBox.MouseDown",
        "TextBox.MouseUp",
        "TextBox.KeyDown:65",
        "TextBox.KeyPress:97",
        "TextBox.Change",
        "TextBox.KeyUp:65",
        "TextBox.BeforeDropOrPaste:2",
        "TextBox.BeforeUpdate",
        "TextBox.AfterUpdate",
        "TextBox.Exit",
        "CommandButton.Enter",
        "CommandButton.Click",
        "CommandButton.KeyDown:66",
        "CommandButton.KeyPress:98",
        "CommandButton.KeyUp:66",
        "CommandButton.MouseDown",
        "CommandButton.MouseUp",
        "CommandButton.Exit",
        "CheckBox.Enter",
        "CheckBox.MouseDown",
        "CheckBox.MouseUp",
        "CheckBox.Change=True",
        "CheckBox.Click=True",
        "CheckBox.Change=False",
        "CheckBox.Click=False",
        "CheckBox.KeyDown:32",
        "CheckBox.KeyUp:32",
        "CheckBox.KeyPress:99",
        "CheckBox.BeforeUpdate",
        "CheckBox.AfterUpdate",
        "CheckBox.Exit",
        "ToggleButton.Enter",
        "ToggleButton.MouseDown",
        "ToggleButton.MouseUp",
        "ToggleButton.Change=False",
        "ToggleButton.Click=False",
        "ToggleButton.Change=True",
        "ToggleButton.Click=True",
        "ToggleButton.KeyDown:32",
        "ToggleButton.KeyUp:32",
        "ToggleButton.KeyPress:116",
        "ToggleButton.BeforeUpdate",
        "ToggleButton.AfterUpdate",
        "ToggleButton.Exit",
        "OptionButton.Enter",
        "OptionButton.MouseDown",
        "OptionButton.MouseUp",
        "OptionButton.Click=True",
        "OptionButton.Click=True",
        "OptionButton.KeyDown:32",
        "OptionButton.KeyUp:32",
        "OptionButton.KeyPress:111",
        "OptionButton.Exit",
        "ListBox.Enter",
        "ListBox.MouseDown",
        "ListBox.Change:Green",
        "ListBox.MouseUp",
        "ListBox.Click:Green",
        "ListBox.KeyDown:40",
        "ListBox.Change:Blue",
        "ListBox.KeyUp:40",
        "ListBox.KeyPress:108",
        "ListBox.BeforeUpdate",
        "ListBox.AfterUpdate",
        "ListBox.Exit",
        "ComboBox.Enter",
        "ComboBox.MouseDown",
        "ComboBox.DropButtonClick",
        "ComboBox.MouseUp",
        "ComboBox.Click:Small",
        "ComboBox.KeyDown:40",
        "ComboBox.Change:Medium",
        "ComboBox.KeyUp:40",
        "ComboBox.KeyPress:120",
        "ComboBox.Change:Mediumx",
        "ComboBox.BeforeUpdate",
        "ComboBox.AfterUpdate",
        "ComboBox.Exit",
        "CancelButton.Click",
        "AcceleratorButton.Enter",
        "AcceleratorButton.Click",
        "UserForm.Deactivate",
        "UserForm.QueryClose:1",
        "UserForm.Terminate",
        "SELFTEST.Pass",
    ] {
        assert_log_contains(&log, expected);
    }

    assert_eq!(
        read_string(&mut rt, "InputText"),
        "a PASTE DROP",
        "TextBox user edit, paste, and drop should all be visible in form state"
    );
    assert!(
        !read_bool(&mut rt, "CheckValue"),
        "CheckBox toggled by mouse then keyboard should end unchecked"
    );
    assert!(
        read_bool(&mut rt, "ToggleValue"),
        "ToggleButton toggled by mouse then keyboard should end checked"
    );
    assert!(
        read_string(&mut rt, "StatusCaption").contains("Self-test pass"),
        "status label should show the deterministic proof result"
    );

    rt.render().expect("render after self-test");
}
