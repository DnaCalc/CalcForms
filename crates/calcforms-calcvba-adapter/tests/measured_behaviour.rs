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

fn run(mut source: String, name: &str, member: &str) -> String {
    // Historical probes omitted Index. Adapt only their unused handler parameter;
    // native transcripts and all scenario actions remain frozen.
    for control in ["TabsControl", "PagesControl"] {
        for event in ["MouseDown", "MouseUp"] {
            source = source.replace(
                &format!("Private Sub {control}_{event}(ByVal Button"),
                &format!("Private Sub {control}_{event}(ByVal Index As Long, ByVal Button"),
            );
        }
    }
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
    for case in data["observations"].as_array().unwrap() {
        if case["zoom"] != 100 {
            continue;
        }
        let name = case["form"].as_str().unwrap();
        let source =
            std::fs::read_to_string(directory.join(format!("{name}-100-runtime.cls"))).unwrap();
        let actual = run(source, name, "ParityKeyboardMeasurements");
        assert_eq!(actual, case["native"].as_str().unwrap(), "{name}");
    }
}

#[test]
fn list_viewport_boundaries_match_native_without_moving_same_index() {
    let directory = evidence("oxforms-jbjp.112").join("native");
    let data: Value =
        serde_json::from_slice(&std::fs::read(directory.join("observations.json")).unwrap())
            .unwrap();
    let native_source = std::fs::read_to_string(directory.join("observer.bas")).unwrap();
    // CalcVBA f85aba21 executes statements following Case labels on the same line (oxforms-jbjp.117).
    let observer = native_source
        .replace("Option Explicit", "")
        .replace("MSForms.ListBox", "ListBox")
        .replace(r#"LayoutSelection.Controls("Choices")"#, "Choices")
        .replace(
            "    Load LayoutSelection
",
            "",
        )
        .replace(
            "    LayoutSelection.Zoom = Zoom
",
            "",
        )
        .replace(
            "    LayoutSelection.Show vbModeless
",
            "",
        )
        .replace(
            "    LayoutSelection.Hide
",
            "",
        );
    let mut source = String::from(
        r#"Option Explicit
Private F As UserForm
Private Choices As ListBox
Private Sub CalcFormsHostBuild()
    Set F = New UserForm
    Set Choices = F.Controls.Add("Forms.ListBox.1", "Choices")
    Choices.Core.FontSize = 8.25
End Sub
Private Sub CalcFormsHostPerformInitialize()
End Sub
Private Sub CalcFormsHostRender()
    F.Render 96, 96
End Sub
"#,
    );
    source.push_str(&observer);
    source.push_str(
        "
Public Function ViewportMeasurements() As String
    Dim S As String, Ignored As String
",
    );
    // Replay the exact saved public-property sequence. Show's one-time IntegralHeight
    // adjustment is a separate layout gap; compare its index/top/count here.
    let mut expected = String::new();
    for case in data["observations"].as_array().unwrap() {
        let zoom = case["zoom"].as_i64().unwrap();
        for row in case["observations"].as_array().unwrap() {
            let step = row["step"].as_str().unwrap();
            let state = row["state"].as_str().unwrap();
            let expression = if step == "initial" {
                format!("Run8ViewportPrepare({zoom})")
            } else {
                if step.starts_with("top_")
                    || step.starts_with("index_")
                    || step == "last"
                    || step == "offscreen_same_index_before"
                {
                    source.push_str(&format!(
                        "    Ignored = Run8ViewportPrepare({zoom})
"
                    ));
                }
                let (member, value) = if let Some(value) = step.strip_prefix("top_") {
                    ("top", value.parse::<i64>().unwrap())
                } else if let Some(value) = step.strip_prefix("index_") {
                    ("index", value.parse::<i64>().unwrap())
                } else {
                    match step {
                        "last" | "reselect_last" => ("index", 22),
                        "shrink" => ("height", 30),
                        "expand" => ("height", 120),
                        "clear" => ("clear", 0),
                        "empty_top_negative" => ("top", -1),
                        "empty_top_zero" => ("top", 0),
                        "empty_top_large" => ("top", 99),
                        "empty_index_zero" => ("index", 0),
                        "offscreen_same_index_before" => ("top", 15),
                        "offscreen_same_index_after" => ("index", 1),
                        _ => panic!("unrecognized native step {step}"),
                    }
                };
                format!(r#"Run8ViewportSet("{member}", {value})"#)
            };
            source.push_str(&format!(
                "    S = S & \"{zoom}:{step}:\" & {expression} & vbLf\n"
            ));
            expected.push_str(&format!(
                "{zoom}:{step}:{state}
"
            ));
        }
    }
    source.push_str(
        "    ViewportMeasurements = S
End Function
",
    );
    let actual = run(source, "ListViewportProbe", "ViewportMeasurements");
    let normalize = |text: &str| {
        text.lines()
            .map(|line| {
                if line.contains(":initial:") {
                    line.split(";height=").next().unwrap()
                } else {
                    line
                }
            })
            .collect::<Vec<_>>()
            .join(
                "
",
            )
    };
    assert_eq!(normalize(&actual), normalize(&expected));
}

#[test]
fn tab_mouse_index_and_value_timing_match_native_headers_and_bodies() {
    let directory = evidence("oxforms-jbjp.108").join("native-index");
    let data: Value =
        serde_json::from_slice(&std::fs::read(directory.join("observations.json")).unwrap())
            .unwrap();
    let native = std::fs::read_to_string(directory.join("form.bas")).unwrap();
    let mut source = native.replacen(
        "Option Explicit",
        r#"Option Explicit
Private F As UserForm
Private R As OxReducer
Private WithEvents TabsControl As TabStrip
Private WithEvents PagesControl As MultiPage
"#,
        1,
    );
    source.push_str(
        r#"
Private Sub CalcFormsHostBuild()
    Set F = New UserForm
    F.Width = 228
    F.Height = 200
    Set TabsControl = F.Controls.Add("Forms.TabStrip.1", "TabsControl")
    TabsControl.Left = 12
    TabsControl.Top = 12
    TabsControl.Width = 200
    TabsControl.Height = 60
    TabsControl.Core.FontSize = 8.25
    TabsControl.Tabs.Add "First"
    TabsControl.Tabs.Add "Second"
    Set PagesControl = F.Controls.Add("Forms.MultiPage.1", "PagesControl")
    PagesControl.Left = 12
    PagesControl.Top = 84
    PagesControl.Width = 200
    PagesControl.Height = 96
    PagesControl.Core.FontSize = 8.25
    PagesControl.Pages.Add "First"
    PagesControl.Pages.Add "Second"
    Set R = New OxReducer
    R.Init F
End Sub
Private Sub CalcFormsHostPerformInitialize()
End Sub
Private Sub CalcFormsHostRender()
    F.Render 96, 96
End Sub
Public Function TabIndexMeasurements() As String
    Dim S As String, E As String
"#,
    );
    let mut expected = String::new();
    for case in data["observations"].as_array().unwrap() {
        let step = case["step"].as_str().unwrap();
        if step == "tabs_first" {
            source.push_str("    TabsControl.Value = 0\n    PagesControl.Value = 0\n");
        }
        let x = case["point_pt"][0].as_i64().unwrap();
        let y = case["point_pt"][1].as_i64().unwrap();
        source.push_str(&format!("    E = R.Dispatch(\"mousedown\", {x}, {y}, 1, 0)\n    E = R.Dispatch(\"mouseup\", {x}, {y}, 1, 0)\n    S = S & Snapshot(True) & vbLf\n"));
        expected.push_str(case["trace"].as_str().unwrap());
        expected.push('\n');
    }
    source.push_str("    TabIndexMeasurements = S\nEnd Function\n");
    assert_eq!(
        run(source, "TabIndexProbe", "TabIndexMeasurements"),
        expected
    );
}
