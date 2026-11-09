//! Shared helpers for tests that run authored VBA against the production controls.
#![allow(dead_code)]
use std::{path::Path, sync::Arc};

use calcforms_calcvba_adapter::{
    library_modules,
    runtime::OxRuntime,
    surface::{register_surface, SurfaceFactory},
};
use calcforms_pal::scene::StubShaper;
use calcvba_bundle::ProjectMemberKind;
use calcvba_com::PortableComProjection;
use calcvba_engine::{Engine, HostConfig, HostProfileProvider};
use calcvba_hal::model::HostPolicy;
use calcvba_runtime::Variant;
use calcvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

/// Compile `source` as a predeclared class named `name` on top of the CalcForms library, build
/// and render it, and return the runtime with the class as its form.
pub fn runtime_for(source: String, name: &str) -> OxRuntime {
    let mut modules = library_modules();
    let mut attributes = ModuleAttributes::named(name);
    attributes.vb_predeclared_id = true;
    modules.push(ModuleUnit {
        module_name: name.into(),
        module_kind: ModuleKind::Class,
        attributes,
        source,
    });
    let manifest = SymbolProjectManifest {
        project_name: "MeasuredFormsBehaviour".into(),
        project_kind: ProjectKind::Library,
        modules,
        references: vec![],
        reference_projects: vec![],
        conditional_constants: Default::default(),
        conditional_compilation_target: Default::default(),
    };
    let program =
        calcvba_bind::bind_program(&manifest, &calcvba_symbol::CatalogTypeLibResolver).unwrap();
    let bundle = calcvba_oxir::elaborate::elaborate(&program).unwrap();
    let projection = Arc::new(PortableComProjection::new());
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(StubShaper)));
    register_surface(&projection, surface);
    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::native());
    let engine = Engine::new(HostConfig::vm3()).with_host_profile_provider(profile);
    let session = engine
        .prepare_image_session(calcvba_oxir::OxImage::new(vec![bundle]))
        .unwrap();
    let mut runtime = OxRuntime::attach(session, name, "CalcFormsHostBuild")
        .unwrap()
        .with_member_prefix("CalcFormsHost");
    runtime.perform("PerformInitialize").unwrap();
    runtime.render().unwrap();
    runtime
}

/// Call a method of the form class and return its String result.
pub fn call_text(runtime: &mut OxRuntime, member: &str, args: Vec<Variant>) -> String {
    let form = runtime.form();
    runtime
        .session_mut()
        .invoke_member_values(form, member, Some(ProjectMemberKind::Method), args)
        .unwrap()
        .as_bstr()
        .unwrap()
        .as_str()
}

/// Compile `source`, build it, call `member` once and return the String result.
pub fn run_class(source: String, name: &str, member: &str) -> String {
    let mut runtime = runtime_for(source, name);
    call_text(&mut runtime, member, vec![])
}

/// Absolute path of an evidence bead directory.
pub fn evidence(bead: &str) -> std::path::PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join(format!(
        "../../docs/evidence/W010_complete_msforms_object_model_parity/beads/{bead}"
    ))
}
