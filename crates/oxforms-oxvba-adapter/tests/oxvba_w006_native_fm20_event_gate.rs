//! W007 native FM20 class-event gate (oxforms-4pn.2).
//!
//! Proves that native FM20-named class events (Click, MouseDown, MouseUp,
//! MouseMove) dispatch through the OxVba package-session RaiseEvent/WithEvents
//! path WITHOUT the W005 generic `Dispatched` carrier, against the pinned OxVba
//! baseline. This is the gate the W007 runtime path depends on; the earlier
//! oxforms-0a0.2 attempt was reverted because the baseline at the time faulted
//! before handler entry.

use std::path::{Path, PathBuf};

use oxvba_bundle::ProjectMemberKind;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig};
use oxvba_runtime::Variant;
use oxvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..").join("..")
}

fn fixture_source(name: &str) -> String {
    std::fs::read_to_string(
        repo_root()
            .join("vba")
            .join("smoke")
            .join("fixtures")
            .join(name),
    )
    .unwrap_or_else(|err| panic!("read fixture {name}: {err}"))
}

fn exposed_class(name: &str, source: String) -> ModuleUnit {
    let mut attributes = ModuleAttributes::named(name);
    attributes.vb_exposed = true;
    attributes.vb_creatable = true;
    ModuleUnit {
        module_name: name.to_string(),
        module_kind: ModuleKind::Class,
        attributes,
        source,
    }
}

fn prepare_session() -> oxvba_host::ProjectRuntimeSession {
    let manifest = SymbolProjectManifest {
        project_name: "W006NativeFm20EventGate".to_string(),
        project_kind: ProjectKind::Library,
        modules: vec![
            exposed_class(
                "W006NativeFm20EventSource",
                fixture_source("w006_native_fm20_event_source.cls"),
            ),
            exposed_class(
                "W006NativeFm20EventSink",
                fixture_source("w006_native_fm20_event_sink.cls"),
            ),
        ],
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
    };
    let program = oxvba_bind::bind_program(&manifest, &oxvba_symbol::CatalogTypeLibResolver)
        .expect("bind native FM20 event gate fixture");
    let bundle = oxvba_oxir::elaborate::elaborate(&program)
        .expect("elaborate native FM20 event gate fixture");

    let mut engine = Engine::new(HostConfig { enable_jit: false });
    engine.set_host_policy(HostPolicy::interactive_dev());
    engine
        .prepare_image_session(oxvba_oxir::OxImage::new(vec![bundle]))
        .expect("prepare native FM20 event gate session")
}

#[test]
fn native_fm20_class_events_dispatch_through_withevents_without_carrier() {
    let mut session = prepare_session();
    let source = session
        .create_class_instance("W006NativeFm20EventSource")
        .expect("create native FM20 event source");
    let sink = session
        .create_class_instance("W006NativeFm20EventSink")
        .expect("create native FM20 event sink");
    session
        .invoke_member_values(
            sink.clone(),
            "Attach",
            Some(ProjectMemberKind::Method),
            vec![Variant::from_object_ref(source.clone())],
        )
        .expect("attach native WithEvents sink to source");

    // Native FM20 scalar argument shapes: Button/Shift As Integer, X/Y As Single.
    let raises: [(&str, Vec<Variant>); 5] = [
        (
            "RaiseMouseDown",
            vec![
                Variant::from_i16(1),
                Variant::from_i16(0),
                Variant::from_f32(4.0),
                Variant::from_f32(8.0),
            ],
        ),
        (
            "RaiseMouseUp",
            vec![
                Variant::from_i16(1),
                Variant::from_i16(0),
                Variant::from_f32(4.0),
                Variant::from_f32(8.0),
            ],
        ),
        (
            "RaiseMouseMove",
            vec![
                Variant::from_i16(0),
                Variant::from_i16(0),
                Variant::from_f32(4.0),
                Variant::from_f32(8.0),
            ],
        ),
        ("RaiseChange", Vec::new()),
        ("RaiseClick", Vec::new()),
    ];

    for (member, args) in raises {
        session
            .invoke_member_values(
                source.clone(),
                member,
                Some(ProjectMemberKind::Method),
                args,
            )
            .unwrap_or_else(|err| panic!("native {member} dispatch failed: {}", err.message()));
    }

    let log = session
        .invoke_member_values(
            sink,
            "LogText",
            Some(ProjectMemberKind::PropertyGet),
            Vec::new(),
        )
        .expect("read native handler log")
        .as_bstr()
        .expect("handler log should be a string")
        .as_str();
    let rows: Vec<_> = log.lines().collect();

    assert_eq!(
        rows,
        vec![
            "MouseDown|Button=1;Shift=0;X=4;Y=8",
            "MouseUp|Button=1;Shift=0;X=4;Y=8",
            "MouseMove|Button=0;Shift=0;X=4;Y=8",
            "Change|no arguments",
            "Click|no arguments",
        ],
        "native FM20-named WithEvents handlers should fire in dispatch order through OxVba"
    );
}
