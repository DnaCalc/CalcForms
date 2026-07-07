# W009 Final Ideal-Architecture Review

Status: `oxforms-zhz.33`
Date: 2026-07-07

This review closes the phase-0 ideal-architecture rework graph and rewrites the
broad intrinsic-control lanes from the representative implementation now in the
repo.

## Canonical Runtime Path

The representative controls use one runtime path:

```text
Windows/headless input
  -> RuntimeInput / OxRuntime::dispatch_event_turn
  -> VBA form facade / OxReducer
  -> OxInteractionManager and concrete IOxControl objects
  -> VBA self-render through OxForms.Surface
  -> retained Scene / backend repaint
```

The broad-control lanes must keep VBA object state authoritative for MSForms
properties, methods, and event order. Rust remains the host/service/surface and
primitive backend, not a second control object model.

## Scaffold Review

No live `crates/oxforms-core` runtime remains in the current build graph. The
remaining `oxforms-core` references found by review are historical W005/W006/W007
evidence notes, frozen trace artifacts, or old capture command logs; they are not
compiled runtime code.

The low-level W002 `OxForms.SmokeCanvas` path remains quarantined as W002
rectangle-smoke infrastructure. The W009 showcase and materialized `.frm` paths
attach through `OxRuntime`, the real VBA reducer, and `OxForms.Surface`.

The full-surface showcase is now the living conformance dashboard. Future control
lanes must move rows from pending to supported there and prove the dashboard
through the adapter/headless path.

## Review Findings

1. The representative architecture is coherent enough for broad control work:
   `TextBox`, `CheckBox`, `ToggleButton`, `ListBox`, `Frame`, `Image`, and `SpinButton` exercise
   the service seams, interaction manager, object model, accessibility snapshot,
   materializer, renderer vocabulary, performance harness, and dashboard.
2. The major remaining architectural hazard is not another control abstraction;
   it is scaled hit-testing. `oxforms-bqr` is therefore a dependency of the new
   broad control lanes.
3. TextService v2 and Windows accessibility-provider work are real follow-ups,
   but they do not block the first broad-control lanes because the current
   single-line TextBox and host-neutral accessibility snapshot are already
   explicitly bounded.
4. Visible desktop showcase inspection remains blocked in this environment by
   Computer Use `get_window_state`: `GetCursorPos failed: Access is denied.
   (0x80070005)`. Headless and adapter conformance are green; visible evidence
   should be retried once the Windows automation helper can capture the window.

## Live Broad-Lane Graph

`oxforms-zhz.33` created the post-foundation control beads:

| Bead | Scope |
|---|---|
| `oxforms-zhz.39` | ToggleButton intrinsic lane |
| `oxforms-zhz.40` | OptionButton intrinsic lane with grouping |
| `oxforms-zhz.41` | ListBox full selection and columns lane |
| `oxforms-zhz.42` | ComboBox intrinsic lane with dropdown |
| `oxforms-zhz.43` | Image full Picture and decoded-pixel lane |
| `oxforms-zhz.44` | SpinButton full range and repeat lane |
| `oxforms-zhz.45` | ScrollBar intrinsic lane |
| `oxforms-zhz.46` | Frame full container parity lane |
| `oxforms-zhz.47` | TabStrip intrinsic lane |
| `oxforms-zhz.48` | MultiPage/Page intrinsic lane |
| `oxforms-zhz.49` | Intrinsic completeness and fact-pack closure |

Each implementation lane depends on `oxforms-zhz.33` and `oxforms-bqr`. The
completeness bead depends on every implementation lane.
