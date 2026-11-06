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

#[test]
fn combobox_uses_a_measured_line_clips_text_and_shares_drop_button_hit_bounds() {
    let source = r#"Option Explicit
Private F As UserForm
Private C As ComboBox
Private R As OxReducer
Public Sub Build()
    Set F = New UserForm
    F.Width = 160
    F.Height = 100
    Set C = F.Controls.Add("Forms.ComboBox.1", "Dropdown")
    C.Left = 12
    C.Top = 12
    C.Width = 130
    C.Height = 21
    C.Core.FontSize = 8.25
    C.Text = "A long editable value extending beyond the button"
    Set R = New OxReducer
    R.Init F
End Sub
Public Sub RenderOnce()
    F.Render 96, 96
End Sub
Public Sub PressAt(ByVal X As Long)
    R.Dispatch "mousedown", X, 20, 1, 0
    R.Dispatch "mouseup", X, 20, 1, 0
End Sub
Public Function Opened() As Boolean
    Opened = C.DropDownOpen
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
    let scene = surface.snapshot().unwrap().scene.unwrap();
    let (rect, run, clip) = scene
        .nodes
        .iter()
        .flat_map(|node| &node.prims)
        .find_map(|prim| match prim {
            Prim::DrawText {
                rect, run, clip, ..
            } => Some((rect, run, clip)),
            _ => None,
        })
        .unwrap();
    assert_eq!((rect.x, rect.y), (21.0, 15.0));
    assert!(clip, "long values must stop before the drop button");
    assert!((rect.h - scene.text_run(*run).unwrap().metrics.line_height()).abs() < 0.002);
    assert!(rect.x + rect.w < 127.5);
    call("PressAt", vec![Variant::from_i32(127)]);
    assert_eq!(call("Opened", vec![]).as_bool(), Some(false));
    call("PressAt", vec![Variant::from_i32(128)]);
    assert_eq!(call("Opened", vec![]).as_bool(), Some(true));
}

#[test]
fn changing_default_button_repaints_and_removes_its_outline() {
    let source = r#"Option Explicit
Private F As UserForm
Private B As CommandButton
Public Sub Build()
    Set F = New UserForm
    Set B = F.Controls.Add("Forms.CommandButton.1", "Save")
    B.Left = 12
    B.Top = 12
    B.Width = 80
    B.Height = 24
    B.Caption = "Save"
End Sub
Public Sub RenderOnce()
    F.Render 96, 96
End Sub
Public Sub MakeDefault()
    B.Default = True
End Sub
Public Sub ClearDefault()
    B.Default = False
End Sub
"#;
    let (mut session, form, surface) = fixture(source);
    let mut call = |name: &str| {
        session
            .invoke_member_values(form.clone(), name, Some(ProjectMemberKind::Method), vec![])
            .unwrap()
    };
    let outlined = || {
        surface
            .snapshot()
            .unwrap()
            .scene
            .unwrap()
            .nodes
            .iter()
            .any(|n| {
                n.id == calcforms_pal::scene::NodeId(1)
                    && n.prims.iter().any(|p| {
                        matches!(p, Prim::FillRect { rect, paint: Paint::Solid(c) }
                    if rect.y == 12.0 && *c == Color::rgba(0, 0, 0, 255))
                    })
            })
    };
    call("Build");
    call("RenderOnce");
    assert!(!outlined());
    call("MakeDefault");
    call("RenderOnce");
    assert!(
        outlined(),
        "changing Default must invalidate its painted outline"
    );
    call("ClearDefault");
    call("RenderOnce");
    assert!(!outlined(), "clearing Default must remove the old outline");
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
fn literal_ampersands_keep_text_list_and_caret_indices_and_explicit_button_accelerator() {
    let source = r#"Option Explicit
Private F As UserForm
Private T As TextBox
Private L As ListBox
Private WithEvents B As CommandButton
Private R As OxReducer
Private Clicks As Long
Public Sub Build()
    Set F = New UserForm
    F.Width = 300
    F.Height = 180
    Set T = F.Controls.Add("Forms.TextBox.1", "Text")
    T.Width = 130
    T.Height = 21
    T.Text = "A&B && C&"
    T.SelStart = 1
    T.SelLength = 1
    Set L = F.Controls.Add("Forms.ListBox.1", "List")
    L.Top = 30
    L.Width = 130
    L.Height = 60
    L.AddItem "A&B"
    L.AddItem "A&&B"
    L.AddItem "tail&"
    Set B = F.Controls.Add("Forms.CommandButton.1", "Button")
    B.Left = 160
    B.Width = 80
    B.Height = 24
    B.Caption = "A&B && C&"
    Set R = New OxReducer
    R.Init F
    R.DispatchKey "keydown", 9, 0
End Sub
Public Sub RenderOnce()
    F.Render 96, 96
End Sub
Public Function SelectedText() As String
    SelectedText = T.SelText
End Function
Public Sub SetAccelerator(ByVal Value As String)
    B.Accelerator = Value
End Sub
Public Function Accelerator() As String
    Accelerator = B.Accelerator
End Function
Public Function PressB() As Long
    R.DispatchKey "keydown", 66, 4
    PressB = Clicks
End Function
Private Sub B_Click()
    Clicks = Clicks + 1
End Sub
"#;
    let (mut session, form, surface) = fixture(source);
    let mut call = |name: &str, args: Vec<Variant>| {
        session
            .invoke_member_values(form.clone(), name, Some(ProjectMemberKind::Method), args)
            .unwrap()
    };
    call("Build", vec![]);
    call("RenderOnce", vec![]);
    assert_eq!(
        call("SelectedText", vec![]).as_bstr().unwrap().as_str(),
        "&"
    );
    assert_eq!(
        call("PressB", vec![]).as_i32(),
        Some(0),
        "Caption contains no implicit accelerator"
    );
    let scene = surface.snapshot().unwrap().scene.unwrap();
    let literal = scene
        .text
        .values()
        .find(|run| &*run.source == "A&B && C&")
        .unwrap();
    assert_eq!(literal.glyphs.len(), 9);
    assert_eq!(literal.caret.stops.len(), 10);
    for text in ["A&B", "A&&B", "tail&"] {
        assert!(scene.text.values().any(|run| &*run.source == text));
    }
    // The four native FM20 property observations keep case and truncate to one character.
    for value in ["b", "BC", "&", ""] {
        call("SetAccelerator", vec![Variant::from_string(value)]);
        assert_eq!(
            call("Accelerator", vec![]).as_bstr().unwrap().as_str(),
            value.chars().take(1).collect::<String>()
        );
    }
    call("SetAccelerator", vec![Variant::from_string("b")]);
    assert_eq!(call("PressB", vec![]).as_i32(), Some(1));
    call("RenderOnce", vec![]);
    assert!(surface
        .snapshot()
        .unwrap()
        .scene
        .unwrap()
        .text
        .values()
        .any(|run| &*run.source == "A&B && C&" && run.accelerator == Some(2)));
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
fn label_wraps_measured_words_reflows_and_keeps_explicit_breaks_without_extra_crossings() {
    let source = r#"Option Explicit
Private F As UserForm
Private L As Label
Public Sub Build()
    Set F = New UserForm
    F.Width = 160
    F.Height = 100
    Set L = F.Controls.Add("Forms.Label.1", "Wrapped")
    L.Left = 12
    L.Top = 12
    L.Width = 45
    L.Height = 48
    L.Core.FontSize = 10
    L.Caption = "one two three"
End Sub
Public Sub RenderOnce()
    F.Render 96, 96
End Sub
Public Sub Widen()
    L.Width = 80
End Sub
Public Sub ExplicitBreaks()
    L.Caption = "one" & vbCrLf & "two" & vbLf & "three"
    L.WordWrap = False
End Sub
Public Sub Clear()
    L.Caption = ""
End Sub
"#;
    let (mut session, form, surface) = fixture(source);
    let mut call = |name: &str| {
        session
            .invoke_member_values(form.clone(), name, Some(ProjectMemberKind::Method), vec![])
            .unwrap()
    };
    call("Build");
    call("RenderOnce");
    let snapshot = surface.snapshot().unwrap();
    assert_eq!(
        snapshot
            .calls
            .iter()
            .filter(|c| c.starts_with("MeasureBatch:"))
            .count(),
        1
    );
    let text = rows(&snapshot.scene.unwrap());
    assert_eq!(
        text.iter().map(|r| (r.0.as_str(), r.1)).collect::<Vec<_>>(),
        [("one", 12.75), ("two", 12.75), ("three", 22.75)]
    );
    call("Widen");
    call("RenderOnce");
    assert_eq!(
        rows(&surface.snapshot().unwrap().scene.unwrap())[0].0,
        "one two three"
    );
    call("ExplicitBreaks");
    call("RenderOnce");
    let text = rows(&surface.snapshot().unwrap().scene.unwrap());
    assert_eq!(
        text.iter().map(|r| (r.0.as_str(), r.1)).collect::<Vec<_>>(),
        [("one", 12.75), ("two", 22.75), ("three", 32.75)]
    );
    call("Clear");
    call("RenderOnce");
    assert!(surface.snapshot().unwrap().scene.unwrap().text.is_empty());
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
        ["Second", "First"],
        "selected header paints last across its overlap"
    );
    let mut text: Vec<_> = scene
        .get(NodeId(1))
        .unwrap()
        .prims
        .iter()
        .filter_map(|p| match p {
            Prim::DrawText { rect, .. } => Some(*rect),
            _ => None,
        })
        .collect();
    text.sort_by(|a, b| a.x.total_cmp(&b.x));
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

#[test]
fn multipage_headers_paint_outside_the_measured_page_child_clip() {
    let source = r#"Option Explicit
Private F As UserForm
Private M As MultiPage
Public Sub Build()
    Set F = New UserForm
    F.Width = 200
    F.Height = 180
    Set M = F.Controls.Add("Forms.MultiPage.1", "Pages")
    M.Left = 12
    M.Top = 12
    M.Width = 162
    M.Height = 144
    M.Core.FontSize = 8.25
    M.Pages.Add "First"
    M.Pages.Add "Second"
    Dim L As Label
    Set L = M.Pages.Item(0).Controls.Add("Forms.Label.1", "InsideFirst")
    L.Left = 5
    L.Top = 6
    L.Width = 60
    L.Height = 18
    L.Caption = "Inside"
    Set L = M.Pages.Item(1).Controls.Add("Forms.Label.1", "InsideSecond")
    L.Left = 5
    L.Top = 6
    L.Width = 60
    L.Height = 18
    L.Caption = "Other"
End Sub
Public Sub RenderOnce()
    F.Render 96, 96
End Sub
Public Sub ChooseSecond()
    M.Value = 1
End Sub
"#;
    let (mut session, form, surface) = fixture(source);
    let mut call = |name: &str| {
        session
            .invoke_member_values(form.clone(), name, Some(ProjectMemberKind::Method), vec![])
            .unwrap()
    };
    call("Build");
    call("RenderOnce");
    let scene = surface.snapshot().unwrap().scene.unwrap();
    let parent = scene.get(NodeId(1)).unwrap();
    assert_eq!(parent.clip, Some(parent.bounds));
    let page = scene.get(NodeId(2)).unwrap();
    let clip = page.clip.unwrap();
    assert_eq!(
        (clip.x, clip.y, clip.w, clip.h),
        (13.5, 27.75, 159.0, 126.75)
    );
    let captions: Vec<_> = parent
        .prims
        .iter()
        .filter_map(|p| match p {
            Prim::DrawText { rect, run, .. } => {
                Some((rect, scene.text_run(*run).unwrap().source.as_ref()))
            }
            _ => None,
        })
        .collect();
    assert_eq!(
        captions.iter().map(|p| p.1).collect::<Vec<_>>(),
        ["Second", "First"],
        "selected header paints last across its overlap"
    );
    assert!(
        captions.iter().all(|p| p.0.y < clip.y),
        "header paint is outside the page's child clip"
    );
    let child = scene.get(NodeId(4)).unwrap();
    assert_eq!((child.bounds.x, child.bounds.y), (18.5, 33.75));
    assert!(scene.get(NodeId(5)).is_none());
    call("ChooseSecond");
    call("RenderOnce");
    let scene = surface.snapshot().unwrap().scene.unwrap();
    assert!(scene.get(NodeId(4)).is_none());
    assert_eq!(scene.get(NodeId(3)).unwrap().clip, Some(clip));
    assert!(scene.get(NodeId(5)).is_some());
}

#[test]
fn option_button_uses_ellipses_for_the_ring_and_selected_dot() {
    let source = r#"Option Explicit
Private F As UserForm
Public Sub Build()
    Set F = New UserForm
    F.Width = 160
    F.Height = 60
    Dim O As OptionButtonControl
    Set O = F.Controls.Add("Forms.OptionButton.1", "Option")
    O.Left = 12
    O.Top = 12
    O.Width = 130
    O.Height = 18
    O.Caption = "First option"
    O.Value = True
End Sub
Public Sub RenderOnce()
    F.Render 96, 96
End Sub
"#;
    let (mut session, form, surface) = fixture(source);
    for name in ["Build", "RenderOnce"] {
        session
            .invoke_member_values(form.clone(), name, Some(ProjectMemberKind::Method), vec![])
            .unwrap();
    }
    let scene = surface.snapshot().unwrap().scene.unwrap();
    let node = scene.get(NodeId(1)).unwrap();
    let rings: Vec<_> = node
        .prims
        .iter()
        .filter_map(|p| match p {
            Prim::Ellipse { rect, .. } => Some(rect),
            _ => None,
        })
        .collect();
    assert_eq!(rings.len(), 3);
    assert_eq!(
        rings.iter().map(|r| r.w).collect::<Vec<_>>(),
        [9.75, 8.25, 4.5]
    );
    assert!(rings.iter().all(|r| r.w == r.h));
    assert!(
        !node
            .prims
            .iter()
            .any(|p| matches!(p, Prim::FillRect { .. })),
        "no square selection glyph remains"
    );
}
