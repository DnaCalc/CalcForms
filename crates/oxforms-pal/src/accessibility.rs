//! Host-neutral accessibility rows mapped to a UIA-provider-facing model.
//!
//! The VBA `OxAccessibilityService` remains the semantic source of truth. This
//! module parses that deterministic snapshot and projects it into the typed
//! shape a Windows UIA adapter can expose. It deliberately stores no HWNDs, COM
//! objects, or assistive-technology client state.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct AccessibilitySnapshot {
    pub nodes: Vec<AccessibilityNode>,
}

impl AccessibilitySnapshot {
    pub fn parse(text: &str) -> Result<Self, AccessibilityParseError> {
        let nodes = text
            .lines()
            .enumerate()
            .filter(|(_, line)| !line.trim().is_empty())
            .map(|(index, line)| AccessibilityNode::parse(index, line))
            .collect::<Result<Vec<_>, _>>()?;
        Ok(Self { nodes })
    }

    #[must_use]
    pub fn focused(&self) -> Option<&AccessibilityNode> {
        self.nodes.iter().find(|node| node.focused)
    }

    #[must_use]
    pub fn by_name(&self, name: &str) -> Option<&AccessibilityNode> {
        self.nodes.iter().find(|node| node.name == name)
    }

    #[must_use]
    pub fn uia_nodes(&self) -> Vec<UiaProviderNode> {
        self.nodes
            .iter()
            .map(UiaProviderNode::from_accessibility_node)
            .collect()
    }

    #[must_use]
    pub fn diff_notifications(&self, next: &Self) -> Vec<AccessibilityNotification> {
        let mut notifications = Vec::new();
        let old_focus = self.focused().map(|node| node.name.as_str());
        let new_focus = next.focused().map(|node| node.name.as_str());
        if old_focus != new_focus {
            notifications.push(AccessibilityNotification::FocusChanged {
                old_name: old_focus.unwrap_or_default().to_string(),
                new_name: new_focus.unwrap_or_default().to_string(),
            });
        }

        for new_node in &next.nodes {
            let Some(old_node) = self.by_name(&new_node.name) else {
                notifications.push(AccessibilityNotification::StructureChanged {
                    name: new_node.name.clone(),
                    change: StructureChange::ChildAdded,
                });
                continue;
            };
            if old_node.value != new_node.value {
                notifications.push(AccessibilityNotification::ValueChanged {
                    name: new_node.name.clone(),
                    old_value: old_node.value.clone(),
                    new_value: new_node.value.clone(),
                });
            }
            if old_node.selection_start != new_node.selection_start
                || old_node.selection_length != new_node.selection_length
                || old_node.selection_text != new_node.selection_text
                || old_node.selected != new_node.selected
            {
                notifications.push(AccessibilityNotification::SelectionChanged {
                    name: new_node.name.clone(),
                    old_start: old_node.selection_start,
                    old_length: old_node.selection_length,
                    new_start: new_node.selection_start,
                    new_length: new_node.selection_length,
                });
            }
            if old_node.enabled != new_node.enabled || old_node.visible != new_node.visible {
                notifications.push(AccessibilityNotification::StateChanged {
                    name: new_node.name.clone(),
                    enabled: new_node.enabled,
                    visible: new_node.visible,
                });
            }
        }

        for old_node in &self.nodes {
            if next.by_name(&old_node.name).is_none() {
                notifications.push(AccessibilityNotification::StructureChanged {
                    name: old_node.name.clone(),
                    change: StructureChange::ChildRemoved,
                });
            }
        }

        notifications
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct AccessibilityNode {
    pub source_index: usize,
    pub role: String,
    pub name: String,
    pub value: String,
    pub enabled: bool,
    pub visible: bool,
    pub focused: bool,
    pub selected: bool,
    pub selection_start: i32,
    pub selection_length: i32,
    pub selection_text: String,
    pub patterns: Vec<String>,
    pub row_count: i32,
    pub column_count: i32,
    pub focusable: bool,
    pub tabstop: bool,
    pub control_count: i32,
}

impl AccessibilityNode {
    fn parse(source_index: usize, line: &str) -> Result<Self, AccessibilityParseError> {
        let fields = parse_fields(line)?;
        let required = |key: &'static str| -> Result<String, AccessibilityParseError> {
            fields
                .iter()
                .find(|(candidate, _)| candidate == key)
                .map(|(_, value)| value.clone())
                .ok_or(AccessibilityParseError::MissingField {
                    line: source_index,
                    key,
                })
        };
        let optional = |key: &str| -> String {
            fields
                .iter()
                .find(|(candidate, _)| candidate == key)
                .map(|(_, value)| value.clone())
                .unwrap_or_default()
        };

        Ok(Self {
            source_index,
            role: required("role")?,
            name: required("name")?,
            value: optional("value"),
            enabled: parse_bool(&optional("enabled")),
            visible: parse_bool(&optional("visible")),
            focused: parse_bool(&optional("focused")),
            selected: parse_bool(&optional("selected")),
            selection_start: parse_i32(&optional("sel_start")),
            selection_length: parse_i32(&optional("sel_length")),
            selection_text: optional("sel_text"),
            patterns: optional("patterns")
                .split(',')
                .filter(|pattern| !pattern.is_empty())
                .map(str::to_string)
                .collect(),
            row_count: parse_i32(&optional("row_count")),
            column_count: parse_i32(&optional("column_count")),
            focusable: parse_bool(&optional("focusable")),
            tabstop: parse_bool(&optional("tabstop")),
            control_count: parse_i32(&optional("control_count")),
        })
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct UiaProviderNode {
    pub automation_id: String,
    pub name: String,
    pub control_type: UiaControlType,
    pub value: String,
    pub is_enabled: bool,
    pub is_offscreen: bool,
    pub has_keyboard_focus: bool,
    pub is_keyboard_focusable: bool,
    pub patterns: Vec<UiaPattern>,
    pub selection: Option<UiaSelection>,
    pub row_count: i32,
    pub column_count: i32,
}

impl UiaProviderNode {
    #[must_use]
    pub fn from_accessibility_node(node: &AccessibilityNode) -> Self {
        Self {
            automation_id: node.name.clone(),
            name: node.name.clone(),
            control_type: UiaControlType::from_role(&node.role),
            value: node.value.clone(),
            is_enabled: node.enabled,
            is_offscreen: !node.visible,
            has_keyboard_focus: node.focused,
            is_keyboard_focusable: node.focusable || node.tabstop,
            patterns: UiaPattern::from_snapshot_patterns(&node.patterns, &node.role),
            selection: if node.selection_length > 0 || node.selected {
                Some(UiaSelection {
                    start: node.selection_start,
                    length: node.selection_length,
                    text: node.selection_text.clone(),
                    selected: node.selected,
                })
            } else {
                None
            },
            row_count: node.row_count,
            column_count: node.column_count,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum UiaControlType {
    Button,
    CheckBox,
    ComboBox,
    Edit,
    Group,
    Image,
    List,
    Pane,
    RadioButton,
    ScrollBar,
    Spinner,
    Tab,
    TabItem,
    Text,
    Window,
}

impl UiaControlType {
    const fn from_role(role: &str) -> Self {
        match role.as_bytes() {
            b"button" => Self::Button,
            b"checkbox" => Self::CheckBox,
            b"combobox" => Self::ComboBox,
            b"form" => Self::Window,
            b"group" => Self::Group,
            b"image" => Self::Image,
            b"label" => Self::Text,
            b"listbox" => Self::List,
            b"multipage" | b"page" => Self::Pane,
            b"radio" => Self::RadioButton,
            b"scrollbar" => Self::ScrollBar,
            b"spinbutton" => Self::Spinner,
            b"tabstrip" => Self::Tab,
            b"textbox" => Self::Edit,
            b"togglebutton" => Self::Button,
            _ => Self::Pane,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum UiaPattern {
    Dock,
    ExpandCollapse,
    Grid,
    Invoke,
    RangeValue,
    Scroll,
    Selection,
    Text,
    Toggle,
    Value,
}

impl UiaPattern {
    fn from_snapshot_patterns(patterns: &[String], role: &str) -> Vec<Self> {
        let mut out = Vec::new();
        for pattern in patterns {
            match pattern.as_str() {
                "container" => {}
                "expand-collapse" => push_unique(&mut out, Self::ExpandCollapse),
                "grid" => push_unique(&mut out, Self::Grid),
                "invoke" => push_unique(&mut out, Self::Invoke),
                "range" => push_unique(&mut out, Self::RangeValue),
                "scroll" => push_unique(&mut out, Self::Scroll),
                "selection" => push_unique(&mut out, Self::Selection),
                "textbox" | "text" => push_unique(&mut out, Self::Text),
                "toggle" => push_unique(&mut out, Self::Toggle),
                "value" => push_unique(&mut out, Self::Value),
                _ => {}
            }
        }
        if role == "checkbox" || role == "togglebutton" {
            push_unique(&mut out, Self::Toggle);
        }
        out
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct UiaSelection {
    pub start: i32,
    pub length: i32,
    pub text: String,
    pub selected: bool,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum AccessibilityNotification {
    FocusChanged {
        old_name: String,
        new_name: String,
    },
    ValueChanged {
        name: String,
        old_value: String,
        new_value: String,
    },
    SelectionChanged {
        name: String,
        old_start: i32,
        old_length: i32,
        new_start: i32,
        new_length: i32,
    },
    StateChanged {
        name: String,
        enabled: bool,
        visible: bool,
    },
    StructureChanged {
        name: String,
        change: StructureChange,
    },
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum StructureChange {
    ChildAdded,
    ChildRemoved,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct MsaaProviderDecision {
    pub implemented: bool,
    pub reason: String,
}

impl Default for MsaaProviderDecision {
    fn default() -> Self {
        Self {
            implemented: false,
            reason: "UIA-first adapter is the W009 provider target; MSAA stays deferred until a named product or compatibility requirement needs it.".to_string(),
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum AccessibilityParseError {
    MissingField { line: usize, key: &'static str },
    MalformedField { line: String },
}

fn parse_fields(line: &str) -> Result<Vec<(String, String)>, AccessibilityParseError> {
    let mut fields = Vec::new();
    for raw_field in split_preserving_escapes(line, ';') {
        let Some((raw_key, raw_value)) = split_once_unescaped(&raw_field, '=') else {
            return Err(AccessibilityParseError::MalformedField { line: raw_field });
        };
        fields.push((unescape(&raw_key), unescape(&raw_value)));
    }
    Ok(fields)
}

fn split_preserving_escapes(text: &str, delimiter: char) -> Vec<String> {
    let mut parts = Vec::new();
    let mut current = String::new();
    let mut chars = text.chars();
    while let Some(ch) = chars.next() {
        if ch == '\\' {
            current.push(ch);
            if let Some(next) = chars.next() {
                current.push(next);
            }
        } else if ch == delimiter {
            parts.push(current);
            current = String::new();
        } else {
            current.push(ch);
        }
    }
    parts.push(current);
    parts
}

fn split_once_unescaped(text: &str, delimiter: char) -> Option<(String, String)> {
    let mut left = String::new();
    let mut right = String::new();
    let mut chars = text.chars();
    let mut found = false;
    while let Some(ch) = chars.next() {
        if ch == '\\' {
            let target = if found { &mut right } else { &mut left };
            target.push(ch);
            if let Some(next) = chars.next() {
                target.push(next);
            }
        } else if ch == delimiter && !found {
            found = true;
        } else if found {
            right.push(ch);
        } else {
            left.push(ch);
        }
    }
    found.then_some((left, right))
}

fn unescape(text: &str) -> String {
    let mut out = String::new();
    let mut chars = text.chars();
    while let Some(ch) = chars.next() {
        if ch == '\\' {
            match chars.next() {
                Some('n') => out.push('\n'),
                Some('r') => out.push('\r'),
                Some(next) => out.push(next),
                None => out.push('\\'),
            }
        } else {
            out.push(ch);
        }
    }
    out
}

fn parse_bool(text: &str) -> bool {
    text.eq_ignore_ascii_case("true")
}

fn parse_i32(text: &str) -> i32 {
    text.parse().unwrap_or_default()
}

fn push_unique<T: Eq + Copy>(items: &mut Vec<T>, item: T) {
    if !items.contains(&item) {
        items.push(item);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SNAPSHOT: &str = "role=form;name=Demo;value=Caption;enabled=True;visible=True;focused=False;selected=False;sel_start=0;sel_length=0;sel_text=;patterns=container;row_count=0;column_count=0;control_count=2\nrole=textbox;name=Input\\;Field;value=a\\=b;enabled=True;visible=True;focused=True;selected=False;sel_start=1;sel_length=2;sel_text=b\\nc;patterns=textbox,value,selection;row_count=0;column_count=0;focusable=True;tabstop=True\nrole=checkbox;name=Accept;value=True;enabled=True;visible=True;focused=False;selected=True;sel_start=0;sel_length=0;sel_text=;patterns=toggle,value;row_count=0;column_count=0;focusable=True;tabstop=True";

    #[test]
    fn parses_accessibility_snapshot_rows_and_escapes() {
        let snapshot = AccessibilitySnapshot::parse(SNAPSHOT).expect("snapshot parses");
        assert_eq!(snapshot.nodes.len(), 3);
        assert_eq!(snapshot.focused().unwrap().name, "Input;Field");
        assert_eq!(snapshot.focused().unwrap().value, "a=b");
        assert_eq!(snapshot.focused().unwrap().selection_text, "b\nc");
    }

    #[test]
    fn maps_snapshot_nodes_to_uia_provider_nodes() {
        let snapshot = AccessibilitySnapshot::parse(SNAPSHOT).expect("snapshot parses");
        let nodes = snapshot.uia_nodes();
        let textbox = nodes
            .iter()
            .find(|node| node.automation_id == "Input;Field")
            .expect("textbox");
        assert_eq!(textbox.control_type, UiaControlType::Edit);
        assert!(textbox.patterns.contains(&UiaPattern::Text));
        assert!(textbox.patterns.contains(&UiaPattern::Value));
        assert!(textbox.patterns.contains(&UiaPattern::Selection));
        assert!(textbox.has_keyboard_focus);
        assert_eq!(textbox.selection.as_ref().unwrap().length, 2);

        let checkbox = nodes
            .iter()
            .find(|node| node.automation_id == "Accept")
            .expect("checkbox");
        assert_eq!(checkbox.control_type, UiaControlType::CheckBox);
        assert!(checkbox.patterns.contains(&UiaPattern::Toggle));
    }

    #[test]
    fn diffs_snapshots_into_provider_notifications() {
        let before = AccessibilitySnapshot::parse(
            "role=form;name=Demo;value=Caption;enabled=True;visible=True;focused=True;selected=False;sel_start=0;sel_length=0;sel_text=;patterns=container;row_count=0;column_count=0;control_count=1\nrole=textbox;name=Input;value=a;enabled=True;visible=True;focused=False;selected=False;sel_start=0;sel_length=0;sel_text=;patterns=textbox,value,selection;row_count=0;column_count=0;focusable=True;tabstop=True",
        )
        .expect("before");
        let after = AccessibilitySnapshot::parse(
            "role=form;name=Demo;value=Caption;enabled=True;visible=True;focused=False;selected=False;sel_start=0;sel_length=0;sel_text=;patterns=container;row_count=0;column_count=0;control_count=1\nrole=textbox;name=Input;value=abc;enabled=True;visible=True;focused=True;selected=False;sel_start=1;sel_length=2;sel_text=bc;patterns=textbox,value,selection;row_count=0;column_count=0;focusable=True;tabstop=True",
        )
        .expect("after");

        let notifications = before.diff_notifications(&after);
        assert!(notifications.iter().any(|notification| matches!(
            notification,
            AccessibilityNotification::FocusChanged { new_name, .. } if new_name == "Input"
        )));
        assert!(notifications.iter().any(|notification| matches!(
            notification,
            AccessibilityNotification::ValueChanged { name, new_value, .. }
                if name == "Input" && new_value == "abc"
        )));
        assert!(notifications.iter().any(|notification| matches!(
            notification,
            AccessibilityNotification::SelectionChanged { name, new_length, .. }
                if name == "Input" && *new_length == 2
        )));
    }

    #[test]
    fn records_msaa_as_deferred_by_policy() {
        let decision = MsaaProviderDecision::default();
        assert!(!decision.implemented);
        assert!(decision.reason.contains("UIA-first"));
    }

    #[test]
    fn preserves_a_malformed_trailing_escape_once() {
        let snapshot = AccessibilitySnapshot::parse(
            "role=label;name=Trailing;enabled=True;visible=True;focused=False;selected=False;sel_start=0;sel_length=0;sel_text=;patterns=text;row_count=0;column_count=0;value=one\\",
        )
        .expect("snapshot parses");
        assert_eq!(snapshot.nodes[0].value, "one\\");
    }
}
