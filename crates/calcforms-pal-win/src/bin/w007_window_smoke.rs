//! W007 visible smoke: open a real window showing the greeter scene.
//!
//! This is the non-headless verification path for oxforms-4pn.6 — windows cannot be
//! checked by the golden oracle, so the backend is proven by *rendering to screen* and
//! screenshotting it. It rasterizes the raw-primitive greeter fixture (the stand-in
//! for VBA self-render output) and normalizes input, logging each event.
//!
//! It also exercises the mutate→`Redraw` path the window API exists for: pressing the
//! mouse nudges the OK button into a "pressed" offset and requests a repaint; releasing
//! restores it. Close the window or press Escape to exit.
//!
//! Run: `cargo run -p calcforms-pal-win --bin w007_window_smoke`

use calcforms_pal::scene::{Affine, NodeId, Scene};
use calcforms_pal::{KeyCode, UiEvent, UiEventKind};
use calcforms_pal_win::fixture::greeter;
use calcforms_pal_win::{load_ui_font, run_scene_window, WindowOptions, WindowSignal};

/// The OK button node id in the greeter fixture, and its resting offset.
const OK_BUTTON: NodeId = NodeId(2);
const OK_REST: (f32, f32) = (140.0, 12.0);

fn main() {
    let font = match load_ui_font() {
        Ok(font) => font,
        Err(err) => {
            eprintln!("could not load a platform UI font: {err}");
            std::process::exit(1);
        }
    };

    let (scene, fonts) = greeter(font);
    let options = WindowOptions::new("CalcForms — W007 greeter (smoke)", 600.0, 360.0);

    println!("W007 window smoke: showing the greeter scene. Close or press Escape to exit.");

    let result = run_scene_window(
        options,
        scene,
        fonts,
        |event: &UiEvent, scene: &mut Scene| {
            log_event(event);
            match &event.kind {
                UiEventKind::KeyDown(e) if e.key == KeyCode::Escape => WindowSignal::Close,
                UiEventKind::CloseRequest(_) => WindowSignal::Close,
                UiEventKind::MouseDown(_) => {
                    set_button_pressed(scene, true);
                    WindowSignal::Redraw
                }
                UiEventKind::MouseUp(_) => {
                    set_button_pressed(scene, false);
                    WindowSignal::Redraw
                }
                _ => WindowSignal::Ignore,
            }
        },
    );

    if let Err(err) = result {
        eprintln!("window error: {err}");
        std::process::exit(1);
    }
}

/// Mutate the scene: offset the OK button by 1pt while pressed (a live repaint demo).
fn set_button_pressed(scene: &mut Scene, pressed: bool) {
    let (x, y) = OK_REST;
    let offset = if pressed { 1.0 } else { 0.0 };
    if let Some(node) = scene.nodes.iter_mut().find(|n| n.id == OK_BUTTON) {
        node.transform = Affine::translate(x + offset, y + offset);
    }
}

fn log_event(event: &UiEvent) {
    // Keep the log terse but proof-bearing: the event kind discriminant.
    let label = match &event.kind {
        UiEventKind::MouseMove(_) => return, // too chatty to log every move
        UiEventKind::MouseDown(e) => {
            format!(
                "MouseDown {:?} @ {:?}",
                e.button, e.coordinates.client_pixels
            )
        }
        UiEventKind::MouseUp(e) => {
            format!("MouseUp {:?} @ {:?}", e.button, e.coordinates.client_pixels)
        }
        UiEventKind::KeyDown(e) => format!("KeyDown {:?}", e.key),
        UiEventKind::KeyUp(e) => format!("KeyUp {:?}", e.key),
        UiEventKind::CharacterInput(e) => format!("CharacterInput {:?}", e.text),
        UiEventKind::FocusIn(_) => "FocusIn".to_string(),
        UiEventKind::FocusOut(_) => "FocusOut".to_string(),
        UiEventKind::CloseRequest(_) => "CloseRequest".to_string(),
        UiEventKind::Resize(e) => format!("Resize {:?}", e.client_size),
        other => format!("{other:?}"),
    };
    println!("  event #{}: {label}", event.event_id.0);
}
