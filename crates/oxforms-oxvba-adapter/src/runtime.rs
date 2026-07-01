//! `OxRuntime`: the thin runtime glue for the VBA-reducer design.
//!
//! This replaces the old `oxforms-core`-backed `RuntimeRunner` (which embedded a Rust reducer +
//! an effect/fold-back interpreter). In the pivoted design the VBA `OxReducer` owns ALL control
//! behavior, so the Rust runtime is a thin shell: it holds the OxVba session + the form-document
//! object, translates normalized input into calls on the form-document's reducer facade
//! (`Dispatch`/`DispatchKey`/`DispatchChar`/`DispatchDrop`), routes form-level lifecycle/close
//! events to the form-document's `Perform*` members, pushes the host clipboard text, and drives the
//! VBA self-render (`Render`). There is no Rust reducer in the loop.
//!
//! The form-document is any VBA class that exposes that facade (the `reducer_*` fixtures and the
//! W007 greeter do). Each input call returns the reducer's ordered effect log (a `'|'`-joined
//! string) for diagnostics/assertions.
//!
//! The named W009 contract is [`OxRuntime::dispatch_event_turn`]: host/backend code normalizes one
//! input turn into [`RuntimeInput`], `OxRuntime` dispatches it to the VBA facade, records any
//! explicit host-service effect, and returns [`RuntimeEventTurn`] so callers can render/read back
//! state in the same turn.

use crate::host_services::{HostCursor, HostServices, HostTimerRequest, HostTimerSlot};
use oxvba_bundle::ProjectMemberKind;
use oxvba_host::ProjectRuntimeSession;
use oxvba_runtime::{ObjectRef, Variant};

const SHIFT_CTRL: i16 = 2;
const VK_V: i16 = 86;

/// Mouse event kind in the canonical W009 runtime/event-turn contract.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RuntimeMouseKind {
    Down,
    Move,
    Up,
}

impl RuntimeMouseKind {
    fn facade_name(self) -> &'static str {
        match self {
            Self::Down => "mousedown",
            Self::Move => "mousemove",
            Self::Up => "mouseup",
        }
    }

    fn label_name(self) -> &'static str {
        match self {
            Self::Down => "mouse_down",
            Self::Move => "mouse_move",
            Self::Up => "mouse_up",
        }
    }
}

/// Key event kind in the canonical W009 runtime/event-turn contract.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RuntimeKeyKind {
    Down,
    Up,
}

impl RuntimeKeyKind {
    fn facade_name(self) -> &'static str {
        match self {
            Self::Down => "keydown",
            Self::Up => "keyup",
        }
    }

    fn label_name(self) -> &'static str {
        match self {
            Self::Down => "key_down",
            Self::Up => "key_up",
        }
    }
}

/// One normalized host input turn entering `OxRuntime`.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum RuntimeInput {
    Mouse {
        kind: RuntimeMouseKind,
        x: i32,
        y: i32,
        button: i16,
        shift: i16,
    },
    Key {
        kind: RuntimeKeyKind,
        key_code: i16,
        shift: i16,
    },
    CharacterInput(String),
    PasteText(String),
    PasteFromClipboard,
    DropText(String),
    ServiceProbe,
    SetCursor(HostCursor),
    ArmTimer(HostTimerRequest),
    CancelTimer(HostTimerSlot),
    AdvanceTime {
        advance_ms: u64,
    },
    DpiChanged {
        dpi_x: u32,
        dpi_y: u32,
    },
    DecodeImage {
        image_id: String,
        bytes_sha256: String,
    },
}

impl RuntimeInput {
    /// Stable action label used by headless JSONL traces and diagnostics.
    #[must_use]
    pub fn label(&self) -> String {
        match self {
            Self::Mouse { kind, x, y, .. } => format!("{}:{x},{y}", kind.label_name()),
            Self::Key {
                kind,
                key_code,
                shift,
            } => format!("{}:{key_code}:{shift}", kind.label_name()),
            Self::CharacterInput(text) => format!("char:{}", escape_label(text)),
            Self::PasteText(text) => format!("paste:{}", escape_label(text)),
            Self::PasteFromClipboard => "paste:clipboard".to_string(),
            Self::DropText(text) => format!("drop:{}", escape_label(text)),
            Self::ServiceProbe => "host_services:probe".to_string(),
            Self::SetCursor(cursor) => format!("cursor:{}", cursor.label()),
            Self::ArmTimer(request) => {
                format!("timer_arm:{}:{}", request.slot.label(), request.interval_ms)
            }
            Self::CancelTimer(slot) => format!("timer_cancel:{}", slot.label()),
            Self::AdvanceTime { advance_ms } => format!("tick:{advance_ms}"),
            Self::DpiChanged { dpi_x, dpi_y } => format!("dpi:{dpi_x}x{dpi_y}"),
            Self::DecodeImage { image_id, .. } => {
                format!("decode_image:{}", escape_label(image_id))
            }
        }
    }
}

/// Result of one canonical W009 runtime/event turn.
#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct RuntimeEventTurn {
    pub action: String,
    pub effect_log: String,
    pub host_service_effects: Vec<String>,
    pub repainted: bool,
}

/// A thin driver over a VBA form-document that owns an `OxReducer`.
pub struct OxRuntime {
    session: ProjectRuntimeSession,
    form: ObjectRef,
    host_services: HostServices,
}

impl OxRuntime {
    /// Create the form-document `form_class` and invoke its `build_member` (e.g. `"Build"`), which
    /// constructs the form + controls + the `OxReducer` and establishes the first frame.
    pub fn attach(
        session: ProjectRuntimeSession,
        form_class: &str,
        build_member: &str,
    ) -> Result<Self, String> {
        Self::attach_with_host_services(session, form_class, build_member, HostServices::headless())
    }

    pub fn attach_with_host_services(
        mut session: ProjectRuntimeSession,
        form_class: &str,
        build_member: &str,
        host_services: HostServices,
    ) -> Result<Self, String> {
        let form = session
            .create_class_instance(form_class)
            .map_err(|err| format!("create {form_class}: {err}"))?;
        session
            .invoke_member_values(
                form.clone(),
                build_member,
                Some(ProjectMemberKind::Method),
                Vec::new(),
            )
            .map_err(|err| format!("invoke {build_member}: {}", err.message()))?;
        Ok(Self {
            session,
            form,
            host_services,
        })
    }

    fn invoke(
        &mut self,
        member: &str,
        kind: ProjectMemberKind,
        args: Vec<Variant>,
    ) -> Result<Variant, String> {
        self.session
            .invoke_member_values(self.form.clone(), member, Some(kind), args)
            .map_err(|err| format!("invoke {member}: {}", err.message()))
    }

    fn invoke_string(
        &mut self,
        member: &str,
        kind: ProjectMemberKind,
        args: Vec<Variant>,
    ) -> Result<String, String> {
        Ok(self
            .invoke(member, kind, args)?
            .as_bstr()
            .map(|s| s.as_str())
            .unwrap_or_default())
    }

    /// Run one canonical W009 input turn through the VBA form-document facade.
    ///
    /// This is the shared dispatch surface for both deterministic headless tests and the Windows
    /// bootstrap. It does not rasterize pixels: callers render/repaint from the returned effect log
    /// and can read back VBA state immediately after the call.
    pub fn dispatch_event_turn(&mut self, input: RuntimeInput) -> Result<RuntimeEventTurn, String> {
        let action = input.label();
        let mut host_service_effects = Vec::new();
        let effect_log = match input {
            RuntimeInput::Mouse {
                kind,
                x,
                y,
                button,
                shift,
            } => self.dispatch_mouse(kind.facade_name(), x, y, button, shift)?,
            RuntimeInput::Key {
                kind,
                key_code,
                shift,
            } => self.dispatch_key(kind.facade_name(), key_code, shift)?,
            RuntimeInput::CharacterInput(text) => self.dispatch_char(&text)?,
            RuntimeInput::PasteText(text) => {
                host_service_effects.extend(self.host_services.set_clipboard_text(&text));
                self.push_clipboard_text_to_vba(&text)?;
                self.dispatch_key("keydown", VK_V, SHIFT_CTRL)?
            }
            RuntimeInput::PasteFromClipboard => {
                let (text, effects) = self.host_services.read_clipboard_text();
                host_service_effects.extend(effects);
                self.push_clipboard_text_to_vba(&text)?;
                self.dispatch_key("keydown", VK_V, SHIFT_CTRL)?
            }
            RuntimeInput::DropText(text) => {
                host_service_effects.extend(self.host_services.trace_drop_text(&text));
                self.dispatch_drop(&text)?
            }
            RuntimeInput::ServiceProbe => {
                host_service_effects.extend(self.host_services.service_probe_trace());
                String::new()
            }
            RuntimeInput::SetCursor(cursor) => {
                host_service_effects.extend(self.host_services.set_cursor(cursor));
                String::new()
            }
            RuntimeInput::ArmTimer(request) => {
                host_service_effects.extend(self.host_services.arm_timer(request));
                String::new()
            }
            RuntimeInput::CancelTimer(slot) => {
                host_service_effects.extend(self.host_services.cancel_timer(slot));
                String::new()
            }
            RuntimeInput::AdvanceTime { advance_ms } => {
                host_service_effects.extend(self.host_services.advance_time(advance_ms));
                String::new()
            }
            RuntimeInput::DpiChanged { dpi_x, dpi_y } => {
                host_service_effects.extend(self.host_services.set_dpi(dpi_x, dpi_y));
                String::new()
            }
            RuntimeInput::DecodeImage {
                image_id,
                bytes_sha256,
            } => {
                host_service_effects
                    .extend(self.host_services.decode_image(&image_id, &bytes_sha256));
                String::new()
            }
        };
        let repainted = effect_log_contains_repaint(&effect_log);
        Ok(RuntimeEventTurn {
            action,
            effect_log,
            host_service_effects,
            repainted,
        })
    }

    /// Route a normalized pointer event to the VBA reducer (`"mousedown"`/`"mouseup"`); returns the
    /// ordered effect log.
    fn dispatch_mouse(
        &mut self,
        kind: &str,
        x: i32,
        y: i32,
        button: i16,
        shift: i16,
    ) -> Result<String, String> {
        self.invoke_string(
            "Dispatch",
            ProjectMemberKind::Method,
            vec![
                Variant::from_string(kind),
                Variant::from_i32(x),
                Variant::from_i32(y),
                Variant::from_i16(button),
                Variant::from_i16(shift),
            ],
        )
    }

    /// Route a key event (`"keydown"`/`"keyup"`) to the focused control via the VBA reducer.
    fn dispatch_key(&mut self, kind: &str, key_code: i16, shift: i16) -> Result<String, String> {
        self.invoke_string(
            "DispatchKey",
            ProjectMemberKind::Method,
            vec![
                Variant::from_string(kind),
                Variant::from_i16(key_code),
                Variant::from_i16(shift),
            ],
        )
    }

    /// Route character input to the focused control via the VBA reducer.
    fn dispatch_char(&mut self, text: &str) -> Result<String, String> {
        self.invoke_string(
            "DispatchChar",
            ProjectMemberKind::Method,
            vec![Variant::from_string(text)],
        )
    }

    /// Route a drag-drop text drop to the focused control via the VBA reducer.
    fn dispatch_drop(&mut self, text: &str) -> Result<String, String> {
        self.invoke_string(
            "DispatchDrop",
            ProjectMemberKind::Method,
            vec![Variant::from_string(text)],
        )
    }

    /// Push the current host clipboard text (read before a Ctrl+V is dispatched).
    fn push_clipboard_text_to_vba(&mut self, text: &str) -> Result<(), String> {
        self.invoke(
            "SetClipboardText",
            ProjectMemberKind::Method,
            vec![Variant::from_string(text)],
        )?;
        Ok(())
    }

    /// Invoke a form-level `Perform*` member (lifecycle: `PerformInitialize`/`PerformActivate`/
    /// `PerformDeactivate`/`PerformTerminate`) on the form-document.
    pub fn perform(&mut self, member: &str) -> Result<(), String> {
        self.invoke(member, ProjectMemberKind::Method, Vec::new())?;
        Ok(())
    }

    /// Invoke `PerformQueryClose(close_mode)` and return the handler's Cancel readback (nonzero =
    /// the close was vetoed).
    pub fn perform_query_close(&mut self, close_mode: i16) -> Result<i16, String> {
        Ok(self
            .invoke(
                "PerformQueryClose",
                ProjectMemberKind::Method,
                vec![Variant::from_i16(close_mode)],
            )?
            .as_i16()
            .unwrap_or(0))
    }

    /// Drive the form's VBA self-render across `OxForms.Surface`.
    pub fn render(&mut self) -> Result<(), String> {
        self.invoke("Render", ProjectMemberKind::Method, Vec::new())?;
        Ok(())
    }

    /// The form-document object (for reading back control state in tests).
    #[must_use]
    pub fn form(&self) -> ObjectRef {
        self.form.clone()
    }

    /// Mutable access to the underlying session (for reading back form-document properties).
    pub fn session_mut(&mut self) -> &mut ProjectRuntimeSession {
        &mut self.session
    }

    #[must_use]
    pub fn host_services(&self) -> &HostServices {
        &self.host_services
    }

    pub fn host_services_mut(&mut self) -> &mut HostServices {
        &mut self.host_services
    }
}

/// True when the VBA reducer's ordered effect log says the turn already performed a re-render.
#[must_use]
pub fn effect_log_contains_repaint(effects: &str) -> bool {
    effects.split('|').any(|effect| effect == "repaint")
}

fn escape_label(text: &str) -> String {
    text.chars()
        .flat_map(char::escape_default)
        .collect::<String>()
}
