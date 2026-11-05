//! Independent VBA text fragments still share one measurement crossing.
use std::sync::Arc;

use calcforms_calcvba_adapter::{
    library_modules,
    surface::{register_surface, SurfaceFactory},
};
use calcforms_pal::{
    scene::{NodeId, Paint, Prim, Scene, StubShaper},
    Color,
};
use calcvba_bundle::ProjectMemberKind;
use calcvba_com::PortableComProjection;
use calcvba_engine::{Engine, HostConfig, HostProfileProvider};
use calcvba_hal::model::HostPolicy;
use calcvba_runtime::Variant;
use calcvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

const SOURCE: &str = r#"Option Explicit
Private F As UserForm
Private L As ListBox
Private R As OxReducer
Public Sub Build()
    Set F = New UserForm
    F.Width = 160
    F.Height = 100
    Set L = F.Controls.Add("Forms.ListBox.1", "Choices")
    L.Left = 12
    L.Top = 12
    L.Width = 130
    L.Height = 26
    L.Core.FontSize = 8.25
    L.AddItem "Alpha"
    L.AddItem "Beta"
    L.AddItem "Gamma"
    L.ListIndex = 1
    Set R = New OxReducer
    R.Init F
End Sub
Public Sub RenderOnce()
    F.Render 96, 96
End Sub
Public Sub ClearRows()
    L.Clear
End Sub
Public Sub EmptyRow()
    L.Clear
    L.AddItem ""
    L.AddItem "Gamma"
End Sub
Public Sub Narrow()
    L.Width = 6
End Sub
Public Sub SelectAt(ByVal Y As Long)
    R.Dispatch "mousedown", 20, Y, 1, 0
    R.Dispatch "mouseup", 20, Y, 1, 0
End Sub
Public Function SelectedRow() As Long
    SelectedRow = L.ListIndex
End Function
"#;

fn rows(scene: &Scene) -> Vec<(String, f32, Color)> {
    scene
        .nodes
        .iter()
        .flat_map(|n| &n.prims)
        .filter_map(|p| {
            if let Prim::DrawText {
                run,
                rect,
                paint: Paint::Solid(color),
                ..
            } = p
            {
                Some((
                    scene.text_run(*run).unwrap().source.to_string(),
                    rect.y,
                    *color,
                ))
            } else {
                None
            }
        })
        .collect()
}

fn fixture(
    source: &str,
) -> (
    calcvba_engine::ProjectRuntimeSession,
    calcvba_runtime::ObjectRef,
    Arc<SurfaceFactory>,
) {
    let mut modules = library_modules();
    modules.push(ModuleUnit {
        module_name: "Fragments".into(),
        module_kind: ModuleKind::Class,
        attributes: ModuleAttributes::named("Fragments"),
        source: source.into(),
    });
    let manifest = SymbolProjectManifest {
        project_name: "Fragments".into(),
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
    register_surface(&projection, surface.clone());
    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::native());
    let mut session = Engine::new(HostConfig::vm3())
        .with_host_profile_provider(profile)
        .prepare_image_session(calcvba_oxir::OxImage::new(vec![bundle]))
        .unwrap();
    let form = session.create_class_instance("Fragments").unwrap();
    (session, form, surface)
}

#[test]
fn list_rows_measure_separately_clip_and_rebuild_without_old_text() {
    let (mut session, form, surface) = fixture(SOURCE);
    let mut call = |name: &str, args: Vec<Variant>| {
        session
            .invoke_member_values(form.clone(), name, Some(ProjectMemberKind::Method), args)
            .unwrap()
    };
    call("Build", vec![]);
    call("RenderOnce", vec![]);
    let snapshot = surface.snapshot().unwrap();
    assert_eq!(
        snapshot
            .calls
            .iter()
            .filter(|s| s.starts_with("MeasureBatch:"))
            .count(),
        1
    );
    let scene = snapshot.scene.unwrap();
    let text = rows(&scene);
    assert_eq!(
        text.iter().map(|r| r.0.as_str()).collect::<Vec<_>>(),
        ["Alpha", "Beta", "Gamma"]
    );
    assert_eq!(
        text.iter().map(|r| r.1).collect::<Vec<_>>(),
        [13.5, 23.25, 33.0]
    );
    assert_eq!(text[0].2, Color::rgba(0, 0, 0, 255));
    assert_eq!(text[1].2, Color::rgba(255, 255, 255, 255));
    let node = scene.nodes.iter().find(|n| n.id == NodeId(1903)).unwrap();
    let clip = node.clip.unwrap();
    assert_eq!((clip.x, clip.y, clip.w, clip.h), (13.5, 13.5, 127.0, 23.0));
    // Points on opposite sides of the painted boundary select opposite rows.
    call("SelectAt", vec![Variant::from_i32(23)]);
    assert_eq!(call("SelectedRow", vec![]).as_i32(), Some(0));
    call("SelectAt", vec![Variant::from_i32(24)]);
    assert_eq!(call("SelectedRow", vec![]).as_i32(), Some(1));
    call("EmptyRow", vec![]);
    call("RenderOnce", vec![]);
    let text = rows(&surface.snapshot().unwrap().scene.unwrap());
    assert_eq!(
        text.iter().map(|r| r.0.as_str()).collect::<Vec<_>>(),
        ["", "Gamma"]
    );
    assert_eq!(text[1].1, 23.25, "an empty row retains its pitch");
    call("Narrow", vec![]);
    call("RenderOnce", vec![]);
    assert!(rows(&surface.snapshot().unwrap().scene.unwrap()).is_empty());
    call("ClearRows", vec![]);
    call("RenderOnce", vec![]);
    assert!(rows(&surface.snapshot().unwrap().scene.unwrap()).is_empty());
}

#[test]
fn tab_captions_have_individual_metrics_and_refresh_after_mutation() {
    let source = r#"Option Explicit
Private F As UserForm
Private T As TabStrip
Private R As OxReducer
Public Sub Build()
    Set F = New UserForm
    F.Width = 180
    F.Height = 100
    Set T = F.Controls.Add("Forms.TabStrip.1", "Tabs")
    T.Left = 12
    T.Top = 12
    T.Width = 160
    T.Height = 80
    T.Core.FontSize = 8.25
    T.Tabs.Add "First"
    T.Tabs.Add "Second"
    Set R = New OxReducer
    R.Init F
End Sub
Public Sub RenderOnce()
    F.Render 96, 96
End Sub
Public Sub Rename()
    T.Tabs.Item(1).Caption = "Longer second caption"
End Sub
Public Sub EmptyTabs()
    T.Tabs.Clear
    T.Tabs.Add ""
End Sub
Public Sub SelectAt(ByVal X As Long)
    R.Dispatch "mousedown", X, 17, 1, 0
    R.Dispatch "mouseup", X, 17, 1, 0
End Sub
Public Function SelectedTab() As Long
    SelectedTab = T.Value
End Function
"#;
    let (mut session, form, surface) = fixture(source);
    let mut call = |name: &str, args: Vec<Variant>| {
        session
            .invoke_member_values(form.clone(), name, Some(ProjectMemberKind::Method), args)
            .unwrap()
    };
    call("Build", vec![]);
    call("RenderOnce", vec![]);
    let snap = surface.snapshot().unwrap();
    assert_eq!(
        snap.calls
            .iter()
            .filter(|s| s.starts_with("MeasureBatch:"))
            .count(),
        1
    );
    let scene = snap.scene.unwrap();
    assert_eq!(
        rows(&scene)
            .iter()
            .map(|r| r.0.as_str())
            .collect::<Vec<_>>(),
        ["First", "Second"]
    );
    let text: Vec<_> = scene
        .get(NodeId(1))
        .unwrap()
        .prims
        .iter()
        .filter_map(|p| match p {
            Prim::DrawText { rect, .. } => Some(*rect),
            _ => None,
        })
        .collect();
    assert!(
        text[1].x < 92.0,
        "tabs follow caption width rather than half the site"
    );
    call(
        "SelectAt",
        vec![Variant::from_i32(text[1].x.ceil() as i32 + 2)],
    );
    assert_eq!(call("SelectedTab", vec![]).as_i32(), Some(1));
    call("SelectAt", vec![Variant::from_i32(165)]);
    assert_eq!(
        call("SelectedTab", vec![]).as_i32(),
        Some(1),
        "blank header space does not select a tab"
    );
    call("Rename", vec![]);
    call("RenderOnce", vec![]);
    let scene = surface.snapshot().unwrap().scene.unwrap();
    assert_eq!(
        rows(&scene)
            .iter()
            .map(|r| r.0.as_str())
            .collect::<Vec<_>>(),
        ["First", "Longer second caption"]
    );
    call("EmptyTabs", vec![]);
    call("RenderOnce", vec![]);
    assert_eq!(rows(&surface.snapshot().unwrap().scene.unwrap())[0].0, "");
}
