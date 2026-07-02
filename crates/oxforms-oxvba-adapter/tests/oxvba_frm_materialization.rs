//! Representative W009 `.frm/.frx` materialization proof.
//!
//! This test pins the direction of `oxforms-zhz.22`: a selected `.frm` slice is parsed by VBA and
//! materialized directly into the live `UserForm`/`Controls.Add` object model. It deliberately does
//! not resurrect the deleted Rust-side RuntimeForm/ControlNode projection.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use oxforms_oxvba_adapter::surface::{register_surface, SurfaceFactory};
use oxforms_pal::scene::StubShaper;

use oxvba_bundle::ProjectMemberKind;
use oxvba_com::PortableComProjection;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, HostProfileProvider, ProjectRuntimeSession};
use oxvba_runtime::{ObjectRef, Variant};
use oxvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

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

fn prepare_session() -> (ProjectRuntimeSession, Arc<SurfaceFactory>) {
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
        module_unit(
            "OxAccessibilityService",
            ModuleKind::Class,
            "vba/oxforms/OxAccessibilityService.cls",
        ),
        module_unit(
            "OxFrmMaterializer",
            ModuleKind::Class,
            "vba/oxforms/OxFrmMaterializer.cls",
        ),
        module_unit(
            "FrmMaterializationProbeForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/frm_materialization_probe_form.cls",
        ),
    ];

    let manifest = SymbolProjectManifest {
        project_name: "FrmMaterialization".to_string(),
        project_kind: ProjectKind::Library,
        modules,
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
    };

    let program = oxvba_bind::bind_program(&manifest, &oxvba_symbol::CatalogTypeLibResolver)
        .expect("bind materialization project");
    let bundle =
        oxvba_oxir::elaborate::elaborate(&program).expect("elaborate materialization project");

    let projection = Arc::new(PortableComProjection::new());
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(StubShaper)));
    register_surface(&projection, surface.clone());

    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::interactive_dev());
    let engine = Engine::new(HostConfig { enable_jit: false }).with_host_profile_provider(profile);
    let session = engine
        .prepare_image_session(oxvba_oxir::OxImage::new(vec![bundle]))
        .expect("prepare materialization session");
    (session, surface)
}

fn call(
    session: &mut ProjectRuntimeSession,
    object: ObjectRef,
    member: &str,
    kind: ProjectMemberKind,
    args: Vec<Variant>,
) -> Variant {
    session
        .invoke_member_values(object, member, Some(kind), args)
        .unwrap_or_else(|err| panic!("invoke {member}: {}", err.message()))
}

fn read_string(session: &mut ProjectRuntimeSession, object: &ObjectRef, member: &str) -> String {
    call(
        session,
        object.clone(),
        member,
        ProjectMemberKind::PropertyGet,
        Vec::new(),
    )
    .as_bstr()
    .map(|s| s.as_str())
    .unwrap_or_default()
}

fn read_i32(session: &mut ProjectRuntimeSession, object: &ObjectRef, member: &str) -> i32 {
    call(
        session,
        object.clone(),
        member,
        ProjectMemberKind::PropertyGet,
        Vec::new(),
    )
    .as_i32()
    .unwrap_or_else(|| panic!("{member} should return a Long-compatible integer"))
}

fn assert_line_contains(haystack: &str, expected: &str) {
    assert!(
        haystack.lines().any(|line| line.contains(expected)),
        "expected line containing {expected:?}; text was:\n{haystack}"
    );
}

#[test]
fn representative_frm_materializes_into_live_vba_object_model() {
    let (mut session, surface) = prepare_session();
    let form = session
        .create_class_instance("FrmMaterializationProbeForm")
        .expect("create materialization probe");
    let frm_text = read_source("fixtures/frm/w009-materialization/w009-representative.frm");

    call(
        &mut session,
        form.clone(),
        "BuildFromText",
        ProjectMemberKind::Method,
        vec![Variant::from_string(frm_text.as_str())],
    );

    assert_eq!(
        read_i32(&mut session, &form, "ControlCount"),
        5,
        "Image is intentionally recorded as .frx metadata until the Image lane lands"
    );

    let catalog = read_string(&mut session, &form, "MaterializationCatalog");
    assert!(
        catalog.contains(
            "form;name=W009MaterializationForm;caption=W009 Materialized Form;width=260;height=190;controls=5"
        ),
        "form row should reflect live UserForm properties:\n{catalog}"
    );
    assert_line_contains(
        &catalog,
        "control;name=TitleLabel;role=label;value=Materialized label;left=12;top=10;width=180;height=18",
    );
    assert_line_contains(
        &catalog,
        "control;name=TitleLabel;role=label;value=Materialized label;left=12;top=10;width=180;height=18;enabled=True;visible=True;tabindex=0;tabstop=False;backcolor=12611616;forecolor=16777215;borderstyle=1",
    );
    assert_line_contains(
        &catalog,
        "control;name=InputField;role=textbox;value=seed;left=12;top=38;width=110;height=21;enabled=True;visible=True;tabindex=0;tabstop=True",
    );
    assert_line_contains(
        &catalog,
        "control;name=DefaultButton;role=button;value=&OK;left=135;top=38;width=45;height=21;enabled=True;visible=True;tabindex=1;tabstop=True",
    );
    assert_line_contains(&catalog, "default=True;cancel=False");
    assert_line_contains(
        &catalog,
        "control;name=CancelButton;role=button;value=Cancel;left=186;top=38;width=48;height=21;enabled=True;visible=True;tabindex=2;tabstop=True",
    );
    assert_line_contains(&catalog, "default=False;cancel=True");
    assert_line_contains(
        &catalog,
        "control;name=AcceptCheck;role=checkbox;value=True;left=12;top=70;width=110;height=21;enabled=True;visible=True;tabindex=3;tabstop=True;backcolor=16777215;forecolor=0",
    );

    let frx_refs = read_string(&mut session, &form, "FrxReferences");
    assert_line_contains(
        &frx_refs,
        "control=LogoImage;property=Picture;path=w009-representative.frx;offset=0",
    );
    let unsupported = read_string(&mut session, &form, "UnsupportedControls");
    assert_line_contains(&unsupported, "control=LogoImage;type=MSForms.Image");
    let image_metadata = read_string(&mut session, &form, "ImageMetadata");
    assert_line_contains(
        &image_metadata,
        "image;name=LogoImage;left=160;top=122;width=32;height=24;picture_path=w009-representative.frx;picture_offset=0",
    );

    let frx = std::fs::read(
        repo_root().join("fixtures/frm/w009-materialization/w009-representative.frx"),
    )
    .expect("read representative .frx");
    assert!(
        frx.starts_with(b"OXFORMS-W009-FRX-STUB"),
        ".frx fixture should carry non-empty representative binary bytes"
    );

    call(
        &mut session,
        form.clone(),
        "Render",
        ProjectMemberKind::Method,
        Vec::new(),
    );
    let snap = surface.snapshot().expect("surface snapshot");
    assert_eq!(
        snap.node_count, 8,
        "root plus five materialized controls plus TextBox text/selection nodes should be resident"
    );

    let accessibility = read_string(&mut session, &form, "AccessibilitySnapshot");
    assert!(
        accessibility.contains("role=form;name=W009MaterializationForm")
            && accessibility.contains("role=textbox;name=InputField;value=seed")
            && accessibility.contains("role=checkbox;name=AcceptCheck;value=True"),
        "materialized form should project accessibility from the live object model:\n{accessibility}"
    );
}
