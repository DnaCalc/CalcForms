//! W005 OxVba event-dispatch smoke adapter.
//!
//! This module does not implement a forms event runtime. It translates
//! `oxforms-core` `FireVbaEvent` effects into traceable dispatch requests that an
//! OxVba host/test can invoke through the shared VBA event path.

use oxforms_core::{EffectArgument, EffectId, EffectKind, EffectRequest};
use oxforms_pal::UiEventTarget;
use oxvba_runtime::Variant;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct VbaEventDispatchRequest {
    pub dispatch_id: u64,
    pub effect_id: EffectId,
    pub target: UiEventTarget,
    pub event_name: String,
    pub raise_member: String,
    pub arguments: Vec<VbaEventArgument>,
    pub fact_source: Option<String>,
    pub cancel_metadata: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct VbaEventArgument {
    pub name: String,
    pub value: String,
    pub by_ref: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct VbaEventDispatchTraceRow {
    pub dispatch_id: u64,
    pub effect_id: EffectId,
    pub target_form_id: Option<String>,
    pub target_control_id: Option<String>,
    pub event_name: String,
    pub raise_member: String,
    pub argument_summary: Vec<String>,
    pub fact_source: Option<String>,
    pub cancel_metadata: Option<String>,
    pub completion: VbaEventDispatchCompletion,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum VbaEventDispatchCompletion {
    Requested,
    Succeeded,
    Failed,
}

#[derive(Debug, Clone, Eq, PartialEq)]
pub enum VbaEventDispatchError {
    NotFireVbaEvent,
    UnsupportedEvent(String),
    MissingArgument {
        event_name: String,
        argument_name: &'static str,
    },
    InvalidArgument {
        event_name: String,
        argument_name: String,
        value: String,
        expected: &'static str,
    },
}

impl std::fmt::Display for VbaEventDispatchError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotFireVbaEvent => write!(f, "effect is not a FireVbaEvent request"),
            Self::UnsupportedEvent(event_name) => {
                write!(f, "W005 smoke does not map event `{event_name}`")
            }
            Self::MissingArgument {
                event_name,
                argument_name,
            } => write!(f, "event `{event_name}` is missing argument `{argument_name}`"),
            Self::InvalidArgument {
                event_name,
                argument_name,
                value,
                expected,
            } => write!(
                f,
                "event `{event_name}` argument `{argument_name}` has value `{value}`, expected {expected}"
            ),
        }
    }
}

impl std::error::Error for VbaEventDispatchError {}

impl VbaEventDispatchRequest {
    pub fn from_effect(
        dispatch_id: u64,
        effect: &EffectRequest,
    ) -> Result<Self, VbaEventDispatchError> {
        let EffectKind::FireVbaEvent {
            event_name,
            fact_source,
            arguments,
            cancel_metadata,
        } = &effect.kind
        else {
            return Err(VbaEventDispatchError::NotFireVbaEvent);
        };

        Ok(Self {
            dispatch_id,
            effect_id: effect.effect_id,
            target: effect.target.clone(),
            event_name: event_name.clone(),
            raise_member: raise_member_for_event(event_name)?,
            arguments: arguments.iter().map(VbaEventArgument::from).collect(),
            fact_source: fact_source.clone(),
            cancel_metadata: cancel_metadata.clone(),
        })
    }

    pub fn trace_row(&self, completion: VbaEventDispatchCompletion) -> VbaEventDispatchTraceRow {
        VbaEventDispatchTraceRow {
            dispatch_id: self.dispatch_id,
            effect_id: self.effect_id,
            target_form_id: self.target.form_id.as_ref().map(|id| id.0.clone()),
            target_control_id: self.target.control_id.as_ref().map(|id| id.0.clone()),
            event_name: self.event_name.clone(),
            raise_member: self.raise_member.clone(),
            argument_summary: self
                .arguments
                .iter()
                .map(|arg| {
                    let direction = if arg.by_ref {
                        "byref_or_mutable"
                    } else {
                        "byval"
                    };
                    format!("{}={}:{}", arg.name, arg.value, direction)
                })
                .collect(),
            fact_source: self.fact_source.clone(),
            cancel_metadata: self.cancel_metadata.clone(),
            completion,
        }
    }

    pub fn to_oxvba_variants(&self) -> Result<Vec<Variant>, VbaEventDispatchError> {
        Ok(vec![
            Variant::from_i32(self.dispatch_id as i32),
            Variant::from_string(self.target_label()),
            Variant::from_string(self.event_name.clone()),
            Variant::from_string(self.argument_log_text()),
        ])
    }

    pub fn target_label(&self) -> String {
        self.target
            .control_id
            .as_ref()
            .map(|id| id.0.clone())
            .or_else(|| self.target.form_id.as_ref().map(|id| id.0.clone()))
            .unwrap_or_else(|| "unknown-target".to_string())
    }

    pub fn argument_log_text(&self) -> String {
        if self.arguments.is_empty() {
            return "no arguments".to_string();
        }

        self.arguments
            .iter()
            .map(|arg| format!("{}={}", arg.name, arg.value))
            .collect::<Vec<_>>()
            .join(";")
    }

    pub fn to_event_specific_oxvba_variants(&self) -> Result<Vec<Variant>, VbaEventDispatchError> {
        match self.event_name.as_str() {
            "Click" | "Change" | "Activate" => Ok(Vec::new()),
            "MouseDown" | "MouseUp" | "MouseMove" => Ok(vec![
                Variant::from_i16(self.required_i16("Button")?),
                Variant::from_i16(self.required_i16("Shift")?),
                Variant::from_f32(self.required_f32("X")?),
                Variant::from_f32(self.required_f32("Y")?),
            ]),
            "KeyPress" => Ok(vec![Variant::from_i16(
                self.required_i16("key_ascii_placeholder")?,
            )]),
            "KeyDown" | "KeyUp" => Ok(vec![
                Variant::from_i16(self.key_code_i16()?),
                Variant::from_i16(self.required_i16("Shift")?),
            ]),
            other => Err(VbaEventDispatchError::UnsupportedEvent(other.to_string())),
        }
    }

    fn argument(&self, name: &'static str) -> Result<&VbaEventArgument, VbaEventDispatchError> {
        self.arguments
            .iter()
            .find(|arg| arg.name.eq_ignore_ascii_case(name))
            .ok_or_else(|| VbaEventDispatchError::MissingArgument {
                event_name: self.event_name.clone(),
                argument_name: name,
            })
    }

    fn required_i16(&self, name: &'static str) -> Result<i16, VbaEventDispatchError> {
        let arg = self.argument(name)?;
        arg.value
            .parse::<i16>()
            .map_err(|_| VbaEventDispatchError::InvalidArgument {
                event_name: self.event_name.clone(),
                argument_name: arg.name.clone(),
                value: arg.value.clone(),
                expected: "a 16-bit integer",
            })
    }

    fn required_f32(&self, name: &'static str) -> Result<f32, VbaEventDispatchError> {
        let arg = self.argument(name)?;
        arg.value
            .parse::<f32>()
            .map_err(|_| VbaEventDispatchError::InvalidArgument {
                event_name: self.event_name.clone(),
                argument_name: arg.name.clone(),
                value: arg.value.clone(),
                expected: "a single-precision number",
            })
    }

    fn key_code_i16(&self) -> Result<i16, VbaEventDispatchError> {
        let arg = self.argument("key")?;
        match arg.value.as_str() {
            "enter" => Ok(13),
            "escape" => Ok(27),
            "tab" => Ok(9),
            value if value.len() == 1 => Ok(value.as_bytes()[0] as i16),
            value if value.starts_with("character:") && value.len() == "character:".len() + 1 => {
                Ok(value.as_bytes()["character:".len()] as i16)
            }
            _ => Err(VbaEventDispatchError::InvalidArgument {
                event_name: self.event_name.clone(),
                argument_name: arg.name.clone(),
                value: arg.value.clone(),
                expected: "a W005 key summary with a scalar smoke mapping",
            }),
        }
    }
}

impl From<&EffectArgument> for VbaEventArgument {
    fn from(argument: &EffectArgument) -> Self {
        Self {
            name: argument.name.clone(),
            value: argument.value.clone(),
            by_ref: argument.by_ref,
        }
    }
}

fn raise_member_for_event(event_name: &str) -> Result<String, VbaEventDispatchError> {
    match event_name {
        "Click" | "Change" | "MouseDown" | "MouseUp" | "MouseMove" | "KeyPress" | "KeyDown"
        | "KeyUp" | "Activate" => Ok("RaiseDispatch".to_string()),
        other => Err(VbaEventDispatchError::UnsupportedEvent(other.to_string())),
    }
}
