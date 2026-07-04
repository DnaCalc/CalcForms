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
//! control-agnostic scene types live in `oxforms-pal`. (The W002 `SmokeCanvas` ran in
//! parallel during the migration and was retired in oxforms-rq5.1; this seam is now the
//! sole VBA→Rust drawing path.)
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
//! - `MeasureText(fontId, sizeMilliPt, caption) -> "id:advance:ascent:descent:linegap"`
//!   — the single-run text-metrics round-trip (RENDERING_ARCHITECTURE.md §8). The caption
//!   (a BSTR borrow) is copied + shaped **once** by an injected [`TextShaper`] into a
//!   retained shaped run stored kernel-side; the returned `id` is a Rust-assigned content
//!   hash. Metrics are returned in 1/1000 pt integers (locale-safe to parse in VBA).
//!
//! - `MeasureBatch(requests) -> results` — the BATCHED text-metrics round-trip
//!   (RENDERING_ARCHITECTURE.md §6/§8, oxforms-98v): one crossing measures every run a frame
//!   needs. `requests`/`results` are typed `SAFEARRAY`s of `OxMeasureRequest`/`OxMeasureResult`
//!   records, so captions ride as native `String` fields (no packing/escaping) and metrics
//!   return as typed `Long`s (no VBA string parsing). Shares [`shape_run`]/[`store_run`] with
//!   `MeasureText`, so an id is identical whichever path measured it. This is what keeps first
//!   paint of N text controls to ONE measure crossing instead of N.
//!
//! Deferred crossings (not needed to paint the W007 slice; tracked by the rendering
//! architecture): `RegisterFont`, `HitTest`, `ResolveSysColor`, `DecodeImage`.

use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};
use std::time::Instant;

use oxvba_com::{
    platform::portable::{PortableDispatch, PortableObjectFactory},
    PortableComProjection,
};
use oxvba_runtime::safe_array::{SafeArray, SafeArrayBound};
use oxvba_runtime::{Variant, VbaRecord, VbaRecordFieldKind, VbaRecordFieldSpec, VbaRecordLayout};

use oxforms_pal::input::DpiScale;
use oxforms_pal::scene::{
    render_headless_report, FontId, NodeId, Prim, Scene, SceneError, ScenePatch, SceneRenderReport,
    TextKey, TextRun, TextShaper,
};
use oxforms_pal::SurfaceSize;

/// ProgID the OxForms VBA library resolves through `CreateObject`.
pub const SURFACE_PROG_ID: &str = "OxForms.Surface";

/// The form/root node is always identity `0`; controls intern stable nonzero ids.
pub const ROOT_NODE_ID: NodeId = NodeId(0);

/// Sentinel returned by `SubmitPatch` when the patch base no longer matches the
/// resident frame; the VBA runtime re-`BeginScene`s and resubmits a full rebuild.
pub const STALE_BASE_SENTINEL: &str = "STALE";

/// Shared text shaper. `Send + Sync` because the factory is shared across OxVba's COM
/// projection; shaping itself is pure and never mutates the shaper.
pub type SharedShaper = Arc<dyn TextShaper + Send + Sync>;

/// Factory registered into OxVba's portable COM projection.
#[derive(Debug, Default)]
pub struct SurfaceFactory {
    state: Arc<Mutex<SurfaceState>>,
    /// Text shaper for `MeasureText` (ab_glyph in the live app, a stub in tests). The
    /// bootstrap injects it; `None` means `MeasureText` errors (BeginScene/SubmitPatch
    /// do not need it). Shared, immutable, and outside the state mutex (shaping never
    /// contends).
    shaper: Option<SharedShaper>,
}

impl SurfaceFactory {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Construct a surface factory with a text shaper wired in, so `MeasureText` can
    /// shape + measure captions (the bootstrap passes the ab_glyph shaper here).
    #[must_use]
    pub fn with_shaper(shaper: SharedShaper) -> Self {
        Self {
            state: Arc::default(),
            shaper: Some(shaper),
        }
    }

    /// Rust-side evidence after the VBA fixture (or a test) drives the surface.
    pub fn snapshot(&self) -> Result<SurfaceSnapshot, String> {
        let state = self.lock()?;
        Ok(SurfaceSnapshot {
            calls: state.calls.clone(),
            call_timings: state.call_timings.clone(),
            frame_token: state.scene.as_ref().map(|s| s.frame_hash),
            revision: state.revision,
            last_report: state.last_report,
            last_stale_base: state.last_stale_base,
            node_count: state.scene.as_ref().map_or(0, |s| s.nodes.len()),
            scene: state.scene.clone(),
            last_patch_json: state.last_patch_json.clone(),
        })
    }

    /// Number of surface calls recorded so far. The headless perf runner uses this
    /// as a lightweight marker so each input turn can report only the crossings it
    /// caused without cloning the resident scene before dispatch.
    pub fn call_timing_count(&self) -> Result<usize, String> {
        let state = self.lock()?;
        Ok(state.call_timings.len())
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
            shaper: self.shaper.clone(),
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
    pub call_timings: Vec<SurfaceCallTiming>,
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

/// Timing for one `OxForms.Surface` method invocation. This is profiling evidence
/// only: the stable functional surface remains the method name, arguments, and
/// return value.
#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct SurfaceCallTiming {
    pub member: String,
    pub arg_count: usize,
    pub elapsed_us: u128,
    pub ok: bool,
}

impl SurfaceCallTiming {
    #[must_use]
    pub fn label(&self) -> String {
        format!("{}:{}", self.member, self.arg_count)
    }
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
    call_timings: Vec<SurfaceCallTiming>,
    /// The persistent shaped-run store (the kernel-side interning cache), keyed by
    /// [`oxforms_pal::scene::TextRunId`]`.0`. Populated by `MeasureText`; it **survives
    /// `BeginScene`** (a cache, not per-frame content). `SubmitPatch` projects the runs
    /// the resident scene references into `Scene.text` so a snapshot is self-contained.
    text_runs: BTreeMap<u64, TextRun>,
}

struct SurfaceDispatch {
    state: Arc<Mutex<SurfaceState>>,
    shaper: Option<SharedShaper>,
}

impl PortableDispatch for SurfaceDispatch {
    fn invoke(&self, member: &str, args: &[Variant]) -> Result<Variant, String> {
        let member = canonical_member(member)
            .ok_or_else(|| format!("unexpected {SURFACE_PROG_ID} method `{member}`"))?;
        let call_start = profiling_timings_enabled().then(Instant::now);

        let result = match member {
            "BeginScene" => self.begin_scene(args),
            "SubmitPatch" => self.submit_patch(args),
            "MeasureText" => self.measure_text(args),
            "MeasureBatch" => self.measure_batch(args),
            _ => unreachable!("canonical_member filters methods"),
        };
        self.record_call(
            member,
            args.len(),
            call_start.map(|start| start.elapsed().as_micros()),
            result.is_ok(),
        )?;
        result
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
        vec![
            "BeginScene".into(),
            "SubmitPatch".into(),
            "MeasureText".into(),
            "MeasureBatch".into(),
        ]
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
        let st = &mut *state;
        let scene = st
            .scene
            .as_mut()
            .ok_or_else(|| "SubmitPatch called before BeginScene".to_string())?;
        let prev_token = scene.frame_hash;

        match scene.apply_patch(&patch) {
            Ok(_) => {
                // Project the shaped runs the resident scene now references from the
                // persistent store into `Scene.text`, so the snapshot is self-contained
                // (the backend resolves text from the scene, not a side channel).
                project_text_runs(scene, &st.text_runs);
                let report = render_headless_report(scene);
                let token = scene.frame_hash;
                st.last_report = Some(report);
                st.last_stale_base = false;
                // Advance the resident revision only when the content actually
                // changed (a content-equal resubmit leaves the token, and the
                // revision, untouched — §16.4/§16.5 coalescing).
                if token != prev_token {
                    st.revision += 1;
                }
                Ok(Variant::from_string(token.to_string()))
            }
            Err(SceneError::StaleBase { .. }) => {
                st.last_stale_base = true;
                Ok(Variant::from_string(STALE_BASE_SENTINEL.to_string()))
            }
            Err(other) => Err(format!("{SURFACE_PROG_ID}.SubmitPatch rejected: {other}")),
        }
    }

    /// `MeasureText(fontId, sizeMilliPt, caption) -> "id:advance:ascent:descent:linegap"`
    /// (metrics in 1/1000 pt integers — locale-safe for VBA to `Val`-parse). The
    /// cache-miss path of the §8 text seam: own the caption (the BSTR belongs to VBA
    /// and is valid only for this call — in-process there is no marshaling copy, so
    /// retaining the raw pointer would be a use-after-free; `bstr_arg`/`as_bstr` copy
    /// it into owned Rust memory before the run is stored, so the run never aliases VBA
    /// memory), shape it once via the injected [`TextShaper`] into a
    /// retained run, store it under its Rust-assigned content-hash id (idempotent), and
    /// return the id + metrics. VBA memoizes the id by text and re-emits it in patches.
    fn measure_text(&self, args: &[Variant]) -> Result<Variant, String> {
        expect_arg_count("MeasureText", args, 3)?;
        let font_id = u32_arg("MeasureText", args, 0, "fontId")?;
        let size_milli_pt = u32_arg("MeasureText", args, 1, "sizeMilliPt")?;
        let caption = bstr_arg("MeasureText", args, 2, "caption")?;

        let shaper = self.shaper.as_ref().ok_or_else(|| {
            format!("{SURFACE_PROG_ID}.MeasureText called without a registered text shaper")
        })?;

        let run = shape_run(shaper, font_id, size_milli_pt, &caption);
        let line = format_measure(&run);
        let mut state = self.lock()?;
        store_run(&mut state, run);
        Ok(Variant::from_string(line))
    }

    /// `MeasureBatch(requests) -> results` — the BATCHED §8 text-metrics crossing
    /// (RENDERING_ARCHITECTURE.md §6/§8). One crossing measures EVERY run a frame needs:
    /// `requests` is a `SAFEARRAY` of `OxMeasureRequest` records `(FontId, SizeMilliPt,
    /// Caption)`; the return is an index-aligned `SAFEARRAY` of `OxMeasureResult` records
    /// `(RunId, AdvanceMilliPt, AscentMilliPt, DescentMilliPt, LineGapMilliPt,
    /// CaretStopsMilliPtCsv)`. Captions ride as native `String` record fields
    /// (never packed/escaped); metrics return as typed `Long`s, and caret stops return as
    /// a comma-separated milli-point string for VBA-side selection/caret geometry. Each run is
    /// shaped once and
    /// stored exactly as the single-run [`Self::measure_text`] does (shared [`shape_run`] +
    /// [`store_run`]), so a content-hash id is identical whichever path measured it. This
    /// replaces the per-control `MeasureText` fan-out: first paint of N text controls
    /// crosses once, not N times (the §6 first-paint budget — oxforms-98v).
    fn measure_batch(&self, args: &[Variant]) -> Result<Variant, String> {
        expect_arg_count("MeasureBatch", args, 1)?;
        let requests = args[0].as_safearray().ok_or_else(|| {
            format!(
                "{SURFACE_PROG_ID}.MeasureBatch expected a SAFEARRAY of OxMeasureRequest records"
            )
        })?;
        let shaper = self.shaper.as_ref().ok_or_else(|| {
            format!("{SURFACE_PROG_ID}.MeasureBatch called without a registered text shaper")
        })?;

        // Shape every requested run (pure; no store mutation yet).
        let elements = requests.variant_elements().unwrap_or_default();
        let mut runs: Vec<TextRun> = Vec::with_capacity(elements.len());
        for (row, element) in elements.iter().enumerate() {
            let record = element.as_vba_record().ok_or_else(|| {
                format!("{SURFACE_PROG_ID}.MeasureBatch request {row} is not an OxMeasureRequest record")
            })?;
            let font_id = record_u32(&record, REQ_FONT_ID, "FontId", row)?;
            let size_milli_pt = record_u32(&record, REQ_SIZE_MILLI_PT, "SizeMilliPt", row)?;
            let caption = record_string(&record, REQ_CAPTION, "Caption", row)?;
            runs.push(shape_run(shaper, font_id, size_milli_pt, &caption));
        }

        // Store the whole batch under one lock, then build the index-aligned result array.
        {
            let mut state = self.lock()?;
            for run in &runs {
                store_run(&mut state, run.clone());
            }
        }

        let layout = measure_result_layout();
        let mut results: Vec<VbaRecord> = Vec::with_capacity(runs.len());
        for run in &runs {
            let mut rec = VbaRecord::new_default(layout.clone())
                .map_err(|err| format!("{SURFACE_PROG_ID}.MeasureBatch result record: {err}"))?;
            rec.write_field_variant(RES_RUN_ID, &Variant::from_string(run.id.0.to_string()))?;
            rec.write_field_variant(
                RES_ADVANCE,
                &Variant::from_i32(milli_pt_i32(run.metrics.advance)?),
            )?;
            rec.write_field_variant(
                RES_ASCENT,
                &Variant::from_i32(milli_pt_i32(run.metrics.ascent)?),
            )?;
            rec.write_field_variant(
                RES_DESCENT,
                &Variant::from_i32(milli_pt_i32(run.metrics.descent)?),
            )?;
            rec.write_field_variant(
                RES_LINE_GAP,
                &Variant::from_i32(milli_pt_i32(run.metrics.line_gap)?),
            )?;
            rec.write_field_variant(
                RES_CARET_STOPS,
                &Variant::from_string(format_caret_stops(run)),
            )?;
            results.push(rec);
        }

        let count = u32::try_from(results.len())
            .map_err(|_| format!("{SURFACE_PROG_ID}.MeasureBatch result count overflow"))?;
        let array = SafeArray::from_vba_records_nd(
            vec![SafeArrayBound { count, lower: 0 }],
            layout,
            results,
        )
        .map_err(|err| format!("{SURFACE_PROG_ID}.MeasureBatch result array: {err}"))?;
        Ok(Variant::from_safearray(array))
    }

    fn record_call(
        &self,
        member: &str,
        arg_count: usize,
        elapsed_us: Option<u128>,
        ok: bool,
    ) -> Result<(), String> {
        let mut state = self.lock()?;
        state.calls.push(format!("{member}:{arg_count}"));
        if let Some(elapsed_us) = elapsed_us {
            state.call_timings.push(SurfaceCallTiming {
                member: member.to_string(),
                arg_count,
                elapsed_us,
                ok,
            });
        }
        Ok(())
    }

    fn lock(&self) -> Result<std::sync::MutexGuard<'_, SurfaceState>, String> {
        self.state
            .lock()
            .map_err(|_| "OxForms.Surface state lock poisoned".to_string())
    }
}

fn profiling_timings_enabled() -> bool {
    std::env::var_os("OXFORMS_PROFILE_TIMINGS").is_some()
}

/// Rebuild `Scene.text` to exactly the runs the resident scene's `DrawText` prims
/// reference, copying them from the persistent store, so a snapshot is self-contained.
/// Rebuilt (not merely appended) each `SubmitPatch`: the persistent `store` is the
/// surviving source of truth, so `Scene.text` carries only the live working set — no
/// ghost runs accumulate over a scene's lifetime and no dropped id can linger. Runs
/// with no stored entry (e.g. an unmeasured `run: 0`) are simply skipped.
fn project_text_runs(scene: &mut Scene, store: &BTreeMap<u64, TextRun>) {
    let referenced: Vec<u64> = scene
        .nodes
        .iter()
        .flat_map(|node| &node.prims)
        .filter_map(|prim| match prim {
            Prim::DrawText { run, .. } => Some(run.0),
            _ => None,
        })
        .collect();
    scene.text.clear();
    for id in referenced {
        if let Some(run) = store.get(&id) {
            scene.upsert_text_run(run.clone());
        }
    }
}

/// Round a logical-point metric to 1/1000 pt for the `MeasureText` return (integer,
/// so VBA parses it locale-independently). Negative is clamped to 0.
fn milli_pt(points: f32) -> i64 {
    (f64::from(points) * 1000.0).round().max(0.0) as i64
}

/// `milli_pt` as a VBA `Long` (i32) for a typed `OxMeasureResult` field. The metric contract
/// IS i32-bounded — the result record's fields are VBA `Long`s — and realistic text metrics
/// are far inside that, so the guard only fires on a degenerate value, erroring rather than
/// wrapping. (The single-run `MeasureText` returns the same `milli_pt` value as a string; the
/// shared i32 ceiling is the wire contract, not a divergence.)
fn milli_pt_i32(points: f32) -> Result<i32, String> {
    let milli = milli_pt(points);
    i32::try_from(milli).map_err(|_| {
        format!("{SURFACE_PROG_ID}.MeasureBatch metric {milli} (1/1000 pt) exceeds a VBA Long")
    })
}

// Field order of the `OxMeasureRequest` / `OxMeasureResult` records — MUST match the VBA
// `Type`s in vba/oxforms/OxFormsModel.bas (co-versioned; both change together).
const REQ_FONT_ID: usize = 0;
const REQ_SIZE_MILLI_PT: usize = 1;
const REQ_CAPTION: usize = 2;
const RES_RUN_ID: usize = 0;
const RES_ADVANCE: usize = 1;
const RES_ASCENT: usize = 2;
const RES_DESCENT: usize = 3;
const RES_LINE_GAP: usize = 4;
const RES_CARET_STOPS: usize = 5;

/// Shape one run via the injected shaper (pure — no store mutation). Shared by the single
/// `MeasureText` and the batched `MeasureBatch` so a content-hash id never depends on which
/// path measured it.
fn shape_run(shaper: &SharedShaper, font_id: u32, size_milli_pt: u32, caption: &str) -> TextRun {
    let key = TextKey {
        font: FontId(u64::from(font_id)),
        size_milli_pt,
        wrap_width_milli_pt: None,
    };
    shaper.shape(&key, caption)
}

/// Insert a shaped run into the persistent store (idempotent by content-hash id; a second
/// measure of identical text is a no-op). Shared by both measure paths.
fn store_run(state: &mut SurfaceState, run: TextRun) {
    debug_assert!(
        state
            .text_runs
            .get(&run.id.0)
            .is_none_or(|existing| *existing == run),
        "text_run_id collision in the MeasureText store: id {:#x}",
        run.id.0
    );
    state.text_runs.insert(run.id.0, run);
}

/// The `MeasureText` return string `id:advance:ascent:descent:linegap` (milli-pt integers).
fn format_measure(run: &TextRun) -> String {
    format!(
        "{}:{}:{}:{}:{}",
        run.id.0,
        milli_pt(run.metrics.advance),
        milli_pt(run.metrics.ascent),
        milli_pt(run.metrics.descent),
        milli_pt(run.metrics.line_gap),
    )
}

fn format_caret_stops(run: &TextRun) -> String {
    let mut out = String::new();
    for (i, stop) in run.caret.stops.iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        out.push_str(&milli_pt(*stop).to_string());
    }
    out
}

/// The shared `OxMeasureResult` record layout (RunId: String, four milli-pt Longs,
/// then caret stops as a milli-pt CSV String).
/// Built per call (cheap); its field kinds + order mirror the VBA `OxMeasureResult` `Type`.
fn measure_result_layout() -> Arc<VbaRecordLayout> {
    let layout = VbaRecordLayout::new(vec![
        VbaRecordFieldSpec::named("RunId", VbaRecordFieldKind::String),
        VbaRecordFieldSpec::named("AdvanceMilliPt", VbaRecordFieldKind::Long),
        VbaRecordFieldSpec::named("AscentMilliPt", VbaRecordFieldKind::Long),
        VbaRecordFieldSpec::named("DescentMilliPt", VbaRecordFieldKind::Long),
        VbaRecordFieldSpec::named("LineGapMilliPt", VbaRecordFieldKind::Long),
        VbaRecordFieldSpec::named("CaretStopsMilliPtCsv", VbaRecordFieldKind::String),
    ])
    .expect("OxMeasureResult layout is statically valid");
    Arc::new(layout)
}

/// Read a non-negative `Long` field from an `OxMeasureRequest` record.
fn record_u32(record: &VbaRecord, index: usize, field: &str, row: usize) -> Result<u32, String> {
    let value = record.read_field_variant(index).map_err(|err| {
        format!("{SURFACE_PROG_ID}.MeasureBatch request {row} field `{field}`: {err}")
    })?;
    let number = value.as_i32().ok_or_else(|| {
        format!("{SURFACE_PROG_ID}.MeasureBatch request {row} field `{field}` is not a Long")
    })?;
    u32::try_from(number).map_err(|_| {
        format!("{SURFACE_PROG_ID}.MeasureBatch request {row} field `{field}` must be non-negative, got {number}")
    })
}

/// Read a `String` field from an `OxMeasureRequest` record — the native BSTR carrier for the
/// free-form caption (no delimiting/escaping/length-prefix).
///
/// Encoding boundary: the wire field is a BSTR (UTF-16, length-prefixed, so embedded NULs are
/// fine), and `BStr::to_string` normalizes it to a Rust `String` (UTF-8) via
/// `String::from_utf16_lossy`. That is lossless for every well-formed caption — including
/// embedded `\0` and astral chars/emoji (surrogate PAIRS) — with one corner: an *unpaired*
/// UTF-16 surrogate becomes `U+FFFD`. Unpaired surrogates are malformed UTF-16 that a real
/// control caption never carries (and a font could not shape anyway), so this is not
/// observable in normal use; the content-hash run id is then computed over the UTF-8 form. If
/// bit-exact UTF-16 fidelity were ever needed, key off the BSTR's `&[u16]` units instead.
fn record_string(
    record: &VbaRecord,
    index: usize,
    field: &str,
    row: usize,
) -> Result<String, String> {
    let value = record.read_field_variant(index).map_err(|err| {
        format!("{SURFACE_PROG_ID}.MeasureBatch request {row} field `{field}`: {err}")
    })?;
    let text = value.as_bstr().ok_or_else(|| {
        format!("{SURFACE_PROG_ID}.MeasureBatch request {row} field `{field}` is not a String")
    })?;
    Ok(text.to_string())
}

fn canonical_member(member: &str) -> Option<&'static str> {
    if member.eq_ignore_ascii_case("BeginScene") {
        Some("BeginScene")
    } else if member.eq_ignore_ascii_case("SubmitPatch") {
        Some("SubmitPatch")
    } else if member.eq_ignore_ascii_case("MeasureText") {
        Some("MeasureText")
    } else if member.eq_ignore_ascii_case("MeasureBatch") {
        Some("MeasureBatch")
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
        text_run_id, NodeEdit, Paint, Prim, RectF, SceneNode, ScenePatch, StubShaper, TextAlign,
        TextFlags, TextKey, TextRunId, SCENE_PATCH_VERSION,
    };
    use oxforms_pal::Color;

    /// Historical W002 rectangle framebuffer hash, now reproduced through the Scene seam
    /// (the pre-Scene `w002_rectangle_fixture_*` helpers retired in oxforms-rq5.1).
    const W002_FRAMEBUFFER_HASH: u64 = 13_797_848_596_963_948_501;

    fn dispatch() -> (Arc<SurfaceFactory>, Box<dyn PortableDispatch>) {
        let factory = Arc::new(SurfaceFactory::new());
        let disp = factory.create();
        (factory, disp)
    }

    fn dispatch_with_stub() -> (Arc<SurfaceFactory>, Box<dyn PortableDispatch>) {
        let factory = Arc::new(SurfaceFactory::with_shaper(Arc::new(StubShaper)));
        let disp = factory.create();
        (factory, disp)
    }

    /// Call `MeasureText` and return the raw `id:advance:ascent:descent:linegap` string.
    fn measure(disp: &dyn PortableDispatch, font: i32, milli_pt: i32, text: &str) -> String {
        token_of(
            disp.invoke(
                "MeasureText",
                &[
                    Variant::from_i32(font),
                    Variant::from_i32(milli_pt),
                    Variant::from_string(text.to_string()),
                ],
            )
            .expect("MeasureText"),
        )
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
            report.framebuffer_hash, W002_FRAMEBUFFER_HASH,
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

    // ── MeasureText + the shaped-run store (4pn.11) ──

    /// A one-node patch whose root carries a single `DrawText` referencing `run`.
    fn text_patch(base_hash: u64, run: TextRunId) -> ScenePatch {
        let mut root = SceneNode::new(ROOT_NODE_ID);
        root.bounds = RectF::new(0.0, 0.0, 4.0, 3.0);
        root.prims = vec![Prim::DrawText {
            run,
            rect: RectF::new(0.0, 0.0, 4.0, 3.0),
            align: TextAlign::Left,
            wrap: false,
            clip: true,
            paint: Paint::Solid(Color::rgba(0, 0, 0, 0xff)),
            flags: TextFlags::default(),
        }];
        ScenePatch {
            version: SCENE_PATCH_VERSION,
            base_hash,
            surface: SurfaceSize::new(4, 3),
            dpi: DpiScale::new(72.0, 72.0),
            edits: vec![NodeEdit::Upsert(root)],
        }
    }

    #[test]
    fn measure_text_shapes_stores_and_returns_id_with_metrics() {
        let (factory, disp) = dispatch_with_stub();
        // StubShaper at 12pt: advance = 2 chars * half-em(6.0) = 12.0pt; ascent 9.6,
        // descent 2.4, line_gap 0 — returned in 1/1000 pt. The id is the golden vector.
        let result = measure(&*disp, 1, 12_000, "OK");
        let expected_id = text_run_id(
            &TextKey {
                font: FontId(1),
                size_milli_pt: 12_000,
                wrap_width_milli_pt: None,
            },
            "OK",
        );
        assert_eq!(result, format!("{}:12000:9600:2400:0", expected_id.0));

        let snap = factory.snapshot().expect("snapshot");
        assert_eq!(snap.calls, ["MeasureText:3"]);
    }

    #[test]
    fn measure_text_is_idempotent_by_content_hash_id() {
        let (_factory, disp) = dispatch_with_stub();
        let first = measure(&*disp, 1, 12_000, "OK");
        let again = measure(&*disp, 1, 12_000, "OK");
        assert_eq!(first, again, "same content → same id + metrics, no churn");
        // Different text → different id (content-derived).
        let other = measure(&*disp, 1, 12_000, "Cancel");
        assert_ne!(
            other.split(':').next(),
            first.split(':').next(),
            "different captions get distinct ids"
        );
    }

    #[test]
    fn measure_text_without_a_shaper_is_a_clear_error() {
        let (_factory, disp) = dispatch(); // no shaper injected
        let err = disp
            .invoke(
                "MeasureText",
                &[
                    Variant::from_i32(1),
                    Variant::from_i32(12_000),
                    Variant::from_string("OK".to_string()),
                ],
            )
            .expect_err("MeasureText without a shaper must error");
        assert!(
            err.contains("without a registered text shaper"),
            "got: {err}"
        );
    }

    #[test]
    fn submit_patch_projects_referenced_runs_into_scene_text() {
        let (factory, disp) = dispatch_with_stub();
        // Measure a run (stores it kernel-side), then reference its id from a patch.
        let result = measure(&*disp, 1, 12_000, "OK");
        let id: u64 = result.split(':').next().unwrap().parse().unwrap();

        let base = begin(&*disp, 4, 3);
        let returned = submit(&*disp, &text_patch(base, TextRunId(id)));
        assert_ne!(returned, STALE_BASE_SENTINEL);

        let snap = factory.snapshot().expect("snapshot");
        let scene = snap.scene.expect("resident scene");
        let run = scene
            .text_run(TextRunId(id))
            .expect("the referenced run is projected into Scene.text");
        assert_eq!(&*run.source, "OK");
        assert_eq!(run.id.0, id);
    }

    #[test]
    fn measure_store_survives_begin_scene() {
        // The store is a persistent cache, not per-frame content: a measured run is
        // still resolvable after a fresh BeginScene + a patch that references it.
        let (factory, disp) = dispatch_with_stub();
        let id: u64 = measure(&*disp, 1, 12_000, "OK")
            .split(':')
            .next()
            .unwrap()
            .parse()
            .unwrap();
        // First frame.
        let base1 = begin(&*disp, 4, 3);
        submit(&*disp, &text_patch(base1, TextRunId(id)));
        // A second, fresh scene (resize/re-show) — the store must survive it.
        let base2 = begin(&*disp, 8, 6);
        submit(&*disp, &text_patch(base2, TextRunId(id)));
        let snap = factory.snapshot().expect("snapshot");
        assert!(
            snap.scene.unwrap().text_run(TextRunId(id)).is_some(),
            "the run survived BeginScene and re-projected into the new scene"
        );
    }

    // ── MeasureBatch — the batched typed-record measure crossing (oxforms-98v) ──

    /// Build a request `SAFEARRAY` of `OxMeasureRequest` records — the exact shape the VM
    /// marshals a VBA `Dim reqs() As OxMeasureRequest` into — so the batch path is unit-tested
    /// at the dispatch boundary without the VBA/VM layer.
    fn request_array(rows: &[(i32, i32, &str)]) -> Variant {
        let layout = Arc::new(
            VbaRecordLayout::new(vec![
                VbaRecordFieldSpec::named("FontId", VbaRecordFieldKind::Long),
                VbaRecordFieldSpec::named("SizeMilliPt", VbaRecordFieldKind::Long),
                VbaRecordFieldSpec::named("Caption", VbaRecordFieldKind::String),
            ])
            .expect("request layout"),
        );
        let records: Vec<VbaRecord> = rows
            .iter()
            .map(|(font, size, caption)| {
                let mut rec = VbaRecord::new_default(layout.clone()).expect("request record");
                rec.write_field_variant(0, &Variant::from_i32(*font))
                    .unwrap();
                rec.write_field_variant(1, &Variant::from_i32(*size))
                    .unwrap();
                rec.write_field_variant(2, &Variant::from_string((*caption).to_string()))
                    .unwrap();
                rec
            })
            .collect();
        let array = SafeArray::from_vba_records_nd(
            vec![SafeArrayBound {
                count: rows.len() as u32,
                lower: 0,
            }],
            layout,
            records,
        )
        .expect("request SAFEARRAY");
        Variant::from_safearray(array)
    }

    #[test]
    fn measure_batch_shapes_a_record_array_in_one_crossing() {
        let (factory, disp) = dispatch_with_stub();
        let result = disp
            .invoke(
                "MeasureBatch",
                &[request_array(&[(1, 12_000, "OK"), (1, 12_000, "Hi")])],
            )
            .expect("MeasureBatch");

        // One crossing measured both runs.
        assert_eq!(factory.snapshot().unwrap().calls, ["MeasureBatch:1"]);

        // The result is an index-aligned SAFEARRAY of OxMeasureResult records.
        let rows = result
            .as_safearray()
            .expect("result is a SAFEARRAY")
            .variant_elements()
            .expect("result rows");
        assert_eq!(rows.len(), 2);

        let key = TextKey {
            font: FontId(1),
            size_milli_pt: 12_000,
            wrap_width_milli_pt: None,
        };
        let row0 = rows[0].as_vba_record().expect("result record 0");
        // RunId is a String field (the content hash); metrics are typed Long fields. StubShaper
        // at 12pt: "OK" -> advance 12000, ascent 9600, descent 2400, line_gap 0 (milli-pt).
        assert_eq!(
            row0.read_field_variant(RES_RUN_ID)
                .unwrap()
                .as_bstr()
                .unwrap()
                .to_string(),
            text_run_id(&key, "OK").0.to_string()
        );
        assert_eq!(
            row0.read_field_variant(RES_ADVANCE).unwrap().as_i32(),
            Some(12_000)
        );
        assert_eq!(
            row0.read_field_variant(RES_ASCENT).unwrap().as_i32(),
            Some(9_600)
        );
        assert_eq!(
            row0.read_field_variant(RES_DESCENT).unwrap().as_i32(),
            Some(2_400)
        );
        assert_eq!(
            row0.read_field_variant(RES_LINE_GAP).unwrap().as_i32(),
            Some(0)
        );

        // The runs landed in the persistent store (resolvable via a referencing patch).
        let id: u64 = text_run_id(&key, "OK").0;
        let base = begin(&*disp, 4, 3);
        submit(&*disp, &text_patch(base, TextRunId(id)));
        assert!(factory
            .snapshot()
            .unwrap()
            .scene
            .unwrap()
            .text_run(TextRunId(id))
            .is_some());
    }

    #[test]
    fn measure_batch_without_a_shaper_is_a_clear_error() {
        let (_factory, disp) = dispatch(); // no shaper injected
        let err = disp
            .invoke("MeasureBatch", &[request_array(&[(1, 12_000, "OK")])])
            .expect_err("MeasureBatch without a shaper must error");
        assert!(
            err.contains("without a registered text shaper"),
            "got: {err}"
        );
    }
}
