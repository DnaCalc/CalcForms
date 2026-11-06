//! Non-production authored-layout driver. All controls/behavior are production VBA.
#![forbid(unsafe_code)]
use calcforms_calcvba_adapter::{
    host_services::HostServices,
    library_modules,
    runtime::OxRuntime,
    surface::{register_surface, SurfaceFactory},
};
use calcforms_pal::scene::FontId;
use calcforms_pal_win::{load_ui_font_family, AbGlyphShaper, FontTable};
use calcvba_bundle::ProjectMemberKind;
use calcvba_com::PortableComProjection;
use calcvba_engine::{Engine, HostConfig, HostProfileProvider};
use calcvba_hal::model::HostPolicy;
use calcvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};
use std::sync::Arc;

fn run() -> Result<(), String> {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args.len() != 8 && !(args.len() == 10 && args[8] == "--measure") {
        return Err("Usage: layout_probe <source.cls> <class> <width-pt> <height-pt> <scale> <scene.json> <caption> <font-family> [--measure <member>]".into());
    }
    let mut modules = library_modules();
    let mut attributes = ModuleAttributes::named(&args[1]);
    attributes.vb_predeclared_id = true;
    modules.push(ModuleUnit {
        module_name: args[1].clone(),
        module_kind: ModuleKind::Class,
        attributes,
        source: std::fs::read_to_string(&args[0]).map_err(|e| e.to_string())?,
    });
    let manifest = SymbolProjectManifest {
        project_name: "CalcFormsAuthoredLayout".into(),
        project_kind: ProjectKind::Library,
        modules,
        references: vec![],
        reference_projects: vec![],
        conditional_constants: Default::default(),
        conditional_compilation_target: Default::default(),
    };
    let program = calcvba_bind::bind_program(&manifest, &calcvba_symbol::CatalogTypeLibResolver)
        .map_err(|e| format!("bind authored layout: {e}"))?;
    let bundle = calcvba_oxir::elaborate::elaborate(&program).map_err(|e| e.to_string())?;
    let font = load_ui_font_family(&args[7]).map_err(|e| e.to_string())?;
    let mut fonts = FontTable::new();
    fonts.add(FontId(1), font.clone());
    let projection = Arc::new(PortableComProjection::new());
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(AbGlyphShaper::new(
        FontId(1),
        font,
    ))));
    register_surface(&projection, surface.clone());
    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::native());
    let engine = Engine::new(HostConfig::vm3()).with_host_profile_provider(profile);
    let session = engine
        .prepare_image_session(calcvba_oxir::OxImage::new(vec![bundle]))
        .map_err(|e| e.to_string())?;
    let mut runtime = OxRuntime::attach_with_host_services(
        session,
        &args[1],
        "CalcFormsHostBuild",
        HostServices::windows(calcforms_pal_win::read_clipboard_text),
    )?
    .with_member_prefix("CalcFormsHost");
    runtime.perform("PerformInitialize")?;
    runtime.render()?;
    if args.len() == 10 {
        let form = runtime.form();
        let value = runtime
            .session_mut()
            .invoke_member_values(form, &args[9], Some(ProjectMemberKind::Method), vec![])
            .map_err(|e| format!("measure authored behaviour: {e}"))?;
        let text = value
            .as_bstr()
            .ok_or("behaviour probe did not return a String")?
            .as_str();
        println!("{}", serde_json::json!({ "measurements": text }));
        return Ok(());
    }
    calcforms_bootstrap::run_form_window(
        runtime,
        surface,
        fonts,
        calcforms_bootstrap::FormWindowConfig {
            title: args[6].clone(),
            width_pt: args[2].parse().map_err(|_| "invalid width")?,
            height_pt: args[3].parse().map_err(|_| "invalid height")?,
            scale: args[4].parse().map_err(|_| "invalid scale")?,
            observation_member: Some("LayoutFacts".into()),
            scene_path: Some((&args[5]).into()),
        },
    )
}

fn main() {
    if let Err(error) = run() {
        eprintln!("layout_probe: {error}");
        std::process::exit(1);
    }
}
