//! Live OS clipboard read for the keyboard Ctrl+V paste (oxforms-esq.16).
//!
//! The desktop bootstrap passes this reader into the thin CalcVBA runtime before dispatching
//! Ctrl+V paste. Reading goes through the `clipboard-win` crate's safe wrappers, so this
//! backend keeps its `forbid(unsafe_code)` stance -- the unsafe Win32 calls are encapsulated
//! in the dependency. Non-Windows targets have no desktop clipboard backend yet and return
//! `None`.

/// Read the current OS clipboard as plain Unicode text.
///
/// Returns `None` when the clipboard is empty, holds no text format, or is momentarily locked
/// by another process (`clipboard-win` surfaces these as errors, which map to `None`). An
/// empty string is also reported as `None`. The reducer treats a no-text result as a no-op
/// paste (no `BeforeDropOrPaste`/`Change`), so a `None` here is benign. On non-Windows targets
/// this always returns `None`.
#[cfg(windows)]
#[must_use]
pub fn read_clipboard_text() -> Option<String> {
    match clipboard_win::get_clipboard_string() {
        Ok(text) if !text.is_empty() => Some(text),
        _ => None,
    }
}

/// Non-Windows fallback: no desktop clipboard backend yet, so a keyboard paste reads nothing.
#[cfg(not(windows))]
#[must_use]
pub fn read_clipboard_text() -> Option<String> {
    None
}

#[cfg(test)]
mod tests {
    use super::read_clipboard_text;

    /// Smoke test (oxforms-esq.16): reading the live clipboard must never panic and always
    /// yields an `Option<String>`. The CONTENT is intentionally not asserted -- it depends on
    /// the machine clipboard and is non-deterministic; on a headless/no-access session
    /// `clipboard-win` returns an error which maps to `None`. This pins the cfg wiring +
    /// error-to-None mapping without coupling the deterministic floor to clipboard contents.
    #[test]
    fn read_clipboard_text_is_callable_and_never_panics() {
        let _result: Option<String> = read_clipboard_text();
    }
}
