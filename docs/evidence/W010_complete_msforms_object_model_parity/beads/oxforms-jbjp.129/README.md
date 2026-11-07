# FORMS PARITY: 1,201 pass / 417 fail; 346 missing measurements

Ten greeter lifecycle unknowns now use six stages at both native scales:
modified, hidden, shown, unloaded with held controls, fresh default, and old
controls after replacement. All twelve complete rows match VM3. Each row retains
every control's member/value/error and the loaded form's visible/application
state. Original workbook handlers and bytes remain unchanged.

The qualified observation executes entirely inside Excel VBA with typed held
controls. A separate native COM readback probe initially found catastrophic
errors from old marshalled wrappers after reload. An independent in-process
probe establishes that VBA-held controls still read successfully. Both call
shapes and all errors are retained; COM wrapper expiry earns no VBA failure or
pass credit. Old-control event routing and held-form reload remain `.95` work.

Eighteen historical behavior/input/keyboard scenarios were also re-executed
against current production code without Office. Runtime source adaptation adds
only the previously corrected unused indexed mouse parameters. Independent
native scenarios, images and measurements stay unchanged. The new report gains
ten lifecycle rows and has zero regressions against `.125`; all 417 failures
stay visible. The earlier font report retains its 17 gains and 14 regressions.

`greeter_lifecycle_reference.py` regenerates the report from pinned native,
runtime, source and baseline inputs, and checks every earlier native fact.
Fresh review checked typed-reference readback, error observations, old/new values,
complete application state, source adaptation and row/gain accounting.
No full control lifetime, COM-wrapper compatibility or full forms parity follows.
