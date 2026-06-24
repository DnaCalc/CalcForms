//! A hand-authored, control-agnostic primitive scene for the W007 visible smoke.
//!
//! This is **raw `Prim` data**, not a control renderer: it stands in for what the VBA
//! self-render path (`OxControlPaint` → `OxSceneBuilder`) will emit across the
//! `OxForms.Surface` boundary, so the desktop backend can be exercised end-to-end —
//! Scene → pixels in a real window with text — before the OxVba integration is wired
//! (that is oxforms-4pn.7/.8). It mirrors the demo greeter's *shape* (a sunken input
//! field, a raised default OK button, an output label) in the post-interaction state
//! ("World" typed, "Hello, World" shown) so the screenshot tells the demo's story.
//!
//! The backend stays control-blind: this fixture only uses `oxforms_pal` Scene types,
//! exactly as a boundary-delivered patch would.

use ab_glyph::FontArc;
use oxforms_pal::scene::{
    Affine, EdgeBorder, EdgeEffect, FontId, NodeId, Paint, Prim, RectF, Scene, SceneNode, Stroke,
    TextAlign, TextFlags, TextRunId,
};
use oxforms_pal::{Color, DpiScale, SurfaceSize};

use crate::text::{ResolvedTextRun, TextRegistry};

/// Classic MSForms-ish palette (opaque RGBA).
const FORM_FACE: Color = Color::rgba(0xF0, 0xF0, 0xF0, 0xFF);
const FIELD_BG: Color = Color::rgba(0xFF, 0xFF, 0xFF, 0xFF);
const EDGE_LIGHT: Color = Color::rgba(0xFF, 0xFF, 0xFF, 0xFF);
const EDGE_SHADOW: Color = Color::rgba(0x80, 0x80, 0x80, 0xFF);
const TEXT: Color = Color::rgba(0x10, 0x10, 0x10, 0xFF);
const DEFAULT_BORDER: Color = Color::rgba(0x20, 0x20, 0x20, 0xFF);

const FORM_W: f32 = 200.0;
const FORM_H: f32 = 120.0;
const FONT_PX: f32 = 8.0;

/// The font id every fixture run references; register the loaded face under it.
pub const FIXTURE_FONT: FontId = FontId(1);

const RUN_FIELD: TextRunId = TextRunId(1);
const RUN_BUTTON: TextRunId = TextRunId(2);
const RUN_LABEL: TextRunId = TextRunId(3);

/// The greeter scene as a control-agnostic primitive tree (logical points).
#[must_use]
pub fn greeter_scene() -> Scene {
    let mut scene = Scene::new(
        SurfaceSize::new(FORM_W as u32, FORM_H as u32),
        DpiScale::new(96.0, 96.0),
        NodeId(0),
    );

    // Root: form background, owns the three control nodes in paint order.
    let mut root = SceneNode::new(NodeId(0));
    root.bounds = RectF::new(0.0, 0.0, FORM_W, FORM_H);
    root.prims = vec![Prim::FillRect {
        rect: RectF::new(0.0, 0.0, FORM_W, FORM_H),
        paint: Paint::Solid(FORM_FACE),
    }];
    root.children = vec![NodeId(1), NodeId(2), NodeId(3)];

    // InputField: a sunken white text field showing "World", text clipped to the field.
    let mut field = SceneNode::new(NodeId(1));
    field.parent = Some(NodeId(0));
    field.transform = Affine::translate(12.0, 12.0);
    field.bounds = RectF::new(0.0, 0.0, 120.0, 18.0);
    field.clip = Some(RectF::new(0.0, 0.0, 120.0, 18.0));
    field.prims = vec![
        Prim::FillRect {
            rect: RectF::new(0.0, 0.0, 120.0, 18.0),
            paint: Paint::Solid(FIELD_BG),
        },
        Prim::DrawEdge {
            rect: RectF::new(0.0, 0.0, 120.0, 18.0),
            effect: EdgeEffect::Sunken,
            border: EdgeBorder::ALL,
            light: EDGE_LIGHT,
            shadow: EDGE_SHADOW,
        },
        Prim::DrawText {
            run: RUN_FIELD,
            rect: RectF::new(4.0, 0.0, 112.0, 18.0),
            align: TextAlign::Left,
            wrap: false,
            clip: true,
            paint: Paint::Solid(TEXT),
            flags: TextFlags::default(),
        },
    ];

    // OkButton: a raised default button labelled "OK" (black default outline).
    let mut button = SceneNode::new(NodeId(2));
    button.parent = Some(NodeId(0));
    button.transform = Affine::translate(140.0, 12.0);
    button.bounds = RectF::new(0.0, 0.0, 48.0, 20.0);
    button.prims = vec![
        Prim::FillRect {
            rect: RectF::new(0.0, 0.0, 48.0, 20.0),
            paint: Paint::Solid(FORM_FACE),
        },
        Prim::StrokeRect {
            rect: RectF::new(0.0, 0.0, 48.0, 20.0),
            stroke: Stroke {
                paint: Paint::Solid(DEFAULT_BORDER),
                width: 1.0,
            },
        },
        Prim::DrawEdge {
            rect: RectF::new(1.0, 1.0, 46.0, 18.0),
            effect: EdgeEffect::Raised,
            border: EdgeBorder::ALL,
            light: EDGE_LIGHT,
            shadow: EDGE_SHADOW,
        },
        Prim::DrawText {
            run: RUN_BUTTON,
            rect: RectF::new(0.0, 0.0, 48.0, 20.0),
            align: TextAlign::Center,
            wrap: false,
            clip: true,
            paint: Paint::Solid(TEXT),
            flags: TextFlags::default(),
        },
    ];

    // OutputLabel: transparent label over the form face showing the greeting.
    let mut label = SceneNode::new(NodeId(3));
    label.parent = Some(NodeId(0));
    label.transform = Affine::translate(12.0, 44.0);
    label.bounds = RectF::new(0.0, 0.0, 176.0, 18.0);
    label.prims = vec![Prim::DrawText {
        run: RUN_LABEL,
        rect: RectF::new(0.0, 0.0, 176.0, 18.0),
        align: TextAlign::Left,
        wrap: false,
        clip: false,
        paint: Paint::Solid(TEXT),
        flags: TextFlags::default(),
    }];

    scene.nodes = vec![root, field, button, label];
    scene.recompute_frame_hash();
    scene
}

/// The text registry the greeter scene's run ids resolve against. Register the loaded
/// platform font face under [`FIXTURE_FONT`].
#[must_use]
pub fn greeter_text(font: FontArc) -> TextRegistry {
    let mut reg = TextRegistry::new();
    reg.add_font(FIXTURE_FONT, font);
    reg.add_run(
        RUN_FIELD,
        ResolvedTextRun::new("World", FIXTURE_FONT, FONT_PX),
    );
    reg.add_run(
        RUN_BUTTON,
        ResolvedTextRun::new("OK", FIXTURE_FONT, FONT_PX),
    );
    reg.add_run(
        RUN_LABEL,
        ResolvedTextRun::new("Hello, World", FIXTURE_FONT, FONT_PX),
    );
    reg
}

#[cfg(test)]
mod tests {
    use super::*;
    use oxforms_pal::scene::render_headless_report;

    #[test]
    fn greeter_scene_has_the_expected_tree_and_renders_headlessly() {
        let scene = greeter_scene();
        assert_eq!(scene.nodes.len(), 4);
        assert_eq!(scene.root, NodeId(0));
        assert_eq!(
            scene.get(NodeId(0)).expect("root").children,
            vec![NodeId(1), NodeId(2), NodeId(3)]
        );
        // The text-free golden oracle walks every node without needing a font.
        let report = render_headless_report(&scene);
        assert_eq!(report.width, FORM_W as u32);
        assert_eq!(report.height, FORM_H as u32);
        // 1 form fill + field(3) + button(4) + label(1) prims walked.
        assert_eq!(report.command_count, 9);
    }

    #[test]
    fn every_text_run_in_the_scene_resolves_in_the_registry() {
        // Guard the fixture's own consistency: no DrawText run id is left dangling.
        let Some(font) = crate::text::host_font_or_skip() else {
            return;
        };
        let reg = greeter_text(font);
        let scene = greeter_scene();
        use crate::text::TextResolver;
        for node in &scene.nodes {
            for prim in &node.prims {
                if let Prim::DrawText { run, .. } = prim {
                    assert!(
                        reg.resolve(*run).is_some(),
                        "scene references unresolved run {run:?}"
                    );
                }
            }
        }
    }
}
