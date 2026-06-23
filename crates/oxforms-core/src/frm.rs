use std::collections::BTreeMap;
use std::fmt;

use oxforms_pal::{ControlId, LogicalRect, LogicalSize};
use serde::{Deserialize, Serialize};

use crate::{
    CheckBoxState, ControlKind, ControlNode, FormState, LifecycleState, TextBoxProbeState,
    TextCaretState,
};

pub const COORDINATE_MODEL_SPEC_PATH: &str = "docs/specs/COORDINATE_MODEL.md";

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct FrmInteractionModel {
    pub form_name: String,
    pub caption: String,
    pub surface: LogicalSize,
    pub state: FormState,
    pub controls: Vec<FrmControlRecord>,
    pub event_hooks: Vec<FrmControlEventHooks>,
    pub frx_references: Vec<FrmFrxReference>,
    pub unsupported: Vec<FrmUnsupportedRecord>,
    pub coordinate_model: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct FrmControlRecord {
    pub name: String,
    pub type_name: String,
    pub kind: ControlKind,
    pub caption: String,
    pub bounds_twips: TwipRect,
    pub bounds_points: LogicalRect,
    pub tab_index: u32,
    pub tab_stop: bool,
    pub focusable: bool,
    pub visible: bool,
    pub enabled: bool,
    pub default: bool,
    pub cancel: bool,
    pub initial_text: Option<String>,
    pub initial_checked: Option<bool>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct FrmControlEventHooks {
    pub control_id: ControlId,
    pub event_names: Vec<String>,
    pub dispatch_status: FrmEventDispatchStatus,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FrmEventDispatchStatus {
    ReducerEffectMetadataOnly,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct TwipRect {
    pub left: i32,
    pub top: i32,
    pub width: i32,
    pub height: i32,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct FrmFrxReference {
    pub owner_name: String,
    pub property_name: String,
    pub reference: String,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct FrmUnsupportedRecord {
    pub owner_name: String,
    pub type_name: String,
    pub reason: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct FrmLoadError {
    pub line: Option<usize>,
    pub message: String,
}

impl FrmLoadError {
    fn new(message: impl Into<String>) -> Self {
        Self {
            line: None,
            message: message.into(),
        }
    }

    fn at_line(line: usize, message: impl Into<String>) -> Self {
        Self {
            line: Some(line),
            message: message.into(),
        }
    }
}

impl fmt::Display for FrmLoadError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self.line {
            Some(line) => write!(formatter, "line {line}: {}", self.message),
            None => formatter.write_str(&self.message),
        }
    }
}

impl std::error::Error for FrmLoadError {}

#[derive(Clone, Debug)]
struct FrmBlock {
    type_name: String,
    name: String,
    properties: BTreeMap<String, String>,
    controls: Vec<FrmBlock>,
    line: usize,
}

#[must_use]
pub fn twips_to_points(twips: i32) -> f64 {
    f64::from(twips) / 20.0
}

pub fn load_selected_frm_interaction_state(
    source: &str,
) -> Result<FrmInteractionModel, FrmLoadError> {
    let root = parse_frm_blocks(source)?;
    project_selected_interaction_model(root)
}

fn parse_frm_blocks(source: &str) -> Result<FrmBlock, FrmLoadError> {
    let mut stack = Vec::<FrmBlock>::new();
    let mut root = None;

    for (index, raw_line) in source.lines().enumerate() {
        let line_number = index + 1;
        let line = raw_line.trim();
        if line.is_empty()
            || line.starts_with('\'')
            || line.starts_with("VERSION ")
            || line.starts_with("Attribute ")
        {
            continue;
        }

        if let Some(rest) = line.strip_prefix("Begin ") {
            let (type_name, name) = parse_begin(rest).ok_or_else(|| {
                FrmLoadError::at_line(line_number, format!("invalid Begin line: {line}"))
            })?;
            stack.push(FrmBlock {
                type_name,
                name,
                properties: BTreeMap::new(),
                controls: Vec::new(),
                line: line_number,
            });
            continue;
        }

        if line == "End" {
            let block = stack
                .pop()
                .ok_or_else(|| FrmLoadError::at_line(line_number, "End without Begin"))?;
            if let Some(parent) = stack.last_mut() {
                parent.controls.push(block);
            } else if root.replace(block).is_some() {
                return Err(FrmLoadError::at_line(
                    line_number,
                    "multiple top-level form blocks are not supported in this slice",
                ));
            }
            continue;
        }

        if let Some((key, value)) = parse_property(line) {
            let block = stack.last_mut().ok_or_else(|| {
                FrmLoadError::at_line(line_number, "property found outside a Begin block")
            })?;
            block.properties.insert(key.to_string(), value.to_string());
        }
    }

    if let Some(unclosed) = stack.last() {
        return Err(FrmLoadError::at_line(
            unclosed.line,
            format!("unclosed Begin block '{}'", unclosed.name),
        ));
    }

    root.ok_or_else(|| FrmLoadError::new("no top-level .frm Begin block found"))
}

fn parse_begin(rest: &str) -> Option<(String, String)> {
    let rest = rest.trim();
    let (type_name, after_type) = if rest.starts_with('{') {
        let end = rest.find('}')?;
        (rest[..=end].to_string(), rest[end + 1..].trim())
    } else {
        let (type_name, after_type) = rest.split_once(char::is_whitespace)?;
        (type_name.to_string(), after_type.trim())
    };
    let name = after_type.split_whitespace().next()?.to_string();
    Some((type_name, name))
}

fn parse_property(line: &str) -> Option<(&str, &str)> {
    let (key, raw_value) = line.split_once('=')?;
    Some((key.trim(), raw_value.trim()))
}

fn project_selected_interaction_model(root: FrmBlock) -> Result<FrmInteractionModel, FrmLoadError> {
    let form_name = root.name.clone();
    let caption = string_property(&root.properties, "Caption").unwrap_or_else(|| form_name.clone());
    let surface = LogicalSize::new(
        twips_to_points(
            int_property(&root.properties, "ClientWidth")
                .or_else(|| int_property(&root.properties, "Width"))
                .unwrap_or(0),
        ),
        twips_to_points(
            int_property(&root.properties, "ClientHeight")
                .or_else(|| int_property(&root.properties, "Height"))
                .unwrap_or(0),
        ),
    );

    let mut state = FormState::new(form_name.clone());
    state.lifecycle = LifecycleState::Loaded;

    let mut controls = Vec::new();
    let mut event_hooks = Vec::new();
    let mut frx_references = collect_frx_references(&root);
    let mut unsupported = Vec::new();

    for (index, child) in root.controls.iter().enumerate() {
        frx_references.extend(collect_frx_references(child));
        let Some(kind) = selected_control_kind(&child.type_name) else {
            unsupported.push(FrmUnsupportedRecord {
                owner_name: child.name.clone(),
                type_name: child.type_name.clone(),
                reason: "unsupported by selected Label/TextBox/CommandButton/CheckBox slice"
                    .to_string(),
            });
            continue;
        };

        let left = int_property(&child.properties, "Left").unwrap_or(0);
        let top = int_property(&child.properties, "Top").unwrap_or(0);
        let width = int_property(&child.properties, "Width").unwrap_or(0);
        let height = int_property(&child.properties, "Height").unwrap_or(0);
        let bounds_twips = TwipRect {
            left,
            top,
            width,
            height,
        };
        let bounds_points = LogicalRect::new(
            twips_to_points(left),
            twips_to_points(top),
            twips_to_points(width),
            twips_to_points(height),
        );
        let tab_index = int_property(&child.properties, "TabIndex")
            .and_then(|value| u32::try_from(value).ok())
            .unwrap_or(index as u32);
        let tab_stop = bool_property(&child.properties, "TabStop").unwrap_or(match kind {
            ControlKind::Label => false,
            ControlKind::CheckBox | ControlKind::CommandButton | ControlKind::TextBox => true,
        });
        let visible = bool_property(&child.properties, "Visible").unwrap_or(true);
        let enabled = bool_property(&child.properties, "Enabled").unwrap_or(true);
        let caption = string_property(&child.properties, "Caption").unwrap_or_default();
        let default = bool_property(&child.properties, "Default").unwrap_or(false);
        let cancel = bool_property(&child.properties, "Cancel").unwrap_or(false);
        let initial_text = if kind == ControlKind::TextBox {
            string_property(&child.properties, "Text")
                .or_else(|| string_property(&child.properties, "Value"))
        } else {
            None
        };
        let initial_checked = if kind == ControlKind::CheckBox {
            Some(boolean_value_property(&child.properties, "Value", child.line)?.unwrap_or(false))
        } else {
            None
        };

        let focusable = matches!(
            kind,
            ControlKind::CheckBox | ControlKind::CommandButton | ControlKind::TextBox
        );
        let mut node = match kind {
            ControlKind::Label => ControlNode::label(&child.name, bounds_points, index as i32),
            ControlKind::CheckBox => {
                ControlNode::check_box(&child.name, bounds_points, index as i32, tab_index)
            }
            ControlKind::CommandButton => {
                ControlNode::command_button(&child.name, bounds_points, index as i32, tab_index)
            }
            ControlKind::TextBox => {
                ControlNode::text_box(&child.name, bounds_points, index as i32, tab_index)
            }
        }
        .with_caption(caption.clone())
        .with_tab_stop(tab_stop);
        node.visible = visible;
        node.enabled = enabled;

        let control_id = node.control_id.clone();
        if default && kind == ControlKind::CommandButton {
            state.default_button = Some(control_id.clone());
        }
        if cancel && kind == ControlKind::CommandButton {
            state.cancel_button = Some(control_id.clone());
        }
        if kind == ControlKind::TextBox {
            state
                .text_boxes
                .push(text_box_state(control_id.clone(), initial_text.as_deref()));
        }
        if kind == ControlKind::CheckBox {
            state.check_boxes.push(check_box_state(
                control_id.clone(),
                initial_checked.unwrap_or(false),
            ));
        }

        state.controls.push(node);
        controls.push(FrmControlRecord {
            name: child.name.clone(),
            type_name: child.type_name.clone(),
            kind,
            caption,
            bounds_twips,
            bounds_points,
            tab_index,
            tab_stop,
            focusable,
            visible,
            enabled,
            default,
            cancel,
            initial_text,
            initial_checked,
        });
        event_hooks.push(FrmControlEventHooks {
            control_id,
            event_names: selected_event_hooks(kind)
                .iter()
                .map(|event| (*event).to_string())
                .collect(),
            dispatch_status: FrmEventDispatchStatus::ReducerEffectMetadataOnly,
        });
    }

    Ok(FrmInteractionModel {
        form_name,
        caption,
        surface,
        state,
        controls,
        event_hooks,
        frx_references,
        unsupported,
        coordinate_model: COORDINATE_MODEL_SPEC_PATH.to_string(),
    })
}

fn selected_control_kind(type_name: &str) -> Option<ControlKind> {
    let normalized = type_name.to_ascii_lowercase();
    if normalized.ends_with(".label") || normalized.contains(".label.") {
        Some(ControlKind::Label)
    } else if normalized.ends_with(".checkbox") || normalized.contains(".checkbox.") {
        Some(ControlKind::CheckBox)
    } else if normalized.ends_with(".commandbutton") || normalized.contains(".commandbutton.") {
        Some(ControlKind::CommandButton)
    } else if normalized.ends_with(".textbox") || normalized.contains(".textbox.") {
        Some(ControlKind::TextBox)
    } else {
        None
    }
}

fn selected_event_hooks(kind: ControlKind) -> &'static [&'static str] {
    match kind {
        ControlKind::CheckBox => &[
            "MouseDown",
            "MouseMove",
            "MouseUp",
            "Click",
            "Change",
            "KeyDown",
            "KeyUp",
        ],
        ControlKind::Label => &["MouseDown", "MouseMove", "MouseUp", "Click"],
        ControlKind::CommandButton => &[
            "MouseDown",
            "MouseMove",
            "MouseUp",
            "Click",
            "KeyDown",
            "KeyUp",
        ],
        ControlKind::TextBox => &[
            "MouseDown",
            "MouseMove",
            "MouseUp",
            "KeyDown",
            "KeyPress",
            "KeyUp",
            "Change",
        ],
    }
}

fn check_box_state(control_id: ControlId, checked: bool) -> CheckBoxState {
    CheckBoxState {
        control_id,
        checked,
        dirty: false,
        edit_sequence: 0,
    }
}

fn text_box_state(control_id: ControlId, initial_text: Option<&str>) -> TextBoxProbeState {
    let text = initial_text.unwrap_or_default().to_string();
    let caret = text.len();
    TextBoxProbeState {
        control_id,
        text,
        caret: TextCaretState {
            anchor: caret,
            active: caret,
            preferred_column: None,
        },
        dirty: false,
        edit_sequence: 0,
    }
}

fn collect_frx_references(block: &FrmBlock) -> Vec<FrmFrxReference> {
    block
        .properties
        .iter()
        .filter_map(|(name, value)| {
            let text = unquote(value);
            if text.to_ascii_lowercase().contains(".frx") {
                Some(FrmFrxReference {
                    owner_name: block.name.clone(),
                    property_name: name.clone(),
                    reference: text.to_string(),
                })
            } else {
                None
            }
        })
        .collect()
}

fn int_property(properties: &BTreeMap<String, String>, key: &str) -> Option<i32> {
    let raw = properties.get(key)?;
    unquote(raw).parse::<i32>().ok()
}

fn bool_property(properties: &BTreeMap<String, String>, key: &str) -> Option<bool> {
    let raw = unquote(properties.get(key)?);
    if raw.eq_ignore_ascii_case("true") {
        Some(true)
    } else if raw.eq_ignore_ascii_case("false") {
        Some(false)
    } else {
        raw.parse::<i32>().ok().map(|value| value != 0)
    }
}

fn boolean_value_property(
    properties: &BTreeMap<String, String>,
    key: &str,
    line: usize,
) -> Result<Option<bool>, FrmLoadError> {
    let Some(raw) = properties.get(key) else {
        return Ok(None);
    };
    let value = unquote(raw);
    if value.eq_ignore_ascii_case("true") || value == "-1" {
        Ok(Some(true))
    } else if value.eq_ignore_ascii_case("false") || value == "0" {
        Ok(Some(false))
    } else {
        Err(FrmLoadError::at_line(
            line,
            format!("unsupported CheckBox Value token '{value}' for boolean-only W006 slice"),
        ))
    }
}

fn string_property(properties: &BTreeMap<String, String>, key: &str) -> Option<String> {
    properties.get(key).map(|value| unquote(value).to_string())
}

fn unquote(value: &str) -> &str {
    value
        .strip_prefix('"')
        .and_then(|value| value.strip_suffix('"'))
        .unwrap_or(value)
}

#[cfg(test)]
mod tests {
    use oxforms_pal::{
        ClickCount, CoordinatePayload, KeyCode, KeyEvent, KeyRepeat, KeyboardModifiers,
        LogicalPoint, MouseButton, MouseButtonEvent, MouseButtons, PointerId, RawKeyDiagnostics,
        UiEvent, UiEventId, UiEventKind, UiEventSource,
    };

    use super::*;
    use crate::{reduce, EffectKind, FocusTarget};

    const W006_SELECTED_FRM: &str =
        include_str!("../../../fixtures/frm/w006-interaction-slice/w006-interaction-slice.frm");
    const W006_CHECKBOX_FRM: &str =
        include_str!("../../../fixtures/frm/w006-checkbox-boolean/w006-checkbox-boolean.frm");

    #[test]
    fn selected_frm_fixture_projects_to_w005_logical_tree() {
        let loaded = load_selected_frm_interaction_state(W006_SELECTED_FRM)
            .expect("selected W006 fixture should load");

        assert_eq!(loaded.coordinate_model, COORDINATE_MODEL_SPEC_PATH);
        assert!(loaded.frx_references.is_empty());
        assert!(loaded.unsupported.is_empty());
        assert_eq!(loaded.surface, LogicalSize::new(240.0, 180.0));
        assert_eq!(loaded.state.lifecycle, LifecycleState::Loaded);
        assert_eq!(loaded.state.controls.len(), 4);
        assert_eq!(
            loaded.state.controls[0],
            ControlNode::label(
                "OracleProbeLabel",
                LogicalRect::new(24.0, 24.0, 96.0, 48.0),
                0,
            )
            .with_caption("Probe Label")
        );
        assert_eq!(
            loaded.state.controls[1],
            ControlNode::text_box(
                "OracleTextBox",
                LogicalRect::new(132.0, 24.0, 72.0, 24.0),
                1,
                0,
            )
            .with_caption("")
        );
        assert_eq!(
            loaded.state.default_button,
            Some(ControlId::new("OracleDefaultButton"))
        );
        assert_eq!(
            loaded.state.cancel_button,
            Some(ControlId::new("OracleCancelButton"))
        );
        assert_eq!(loaded.state.text_boxes[0].text, "seed");
        assert_eq!(loaded.state.text_boxes[0].caret.active, 4);
    }

    #[test]
    fn selected_frm_fixture_controls_participate_in_interaction_routing() {
        let loaded = load_selected_frm_interaction_state(W006_SELECTED_FRM)
            .expect("selected W006 fixture should load");

        let text_focus = reduce(
            loaded.state,
            UiEvent::new(
                UiEventId(1),
                UiEventSource::Replay,
                UiEventKind::MouseDown(mouse_button_event_at(true, 140.0, 30.0)),
            ),
        );
        assert_eq!(
            text_focus.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("OracleTextBox")))
        );

        let tabbed = reduce(
            text_focus.state,
            UiEvent::new(
                UiEventId(2),
                UiEventSource::Replay,
                UiEventKind::KeyDown(key_event(KeyCode::Tab)),
            ),
        );
        assert_eq!(
            tabbed.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("OracleDefaultButton")))
        );

        let enter = reduce(
            tabbed.state,
            UiEvent::new(
                UiEventId(3),
                UiEventSource::Replay,
                UiEventKind::KeyDown(key_event(KeyCode::Enter)),
            ),
        );
        assert!(enter.effects.iter().any(|effect| {
            matches!(
                &effect.kind,
                EffectKind::FireVbaEvent { event_name, .. } if event_name == "Click"
            ) && effect.target.control_id == Some(ControlId::new("OracleDefaultButton"))
        }));
    }

    #[test]
    fn selected_frm_fixture_records_reducer_event_hooks_as_metadata_only() {
        let loaded = load_selected_frm_interaction_state(W006_SELECTED_FRM)
            .expect("selected W006 fixture should load");
        let default_button_hooks = loaded
            .event_hooks
            .iter()
            .find(|hooks| hooks.control_id == ControlId::new("OracleDefaultButton"))
            .expect("default button hooks should exist");

        assert_eq!(
            default_button_hooks.dispatch_status,
            FrmEventDispatchStatus::ReducerEffectMetadataOnly
        );
        assert!(default_button_hooks
            .event_names
            .iter()
            .any(|event| event == "Click"));
    }

    #[test]
    fn checkbox_boolean_fixture_projects_to_control_tree_and_state() {
        let loaded = load_selected_frm_interaction_state(W006_CHECKBOX_FRM)
            .expect("selected CheckBox fixture should load");

        assert_eq!(loaded.form_name, "OxFormsW006CheckBoxBooleanForm");
        assert_eq!(loaded.surface, LogicalSize::new(180.0, 120.0));
        assert!(loaded.frx_references.is_empty());
        assert!(loaded.unsupported.is_empty());
        assert_eq!(loaded.state.controls.len(), 2);
        assert_eq!(loaded.state.check_boxes.len(), 2);
        assert_eq!(loaded.state.controls[0].kind, ControlKind::CheckBox);
        assert_eq!(
            loaded.state.controls[0],
            ControlNode::check_box(
                "OracleCheckBoxFalse",
                LogicalRect::new(24.0, 24.0, 96.0, 18.0),
                0,
                0,
            )
            .with_caption("Unchecked")
        );
        assert_eq!(loaded.controls[0].initial_checked, Some(false));
        assert_eq!(loaded.controls[1].initial_checked, Some(true));
        assert_eq!(
            loaded
                .state
                .check_boxes
                .iter()
                .map(|entry| (entry.control_id.clone(), entry.checked))
                .collect::<Vec<_>>(),
            vec![
                (ControlId::new("OracleCheckBoxFalse"), false),
                (ControlId::new("OracleCheckBoxTrue"), true),
            ]
        );
    }

    #[test]
    fn checkbox_fixture_records_reducer_event_hooks_as_metadata_only() {
        let loaded = load_selected_frm_interaction_state(W006_CHECKBOX_FRM)
            .expect("selected CheckBox fixture should load");
        let hooks = loaded
            .event_hooks
            .iter()
            .find(|hooks| hooks.control_id == ControlId::new("OracleCheckBoxFalse"))
            .expect("CheckBox hooks should exist");

        assert_eq!(
            hooks.dispatch_status,
            FrmEventDispatchStatus::ReducerEffectMetadataOnly
        );
        assert_eq!(
            hooks.event_names,
            vec![
                "MouseDown",
                "MouseMove",
                "MouseUp",
                "Click",
                "Change",
                "KeyDown",
                "KeyUp",
            ]
        );
    }

    #[test]
    fn checkbox_value_rejects_non_boolean_tokens_in_selected_slice() {
        let source = r#"
VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} BadCheckBoxValue
   ClientHeight = 1200
   ClientWidth = 1200
   Begin MSForms.CheckBox CheckBox1
      Caption = "Bad"
      Value = 1
      Left = 0
      Top = 0
      Width = 1200
      Height = 300
   End
End
"#;
        let error =
            load_selected_frm_interaction_state(source).expect_err("Value=1 is outside this lane");

        assert!(error
            .message
            .contains("unsupported CheckBox Value token '1'"));
    }

    #[test]
    fn frx_references_are_detected_but_not_required_for_selected_fixture() {
        let source = r#"
VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} FrxProbe
   ClientHeight = 1200
   ClientWidth = 1200
   Begin MSForms.Label Label1
      Caption = "Has Picture"
      Left = 0
      Top = 0
      Width = 1200
      Height = 300
      Picture = "FrxProbe.frx":0000
   End
End
"#;
        let loaded = load_selected_frm_interaction_state(source)
            .expect("binary references should be reported, not crash the small slice");

        assert_eq!(loaded.frx_references.len(), 1);
        assert_eq!(loaded.frx_references[0].property_name, "Picture");
    }

    fn mouse_button_event_at(left_down: bool, x: f64, y: f64) -> MouseButtonEvent {
        MouseButtonEvent {
            pointer_id: Some(PointerId(1)),
            button: MouseButton::Left,
            buttons_down: MouseButtons {
                left: left_down,
                ..MouseButtons::default()
            },
            modifiers: KeyboardModifiers::default(),
            click_count: ClickCount(1),
            coordinates: CoordinatePayload {
                form_logical: Some(LogicalPoint::new(x, y)),
                ..CoordinatePayload::default()
            },
        }
    }

    fn key_event(key: KeyCode) -> KeyEvent {
        KeyEvent {
            key,
            modifiers: KeyboardModifiers::default(),
            repeat: KeyRepeat::default(),
            raw: RawKeyDiagnostics::default(),
        }
    }
}
