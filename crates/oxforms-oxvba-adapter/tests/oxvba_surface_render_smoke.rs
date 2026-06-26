//! W007 self-render slice end to end on OxVba (oxforms-rq5 step 4).
//!
//! Proves the full Scene rendering spine across the real VBA↔Rust boundary:
//!
//! - the OxForms VBA controls paint themselves in immediate mode into an
//!   `OxSceneBuilder` (face fill + 3D edge + text, resolved through `OxTheme` and
//!   the `OxControlCore` appearance band);
//! - the form serializes one batched `ScenePatch` and crosses the injected
//!   `OxForms.Surface` exactly once via `BeginScene` + `SubmitPatch`;
//! - Rust retains the patched primitives as a control-blind `Scene` and renders it
//!   through the headless reference.
//!
//! The assertion is the rendering-architecture keystone invariant (c) across the
//! boundary: the framebuffer produced from the VBA-authored, JSON-marshalled,
//! patch-applied scene is byte-identical (by hash) to the same scene built directly
//! in Rust from first principles. Text prims are part of the patch but are headless
//! no-ops, so the expected scene carries only the rasterized prims (fills + edges).

use std::path::{Path, PathBuf};
use std::sync::Arc;

use oxforms_oxvba_adapter::surface::{register_surface, SurfaceFactory};
use oxforms_pal::input::DpiScale;
use oxforms_pal::scene::{
    render_headless_hash, EdgeBorder, EdgeEffect, FontId, NodeEdit, NodeId, Paint, Prim, RectF,
    Scene, SceneNode, ScenePatch, StubShaper,
};
use oxforms_pal::{Color, SurfaceSize};
use oxforms_pal_win::{load_ui_font, render_scene_to_rgba, AbGlyphShaper, FontTable};

use oxvba_bundle::{BundlePackage, ProjectMemberKind};
use oxvba_com::PortableComProjection;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, HostProfileProvider};
use oxvba_runtime::ObjectRef;
use oxvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..").join("..")
}

fn read_source(relative: &str) -> String {
    let path = repo_root().join(relative);
    std::fs::read_to_string(&path).unwrap_or_else(|err| panic!("read {}: {err}", path.display()))
}

fn module_unit(name: &str, kind: ModuleKind, relative: &str) -> ModuleUnit {
    let mut attributes = ModuleAttributes::named(name);
    attributes.vb_exposed = true;
    attributes.vb_creatable = true;
    ModuleUnit {
        module_name: name.to_string(),
        module_kind: kind,
        attributes,
        source: read_source(relative),
    }
}

fn prepare_session(projection: Arc<PortableComProjection>) -> oxvba_host::ProjectRuntimeSession {
    let manifest = SymbolProjectManifest {
        project_name: "W007SurfaceRender".to_string(),
        project_kind: ProjectKind::Library,
        modules: vec![
            module_unit(
                "OxFormsModel",
                ModuleKind::Procedural,
                "vba/oxforms/OxFormsModel.bas",
            ),
            module_unit(
                "IOxControl",
                ModuleKind::Class,
                "vba/oxforms/IOxControl.cls",
            ),
            module_unit(
                "IOxControlHost",
                ModuleKind::Class,
                "vba/oxforms/IOxControlHost.cls",
            ),
            module_unit(
                "OxControlCore",
                ModuleKind::Class,
                "vba/oxforms/OxControlCore.cls",
            ),
            module_unit(
                "OxReturnInteger",
                ModuleKind::Class,
                "vba/oxforms/OxReturnInteger.cls",
            ),
            module_unit(
                "OxReturnBoolean",
                ModuleKind::Class,
                "vba/oxforms/OxReturnBoolean.cls",
            ),
            module_unit("Label", ModuleKind::Class, "vba/oxforms/Label.cls"),
            module_unit("TextBox", ModuleKind::Class, "vba/oxforms/TextBox.cls"),
            module_unit(
                "CommandButton",
                ModuleKind::Class,
                "vba/oxforms/CommandButton.cls",
            ),
            module_unit(
                "OxUserForm",
                ModuleKind::Class,
                "vba/oxforms/OxUserForm.cls",
            ),
            module_unit("OxTheme", ModuleKind::Procedural, "vba/oxforms/OxTheme.bas"),
            module_unit(
                "OxControlPaint",
                ModuleKind::Procedural,
                "vba/oxforms/OxControlPaint.bas",
            ),
            module_unit(
                "OxSceneBuilder",
                ModuleKind::Class,
                "vba/oxforms/OxSceneBuilder.cls",
            ),
            module_unit(
                "RenderProbeForm",
                ModuleKind::Class,
                "vba/smoke/fixtures/render_scene_probe_form.cls",
            ),
            module_unit(
                "AutoSizeDemoForm",
                ModuleKind::Class,
                "vba/smoke/fixtures/autosize_demo_form.cls",
            ),
            module_unit(
                "InvalidationDemoForm",
                ModuleKind::Class,
                "vba/smoke/fixtures/invalidation_demo_form.cls",
            ),
        ],
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
    };

    let program = oxvba_bind::bind_program(&manifest, &oxvba_symbol::CatalogTypeLibResolver)
        .expect("bind OxForms render project");
    let bundle = oxvba_bundle::linearize(&program).expect("linearize OxForms render project");

    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::interactive_dev());
    let engine = Engine::new(HostConfig { enable_jit: false }).with_host_profile_provider(profile);
    engine
        .prepare_bundle_package_session(BundlePackage::single(bundle))
        .expect("prepare OxForms render session")
}

/// The demo form rebuilt directly in Rust from first principles. Only the prims the
/// headless reference rasterizes (fills + edges) are needed for the framebuffer
/// hash; text prims that the VBA scene also carries are headless no-ops.
fn expected_demo_framebuffer_hash() -> u64 {
    let white = Color::rgba(0xff, 0xff, 0xff, 0xff);
    let shadow = Color::rgba(0x80, 0x80, 0x80, 0xff);

    let mut root = SceneNode::new(NodeId(0));
    root.bounds = RectF::new(0.0, 0.0, 200.0, 120.0);
    root.children = vec![NodeId(1), NodeId(2), NodeId(3)];
    root.prims = vec![Prim::FillRect {
        rect: RectF::new(0.0, 0.0, 200.0, 120.0),
        paint: Paint::Solid(Color::rgba(0xf0, 0xf0, 0xf0, 0xff)),
    }];

    let mut input = SceneNode::new(NodeId(1));
    input.parent = Some(NodeId(0));
    input.bounds = RectF::new(12.0, 12.0, 120.0, 18.0);
    input.prims = vec![
        Prim::FillRect {
            rect: RectF::new(12.0, 12.0, 120.0, 18.0),
            paint: Paint::Solid(white),
        },
        Prim::DrawEdge {
            rect: RectF::new(12.0, 12.0, 120.0, 18.0),
            effect: EdgeEffect::Sunken,
            border: EdgeBorder::ALL,
            light: white,
            shadow,
        },
    ];

    let mut button = SceneNode::new(NodeId(2));
    button.parent = Some(NodeId(0));
    button.bounds = RectF::new(140.0, 12.0, 48.0, 20.0);
    button.prims = vec![
        Prim::FillRect {
            rect: RectF::new(140.0, 12.0, 48.0, 20.0),
            paint: Paint::Solid(Color::rgba(0xdc, 0xdc, 0xdc, 0xff)),
        },
        Prim::DrawEdge {
            rect: RectF::new(140.0, 12.0, 48.0, 20.0),
            effect: EdgeEffect::Raised,
            border: EdgeBorder::ALL,
            light: white,
            shadow,
        },
    ];

    let mut label = SceneNode::new(NodeId(3));
    label.parent = Some(NodeId(0));
    label.bounds = RectF::new(12.0, 44.0, 176.0, 18.0);
    label.prims = vec![Prim::FillRect {
        rect: RectF::new(12.0, 44.0, 176.0, 18.0),
        paint: Paint::Solid(Color::rgba(0x20, 0x70, 0xc0, 0xff)),
    }];

    let mut scene = Scene::new(
        SurfaceSize::new(200, 120),
        DpiScale::new(96.0, 96.0),
        NodeId(0),
    );
    scene.nodes = vec![root, input, button, label];
    scene.recompute_frame_hash();
    render_headless_hash(&scene)
}

fn get_string(
    session: &mut oxvba_host::ProjectRuntimeSession,
    object: ObjectRef,
    member: &str,
) -> String {
    session
        .invoke_member_values(
            object,
            member,
            Some(ProjectMemberKind::PropertyGet),
            Vec::new(),
        )
        .unwrap_or_else(|err| panic!("invoke {member}: {}", err.message()))
        .as_bstr()
        .unwrap_or_else(|| panic!("{member} should return a string"))
        .to_string()
}

#[test]
fn vba_self_render_crosses_the_surface_and_matches_the_canonical_scene() {
    let projection = Arc::new(PortableComProjection::new());
    // The VBA render measures text via Surface.MeasureText, so a shaper must be present;
    // StubShaper is deterministic + font-free (the headless framebuffer is text-free, so
    // the golden hash is unaffected).
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(StubShaper)));
    register_surface(&projection, surface.clone());

    let mut session = prepare_session(projection);
    let form = session
        .create_class_instance("RenderProbeForm")
        .expect("create render probe form");

    session
        .invoke_member_values(
            form.clone(),
            "Run",
            Some(ProjectMemberKind::Method),
            Vec::new(),
        )
        .unwrap_or_else(|err| panic!("invoke Run: {}", err.message()));

    let result_token = get_string(&mut session, form, "ResultToken");
    assert_ne!(
        result_token, "STALE",
        "the first patch against the BeginScene token must apply, not go stale"
    );

    let snap = surface.snapshot().expect("surface snapshot");
    assert_eq!(
        snap.calls,
        [
            "BeginScene:4",
            "MeasureText:3",
            "MeasureText:3",
            "MeasureText:3",
            "SubmitPatch:1"
        ],
        "VBA drives one BeginScene, a MeasureText per text control (the §8 measure \
         pre-pass), then one batched SubmitPatch"
    );
    assert!(
        !snap.last_stale_base,
        "the patch base must match BeginScene"
    );
    assert_eq!(
        snap.node_count, 4,
        "the form root plus three controls become four retained nodes"
    );
    assert_eq!(
        result_token.parse::<u64>().ok(),
        snap.frame_token,
        "VBA receives the resident frame token SubmitPatch reported"
    );

    // The VBA-authored, JSON-marshalled, patch-applied scene rasterizes to exactly
    // the framebuffer of the same scene built directly in Rust.
    let report = snap.last_report.expect("a render report");
    assert_eq!(
        report.width, 200,
        "surface width crossed from the form geometry"
    );
    assert_eq!(report.height, 120);
    assert_eq!(
        report.framebuffer_hash,
        expected_demo_framebuffer_hash(),
        "the cross-boundary self-render must match the canonical Rust-built scene (invariant c)"
    );

    // 4pn.13: the captions crossed once via MeasureText and landed as resident shaped
    // runs (projected into Scene.text by SubmitPatch), so the VBA self-render now carries
    // real text — not run id 0. The headless framebuffer above is text-free, so this is
    // an independent assertion on the text seam.
    let scene = snap.scene.expect("resident scene");
    assert_eq!(scene.text.len(), 3, "three captions shaped into Scene.text");
    let mut sources: Vec<String> = scene.text.values().map(|r| r.source.to_string()).collect();
    sources.sort();
    assert_eq!(
        sources,
        vec!["Hi".to_string(), "OK".to_string(), "Ready".to_string()],
        "Scene.text holds the control captions (InputField/OkButton/OutputLabel)"
    );

    // The patch the VBA encoder produced is well-formed: four full-node upserts with
    // the expected ids (form root 0 plus controls 1..=3).
    let patch_json = snap.last_patch_json.expect("captured patch JSON");
    let patch: ScenePatch =
        serde_json::from_str(&patch_json).expect("VBA-encoded patch is valid ScenePatch JSON");
    assert_eq!(patch.edits.len(), 4, "one upsert per node");
    let mut ids: Vec<u64> = patch
        .edits
        .iter()
        .map(|edit| match edit {
            NodeEdit::Upsert(node) => node.id.0,
            other => panic!("a full rebuild emits only upserts, got {other:?}"),
        })
        .collect();
    ids.sort_unstable();
    assert_eq!(ids, vec![0, 1, 2, 3], "form root plus three control nodes");
}

/// End-to-end glyph coverage (oxforms-4pn.13 acceptance): a real VBA self-render,
/// measured + shaped by the REAL `AbGlyphShaper` (the desktop backend, not the stub),
/// rasterizes caption glyphs to pixels. This also pins the `FONT_ID` coupling — VBA's
/// `OX_DEFAULT_FONT_ID` (1) must equal the `FontId` the shaper + `FontTable` register
/// under, or `resolver.font` would miss and the text would be silently dropped.
#[test]
fn vba_self_render_rasterizes_captions_through_the_real_shaper() {
    let Ok(font) = load_ui_font() else {
        // Off-Windows (no platform UI font): skip honestly rather than assert nothing.
        eprintln!("SKIP: no platform UI font on this host");
        return;
    };
    let font_id = FontId(1); // must match the VBA OX_DEFAULT_FONT_ID

    let projection = Arc::new(PortableComProjection::new());
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(AbGlyphShaper::new(
        font_id,
        font.clone(),
    ))));
    register_surface(&projection, surface.clone());

    let mut session = prepare_session(projection);
    let form = session
        .create_class_instance("RenderProbeForm")
        .expect("create render probe form");
    session
        .invoke_member_values(form, "Run", Some(ProjectMemberKind::Method), Vec::new())
        .unwrap_or_else(|err| panic!("invoke Run: {}", err.message()));

    let snap = surface.snapshot().expect("surface snapshot");
    let scene = snap.scene.expect("resident scene");
    assert_eq!(scene.text.len(), 3, "captions shaped into Scene.text");

    // Rasterize the resident scene with the same face registered under the same id, then
    // assert real glyph coverage (near-black pixels). A FONT_ID divergence drops text.
    let mut fonts = FontTable::new();
    fonts.add(font_id, font);
    let rgba = render_scene_to_rgba(&scene, 200, 120, &fonts);
    let dark = rgba
        .chunks_exact(4)
        .filter(|p| p[0] < 0x40 && p[1] < 0x40 && p[2] < 0x40 && p[3] == 0xFF)
        .count();
    assert!(
        dark > 0,
        "the real VBA self-render must rasterize caption glyphs; found no dark pixels"
    );
}

/// AutoSize layout (oxforms-4pn.14): a bordered AutoSize label shrink-wraps its caption,
/// deriving its bounds from the MeasureText metrics (measure -> layout -> paint), so a
/// font-size change re-measures and the box re-fits. This proves the metrics round-trip
/// is load-bearing, not merely plumbed. Uses StubShaper for deterministic geometry.
#[test]
fn autosize_label_bounds_track_metrics_and_grow_with_font_size() {
    let projection = Arc::new(PortableComProjection::new());
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(StubShaper)));
    register_surface(&projection, surface.clone());

    let mut session = prepare_session(projection);
    let form = session
        .create_class_instance("AutoSizeDemoForm")
        .expect("create autosize demo form");
    let call = |session: &mut oxvba_host::ProjectRuntimeSession, name: &str| {
        session
            .invoke_member_values(
                form.clone(),
                name,
                Some(ProjectMemberKind::Method),
                Vec::new(),
            )
            .unwrap_or_else(|err| panic!("invoke {name}: {}", err.message()));
    };

    // Build + first render at the default 8pt font.
    call(&mut session, "Build");
    call(&mut session, "RenderOnce");
    let before = autolabel_node(&surface);
    // Pin the exact hug, not just "it shrank": StubShaper is exact, so "Size me" (7 chars)
    // at 8pt is advance 7*(8*0.5)=28 + 8 padding wide, ascent+descent 8 + 6 padding tall =
    // 36 x 14 (a wrong padding / W<->H swap would fail here, where a `>` check would not).
    assert_eq!(
        (before.bounds.w, before.bounds.h),
        (36.0, 14.0),
        "8pt AutoSize bounds = measured advance/height + 4pt/3pt insets"
    );
    // The single-line border hugs those bounds exactly (border rect == node bounds).
    let border = before
        .prims
        .iter()
        .find_map(|p| match p {
            Prim::StrokeRect { rect, .. } => Some(*rect),
            _ => None,
        })
        .expect("the AutoSize label paints a hugging border");
    assert_eq!(
        (border.x, border.y, border.w, border.h),
        (
            before.bounds.x,
            before.bounds.y,
            before.bounds.w,
            before.bounds.h
        ),
        "the border rect equals the autosized node bounds — it hugs exactly"
    );

    // Grow the font (8pt -> 14pt); re-measure + re-layout must re-fit the hugging box.
    call(&mut session, "GrowFont");
    call(&mut session, "RenderOnce");
    let after = autolabel_node(&surface);
    // 14pt: advance 7*(14*0.5)=49 + 8 wide, height 14 + 6 tall = 57 x 20.
    assert_eq!(
        (after.bounds.w, after.bounds.h),
        (57.0, 20.0),
        "14pt AutoSize bounds re-fit to the larger measured run"
    );
    assert!(
        after.bounds.w > before.bounds.w && after.bounds.h > before.bounds.h,
        "the box grew in both dimensions with the font"
    );
}

/// The AutoLabel control node (NodeId 1 — the form's only control) from the resident scene.
fn autolabel_node(surface: &Arc<SurfaceFactory>) -> SceneNode {
    let snap = surface.snapshot().expect("surface snapshot");
    let scene = snap.scene.expect("resident scene");
    scene
        .get(NodeId(1))
        .expect("the AutoLabel control node")
        .clone()
}

/// oxforms-rq5.2: the SuspendLayout/ResumeLayout band + NodeId dedup coalesce a bulk
/// multi-setter update into one node per CHANGED control, and the incremental render emits
/// only those controls (the root + unchanged controls are retained by the kernel). This is
/// the §6 crossing-budget mechanism — a change does not re-emit the whole form.
#[test]
fn suspend_resume_dedup_emits_one_incremental_node_per_changed_control() {
    let projection = Arc::new(PortableComProjection::new());
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(StubShaper)));
    register_surface(&projection, surface.clone());

    let mut session = prepare_session(projection);
    let form = session
        .create_class_instance("InvalidationDemoForm")
        .expect("create invalidation demo form");
    let call = |session: &mut oxvba_host::ProjectRuntimeSession, name: &str| {
        session
            .invoke_member_values(
                form.clone(),
                name,
                Some(ProjectMemberKind::Method),
                Vec::new(),
            )
            .unwrap_or_else(|err| panic!("invoke {name}: {}", err.message()));
    };

    let upserts = |surface: &Arc<SurfaceFactory>| -> usize {
        surface
            .snapshot()
            .expect("snapshot")
            .last_patch_json
            .expect("a submitted patch")
            .matches("\"upsert\"")
            .count()
    };

    // First frame: full rebuild — root + the two labels = three upserts.
    call(&mut session, "Build");
    call(&mut session, "RenderOnce");
    assert_eq!(
        upserts(&surface),
        3,
        "the first frame is a full rebuild: root + two labels"
    );

    // Bulk suspended update: three setters on Label1 + one on Label2. The next render is
    // incremental and must carry exactly TWO upserts — Label1's three setters are coalesced
    // by suspend-suppression (ResumeLayout records it once), Label2 once, and NO root. (This
    // first band is the non-discriminating baseline: both labels are changed here, so it
    // emits 2 with or without the ClearDirty fix; the SUBSET band below is what catches the
    // over-invalidation bug.)
    call(&mut session, "BulkUpdateSuspended");
    call(&mut session, "RenderOnce");
    assert_eq!(
        upserts(&surface),
        2,
        "incremental: one node per changed control (Label1's setters coalesced, root retained)"
    );
    let label1_x = |surface: &Arc<SurfaceFactory>| -> f32 {
        surface
            .snapshot()
            .expect("snapshot")
            .scene
            .expect("scene")
            .get(NodeId(1))
            .expect("Label1")
            .bounds
            .x
    };
    assert_eq!(
        label1_x(&surface),
        20.0,
        "the bulk update is reflected in the resident scene"
    );

    // A SECOND suspended band touching ONLY Label1 must emit exactly ONE node. This is the
    // discriminating case: it passes only because each emit cleared Core.Dirty, so Label2 is
    // no longer stale-dirty from the first band. (Without the rq5.2 ClearDirty-on-emit fix,
    // ResumeLayout's dirty re-derive would re-invalidate Label2 too and this would be 2.)
    call(&mut session, "BulkUpdateSuspendedLabel1Only");
    call(&mut session, "RenderOnce");
    assert_eq!(
        upserts(&surface),
        1,
        "a subset band invalidates exactly the touched control (no stale-dirty over-invalidation)"
    );
    assert_eq!(label1_x(&surface), 55.0, "the subset band moved Label1");

    // Two NON-suspended setters on Label1 exercise the RecordInvalidated NodeId dedup scan
    // directly (each setter notifies the host); the control still lands once → one node.
    call(&mut session, "BulkUpdateUnsuspendedLabel1");
    call(&mut session, "RenderOnce");
    assert_eq!(
        upserts(&surface),
        1,
        "two setters on one control dedup to a single incremental node"
    );
    assert_eq!(
        label1_x(&surface),
        70.0,
        "the unsuspended update moved Label1"
    );
}

/// Evidence generator (on-demand): render the AutoSize demo through the REAL ab_glyph
/// shaper at the default and grown font sizes, writing two PNGs so the hugging box and
/// its growth are visible. Run with `cargo test -p oxforms-oxvba-adapter
/// --test oxvba_surface_render_smoke -- --ignored autosize_evidence`.
#[test]
#[ignore = "evidence generator: writes autosize PNGs to docs/evidence"]
fn autosize_evidence_pngs() {
    let Ok(font) = load_ui_font() else {
        eprintln!("SKIP: no platform UI font on this host");
        return;
    };
    let font_id = FontId(1);
    let projection = Arc::new(PortableComProjection::new());
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(AbGlyphShaper::new(
        font_id,
        font.clone(),
    ))));
    register_surface(&projection, surface.clone());
    let mut session = prepare_session(projection);
    let form = session
        .create_class_instance("AutoSizeDemoForm")
        .expect("create autosize demo form");
    let call = |session: &mut oxvba_host::ProjectRuntimeSession, name: &str| {
        session
            .invoke_member_values(
                form.clone(),
                name,
                Some(ProjectMemberKind::Method),
                Vec::new(),
            )
            .unwrap_or_else(|err| panic!("invoke {name}: {}", err.message()));
    };
    let mut fonts = FontTable::new();
    fonts.add(font_id, font);

    let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(
        "../../docs/evidence/W007_production_runtime_vertical_slice/captures/autosize-hug-20260626",
    );
    std::fs::create_dir_all(&dir).expect("create evidence dir");

    // Guard against clobbering committed evidence with a blank/degenerate render: only
    // write a PNG once the scene drew something over the form face — i.e. non-background
    // pixels exist (the label's box/border/text; the face clears to ~0xF0F0F0). A
    // near-black check would miss this label, whose theme paints white text on a blue box.
    let content_pixels = |scene: &Scene| -> usize {
        render_scene_to_rgba(scene, 600, 360, &fonts)
            .chunks_exact(4)
            .filter(|p| !(p[0] > 0xE0 && p[1] > 0xE0 && p[2] > 0xE0))
            .count()
    };

    call(&mut session, "Build");
    call(&mut session, "RenderOnce");
    let small = surface.snapshot().unwrap().scene.unwrap();
    assert!(
        content_pixels(&small) > 0,
        "small autosize render must paint the label box"
    );
    oxforms_pal_win::render_scene_to_png(&small, 600, 360, &fonts, &dir.join("autosize-small.png"))
        .expect("write small png");

    call(&mut session, "GrowFont");
    call(&mut session, "RenderOnce");
    let big = surface.snapshot().unwrap().scene.unwrap();
    assert!(
        content_pixels(&big) > 0,
        "big autosize render must paint the label box"
    );
    oxforms_pal_win::render_scene_to_png(&big, 600, 360, &fonts, &dir.join("autosize-big.png"))
        .expect("write big png");
    eprintln!("wrote autosize evidence PNGs to {}", dir.display());
}
