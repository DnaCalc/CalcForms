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
    DispatchIdOutOfRange(u64),
}

impl std::fmt::Display for VbaEventDispatchError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotFireVbaEvent => write!(f, "effect is not a FireVbaEvent request"),
            Self::UnsupportedEvent(event_name) => {
                write!(f, "W005 smoke does not map event `{event_name}`")
            }
            Self::DispatchIdOutOfRange(dispatch_id) => write!(
                f,
                "dispatch id {dispatch_id} does not fit the W005 VBA Long smoke carrier"
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
        let dispatch_id = i32::try_from(self.dispatch_id)
            .map_err(|_| VbaEventDispatchError::DispatchIdOutOfRange(self.dispatch_id))?;

        Ok(vec![
            Variant::from_i32(dispatch_id),
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
        | "KeyUp" | "Activate" | "Exit" => Ok("RaiseDispatch".to_string()),
        other => Err(VbaEventDispatchError::UnsupportedEvent(other.to_string())),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn request_with_dispatch_id(dispatch_id: u64) -> VbaEventDispatchRequest {
        VbaEventDispatchRequest {
            dispatch_id,
            effect_id: EffectId(1),
            target: UiEventTarget::control("form-main", "ok"),
            event_name: "Click".to_string(),
            raise_member: "RaiseDispatch".to_string(),
            arguments: Vec::new(),
            fact_source: None,
            cancel_metadata: None,
        }
    }

    #[test]
    fn to_oxvba_variants_accepts_largest_vba_long_dispatch_id() {
        let request = request_with_dispatch_id(i32::MAX as u64);
        let variants = request
            .to_oxvba_variants()
            .expect("i32::MAX fits the VBA Long smoke carrier");

        assert_eq!(variants[0].as_i32(), Some(i32::MAX));
    }

    #[test]
    fn to_oxvba_variants_rejects_dispatch_id_that_cannot_fit_vba_long() {
        let overflowing_id = i32::MAX as u64 + 1;
        let request = request_with_dispatch_id(overflowing_id);

        assert_eq!(
            request.to_oxvba_variants(),
            Err(VbaEventDispatchError::DispatchIdOutOfRange(overflowing_id))
        );
    }
}
