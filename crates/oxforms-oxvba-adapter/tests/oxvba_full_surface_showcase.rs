//! Living full-surface showcase proof. The VBA fixture renders the current intrinsic surface
//! (Label, TextBox, CommandButton, CheckBox), lists future FM20 controls as pending rows, and
//! exposes `RunSelfTest` so the supported method/event surface can be proven without launching a
//! desktop window.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use oxforms_oxvba_adapter::runtime::OxRuntime;
use oxforms_oxvba_adapter::surface::{register_surface, SurfaceFactory};
use oxforms_pal::scene::StubShaper;

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
        13,
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
    ] {
        assert!(
            catalog.contains(live),
            "catalog should include {live:?}; catalog was:\n{catalog}"
        );
    }
    for pending in [
        "OptionButton",
        "ToggleButton",
        "ComboBox",
        "ListBox",
        "MultiPage",
    ] {
        assert!(
            catalog.contains(pending),
            "catalog should keep future control {pending:?} visible"
        );
    }

    rt.render().expect("render showcase");
    let snap = surface.snapshot().expect("surface snapshot");
    assert_eq!(
        snap.node_count, 16,
        "root node plus 13 current showcase controls plus the TextBox text and selection overlay nodes should be resident"
    );
}

#[test]
fn showcase_selftest_drives_current_methods_and_events() {
    let (mut rt, _surface) = attach_showcase();

    let result = invoke_string(&mut rt, "RunSelfTest", ProjectMemberKind::Method);
    assert!(
        result.starts_with("PASS controls=13;"),
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
        read_string(&mut rt, "StatusCaption").contains("Self-test pass"),
        "status label should show the deterministic proof result"
    );

    rt.render().expect("render after self-test");
}
