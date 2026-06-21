use std::sync::Arc;

use oxforms_pal::{
    oxvba_host_object::{register_smoke_canvas, SmokeCanvasFactory},
    w002_rectangle_fixture_diagnostics, w002_rectangle_fixture_display_list,
};
use oxvba_com::PortableComProjection;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, HostProfileProvider, RuntimeProfileId};
use oxvba_runtime::Variant;

const RECTANGLE_SMOKE_SOURCE: &str =
    include_str!("../../../vba/smoke/fixtures/rectangle_fillrect_smoke.bas");

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

#[test]
fn oxvba_rectangle_smoke_reaches_host_injected_pal_canvas_and_renderer() {
    let projection = Arc::new(PortableComProjection::new());
    let canvas_factory = Arc::new(SmokeCanvasFactory::new());
    register_smoke_canvas(&projection, canvas_factory.clone());

    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::interactive_dev());
    let mut engine =
        Engine::new(HostConfig { enable_jit: false }).with_host_profile_provider(profile);
    engine.set_runtime_profile(headless_runtime_profile());

    let globals = engine
        .execute_source_with_variant_snapshot_clean(RECTANGLE_SMOKE_SOURCE)
        .expect("OxVba should execute the W002 host-injected rectangle smoke fixture");

    let snapshot = canvas_factory
        .snapshot()
        .expect("smoke canvas state should be readable after execution");
    assert_eq!(
        snapshot.calls,
        ["CreateSurface:2", "FillRect:8", "Flush:0"],
        "VBA should drive the Rust PAL canvas through member dispatch, not through debug text"
    );

    let observed_display_list = snapshot
        .display_list
        .expect("VBA smoke should create a display list on the Rust canvas");
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
        "VBA should receive the Flush return value from the Rust host object"
    );
}
