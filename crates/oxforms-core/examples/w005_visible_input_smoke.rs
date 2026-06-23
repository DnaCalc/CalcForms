use std::error::Error;
use std::fs;
use std::path::{Path, PathBuf};

use oxforms_core::{
    build_probe_pal_smoke_display_list, reduce, transition_trace_rows, ControlNode, FormState,
    TracePhase,
};
use oxforms_pal::{
    render_headless, ActivationEvent, ActivationReason, CharacterInputEvent, ClickCount,
    CloseQueryPolicy, CloseReason, CloseRequestEvent, CloseRequestOrigin, CoordinatePayload,
    CoordinatePoint, CoordinateSpace, DpiScale, FormId, KeyCode, KeyEvent, KeyRepeat,
    KeyboardModifiers, LifecycleReason, LogicalPoint, LogicalRect, MouseButton, MouseButtonEvent,
    MouseButtons, PixelPoint, PixelRect, RawCoordinateSample, RawDiagnostic, RawDiagnosticValue,
    RawKeyDiagnostics, ResizeEvent, ShowMode, ShowRequestedEvent, SurfaceSize, UiEvent, UiEventId,
    UiEventKind, UiEventSource, UiEventTarget, WindowId, WindowShownEvent,
};
use serde::Serialize;

const BEAD: &str = "oxforms-xvx.11";
const FORM_ID: &str = "w005-visible-probe-form";
const WINDOW_ID: &str = "w005-visible-input-window";
const TITLE: &str = "OxForms W005 Visible Input Smoke";
const WIDTH: u32 = 260;
const HEIGHT: u32 = 128;
const DPI_FOR_ONE_PIXEL_PER_POINT: f64 = 72.0;

fn main() -> Result<(), Box<dyn Error>> {
    let config = SmokeConfig::from_args(std::env::args().skip(1))?;
    if config.help {
        print_help();
        return Ok(());
    }

    #[cfg(windows)]
    {
        return run_windows_smoke(config);
    }

    #[cfg(not(windows))]
    {
        let _ = config;
        println!("unsupported: W005 visible input smoke requires a Windows desktop session");
        Ok(())
    }
}

#[derive(Clone, Debug, Default)]
struct SmokeConfig {
    dry_run: bool,
    hold_ms: u64,
    evidence_dir: Option<PathBuf>,
    help: bool,
}

impl SmokeConfig {
    fn from_args(args: impl IntoIterator<Item = String>) -> Result<Self, Box<dyn Error>> {
        let mut config = Self {
            hold_ms: 10_000,
            ..Self::default()
        };
        let mut args = args.into_iter();

        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--dry-run" => config.dry_run = true,
                "--hold-ms" => {
                    let value = args.next().ok_or("--hold-ms requires a value")?;
                    config.hold_ms = value.parse()?;
                }
                "--evidence-dir" => {
                    let value = args.next().ok_or("--evidence-dir requires a value")?;
                    config.evidence_dir = Some(PathBuf::from(value));
                }
                "--help" | "-h" => config.help = true,
                _ => return Err(format!("unknown argument: {arg}").into()),
            }
        }

        Ok(config)
    }
}

fn print_help() {
    println!(
        "Usage: cargo run -p oxforms-core --example w005_visible_input_smoke -- [--dry-run] [--hold-ms N] [--evidence-dir DIR]"
    );
}

#[cfg(windows)]
fn run_windows_smoke(config: SmokeConfig) -> Result<(), Box<dyn Error>> {
    use std::cell::RefCell;
    use std::rc::Rc;
    use std::thread;
    use std::time::{Duration, Instant};

    use minifb::{
        InputCallback, KeyRepeat as MiniKeyRepeat, MouseButton as MiniMouseButton, MouseMode,
        Scale, Window, WindowOptions,
    };

    #[derive(Clone)]
    struct CharSink {
        chars: Rc<RefCell<Vec<u32>>>,
    }

    impl InputCallback for CharSink {
        fn add_char(&mut self, uni_char: u32) {
            self.chars.borrow_mut().push(uni_char);
        }
    }

    let mut smoke = VisibleSmoke::new();
    let event_id = smoke.next_event_id();
    smoke.apply_event(show_requested_event(event_id));
    smoke.repaint()?;

    if config.dry_run {
        let event_id = smoke.next_event_id();
        smoke.apply_event(window_shown_event(event_id, None));
        let event_id = smoke.next_event_id();
        smoke.apply_event(activate_event(event_id));
        let event_id = smoke.next_event_id();
        smoke.apply_event(resize_event(event_id));
        smoke.repaint()?;
        println!("dry run: W005 visible input window creation skipped");
        smoke.write_evidence(config.evidence_dir.as_deref(), "dry_run")?;
        return Ok(());
    }

    let chars = Rc::new(RefCell::new(Vec::new()));
    let mut window = Window::new(
        TITLE,
        usize::try_from(WIDTH)?,
        usize::try_from(HEIGHT)?,
        WindowOptions {
            resize: false,
            scale: Scale::X2,
            ..WindowOptions::default()
        },
    )?;
    window.set_target_fps(60);
    window.set_input_callback(Box::new(CharSink {
        chars: chars.clone(),
    }));

    let (window_x, window_y) = window.get_position();
    let (window_width, window_height) = window.get_size();
    let event_id = smoke.next_event_id();
    smoke.apply_event(window_shown_event(
        event_id,
        Some(PixelRect::new(
            window_x as f64,
            window_y as f64,
            window_width as f64,
            window_height as f64,
        )),
    ));
    let event_id = smoke.next_event_id();
    smoke.apply_event(activate_event(event_id));
    let event_id = smoke.next_event_id();
    smoke.apply_event(resize_event(event_id));
    smoke.repaint()?;

    let mut last_left_down = false;
    let mut last_mouse_pos: Option<(f32, f32)> = None;
    let mut emitted_focus_in = false;
    let deadline = Instant::now() + Duration::from_millis(config.hold_ms);

    while window.is_open() && Instant::now() < deadline {
        if window.is_active() && !emitted_focus_in {
            emitted_focus_in = true;
            smoke.record_lifecycle_pump("active", "host_modeless_pump");
        }

        if let Some((x, y)) = window.get_mouse_pos(MouseMode::Pass) {
            if last_mouse_pos != Some((x, y)) {
                last_mouse_pos = Some((x, y));
                let event_id = smoke.next_event_id();
                smoke.apply_event(mouse_move_event(event_id, x, y, last_left_down));
                smoke.repaint()?;
            }
        }

        let left_down = window.get_mouse_down(MiniMouseButton::Left);
        if left_down != last_left_down {
            let (x, y) = last_mouse_pos.unwrap_or((0.0, 0.0));
            let event_id = smoke.next_event_id();
            let event = if left_down {
                mouse_button_event(event_id, x, y, true)
            } else {
                mouse_button_event(event_id, x, y, false)
            };
            smoke.apply_event(event);
            smoke.repaint()?;
            last_left_down = left_down;
        }

        for key in window.get_keys_pressed(MiniKeyRepeat::No) {
            let event_id = smoke.next_event_id();
            smoke.apply_event(key_event(event_id, key, true));
            smoke.repaint()?;
        }

        for codepoint in chars.borrow_mut().drain(..) {
            if let Some(character) = char::from_u32(codepoint) {
                if !character.is_control() {
                    let event_id = smoke.next_event_id();
                    smoke.apply_event(character_event(event_id, character));
                    smoke.repaint()?;
                }
            }
        }

        for key in window.get_keys_released() {
            let event_id = smoke.next_event_id();
            smoke.apply_event(key_event(event_id, key, false));
            smoke.repaint()?;
        }

        window.update_with_buffer(
            &smoke.present_buffer,
            usize::try_from(WIDTH)?,
            usize::try_from(HEIGHT)?,
        )?;
        thread::sleep(Duration::from_millis(8));
    }

    let status = if window.is_open() {
        "timed_out"
    } else {
        let event_id = smoke.next_event_id();
        smoke.apply_event(close_request_event(event_id));
        smoke.record_lifecycle_pump("close_requested", "close_unload_cancellation");
        smoke.repaint()?;
        "closed_by_platform"
    };

    smoke.write_evidence(config.evidence_dir.as_deref(), status)?;
    println!(
        "W005 visible input smoke finished: status={status}, ui_events={}, effects={}, text='{}'",
        smoke.ui_event_count,
        smoke.effect_count,
        smoke.textbox_text()
    );
    Ok(())
}

struct VisibleSmoke {
    state: FormState,
    next_event: u64,
    next_row_sequence: u64,
    ui_event_count: u64,
    effect_count: u64,
    rows: Vec<EvidenceRow>,
    present_buffer: Vec<u32>,
    render_hash: u64,
}

impl VisibleSmoke {
    fn new() -> Self {
        let mut state = FormState::new(FORM_ID);
        state.controls = vec![
            ControlNode::label("label", LogicalRect::new(12.0, 12.0, 84.0, 24.0), 0)
                .with_caption("W005"),
            ControlNode::text_box("text-1", LogicalRect::new(12.0, 52.0, 124.0, 28.0), 0, 0),
            ControlNode::command_button("ok", LogicalRect::new(160.0, 52.0, 72.0, 28.0), 0, 1)
                .with_caption("&OK"),
        ];
        state.default_button = Some(oxforms_pal::ControlId::new("ok"));

        Self {
            state,
            next_event: 1,
            next_row_sequence: 1,
            ui_event_count: 0,
            effect_count: 0,
            rows: Vec::new(),
            present_buffer: vec![0; usize::try_from(WIDTH * HEIGHT).expect("small surface")],
            render_hash: 0,
        }
    }

    fn next_event_id(&mut self) -> UiEventId {
        let id = UiEventId(self.next_event);
        self.next_event += 1;
        id
    }

    fn apply_event(&mut self, event: UiEvent) {
        self.ui_event_count += 1;
        self.push_row("input", "ui_event", &event);
        let output = reduce(self.state.clone(), event);
        self.effect_count += u64::try_from(output.effects.len()).unwrap_or(0);
        for trace_row in transition_trace_rows(
            &output.transition,
            &output.effects,
            &output.invalidations,
            self.next_row_sequence,
            output.transition.causal_ui_event_id.0,
        ) {
            self.next_row_sequence = trace_row.sequence + 1;
            let phase = match trace_row.phase {
                TracePhase::Reducer => "reducer",
                TracePhase::Effect => "effect",
                TracePhase::Render => "render",
            };
            let kind = format!("{:?}", trace_row.kind);
            self.push_row(phase, &kind, &trace_row);
        }
        self.state = output.state;
    }

    fn record_lifecycle_pump(&mut self, lifecycle_state: &str, pump_term: &str) {
        let active_form = self
            .state
            .active
            .active_form
            .as_ref()
            .map(|id| id.0.clone());
        let active_window = self
            .state
            .active
            .active_window
            .as_ref()
            .map(|id| id.0.clone());
        self.push_row(
            "pump",
            "lifecycle_pump",
            &LifecyclePumpEvidence {
                lifecycle_state,
                pump_term,
                modal_depth: self.state.pump.nested_modal_depth,
                active_form: active_form.as_deref(),
                active_window: active_window.as_deref(),
            },
        );
    }

    fn repaint(&mut self) -> Result<(), Box<dyn Error>> {
        let display_list =
            build_probe_pal_smoke_display_list(&self.state, SurfaceSize::new(WIDTH, HEIGHT));
        let render = render_headless(&display_list)?;
        self.render_hash = render.diagnostics.framebuffer_hash;
        self.present_buffer = rgba8_to_minifb(&render.pixels)?;
        self.push_row(
            "render",
            "render_artifact",
            &RenderEvidence {
                width: render.diagnostics.width,
                height: render.diagnostics.height,
                command_count: render.diagnostics.command_count,
                framebuffer_hash: render.diagnostics.framebuffer_hash,
                hash_algorithm: render.diagnostics.hash_algorithm,
            },
        );
        Ok(())
    }

    fn textbox_text(&self) -> String {
        self.state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id.0 == "text-1")
            .map(|entry| entry.text.clone())
            .unwrap_or_default()
    }

    fn write_evidence(
        &self,
        evidence_dir: Option<&Path>,
        status: &str,
    ) -> Result<(), Box<dyn Error>> {
        let Some(evidence_dir) = evidence_dir else {
            return Ok(());
        };

        fs::create_dir_all(evidence_dir)?;
        let trace_path = evidence_dir.join("visible-input-trace.json");
        let frame_path = evidence_dir.join("visible-input-frame.ppm");
        write_ppm(&frame_path, &self.present_buffer, WIDTH, HEIGHT)?;

        let artifact = EvidenceArtifact {
            schema: "oxforms.w005.visible_input_smoke.v1",
            bead: BEAD,
            status,
            title: TITLE,
            command_hint: "cargo run -p oxforms-core --example w005_visible_input_smoke -- --evidence-dir <dir>",
            scenario: ScenarioEvidence {
                intent: "Open a W005 probe surface and route platform mouse/key/char/close input through oxforms-pal UiEvent rows and oxforms-core reduce().",
                controls: vec![
                    "label: non-focus mouse probe",
                    "text-1: focusable TextBox probe",
                    "ok: default CommandButton probe",
                ],
                coordinate_policy: "minifb unscaled client pixels are normalized 1:1 into form_logical points for this W005 smoke; the driver records screen/client injection coordinates separately.",
            },
            coverage: CoverageEvidence {
                ui_event_count: self.ui_event_count,
                effect_count: self.effect_count,
                final_focus_owner: format!("{:?}", self.state.focus_owner),
                final_lifecycle: format!("{:?}", self.state.lifecycle),
                final_pump_term: format!("{:?}", self.state.pump.term),
                text_box_text: self.textbox_text(),
                framebuffer_hash: self.render_hash,
            },
            artifacts: ArtifactRefs {
                frame_ppm: "visible-input-frame.ppm",
            },
            rows: &self.rows,
            non_claims: vec![
                "This is W005 evidence/test infrastructure, not a final UserForm.Show host.",
                "Headless reducer tests and future trace/replay remain the deterministic verification path.",
                "The 1:1 client-pixel/form-logical mapping is a smoke harness projection, not an MSForms DPI parity claim.",
            ],
        };

        fs::write(trace_path, serde_json::to_string_pretty(&artifact)?)?;
        Ok(())
    }

    fn push_row<T: Serialize>(&mut self, phase: &str, kind: &str, payload: &T) {
        let payload = serde_json::to_value(payload).expect("evidence rows should serialize");
        self.rows.push(EvidenceRow {
            sequence: self.next_row_sequence,
            phase: phase.to_string(),
            kind: kind.to_string(),
            payload,
        });
        self.next_row_sequence += 1;
    }
}

#[derive(Serialize)]
struct EvidenceArtifact<'a> {
    schema: &'a str,
    bead: &'a str,
    status: &'a str,
    title: &'a str,
    command_hint: &'a str,
    scenario: ScenarioEvidence<'a>,
    coverage: CoverageEvidence,
    artifacts: ArtifactRefs<'a>,
    rows: &'a [EvidenceRow],
    non_claims: Vec<&'a str>,
}

#[derive(Serialize)]
struct ScenarioEvidence<'a> {
    intent: &'a str,
    controls: Vec<&'a str>,
    coordinate_policy: &'a str,
}

#[derive(Serialize)]
struct CoverageEvidence {
    ui_event_count: u64,
    effect_count: u64,
    final_focus_owner: String,
    final_lifecycle: String,
    final_pump_term: String,
    text_box_text: String,
    framebuffer_hash: u64,
}

#[derive(Serialize)]
struct ArtifactRefs<'a> {
    frame_ppm: &'a str,
}

#[derive(Serialize)]
struct EvidenceRow {
    sequence: u64,
    phase: String,
    kind: String,
    payload: serde_json::Value,
}

#[derive(Serialize)]
struct LifecyclePumpEvidence<'a> {
    lifecycle_state: &'a str,
    pump_term: &'a str,
    modal_depth: u32,
    active_form: Option<&'a str>,
    active_window: Option<&'a str>,
}

#[derive(Serialize)]
struct RenderEvidence {
    width: u32,
    height: u32,
    command_count: usize,
    framebuffer_hash: u64,
    hash_algorithm: &'static str,
}

fn show_requested_event(event_id: UiEventId) -> UiEvent {
    targeted_event(
        event_id,
        UiEventKind::ShowRequested(ShowRequestedEvent {
            form_id: FormId::new(FORM_ID),
            show_mode: ShowMode::Modeless,
            owner: None,
            initial_bounds: Some(LogicalRect::new(
                0.0,
                0.0,
                f64::from(WIDTH),
                f64::from(HEIGHT),
            )),
            reason: LifecycleReason::ShowRequested,
        }),
    )
}

fn window_shown_event(event_id: UiEventId, window_rect: Option<PixelRect>) -> UiEvent {
    targeted_event(
        event_id,
        UiEventKind::WindowShown(WindowShownEvent {
            form_id: FormId::new(FORM_ID),
            window_id: WindowId::new(WINDOW_ID),
            show_mode: ShowMode::Modeless,
            window_rect,
            dpi: Some(DpiScale::new(
                DPI_FOR_ONE_PIXEL_PER_POINT,
                DPI_FOR_ONE_PIXEL_PER_POINT,
            )),
        }),
    )
}

fn activate_event(event_id: UiEventId) -> UiEvent {
    targeted_event(
        event_id,
        UiEventKind::Activate(ActivationEvent {
            reason: ActivationReason::WindowShown,
            previous: None,
            next: Some(target()),
        }),
    )
}

fn resize_event(event_id: UiEventId) -> UiEvent {
    targeted_event(
        event_id,
        UiEventKind::Resize(ResizeEvent {
            window_rect: None,
            client_size: Some(oxforms_pal::PixelSize::new(
                f64::from(WIDTH),
                f64::from(HEIGHT),
            )),
            form_logical_size: Some(oxforms_pal::LogicalSize::new(
                f64::from(WIDTH),
                f64::from(HEIGHT),
            )),
            dpi: Some(DpiScale::new(
                DPI_FOR_ONE_PIXEL_PER_POINT,
                DPI_FOR_ONE_PIXEL_PER_POINT,
            )),
        }),
    )
}

fn mouse_move_event(event_id: UiEventId, x: f32, y: f32, left_down: bool) -> UiEvent {
    targeted_event(
        event_id,
        UiEventKind::MouseMove(oxforms_pal::MouseMoveEvent {
            pointer_id: Some(oxforms_pal::PointerId(1)),
            buttons_down: MouseButtons {
                left: left_down,
                ..MouseButtons::default()
            },
            modifiers: KeyboardModifiers::default(),
            coordinates: coordinates(x, y),
        }),
    )
}

fn mouse_button_event(event_id: UiEventId, x: f32, y: f32, down: bool) -> UiEvent {
    let payload = MouseButtonEvent {
        pointer_id: Some(oxforms_pal::PointerId(1)),
        button: MouseButton::Left,
        buttons_down: MouseButtons {
            left: down,
            ..MouseButtons::default()
        },
        modifiers: KeyboardModifiers::default(),
        click_count: ClickCount(1),
        coordinates: coordinates(x, y),
    };
    targeted_event(
        event_id,
        if down {
            UiEventKind::MouseDown(payload)
        } else {
            UiEventKind::MouseUp(payload)
        },
    )
}

#[cfg(windows)]
fn key_event(event_id: UiEventId, key: minifb::Key, down: bool) -> UiEvent {
    let payload = KeyEvent {
        key: key_code(key),
        modifiers: KeyboardModifiers {
            shift: matches!(key, minifb::Key::LeftShift | minifb::Key::RightShift),
            control: matches!(key, minifb::Key::LeftCtrl | minifb::Key::RightCtrl),
            alt: matches!(key, minifb::Key::LeftAlt | minifb::Key::RightAlt),
            ..KeyboardModifiers::default()
        },
        repeat: KeyRepeat {
            is_repeat: false,
            repeat_count: Some(1),
        },
        raw: RawKeyDiagnostics {
            virtual_key: None,
            scan_code: None,
            native_code: None,
            is_extended: None,
        },
    };
    let mut event = targeted_event(
        event_id,
        if down {
            UiEventKind::KeyDown(payload)
        } else {
            UiEventKind::KeyUp(payload)
        },
    );
    event.diagnostics.push(RawDiagnostic {
        source: "minifb".to_string(),
        name: "key".to_string(),
        value: RawDiagnosticValue::Text(format!("{key:?}")),
    });
    event
}

fn character_event(event_id: UiEventId, character: char) -> UiEvent {
    targeted_event(
        event_id,
        UiEventKind::CharacterInput(CharacterInputEvent {
            text: character.to_string(),
            modifiers: KeyboardModifiers::default(),
            raw: vec![RawDiagnostic::text(
                "minifb",
                "character_callback",
                u32::from(character).to_string(),
            )],
        }),
    )
}

fn close_request_event(event_id: UiEventId) -> UiEvent {
    targeted_event(
        event_id,
        UiEventKind::CloseRequest(CloseRequestEvent {
            origin: CloseRequestOrigin::CloseButton,
            reason: CloseReason::User,
            query_policy: CloseQueryPolicy::Query,
            coordinates: None,
        }),
    )
}

fn targeted_event(event_id: UiEventId, kind: UiEventKind) -> UiEvent {
    UiEvent {
        target: target(),
        ..UiEvent::new(event_id, UiEventSource::Pal, kind)
    }
}

fn target() -> UiEventTarget {
    UiEventTarget {
        form_id: Some(FormId::new(FORM_ID)),
        window_id: Some(WindowId::new(WINDOW_ID)),
        control_id: None,
    }
}

fn coordinates(x: f32, y: f32) -> CoordinatePayload {
    let x = f64::from(x);
    let y = f64::from(y);
    CoordinatePayload {
        screen_pixels: None,
        window_rect: None,
        client_pixels: Some(PixelPoint::new(x, y)),
        form_logical: Some(LogicalPoint::new(x, y)),
        control_local: None,
        dpi: Some(DpiScale::new(
            DPI_FOR_ONE_PIXEL_PER_POINT,
            DPI_FOR_ONE_PIXEL_PER_POINT,
        )),
        raw_samples: vec![
            RawCoordinateSample {
                space: CoordinateSpace::ClientPixels,
                point: CoordinatePoint::new(x, y),
                source: "minifb.get_mouse_pos(MouseMode::Pass)".to_string(),
            },
            RawCoordinateSample {
                space: CoordinateSpace::FormLogical,
                point: CoordinatePoint::new(x, y),
                source: "w005_visible_input_smoke.1_to_1_projection".to_string(),
            },
        ],
    }
}

#[cfg(windows)]
fn key_code(key: minifb::Key) -> KeyCode {
    use minifb::Key;

    match key {
        Key::Enter => KeyCode::Enter,
        Key::Escape => KeyCode::Escape,
        Key::Tab => KeyCode::Tab,
        Key::Backspace => KeyCode::Backspace,
        Key::Delete => KeyCode::Delete,
        Key::Left => KeyCode::ArrowLeft,
        Key::Right => KeyCode::ArrowRight,
        Key::Up => KeyCode::ArrowUp,
        Key::Down => KeyCode::ArrowDown,
        Key::Home => KeyCode::Home,
        Key::End => KeyCode::End,
        Key::PageUp => KeyCode::PageUp,
        Key::PageDown => KeyCode::PageDown,
        Key::Space => KeyCode::Space,
        Key::A => KeyCode::Character("A".to_string()),
        Key::B => KeyCode::Character("B".to_string()),
        Key::C => KeyCode::Character("C".to_string()),
        Key::O => KeyCode::Character("O".to_string()),
        Key::F1 => KeyCode::Function(1),
        Key::F2 => KeyCode::Function(2),
        Key::F3 => KeyCode::Function(3),
        Key::F4 => KeyCode::Function(4),
        _ => KeyCode::Other(format!("{key:?}")),
    }
}

fn rgba8_to_minifb(pixels: &[u8]) -> Result<Vec<u32>, Box<dyn Error>> {
    let mut out = Vec::with_capacity(pixels.len() / 4);
    for pixel in pixels.chunks_exact(4) {
        out.push((u32::from(pixel[0]) << 16) | (u32::from(pixel[1]) << 8) | u32::from(pixel[2]));
    }
    Ok(out)
}

fn write_ppm(path: &Path, pixels: &[u32], width: u32, height: u32) -> Result<(), Box<dyn Error>> {
    let mut bytes = format!("P6\n{} {}\n255\n", width, height).into_bytes();
    for pixel in pixels {
        bytes.push(((pixel >> 16) & 0xff) as u8);
        bytes.push(((pixel >> 8) & 0xff) as u8);
        bytes.push((pixel & 0xff) as u8);
    }
    fs::write(path, bytes)?;
    Ok(())
}
