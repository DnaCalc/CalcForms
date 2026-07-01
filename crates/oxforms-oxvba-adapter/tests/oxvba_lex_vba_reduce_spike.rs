//! oxforms-lex: prove a VBA-side REDUCE runs on OxVba vm3 with the intended path
//!
//!   input -> VBA reduce -> effects -> pal Scene
//!
//! The harness builds a vm3 image session with only the `OxSceneBuilder` library module + a
//! self-contained spike form, injects `OxForms.Surface`, and drives interaction by invoking the
//! VBA `Reduce` member with a raw mouse-down point. The VBA side hit-tests the click ITSELF,
//! toggles its `Pressed` state, and re-renders the button (gray up / blue pressed) across the
//! Surface; we read the resident `Scene`'s single `FillRect` colour back and assert it reflects
//! the VBA-decided state change (and that a MISS does not toggle).
//!
//! What this proves: the reduce decision (hit-test + state transition + repaint) can run in VBA
//! on vm3. The harness never imports or invokes `oxforms-core`'s reducer (`reduce`/`FormState`)
//! nor the adapter's historical Rust-reducer-driven `RuntimeRunner` — it drives the VBA reduce
//! directly via the session + Surface. (`oxforms-core` was later deleted in `oxforms-ih6`; this
//! spike remains useful provenance for why the reducer now lives in VBA.)
//!
//! What this does NOT prove (the porting bead's scope): multi-control reduce, the full event
//! spine (keyboard/focus/validation/dispatch ordering), error handling, or per-frame perf — this
//! is minimal single-control feasibility only. See memory oxforms-reducer-home-decision +
//! oxvba-vm3-handover-policy (any vm3 limitation -> an OxVba handover, never a workaround).

use std::path::{Path, PathBuf};
use std::sync::Arc;

use oxforms_oxvba_adapter::surface::{register_surface, SurfaceFactory};
use oxforms_pal::scene::{Paint, Prim};

use oxvba_bundle::ProjectMemberKind;
use oxvba_com::PortableComProjection;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, HostProfileProvider, ProjectRuntimeSession};
use oxvba_runtime::{ObjectRef, Variant};
use oxvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

// Packed 0xRRGGBB faces the spike form paints — must match lex_reduce_spike_form.cls.
const FACE_UP: u32 = 0x0080_8080;
const FACE_PRESSED: u32 = 0x0020_60C0;

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..").join("..")
}

fn module_unit(name: &str, kind: ModuleKind, relative: &str) -> ModuleUnit {
    let path = repo_root().join(relative);
    let source = std::fs::read_to_string(&path)
        .unwrap_or_else(|err| panic!("read {}: {err}", path.display()));
    let mut attributes = ModuleAttributes::named(name);
    attributes.vb_exposed = true;
    attributes.vb_creatable = true;
    ModuleUnit {
        module_name: name.to_string(),
        module_kind: kind,
        attributes,
        source,
    }
}

fn prepare_session(projection: Arc<PortableComProjection>) -> ProjectRuntimeSession {
    let manifest = SymbolProjectManifest {
        project_name: "OxFormsLexReduceSpike".to_string(),
        project_kind: ProjectKind::Library,
        modules: vec![
            module_unit(
                "OxSceneBuilder",
                ModuleKind::Class,
                "vba/oxforms/OxSceneBuilder.cls",
            ),
            module_unit(
                "LexReduceSpikeForm",
                ModuleKind::Class,
                "vba/smoke/fixtures/lex_reduce_spike_form.cls",
            ),
        ],
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
    };

    let program = oxvba_bind::bind_program(&manifest, &oxvba_symbol::CatalogTypeLibResolver)
        .expect("bind lex spike project");
    let bundle = oxvba_oxir::elaborate::elaborate(&program).expect("elaborate lex spike project");

    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::interactive_dev());
    let engine = Engine::new(HostConfig { enable_jit: false }).with_host_profile_provider(profile);
    engine
        .prepare_image_session(oxvba_oxir::OxImage::new(vec![bundle]))
        .expect("prepare lex spike session")
}

/// Read the button face colour (packed 0xRRGGBB) from the resident scene, asserting the spike
/// rendered EXACTLY one `FillRect` — so the readback is unambiguously the button, not whichever
/// fill happened to be first. The asymmetric pressed colour (0x2060C0, R≠G≠B) means this exact
/// comparison also catches any red/blue channel-order regression in the pack/unpack path.
fn button_face(factory: &SurfaceFactory) -> u32 {
    let snap = factory.snapshot().expect("surface snapshot");
    let scene = snap.scene.expect("resident scene after a VBA render");
    let fills: Vec<u32> = scene
        .nodes
        .iter()
        .flat_map(|node| &node.prims)
        .filter_map(|prim| match prim {
            Prim::FillRect {
                paint: Paint::Solid(c),
                ..
            } => Some((u32::from(c.red) << 16) | (u32::from(c.green) << 8) | u32::from(c.blue)),
            _ => None,
        })
        .collect();
    assert_eq!(
        fills.len(),
        1,
        "the spike renders exactly one button FillRect"
    );
    fills[0]
}

/// Invoke the VBA `Reduce(x, y)` member (the VBA-side reducer) and return its Long result
/// (1 = it repainted, 0 = the click missed).
fn reduce(session: &mut ProjectRuntimeSession, form: &ObjectRef, x: i32, y: i32) -> i32 {
    session
        .invoke_member_values(
            form.clone(),
            "Reduce",
            Some(ProjectMemberKind::Method),
            vec![Variant::from_i32(x), Variant::from_i32(y)],
        )
        .expect("invoke VBA Reduce")
        .as_i32()
        .expect("Reduce returns a Long")
}

#[test]
fn vba_side_reduce_runs_on_vm3_with_no_rust_reducer() {
    let projection = Arc::new(PortableComProjection::new());
    // No text shaper needed: the spike paints a solid rect, not captions.
    let factory = Arc::new(SurfaceFactory::new());
    register_surface(&projection, factory.clone());
    let mut session = prepare_session(projection);

    let form = session
        .create_class_instance("LexReduceSpikeForm")
        .expect("create the spike form on vm3");

    // Initial VBA render: the unpressed (gray) face.
    session
        .invoke_member_values(
            form.clone(),
            "Build",
            Some(ProjectMemberKind::Method),
            Vec::new(),
        )
        .expect("invoke VBA Build");
    assert_eq!(
        button_face(&factory),
        FACE_UP,
        "the initial VBA render is the unpressed face"
    );

    // A HIT inside the button: VBA hit-tests, toggles Pressed, and re-renders.
    assert_eq!(
        reduce(&mut session, &form, 40, 40),
        1,
        "a hit reduce repaints"
    );
    assert_eq!(
        button_face(&factory),
        FACE_PRESSED,
        "the VBA reduce toggled Pressed and re-rendered the pressed face"
    );

    // A MISS outside the button: VBA rejects it, no toggle, scene unchanged.
    assert_eq!(
        reduce(&mut session, &form, 5, 5),
        0,
        "a miss reduce reports no repaint"
    );
    assert_eq!(
        button_face(&factory),
        FACE_PRESSED,
        "a missed click left the pressed face unchanged"
    );

    // A second HIT toggles back to unpressed.
    assert_eq!(
        reduce(&mut session, &form, 40, 40),
        1,
        "a second hit repaints"
    );
    assert_eq!(
        button_face(&factory),
        FACE_UP,
        "the second hit toggled Pressed back and re-rendered the unpressed face"
    );
}
