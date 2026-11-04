//! Representative W009 HostServices spine.
//!
//! HostServices is the host-facing side of `OxRuntime`: it owns deterministic traces for services
//! that are not VBA control semantics (clipboard, cursor, timers, system metrics/colors, DPI,
//! image handles, and drag/drop data snapshots). The implementation is intentionally small for
//! `oxforms-zhz.15`; later beads can replace individual stubs without changing the runtime turn
//! contract.

use std::collections::BTreeMap;

/// Which host implementation is providing services for this runtime.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum HostServiceBackend {
    Headless,
    Windows,
}

impl HostServiceBackend {
    #[must_use]
    pub const fn label(self) -> &'static str {
        match self {
            Self::Headless => "headless",
            Self::Windows => "windows",
        }
    }
}

/// Representative cursor shapes the interaction manager can request.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum HostCursor {
    Default,
    IBeam,
    Hand,
    Crosshair,
    Wait,
}

impl HostCursor {
    #[must_use]
    pub const fn label(self) -> &'static str {
        match self {
            Self::Default => "default",
            Self::IBeam => "ibeam",
            Self::Hand => "hand",
            Self::Crosshair => "crosshair",
            Self::Wait => "wait",
        }
    }
}

/// Named timer slots used by representative controls.
#[derive(Clone, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub enum HostTimerSlot {
    CaretBlink,
    AutoRepeat,
    Named(String),
}

impl HostTimerSlot {
    #[must_use]
    pub fn label(&self) -> String {
        match self {
            Self::CaretBlink => "caret_blink".to_string(),
            Self::AutoRepeat => "auto_repeat".to_string(),
            Self::Named(name) => format!("named:{name}"),
        }
    }
}

/// Timer registration request.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct HostTimerRequest {
    pub slot: HostTimerSlot,
    pub interval_ms: u64,
    pub repeating: bool,
}

impl HostTimerRequest {
    #[must_use]
    pub fn new(slot: HostTimerSlot, interval_ms: u64, repeating: bool) -> Self {
        Self {
            slot,
            interval_ms,
            repeating,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct HostTimerState {
    request: HostTimerRequest,
    next_due_ms: u64,
}

/// Host-side services owned by one `OxRuntime` session.
pub struct HostServices {
    backend: HostServiceBackend,
    clipboard_text: String,
    clipboard_reader: Option<Box<dyn FnMut() -> Option<String>>>,
    clock_ms: u64,
    timers: BTreeMap<String, HostTimerState>,
    cursor: HostCursor,
    dpi_x: u32,
    dpi_y: u32,
    image_sequence: u64,
}

impl HostServices {
    #[must_use]
    pub fn headless() -> Self {
        Self::new(HostServiceBackend::Headless, None)
    }

    pub fn windows(clipboard_reader: impl FnMut() -> Option<String> + 'static) -> Self {
        Self::new(
            HostServiceBackend::Windows,
            Some(Box::new(clipboard_reader)),
        )
    }

    fn new(
        backend: HostServiceBackend,
        clipboard_reader: Option<Box<dyn FnMut() -> Option<String>>>,
    ) -> Self {
        Self {
            backend,
            clipboard_text: String::new(),
            clipboard_reader,
            clock_ms: 0,
            timers: BTreeMap::new(),
            cursor: HostCursor::Default,
            dpi_x: 96,
            dpi_y: 96,
            image_sequence: 0,
        }
    }

    #[must_use]
    pub const fn backend(&self) -> HostServiceBackend {
        self.backend
    }

    #[must_use]
    pub const fn clock_ms(&self) -> u64 {
        self.clock_ms
    }

    pub fn set_clipboard_text(&mut self, text: &str) -> Vec<String> {
        self.clipboard_text = text.to_string();
        vec![format!("clipboard.set_text:{}", text.len())]
    }

    pub fn read_clipboard_text(&mut self) -> (String, Vec<String>) {
        let text = if let Some(reader) = &mut self.clipboard_reader {
            reader().unwrap_or_default()
        } else {
            self.clipboard_text.clone()
        };
        self.clipboard_text = text.clone();
        let len = text.len();
        (
            text,
            vec![
                format!("clipboard.read:{len}:{}", self.backend.label()),
                format!("clipboard.set_text:{len}"),
            ],
        )
    }

    pub fn set_cursor(&mut self, cursor: HostCursor) -> Vec<String> {
        self.cursor = cursor;
        vec![format!("cursor.set:{}", cursor.label())]
    }

    pub fn set_dpi(&mut self, dpi_x: u32, dpi_y: u32) -> Vec<String> {
        self.dpi_x = dpi_x;
        self.dpi_y = dpi_y;
        vec![format!("dpi.set:{dpi_x}x{dpi_y}")]
    }

    pub fn arm_timer(&mut self, request: HostTimerRequest) -> Vec<String> {
        let slot = request.slot.label();
        let interval = request.interval_ms.max(1);
        let repeating = request.repeating;
        let state = HostTimerState {
            request: HostTimerRequest {
                interval_ms: interval,
                ..request
            },
            next_due_ms: self.clock_ms.saturating_add(interval),
        };
        self.timers.insert(slot.clone(), state);
        vec![format!(
            "timer.arm:{slot}:{interval}:repeat={}",
            bool_label(repeating)
        )]
    }

    pub fn cancel_timer(&mut self, slot: HostTimerSlot) -> Vec<String> {
        let label = slot.label();
        self.timers.remove(&label);
        vec![format!("timer.cancel:{label}")]
    }

    pub fn advance_time(&mut self, advance_ms: u64) -> Vec<String> {
        self.clock_ms = self.clock_ms.saturating_add(advance_ms);
        let mut effects = vec![format!("time.advance:{advance_ms}:now={}", self.clock_ms)];
        let keys: Vec<String> = self.timers.keys().cloned().collect();
        for key in keys {
            let Some(timer) = self.timers.get_mut(&key) else {
                continue;
            };
            if self.clock_ms < timer.next_due_ms {
                continue;
            }

            let interval = timer.request.interval_ms;
            let elapsed = self.clock_ms.saturating_sub(timer.next_due_ms);
            let additional_fires = if timer.request.repeating {
                elapsed / interval
            } else {
                0
            };
            let fires = additional_fires.saturating_add(1);
            let last_due = timer
                .next_due_ms
                .saturating_add(additional_fires.saturating_mul(interval));
            let next_due = last_due.checked_add(interval);
            if timer.request.repeating {
                if let Some(next_due) = next_due {
                    timer.next_due_ms = next_due;
                }
            }
            effects.push(format!("timer.fire:{key}:{fires}:at={last_due}"));
            if !timer.request.repeating || next_due.is_none() {
                self.timers.remove(&key);
            }
        }
        effects
    }

    pub fn decode_image(&mut self, image_id: &str, bytes_sha256: &str) -> Vec<String> {
        self.image_sequence += 1;
        vec![format!(
            "image.decode:{image_id}:sha256={bytes_sha256}:handle={}#{:04}",
            self.backend.label(),
            self.image_sequence
        )]
    }

    pub fn trace_drop_text(&mut self, text: &str) -> Vec<String> {
        vec![
            format!("data_object.snapshot:text:{}", text.len()),
            format!("drag_drop.drop_text:{}", text.len()),
        ]
    }

    #[must_use]
    pub fn service_probe_trace(&self) -> Vec<String> {
        vec![
            format!("host_services.backend:{}", self.backend.label()),
            "clipboard.formats:text".to_string(),
            "data_object.skeleton:text".to_string(),
            format!("cursor.current:{}", self.cursor.label()),
            "timer.slot:caret_blink".to_string(),
            "timer.slot:auto_repeat".to_string(),
            "metrics.system:caret_blink_ms=500;double_click_ms=500;wheel_delta=120".to_string(),
            "colors.system:window=FFFFFF;text=000000;highlight=3399FF".to_string(),
            format!("dpi.current:{}x{}", self.dpi_x, self.dpi_y),
            "image.decode:stub:handle_shape=opaque".to_string(),
            "drag_drop.trace:drop_or_paste".to_string(),
        ]
    }
}

fn bool_label(value: bool) -> &'static str {
    if value {
        "true"
    } else {
        "false"
    }
}

#[cfg(test)]
mod tests {
    use super::{HostCursor, HostServices, HostTimerRequest, HostTimerSlot};

    #[test]
    fn headless_service_probe_names_every_representative_service() {
        let services = HostServices::headless();
        let trace = services.service_probe_trace().join("|");
        for expected in [
            "host_services.backend:headless",
            "clipboard.formats:text",
            "data_object.skeleton:text",
            "cursor.current:default",
            "timer.slot:caret_blink",
            "timer.slot:auto_repeat",
            "metrics.system:",
            "colors.system:",
            "dpi.current:96x96",
            "image.decode:stub",
            "drag_drop.trace:",
        ] {
            assert!(
                trace.contains(expected),
                "probe trace should contain {expected}: {trace}"
            );
        }
    }

    #[test]
    fn virtual_timers_fire_deterministically() {
        let mut services = HostServices::headless();
        assert_eq!(
            services.arm_timer(HostTimerRequest::new(HostTimerSlot::CaretBlink, 25, true)),
            vec!["timer.arm:caret_blink:25:repeat=true"]
        );
        assert_eq!(services.advance_time(24), vec!["time.advance:24:now=24"]);
        assert_eq!(
            services.advance_time(1),
            vec!["time.advance:1:now=25", "timer.fire:caret_blink:1:at=25"]
        );
        assert_eq!(
            services.advance_time(50),
            vec!["time.advance:50:now=75", "timer.fire:caret_blink:2:at=75"]
        );
    }

    #[test]
    fn windows_clipboard_reader_and_cursor_are_traceable() {
        let mut services = HostServices::windows(|| Some("win".to_string()));
        let (text, trace) = services.read_clipboard_text();
        assert_eq!(text, "win");
        assert_eq!(
            trace,
            vec!["clipboard.read:3:windows", "clipboard.set_text:3"]
        );
        assert_eq!(
            services.set_cursor(HostCursor::IBeam),
            vec!["cursor.set:ibeam"]
        );
    }
}
