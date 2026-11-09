//! Runtime integration on the VBA-reducer design (oxforms-ih6.7): the thin `OxRuntime` drives a
//! W007 greeter form-document end to end through `OxReducer` -- the runtime half of the pivot, with
//! NO `calcforms-core` reducer. This is the replacement for the old `calcvba_w007_runtime_runner` +
//! lifecycle coverage; control-interaction ORDERINGS are pinned by the `calcvba_reducer_cmdbutton`
//! suite, so this proves the runtime wiring + the W007 demo flow + form lifecycle/QueryClose.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use calcforms_calcvba_adapter::runtime::{OxRuntime, RuntimeInput, RuntimeMouseKind};
use calcforms_calcvba_adapter::surface::{register_surface, SurfaceFactory};
use calcforms_pal::scene::StubShaper;

use calcvba_bundle::ProjectMemberKind;
use calcvba_com::PortableComProjection;
use calcvba_engine::{Engine, HostConfig, HostProfileProvider, ProjectRuntimeSession};
use calcvba_hal::model::HostPolicy;
use calcvba_symbol::manifest::{
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

fn build_session() -> ProjectRuntimeSession {
    let modules = vec![
        module_unit(
            "CalcFormsModel",
            ModuleKind::Procedural,
            "vba/calcforms/CalcFormsModel.bas",
        ),
        module_unit(
            "IOxControl",
            ModuleKind::Class,
            "vba/calcforms/IOxControl.cls",
        ),
        module_unit(
            "IOxControlHost",
            ModuleKind::Class,
            "vba/calcforms/IOxControlHost.cls",
        ),
        module_unit(
            "IOxControlContainer",
            ModuleKind::Class,
            "vba/calcforms/IOxControlContainer.cls",
        ),
        module_unit(
            "OxControlCore",
            ModuleKind::Class,
            "vba/calcforms/OxControlCore.cls",
        ),
        module_unit("Controls", ModuleKind::Class, "vba/calcforms/Controls.cls"),
        module_unit(
            "ReturnInteger",
            ModuleKind::Class,
            "vba/calcforms/ReturnInteger.cls",
        ),
        module_unit(
            "ReturnBoolean",
            ModuleKind::Class,
            "vba/calcforms/ReturnBoolean.cls",
        ),
        module_unit("Font", ModuleKind::Class, "vba/calcforms/Font.cls"),
        module_unit("Label", ModuleKind::Class, "vba/calcforms/Label.cls"),
        module_unit(
            "OxTextService",
            ModuleKind::Class,
            "vba/calcforms/OxTextService.cls",
        ),
        module_unit("TextBox", ModuleKind::Class, "vba/calcforms/TextBox.cls"),
        module_unit(
            "CommandButton",
            ModuleKind::Class,
            "vba/calcforms/CommandButton.cls",
        ),
        module_unit("CheckBox", ModuleKind::Class, "vba/calcforms/CheckBox.cls"),
        module_unit("ListBox", ModuleKind::Class, "vba/calcforms/ListBox.cls"),
        module_unit("ComboBox", ModuleKind::Class, "vba/calcforms/ComboBox.cls"),
        module_unit("Frame", ModuleKind::Class, "vba/calcforms/Frame.cls"),
        module_unit("Image", ModuleKind::Class, "vba/calcforms/Image.cls"),
        module_unit(
            "SpinButton",
            ModuleKind::Class,
            "vba/calcforms/SpinButton.cls",
        ),
        module_unit(
            "ScrollBar",
            ModuleKind::Class,
            "vba/calcforms/ScrollBar.cls",
        ),
        module_unit("Tab", ModuleKind::Class, "vba/calcforms/Tab.cls"),
        module_unit("Tabs", ModuleKind::Class, "vba/calcforms/Tabs.cls"),
        module_unit("TabStrip", ModuleKind::Class, "vba/calcforms/TabStrip.cls"),
        module_unit(
            "MultiPage",
            ModuleKind::Class,
            "vba/calcforms/MultiPage.cls",
        ),
        module_unit("Page", ModuleKind::Class, "vba/calcforms/Page.cls"),
        module_unit("Pages", ModuleKind::Class, "vba/calcforms/Pages.cls"),
        module_unit(
            "ToggleButton",
            ModuleKind::Class,
            "vba/calcforms/ToggleButton.cls",
        ),
        module_unit(
            "OptionButtonControl",
            ModuleKind::Class,
            "vba/calcforms/OptionButtonControl.cls",
        ),
        module_unit("UserForm", ModuleKind::Class, "vba/calcforms/UserForm.cls"),
        module_unit(
            "OxTheme",
            ModuleKind::Procedural,
            "vba/calcforms/OxTheme.bas",
        ),
        module_unit(
            "OxControlPaint",
            ModuleKind::Procedural,
            "vba/calcforms/OxControlPaint.bas",
        ),
        module_unit(
            "OxSceneBuilder",
            ModuleKind::Class,
            "vba/calcforms/OxSceneBuilder.cls",
        ),
        module_unit(
            "OxAccessibilityService",
            ModuleKind::Class,
            "vba/calcforms/OxAccessibilityService.cls",
        ),
        module_unit(
            "OxInteractionManager",
            ModuleKind::Class,
            "vba/calcforms/OxInteractionManager.cls",
        ),
        module_unit(
            "OxReducer",
            ModuleKind::Class,
            "vba/calcforms/OxReducer.cls",
        ),
        module_unit(
            "ReducerGreeterForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_greeter_form.cls",
        ),
    ];

    let manifest = SymbolProjectManifest {
        project_name: "RuntimeGreeter".to_string(),
        project_kind: ProjectKind::Library,
        modules,
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
        conditional_compilation_target: Default::default(),
    };

    let program = calcvba_bind::bind_program(&manifest, &calcvba_symbol::CatalogTypeLibResolver)
        .expect("bind greeter project");
    let bundle = calcvba_oxir::elaborate::elaborate(&program).expect("elaborate greeter project");

    let projection = Arc::new(PortableComProjection::new());
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(StubShaper)));
    register_surface(&projection, surface);

    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::native());
    let engine = Engine::new(HostConfig::vm3()).with_host_profile_provider(profile);
    engine
        .prepare_image_session(calcvba_oxir::OxImage::new(vec![bundle]))
        .expect("prepare greeter session")
}

fn read_string(rt: &mut OxRuntime, member: &str) -> String {
    let form = rt.form();
    rt.session_mut()
        .invoke_member_values(
            form,
            member,
            Some(ProjectMemberKind::PropertyGet),
            Vec::new(),
        )
        .unwrap_or_else(|err| panic!("read {member}: {}", err.message()))
        .as_bstr()
        .map(|s| s.as_str())
        .unwrap_or_default()
}

#[test]
fn oxruntime_drives_the_w007_greeter_demo_through_the_vba_reducer() {
    let mut rt =
        OxRuntime::attach(build_session(), "ReducerGreeterForm", "Build").expect("attach greeter");

    // Focus the input (click) and type "World" (a user edit -> dirty).
    rt.dispatch_event_turn(RuntimeInput::Mouse {
        kind: RuntimeMouseKind::Down,
        x: 40,
        y: 20,
        button: 1,
        shift: 0,
    })
    .unwrap();
    rt.dispatch_event_turn(RuntimeInput::Mouse {
        kind: RuntimeMouseKind::Up,
        x: 40,
        y: 20,
        button: 1,
        shift: 0,
    })
    .unwrap();
    let typed = rt
        .dispatch_event_turn(RuntimeInput::CharacterInput("World".to_string()))
        .unwrap();
    assert!(
        typed.repainted,
        "character input should repaint in the same turn"
    );
    assert_eq!(read_string(&mut rt, "InputText"), "World");

    // Click OK: focus leaves the dirty input (validation commits), then OkButton_Click reads the
    // text and sets the label -- the W007 demo flow, all in VBA.
    rt.dispatch_event_turn(RuntimeInput::Mouse {
        kind: RuntimeMouseKind::Down,
        x: 170,
        y: 20,
        button: 1,
        shift: 0,
    })
    .unwrap();
    rt.dispatch_event_turn(RuntimeInput::Mouse {
        kind: RuntimeMouseKind::Up,
        x: 170,
        y: 20,
        button: 1,
        shift: 0,
    })
    .unwrap();
    assert_eq!(
        read_string(&mut rt, "OutputCaption"),
        "Hello, World",
        "the VBA OK Click handler derived the label from the typed text"
    );

    // The runtime can self-render the form (VBA self-render across CalcForms.Surface).
    rt.render().expect("render");
}

#[test]
fn oxruntime_routes_form_lifecycle_and_queryclose() {
    let mut rt =
        OxRuntime::attach(build_session(), "ReducerGreeterForm", "Build").expect("attach greeter");

    rt.perform("PerformInitialize").unwrap();
    rt.perform("PerformActivate").unwrap();
    rt.perform("PerformDeactivate").unwrap();
    rt.perform("PerformTerminate").unwrap();
    assert_eq!(
        read_string(&mut rt, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec![
            "UserForm_Initialize",
            "UserForm_Activate",
            "UserForm_Deactivate",
            "UserForm_Terminate",
        ],
        "lifecycle events route to the form-document handlers in order"
    );

    // QueryClose: a control-menu close (CloseMode 0) is vetoed (-1); a code Unload (1) is allowed.
    assert_eq!(rt.perform_query_close(0).unwrap(), -1, "menu close vetoed");
    assert_eq!(rt.perform_query_close(1).unwrap(), 0, "code unload allowed");
}
