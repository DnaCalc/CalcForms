//! Reducer control-policy model: the logical control tree the reducer routes
//! input over ([`ControlNode`]/[`ControlKind`]) and pure-geometry hit testing
//! ([`hit_test_control_tree`]). This is reducer *policy*, not rendering (see
//! `docs/specs/RENDERING_ARCHITECTURE.md` §9) — the kernel never sees these types.
//!
//! The `ControlNode::label`/`text_box`/`command_button`/`check_box` constructors are
//! low-level builders. The legitimate callers are the `.frm` loader ([`crate::frm`]),
//! tests, and the W005/W006 trace-replay evidence builders + examples (the latter are
//! explicitly-quarantined evidence/demo scaffolds, not the runtime path). Runtime
//! (W007) code must obtain a control tree only by materializing a form through
//! [`crate::runtime::materialize_form_from_frm`] (e.g.
//! [`crate::runtime::materialize_w007_demo_form`]) — never by hand-constructing
//! `ControlNode`s. Hand-built trees must not become the runtime pattern (oxforms-4pn.4).

use serde::{Deserialize, Serialize};

use oxforms_pal::{ControlId, LogicalPoint, LogicalRect};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ControlNode {
    pub control_id: ControlId,
    pub kind: ControlKind,
    pub caption: String,
    pub bounds: LogicalRect,
    pub z_order: i32,
    pub visible: bool,
    pub enabled: bool,
    pub focusable: bool,
    pub tab_stop: bool,
    pub tab_index: u32,
}

impl ControlNode {
    #[must_use]
    pub fn label(control_id: impl Into<String>, bounds: LogicalRect, z_order: i32) -> Self {
        Self {
            control_id: ControlId::new(control_id),
            kind: ControlKind::Label,
            caption: String::new(),
            bounds,
            z_order,
            visible: true,
            enabled: true,
            focusable: false,
            tab_stop: false,
            tab_index: 0,
        }
    }

    #[must_use]
    pub fn command_button(
        control_id: impl Into<String>,
        bounds: LogicalRect,
        z_order: i32,
        tab_index: u32,
    ) -> Self {
        Self {
            control_id: ControlId::new(control_id),
            kind: ControlKind::CommandButton,
            caption: String::new(),
            bounds,
            z_order,
            visible: true,
            enabled: true,
            focusable: true,
            tab_stop: true,
            tab_index,
        }
    }

    #[must_use]
    pub fn text_box(
        control_id: impl Into<String>,
        bounds: LogicalRect,
        z_order: i32,
        tab_index: u32,
    ) -> Self {
        Self {
            control_id: ControlId::new(control_id),
            kind: ControlKind::TextBox,
            caption: String::new(),
            bounds,
            z_order,
            visible: true,
            enabled: true,
            focusable: true,
            tab_stop: true,
            tab_index,
        }
    }

    #[must_use]
    pub fn check_box(
        control_id: impl Into<String>,
        bounds: LogicalRect,
        z_order: i32,
        tab_index: u32,
    ) -> Self {
        Self {
            control_id: ControlId::new(control_id),
            kind: ControlKind::CheckBox,
            caption: String::new(),
            bounds,
            z_order,
            visible: true,
            enabled: true,
            focusable: true,
            tab_stop: true,
            tab_index,
        }
    }

    #[must_use]
    pub fn hidden(mut self) -> Self {
        self.visible = false;
        self
    }

    #[must_use]
    pub fn disabled(mut self) -> Self {
        self.enabled = false;
        self
    }

    #[must_use]
    pub fn with_tab_stop(mut self, tab_stop: bool) -> Self {
        self.tab_stop = tab_stop;
        self
    }

    #[must_use]
    pub fn with_caption(mut self, caption: impl Into<String>) -> Self {
        self.caption = caption.into();
        self
    }

    #[must_use]
    pub fn contains_form_logical(&self, point: LogicalPoint) -> bool {
        self.visible
            && self.enabled
            && point.x >= self.bounds.x
            && point.y >= self.bounds.y
            && point.x < self.bounds.x + self.bounds.width
            && point.y < self.bounds.y + self.bounds.height
    }

    #[must_use]
    pub fn form_to_control_local(&self, point: LogicalPoint) -> LogicalPoint {
        LogicalPoint::new(point.x - self.bounds.x, point.y - self.bounds.y)
    }

    #[must_use]
    pub fn can_receive_focus(&self) -> bool {
        self.visible && self.enabled && self.focusable
    }

    #[must_use]
    pub fn participates_in_tab_order(&self) -> bool {
        self.can_receive_focus() && self.tab_stop
    }

    #[must_use]
    pub fn accelerator_key(&self) -> Option<char> {
        let mut chars = self.caption.chars();
        while let Some(character) = chars.next() {
            if character != '&' {
                continue;
            }

            match chars.next() {
                Some('&') => continue,
                Some(accelerator) if !accelerator.is_control() => {
                    return accelerator.to_uppercase().next();
                }
                _ => return None,
            }
        }

        None
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ControlKind {
    Label,
    CommandButton,
    TextBox,
    CheckBox,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct HitTestResult {
    pub control_id: ControlId,
    pub kind: ControlKind,
    pub bounds: LogicalRect,
    pub form_logical: LogicalPoint,
    pub control_local: LogicalPoint,
    pub z_order: i32,
}

#[must_use]
pub fn hit_test_control_tree(
    controls: &[ControlNode],
    form_logical: LogicalPoint,
) -> Option<HitTestResult> {
    controls
        .iter()
        .enumerate()
        .filter(|(_, control)| control.contains_form_logical(form_logical))
        .max_by_key(|(index, control)| (control.z_order, *index))
        .map(|(_, control)| HitTestResult {
            control_id: control.control_id.clone(),
            kind: control.kind,
            bounds: control.bounds,
            form_logical,
            control_local: control.form_to_control_local(form_logical),
            z_order: control.z_order,
        })
}
