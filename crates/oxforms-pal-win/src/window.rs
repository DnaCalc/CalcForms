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
//! consumer loop — the callback refreshes the held `Scene` from the latest resident
//! revision the runtime produced by Re-render and returns [`WindowSignal::Redraw`] — is
//! how the full runtime drives live updates; the W007 smoke binary already exercises
//! that mutate→`Redraw` shape directly (no VBA in its loop). The oxforms-4pn.7 bootstrap
//! is a one-shot: it produces the first resident revision and presents that snapshot
//! statically, its callback governing only window close; wiring the revision-refresh
//! consumer loop into the bootstrap is the next increment.
//!
//! The callback emits *client-pixel* coordinates; mapping those to a form's logical
//! points is the bootstrap's job (it knows the render scale) via
//! [`crate::input::with_form_logical`].

use std::num::NonZeroU32;
use std::rc::Rc;

use oxforms_pal::scene::Scene;
use oxforms_pal::{DpiScale, KeyboardModifiers, MouseButtons, UiEvent, UiEventId};
use winit::application::ApplicationHandler;
use winit::dpi::LogicalSize;
use winit::event::{ElementState, WindowEvent};
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop};
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
}

impl WindowOptions {
    #[must_use]
    pub fn new(title: impl Into<String>, logical_width: f64, logical_height: f64) -> Self {
        Self {
            title: title.into(),
            logical_width,
            logical_height,
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
        let signal = (self.on_event)(&event, &mut self.scene);
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

        let mut pixmap = match tiny_skia::Pixmap::new(width.get(), height.get()) {
            Some(p) => p,
            None => {
                self.fail(
                    event_loop,
                    format!("pixmap allocation failed for {width}x{height}"),
                );
                return;
            }
        };
        crate::raster::render_scene_to_pixmap(&self.scene, &mut pixmap, &self.fonts);

        let surface = self.surface.as_mut().unwrap();
        let mut buffer = match surface.buffer_mut() {
            Ok(b) => b,
            Err(e) => {
                self.error = Some(WindowError::Surface(e.to_string()));
                event_loop.exit();
                return;
            }
        };
        for (dst, src) in buffer.iter_mut().zip(pixmap.data().chunks_exact(4)) {
            // softbuffer wants 0RGB; pixmap is opaque RGBA (premultiplied == straight).
            *dst = (u32::from(src[0]) << 16) | (u32::from(src[1]) << 8) | u32::from(src[2]);
        }
        if let Err(e) = buffer.present() {
            self.error = Some(WindowError::Surface(e.to_string()));
            event_loop.exit();
        }
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
                    if let Some(text) = &event.text {
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
