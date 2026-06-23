# W006 Runtime Accessibility Semantics

Status: design-only evidence note for `oxforms-0a0.7`.

## Decision

W006 continues to make no runtime accessibility claim. OxForms does not yet
expose a UI Automation provider, an MSAA provider, or assistive-technology
semantics for its controls.

The design home is
[`../../specs/RUNTIME_ACCESSIBILITY_MODEL.md`](../../specs/RUNTIME_ACCESSIBILITY_MODEL.md).
It gates future implementation on an explicit product requirement, scoped
control subset, provider boundary, and runtime-specific tests/evidence.

## Evidence Read

Reviewed sources:

- `CHARTER.md` scope, compatibility, clean-room, and success criteria;
- [`../W005_input_interaction_model_exploration/windows-automation-inspection.md`](../W005_input_interaction_model_exploration/windows-automation-inspection.md);
- [`../../worksets/W005_input_interaction_model_exploration.md`](../../worksets/W005_input_interaction_model_exploration.md)
  section 14, Programmatic Driving And Inspection;
- [`../../worksets/W006_control_implementation_rollout.md`](../../worksets/W006_control_implementation_rollout.md);
- `tools/W005AccessibilityMetadataProbe.ps1`.

Repository scans found the W005 probe script but no committed UIA/MSAA metadata
probe output artifacts under `docs/evidence/`. The probe self-check was run on
2026-06-23 and returned schema
`oxforms.w005.accessibility_metadata_probe.self_check.v1` with status `ok`; its
own non-claims state that the self-check does not enumerate, inspect, or
automate any live window and does not validate MSForms or OxForms behavior.

## Boundary

W005 diagnostics may record top-level Win32 window metadata and bounded UIA
discoverability for already-open oracle or smoke windows. That metadata remains
public diagnostics only.

Runtime accessibility semantics, if implemented later, must be derived from
OxForms control definitions, reducer-owned `FormState`, layout/coordinate state,
and adapter-owned provider mappings. Screenshots, top-level windows, UIA child
counts, control types, supported patterns, and foreground/focus diagnostics are
not control semantics and are not FM20 behavior truth.

## Follow-up Policy

No residual bead is created by `oxforms-0a0.7` because no product requirement
currently asks for runtime accessibility implementation. If such a requirement
appears, create a focused W006 or later-workset bead that cites
`RUNTIME_ACCESSIBILITY_MODEL.md`, names the provider target and control subset,
and requires semantic snapshot tests plus public UIA/MSAA provider evidence
before making any accessibility claim.
