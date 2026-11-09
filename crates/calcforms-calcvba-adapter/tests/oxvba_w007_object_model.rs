//! W007 VBA object-model slice (oxforms-4pn.3).
//!
//! Proves the CalcForms VBA control object model compiles and runs on CalcVBA and
//! supports the W007 demo shape end to end, with no custom callback API:
//!
//! - controls are created the Forms 2.0 way, through `Controls.Add` by ProgID;
//! - typed properties (Caption/Text/geometry) round-trip through OxControlCore;
//! - native control events (Change, Click) reach ordinary VBA handlers via
//!   WithEvents, and the handler reads TextBox.Text and sets Label.Caption;
//! - the mutable-helper pattern (ReturnInteger) round-trips through KeyDown;
//! - the runtime can reach every control uniformly through IOxControl.Core and
//!   observe dirty/invalidation state for repaint scheduling.

use std::path::{Path, PathBuf};

use calcvba_bundle::ProjectMemberKind;
use calcvba_engine::{Engine, HostConfig};
use calcvba_hal::model::HostPolicy;
use calcvba_runtime::{ObjectRef, Variant};
use calcvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

const OX_CONTROL_LABEL: i32 = 0;

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..").join("..")
}

fn read_source(relative: &str) -> String {
    let path = repo_root().join(relative);
    std::fs::read_to_string(&path).unwrap_or_else(|err| panic!("read {}: {err}", path.display()))
}

fn module_unit(name: &str, kind: ModuleKind, relative: &str) -> ModuleUnit {
    let mut attributes = ModuleAttributes::named(name);
    attributes.vb_exposed = true;
    attributes.vb_creatable = true;
    ModuleUnit {
        module_name: name.to_string(),
        module_kind: kind,
        attributes,
        source: read_source(relative),
    }
}

fn project_manifest() -> SymbolProjectManifest {
    SymbolProjectManifest {
        project_name: "W007ObjectModel".to_string(),
        project_kind: ProjectKind::Library,
        modules: vec![
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
                "W007ObjectModelProbeForm",
                ModuleKind::Class,
                "vba/smoke/fixtures/w007_object_model_probe_form.cls",
            ),
        ],
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
        conditional_compilation_target: Default::default(),
    }
}

fn prepare_session() -> calcvba_engine::ProjectRuntimeSession {
    let manifest = project_manifest();
    let program = calcvba_bind::bind_program(&manifest, &calcvba_symbol::CatalogTypeLibResolver)
        .expect("bind CalcForms object-model project");
    let bundle = calcvba_oxir::elaborate::elaborate(&program)
        .expect("elaborate CalcForms object-model project");

    let mut engine = Engine::new(HostConfig::vm3());
    engine.set_host_policy(HostPolicy::native());
    engine
        .prepare_image_session(calcvba_oxir::OxImage::new(vec![bundle]))
        .expect("prepare CalcForms object-model session")
}

fn call(
    session: &mut calcvba_engine::ProjectRuntimeSession,
    object: ObjectRef,
    member: &str,
    kind: ProjectMemberKind,
    args: Vec<Variant>,
) -> Variant {
    session
        .invoke_member_values(object, member, Some(kind), args)
        .unwrap_or_else(|err| panic!("invoke {member}: {}", err.message()))
}

fn get_string(
    session: &mut calcvba_engine::ProjectRuntimeSession,
    object: ObjectRef,
    member: &str,
) -> String {
    call(
        session,
        object,
        member,
        ProjectMemberKind::PropertyGet,
        Vec::new(),
    )
    .as_bstr()
    .unwrap_or_else(|| panic!("{member} should return a string"))
    .as_str()
}

fn get_object(
    session: &mut calcvba_engine::ProjectRuntimeSession,
    object: ObjectRef,
    member: &str,
    args: Vec<Variant>,
    kind: ProjectMemberKind,
) -> ObjectRef {
    call(session, object, member, kind, args)
        .as_object_ref()
        .unwrap_or_else(|| panic!("{member} should return an object"))
}

#[test]
fn host_created_form_keeps_its_control_collection_between_calls() {
    let mut session = prepare_session();
    let form = session.create_class_instance("UserForm").expect("new form");
    let direct = session.create_class_instance("Label").expect("new label");
    let core = get_object(
        &mut session,
        direct.clone(),
        "Core",
        vec![],
        ProjectMemberKind::PropertyGet,
    );
    call(
        &mut session,
        core,
        "Name",
        ProjectMemberKind::PropertyLet,
        vec![Variant::from_string("DirectLabel")],
    );
    let controls = get_object(
        &mut session,
        form.clone(),
        "Controls",
        vec![],
        ProjectMemberKind::PropertyGet,
    );
    let count = call(
        &mut session,
        controls.clone(),
        "Count",
        ProjectMemberKind::PropertyGet,
        vec![],
    );
    assert_eq!(count.as_i32(), Some(0));
    let label = get_object(
        &mut session,
        controls,
        "Add",
        vec![
            Variant::from_string("Forms.Label.1"),
            Variant::from_string("Label1"),
        ],
        ProjectMemberKind::Method,
    );
    call(
        &mut session,
        label,
        "Caption",
        ProjectMemberKind::PropertyLet,
        vec![Variant::from_string("loaded")],
    );
    let count = call(
        &mut session,
        form,
        "Count",
        ProjectMemberKind::PropertyGet,
        vec![],
    );
    assert_eq!(count.as_i32(), Some(1));
}

#[test]
fn object_model_supports_the_w007_demo_shape() {
    let mut session = prepare_session();
    let form = session
        .create_class_instance("W007ObjectModelProbeForm")
        .expect("create probe form");

    call(
        &mut session,
        form.clone(),
        "Build",
        ProjectMemberKind::Method,
        Vec::new(),
    );

    // A user edit raises Change through the same sink as programmatic Text changes.
    call(
        &mut session,
        form.clone(),
        "TypeIntoInput",
        ProjectMemberKind::Method,
        vec![Variant::from_string("World")],
    );

    // KeyDown carries a mutable ReturnInteger: the handler swallows Escape (27 -> 0)
    // and leaves an ordinary key untouched. The post-handler value round-trips back.
    let escape = call(
        &mut session,
        form.clone(),
        "SendInputKeyDown",
        ProjectMemberKind::Method,
        vec![Variant::from_i16(27), Variant::from_i16(0)],
    )
    .as_i16()
    .expect("SendInputKeyDown should return an integer");
    assert_eq!(
        escape, 0,
        "handler should swallow Escape via ReturnInteger.Value"
    );

    let letter = call(
        &mut session,
        form.clone(),
        "SendInputKeyDown",
        ProjectMemberKind::Method,
        vec![Variant::from_i16(65), Variant::from_i16(0)],
    )
    .as_i16()
    .expect("SendInputKeyDown should return an integer");
    assert_eq!(
        letter, 65,
        "non-swallowed KeyDown returns the original key code"
    );

    // Clicking OK runs the native VBA Click handler, which reads TextBox.Text and
    // sets Label.Caption -- the exact W007 demo behavior.
    call(
        &mut session,
        form.clone(),
        "ClickOk",
        ProjectMemberKind::Method,
        Vec::new(),
    );

    // Native FM20 [Exit] event (a reserved word) round-trips a mutable Cancel: arm the
    // veto (off by default since oxforms-esq.11) so the handler sets Cancel.Value = True
    // and the control returns it.
    call(
        &mut session,
        form.clone(),
        "ArmExitVeto",
        ProjectMemberKind::Method,
        Vec::new(),
    );
    let cancelled = call(
        &mut session,
        form.clone(),
        "SendInputExit",
        ProjectMemberKind::Method,
        Vec::new(),
    )
    .as_bool()
    .expect("SendInputExit should return a boolean");
    assert!(
        cancelled,
        "the native [Exit] handler should cancel via ReturnBoolean"
    );

    assert_eq!(
        get_string(&mut session, form.clone(), "OutputCaption"),
        "Hello, World",
        "Click handler should derive the label caption from the typed text"
    );

    let log = get_string(&mut session, form.clone(), "Log");
    assert_eq!(
        log.lines().collect::<Vec<_>>(),
        vec![
            "InputField_Change=World",
            "InputField_KeyDown=27;Shift=0",
            "InputField_KeyDown=65;Shift=0",
            "OkButton_Click",
            "InputField_Exit",
        ],
        "native control events should reach the VBA handlers in order"
    );

    // The runtime reaches controls uniformly through the form + IOxControl.Core.
    let form_obj = get_object(
        &mut session,
        form.clone(),
        "Form",
        Vec::new(),
        ProjectMemberKind::PropertyGet,
    );
    let count = call(
        &mut session,
        form_obj.clone(),
        "Count",
        ProjectMemberKind::PropertyGet,
        Vec::new(),
    )
    .as_i32()
    .expect("Count should be an integer");
    assert_eq!(count, 3, "three controls were added to the form");

    let label = get_object(
        &mut session,
        form_obj,
        "ControlByName",
        vec![Variant::from_string("OutputLabel")],
        ProjectMemberKind::Method,
    );
    let core = get_object(
        &mut session,
        label,
        "Core",
        Vec::new(),
        ProjectMemberKind::PropertyGet,
    );

    assert_eq!(
        call(
            &mut session,
            core.clone(),
            "Kind",
            ProjectMemberKind::PropertyGet,
            Vec::new()
        )
        .as_i32()
        .expect("Kind should be an integer"),
        OX_CONTROL_LABEL,
        "OutputLabel reports the label kind through the uniform core"
    );
    assert_eq!(
        get_string(&mut session, core.clone(), "DisplayText"),
        "Hello, World",
        "the label's generic DisplayText reflects the caption the handler set"
    );
    assert!(
        call(
            &mut session,
            core,
            "Dirty",
            ProjectMemberKind::PropertyGet,
            Vec::new()
        )
        .as_bool()
        .expect("Dirty should be a boolean"),
        "setting the caption should mark the control dirty for repaint"
    );
}

#[test]
fn current_procedure_host_runs_vba_controls() {
    let mut manifest = project_manifest();
    manifest.modules.push(ModuleUnit {
        module_name: "HostProbe".into(), module_kind: ModuleKind::Procedural,
        attributes: ModuleAttributes::named("HostProbe"),
        source: "Public Function Run() As String\nDim label As New Label\nlabel.Caption = \"host\"\nRun = label.Caption\nEnd Function\n".into(),
    });
    let module =
        calcvba_host::Module::load_project(&manifest, &calcvba_symbol::CatalogTypeLibResolver)
            .expect("load current host");
    let session = module
        .into_session(calcvba_host::Backend::Interpreter)
        .expect("host session");
    let run = session
        .bind("HostProbe", "Run", calcvba_host::ProcedureKind::Function)
        .expect("bind entry");
    let result = session
        .call_bound(&run, &[], 1_000_000)
        .expect("run VBA controls through current host");
    assert_eq!(result.as_bstr().expect("caption").as_str(), "host");
}
