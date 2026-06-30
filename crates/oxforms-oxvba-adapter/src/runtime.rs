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

use oxvba_bundle::ProjectMemberKind;
use oxvba_host::ProjectRuntimeSession;
use oxvba_runtime::{ObjectRef, Variant};

/// A thin driver over a VBA form-document that owns an `OxReducer`.
pub struct OxRuntime {
    session: ProjectRuntimeSession,
    form: ObjectRef,
}

impl OxRuntime {
    /// Create the form-document `form_class` and invoke its `build_member` (e.g. `"Build"`), which
    /// constructs the form + controls + the `OxReducer` and establishes the first frame.
    pub fn attach(
        mut session: ProjectRuntimeSession,
        form_class: &str,
        build_member: &str,
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
        Ok(Self { session, form })
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

    /// Route a normalized pointer event to the VBA reducer (`"mousedown"`/`"mouseup"`); returns the
    /// ordered effect log.
    pub fn dispatch_mouse(
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
    pub fn dispatch_key(
        &mut self,
        kind: &str,
        key_code: i16,
        shift: i16,
    ) -> Result<String, String> {
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
    pub fn dispatch_char(&mut self, text: &str) -> Result<String, String> {
        self.invoke_string(
            "DispatchChar",
            ProjectMemberKind::Method,
            vec![Variant::from_string(text)],
        )
    }

    /// Route a drag-drop text drop to the focused control via the VBA reducer.
    pub fn dispatch_drop(&mut self, text: &str) -> Result<String, String> {
        self.invoke_string(
            "DispatchDrop",
            ProjectMemberKind::Method,
            vec![Variant::from_string(text)],
        )
    }

    /// Push the current host clipboard text (read before a Ctrl+V is dispatched).
    pub fn set_clipboard_text(&mut self, text: &str) -> Result<(), String> {
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
}
