use std::{
    path::{Path, PathBuf},
    sync::Arc,
};

use oxforms_oxvba_adapter::{register_smoke_canvas, SmokeCanvasFactory};
use oxforms_pal::{w002_rectangle_fixture_diagnostics, w002_rectangle_fixture_display_list};
use oxvba_com::PortableComProjection;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, HostProfileProvider, RuntimeProfileId};
use oxvba_project::load_project_closure;
use oxvba_runtime::Variant;

fn headless_runtime_profile() -> RuntimeProfileId {
    if cfg!(target_os = "windows") {
        RuntimeProfileId::WindowsStdio
    } else if cfg!(target_os = "linux") {
        RuntimeProfileId::LinuxStdio
    } else if cfg!(target_os = "macos") {
        RuntimeProfileId::MacOsHeadless
    } else {
        RuntimeProfileId::NullFloor
    }
}

fn i32_values(values: &[Variant]) -> Vec<i32> {
    values.iter().filter_map(Variant::as_i32).collect()
}

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..").join("..")
}

fn rectangle_smoke_app_project() -> PathBuf {
    repo_root()
        .join("vba")
        .join("smoke")
        .join("projects")
        .join("rectangle_app")
        .join("RectangleSmokeApp.basproj")
}

fn rectangle_smoke_app_module() -> PathBuf {
    repo_root()
        .join("vba")
        .join("smoke")
        .join("fixtures")
        .join("rectangle_fillrect_smoke.bas")
}

#[test]
fn oxvba_rectangle_smoke_app_loads_oxforms_library_and_reaches_renderer() {
    let projection = Arc::new(PortableComProjection::new());
    let canvas_factory = Arc::new(SmokeCanvasFactory::new());
    register_smoke_canvas(&projection, canvas_factory.clone());

    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::interactive_dev());
    let mut engine =
        Engine::new(HostConfig { enable_jit: false }).with_host_profile_provider(profile);
    engine.set_runtime_profile(headless_runtime_profile());

    let app_source =
        std::fs::read_to_string(rectangle_smoke_app_module()).expect("read VBA app fixture");
    assert!(
        !app_source.contains("OxForms.SmokeCanvas"),
        "the app project must load OxForms instead of directly creating the PAL canvas"
    );

    let closure = load_project_closure(&rectangle_smoke_app_project())
        .expect("OxVba should load the W002 app plus OxForms project closure");
    let project_names: Vec<_> = closure
        .iter()
        .map(|project| project.project_name.as_str())
        .collect();
    assert_eq!(
        project_names,
        ["OxForms", "RectangleSmokeApp"],
        "the W002 smoke should execute an app project that references the OxForms library"
    );

    let globals = engine
        .execute_project_closure_with_variant_snapshot(&closure)
        .expect("OxVba should execute the W002 app through the OxForms library");

    let snapshot = canvas_factory
        .snapshot()
        .expect("smoke canvas state should be readable after execution");
    assert_eq!(
        snapshot.calls,
        ["CreateSurface:2", "FillRect:8", "Flush:0"],
        "VBA should drive the Rust PAL adapter through member dispatch, not through debug text"
    );

    let observed_display_list = snapshot
        .display_list
        .expect("VBA smoke should create a display list through the OxVba adapter");
    assert_eq!(
        observed_display_list,
        w002_rectangle_fixture_display_list(),
        "host-injected VBA smoke produced a different display list"
    );

    let observed_render = snapshot
        .rendered
        .expect("VBA smoke Flush should render through oxforms-pal::render_headless");
    assert_eq!(
        observed_render.diagnostics,
        w002_rectangle_fixture_diagnostics(),
        "host-injected VBA smoke rendered with unexpected diagnostics"
    );
    assert_eq!(
        i32_values(&globals),
        [1],
        "VBA should receive the Flush return value from the Rust PAL adapter"
    );
}
