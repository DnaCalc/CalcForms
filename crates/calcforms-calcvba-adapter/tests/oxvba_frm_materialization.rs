//! Representative W009 `.frm/.frx` materialization proof.
//!
//! This test pins the direction of `oxforms-zhz.22`: a selected `.frm` slice is parsed by VBA and
//! materialized directly into the live `UserForm`/`Controls.Add` object model. It deliberately does
//! not resurrect the deleted Rust-side RuntimeForm/ControlNode projection.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use calcforms_calcvba_adapter::host_services::HostServices;
use calcforms_calcvba_adapter::surface::{register_surface, SurfaceFactory};
use calcforms_pal::scene::{render_headless_report, ImageHandle, ImageMode, Prim, StubShaper};

use calcvba_bundle::ProjectMemberKind;
use calcvba_com::PortableComProjection;
use calcvba_engine::{Engine, HostConfig, HostProfileProvider, ProjectRuntimeSession};
use calcvba_hal::model::HostPolicy;
use calcvba_runtime::{ObjectRef, Variant};
use calcvba_symbol::manifest::{
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
            "OxFrmMaterializer",
            ModuleKind::Class,
            "vba/calcforms/OxFrmMaterializer.cls",
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
        conditional_compilation_target: Default::default(),
    };

    let program = calcvba_bind::bind_program(&manifest, &calcvba_symbol::CatalogTypeLibResolver)
        .expect("bind materialization project");
    let bundle =
        calcvba_oxir::elaborate::elaborate(&program).expect("elaborate materialization project");

    let projection = Arc::new(PortableComProjection::new());
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(StubShaper)));
    register_surface(&projection, surface.clone());

    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::native());
    let engine = Engine::new(HostConfig::vm3()).with_host_profile_provider(profile);
    let session = engine
        .prepare_image_session(calcvba_oxir::OxImage::new(vec![bundle]))
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
        14,
        "OptionButton, ListBox, ComboBox, ToggleButton, Image, SpinButton, ScrollBar, TabStrip, and MultiPage now materialize as live VBA controls"
    );

    let catalog = read_string(&mut session, &form, "MaterializationCatalog");
    assert!(
        catalog.contains(
            "form;name=W009MaterializationForm;caption=W009 Materialized Form;width=260;height=190;controls=14"
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
    assert_line_contains(
        &catalog,
        "control;name=ModeToggle;role=togglebutton;value=True;left=135;top=70;width=60;height=21;enabled=True;visible=True;tabindex=4;tabstop=True",
    );
    assert_line_contains(
        &catalog,
        "control;name=ModeOption;role=radio;value=True;left=135;top=95;width=60;height=21;enabled=True;visible=True;tabindex=5;tabstop=True",
    );
    assert_line_contains(
        &catalog,
        "control;name=ChoicesList;role=listbox;value=;left=12;top=122;width=110;height=42;enabled=True;visible=True;tabindex=6;tabstop=True",
    );
    assert_line_contains(
        &catalog,
        "control;name=LogoImage;role=image;value=w009-representative.frx;left=160;top=122;width=32;height=24;enabled=True;visible=True;tabindex=0;tabstop=False",
    );
    assert_line_contains(
        &catalog,
        "control;name=SizeCombo;role=combobox;value=Medium;left=135;top=160;width=80;height=21;enabled=True;visible=True;tabindex=7;tabstop=True",
    );
    assert_line_contains(
        &catalog,
        "control;name=CountSpin;role=spinbutton;value=3;left=225;top=160;width=21;height=42;enabled=True;visible=True;tabindex=8;tabstop=True",
    );
    assert_line_contains(
        &catalog,
        "control;name=AmountScroll;role=scrollbar;value=25;left=12;top=168;width=110;height=16;enabled=True;visible=True;tabindex=9;tabstop=True",
    );
    assert_line_contains(
        &catalog,
        "control;name=ModeTabs;role=tabstrip;value=;left=12;top=188;width=110;height=32;enabled=True;visible=True;tabindex=10;tabstop=True",
    );
    assert_line_contains(
        &catalog,
        "control;name=ModePages;role=multipage;value=;left=135;top=188;width=110;height=39;enabled=True;visible=True;tabindex=11;tabstop=True",
    );
    assert_eq!(read_string(&mut session, &form, "InputText"), "seed");
    assert_eq!(read_string(&mut session, &form, "InputValue"), "seed");
    let textbox_diagnostics = read_string(&mut session, &form, "TextBoxDiagnostics");
    assert!(
        textbox_diagnostics.contains("text=seed;value=seed")
            && textbox_diagnostics.contains("capabilities=kind=TextBox")
            && textbox_diagnostics.contains("accessibility=textbox/text,value,selection"),
        "materialized TextBox diagnostics should expose the live Value/capability/accessibility surface:\n{textbox_diagnostics}"
    );

    let frx_refs = read_string(&mut session, &form, "FrxReferences");
    assert_line_contains(
        &frx_refs,
        "control=LogoImage;property=Picture;path=w009-representative.frx;offset=0",
    );
    let unsupported = read_string(&mut session, &form, "UnsupportedControls");
    assert!(
        unsupported.is_empty(),
        "Image should no longer materialize through the unsupported-control path: {unsupported}"
    );
    let image_metadata = read_string(&mut session, &form, "ImageMetadata");
    assert_line_contains(
        &image_metadata,
        "image;name=LogoImage;left=160;top=122;width=32;height=24;picture_path=w009-representative.frx;picture_offset=0;handle=9009",
    );
    let image_diagnostics = read_string(&mut session, &form, "ImageDiagnostics");
    assert!(
        image_diagnostics.contains("picture=w009-representative.frx;offset=0")
            && image_diagnostics.contains(";handle=9009;")
            && image_diagnostics.contains("draw_mode=zoom")
            && image_diagnostics.contains("capabilities=kind=Image")
            && image_diagnostics.contains(";focusable=False;tabstop=False;click=True"),
        "Image diagnostics should expose the live picture handle and capability shape:\n{image_diagnostics}"
    );
    let spin_diagnostics = read_string(&mut session, &form, "SpinButtonDiagnostics");
    assert!(
        spin_diagnostics.contains("value=3;min=-1;max=7;small_change=2;pressed_direction=0")
            && spin_diagnostics.contains("capabilities=kind=SpinButton"),
        "SpinButton diagnostics should expose .frm value/range materialization:\n{spin_diagnostics}"
    );
    assert_eq!(read_i32(&mut session, &form, "SpinValue"), 3);
    let scroll_diagnostics = read_string(&mut session, &form, "ScrollBarDiagnostics");
    assert!(
        scroll_diagnostics.contains("value=25;min=0;max=100;small_change=5;large_change=20;pressed_part=")
            && scroll_diagnostics.contains("capabilities=kind=ScrollBar"),
        "ScrollBar diagnostics should expose .frm value/range materialization:\n{scroll_diagnostics}"
    );
    assert_eq!(read_i32(&mut session, &form, "ScrollValue"), 25);
    let tabstrip_diagnostics = read_string(&mut session, &form, "TabStripDiagnostics");
    assert!(
        tabstrip_diagnostics.contains("count=0;value=-1;caption=;tabs=")
            && tabstrip_diagnostics.contains("capabilities=kind=TabStrip"),
        "TabStrip diagnostics should expose live empty materialization and capability shape:\n{tabstrip_diagnostics}"
    );
    let multipage_diagnostics = read_string(&mut session, &form, "MultiPageDiagnostics");
    assert!(
        multipage_diagnostics.contains("count=0;value=-1;caption=;pages=;selected_children=0")
            && multipage_diagnostics.contains("capabilities=kind=MultiPage"),
        "MultiPage diagnostics should expose live empty materialization and capability shape:\n{multipage_diagnostics}"
    );

    let frx = std::fs::read(
        repo_root().join("fixtures/frm/w009-materialization/w009-representative.frx"),
    )
    .expect("read representative .frx");
    assert!(
        frx.starts_with(b"OXFORMS-W009-FRX-STUB"),
        ".frx fixture should carry non-empty representative binary bytes"
    );
    let bytes_label = format!("fixture-len-{}", frx.len());
    let decode_effects = HostServices::headless().decode_image("LogoImage", &bytes_label);
    assert!(
        decode_effects
            .iter()
            .any(|effect| effect.contains("image.decode:LogoImage:sha256=fixture-len-")),
        "representative .frx bytes should drive the HostServices decode-handle trace: {decode_effects:?}"
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
        snap.node_count, 18,
        "root plus fourteen controls, ListBox rows and TextBox text/selection nodes"
    );
    let scene = snap.scene.as_ref().expect("resident scene");
    assert!(
        scene.nodes.iter().flat_map(|node| &node.prims).any(|prim| {
            matches!(
                prim,
                Prim::DrawImage {
                    image: ImageHandle(9009),
                    mode: ImageMode::Zoom,
                    ..
                }
            )
        }),
        "materialized Image should emit a DrawImage primitive with the opaque handle"
    );
    let report = render_headless_report(scene);
    assert!(
        report.command_count > 0 && report.framebuffer_hash != 0,
        "headless renderer should produce deterministic output for the Image placeholder"
    );

    let accessibility = read_string(&mut session, &form, "AccessibilitySnapshot");
    assert!(
        accessibility.contains("role=form;name=W009MaterializationForm")
            && accessibility.contains("role=textbox;name=InputField;value=seed")
            && accessibility.contains("role=checkbox;name=AcceptCheck;value=True")
            && accessibility.contains("role=togglebutton;name=ModeToggle;value=True")
            && accessibility.contains("role=radio;name=ModeOption;value=True")
            && accessibility.contains("role=listbox;name=ChoicesList;value=")
            && accessibility.contains("role=image;name=LogoImage;value=w009-representative.frx")
            && accessibility.contains("role=combobox;name=SizeCombo;value=Medium")
            && accessibility.contains("role=spinbutton;name=CountSpin;value=3")
            && accessibility.contains("role=scrollbar;name=AmountScroll;value=25")
            && accessibility.contains("role=tabstrip;name=ModeTabs;value=")
            && accessibility.contains("role=multipage;name=ModePages;value="),
        "materialized form should project accessibility from the live object model:\n{accessibility}"
    );

    call(
        &mut session,
        form.clone(),
        "DispatchChar",
        ProjectMemberKind::Method,
        vec![Variant::from_string("!")],
    );
    assert_eq!(
        read_string(&mut session, &form, "InputValue"),
        "seed!",
        "materialized .frm TextBox should accept reducer-driven character input"
    );
    assert!(
        read_string(&mut session, &form, "TextBoxDiagnostics").contains("text=seed!;value=seed!"),
        "updated materialized TextBox diagnostics should reflect typed input"
    );
}
