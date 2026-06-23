use serde::{Deserialize, Serialize};

use oxforms_pal::{ControlId, LogicalPoint, LogicalRect};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ControlNode {
    pub control_id: ControlId,
    pub kind: ProbeControlKind,
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
            kind: ProbeControlKind::Label,
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
            kind: ProbeControlKind::CommandButton,
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
            kind: ProbeControlKind::TextBox,
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
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProbeControlKind {
    Label,
    CommandButton,
    TextBox,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct HitTestResult {
    pub control_id: ControlId,
    pub kind: ProbeControlKind,
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
