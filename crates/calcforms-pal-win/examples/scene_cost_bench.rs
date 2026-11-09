//! Cost of one label change: `Scene::apply_patch` plus the incremental raster repaint,
//! on forms of 50, 500 and 5,000 controls (flat, and grouped into clipped Frames of 50),
//! and on a 50-control form carrying a 10,000-item ListBox (virtualized: the node holds
//! the visible rows only, as `ListBox.cls` emits).
//!
//! Run: `cargo run --release -p calcforms-pal-win --example scene_cost_bench`
//! The numbers are the median of repeated single-label changes, in microseconds.

use std::time::Instant;

use calcforms_pal::scene::{
    text_run_id, Affine, FontId, NodeEdit, NodeId, Paint, Prim, RectF, Scene, SceneNode,
    ScenePatch, Stroke, TextAlign, TextFlags, TextKey, TextShaper, SCENE_PATCH_VERSION,
};
use calcforms_pal::{Color, DpiScale, SurfaceSize};
use calcforms_pal_win::{load_ui_font, repaint_scene_damage, AbGlyphShaper, FontTable};

const FONT: FontId = FontId(1);
const CELL_W: f32 = 60.0;
const CELL_H: f32 = 22.0;

fn key() -> TextKey {
    TextKey {
        font: FONT,
        size_milli_pt: 8_000,
        wrap_width_milli_pt: None,
        device_scale_micros: None,
        device_em_pixels: None,
        accelerator_index: None,
    }
}

fn label_prims(text: &str) -> Vec<Prim> {
    let solid = |g: u8| Paint::Solid(Color::rgba(g, g, g, 0xFF));
    vec![
        Prim::FillRect {
            rect: RectF::new(0.0, 0.0, 56.0, 18.0),
            paint: solid(0xF0),
        },
        Prim::StrokeRect {
            rect: RectF::new(0.0, 0.0, 56.0, 18.0),
            stroke: Stroke {
                paint: solid(0x40),
                width: 1.0,
            },
        },
        Prim::DrawText {
            run: text_run_id(&key(), text),
            rect: RectF::new(2.0, 1.0, 52.0, 16.0),
            align: TextAlign::Left,
            wrap: false,
            clip: true,
            paint: solid(0x10),
            flags: TextFlags::default(),
        },
    ]
}

fn label_node(id: u64, parent: u64, x: f32, y: f32, text: &str) -> SceneNode {
    let mut n = SceneNode::new(NodeId(id));
    n.parent = Some(NodeId(parent));
    n.transform = Affine::translate(x, y);
    n.bounds = RectF::new(0.0, 0.0, 56.0, 18.0);
    n.prims = label_prims(text);
    n
}

struct Built {
    scene: Scene,
    target: u64,
}

/// `n` labels in a 50-column grid; `grouped` puts each 50 under a clipped Frame node.
fn build(n: usize, grouped: bool, listbox_items: Option<usize>, shaper: &AbGlyphShaper) -> Built {
    let cols = 50usize;
    let rows = n.div_ceil(cols);
    let (w, h) = (
        (cols as f32 * CELL_W) as u32,
        (rows as f32 * CELL_H) as u32 + 400,
    );
    let mut scene = Scene::new(
        SurfaceSize {
            width: w,
            height: h,
        },
        DpiScale::new(96.0, 96.0),
        NodeId(0),
    );
    let mut root = SceneNode::new(NodeId(0));
    root.bounds = RectF::new(0.0, 0.0, w as f32, h as f32);
    root.prims = vec![Prim::FillRect {
        rect: root.bounds,
        paint: Paint::Solid(Color::rgba(0xF0, 0xF0, 0xF0, 0xFF)),
    }];
    let mut nodes = Vec::new();
    let mut runs = Vec::new();
    let text_of = |i: usize| format!("L{i}");
    if grouped {
        // Frame = 10 columns x 5 rows of cells (50 labels), 5 frames per row of frames.
        let per = 50usize;
        let frames = n.div_ceil(per);
        for f in 0..frames {
            let fid = (n + 1 + f) as u64;
            let (fx, fy) = ((f % 5) as f32 * 600.0, (f / 5) as f32 * 110.0);
            let mut fr = SceneNode::new(NodeId(fid));
            fr.parent = Some(NodeId(0));
            fr.transform = Affine::translate(fx, fy);
            fr.bounds = RectF::new(0.0, 0.0, 600.0, 110.0);
            fr.clip = Some(fr.bounds);
            fr.prims = vec![Prim::FillRect {
                rect: fr.bounds,
                paint: Paint::Solid(Color::rgba(0xE8, 0xE8, 0xE8, 0xFF)),
            }];
            for j in 0..per.min(n - f * per) {
                let i = f * per + j;
                let id = (i + 1) as u64;
                let (x, y) = ((j % 10) as f32 * CELL_W, (j / 10) as f32 * CELL_H);
                nodes.push(label_node(id, fid, x, y, &text_of(i)));
                fr.children.push(NodeId(id));
                runs.push(text_of(i));
            }
            root.children.push(NodeId(fid));
            nodes.push(fr);
        }
    } else {
        for i in 0..n {
            let id = (i + 1) as u64;
            let (x, y) = ((i % cols) as f32 * CELL_W, (i / cols) as f32 * CELL_H);
            nodes.push(label_node(id, 0, x, y, &text_of(i)));
            root.children.push(NodeId(id));
            runs.push(text_of(i));
        }
    }
    if let Some(items) = listbox_items {
        // The ListBox node: items live VBA-side; the node carries the ~14 visible rows.
        let id = (n * 2 + 10_000) as u64;
        let mut lb = SceneNode::new(NodeId(id));
        lb.parent = Some(NodeId(0));
        lb.transform = Affine::translate(0.0, rows as f32 * CELL_H + 10.0);
        lb.bounds = RectF::new(0.0, 0.0, 200.0, 300.0);
        let mut prims = vec![Prim::FillRect {
            rect: lb.bounds,
            paint: Paint::Solid(Color::rgba(0xFF, 0xFF, 0xFF, 0xFF)),
        }];
        for r in 0..14 {
            let t = format!("Item {}", r + items / 2);
            prims.push(Prim::DrawText {
                run: text_run_id(&key(), &t),
                rect: RectF::new(2.0, 2.0 + r as f32 * 13.0, 190.0, 13.0),
                align: TextAlign::Left,
                wrap: false,
                clip: true,
                paint: Paint::Solid(Color::rgba(0, 0, 0, 0xFF)),
                flags: TextFlags::default(),
            });
            runs.push(t);
        }
        lb.prims = prims;
        root.children.push(NodeId(id));
        nodes.push(lb);
    }
    nodes.push(root);
    nodes.sort_by_key(|n| n.id);
    scene.nodes = nodes;
    for t in runs.iter().map(String::as_str).chain(["X0", "X1"]) {
        scene.upsert_text_run(shaper.shape(&key(), t));
    }
    scene.recompute_frame_hash();
    Built {
        scene,
        target: (n / 2).max(1) as u64,
    }
}

fn median(v: &mut [f64]) -> f64 {
    v.sort_by(|a, b| a.partial_cmp(b).unwrap());
    v[v.len() / 2]
}

fn measure(label: &str, mut built: Built, fonts: &FontTable) {
    let (w, h) = (built.scene.surface.width, built.scene.surface.height);
    let mut pixmap = tiny_skia::Pixmap::new(w, h).expect("pixmap");
    calcforms_pal_win::render_scene_to_pixmap(&built.scene, &mut pixmap, fonts);
    let n = built.scene.nodes.len();
    let iters = if n > 2000 { 60 } else { 300 };
    let (mut patch, mut repaint) = (Vec::new(), Vec::new());
    for it in 0..iters + 5 {
        let text = if it % 2 == 0 { "X0" } else { "X1" };
        let mut node = built.scene.get(NodeId(built.target)).unwrap().clone();
        node.prims = label_prims(text);
        let p = ScenePatch {
            version: SCENE_PATCH_VERSION,
            base_hash: built.scene.frame_hash,
            surface: built.scene.surface,
            dpi: built.scene.dpi,
            edits: vec![NodeEdit::Upsert(node)],
        };
        let t0 = Instant::now();
        let damage = built.scene.apply_patch(&p).expect("patch");
        let t1 = Instant::now();
        built.scene.damage = damage;
        repaint_scene_damage(&built.scene, &mut pixmap, fonts);
        let t2 = Instant::now();
        if it >= 5 {
            patch.push((t1 - t0).as_secs_f64() * 1e6);
            repaint.push((t2 - t1).as_secs_f64() * 1e6);
        }
    }
    let (p, r) = (median(&mut patch), median(&mut repaint));
    println!(
        "{label:<36} nodes={n:<6} patch={p:>9.1} us  repaint={r:>9.1} us  total={:>9.1} us",
        p + r
    );
}

fn main() {
    let font = load_ui_font().expect("platform UI font");
    let shaper = AbGlyphShaper::new(FONT, font.clone());
    let mut fonts = FontTable::new();
    fonts.add(FONT, font);
    for n in [50usize, 500, 5000] {
        measure(
            &format!("{n} controls, flat"),
            build(n, false, None, &shaper),
            &fonts,
        );
        measure(
            &format!("{n} controls, frames of 50"),
            build(n, true, None, &shaper),
            &fonts,
        );
    }
    measure(
        "50 controls + ListBox(10,000 items)",
        build(50, false, Some(10_000), &shaper),
        &fonts,
    );
}
