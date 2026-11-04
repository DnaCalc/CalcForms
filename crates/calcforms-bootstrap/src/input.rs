//! Shared Windows input routing for the demo and Office workbook hosts.
use calcforms_calcvba_adapter::runtime::{
    OxRuntime, RuntimeEventTurn, RuntimeInput, RuntimeKeyKind, RuntimeMouseKind,
};
use calcforms_pal::{
    CoordinatePayload, KeyCode, LogicalPoint, MouseButton, MouseButtons, UiEvent, UiEventKind,
};

/// Map a window event to the VBA reducer call. Returns `Ok(Some(effect_log))` for a dispatched
/// event (empty log = no state change), `Ok(None)` for an event kind the demo ignores.
pub(super) fn dispatch_event(
    rt: &mut OxRuntime,
    event: &UiEvent,
    scale: f64,
) -> Result<Option<RuntimeEventTurn>, String> {
    let shift = |m: &calcforms_pal::KeyboardModifiers| -> i16 {
        (if m.shift { 1 } else { 0 })
            | (if m.control { 2 } else { 0 })
            | (if m.alt { 4 } else { 0 })
    };
    match &event.kind {
        UiEventKind::MouseDown(e) | UiEventKind::MouseUp(e) => {
            let (x, y) = logical_point(&e.coordinates, scale);
            let kind = if matches!(event.kind, UiEventKind::MouseDown(_)) {
                RuntimeMouseKind::Down
            } else {
                RuntimeMouseKind::Up
            };
            rt.dispatch_event_turn(RuntimeInput::Mouse {
                kind,
                x,
                y,
                button: mouse_button(e.button),
                shift: shift(&e.modifiers),
            })
            .map(Some)
        }
        UiEventKind::MouseMove(e) => {
            let (x, y) = logical_point(&e.coordinates, scale);
            rt.dispatch_event_turn(RuntimeInput::Mouse {
                kind: RuntimeMouseKind::Move,
                x,
                y,
                button: mouse_buttons(&e.buttons_down),
                shift: shift(&e.modifiers),
            })
            .map(Some)
        }
        UiEventKind::KeyDown(e) | UiEventKind::KeyUp(e) => {
            let vk = keycode_to_vk(&e.key);
            let shift_bits = shift(&e.modifiers);
            let input =
                if matches!(event.kind, UiEventKind::KeyDown(_)) && is_ctrl_v(vk, shift_bits) {
                    // Read the live OS clipboard only for Ctrl+V. The HostServices trace stays
                    // attached to this event turn.
                    RuntimeInput::PasteFromClipboard
                } else {
                    let kind = if matches!(event.kind, UiEventKind::KeyDown(_)) {
                        RuntimeKeyKind::Down
                    } else {
                        RuntimeKeyKind::Up
                    };
                    RuntimeInput::Key {
                        kind,
                        key_code: vk,
                        shift: shift_bits,
                    }
                };
            rt.dispatch_event_turn(input).map(Some)
        }
        UiEventKind::CharacterInput(e) => rt
            .dispatch_event_turn(RuntimeInput::CharacterInput(e.text.clone()))
            .map(Some),
        _ => Ok(None),
    }
}

pub(super) fn is_ctrl_v(vk: i16, shift: i16) -> bool {
    (shift & 2) != 0 && vk == 86
}

pub(super) fn is_deferred_plain_text_key(event: &UiEvent) -> bool {
    match &event.kind {
        UiEventKind::KeyDown(e) | UiEventKind::KeyUp(e) => {
            !e.modifiers.control
                && !e.modifiers.alt
                && matches!(e.key, KeyCode::Character(_) | KeyCode::Space)
        }
        _ => false,
    }
}

fn mouse_button(button: MouseButton) -> i16 {
    match button {
        MouseButton::Left => 1,
        MouseButton::Right => 2,
        MouseButton::Middle => 3,
        _ => 0,
    }
}

fn mouse_buttons(buttons: &MouseButtons) -> i16 {
    if buttons.left {
        1
    } else if buttons.right {
        2
    } else if buttons.middle {
        3
    } else {
        0
    }
}

/// Client pixels divided by the uniform device-fit `scale` -> form-logical integer point.
fn logical_point(coords: &CoordinatePayload, scale: f64) -> (i32, i32) {
    if let Some(form) = coords.form_logical {
        return (form.x.round() as i32, form.y.round() as i32);
    }
    if let Some(px) = coords.client_pixels {
        let p = LogicalPoint::new(px.x / scale, px.y / scale);
        return (p.x.round() as i32, p.y.round() as i32);
    }
    (0, 0)
}

/// Map the structured `KeyCode` (the PAL populates this; it does NOT populate the raw virtual-key
/// diagnostic) to the MSForms/Windows virtual-key number the VBA reducer routes by (Tab=9,
/// Enter=13, Escape=27, Space=32, edit keys, and a letter/digit's uppercased ASCII byte so
/// e.g. 'v' -> 86 for Ctrl+V). Unknown keys map to 0 (no special routing).
pub(super) fn keycode_to_vk(key: &KeyCode) -> i16 {
    match key {
        KeyCode::Backspace => 8,
        KeyCode::Tab => 9,
        KeyCode::Enter => 13,
        KeyCode::Escape => 27,
        KeyCode::Space => 32,
        KeyCode::End => 35,
        KeyCode::Home => 36,
        KeyCode::ArrowLeft => 37,
        KeyCode::ArrowUp => 38,
        KeyCode::ArrowRight => 39,
        KeyCode::ArrowDown => 40,
        KeyCode::Delete => 46,
        KeyCode::Character(s) => s.chars().next().map_or(0, char_to_vk),
        _ => 0,
    }
}

fn char_to_vk(c: char) -> i16 {
    match c.to_ascii_uppercase() {
        'A'..='Z' | '0'..='9' => i16::from(c.to_ascii_uppercase() as u8),
        ' ' => 32,
        ';' | ':' => 0xBA,
        '=' | '+' => 0xBB,
        ',' | '<' => 0xBC,
        '-' | '_' => 0xBD,
        '.' | '>' => 0xBE,
        '/' | '?' => 0xBF,
        '`' | '~' => 0xC0,
        '[' | '{' => 0xDB,
        '\\' | '|' => 0xDC,
        ']' | '}' => 0xDD,
        '\'' | '"' => 0xDE,
        _ => 0,
    }
}
