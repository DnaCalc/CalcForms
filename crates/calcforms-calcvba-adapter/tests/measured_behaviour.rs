//! Native transcripts are independent of the production controls being tested.
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
use calcvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};
use serde_json::Value;

fn run(source: String, name: &str, member: &str) -> String {
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
    let form = runtime.form();
    runtime
        .session_mut()
        .invoke_member_values(form, member, Some(ProjectMemberKind::Method), vec![])
        .unwrap()
        .as_bstr()
        .unwrap()
        .as_str()
}

fn evidence(bead: &str) -> std::path::PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join(format!(
        "../../docs/evidence/W010_complete_msforms_object_model_parity/beads/{bead}"
    ))
}

#[test]
fn setters_match_native_notifications_repeat_suppression_and_peer_order() {
    let directory = evidence("oxforms-jbjp.107").join("behaviour");
    let data: Value =
        serde_json::from_slice(&std::fs::read(directory.join("observations.json")).unwrap())
            .unwrap();
    for case in data["observations"].as_array().unwrap() {
        if case["zoom"] != 100 {
            continue;
        }
        let name = case["form"].as_str().unwrap();
        let paired = data["observations"]
            .as_array()
            .unwrap()
            .iter()
            .find(|c| c["form"] == name && c["zoom"] == 150)
            .unwrap();
        assert_eq!(case["native"], paired["native"]);
        let source =
            std::fs::read_to_string(directory.join(format!("{name}-runtime.cls"))).unwrap();
        assert_eq!(
            run(source, name, "ParityMeasurements"),
            case["native"].as_str().unwrap(),
            "{name}: same-value assignment must stay quiet; peer Change precedes selected Change/Click"
        );
    }
}

#[test]
fn enter_and_escape_match_native_default_and_boolean_notifications() {
    let directory = evidence("oxforms-jbjp.109").join("keyboard");
    let data: Value =
        serde_json::from_slice(&std::fs::read(directory.join("observations.json")).unwrap())
            .unwrap();
    let keys_only = |s: &str| {
        s.lines()
            .filter(|line| !line.contains("~scrolling~"))
            .map(str::to_owned)
            .collect::<Vec<_>>()
    };
    for case in data["observations"].as_array().unwrap() {
        if case["zoom"] != 100 {
            continue;
        }
        let name = case["form"].as_str().unwrap();
        let source =
            std::fs::read_to_string(directory.join(format!("{name}-100-runtime.cls"))).unwrap();
        let actual = run(source, name, "ParityKeyboardMeasurements");
        assert_eq!(
            keys_only(&actual),
            keys_only(case["native"].as_str().unwrap()),
            "{name}"
        );
        if name == "LayoutSelection" {
            // This separate, still-open mismatch must not be masked by key parity.
            assert!(actual.contains("top_error=438"));
        }
    }
}
