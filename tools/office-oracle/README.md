# Office Oracle Harness Tools

This directory is reserved for W003 tooling that observes real
Excel/MSForms behavior as a black-box oracle.

The tools here are not OxForms runtime APIs, adapter APIs, or compatibility
bridges. They are local harness utilities for generating, opening, capturing,
or checking Office oracle fixtures and their evidence artifacts.

Current scaffold:

- `Test-OfficeOracleScaffold.ps1` checks that the W003 fixture, tool, capture,
  and comparison directories exist. It does not start Excel, automate Office,
  capture screenshots, or create a UserForm fixture.

Future W003 beads should keep Office-specific commands explicit and local:

- `oxforms-fg9.2` may add Windows discovery/capture primitives here or in a
  dedicated buildable crate if Rust code becomes necessary.
- `oxforms-fg9.4` should add repo-owned Excel/VBA fixture inputs under
  `fixtures/office-oracle/excel-msforms/`.
- `oxforms-fg9.5` should write generated capture artifacts under
  `docs/evidence/W003_excel_forms_oracle_capture/captures/`.

Local Office prerequisites, when a future command actually uses Excel:

- Microsoft Excel installed on the Windows host.
- Macro/VBA project access policy configured enough to open or generate the
  repo-owned fixture.
- A desktop session where the UserForm can be shown and captured.

Non-Office scaffold checks must not require those prerequisites.
