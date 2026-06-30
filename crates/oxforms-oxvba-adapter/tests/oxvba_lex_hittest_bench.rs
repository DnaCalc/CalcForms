//! oxforms-lex perf probe: scaling of VBA-side hit-testing on OxVba vm3 vs the native Rust
//! kernel, plus the bare per-crossing overhead. Informs whether hit-testing should be offloaded
//! to Rust (the deferred `OxForms.Surface` HitTest crossing) and whether VBA should own the
//! primary message loop. NOT a floor test — it is `#[ignore]`d (timing, no hard asserts); run it
//! explicitly:
//!
//!   cargo test -p oxforms-oxvba-adapter --test oxvba_lex_hittest_bench -- --ignored --nocapture
//!
//! Three measurements per control-count N, over the same deterministic click stream:
//!   - rust:     native linear hit-test over N rects (the control-agnostic kernel service shape).
//!   - vba:      one `HitTestAll` crossing per click (VBA hit-test compute + the crossing).
//!   - noop:     one `Noop` crossing per click (the bare invoke/marshal cost, no hit-test).
//!
//! vba_compute ≈ vba − noop isolates the interpreted hit-test loop from the crossing tax.
//!
//! Run on the vm3 interpreter (enable_jit = false) to match the shape we expect to ship on.

use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use oxvba_bundle::ProjectMemberKind;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, ProjectRuntimeSession};
use oxvba_runtime::{ObjectRef, Variant};
use oxvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

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

fn prepare_session() -> ProjectRuntimeSession {
    let manifest = SymbolProjectManifest {
        project_name: "OxFormsLexHitTestBench".to_string(),
        project_kind: ProjectKind::Library,
        modules: vec![module_unit(
            "LexHitTestBenchForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/lex_hittest_bench_form.cls",
        )],
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
    };
    let program = oxvba_bind::bind_program(&manifest, &oxvba_symbol::CatalogTypeLibResolver)
        .expect("bind bench project");
    let bundle = oxvba_oxir::elaborate::elaborate(&program).expect("elaborate bench project");
    let mut engine = Engine::new(HostConfig { enable_jit: false });
    engine.set_host_policy(HostPolicy::interactive_dev());
    engine
        .prepare_image_session(oxvba_oxir::OxImage::new(vec![bundle]))
        .expect("prepare bench session")
}

#[derive(Clone, Copy)]
struct Rect {
    x: i64,
    y: i64,
    w: i64,
    h: i64,
}

/// The control-agnostic Rust hit-region scan (same algorithm as the VBA `HitTestAll` and
/// equivalent to `oxforms-core`'s rect hit-test): linear, last (top-most) wins, returns the
/// hit index or -1.
fn native_hit_test(rects: &[Rect], x: i64, y: i64) -> i64 {
    let mut hit = -1;
    for (i, r) in rects.iter().enumerate() {
        if x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h {
            hit = i as i64;
        }
    }
    hit
}

fn build_rects(n: usize) -> Vec<Rect> {
    let (cols, cw, ch) = (40usize, 24i64, 16i64);
    (0..n)
        .map(|i| Rect {
            x: (i % cols) as i64 * cw,
            y: (i / cols) as i64 * ch,
            w: cw - 2,
            h: ch - 2,
        })
        .collect()
}

fn invoke_i32(
    session: &mut ProjectRuntimeSession,
    form: &ObjectRef,
    member: &str,
    args: Vec<Variant>,
) {
    session
        .invoke_member_values(form.clone(), member, Some(ProjectMemberKind::Method), args)
        .unwrap_or_else(|err| panic!("invoke {member}: {err}"));
}

#[test]
#[ignore = "perf probe; run explicitly with --ignored --nocapture"]
fn hit_test_scaling_vba_vs_rust_on_vm3() {
    let mut session = prepare_session();
    let form = session
        .create_class_instance("LexHitTestBenchForm")
        .expect("create bench form");

    let iters: usize = 20;
    // A deterministic, varied click stream (so it isn't a single hot rect / branch).
    let clicks: Vec<(i32, i32)> = (0..iters)
        .map(|k| (((k * 37) % 960) as i32, ((k * 53) % 640) as i32))
        .collect();

    // stderr is unbuffered, so each row lands live (println to a redirected file block-buffers).
    eprintln!("oxforms-lex hit-test scaling (vm3 interpreter, enable_jit=false), iters={iters}/N");
    eprintln!(
        "{:>6} | {:>14} | {:>14} | {:>14} | {:>14}",
        "N", "rust/op", "vba/op", "noop/op", "vba_compute/op"
    );

    for &n in &[25usize, 50, 100, 200, 400] {
        invoke_i32(
            &mut session,
            &form,
            "Setup",
            vec![Variant::from_i32(n as i32)],
        );
        let rects = build_rects(n);

        // Native Rust hit-test.
        let t = Instant::now();
        let mut acc = 0i64;
        for &(x, y) in &clicks {
            acc += native_hit_test(&rects, i64::from(x), i64::from(y));
        }
        let rust = t.elapsed();
        std::hint::black_box(acc);

        // VBA hit-test (compute + one crossing per click).
        let t = Instant::now();
        for &(x, y) in &clicks {
            invoke_i32(
                &mut session,
                &form,
                "HitTestAll",
                vec![Variant::from_i32(x), Variant::from_i32(y)],
            );
        }
        let vba = t.elapsed();

        // Bare crossing overhead (Noop, no hit-test).
        let t = Instant::now();
        for _ in 0..iters {
            invoke_i32(&mut session, &form, "Noop", Vec::new());
        }
        let noop = t.elapsed();

        let per = |d: std::time::Duration| d / iters as u32;
        let vba_compute = vba.saturating_sub(noop);
        eprintln!(
            "{n:>6} | {:>14?} | {:>14?} | {:>14?} | {:>14?}",
            per(rust),
            per(vba),
            per(noop),
            per(vba_compute)
        );
    }
}

/// Pinpoints the O(N) operation. `ScanPlain` and `ScanArray` run the SAME fixed-length loop
/// (`Reps` iterations); the only difference is `ScanArray` reads one array element per iteration.
/// We hold `Reps` fixed and vary the array LENGTH `N`: if `per-read = (ScanArray − ScanPlain)/Reps`
/// grows with `N`, dynamic-array element access is O(N) (so array loops are O(N²)). `ScanPlain`
/// should stay flat across `N` (it never touches the array).
#[test]
#[ignore = "perf probe; run explicitly with --ignored --nocapture"]
fn array_access_isolation_on_vm3() {
    let mut session = prepare_session();
    let form = session
        .create_class_instance("LexHitTestBenchForm")
        .expect("create bench form");

    let reps: i32 = 2000;
    let trials = 9u32;
    // Noise-robust: report the MIN over trials (a warmup discards cold start), over a wide
    // array-LENGTH range. If element access is O(1) the per-read stays FLAT across N; if it is
    // O(N) the per-read fans out ~16x from N=50 to N=800.
    eprintln!(
        "oxforms-lex array-access isolation (vm3 interpreter), Reps={reps}, min of {trials} trials"
    );
    eprintln!(
        "{:>6} | {:>16} | {:>16} | {:>14}",
        "N", "ScanPlain min", "ScanArray min", "per-read"
    );
    let min_of =
        |session: &mut ProjectRuntimeSession, form: &ObjectRef, member: &str| -> Duration {
            invoke_i32(session, form, member, vec![Variant::from_i32(reps)]); // warmup
            let mut best = Duration::MAX;
            for _ in 0..trials {
                let t = Instant::now();
                invoke_i32(session, form, member, vec![Variant::from_i32(reps)]);
                best = best.min(t.elapsed());
            }
            best
        };
    for &n in &[50i32, 100, 200, 400, 800] {
        invoke_i32(&mut session, &form, "Setup", vec![Variant::from_i32(n)]);
        let plain = min_of(&mut session, &form, "ScanPlain");
        let arr = min_of(&mut session, &form, "ScanArray");
        let per_read = arr.saturating_sub(plain) / reps as u32;
        eprintln!("{n:>6} | {plain:>16?} | {arr:>16?} | {per_read:>14?}");
    }
}
