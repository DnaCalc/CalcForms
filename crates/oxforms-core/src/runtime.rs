//! W007 runtime form materialization (oxforms-4pn.4).
//!
//! The first-class path from a canonical `.frm` into runtime state. The runtime
//! (effect runner, repaint, demo bootstrap) consumes a [`RuntimeForm`]; it never
//! hand-builds a control tree from the [`crate::controls`] constructors (those are
//! the `.frm` loader's building blocks and test scaffolds — see that module's note).
//!
//! A [`RuntimeForm`] carries both the reducer [`FormState`] (what the reducer routes
//! input over) and a [`RuntimeControlBinding`] per control (the stable identity and
//! geometry the runtime uses to dispatch events to, and sync properties with, the
//! matching VBA object-model control). The binding key is `control_id`, which equals
//! the control `name` — and that name is the VBA control's `Name`, so a reducer
//! `ControlId` and a VBA control resolve to the same control on both sides of the
//! boundary.
//!
//! This reuses the selected-`.frm` loader ([`crate::frm`]); it does not re-parse and
//! it inherits the loader's precise diagnostics (unsupported control types are
//! reported in [`RuntimeForm::unsupported`], `.frx` resource references in
//! [`RuntimeForm::frx_references`], and malformed/out-of-lane input is a
//! [`FrmLoadError`]). Unsupported `.frx` binary decode and full designer persistence
//! remain explicit non-claims.

use oxforms_pal::{ControlId, FormId, LogicalRect, LogicalSize};
use serde::{Deserialize, Serialize};

use crate::frm::{load_selected_frm_interaction_state, FrmControlRecord};
use crate::{ControlKind, FormState, FrmFrxReference, FrmLoadError, FrmUnsupportedRecord};

/// The canonical W007 demo form (the "greeter"): a `TextBox` (`InputField`), a
/// default `CommandButton` (`OkButton`), and a `Label` (`OutputLabel`). It is
/// materialized from this `.frm` rather than hand-constructed, and its control names
/// match the VBA object-model demo so the two sides bind by identity.
pub const W007_DEMO_FORM_FRM: &str =
    include_str!("../../../fixtures/frm/w007-demo/w007-greeter.frm");

/// A form materialized into first-class runtime state.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RuntimeForm {
    pub form_id: FormId,
    pub form_name: String,
    pub caption: String,
    pub surface: LogicalSize,
    /// The reducer state the input/effect pipeline operates on.
    pub state: FormState,
    /// Per-control binding metadata, in paint/declaration order, keyed by `control_id`.
    pub controls: Vec<RuntimeControlBinding>,
    /// `.frx` resource references detected but not decoded (binary decode is a non-claim).
    pub frx_references: Vec<FrmFrxReference>,
    /// Controls/properties outside the supported slice, reported rather than defaulted.
    pub unsupported: Vec<FrmUnsupportedRecord>,
    pub coordinate_model: String,
}

impl RuntimeForm {
    /// The binding for a control by its stable id (== name), if present.
    #[must_use]
    pub fn binding(&self, control_id: &ControlId) -> Option<&RuntimeControlBinding> {
        self.controls
            .iter()
            .find(|binding| &binding.control_id == control_id)
    }
}

/// The stable identity + geometry/flags the runtime needs to route events to and
/// sync properties with the matching VBA control. `control_id == ControlId(name)`,
/// and `name` is the VBA control's `Name`.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RuntimeControlBinding {
    pub control_id: ControlId,
    pub name: String,
    pub kind: ControlKind,
    pub caption: String,
    pub bounds_points: LogicalRect,
    pub tab_index: u32,
    pub tab_stop: bool,
    pub focusable: bool,
    pub visible: bool,
    pub enabled: bool,
    pub default: bool,
    pub cancel: bool,
    /// Initial editable text (TextBox), if any. Empty/None means an empty field.
    pub initial_text: Option<String>,
    /// MSForms event names this control raises into VBA code-behind.
    pub event_names: Vec<String>,
}

impl RuntimeControlBinding {
    fn from_record(record: &FrmControlRecord, event_names: Vec<String>) -> Self {
        Self {
            control_id: ControlId::new(record.name.clone()),
            name: record.name.clone(),
            kind: record.kind,
            caption: record.caption.clone(),
            bounds_points: record.bounds_points,
            tab_index: record.tab_index,
            tab_stop: record.tab_stop,
            focusable: record.focusable,
            visible: record.visible,
            enabled: record.enabled,
            default: record.default,
            cancel: record.cancel,
            initial_text: record.initial_text.clone(),
            event_names,
        }
    }
}

/// Materialize a selected `.frm` source into first-class runtime state. This is the
/// production path; runtime code calls this (or a wrapper like
/// [`materialize_w007_demo_form`]) instead of hand-building a control tree.
pub fn materialize_form_from_frm(source: &str) -> Result<RuntimeForm, FrmLoadError> {
    let model = load_selected_frm_interaction_state(source)?;

    let controls = model
        .controls
        .iter()
        .map(|record| {
            let control_id = ControlId::new(record.name.clone());
            let event_names = model
                .event_hooks
                .iter()
                .find(|hooks| hooks.control_id == control_id)
                .map(|hooks| hooks.event_names.clone())
                .unwrap_or_default();
            RuntimeControlBinding::from_record(record, event_names)
        })
        .collect();

    Ok(RuntimeForm {
        form_id: model.state.form_id.clone(),
        form_name: model.form_name,
        caption: model.caption,
        surface: model.surface,
        controls,
        state: model.state,
        frx_references: model.frx_references,
        unsupported: model.unsupported,
        coordinate_model: model.coordinate_model,
    })
}

/// Materialize the bundled W007 demo greeter form into runtime state.
pub fn materialize_w007_demo_form() -> Result<RuntimeForm, FrmLoadError> {
    materialize_form_from_frm(W007_DEMO_FORM_FRM)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{reduce, EffectKind, FocusTarget};
    use oxforms_pal::{
        ClickCount, CoordinatePayload, FocusValidationCompletedEvent, KeyCode, KeyEvent, KeyRepeat,
        KeyboardModifiers, LogicalPoint, MouseButton, MouseButtonEvent, MouseButtons, PointerId,
        RawKeyDiagnostics, UiEvent, UiEventId, UiEventKind, UiEventSource,
    };

    /// The control names the VBA object-model demo uses; the materialized reducer
    /// identities must match these exactly so dispatch/property-sync line up.
    const DEMO_CONTROL_NAMES: [&str; 3] = ["InputField", "OkButton", "OutputLabel"];

    #[test]
    fn demo_form_materializes_with_stable_ids_and_geometry() {
        let form = materialize_w007_demo_form().expect("W007 demo form should materialize");

        assert_eq!(form.form_name, "OxFormsW007GreeterForm");
        assert_eq!(form.caption, "Greeter");
        assert_eq!(form.surface, LogicalSize::new(200.0, 120.0));
        assert!(form.frx_references.is_empty(), "demo form has no .frx");
        assert!(
            form.unsupported.is_empty(),
            "every demo control is supported"
        );
        assert_eq!(form.coordinate_model, crate::COORDINATE_MODEL_SPEC_PATH);

        // Three controls, in declaration order, with the expected kinds + geometry
        // (twips -> points per the coordinate model).
        let shapes: Vec<(&str, ControlKind, LogicalRect)> = form
            .controls
            .iter()
            .map(|b| (b.name.as_str(), b.kind, b.bounds_points))
            .collect();
        assert_eq!(
            shapes,
            vec![
                (
                    "InputField",
                    ControlKind::TextBox,
                    LogicalRect::new(12.0, 12.0, 120.0, 18.0)
                ),
                (
                    "OkButton",
                    ControlKind::CommandButton,
                    LogicalRect::new(140.0, 12.0, 48.0, 20.0)
                ),
                (
                    "OutputLabel",
                    ControlKind::Label,
                    LogicalRect::new(12.0, 44.0, 176.0, 18.0)
                ),
            ]
        );

        assert_eq!(form.controls[1].caption, "OK");
        assert_eq!(form.controls[2].caption, "(idle)");
        // The greeter starts with an empty input field.
        assert_eq!(form.state.text_boxes.len(), 1);
        assert_eq!(form.state.text_boxes[0].text, "");
    }

    #[test]
    fn demo_binding_identities_match_the_vba_control_names() {
        let form = materialize_w007_demo_form().expect("materialize");

        // Binding ids == names == the VBA object-model control names, and the reducer
        // FormState carries the same ids in the same order. This is the identity
        // contract the runtime relies on to dispatch events to / sync properties with
        // the VBA controls.
        let binding_ids: Vec<ControlId> =
            form.controls.iter().map(|b| b.control_id.clone()).collect();
        let state_ids: Vec<ControlId> = form
            .state
            .controls
            .iter()
            .map(|c| c.control_id.clone())
            .collect();
        let expected_ids: Vec<ControlId> = DEMO_CONTROL_NAMES
            .iter()
            .map(|name| ControlId::new(*name))
            .collect();

        assert_eq!(binding_ids, expected_ids);
        assert_eq!(state_ids, expected_ids);
        for binding in &form.controls {
            assert_eq!(binding.control_id, ControlId::new(binding.name.clone()));
            assert!(
                form.binding(&binding.control_id).is_some(),
                "binding is resolvable by its id"
            );
        }

        // OkButton is the default button; the greeter has no cancel button.
        assert_eq!(form.state.default_button, Some(ControlId::new("OkButton")));
        assert_eq!(form.state.cancel_button, None);

        // The per-control binding surface (what the runtime pushes/pulls to VBA) agrees
        // with the reducer state and the routing contract.
        let ok = form
            .binding(&ControlId::new("OkButton"))
            .expect("OkButton binding");
        assert!(ok.default, "OkButton binding is the form default");
        assert!(!ok.cancel);
        assert!(
            ok.event_names.iter().any(|e| e == "Click"),
            "OkButton binding raises Click (the event the routing test dispatches)"
        );

        let input = form
            .binding(&ControlId::new("InputField"))
            .expect("InputField binding");
        assert!(input.focusable && input.kind == ControlKind::TextBox);
        assert!(input.event_names.iter().any(|e| e == "Change"));

        // The label is a non-button, non-default, and never carries a default flag.
        let label = form
            .binding(&ControlId::new("OutputLabel"))
            .expect("OutputLabel binding");
        assert!(!label.default && !label.cancel && !label.focusable);
    }

    #[test]
    fn materialized_demo_state_feeds_interaction_routing() {
        let form = materialize_w007_demo_form().expect("materialize");

        // A click inside the InputField bounds focuses it by its materialized id.
        let focused = reduce(
            form.state,
            UiEvent::new(
                UiEventId(1),
                UiEventSource::Replay,
                UiEventKind::MouseDown(mouse_down_at(20.0, 18.0)),
            ),
        );
        assert_eq!(
            focused.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("InputField")))
        );

        // A default-button Enter transfers focus to OkButton: Exit fires on InputField and
        // the commit (and the button Click) is held pending the veto (oxforms-esq.6 on the
        // esq.4 deferred-focus model).
        let entered = reduce(
            focused.state,
            UiEvent::new(
                UiEventId(2),
                UiEventSource::Replay,
                UiEventKind::KeyDown(key_event(KeyCode::Enter)),
            ),
        );
        assert!(
            entered.effects.iter().any(|effect| matches!(
                &effect.kind,
                EffectKind::FireVbaEvent { event_name, .. } if event_name == "Exit"
            )),
            "Enter begins a focus transfer with Exit on the focused control"
        );

        // The uncancelled completion commits focus to OkButton and fires its Click.
        let completion = UiEvent::new(
            UiEventId(3),
            UiEventSource::Service,
            UiEventKind::FocusValidationCompleted(FocusValidationCompletedEvent {
                form_id: entered.state.form_id.clone(),
                cancelled: false,
                dispatch_diagnostics: Vec::new(),
            }),
        );
        let committed = reduce(entered.state, completion);
        assert!(
            committed.effects.iter().any(|effect| matches!(
                &effect.kind,
                EffectKind::FireVbaEvent { event_name, .. } if event_name == "Click"
            ) && effect.target.control_id
                == Some(ControlId::new("OkButton"))),
            "the committed default-button Enter fires Click on OkButton"
        );
    }

    #[test]
    fn unsupported_control_is_reported_not_defaulted() {
        // A W007-shaped form with a control outside the supported slice: the
        // supported controls still materialize and the unknown one is reported.
        let source = r#"
VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} OxFormsW007UnsupportedProbe
   ClientWidth = 4000
   ClientHeight = 2400
   Begin MSForms.Label OutputLabel
      Caption = "ok"
      Left = 240
      Top = 240
      Width = 2400
      Height = 360
   End
   Begin MSForms.ComboBox Picker
      Left = 240
      Top = 880
      Width = 2400
      Height = 360
   End
End
"#;
        let form = materialize_form_from_frm(source).expect("supported subset still materializes");
        assert_eq!(form.controls.len(), 1);
        assert_eq!(form.controls[0].name, "OutputLabel");
        assert_eq!(form.unsupported.len(), 1);
        assert_eq!(form.unsupported[0].owner_name, "Picker");
        assert!(form.unsupported[0]
            .type_name
            .to_lowercase()
            .contains("combobox"));
    }

    #[test]
    fn frx_reference_is_detected_not_decoded() {
        let source = r#"
VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} OxFormsW007FrxProbe
   ClientWidth = 4000
   ClientHeight = 2400
   Begin MSForms.Label OutputLabel
      Caption = "has picture"
      Left = 240
      Top = 240
      Width = 2400
      Height = 360
      Picture = "OxFormsW007FrxProbe.frx":0000
   End
End
"#;
        let form = materialize_form_from_frm(source).expect("frx reference must not crash");
        assert_eq!(form.frx_references.len(), 1);
        assert_eq!(form.frx_references[0].property_name, "Picture");
    }

    #[test]
    fn duplicate_control_name_is_a_precise_diagnostic() {
        // The binding key is the control name; a duplicate would silently shadow a
        // control, so it must be a hard error rather than a first-wins mis-bind.
        let source = r#"
VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} OxFormsW007DuplicateProbe
   ClientWidth = 4000
   ClientHeight = 2400
   Begin MSForms.Label OutputLabel
      Caption = "first"
      Left = 240
      Top = 240
      Width = 2400
      Height = 360
   End
   Begin MSForms.TextBox OutputLabel
      Left = 240
      Top = 880
      Width = 2400
      Height = 360
   End
End
"#;
        let err =
            materialize_form_from_frm(source).expect_err("duplicate control name must be rejected");
        assert!(
            err.message.contains("duplicate control name 'OutputLabel'"),
            "got: {}",
            err.message
        );
        // Points at the duplicate control's declaration (its Begin line).
        assert_eq!(err.line, Some(13));
    }

    #[test]
    fn malformed_geometry_is_a_precise_diagnostic_not_a_silent_zero() {
        // A present-but-unparseable geometry value must not silently collapse to 0.
        let source = r#"
VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} OxFormsW007BadGeometryProbe
   ClientWidth = 4000
   ClientHeight = 2400
   Begin MSForms.TextBox InputField
      Left = oops
      Top = 240
      Width = 2400
      Height = 360
   End
End
"#;
        let err =
            materialize_form_from_frm(source).expect_err("malformed geometry must be rejected");
        assert!(
            err.message
                .contains("property 'Left' is not a valid integer"),
            "got: {}",
            err.message
        );
        // Points at the offending control's declaration (its Begin line).
        assert_eq!(err.line, Some(6));
    }

    #[test]
    fn out_of_lane_property_error_propagates_through_materialize() {
        // A precise loader diagnostic must survive the runtime materialization boundary.
        let source = r#"
VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} OxFormsW007BadBoolProbe
   ClientWidth = 4000
   ClientHeight = 2400
   Begin MSForms.CheckBox Agree
      Value = 2
      Left = 240
      Top = 240
      Width = 2400
      Height = 360
   End
End
"#;
        let err = materialize_form_from_frm(source)
            .expect_err("out-of-lane property must surface a diagnostic");
        assert!(
            err.message.contains("is not a VB6 boolean"),
            "got: {}",
            err.message
        );
        // Points at the offending control's declaration (its Begin line).
        assert_eq!(err.line, Some(6));
    }

    #[test]
    fn negative_tab_index_is_a_precise_diagnostic() {
        let source = r#"
VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} OxFormsW007BadTabIndexProbe
   ClientWidth = 4000
   ClientHeight = 2400
   Begin MSForms.TextBox InputField
      TabIndex = -1
      Left = 240
      Top = 240
      Width = 2400
      Height = 360
   End
End
"#;
        let err =
            materialize_form_from_frm(source).expect_err("a negative TabIndex must be rejected");
        assert!(
            err.message.contains("TabIndex must be non-negative"),
            "got: {}",
            err.message
        );
        assert_eq!(err.line, Some(6));
    }

    #[test]
    fn default_cancel_on_a_non_button_are_dropped_not_errored() {
        // Default/Cancel are CommandButton-only; on a non-button they are silently
        // inapplicable (loads fine) and must never set the form default/cancel — the
        // binding flags stay false and state.default_button/cancel_button stay None.
        let source = r#"
VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} OxFormsW007NonButtonDefaultProbe
   ClientWidth = 4000
   ClientHeight = 2400
   Begin MSForms.Label OutputLabel
      Caption = "label"
      Default = -1
      Cancel = -1
      Left = 240
      Top = 240
      Width = 2400
      Height = 360
   End
   Begin MSForms.CommandButton OkButton
      Caption = "OK"
      Default = -1
      Left = 2800
      Top = 240
      Width = 960
      Height = 400
   End
End
"#;
        let form =
            materialize_form_from_frm(source).expect("non-button Default/Cancel still loads");

        let label = form
            .binding(&ControlId::new("OutputLabel"))
            .expect("label binding");
        assert!(
            !label.default && !label.cancel,
            "Default/Cancel are gated to CommandButton, so the label carries neither"
        );

        // The real CommandButton still becomes the form default; the label never does.
        assert_eq!(form.state.default_button, Some(ControlId::new("OkButton")));
        assert_eq!(form.state.cancel_button, None);
        let ok = form
            .binding(&ControlId::new("OkButton"))
            .expect("button binding");
        assert!(ok.default && !ok.cancel);
    }

    fn mouse_down_at(x: f64, y: f64) -> MouseButtonEvent {
        MouseButtonEvent {
            pointer_id: Some(PointerId(1)),
            button: MouseButton::Left,
            buttons_down: MouseButtons {
                left: true,
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
