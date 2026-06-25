//! `OxForms.Surface` — the generalized VBA↔Rust drawing seam.
//!
//! This is the production successor to the W002 `SmokeCanvas`: instead of a flat
//! `FillRect` display list, the VBA library authors its controls in immediate mode
//! into a VBA-side `OxSceneBuilder`, serializes one batched [`ScenePatch`] per
//! frame, and crosses the boundary exactly once through [`SURFACE_PROG_ID`]. The
//! Rust side retains the patched primitives as a control-blind [`Scene`] (see
//! `oxforms_pal::scene`) and renders it through the headless reference oracle.
//!
//! The contract is deliberately small and serde-shaped (the payload is JSON, so it
//! is hand-inspectable and versioned). Per `docs/specs/RENDERING_ARCHITECTURE.md`
//! §6 the marshalling and the `NodeId`↔control map live here, in the adapter; the
//! control-agnostic scene types live in `oxforms-pal`. SmokeCanvas stays registered
//! in parallel (quarantined) until the migration retires it.
//!
//! Crossings implemented for the W007 slice:
//! - `BeginScene(width, height, dpiX, dpiY) -> baseToken` — (re)initialize an empty
//!   retained scene and return its frame token (a decimal `u64` string) for the
//!   first patch's `base_hash`.
//! - `SubmitPatch(payloadJson) -> token | "STALE"` — apply one batched patch,
//!   render, and return the new frame token, or the literal `STALE` when the
//!   patch's `base_hash` no longer matches (the runtime then re-`BeginScene`s and
//!   resubmits a full rebuild — the self-healing path from §3).
//!
//! Deferred crossings (not needed to paint the W007 slice; tracked by the rendering
//! architecture): `RegisterFont`, `MeasureText`, `HitTest`, `ResolveSysColor`,
//! `DecodeImage`. Text prims still round-trip through the patch; the headless
//! reference does not rasterize glyphs yet, so they do not affect the framebuffer
//! hash.

use std::sync::{Arc, Mutex};

use oxvba_com::{
    platform::portable::{PortableDispatch, PortableObjectFactory},
    PortableComProjection,
};
use oxvba_runtime::Variant;

use oxforms_pal::input::DpiScale;
use oxforms_pal::scene::{
    render_headless_report, NodeId, Scene, SceneError, ScenePatch, SceneRenderReport,
};
use oxforms_pal::SurfaceSize;

/// ProgID the OxForms VBA library resolves through `CreateObject`.
pub const SURFACE_PROG_ID: &str = "OxForms.Surface";

/// The form/root node is always identity `0`; controls intern stable nonzero ids.
pub const ROOT_NODE_ID: NodeId = NodeId(0);

/// Sentinel returned by `SubmitPatch` when the patch base no longer matches the
/// resident frame; the VBA runtime re-`BeginScene`s and resubmits a full rebuild.
pub const STALE_BASE_SENTINEL: &str = "STALE";

/// Factory registered into OxVba's portable COM projection.
#[derive(Debug, Default)]
pub struct SurfaceFactory {
    state: Arc<Mutex<SurfaceState>>,
}

impl SurfaceFactory {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Rust-side evidence after the VBA fixture (or a test) drives the surface.
    pub fn snapshot(&self) -> Result<SurfaceSnapshot, String> {
        let state = self.lock()?;
        Ok(SurfaceSnapshot {
            calls: state.calls.clone(),
            frame_token: state.scene.as_ref().map(|s| s.frame_hash),
            revision: state.revision,
            last_report: state.last_report,
            last_stale_base: state.last_stale_base,
            node_count: state.scene.as_ref().map_or(0, |s| s.nodes.len()),
            scene: state.scene.clone(),
            last_patch_json: state.last_patch_json.clone(),
        })
    }

    fn lock(&self) -> Result<std::sync::MutexGuard<'_, SurfaceState>, String> {
        self.state
            .lock()
            .map_err(|_| "OxForms.Surface state lock poisoned".to_string())
    }
}

impl PortableObjectFactory for SurfaceFactory {
    fn create(&self) -> Box<dyn PortableDispatch> {
        Box::new(SurfaceDispatch {
            state: self.state.clone(),
        })
    }
}

/// Register the surface ProgID in an OxVba portable COM projection.
pub fn register_surface(projection: &PortableComProjection, factory: Arc<SurfaceFactory>) {
    projection.register_object(SURFACE_PROG_ID, factory);
}

/// Captured Rust-side evidence for tests and the runtime repaint loop.
#[derive(Clone, Debug, Default)]
pub struct SurfaceSnapshot {
    pub calls: Vec<String>,
    /// Current resident frame token (the `base_hash` the next patch must carry).
    pub frame_token: Option<u64>,
    /// Monotonic resident-Scene revision (the §16.4 producer/consumer seam): bumped
    /// on `BeginScene` and on any `SubmitPatch` that changes the resident content.
    /// The backend consumes this to decide "is there a newer frame to Repaint?" —
    /// it never goes backward, even though `frame_token` is a content hash.
    pub revision: u64,
    pub last_report: Option<SceneRenderReport>,
    pub last_stale_base: bool,
    pub node_count: usize,
    pub scene: Option<Scene>,
    pub last_patch_json: Option<String>,
}

#[derive(Debug, Default)]
struct SurfaceState {
    scene: Option<Scene>,
    /// Monotonic resident-Scene revision; see [`SurfaceSnapshot::revision`].
    revision: u64,
    last_report: Option<SceneRenderReport>,
    last_stale_base: bool,
    last_patch_json: Option<String>,
    calls: Vec<String>,
}

struct SurfaceDispatch {
    state: Arc<Mutex<SurfaceState>>,
}

impl PortableDispatch for SurfaceDispatch {
    fn invoke(&self, member: &str, args: &[Variant]) -> Result<Variant, String> {
        let member = canonical_member(member)
            .ok_or_else(|| format!("unexpected {SURFACE_PROG_ID} method `{member}`"))?;
        self.record_call(member, args.len())?;

        match member {
            "BeginScene" => self.begin_scene(args),
            "SubmitPatch" => self.submit_patch(args),
            _ => unreachable!("canonical_member filters methods"),
        }
    }

    fn get(&self, member: &str) -> Result<Variant, String> {
        Err(format!(
            "unexpected {SURFACE_PROG_ID} property get `{member}`"
        ))
    }

    fn put(&self, member: &str, _value: Variant) -> Result<(), String> {
        Err(format!(
            "unexpected {SURFACE_PROG_ID} property put `{member}`"
        ))
    }

    fn member_names(&self) -> Vec<String> {
        vec!["BeginScene".into(), "SubmitPatch".into()]
    }
}

impl SurfaceDispatch {
    fn begin_scene(&self, args: &[Variant]) -> Result<Variant, String> {
        expect_arg_count("BeginScene", args, 4)?;
        let width = u32_arg("BeginScene", args, 0, "width")?;
        let height = u32_arg("BeginScene", args, 1, "height")?;
        let dpi_x = i32_arg("BeginScene", args, 2, "dpiX")?;
        let dpi_y = i32_arg("BeginScene", args, 3, "dpiY")?;

        let scene = Scene::new(
            SurfaceSize::new(width, height),
            DpiScale::new(f64::from(dpi_x), f64::from(dpi_y)),
            ROOT_NODE_ID,
        );
        let token = scene.frame_hash;

        let mut state = self.lock()?;
        state.scene = Some(scene);
        state.last_report = None;
        state.last_stale_base = false;
        state.last_patch_json = None;
        // A fresh scene is a new resident revision (the §16.4 consumer seam).
        state.revision += 1;

        Ok(Variant::from_string(token.to_string()))
    }

    fn submit_patch(&self, args: &[Variant]) -> Result<Variant, String> {
        expect_arg_count("SubmitPatch", args, 1)?;
        let payload = bstr_arg("SubmitPatch", args, 0, "payload")?;

        let patch: ScenePatch = serde_json::from_str(&payload)
            .map_err(|err| format!("{SURFACE_PROG_ID}.SubmitPatch invalid patch JSON: {err}"))?;

        let mut state = self.lock()?;
        state.last_patch_json = Some(payload);
        let scene = state
            .scene
            .as_mut()
            .ok_or_else(|| "SubmitPatch called before BeginScene".to_string())?;
        let prev_token = scene.frame_hash;

        match scene.apply_patch(&patch) {
            Ok(_) => {
                let report = render_headless_report(scene);
                let token = scene.frame_hash;
                state.last_report = Some(report);
                state.last_stale_base = false;
                // Advance the resident revision only when the content actually
                // changed (a content-equal resubmit leaves the token, and the
                // revision, untouched — §16.4/§16.5 coalescing).
                if token != prev_token {
                    state.revision += 1;
                }
                Ok(Variant::from_string(token.to_string()))
            }
            Err(SceneError::StaleBase { .. }) => {
                state.last_stale_base = true;
                Ok(Variant::from_string(STALE_BASE_SENTINEL.to_string()))
            }
            Err(other) => Err(format!("{SURFACE_PROG_ID}.SubmitPatch rejected: {other}")),
        }
    }

    fn record_call(&self, member: &str, arg_count: usize) -> Result<(), String> {
        let mut state = self.lock()?;
        state.calls.push(format!("{member}:{arg_count}"));
        Ok(())
    }

    fn lock(&self) -> Result<std::sync::MutexGuard<'_, SurfaceState>, String> {
        self.state
            .lock()
            .map_err(|_| "OxForms.Surface state lock poisoned".to_string())
    }
}

fn canonical_member(member: &str) -> Option<&'static str> {
    if member.eq_ignore_ascii_case("BeginScene") {
        Some("BeginScene")
    } else if member.eq_ignore_ascii_case("SubmitPatch") {
        Some("SubmitPatch")
    } else {
        None
    }
}

fn expect_arg_count(member: &str, args: &[Variant], expected: usize) -> Result<(), String> {
    if args.len() == expected {
        Ok(())
    } else {
        Err(format!(
            "{SURFACE_PROG_ID}.{member} expected {expected} argument(s), got {}",
            args.len()
        ))
    }
}

fn i32_arg(member: &str, args: &[Variant], index: usize, name: &str) -> Result<i32, String> {
    args.get(index).and_then(Variant::as_i32).ok_or_else(|| {
        format!(
            "{SURFACE_PROG_ID}.{member} expected argument {} `{name}` as VBA Long, got {:?}",
            index + 1,
            args.get(index)
        )
    })
}

fn u32_arg(member: &str, args: &[Variant], index: usize, name: &str) -> Result<u32, String> {
    let value = i32_arg(member, args, index, name)?;
    u32::try_from(value).map_err(|_| {
        format!(
            "{SURFACE_PROG_ID}.{member} expected argument {} `{name}` to be non-negative, got {value}",
            index + 1
        )
    })
}

fn bstr_arg(member: &str, args: &[Variant], index: usize, name: &str) -> Result<String, String> {
    args.get(index)
        .and_then(Variant::as_bstr)
        .map(|value| value.to_string())
        .ok_or_else(|| {
            format!(
                "{SURFACE_PROG_ID}.{member} expected argument {} `{name}` as a VBA String",
                index + 1
            )
        })
}

#[cfg(test)]
mod tests {
    use super::*;

    use oxforms_pal::scene::{
        NodeEdit, Paint, Prim, RectF, SceneNode, ScenePatch, SCENE_PATCH_VERSION,
    };
    use oxforms_pal::{w002_rectangle_fixture_diagnostics, Color};

    fn dispatch() -> (Arc<SurfaceFactory>, Box<dyn PortableDispatch>) {
        let factory = Arc::new(SurfaceFactory::new());
        let disp = factory.create();
        (factory, disp)
    }

    fn token_of(value: Variant) -> String {
        value
            .as_bstr()
            .map(|s| s.to_string())
            .expect("surface members return a string token")
    }

    fn begin(disp: &dyn PortableDispatch, w: i32, h: i32) -> u64 {
        let token = token_of(
            disp.invoke(
                "BeginScene",
                &[
                    Variant::from_i32(w),
                    Variant::from_i32(h),
                    Variant::from_i32(72),
                    Variant::from_i32(72),
                ],
            )
            .expect("BeginScene"),
        );
        token.parse().expect("base token is a decimal u64")
    }

    /// A W002-equivalent one-node patch (root `NodeId(0)` with a single FillRect),
    /// built against `base_hash`.
    fn w002_patch(base_hash: u64) -> ScenePatch {
        let mut root = SceneNode::new(ROOT_NODE_ID);
        root.bounds = RectF::new(0.0, 0.0, 4.0, 3.0);
        root.prims = vec![Prim::FillRect {
            rect: RectF::new(1.0, 1.0, 2.0, 1.0),
            paint: Paint::Solid(Color::rgba(0x10, 0x20, 0x30, 0xff)),
        }];
        ScenePatch {
            version: SCENE_PATCH_VERSION,
            base_hash,
            surface: SurfaceSize::new(4, 3),
            dpi: DpiScale::new(72.0, 72.0),
            edits: vec![NodeEdit::Upsert(root)],
        }
    }

    fn submit(disp: &dyn PortableDispatch, patch: &ScenePatch) -> String {
        let json = serde_json::to_string(patch).expect("serialize patch");
        token_of(
            disp.invoke("SubmitPatch", &[Variant::from_string(json)])
                .expect("SubmitPatch"),
        )
    }

    #[test]
    fn begin_then_full_patch_reproduces_the_w002_framebuffer_hash() {
        let (factory, disp) = dispatch();
        let base = begin(&*disp, 4, 3);
        let returned = submit(&*disp, &w002_patch(base));
        assert_ne!(returned, STALE_BASE_SENTINEL);

        let snap = factory.snapshot().expect("snapshot");
        assert_eq!(snap.calls, ["BeginScene:4", "SubmitPatch:1"]);
        assert!(!snap.last_stale_base);
        assert_eq!(snap.node_count, 1);
        let report = snap.last_report.expect("report");
        assert_eq!(
            report.framebuffer_hash,
            w002_rectangle_fixture_diagnostics().framebuffer_hash,
            "the Scene seam must reproduce the historical W002 framebuffer hash"
        );
        assert_eq!(report.command_count, 1);
        // The returned token is the new resident frame token, ready to be the next
        // patch's base_hash.
        assert_eq!(returned.parse::<u64>().ok(), snap.frame_token);
    }

    #[test]
    fn content_equal_resubmit_is_a_noop_and_threads_the_token() {
        let (factory, disp) = dispatch();
        let base = begin(&*disp, 4, 3);
        let first = submit(&*disp, &w002_patch(base));
        let first_hash: u64 = first.parse().unwrap();

        // Resubmit the identical node against the now-current token.
        let second = submit(&*disp, &w002_patch(first_hash));
        assert_eq!(
            second, first,
            "re-upserting identical content leaves the frame token unchanged"
        );
        let snap = factory.snapshot().expect("snapshot");
        assert!(!snap.last_stale_base);
        assert_eq!(snap.node_count, 1);
    }

    #[test]
    fn revision_advances_on_change_not_on_content_equal_resubmit() {
        // The §16.4 resident-Scene consumer seam: a monotonic revision the backend
        // reads to decide "is there a newer frame to Repaint?".
        let (factory, disp) = dispatch();
        let base = begin(&*disp, 4, 3);
        assert_eq!(
            factory.snapshot().unwrap().revision,
            1,
            "BeginScene is revision 1"
        );

        let token: u64 = submit(&*disp, &w002_patch(base)).parse().unwrap();
        assert_eq!(
            factory.snapshot().unwrap().revision,
            2,
            "a content-changing patch advances the revision"
        );

        // Content-equal resubmit against the current token: no damage, no new revision.
        submit(&*disp, &w002_patch(token));
        assert_eq!(
            factory.snapshot().unwrap().revision,
            2,
            "a content-equal resubmit does not advance the revision"
        );

        // A stale patch is rejected and must not advance the revision.
        submit(&*disp, &w002_patch(token.wrapping_add(1)));
        assert_eq!(
            factory.snapshot().unwrap().revision,
            2,
            "a stale patch does not advance the revision"
        );
    }

    #[test]
    fn stale_base_returns_the_sentinel_without_mutating() {
        let (factory, disp) = dispatch();
        let base = begin(&*disp, 4, 3);
        // Build the patch against a deliberately wrong base.
        let returned = submit(&*disp, &w002_patch(base.wrapping_add(1)));
        assert_eq!(returned, STALE_BASE_SENTINEL);

        let snap = factory.snapshot().expect("snapshot");
        assert!(snap.last_stale_base, "a base mismatch is reported as stale");
        assert_eq!(
            snap.node_count, 0,
            "a stale patch must not mutate the scene"
        );
        assert!(snap.last_report.is_none());
    }

    #[test]
    fn submit_before_begin_is_an_error() {
        let (_factory, disp) = dispatch();
        let json = serde_json::to_string(&w002_patch(0)).unwrap();
        let err = disp
            .invoke("SubmitPatch", &[Variant::from_string(json)])
            .expect_err("SubmitPatch before BeginScene must error");
        assert!(err.contains("before BeginScene"), "got: {err}");
    }

    #[test]
    fn unknown_member_is_rejected() {
        let (_factory, disp) = dispatch();
        let err = disp
            .invoke("Frobnicate", &[])
            .expect_err("unknown member must error");
        assert!(err.contains("unexpected"), "got: {err}");
    }
}
