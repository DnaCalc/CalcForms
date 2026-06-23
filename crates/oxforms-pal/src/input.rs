//! Host-neutral W005 normalized input contract.
//!
//! These types describe the value-shaped PAL/replay input rows that downstream
//! reducers consume. They do not implement routing, pumping, platform capture,
//! control behavior, or runtime adapter marshalling.

use serde::{Deserialize, Serialize};

/// First schema version for W005 normalized input rows.
pub const UI_EVENT_SCHEMA_VERSION: u16 = 1;

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct UiEventId(pub u64);

#[derive(Clone, Debug, Eq, Hash, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct FormId(pub String);

impl FormId {
    #[must_use]
    pub fn new(id: impl Into<String>) -> Self {
        Self(id.into())
    }
}

#[derive(Clone, Debug, Eq, Hash, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ControlId(pub String);

impl ControlId {
    #[must_use]
    pub fn new(id: impl Into<String>) -> Self {
        Self(id.into())
    }
}

#[derive(Clone, Debug, Eq, Hash, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct WindowId(pub String);

impl WindowId {
    #[must_use]
    pub fn new(id: impl Into<String>) -> Self {
        Self(id.into())
    }
}

#[derive(Clone, Debug, Eq, Hash, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct HostScopeId(pub String);

impl HostScopeId {
    #[must_use]
    pub fn new(id: impl Into<String>) -> Self {
        Self(id.into())
    }
}

#[derive(Clone, Debug, Eq, Hash, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct TimerId(pub String);

impl TimerId {
    #[must_use]
    pub fn new(id: impl Into<String>) -> Self {
        Self(id.into())
    }
}

#[derive(Clone, Debug, Eq, Hash, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ServiceRequestId(pub String);

impl ServiceRequestId {
    #[must_use]
    pub fn new(id: impl Into<String>) -> Self {
        Self(id.into())
    }
}

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct PointerId(pub u64);

/// Optional target hints attached before reducer-owned routing.
#[derive(Clone, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
pub struct UiEventTarget {
    pub form_id: Option<FormId>,
    pub window_id: Option<WindowId>,
    pub control_id: Option<ControlId>,
}

impl UiEventTarget {
    #[must_use]
    pub fn form(form_id: impl Into<String>) -> Self {
        Self {
            form_id: Some(FormId::new(form_id)),
            window_id: None,
            control_id: None,
        }
    }

    #[must_use]
    pub fn window(window_id: impl Into<String>) -> Self {
        Self {
            form_id: None,
            window_id: Some(WindowId::new(window_id)),
            control_id: None,
        }
    }

    #[must_use]
    pub fn control(form_id: impl Into<String>, control_id: impl Into<String>) -> Self {
        Self {
            form_id: Some(FormId::new(form_id)),
            window_id: None,
            control_id: Some(ControlId::new(control_id)),
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UiEventSource {
    Pal,
    HostExtension,
    Service,
    Replay,
    Oracle,
}

/// Platform-independent input or service row consumed by the reducer path.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct UiEvent {
    pub schema_version: u16,
    pub event_id: UiEventId,
    pub parent_event_id: Option<UiEventId>,
    pub nesting_depth: u32,
    pub logical_tick: Option<u64>,
    pub source: UiEventSource,
    pub target: UiEventTarget,
    pub kind: UiEventKind,
    pub diagnostics: Vec<RawDiagnostic>,
}

impl UiEvent {
    #[must_use]
    pub fn new(event_id: UiEventId, source: UiEventSource, kind: UiEventKind) -> Self {
        Self {
            schema_version: UI_EVENT_SCHEMA_VERSION,
            event_id,
            parent_event_id: None,
            nesting_depth: 0,
            logical_tick: None,
            source,
            target: UiEventTarget::default(),
            kind,
            diagnostics: Vec::new(),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload", rename_all = "snake_case")]
pub enum UiEventKind {
    MouseMove(MouseMoveEvent),
    MouseDown(MouseButtonEvent),
    MouseUp(MouseButtonEvent),
    MouseDoubleClick(MouseButtonEvent),
    MouseWheel(MouseWheelEvent),
    KeyDown(KeyEvent),
    KeyUp(KeyEvent),
    CharacterInput(CharacterInputEvent),
    FocusIn(FocusEvent),
    FocusOut(FocusEvent),
    Activate(ActivationEvent),
    Deactivate(ActivationEvent),
    CloseRequest(CloseRequestEvent),
    TimerFired(TimerFiredEvent),
    ClipboardResult(ClipboardResultEvent),
    DragOver(DragOverEvent),
    DropOrPaste(DropOrPasteEvent),
    ServiceResult(ServiceResultEvent),
    DpiChanged(DpiChangedEvent),
    Resize(ResizeEvent),
    HostExtension(HostExtensionEvent),
    FormInstanceRequested(FormInstanceRequestedEvent),
    FormLoaded(FormLoadedEvent),
    FormLoadFailed(FormLoadFailedEvent),
    ShowRequested(ShowRequestedEvent),
    WindowShown(WindowShownEvent),
    HideRequested(HideRequestedEvent),
    WindowHidden(WindowHiddenEvent),
    QueryCloseCompleted(QueryCloseCompletedEvent),
    UnloadRequested(UnloadRequestedEvent),
    Unloaded(UnloadedEvent),
    Terminated(TerminatedEvent),
    PumpYieldRequested(PumpYieldRequestedEvent),
    PumpFrameExited(PumpFrameExitedEvent),
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct PixelPoint {
    pub x: f64,
    pub y: f64,
}

impl PixelPoint {
    #[must_use]
    pub const fn new(x: f64, y: f64) -> Self {
        Self { x, y }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct CoordinatePoint {
    pub x: f64,
    pub y: f64,
}

impl CoordinatePoint {
    #[must_use]
    pub const fn new(x: f64, y: f64) -> Self {
        Self { x, y }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct PixelSize {
    pub width: f64,
    pub height: f64,
}

impl PixelSize {
    #[must_use]
    pub const fn new(width: f64, height: f64) -> Self {
        Self { width, height }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct PixelRect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

impl PixelRect {
    #[must_use]
    pub const fn new(x: f64, y: f64, width: f64, height: f64) -> Self {
        Self {
            x,
            y,
            width,
            height,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct LogicalPoint {
    pub x: f64,
    pub y: f64,
}

impl LogicalPoint {
    #[must_use]
    pub const fn new(x: f64, y: f64) -> Self {
        Self { x, y }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct LogicalSize {
    pub width: f64,
    pub height: f64,
}

impl LogicalSize {
    #[must_use]
    pub const fn new(width: f64, height: f64) -> Self {
        Self { width, height }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct LogicalRect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

impl LogicalRect {
    #[must_use]
    pub const fn new(x: f64, y: f64, width: f64, height: f64) -> Self {
        Self {
            x,
            y,
            width,
            height,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CoordinateSpace {
    ScreenPixels,
    WindowRect,
    ScreenshotPixels,
    ClientPixels,
    FormLogical,
    ControlLocal,
    DisplayListLogical,
    MsformsEventArgs,
    RawDiagnostic,
}

/// Coordinates preserved with normalized input before and after routing.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct CoordinatePayload {
    pub screen_pixels: Option<PixelPoint>,
    pub window_rect: Option<PixelRect>,
    pub client_pixels: Option<PixelPoint>,
    pub form_logical: Option<LogicalPoint>,
    pub control_local: Option<LogicalPoint>,
    pub dpi: Option<DpiScale>,
    pub raw_samples: Vec<RawCoordinateSample>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RawCoordinateSample {
    pub space: CoordinateSpace,
    pub point: CoordinatePoint,
    pub source: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct DpiScale {
    pub dpi_x: f64,
    pub dpi_y: f64,
    pub scale_x: Option<f64>,
    pub scale_y: Option<f64>,
}

impl DpiScale {
    #[must_use]
    pub const fn new(dpi_x: f64, dpi_y: f64) -> Self {
        Self {
            dpi_x,
            dpi_y,
            scale_x: None,
            scale_y: None,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RawDiagnostic {
    pub source: String,
    pub name: String,
    pub value: RawDiagnosticValue,
}

impl RawDiagnostic {
    #[must_use]
    pub fn text(
        source: impl Into<String>,
        name: impl Into<String>,
        value: impl Into<String>,
    ) -> Self {
        Self {
            source: source.into(),
            name: name.into(),
            value: RawDiagnosticValue::Text(value.into()),
        }
    }

    #[must_use]
    pub fn unsigned(source: impl Into<String>, name: impl Into<String>, value: u64) -> Self {
        Self {
            source: source.into(),
            name: name.into(),
            value: RawDiagnosticValue::Unsigned(value),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "value", rename_all = "snake_case")]
pub enum RawDiagnosticValue {
    Bool(bool),
    Signed(i64),
    Unsigned(u64),
    Float(f64),
    Text(String),
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
pub struct KeyboardModifiers {
    pub shift: bool,
    pub control: bool,
    pub alt: bool,
    pub meta: bool,
    pub platform: bool,
    pub caps_lock: bool,
    pub num_lock: bool,
    pub scroll_lock: bool,
}

#[derive(Clone, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
pub struct MouseButtons {
    pub left: bool,
    pub right: bool,
    pub middle: bool,
    pub x1: bool,
    pub x2: bool,
    pub other: Vec<u16>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MouseButton {
    Left,
    Right,
    Middle,
    X1,
    X2,
    Other(u16),
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ClickCount(pub u8);

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct MouseMoveEvent {
    pub pointer_id: Option<PointerId>,
    pub buttons_down: MouseButtons,
    pub modifiers: KeyboardModifiers,
    pub coordinates: CoordinatePayload,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct MouseButtonEvent {
    pub pointer_id: Option<PointerId>,
    pub button: MouseButton,
    pub buttons_down: MouseButtons,
    pub modifiers: KeyboardModifiers,
    pub click_count: ClickCount,
    pub coordinates: CoordinatePayload,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WheelDeltaUnit {
    Lines,
    Pages,
    Pixels,
    PlatformUnits,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct MouseWheelEvent {
    pub pointer_id: Option<PointerId>,
    pub buttons_down: MouseButtons,
    pub modifiers: KeyboardModifiers,
    pub delta_x: f64,
    pub delta_y: f64,
    pub delta_unit: WheelDeltaUnit,
    pub coordinates: CoordinatePayload,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "value", rename_all = "snake_case")]
pub enum KeyCode {
    Enter,
    Escape,
    Tab,
    Backspace,
    Delete,
    ArrowLeft,
    ArrowRight,
    ArrowUp,
    ArrowDown,
    Home,
    End,
    PageUp,
    PageDown,
    Space,
    Function(u8),
    Character(String),
    Other(String),
    Unidentified,
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
pub struct KeyRepeat {
    pub is_repeat: bool,
    pub repeat_count: Option<u32>,
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
pub struct RawKeyDiagnostics {
    pub virtual_key: Option<u32>,
    pub scan_code: Option<u32>,
    pub native_code: Option<u64>,
    pub is_extended: Option<bool>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct KeyEvent {
    pub key: KeyCode,
    pub modifiers: KeyboardModifiers,
    pub repeat: KeyRepeat,
    pub raw: RawKeyDiagnostics,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CharacterInputEvent {
    pub text: String,
    pub modifiers: KeyboardModifiers,
    pub raw: Vec<RawDiagnostic>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FocusReason {
    Mouse,
    Keyboard,
    Programmatic,
    WindowActivation,
    Host,
    Replay,
    Unknown,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct FocusEvent {
    pub reason: FocusReason,
    pub related_target: Option<UiEventTarget>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ActivationReason {
    User,
    Programmatic,
    WindowShown,
    Host,
    Replay,
    Unknown,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct ActivationEvent {
    pub reason: ActivationReason,
    pub previous: Option<UiEventTarget>,
    pub next: Option<UiEventTarget>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CloseRequestOrigin {
    CloseButton,
    SystemMenu,
    HostRequest,
    CodeUnload,
    OwnerShutdown,
    Replay,
    Unknown,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CloseReason {
    User,
    Programmatic,
    HostShutdown,
    Error,
    Replay,
    Unknown,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CloseQueryPolicy {
    Query,
    SkipQuery,
    Unknown,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CloseRequestEvent {
    pub origin: CloseRequestOrigin,
    pub reason: CloseReason,
    pub query_policy: CloseQueryPolicy,
    pub coordinates: Option<CoordinatePayload>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DpiChangedEvent {
    pub old: Option<DpiScale>,
    pub new: DpiScale,
    pub suggested_window_rect: Option<PixelRect>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ResizeEvent {
    pub window_rect: Option<PixelRect>,
    pub client_size: Option<PixelSize>,
    pub form_logical_size: Option<LogicalSize>,
    pub dpi: Option<DpiScale>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct TimerFiredEvent {
    pub timer_id: TimerId,
    pub logical_tick: u64,
    pub drift_millis: Option<i64>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ClipboardOperation {
    Get,
    Set,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ClipboardResultEvent {
    pub request_id: ServiceRequestId,
    pub operation: ClipboardOperation,
    pub outcome: ServiceOutcome,
    pub formats: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub payload: Option<ServicePayload>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DataObjectSnapshot {
    pub snapshot_id: ServiceRequestId,
    pub formats: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub payload: Option<ServicePayload>,
    #[serde(default)]
    pub metadata: Vec<RawDiagnostic>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DragOverEvent {
    pub drag_session_id: String,
    pub coordinates: CoordinatePayload,
    pub modifiers: KeyboardModifiers,
    pub buttons_down: MouseButtons,
    pub drag_state: i32,
    pub effect: i32,
    pub data: DataObjectSnapshot,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DropOrPasteOrigin {
    DragDrop,
    ClipboardPaste,
    Code,
    Replay,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DropOrPasteEvent {
    pub transfer_session_id: String,
    pub origin: DropOrPasteOrigin,
    pub coordinates: CoordinatePayload,
    pub modifiers: KeyboardModifiers,
    pub action: i32,
    pub effect: i32,
    pub data: DataObjectSnapshot,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ServiceResultEvent {
    pub request_id: ServiceRequestId,
    pub service_kind: String,
    pub outcome: ServiceOutcome,
    pub payload: Option<ServicePayload>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum ServiceOutcome {
    Success,
    Error { kind: String, message: String },
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ServicePayload {
    pub content_type: Option<String>,
    pub text: Option<String>,
    pub bytes_sha256: Option<String>,
    pub metadata: Vec<RawDiagnostic>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct HostExtensionEvent {
    pub host_namespace: String,
    pub capability: String,
    pub event_kind: String,
    pub host_scope_id: Option<HostScopeId>,
    pub target: Option<UiEventTarget>,
    pub payload: Option<ServicePayload>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ShowMode {
    Modal,
    Modeless,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LifecycleReason {
    DefaultInstance,
    ShowRequested,
    Programmatic,
    User,
    Host,
    Replay,
    Error,
    Unknown,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct FormInstanceRequestedEvent {
    pub form_id: FormId,
    pub form_class_name: String,
    pub owner: Option<UiEventTarget>,
    pub show_mode: Option<ShowMode>,
    pub reason: LifecycleReason,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct FormLoadedEvent {
    pub form_id: FormId,
    pub load_source: String,
    pub control_count: Option<u32>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct FormLoadFailedEvent {
    pub form_id: FormId,
    pub error_kind: String,
    pub message: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ShowRequestedEvent {
    pub form_id: FormId,
    pub show_mode: ShowMode,
    pub owner: Option<UiEventTarget>,
    pub initial_bounds: Option<LogicalRect>,
    pub reason: LifecycleReason,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct WindowShownEvent {
    pub form_id: FormId,
    pub window_id: WindowId,
    pub show_mode: ShowMode,
    pub window_rect: Option<PixelRect>,
    pub dpi: Option<DpiScale>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct HideRequestedEvent {
    pub form_id: FormId,
    pub reason: LifecycleReason,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct WindowHiddenEvent {
    pub form_id: FormId,
    pub window_id: WindowId,
    pub reason: LifecycleReason,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct QueryCloseCompletedEvent {
    pub form_id: FormId,
    pub reason: CloseReason,
    pub cancelled: bool,
    pub close_mode: Option<i32>,
    pub dispatch_diagnostics: Vec<RawDiagnostic>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct UnloadRequestedEvent {
    pub form_id: FormId,
    pub reason: LifecycleReason,
    pub query_policy: CloseQueryPolicy,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct UnloadedEvent {
    pub form_id: FormId,
    pub reason: LifecycleReason,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct TerminatedEvent {
    pub form_id: FormId,
    pub reason: LifecycleReason,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct PumpYieldRequestedEvent {
    pub source_effect_id: Option<u64>,
    pub reason: String,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct PumpFrameExitedEvent {
    pub modal_depth: u32,
    pub exit_reason: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mouse_wheel_event_preserves_named_coordinates_and_raw_diagnostics() {
        let buttons = MouseButtons {
            left: true,
            ..MouseButtons::default()
        };

        let mut coordinates = CoordinatePayload {
            screen_pixels: Some(PixelPoint::new(810.0, 450.0)),
            window_rect: Some(PixelRect::new(800.0, 420.0, 320.0, 240.0)),
            client_pixels: Some(PixelPoint::new(10.0, 30.0)),
            form_logical: Some(LogicalPoint::new(1.5, 22.5)),
            control_local: None,
            dpi: Some(DpiScale::new(96.0, 96.0)),
            raw_samples: Vec::new(),
        };
        coordinates.raw_samples.push(RawCoordinateSample {
            space: CoordinateSpace::ScreenPixels,
            point: CoordinatePoint::new(810.0, 450.0),
            source: "platform.pointer".to_string(),
        });

        let mouse_down = UiEvent {
            target: UiEventTarget::window("window-1"),
            ..UiEvent::new(
                UiEventId(6),
                UiEventSource::Pal,
                UiEventKind::MouseDown(MouseButtonEvent {
                    pointer_id: Some(PointerId(1)),
                    button: MouseButton::Left,
                    buttons_down: buttons.clone(),
                    modifiers: KeyboardModifiers {
                        shift: true,
                        ..KeyboardModifiers::default()
                    },
                    click_count: ClickCount(2),
                    coordinates: coordinates.clone(),
                }),
            )
        };
        let mouse_wheel = UiEvent {
            target: UiEventTarget::window("window-1"),
            diagnostics: vec![RawDiagnostic::unsigned(
                "platform",
                "native_wheel_code",
                0x0078_0001,
            )],
            ..UiEvent::new(
                UiEventId(7),
                UiEventSource::Pal,
                UiEventKind::MouseWheel(MouseWheelEvent {
                    pointer_id: Some(PointerId(1)),
                    buttons_down: buttons,
                    modifiers: KeyboardModifiers {
                        shift: true,
                        ..KeyboardModifiers::default()
                    },
                    delta_x: 0.0,
                    delta_y: -120.0,
                    delta_unit: WheelDeltaUnit::PlatformUnits,
                    coordinates,
                }),
            )
        };

        let events = vec![mouse_down, mouse_wheel];
        let encoded = serde_json::to_string(&events).expect("events should serialize");
        let decoded: Vec<UiEvent> =
            serde_json::from_str(&encoded).expect("events should deserialize");

        assert_eq!(decoded, events);
        assert!(encoded.contains("mouse_down"));
        assert!(encoded.contains("click_count"));
        assert!(encoded.contains("screen_pixels"));
        assert!(encoded.contains("form_logical"));
    }

    #[test]
    fn keyboard_and_character_input_round_trip_without_text_semantics() {
        let key_event = UiEvent::new(
            UiEventId(8),
            UiEventSource::Pal,
            UiEventKind::KeyDown(KeyEvent {
                key: KeyCode::Character("A".to_string()),
                modifiers: KeyboardModifiers {
                    control: true,
                    ..KeyboardModifiers::default()
                },
                repeat: KeyRepeat {
                    is_repeat: false,
                    repeat_count: Some(1),
                },
                raw: RawKeyDiagnostics {
                    virtual_key: Some(0x41),
                    scan_code: Some(0x1e),
                    native_code: None,
                    is_extended: Some(false),
                },
            }),
        );
        let char_event = UiEvent::new(
            UiEventId(9),
            UiEventSource::Pal,
            UiEventKind::CharacterInput(CharacterInputEvent {
                text: "A".to_string(),
                modifiers: KeyboardModifiers::default(),
                raw: vec![RawDiagnostic::text("platform", "text_service", "committed")],
            }),
        );

        let encoded = serde_json::to_string(&vec![key_event.clone(), char_event.clone()])
            .expect("events should serialize");
        let decoded: Vec<UiEvent> =
            serde_json::from_str(&encoded).expect("events should deserialize");

        assert_eq!(decoded, vec![key_event, char_event]);
    }

    #[test]
    fn focus_resize_dpi_and_service_shapes_round_trip() {
        let events = vec![
            UiEvent::new(
                UiEventId(10),
                UiEventSource::Pal,
                UiEventKind::FocusIn(FocusEvent {
                    reason: FocusReason::WindowActivation,
                    related_target: Some(UiEventTarget::control("form-1", "textbox-1")),
                }),
            ),
            UiEvent::new(
                UiEventId(11),
                UiEventSource::Pal,
                UiEventKind::DpiChanged(DpiChangedEvent {
                    old: Some(DpiScale::new(96.0, 96.0)),
                    new: DpiScale {
                        dpi_x: 144.0,
                        dpi_y: 144.0,
                        scale_x: Some(1.5),
                        scale_y: Some(1.5),
                    },
                    suggested_window_rect: Some(PixelRect::new(10.0, 20.0, 480.0, 360.0)),
                }),
            ),
            UiEvent::new(
                UiEventId(12),
                UiEventSource::Pal,
                UiEventKind::Resize(ResizeEvent {
                    window_rect: Some(PixelRect::new(10.0, 20.0, 480.0, 360.0)),
                    client_size: Some(PixelSize::new(460.0, 320.0)),
                    form_logical_size: Some(LogicalSize::new(240.0, 180.0)),
                    dpi: Some(DpiScale::new(144.0, 144.0)),
                }),
            ),
            UiEvent::new(
                UiEventId(13),
                UiEventSource::Service,
                UiEventKind::ServiceResult(ServiceResultEvent {
                    request_id: ServiceRequestId::new("cursor-1"),
                    service_kind: "set_cursor".to_string(),
                    outcome: ServiceOutcome::Success,
                    payload: Some(ServicePayload {
                        content_type: Some("application/x-oxforms-diagnostic".to_string()),
                        text: Some("ibeam".to_string()),
                        bytes_sha256: None,
                        metadata: vec![RawDiagnostic::text("pal", "cursor", "ibeam")],
                    }),
                }),
            ),
        ];

        let encoded = serde_json::to_string(&events).expect("events should serialize");
        let decoded: Vec<UiEvent> =
            serde_json::from_str(&encoded).expect("events should deserialize");

        assert_eq!(decoded, events);
    }

    #[test]
    fn drag_drop_shapes_round_trip_with_serializable_data_snapshot() {
        let mut coordinates = CoordinatePayload {
            control_local: Some(LogicalPoint::new(63.0, 15.0)),
            dpi: Some(DpiScale::new(96.0, 96.0)),
            ..CoordinatePayload::default()
        };
        coordinates.raw_samples.push(RawCoordinateSample {
            space: CoordinateSpace::MsformsEventArgs,
            point: CoordinatePoint::new(63.0, 15.0),
            source: "repo_owned_oracle".to_string(),
        });
        let data = DataObjectSnapshot {
            snapshot_id: ServiceRequestId::new("drag-snapshot-1"),
            formats: vec!["cf_text".to_string()],
            payload: Some(ServicePayload {
                content_type: Some("text/plain".to_string()),
                text: Some("repo_owned_drag_text_seed_v1".to_string()),
                bytes_sha256: None,
                metadata: vec![RawDiagnostic::text(
                    "oracle",
                    "data_object_get_format_1",
                    "true",
                )],
            }),
            metadata: vec![RawDiagnostic::text(
                "policy",
                "live_object_identity",
                "not_recorded",
            )],
        };

        let events = vec![
            UiEvent::new(
                UiEventId(17),
                UiEventSource::Pal,
                UiEventKind::DragOver(DragOverEvent {
                    drag_session_id: "drag-session-1".to_string(),
                    coordinates: coordinates.clone(),
                    modifiers: KeyboardModifiers::default(),
                    buttons_down: MouseButtons {
                        left: true,
                        ..MouseButtons::default()
                    },
                    drag_state: 2,
                    effect: 1,
                    data: data.clone(),
                }),
            ),
            UiEvent::new(
                UiEventId(18),
                UiEventSource::Pal,
                UiEventKind::DropOrPaste(DropOrPasteEvent {
                    transfer_session_id: "drag-session-1".to_string(),
                    origin: DropOrPasteOrigin::DragDrop,
                    coordinates,
                    modifiers: KeyboardModifiers::default(),
                    action: 3,
                    effect: 1,
                    data,
                }),
            ),
        ];

        let encoded = serde_json::to_string_pretty(&events).expect("events should serialize");
        let decoded: Vec<UiEvent> =
            serde_json::from_str(&encoded).expect("events should deserialize");

        assert_eq!(decoded, events);
        assert!(encoded.contains("drag_over"));
        assert!(encoded.contains("drop_or_paste"));
        assert!(encoded.contains("live_object_identity"));
    }

    #[test]
    fn lifecycle_activation_and_close_shapes_follow_named_model() {
        let events = vec![
            UiEvent::new(
                UiEventId(14),
                UiEventSource::Pal,
                UiEventKind::Activate(ActivationEvent {
                    reason: ActivationReason::WindowShown,
                    previous: None,
                    next: Some(UiEventTarget::form("form-1")),
                }),
            ),
            UiEvent::new(
                UiEventId(15),
                UiEventSource::Pal,
                UiEventKind::CloseRequest(CloseRequestEvent {
                    origin: CloseRequestOrigin::CloseButton,
                    reason: CloseReason::User,
                    query_policy: CloseQueryPolicy::Query,
                    coordinates: None,
                }),
            ),
            UiEvent::new(
                UiEventId(16),
                UiEventSource::Service,
                UiEventKind::QueryCloseCompleted(QueryCloseCompletedEvent {
                    form_id: FormId::new("form-1"),
                    reason: CloseReason::User,
                    cancelled: true,
                    close_mode: Some(0),
                    dispatch_diagnostics: vec![RawDiagnostic::text(
                        "dispatch",
                        "cancel_after",
                        "true",
                    )],
                }),
            ),
        ];

        let encoded = serde_json::to_string_pretty(&events).expect("events should serialize");
        let decoded: Vec<UiEvent> =
            serde_json::from_str(&encoded).expect("events should deserialize");

        assert_eq!(decoded, events);
        assert!(encoded.contains("query_close_completed"));
    }
}
