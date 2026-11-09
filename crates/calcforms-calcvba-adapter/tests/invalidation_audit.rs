//! A full re-render of every control must not produce a patch beyond the one the form's
//! invalidation set (`UserForm.InvalidatedControls`) predicted.
//!
//! With `CALCFORMS_AUDIT_INVALIDATION` set, every incremental `UserForm.Render` is followed by
//! a full re-render of every control, and a frame token that differs from the one the
//! incremental patch reached is reported through `Surface.ProfileMark` as `audit-stale:`.
//! A difference means a control changed without being invalidated (a missed dirty link: a
//! `Font` write, a container or page relation, a peer control), which would leave a stale node
//! on screen. These tests drive the audit over a setter sweep of every control kind and over
//! the existing form corpus; any `audit-stale` mark fails them.
mod common;
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
use std::sync::Arc;

fn enable_audit() {
    std::env::set_var("CALCFORMS_AUDIT_INVALIDATION", "1");
    std::env::set_var("CALCFORMS_PROFILE_TIMINGS", "1");
}

fn runtime_with_surface(source: String, name: &str) -> (OxRuntime, Arc<SurfaceFactory>) {
    enable_audit();
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
        project_name: "InvalidationAudit".into(),
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
    let engine = Engine::new(HostConfig::vm3()).with_host_profile_provider(profile);
    let session = engine
        .prepare_image_session(calcvba_oxir::OxImage::new(vec![bundle]))
        .unwrap();
    let mut runtime = OxRuntime::attach(session, name, "CalcFormsHostBuild")
        .unwrap()
        .with_member_prefix("CalcFormsHost");
    runtime.perform("PerformInitialize").unwrap();
    runtime.render().unwrap();
    (runtime, surface)
}

fn stale_marks(surface: &SurfaceFactory) -> Vec<String> {
    surface
        .snapshot()
        .unwrap()
        .calls
        .into_iter()
        .filter(|c| c.starts_with("ProfileMark:audit-stale"))
        .collect()
}

fn audit_ran(surface: &SurfaceFactory) -> usize {
    surface
        .snapshot()
        .unwrap()
        .calls
        .iter()
        .filter(|c| c.starts_with("BeginScene"))
        .count()
}

/// One mutation per `Case`; the sweep form applies each, renders (incrementally, then audited).
const MUTATIONS: &[(&str, &str)] = &[
    ("Label.Caption", "Lbl.Caption = \"Changed\""),
    ("Label.WordWrap", "Lbl.WordWrap = True"),
    ("Label.Left", "Lbl.Left = Lbl.Left + 5"),
    ("Label.Width", "Lbl.Width = Lbl.Width + 9"),
    ("Label.Visible", "Lbl.Visible = False"),
    ("Label.Enabled", "Lbl.Enabled = False"),
    ("Label.Font.Bold", "Lbl.Font.Bold = True"),
    ("Label.Font.Size", "Lbl.Font.Size = 10"),
    ("Label.Font.Name", "Lbl.Font.Name = \"Arial\""),
    ("Label.Font.Italic", "Lbl.Font.Italic = True"),
    ("Label.Font.Underline", "Lbl.Font.Underline = True"),
    ("Label.Font.Strikethrough", "Lbl.Font.Strikethrough = True"),
    ("Label.Font.Weight", "Lbl.Font.Weight = 700"),
    ("Label.Font.Charset", "Lbl.Font.Charset = 2"),
    ("Label.BackColor", "Lbl.Core.BackColor = 255"),
    ("Label.ForeColor", "Lbl.Core.ForeColor = 65280"),
    ("Label.BorderColor", "Lbl.Core.BorderColor = 16711680"),
    ("Label.SpecialEffect", "Lbl.Core.SpecialEffect = 2"),
    ("Label.BorderStyle", "Lbl.Core.BorderStyle = 1"),
    ("Label.AutoSize", "Lbl.Core.AutoSize = True"),
    ("Label.ZOrder", "Lbl.Core.ZOrder = 7"),
    ("Label.TabIndex", "Lbl.TabIndex = 3"),
    ("Label.Tag", "Lbl.Tag = \"t\""),
    ("TextBox.Text", "Txt.Text = \"typed\""),
    ("TextBox.SelStart", "Txt.SelStart = 2"),
    ("TextBox.SelLength", "Txt.SelLength = 2"),
    ("TextBox.SelText", "Txt.SelText = \"zz\""),
    ("TextBox.HideSelection", "Txt.HideSelection = False"),
    ("TextBox.MultiLine", "Txt.MultiLine = True"),
    ("TextBox.Font.Bold", "Txt.Font.Bold = True"),
    ("TextBox.Font.Size", "Txt.Font.Size = 12"),
    ("TextBox.Font.Name", "Txt.Font.Name = \"Courier New\""),
    ("TextBox.Enabled", "Txt.Enabled = False"),
    ("TextBox.Top", "Txt.Top = Txt.Top + 3"),
    ("TextBox.Height", "Txt.Height = Txt.Height + 4"),
    ("TextBox.TabStop", "Txt.TabStop = False"),
    ("CommandButton.Caption", "Btn.Caption = \"Go\""),
    ("CommandButton.Default", "Btn.Default = True"),
    ("CommandButton.Cancel", "Btn.Cancel = True"),
    ("CommandButton.Accelerator", "Btn.Accelerator = \"G\""),
    ("CommandButton.Font.Bold", "Btn.Font.Bold = True"),
    ("CommandButton.Font.Size", "Btn.Font.Size = 11"),
    ("CommandButton.Enabled", "Btn.Enabled = False"),
    ("CommandButton.Width", "Btn.Width = Btn.Width + 6"),
    ("CheckBox.Value", "Chk.Value = True"),
    ("CheckBox.Caption", "Chk.Caption = \"Checked\""),
    ("CheckBox.Font.Italic", "Chk.Font.Italic = True"),
    ("CheckBox.Font.Size", "Chk.Font.Size = 9"),
    ("CheckBox.Enabled", "Chk.Enabled = False"),
    ("ToggleButton.Value", "Tgl.Value = True"),
    ("ToggleButton.Caption", "Tgl.Caption = \"On\""),
    ("ToggleButton.Font.Bold", "Tgl.Font.Bold = True"),
    ("OptionButton.Value", "Opt1.Value = True"),
    ("OptionButton.Value peer", "Opt2.Value = True"),
    ("OptionButton.GroupName", "Opt2.GroupName = \"Other\""),
    ("OptionButton.Caption", "Opt1.Caption = \"First!\""),
    ("OptionButton.Font.Underline", "Opt1.Font.Underline = True"),
    ("ListBox.AddItem", "Lst.AddItem \"extra\""),
    ("ListBox.ListIndex", "Lst.ListIndex = 1"),
    ("ListBox.TopIndex", "Lst.TopIndex = 1"),
    ("ListBox.MultiSelect", "Lst.MultiSelect = 1"),
    ("ListBox.Selected", "Lst.Selected(2) = True"),
    ("ListBox.ColumnCount", "Lst.ColumnCount = 2"),
    ("ListBox.IntegralHeight", "Lst.IntegralHeight = False"),
    ("ListBox.Height", "Lst.Height = Lst.Height + 11"),
    ("ListBox.BorderStyle", "Lst.BorderStyle = 1"),
    ("ListBox.Font.Bold", "Lst.Font.Bold = True"),
    ("ListBox.Font.Size", "Lst.Font.Size = 12"),
    ("ListBox.Clear", "Lst.Clear"),
    ("ComboBox.AddItem", "Cmb.AddItem \"x\""),
    ("ComboBox.ListIndex", "Cmb.ListIndex = 0"),
    ("ComboBox.Text", "Cmb.Text = \"abc\""),
    ("ComboBox.DropDown", "Cmb.DropDown"),
    ("ComboBox.Font.Bold", "Cmb.Font.Bold = True"),
    ("ComboBox.Font.Size", "Cmb.Font.Size = 10"),
    ("ComboBox.Enabled", "Cmb.Enabled = False"),
    ("ScrollBar.Value", "Scr.Value = 4"),
    ("ScrollBar.Max", "Scr.Max = 50"),
    ("ScrollBar.Min", "Scr.Min = 2"),
    ("ScrollBar.Enabled", "Scr.Enabled = False"),
    ("SpinButton.Value", "Spn.Value = 3"),
    ("SpinButton.Max", "Spn.Max = 20"),
    ("SpinButton.Enabled", "Spn.Enabled = False"),
    ("Image.PictureSizeMode", "Img.PictureSizeMode = 1"),
    ("Image.Width", "Img.Width = Img.Width + 5"),
    ("Image.Visible", "Img.Visible = False"),
    ("Frame.Caption", "Frm.Caption = \"Group!\""),
    ("Frame.Left", "Frm.Left = Frm.Left + 7"),
    ("Frame.Width", "Frm.Width = Frm.Width + 7"),
    ("Frame.Visible", "Frm.Visible = False"),
    ("Frame.Enabled", "Frm.Enabled = False"),
    ("Frame.Font.Bold", "Frm.Font.Bold = True"),
    ("Frame.Font.Size", "Frm.Font.Size = 12"),
    ("FrameChild.Caption", "FrmLbl.Caption = \"inner\""),
    ("FrameChild.Left", "FrmLbl.Left = FrmLbl.Left + 4"),
    ("FrameChild.Font.Bold", "FrmLbl.Font.Bold = True"),
    ("FrameChild.Font.Size", "FrmLbl.Font.Size = 11"),
    ("FrameChild.Enabled", "FrmLbl.Enabled = False"),
    ("FrameChild.Visible", "FrmLbl.Visible = False"),
    ("FrameChildTextBox.Text", "FrmTxt.Text = \"in frame\""),
    ("FrameChildTextBox.Font.Bold", "FrmTxt.Font.Bold = True"),
    ("MultiPage.Value", "Mp.Value = 1"),
    ("MultiPage.Left", "Mp.Left = Mp.Left + 3"),
    ("MultiPage.Width", "Mp.Width = Mp.Width + 3"),
    ("MultiPage.Enabled", "Mp.Enabled = False"),
    ("MultiPage.Visible", "Mp.Visible = False"),
    ("MultiPage.Font.Bold", "Mp.Font.Bold = True"),
    ("MultiPage.Font.Size", "Mp.Font.Size = 11"),
    ("MultiPage.Pages.Add", "Mp.Pages.Add \"Third\""),
    ("Page.Caption", "Mp.Pages.Item(0).Caption = \"Renamed\""),
    ("Page.Enabled", "Mp.Pages.Item(0).Enabled = False"),
    ("Page.Visible", "Mp.Pages.Item(0).Visible = False"),
    ("PageChild.Text", "PgTxt.Text = \"in page\""),
    ("PageChild.Font.Bold", "PgTxt.Font.Bold = True"),
    ("PageChild.Font.Size", "PgTxt.Font.Size = 12"),
    ("PageChild.Enabled", "PgTxt.Enabled = False"),
    ("PageChild.Left", "PgTxt.Left = PgTxt.Left + 2"),
    ("TabStrip.Value", "Tbs.Value = 1"),
    ("TabStrip.Left", "Tbs.Left = Tbs.Left + 3"),
    ("TabStrip.Font.Bold", "Tbs.Font.Bold = True"),
    ("TabStrip.Font.Size", "Tbs.Font.Size = 11"),
    ("TabStrip.Enabled", "Tbs.Enabled = False"),
    ("TabStrip.Tabs.Add", "Tbs.Tabs.Add \"Third\""),
    ("Tab.Caption", "Tbs.Tabs.Item(0).Caption = \"Renamed\""),
    ("Form.Zoom", "F.Zoom = 150"),
    ("Form.Width", "F.Width = F.Width + 20"),
    ("Form.Height", "F.Height = F.Height + 20"),
    ("Controls.Add", "F.Controls.Add \"Forms.Label.1\", \"Late\""),
];

fn sweep_source() -> String {
    let mut cases = String::new();
    for (i, (_, stmt)) in MUTATIONS.iter().enumerate() {
        cases.push_str(&format!("        Case {}\n            {}\n", i + 1, stmt));
    }
    format!(
        r#"Option Explicit
Private F As UserForm
Private Lbl As Label
Private Txt As TextBox
Private Btn As CommandButton
Private Chk As CheckBox
Private Tgl As ToggleButton
Private Opt1 As OptionButtonControl
Private Opt2 As OptionButtonControl
Private Lst As ListBox
Private Cmb As ComboBox
Private Scr As ScrollBar
Private Spn As SpinButton
Private Img As Image
Private Frm As Frame
Private FrmLbl As Label
Private FrmTxt As TextBox
Private Mp As MultiPage
Private PgTxt As TextBox
Private Tbs As TabStrip
Private Sub Place(ByVal C As Object, ByVal L As Single, ByVal T As Single, ByVal W As Single, ByVal H As Single)
    C.Left = L: C.Top = T: C.Width = W: C.Height = H
End Sub
Private Sub CalcFormsHostBuild()
    Set F = New UserForm
    F.Width = 420
    F.Height = 420
    Set Lbl = F.Controls.Add("Forms.Label.1", "Lbl"): Place Lbl, 6, 6, 90, 18: Lbl.Caption = "Label"
    Set Txt = F.Controls.Add("Forms.TextBox.1", "Txt"): Place Txt, 6, 30, 90, 18: Txt.Text = "text"
    Set Btn = F.Controls.Add("Forms.CommandButton.1", "Btn"): Place Btn, 6, 54, 90, 22: Btn.Caption = "Button"
    Set Chk = F.Controls.Add("Forms.CheckBox.1", "Chk"): Place Chk, 6, 80, 90, 18: Chk.Caption = "Check"
    Set Tgl = F.Controls.Add("Forms.ToggleButton.1", "Tgl"): Place Tgl, 6, 102, 90, 22: Tgl.Caption = "Toggle"
    Set Opt1 = F.Controls.Add("Forms.OptionButton.1", "Opt1"): Place Opt1, 6, 128, 90, 18: Opt1.Caption = "One"
    Set Opt2 = F.Controls.Add("Forms.OptionButton.1", "Opt2"): Place Opt2, 6, 150, 90, 18: Opt2.Caption = "Two"
    Set Lst = F.Controls.Add("Forms.ListBox.1", "Lst"): Place Lst, 110, 6, 90, 70
    Lst.AddItem "a": Lst.AddItem "b": Lst.AddItem "c": Lst.AddItem "d"
    Set Cmb = F.Controls.Add("Forms.ComboBox.1", "Cmb"): Place Cmb, 110, 84, 90, 18
    Cmb.AddItem "p": Cmb.AddItem "q"
    Set Scr = F.Controls.Add("Forms.ScrollBar.1", "Scr"): Place Scr, 110, 110, 90, 16
    Set Spn = F.Controls.Add("Forms.SpinButton.1", "Spn"): Place Spn, 110, 132, 18, 30
    Set Img = F.Controls.Add("Forms.Image.1", "Img"): Place Img, 140, 132, 50, 30
    Set Frm = F.Controls.Add("Forms.Frame.1", "Frm"): Place Frm, 210, 6, 190, 100: Frm.Caption = "Group"
    Set FrmLbl = Frm.Controls.Add("Forms.Label.1", "FrmLbl"): Place FrmLbl, 6, 6, 80, 18: FrmLbl.Caption = "in frame"
    Set FrmTxt = Frm.Controls.Add("Forms.TextBox.1", "FrmTxt"): Place FrmTxt, 6, 30, 80, 18
    Set Mp = F.Controls.Add("Forms.MultiPage.1", "Mp"): Place Mp, 210, 114, 190, 100
    Mp.Pages.Add "One": Mp.Pages.Add "Two"
    Set PgTxt = Mp.Pages.Item(0).Controls.Add("Forms.TextBox.1", "PgTxt"): Place PgTxt, 6, 6, 80, 18
    Set Tbs = F.Controls.Add("Forms.TabStrip.1", "Tbs"): Place Tbs, 210, 222, 190, 80
    Tbs.Tabs.Add "A": Tbs.Tabs.Add "B"
End Sub
Private Sub CalcFormsHostPerformInitialize()
End Sub
Private Sub CalcFormsHostRender()
    F.Render 96, 96
End Sub
Public Function MutationCount() As Long
    MutationCount = {count}
End Function
Public Sub Mutate(ByVal N As Long)
    Select Case N
{cases}    End Select
End Sub
"#,
        count = MUTATIONS.len(),
        cases = cases
    )
}

/// Every setter of every control kind (and the container and form relations) leaves the
/// resident scene equal to a full re-render once the predicted invalidations are drained.
#[test]
fn full_rerender_after_each_setter_matches_the_predicted_patch() {
    let (mut runtime, surface) = runtime_with_surface(sweep_source(), "AuditSweep");
    assert!(
        stale_marks(&surface).is_empty(),
        "initial render: {:?}",
        stale_marks(&surface)
    );
    let form = runtime.form();
    let mut failures = Vec::new();
    for (i, (name, _)) in MUTATIONS.iter().enumerate() {
        let before = stale_marks(&surface).len();
        runtime
            .session_mut()
            .invoke_member_values(
                form.clone(),
                "Mutate",
                Some(ProjectMemberKind::Method),
                vec![Variant::from_i32(i as i32 + 1)],
            )
            .unwrap_or_else(|e| panic!("mutation {name}: {}", e.message()));
        runtime
            .render()
            .unwrap_or_else(|e| panic!("render after {name}: {e}"));
        let after = stale_marks(&surface);
        if after.len() > before {
            failures.push(format!("{name}: {}", after[after.len() - 1]));
        }
    }
    assert!(
        audit_ran(&surface) > MUTATIONS.len(),
        "the audit must have re-rendered after incremental frames"
    );
    assert!(
        failures.is_empty(),
        "missed dirty links (changed without being invalidated):\n{}",
        failures.join("\n")
    );
}

fn marks(surface: &SurfaceFactory, prefix: &str) -> usize {
    surface
        .snapshot()
        .unwrap()
        .calls
        .iter()
        .filter(|c| c.starts_with(prefix))
        .count()
}

/// The measured-behaviour forms of the existing corpus (Layout* at 100 and 150 percent, the
/// property, input and keyboard scenarios): each scenario runs with the audit on, then the
/// form renders once more. Any `audit-stale` mark fails; the count of audited frames is
/// reported so a corpus that stopped rendering incrementally cannot pass silently.
#[test]
fn existing_form_corpus_runs_clean_under_the_audit() {
    let jobs: &[(&str, &str, &str)] = &[
        ("oxforms-jbjp.107", "behaviour", "ParityMeasurements"),
        ("oxforms-jbjp.107", "input", "ParityInputMeasurements"),
        ("oxforms-jbjp.109", "keyboard", "ParityKeyboardMeasurements"),
    ];
    let mut audited = 0usize;
    let mut forms = 0usize;
    let mut stale = Vec::new();
    for (bead, dir, member) in jobs {
        let directory = common::evidence(bead).join(dir);
        let mut files: Vec<_> = std::fs::read_dir(&directory)
            .unwrap()
            .map(|e| e.unwrap().path())
            .filter(|p| {
                p.file_name()
                    .and_then(|n| n.to_str())
                    .is_some_and(|n| n.ends_with("-runtime.cls"))
            })
            .collect();
        files.sort();
        for file in files {
            let name = file
                .file_name()
                .unwrap()
                .to_str()
                .unwrap()
                .trim_end_matches("-runtime.cls")
                .replace('-', "");
            let mut source = std::fs::read_to_string(&file).unwrap();
            for control in ["TabsControl", "PagesControl"] {
                for event in ["MouseDown", "MouseUp"] {
                    source = source.replace(
                        &format!("Private Sub {control}_{event}(ByVal Button"),
                        &format!("Private Sub {control}_{event}(ByVal Index As Long, ByVal Button"),
                    );
                }
            }
            let class = file.file_stem().unwrap().to_str().unwrap().replace('-', "");
            let _ = name;
            let (mut runtime, surface) = runtime_with_surface(source, &class);
            let form = runtime.form();
            let outcome = runtime.session_mut().invoke_member_values(
                form,
                member,
                Some(ProjectMemberKind::Method),
                Vec::new(),
            );
            outcome.unwrap_or_else(|e| panic!("{}: {}", file.display(), e.message()));
            runtime.render().unwrap();
            forms += 1;
            audited += marks(&surface, "ProfileMark:audit-ok");
            for mark in stale_marks(&surface) {
                stale.push(format!("{}: {mark}", file.display()));
            }
        }
    }
    println!("audited {audited} incremental frames over {forms} corpus forms");
    assert!(forms >= 10, "corpus forms found: {forms}");
    assert!(
        stale.is_empty(),
        "missed dirty links:\n{}",
        stale.join("\n")
    );
}
