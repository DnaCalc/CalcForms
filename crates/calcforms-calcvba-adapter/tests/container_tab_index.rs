//! Controls.Add TabIndex sequence matches native Excel for the LayoutContainers control set
//! (oxforms-jbjp.131): an Image has no TabIndex and takes no slot.
use calcforms_calcvba_adapter::{host_services::HostServices, office::WorkbookForm};
use calcforms_pal::scene::StubShaper;
use calcvba_bundle::ProjectMemberKind;
use calcvba_symbol::manifest::{ModuleAttributes, ModuleKind, ModuleUnit};
use serde_json::Value;
use std::{collections::BTreeSet, path::Path, sync::Arc};

const DRIVER: &str = r#"Option Explicit
Public Function Indices() As String
    Dim F As UserForm, C As Object, S As String
    Set F = New UserForm
    Set C = F.Controls.Add("Forms.Frame.1", "Group")
    S = S & "Group:" & CStr(C.Core.TabIndex) & ";"
    Set C = F.Controls.Add("Forms.Image.1", "Picture")
    Set C = F.Controls.Add("Forms.SpinButton.1", "Spinner")
    S = S & "Spinner:" & CStr(C.Core.TabIndex) & ";"
    Set C = F.Controls.Add("Forms.ScrollBar.1", "Slider")
    S = S & "Slider:" & CStr(C.Core.TabIndex) & ";"
    Set C = F.Controls.Add("Forms.TabStrip.1", "TabsControl")
    S = S & "TabsControl:" & CStr(C.Core.TabIndex) & ";"
    Set C = F.Controls.Add("Forms.MultiPage.1", "PagesControl")
    S = S & "PagesControl:" & CStr(C.Core.TabIndex) & ";"
    Set C = F.Controls.Item("Group").Controls.Add("Forms.Label.1", "NestedLabel")
    S = S & "NestedLabel:" & CStr(C.Core.TabIndex) & ";"
    Set C = F.Controls.Item("Group").Controls.Add("Forms.TextBox.1", "NestedInput")
    S = S & "NestedInput:" & CStr(C.Core.TabIndex) & ";"
    Indices = S
End Function
"#;

#[test]
fn controls_add_tab_indices_skip_image_like_native_excel() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let native: Value = serde_json::from_slice(
        &std::fs::read(root.join(
            "docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.131/native-round12.json",
        ))
        .unwrap(),
    )
    .unwrap();
    // Native entries are "Name:Type:Index;"; the Image entry reads an error and is not in
    // the sequence. Designer-built and Controls.Add forms agree natively.
    let indices = |text: &str| -> BTreeSet<String> {
        text.split(['|', ';'])
            .filter_map(|entry| {
                let entry = entry
                    .trim_start_matches("form=")
                    .trim_start_matches("group=");
                let parts: Vec<&str> = entry.split(':').collect();
                (parts.len() == 3 && !parts[2].starts_with("err"))
                    .then(|| format!("{}:{}", parts[0], parts[2]))
            })
            .collect()
    };
    let expected = indices(native["tabs"]["runtime"].as_str().unwrap());
    assert_eq!(
        expected,
        indices(native["tabs"]["design"].as_str().unwrap())
    );
    assert!(expected.contains("TabsControl:3") && expected.contains("PagesControl:4"));

    let mut form = WorkbookForm::open(
        root.join("fixtures/workbooks/planner/planner.xlsm"),
        "PlannerForm",
    )
    .unwrap();
    form.project_modules.push(ModuleUnit {
        module_name: "TabIndexDriver".into(),
        module_kind: ModuleKind::Class,
        attributes: ModuleAttributes::named("TabIndexDriver"),
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
        .create_class_instance("TabIndexDriver")
        .unwrap();
    let text = runtime
        .session_mut()
        .invoke_member_values(driver, "Indices", Some(ProjectMemberKind::Method), vec![])
        .unwrap()
        .as_bstr()
        .unwrap()
        .as_str();
    let actual: BTreeSet<String> = text
        .split(';')
        .filter(|entry| !entry.is_empty())
        .map(str::to_string)
        .collect();
    assert_eq!(actual, expected, "{text}");
}
