//! Required outcomes for the CalcVBA .75 input-only portable dispatch regression.
use std::sync::Arc;

use calcforms_calcvba_adapter::surface::{register_surface, SurfaceFactory};
use calcvba_com::PortableComProjection;
use calcvba_engine::{Engine, HostConfig, RuntimeProfileId};

#[test]
fn surface_accepts_variable_arguments_without_byval_workarounds() {
    let projection = Arc::new(PortableComProjection::new());
    let factory = Arc::new(SurfaceFactory::new());
    register_surface(&projection, factory.clone());
    let engine = Engine::new(HostConfig::vm3())
        .with_runtime_profile(RuntimeProfileId::WindowsHeadless)
        .with_portable_com_projection(projection);
    engine
        .execute_source_with_variant_snapshot_clean(
            r#"
Sub Main()
    Dim surface As Object, width As Long, height As Long, dpi As Long
    Dim token As String
    Set surface = CreateObject("CalcForms.Surface")
    width = 240
    height = 180
    dpi = 96
    token = surface.BeginScene(width, height, dpi, dpi)
    If width <> 240 Or height <> 180 Or dpi <> 96 Then Err.Raise 5
    If Len(token) = 0 Then Err.Raise 5
End Sub
"#,
        )
        .expect("portable dynamic calls with variable arguments reach the real Surface");
    let snapshot = factory.snapshot().unwrap();
    assert_eq!(snapshot.calls.len(), 1);
    let scene = snapshot
        .scene
        .expect("BeginScene reached portable dispatch");
    assert_eq!(scene.surface.width, 240);
    assert_eq!(scene.surface.height, 180);
}
