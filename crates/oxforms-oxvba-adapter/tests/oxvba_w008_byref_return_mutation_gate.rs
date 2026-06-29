//! W008 Return* helper-mutation gate (oxforms-esq.1).
//!
//! Native FM20 events that let a handler veto/alter behavior carry a mutable
//! helper OBJECT -- e.g. KeyDown(KeyCode As MSForms.ReturnInteger) and
//! QueryClose(Cancel As MSForms.ReturnBoolean), both COM objects exposing a
//! settable .Value -- where the handler writes arg.Value and the raiser reads
//! the mutated value back. oxforms-4pn.2 proved native dispatch with scalar
//! IN-args; this gate proves the missing piece: a Return*-shaped helper passed
//! into the event and mutated by the WithEvents handler is read back by the
//! raiser through the OxVba RaiseEvent/invoke_member_values path (the same
//! shared object instance throughout) -- the readback the runtime needs for
//! Cancel/KeyCode helper-mutation semantics.
//!
//! Scope / non-claims: Return* are OBJECTS, so this proves reference-shared
//! .Value mutation (the real mechanism), NOT VBA ByRef-SCALAR copyback (not
//! exercised). The helper is a repo-owned stand-in (W008ReturnValue, a project
//! class); the real MSForms.ReturnInteger/ReturnBoolean COM types crossing the
//! foreign-COM boundary are not exercised here. The object-.Value-mutation
//! mechanism this proves is not a current OxVba blocker; a regression on a real
//! signature outside this scope would be a fresh OxVba question.

use std::path::{Path, PathBuf};

use oxvba_bundle::ProjectMemberKind;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig};
use oxvba_runtime::{ObjectRef, Variant};
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

fn prepare_session() -> oxvba_host::Vm3RuntimeSession {
    let manifest = SymbolProjectManifest {
        project_name: "W008ByRefReturnMutationGate".to_string(),
        project_kind: ProjectKind::Library,
        modules: vec![
            exposed_class("W008ReturnValue", fixture_source("w008_return_value.cls")),
            exposed_class(
                "W008ReturnMutationSource",
                fixture_source("w008_return_mutation_source.cls"),
            ),
            exposed_class(
                "W008ReturnMutationSink",
                fixture_source("w008_return_mutation_sink.cls"),
            ),
        ],
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
    };
    let program = oxvba_bind::bind_program(&manifest, &oxvba_symbol::CatalogTypeLibResolver)
        .expect("bind W008 ByRef return mutation gate fixture");
    let bundle = oxvba_oxir::elaborate::elaborate(&program)
        .expect("elaborate W008 ByRef return mutation gate fixture");

    let mut engine = Engine::new(HostConfig { enable_jit: false });
    engine.set_host_policy(HostPolicy::interactive_dev());
    engine
        .prepare_image_session(oxvba_oxir::OxImage::new(vec![bundle]))
        .expect("prepare W008 ByRef return mutation gate session")
}

#[test]
fn byref_return_helper_mutation_is_read_back_through_dispatch() {
    let mut session = prepare_session();
    let source = session
        .create_class_instance("W008ReturnMutationSource")
        .expect("create W008 return mutation source");
    let sink = session
        .create_class_instance("W008ReturnMutationSink")
        .expect("create W008 return mutation sink");
    // A second, sink-less source is the control: with no handler attached, the
    // helper must keep its value (proves the readback reflects real mutation, not
    // a constant).
    let unattached = session
        .create_class_instance("W008ReturnMutationSource")
        .expect("create unattached W008 return mutation source");
    session
        .invoke_member_values(
            sink,
            "Attach",
            Some(ProjectMemberKind::Method),
            vec![Variant::from_object_ref(source.clone())],
        )
        .expect("attach WithEvents sink to source");

    // Helper: raise an event carrying a fresh Return* helper, then read its
    // .Value back after the handler (if any) has run.
    let raise_and_read = |session: &mut oxvba_host::Vm3RuntimeSession,
                          raiser: &ObjectRef,
                          member: &str,
                          mut args: Vec<Variant>|
     -> i32 {
        let value = session
            .create_class_instance("W008ReturnValue")
            .expect("create W008 return value helper");
        let mut full_args = vec![Variant::from_object_ref(value.clone())];
        full_args.append(&mut args);
        session
            .invoke_member_values(
                raiser.clone(),
                member,
                Some(ProjectMemberKind::Method),
                full_args,
            )
            .unwrap_or_else(|err| panic!("{member} dispatch failed: {}", err.message()));
        session
            .invoke_member_values(
                value,
                "Value",
                Some(ProjectMemberKind::PropertyGet),
                Vec::new(),
            )
            .expect("read Return* helper .Value")
            .as_i32()
            .expect("Return* helper .Value should be a Long")
    };

    // KeyDown handler swallows the key: KeyCode starts 65, handler sets it to 0.
    let swallowed = raise_and_read(
        &mut session,
        &source,
        "RaiseKeyDownLike",
        vec![Variant::from_i32(65), Variant::from_i16(0)],
    );
    assert_eq!(
        swallowed, 0,
        "KeyDown handler should swallow KeyCode via Return* helper mutation read back through dispatch"
    );

    // QueryClose handler vetoes: Cancel starts 0, handler sets it to -1.
    let canceled = raise_and_read(
        &mut session,
        &source,
        "RaiseQueryCloseLike",
        vec![Variant::from_i32(0)],
    );
    assert_eq!(
        canceled, -1,
        "QueryClose handler should set Cancel via Return* helper mutation read back through dispatch"
    );

    // Control: no attached handler, so the helper keeps its start value.
    let untouched = raise_and_read(
        &mut session,
        &unattached,
        "RaiseKeyDownLike",
        vec![Variant::from_i32(65), Variant::from_i16(0)],
    );
    assert_eq!(
        untouched, 65,
        "with no attached handler the Return* helper keeps its start value (readback is real)"
    );
}
