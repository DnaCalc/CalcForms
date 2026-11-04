//! winit → normalized [`UiEvent`] mapping.
//!
//! Pure functions only: each takes the leaf pieces of a winit event (already
//! destructured by the window layer) plus an explicit [`UiEventId`], and returns the
//! host-neutral [`UiEvent`] the reducer path consumes. No event loop, window handle,
//! or interior mutability is involved, so every mapping is unit-testable headlessly.
//!
//! These functions fill *device/client* coordinates (client pixels + DPI). Mapping
//! client pixels to a form's logical points needs the renderer's device scale, which
//! the window/bootstrap layer owns — [`with_form_logical`] is the pure helper for that
//! step, kept here so the whole input contract lives in one place but layered so the
//! normalizer never needs to know a form's geometry.

use calcforms_pal::{
    CharacterInputEvent, ClickCount, CloseQueryPolicy, CloseReason, CloseRequestEvent,
    CloseRequestOrigin, CoordinatePayload, DpiScale, FocusEvent, FocusReason, KeyCode, KeyEvent,
    KeyRepeat, KeyboardModifiers, LogicalPoint, MouseButton, MouseButtonEvent, MouseButtons,
    MouseMoveEvent, PixelPoint, PixelSize, RawKeyDiagnostics, ResizeEvent, UiEvent, UiEventId,
    UiEventKind, UiEventSource,
};

use winit::event::MouseButton as WinitMouseButton;
use winit::keyboard::{Key, ModifiersState, NamedKey};

/// Map a winit mouse button to the normalized button enum.
#[must_use]
pub fn mouse_button(button: WinitMouseButton) -> MouseButton {
    match button {
        WinitMouseButton::Left => MouseButton::Left,
        WinitMouseButton::Right => MouseButton::Right,
        WinitMouseButton::Middle => MouseButton::Middle,
        WinitMouseButton::Back => MouseButton::X1,
        WinitMouseButton::Forward => MouseButton::X2,
        WinitMouseButton::Other(code) => MouseButton::Other(code),
    }
}

/// Set/clear a button in a [`MouseButtons`] bitset (the window tracks the live set).
pub fn set_button(buttons: &mut MouseButtons, button: MouseButton, down: bool) {
    match button {
        MouseButton::Left => buttons.left = down,
        MouseButton::Right => buttons.right = down,
        MouseButton::Middle => buttons.middle = down,
        MouseButton::X1 => buttons.x1 = down,
        MouseButton::X2 => buttons.x2 = down,
        MouseButton::Other(code) => {
            buttons.other.retain(|c| *c != code);
            if down {
                buttons.other.push(code);
            }
        }
    }
}

/// Map winit modifier state to the normalized modifier set.
///
/// winit 0.30 `ModifiersState` exposes only shift/control/alt/super, so
/// `caps_lock`/`num_lock`/`scroll_lock`/`platform` are left at their default `false`.
/// That is "not provided by this backend", not an authoritative "off" — a consumer
/// that needs lock state must source it separately (e.g. `GetKeyState` on Windows).
#[must_use]
pub fn modifiers(state: ModifiersState) -> KeyboardModifiers {
    KeyboardModifiers {
        shift: state.shift_key(),
        control: state.control_key(),
        alt: state.alt_key(),
        meta: state.super_key(),
        ..KeyboardModifiers::default()
    }
}

/// Map a winit logical key to the normalized [`KeyCode`].
#[must_use]
pub fn key_code(key: &Key) -> KeyCode {
    match key {
        Key::Named(named) => named_key(*named),
        Key::Character(s) => KeyCode::Character(s.to_string()),
        Key::Unidentified(_) | Key::Dead(_) => KeyCode::Unidentified,
    }
}

fn named_key(named: NamedKey) -> KeyCode {
    match named {
        NamedKey::Enter => KeyCode::Enter,
        NamedKey::Escape => KeyCode::Escape,
        NamedKey::Tab => KeyCode::Tab,
        NamedKey::Backspace => KeyCode::Backspace,
        NamedKey::Delete => KeyCode::Delete,
        NamedKey::ArrowLeft => KeyCode::ArrowLeft,
        NamedKey::ArrowRight => KeyCode::ArrowRight,
        NamedKey::ArrowUp => KeyCode::ArrowUp,
        NamedKey::ArrowDown => KeyCode::ArrowDown,
        NamedKey::Home => KeyCode::Home,
        NamedKey::End => KeyCode::End,
        NamedKey::PageUp => KeyCode::PageUp,
        NamedKey::PageDown => KeyCode::PageDown,
        NamedKey::Space => KeyCode::Space,
        NamedKey::F1 => KeyCode::Function(1),
        NamedKey::F2 => KeyCode::Function(2),
        NamedKey::F3 => KeyCode::Function(3),
        NamedKey::F4 => KeyCode::Function(4),
        NamedKey::F5 => KeyCode::Function(5),
        NamedKey::F6 => KeyCode::Function(6),
        NamedKey::F7 => KeyCode::Function(7),
        NamedKey::F8 => KeyCode::Function(8),
        NamedKey::F9 => KeyCode::Function(9),
        NamedKey::F10 => KeyCode::Function(10),
        NamedKey::F11 => KeyCode::Function(11),
        NamedKey::F12 => KeyCode::Function(12),
        other => KeyCode::Other(format!("{other:?}")),
    }
}

fn client_coords(x: f64, y: f64, dpi: DpiScale) -> CoordinatePayload {
    CoordinatePayload {
        client_pixels: Some(PixelPoint::new(x, y)),
        dpi: Some(dpi),
        ..CoordinatePayload::default()
    }
}

/// Enrich a coordinate payload with `form_logical`, derived from the renderer's
/// device scale (logical = client / scale; the form origin is the client origin).
/// This is the layering seam: the normalizer fills client pixels, the window/bootstrap
/// — which knows the scale used to render — adds the logical mapping the reducer routes
/// on. Returns the payload unchanged if it has no client point.
#[must_use]
pub fn with_form_logical(
    mut coords: CoordinatePayload,
    scale_x: f64,
    scale_y: f64,
) -> CoordinatePayload {
    if let Some(client) = coords.client_pixels {
        let sx = if scale_x == 0.0 { 1.0 } else { scale_x };
        let sy = if scale_y == 0.0 { 1.0 } else { scale_y };
        coords.form_logical = Some(LogicalPoint::new(client.x / sx, client.y / sy));
    }
    coords
}

/// `MouseMove` from a winit cursor-moved event (client pixels).
#[must_use]
pub fn pointer_moved(
    id: UiEventId,
    x: f64,
    y: f64,
    dpi: DpiScale,
    buttons: MouseButtons,
    mods: KeyboardModifiers,
) -> UiEvent {
    UiEvent::new(
        id,
        UiEventSource::Pal,
        UiEventKind::MouseMove(MouseMoveEvent {
            pointer_id: None,
            buttons_down: buttons,
            modifiers: mods,
            coordinates: client_coords(x, y, dpi),
        }),
    )
}

/// `MouseDown`/`MouseUp` from a winit mouse-input event.
#[allow(clippy::too_many_arguments)]
#[must_use]
pub fn pointer_button(
    id: UiEventId,
    button: MouseButton,
    pressed: bool,
    x: f64,
    y: f64,
    dpi: DpiScale,
    buttons: MouseButtons,
    mods: KeyboardModifiers,
    click_count: u8,
) -> UiEvent {
    let event = MouseButtonEvent {
        pointer_id: None,
        button,
        buttons_down: buttons,
        modifiers: mods,
        click_count: ClickCount(click_count),
        coordinates: client_coords(x, y, dpi),
    };
    let kind = if pressed {
        UiEventKind::MouseDown(event)
    } else {
        UiEventKind::MouseUp(event)
    };
    UiEvent::new(id, UiEventSource::Pal, kind)
}

/// `KeyDown`/`KeyUp` from a winit keyboard event's logical key.
#[must_use]
pub fn key_event(
    id: UiEventId,
    key: &Key,
    pressed: bool,
    mods: KeyboardModifiers,
    is_repeat: bool,
) -> UiEvent {
    let event = KeyEvent {
        key: key_code(key),
        modifiers: mods,
        repeat: KeyRepeat {
            is_repeat,
            repeat_count: None,
        },
        raw: RawKeyDiagnostics::default(),
    };
    let kind = if pressed {
        UiEventKind::KeyDown(event)
    } else {
        UiEventKind::KeyUp(event)
    };
    UiEvent::new(id, UiEventSource::Pal, kind)
}

/// `CharacterInput` from a winit key event's committed text, dropping control
/// characters (the text service commits printable text only). Returns `None` when
/// nothing printable remains.
#[must_use]
pub fn character_input(id: UiEventId, text: &str, mods: KeyboardModifiers) -> Option<UiEvent> {
    let printable: String = text.chars().filter(|c| !c.is_control()).collect();
    if printable.is_empty() {
        return None;
    }
    Some(UiEvent::new(
        id,
        UiEventSource::Pal,
        UiEventKind::CharacterInput(CharacterInputEvent {
            text: printable,
            modifiers: mods,
            raw: Vec::new(),
        }),
    ))
}

/// `CloseRequest` from a winit `CloseRequested` (the user clicked the X / Alt-F4).
/// This is a close request, not a focus change — winit delivers real focus loss
/// separately via `Focused(false)` ([`window_focus`]).
#[must_use]
pub fn window_close_request(id: UiEventId) -> UiEvent {
    UiEvent::new(
        id,
        UiEventSource::Pal,
        UiEventKind::CloseRequest(CloseRequestEvent {
            origin: CloseRequestOrigin::CloseButton,
            reason: CloseReason::User,
            query_policy: CloseQueryPolicy::Query,
            coordinates: None,
        }),
    )
}

/// `FocusIn`/`FocusOut` from a winit window-focus change.
#[must_use]
pub fn window_focus(id: UiEventId, focused: bool) -> UiEvent {
    let event = FocusEvent {
        reason: FocusReason::WindowActivation,
        related_target: None,
    };
    let kind = if focused {
        UiEventKind::FocusIn(event)
    } else {
        UiEventKind::FocusOut(event)
    };
    UiEvent::new(id, UiEventSource::Pal, kind)
}

/// `Resize` from a winit resize (physical client pixels + DPI).
#[must_use]
pub fn window_resized(id: UiEventId, width: f64, height: f64, dpi: DpiScale) -> UiEvent {
    UiEvent::new(
        id,
        UiEventSource::Pal,
        UiEventKind::Resize(ResizeEvent {
            window_rect: None,
            client_size: Some(PixelSize::new(width, height)),
            form_logical_size: None,
            dpi: Some(dpi),
        }),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use winit::keyboard::SmolStr;

    fn dpi() -> DpiScale {
        DpiScale::new(96.0, 96.0)
    }

    #[test]
    fn mouse_buttons_map_and_track() {
        assert_eq!(mouse_button(WinitMouseButton::Left), MouseButton::Left);
        assert_eq!(mouse_button(WinitMouseButton::Back), MouseButton::X1);
        assert_eq!(
            mouse_button(WinitMouseButton::Other(9)),
            MouseButton::Other(9)
        );

        let mut buttons = MouseButtons::default();
        set_button(&mut buttons, MouseButton::Left, true);
        assert!(buttons.left);
        set_button(&mut buttons, MouseButton::Other(9), true);
        assert_eq!(buttons.other, vec![9]);
        set_button(&mut buttons, MouseButton::Other(9), false);
        assert!(buttons.other.is_empty());
    }

    #[test]
    fn pointer_button_carries_button_state_and_client_point() {
        let mut buttons = MouseButtons::default();
        set_button(&mut buttons, MouseButton::Left, true);
        let ev = pointer_button(
            UiEventId(1),
            MouseButton::Left,
            true,
            30.0,
            18.0,
            dpi(),
            buttons,
            KeyboardModifiers::default(),
            1,
        );
        match ev.kind {
            UiEventKind::MouseDown(e) => {
                assert_eq!(e.button, MouseButton::Left);
                assert!(e.buttons_down.left);
                assert_eq!(
                    e.coordinates.client_pixels,
                    Some(PixelPoint::new(30.0, 18.0))
                );
                assert!(e.coordinates.dpi.is_some());
            }
            other => panic!("expected MouseDown, got {other:?}"),
        }
    }

    #[test]
    fn key_named_and_character_mapping() {
        assert_eq!(key_code(&Key::Named(NamedKey::Enter)), KeyCode::Enter);
        assert_eq!(key_code(&Key::Named(NamedKey::F5)), KeyCode::Function(5));
        assert_eq!(
            key_code(&Key::Character(SmolStr::new("a"))),
            KeyCode::Character("a".to_string())
        );
    }

    #[test]
    fn character_input_drops_control_chars() {
        assert!(character_input(UiEventId(2), "\u{8}", KeyboardModifiers::default()).is_none());
        let ev = character_input(UiEventId(3), "W", KeyboardModifiers::default())
            .expect("printable char yields an event");
        match ev.kind {
            UiEventKind::CharacterInput(e) => assert_eq!(e.text, "W"),
            other => panic!("expected CharacterInput, got {other:?}"),
        }
    }

    #[test]
    fn form_logical_is_client_divided_by_device_scale() {
        // At 3x device scale, a click at client (60,36) lands at logical (20,12).
        let coords = with_form_logical(client_coords(60.0, 36.0, dpi()), 3.0, 3.0);
        assert_eq!(coords.form_logical, Some(LogicalPoint::new(20.0, 12.0)));
        // Degenerate scale falls back to 1:1 rather than dividing by zero.
        let coords0 = with_form_logical(client_coords(5.0, 7.0, dpi()), 0.0, 0.0);
        assert_eq!(coords0.form_logical, Some(LogicalPoint::new(5.0, 7.0)));
    }

    #[test]
    fn resize_and_focus_shapes() {
        let resize = window_resized(UiEventId(4), 600.0, 360.0, dpi());
        assert!(matches!(resize.kind, UiEventKind::Resize(_)));
        let focus_in = window_focus(UiEventId(5), true);
        assert!(matches!(focus_in.kind, UiEventKind::FocusIn(_)));
        let focus_out = window_focus(UiEventId(6), false);
        assert!(matches!(focus_out.kind, UiEventKind::FocusOut(_)));
    }

    #[test]
    fn close_request_is_a_close_event_not_a_focus_change() {
        let ev = window_close_request(UiEventId(7));
        match ev.kind {
            UiEventKind::CloseRequest(e) => {
                assert_eq!(e.origin, calcforms_pal::CloseRequestOrigin::CloseButton);
                assert_eq!(e.reason, calcforms_pal::CloseReason::User);
            }
            other => panic!("expected CloseRequest, got {other:?}"),
        }
    }
}
