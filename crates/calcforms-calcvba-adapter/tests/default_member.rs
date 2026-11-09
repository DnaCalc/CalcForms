//! The FM20 default members (memid 0) work through plain assignment and plain reads (round 13).
//! The canonical identity is the pinned typelib fact (Label.Caption; Value on the input and scroll
//! controls); here each control must give the same result through the bare variable as through the
//! explicit member, and a Let on the bare variable must land in the member.
use calcforms_calcvba_adapter::{
    host_services::HostServices, office::WorkbookForm, runtime::OxRuntime,
};
use calcforms_pal::scene::StubShaper;
use calcvba_bundle::ProjectMemberKind;
use calcvba_runtime::{ObjectRef, Variant};
use calcvba_symbol::manifest::{ModuleAttributes, ModuleKind, ModuleUnit};
use std::{path::Path, sync::Arc};

const DRIVER: &str = r#"Option Explicit
Private Lb As MSForms.Label
Private Tx As MSForms.TextBox
Private Ck As MSForms.CheckBox
Private Tg As MSForms.ToggleButton
Private Sb As MSForms.ScrollBar
Private Sp As MSForms.SpinButton
Private Ls As MSForms.ListBox
Private Cb As MSForms.ComboBox
Public Sub Attach()
    Set Lb = PlannerForm.Controls.Add("Forms.Label.1", "DefLabel")
    Set Tx = PlannerForm.Controls.Add("Forms.TextBox.1", "DefText")
    Set Ck = PlannerForm.Controls.Add("Forms.CheckBox.1", "DefCheck")
    Set Tg = PlannerForm.Controls.Add("Forms.ToggleButton.1", "DefToggle")
    Set Sb = PlannerForm.Controls.Add("Forms.ScrollBar.1", "DefScroll")
    Set Sp = PlannerForm.Controls.Add("Forms.SpinButton.1", "DefSpin")
    Set Ls = PlannerForm.Controls.Add("Forms.ListBox.1", "DefList")
    Set Cb = PlannerForm.Controls.Add("Forms.ComboBox.1", "DefCombo")
    Sb.Max = 50
    Sp.Max = 50
    Ls.AddItem "alpha"
    Ls.AddItem "beta"
    Cb.AddItem "one"
    Cb.AddItem "two"
End Sub
Public Function Run() As String
    Dim S As String, V As Variant, N As Long, T As String
    Lb = "caption via default"
    S = S & "Label:" & Lb.Caption & "|"
    T = Lb
    S = S & T & "|"
    Tx = "text via default"
    S = S & "TextBox:" & Tx.Value & "|"
    T = Tx
    S = S & T & "|"
    Ck = True
    S = S & "CheckBox:" & CStr(Ck.Value) & "|"
    V = Ck
    S = S & CStr(V) & "|"
    Tg = True
    S = S & "Toggle:" & CStr(Tg.Value) & "|"
    V = Tg
    S = S & CStr(V) & "|"
    Sb = 17
    S = S & "Scroll:" & CStr(Sb.Value) & "|"
    N = Sb
    S = S & CStr(N) & "|"
    Sp = 9
    S = S & "Spin:" & CStr(Sp.Value) & "|"
    N = Sp
    S = S & CStr(N) & "|"
    Ls = "alpha"
    S = S & "ListIdx:" & CStr(Ls.ListIndex) & "|"
    Ls.ListIndex = 1
    T = Ls
    S = S & "List:" & T & "|" & Ls.Value & "|"
    Cb = "one"
    S = S & "ComboText:" & Cb.Text & "|"
    Cb.Text = "two"
    T = Cb
    S = S & "Combo:" & T & "|" & Cb.Value
    Run = S
End Function
"#;

fn call(runtime: &mut OxRuntime, driver: &ObjectRef, name: &str) -> String {
    runtime
        .session_mut()
        .invoke_member_values(
            driver.clone(),
            name,
            Some(ProjectMemberKind::Method),
            Vec::<Variant>::new(),
        )
        .unwrap()
        .as_bstr()
        .map(|text| text.as_str())
        .unwrap_or_default()
}

#[test]
fn default_members_read_and_assign_through_the_bare_variable() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let mut form = WorkbookForm::open(
        root.join("fixtures/workbooks/planner/planner.xlsm"),
        "PlannerForm",
    )
    .unwrap();
    form.project_modules.push(ModuleUnit {
        module_name: "DefaultMemberDriver".into(),
        module_kind: ModuleKind::Class,
        attributes: ModuleAttributes::named("DefaultMemberDriver"),
        source: DRIVER.into(),
    });
    let (mut runtime, _) = form
        .runtime_with_entry(
            Arc::new(StubShaper),
            HostServices::headless(),
            Some("OpenPlanner"),
        )
        .unwrap();
    let driver = runtime
        .session_mut()
        .create_class_instance("DefaultMemberDriver")
        .unwrap();
    call(&mut runtime, &driver, "Attach");
    let result = call(&mut runtime, &driver, "Run");
    assert_eq!(
        result,
        "Label:caption via default|caption via default|\
TextBox:text via default|text via default|\
CheckBox:True|True|\
Toggle:True|True|\
Scroll:17|17|\
Spin:9|9|\
ListIdx:0|List:beta|beta|\
ComboText:one|Combo:two|two"
    );
}
