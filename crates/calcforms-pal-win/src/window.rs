//! winit window + softbuffer present loop.
//!
//! [`run_scene_window`] opens a window and owns **Repaint** (the resident `Scene` →
//! pixels operation of `RENDERING_ARCHITECTURE.md` §16): on each redraw it rasterizes
//! the current [`Scene`] into a `tiny_skia::Pixmap` (via [`crate::raster`]) and blits
//! it to the softbuffer surface — a pure-Rust step that never enters the VM. Window
//! events are normalized to [`UiEvent`]s (via [`crate::input`]) and handed to a caller
//! callback, which returns a [`WindowSignal`]. The window itself is control-blind: it
//! knows pixels, scenes, and normalized input — never controls or routing.
//!
//! Per §16 the `Scene` this loop holds is a **consumed snapshot**. The revision-driven
//! consumer loop — the callback dispatches input to the runtime and, on a requested
//! repaint, refreshes the held `Scene` from the latest resident revision (produced by
//! Re-render) and returns [`WindowSignal::Redraw`] — is how the runtime drives live
//! updates. The W007 bootstrap (oxforms-4pn.8e) runs exactly this loop; the smoke binary
//! exercises the mutate→`Redraw` shape directly (no VBA in its loop).
//!
//! The callback emits *client-pixel* coordinates; mapping those to a form's logical
//! points is the bootstrap's job (it knows the render scale).

use std::num::NonZeroU32;
use std::rc::Rc;

use calcforms_pal::scene::Scene;
use calcforms_pal::{DpiScale, KeyboardModifiers, MouseButtons, UiEvent, UiEventId};
use winit::application::ApplicationHandler;
use winit::dpi::LogicalSize;
use winit::event::{ElementState, WindowEvent};
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop};
use winit::platform::modifier_supplement::KeyEventExtModifierSupplement;
use winit::window::{Window, WindowId};

use crate::input;
use crate::text::FontTable;

/// What a caller's event callback asks the window to do next.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum WindowSignal {
    /// Nothing to do.
    Ignore,
    /// Scene changed; schedule a repaint.
    Redraw,
    /// Tear the window down and return from [`run_scene_window`].
    Close,
}

/// Window creation options.
#[derive(Clone, Debug)]
pub struct WindowOptions {
    pub title: String,
    /// Initial inner size in logical pixels.
    pub logical_width: f64,
    pub logical_height: f64,
    /// Show without taking keyboard focus from another application.
    pub activate_on_show: bool,
}

impl WindowOptions {
    #[must_use]
    pub fn new(title: impl Into<String>, logical_width: f64, logical_height: f64) -> Self {
        Self {
            title: title.into(),
            logical_width,
            logical_height,
            activate_on_show: false,
        }
    }
}

/// Errors from running the window loop.
#[derive(Debug)]
pub enum WindowError {
    EventLoop(String),
    Surface(String),
}

impl std::fmt::Display for WindowError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::EventLoop(m) => write!(f, "event loop error: {m}"),
            Self::Surface(m) => write!(f, "surface error: {m}"),
        }
    }
}

impl std::error::Error for WindowError {}

/// Open a window presenting `scene`, normalizing input to `on_event`. Blocks until the
/// window closes. `on_event` receives each normalized event and the mutable scene, and
/// returns a [`WindowSignal`].
///
/// # Errors
/// Returns [`WindowError`] if the event loop or drawing surface cannot be created.
pub fn run_scene_window<F>(
    options: WindowOptions,
    scene: Scene,
    fonts: FontTable,
    on_event: F,
) -> Result<(), WindowError>
where
    F: FnMut(&UiEvent, &mut Scene) -> WindowSignal,
{
    let event_loop = EventLoop::new().map_err(|e| WindowError::EventLoop(e.to_string()))?;
    event_loop.set_control_flow(ControlFlow::Wait);
    let mut app = App::new(options, scene, fonts, on_event);
    event_loop
        .run_app(&mut app)
        .map_err(|e| WindowError::EventLoop(e.to_string()))?;
    app.into_result()
}

struct App<F> {
    options: WindowOptions,
    scene: Scene,
    fonts: FontTable,
    on_event: F,
    next_event_id: u64,
    buttons: MouseButtons,
    modifiers: KeyboardModifiers,
    cursor: (f64, f64),
    window: Option<Rc<Window>>,
    surface: Option<softbuffer::Surface<Rc<Window>, Rc<Window>>>,
    /// Retained framebuffer (oxforms-rq5.3): kept across frames so an unchanged-region
    /// repaint reuses prior pixels and only the scene's damage is re-rasterized. Dropped /
    /// reallocated (and full-rendered) on a size change; `None` until the first frame.
    pixmap: Option<tiny_skia::Pixmap>,
    error: Option<WindowError>,
}

impl<F> App<F>
where
    F: FnMut(&UiEvent, &mut Scene) -> WindowSignal,
{
    fn new(options: WindowOptions, scene: Scene, fonts: FontTable, on_event: F) -> Self {
        Self {
            options,
            scene,
            fonts,
            on_event,
            next_event_id: 0,
            buttons: MouseButtons::default(),
            modifiers: KeyboardModifiers::default(),
            cursor: (0.0, 0.0),
            window: None,
            surface: None,
            pixmap: None,
            error: None,
        }
    }

    fn into_result(self) -> Result<(), WindowError> {
        match self.error {
            Some(err) => Err(err),
            None => Ok(()),
        }
    }

    fn next_id(&mut self) -> UiEventId {
        self.next_event_id += 1;
        UiEventId(self.next_event_id)
    }

    fn dpi(&self) -> DpiScale {
        // winit reports a unitless scale factor, not a DPI; 96·factor is the
        // conventional Windows stand-in (96 dpi == 100%). Carried as best-effort
        // device metadata, not an authoritative physical DPI.
        let sf = self.window.as_ref().map_or(1.0, |w| w.scale_factor());
        DpiScale::new(96.0 * sf, 96.0 * sf)
    }

    /// Run the callback for `event` and act on its signal.
    fn dispatch(&mut self, event_loop: &ActiveEventLoop, event: UiEvent) {
        let signal = self.update_scene(&event);
        match signal {
            WindowSignal::Ignore => {}
            WindowSignal::Redraw => {
                if let Some(window) = &self.window {
                    window.request_redraw();
                }
            }
            WindowSignal::Close => event_loop.exit(),
        }
    }

    fn update_scene(&mut self, event: &UiEvent) -> WindowSignal {
        // Several input callbacks can precede one RedrawRequested (notably a
        // mouse-down/up pair). A producer snapshot carries only its last
        // patch's damage. Retain every region not yet presented, even when the
        // newest snapshot is a content-equal resubmit with empty damage.
        let pending = std::mem::take(&mut self.scene.damage);
        let signal = (self.on_event)(event, &mut self.scene);
        self.scene.damage.dirty.extend(pending.dirty);
        for rect in pending.rects {
            if !self.scene.damage.rects.contains(&rect) {
                self.scene.damage.rects.push(rect);
            }
        }
        signal
    }

    /// Record a fatal surface error and tear the loop down, mirroring `resumed`'s
    /// error handling so `run_scene_window` returns it deterministically rather than
    /// spinning on with stale content.
    fn fail(&mut self, event_loop: &ActiveEventLoop, message: String) {
        self.error = Some(WindowError::Surface(message));
        event_loop.exit();
    }

    fn render(&mut self, event_loop: &ActiveEventLoop) {
        let Some(window) = self.window.as_ref() else {
            return;
        };
        let size = window.inner_size();
        let (Some(width), Some(height)) =
            (NonZeroU32::new(size.width), NonZeroU32::new(size.height))
        else {
            return; // minimized / zero-sized: nothing to present (not an error).
        };
        if self.surface.is_none() {
            return;
        }
        if let Err(e) = self.surface.as_mut().unwrap().resize(width, height) {
            self.fail(event_loop, e.to_string());
            return;
        }

        // Reuse the retained framebuffer when it matches the window size; otherwise (first
        // frame / resize) allocate fresh. A reused pixmap gets an INCREMENTAL repaint (only
        // the scene's damage re-rasterized, prior pixels retained); a fresh one a full render
        // (no valid prior pixels). Both yield identical pixels (raster invariant b).
        let reuse = matches!(
            &self.pixmap,
            Some(p) if p.width() == width.get() && p.height() == height.get()
        );
        let mut pixmap = if reuse {
            self.pixmap.take().expect("reuse implies Some")
        } else {
            match tiny_skia::Pixmap::new(width.get(), height.get()) {
                Some(p) => p,
                None => {
                    self.fail(
                        event_loop,
                        format!("pixmap allocation failed for {width}x{height}"),
                    );
                    return;
                }
            }
        };
        if reuse {
            crate::raster::repaint_scene_damage(&self.scene, &mut pixmap, &self.fonts);
        } else {
            crate::raster::render_scene_to_pixmap(&self.scene, &mut pixmap, &self.fonts);
        }

        let surface = self.surface.as_mut().unwrap();
        let mut buffer = match surface.buffer_mut() {
            Ok(b) => b,
            Err(e) => {
                self.error = Some(WindowError::Surface(e.to_string()));
                event_loop.exit();
                return;
            }
        };
        // Present the entire retained pixmap. An expose with no new damage can
        // reuse those pixels; pending regions are consumed only after success.
        for (dst, src) in buffer.iter_mut().zip(pixmap.data().chunks_exact(4)) {
            // softbuffer wants 0RGB; pixmap is opaque RGBA (premultiplied == straight).
            *dst = (u32::from(src[0]) << 16) | (u32::from(src[1]) << 8) | u32::from(src[2]);
        }
        if let Err(e) = buffer.present() {
            self.error = Some(WindowError::Surface(e.to_string()));
            event_loop.exit();
            return;
        }
        // Retain the framebuffer for the next frame's incremental repaint.
        self.pixmap = Some(pixmap);
        self.scene.damage = Default::default();
    }
}

impl<F> ApplicationHandler for App<F>
where
    F: FnMut(&UiEvent, &mut Scene) -> WindowSignal,
{
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.window.is_some() {
            return;
        }
        let attrs = Window::default_attributes()
            .with_active(self.options.activate_on_show)
            .with_title(self.options.title.clone())
            .with_inner_size(LogicalSize::new(
                self.options.logical_width,
                self.options.logical_height,
            ));
        let window = match event_loop.create_window(attrs) {
            Ok(w) => Rc::new(w),
            Err(e) => {
                self.error = Some(WindowError::EventLoop(e.to_string()));
                event_loop.exit();
                return;
            }
        };
        let context = match softbuffer::Context::new(window.clone()) {
            Ok(c) => c,
            Err(e) => {
                self.error = Some(WindowError::Surface(e.to_string()));
                event_loop.exit();
                return;
            }
        };
        let surface = match softbuffer::Surface::new(&context, window.clone()) {
            Ok(s) => s,
            Err(e) => {
                self.error = Some(WindowError::Surface(e.to_string()));
                event_loop.exit();
                return;
            }
        };
        window.request_redraw();
        self.window = Some(window);
        self.surface = Some(surface);
    }

    fn window_event(
        &mut self,
        event_loop: &ActiveEventLoop,
        _window_id: WindowId,
        event: WindowEvent,
    ) {
        match event {
            WindowEvent::CloseRequested => {
                // The callback governs the close (winit does not auto-close): it returns
                // WindowSignal::Close to exit, or Ignore/Redraw to veto/defer — honoring
                // the CloseQueryPolicy::Query the emitted CloseRequest advertises.
                let id = self.next_id();
                self.dispatch(event_loop, input::window_close_request(id));
            }
            WindowEvent::RedrawRequested => self.render(event_loop),
            WindowEvent::Resized(_) => {
                let dpi = self.dpi();
                let size = self
                    .window
                    .as_ref()
                    .map(|w| w.inner_size())
                    .unwrap_or_default();
                let id = self.next_id();
                let ev =
                    input::window_resized(id, f64::from(size.width), f64::from(size.height), dpi);
                self.dispatch(event_loop, ev);
                if let Some(window) = &self.window {
                    window.request_redraw();
                }
            }
            WindowEvent::ModifiersChanged(m) => {
                self.modifiers = input::modifiers(m.state());
            }
            WindowEvent::CursorMoved { position, .. } => {
                self.cursor = (position.x, position.y);
                let (dpi, buttons, mods) = (self.dpi(), self.buttons.clone(), self.modifiers);
                let id = self.next_id();
                let ev = input::pointer_moved(id, position.x, position.y, dpi, buttons, mods);
                self.dispatch(event_loop, ev);
            }
            WindowEvent::MouseInput { state, button, .. } => {
                let button = input::mouse_button(button);
                let pressed = state == ElementState::Pressed;
                input::set_button(&mut self.buttons, button, pressed);
                let (cx, cy) = self.cursor;
                let (dpi, buttons, mods) = (self.dpi(), self.buttons.clone(), self.modifiers);
                let id = self.next_id();
                // click_count is 1: winit's MouseInput reports per-press state only.
                // Multi-click synthesis is a deferred, spec-open question (W005 /
                // INPUT_INTERACTION_MODEL.md), not done in this backend.
                let ev = input::pointer_button(id, button, pressed, cx, cy, dpi, buttons, mods, 1);
                self.dispatch(event_loop, ev);
            }
            WindowEvent::KeyboardInput { event, .. } => {
                let pressed = event.state == ElementState::Pressed;
                let id = self.next_id();
                let key_ev = input::key_event(
                    id,
                    &event.logical_key,
                    pressed,
                    self.modifiers,
                    event.repeat,
                );
                self.dispatch(event_loop, key_ev);
                if pressed {
                    // KeyEvent.text deliberately ignores Ctrl: Ctrl+A would
                    // select all and then replace the selection with "a".
                    // Use the OS text (Ctrl+A = U+0001); the normalizer drops
                    // control characters while retaining AltGr's printable text.
                    if let Some(text) = event.text_with_all_modifiers() {
                        let char_id = self.next_id();
                        if let Some(char_ev) = input::character_input(char_id, text, self.modifiers)
                        {
                            self.dispatch(event_loop, char_ev);
                        }
                    }
                }
            }
            WindowEvent::Focused(focused) => {
                let id = self.next_id();
                self.dispatch(event_loop, input::window_focus(id, focused));
            }
            // Not yet normalized by this backend: mouse wheel (the PAL has a
            // UiEventKind::MouseWheel slot), IME, touch/gesture, and DPI/scale-factor
            // changes. They are dropped here rather than mis-mapped; wiring them is
            // follow-on backend work.
            _ => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use calcforms_pal::scene::{
        NodeEdit, NodeId, Paint, Prim, RectF, SceneNode, ScenePatch, SCENE_PATCH_VERSION,
    };
    use calcforms_pal::{Color, SurfaceSize};

    #[test]
    fn consecutive_input_snapshots_before_one_frame_preserve_all_damage() {
        let size = SurfaceSize::new(40, 40);
        let dpi = DpiScale::new(96.0, 96.0);
        let mut scene = Scene::new(size, dpi, NodeId(0));
        let mut root = SceneNode::new(NodeId(0));
        root.bounds = RectF::new(0.0, 0.0, 40.0, 40.0);
        root.children = vec![NodeId(1), NodeId(2)];
        root.prims = vec![Prim::FillRect {
            rect: root.bounds,
            paint: Paint::Solid(Color::rgba(240, 240, 240, 255)),
        }];
        let control = |id: u64, y: f32, color: Color| {
            let mut node = SceneNode::new(NodeId(id));
            node.parent = Some(NodeId(0));
            node.bounds = RectF::new(6.0, y, 12.0, 8.0);
            node.prims = vec![Prim::FillRect {
                rect: node.bounds,
                paint: Paint::Solid(color),
            }];
            node
        };
        let apply = |scene: &mut Scene, edits| {
            scene
                .apply_patch(&ScenePatch {
                    version: SCENE_PATCH_VERSION,
                    base_hash: scene.frame_hash,
                    surface: size,
                    dpi,
                    edits,
                })
                .expect("valid producer patch");
        };
        apply(
            &mut scene,
            vec![
                NodeEdit::Upsert(root),
                NodeEdit::Upsert(control(1, 6.0, Color::rgba(255, 0, 0, 255))),
                NodeEdit::Upsert(control(2, 26.0, Color::rgba(0, 0, 255, 255))),
            ],
        );
        let fonts = FontTable::new();
        let mut retained = tiny_skia::Pixmap::new(60, 60).expect("150% frame");
        crate::raster::render_scene_to_pixmap(&scene, &mut retained, &fonts);
        scene.damage = Default::default(); // initial frame was presented
        let initial = scene.clone();
        apply(
            &mut scene,
            vec![NodeEdit::Upsert(control(
                1,
                6.0,
                Color::rgba(0, 128, 0, 255),
            ))],
        );
        let first = scene.clone();
        apply(
            &mut scene,
            vec![NodeEdit::Upsert(control(
                2,
                26.0,
                Color::rgba(255, 128, 0, 255),
            ))],
        );
        let second = scene.clone();
        // A content-equal resubmit can be the last callback before RedrawRequested.
        apply(&mut scene, vec![]);
        let mut snapshots = vec![first, second, scene].into_iter();
        let mut app = App::new(
            WindowOptions::new("test", 60.0, 60.0),
            initial,
            fonts,
            move |_, current| {
                *current = snapshots.next().expect("producer snapshot");
                WindowSignal::Redraw
            },
        );
        for id in 1..=3 {
            assert_eq!(
                app.update_scene(&input::window_focus(UiEventId(id), true)),
                WindowSignal::Redraw
            );
        }
        crate::raster::repaint_scene_damage(&app.scene, &mut retained, &app.fonts);
        let mut full = tiny_skia::Pixmap::new(60, 60).expect("full frame");
        crate::raster::render_scene_to_pixmap(&app.scene, &mut full, &app.fonts);
        assert!(
            retained.data() == full.data(),
            "coalesced mouse-down/up frames must erase old focus and retain every change"
        );
    }
}
