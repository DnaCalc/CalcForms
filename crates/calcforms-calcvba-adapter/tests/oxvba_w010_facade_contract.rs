//! Executable boundary probes, not the production MSForms implementation.
//! Small fixtures isolate the compiler/runtime mechanisms required
//! by .6; later implementation beads must test the real library separately.

use calcvba_bundle::ProjectMemberKind;
use calcvba_engine::{Engine, HostConfig};
use calcvba_hal::model::HostPolicy;
use calcvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, ProjectReference,
    ReferencedProjectManifest, SymbolProjectManifest,
};

fn class(name: &str, source: &str) -> ModuleUnit {
    let mut attributes = ModuleAttributes::named(name);
    attributes.vb_exposed = true;
    attributes.vb_creatable = true;
    ModuleUnit {
        module_name: name.into(),
        module_kind: ModuleKind::Class,
        attributes,
        source: source.into(),
    }
}

fn library() -> Vec<ModuleUnit> {
    vec![
        class(
            "Label",
            r#"
Option Explicit
Private mCaption As String
Public Property Get Caption() As String
    Caption = mCaption
End Property
Attribute Caption.VB_UserMemId = 0
Public Property Let Caption(ByVal value As String)
    mCaption = value
End Property
Friend Function RuntimeDispatch(ByVal opcode As Long) As Long
    RuntimeDispatch = opcode + 100
End Function
Public Function CheckInternalBridge() As Long
    CheckInternalBridge = RuntimeDispatch(7)
End Function
"#,
        ),
        // Deliberately synthetic Variant storage to distinguish put and putref
        // on one name. TextBox.Value has no canonical putref; do not present this
        // helper as an MSForms public type or its behavior as control parity.
        class(
            "SetterMechanismProbe",
            r#"
Option Explicit
Private stored As Variant
Public Property Get Value() As Variant
    If IsObject(stored) Then
        Set Value = stored
    Else
        Value = stored
    End If
End Property
Attribute Value.VB_UserMemId = 0
Public Property Let Value(ByVal value As Variant)
    stored = value
End Property
Public Property Set Value(ByVal value As Variant)
    Set stored = value
End Property
"#,
        ),
    ]
}

fn projects(body: &str) -> Vec<SymbolProjectManifest> {
    let modules = library();
    vec![
        SymbolProjectManifest {
            project_name: "MSForms".into(),
            project_kind: ProjectKind::Library,
            modules: modules.clone(),
            references: vec![],
            reference_projects: vec![],
            conditional_constants: Default::default(),
            conditional_compilation_target: Default::default(),
        },
        SymbolProjectManifest {
            project_name: "UnchangedClient".into(),
            project_kind: ProjectKind::Source,
            modules: vec![class("Client", body)],
            references: vec![ProjectReference::Project {
                referenced_project_name: "MSForms".into(),
            }],
            reference_projects: vec![ReferencedProjectManifest {
                project_name: "MSForms".into(),
                project_kind: ProjectKind::Library,
                modules,
            }],
            conditional_constants: Default::default(),
            conditional_compilation_target: Default::default(),
        },
    ]
}

fn run_result(body: &str) -> Result<i32, String> {
    let programs =
        calcvba_bind::bind_projects(&projects(body), &calcvba_symbol::CatalogTypeLibResolver)
            .expect("bind MSForms and unchanged client as separate projects");
    let bundles = programs
        .iter()
        .map(|program| calcvba_oxir::elaborate::elaborate(program).expect("elaborate"))
        .collect();
    let mut engine = Engine::new(HostConfig::vm3());
    engine.set_host_policy(HostPolicy::default());
    let mut session = engine
        .prepare_image_session(calcvba_oxir::OxImage::new(bundles))
        .expect("link reference closure");
    let client = session
        .create_class_instance("Client")
        .expect("create client");
    session
        .invoke_member_values(client, "Probe", Some(ProjectMemberKind::Method), vec![])
        .map(|value| value.as_i32().expect("Long result"))
        .map_err(|error| error.message().to_string())
}

#[test]
fn exact_msforms_reference_and_explicit_member_execute() {
    assert_eq!(
        run_result(
            r#"
Public Function Probe() As Long
    Dim label As MSForms.Label
    Set label = New MSForms.Label
    label.Caption = "unchanged"
    If label.Caption = "unchanged" Then Probe = label.CheckInternalBridge()
End Function
"#
        )
        .expect("qualified reference and explicit member"),
        107
    );
}

#[test]
fn discrepancy_d006_01_qualified_default_member_is_not_executed() {
    // This locks down the observed blocker, NOT compatibility. The required
    // result is Ok(107). Replace this discrepancy assertion when CalcVBA fixes it.
    let error = run_result(
        r#"
Public Function Probe() As Long
    Dim label As MSForms.Label
    Set label = New MSForms.Label
    label.Caption = "unchanged"
    Dim text As String
    text = label
    If text = "unchanged" Then Probe = label.CheckInternalBridge()
End Function
"#,
    )
    .expect_err("D006-01 changed; rerun acceptance and update the handover");
    assert!(
        error.contains("error 13: cannot convert Object to String"),
        "{error}"
    );
}

#[test]
fn put_and_putref_preserve_value_and_object_identity() {
    assert_eq!(
        run_result(
            r#"
Public Function Probe() As Long
    Dim box As MSForms.SetterMechanismProbe
    Set box = New MSForms.SetterMechanismProbe
    box.Value = 42
    If box.Value = 42 Then Probe = 1
    Dim label As MSForms.Label
    Set label = New MSForms.Label
    Set box.Value = label
    Dim returnedObject As Object
    Set returnedObject = box.Value
    If returnedObject Is label Then Probe = Probe + 2
    label.Caption = "same instance"
    If returnedObject.Caption = "same instance" Then Probe = Probe + 4
End Function
"#
        )
        .expect("Let versus Set and object identity"),
        7
    );
}

#[test]
fn unqualified_referenced_default_member_executes() {
    assert_eq!(
        run_result(
            r#"
Public Function Probe() As Long
    Dim label As Label
    Set label = New MSForms.Label
    label.Caption = "unchanged"
    Dim text As String
    text = label
    If text = "unchanged" Then Probe = 107
End Function
"#,
        )
        .expect("unqualified reference isolates the qualified-name discrepancy"),
        107
    );
}

#[test]
fn discrepancy_d006_02_friend_bridge_leaks_to_referencing_project() {
    // Required: inaccessible member (bind error / error 438 for Object calls).
    // Observed on the pinned baseline: the external call succeeds. This is
    // evidence against using Friend as a sufficient production boundary.
    assert_eq!(
        run_result(
            r#"
Public Function Probe() As Long
    Dim label As MSForms.Label
    Set label = New MSForms.Label
    Probe = label.RuntimeDispatch(7)
End Function
"#
        )
        .expect("D006-02 changed; rerun acceptance and update the handover"),
        107
    );
}
