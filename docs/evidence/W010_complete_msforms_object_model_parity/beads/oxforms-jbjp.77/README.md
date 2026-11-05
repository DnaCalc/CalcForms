# Original workbook lifetime observations

Run 4 reused owned Excel PID 56892, without another launch. observer.bas runs
the existing greeter's original State/Change/Initialize code and records eight
rows in observations.json. Hide/Show preserves Lifetime text and default
instance identity. Unload then Load creates a fresh default, separate from
held references. Explicit New is separate and editing it leaves the default
unchanged. The original workbook bytes remain unchanged.

The first observer attempted state reads through unloaded control references
and hit an owned VBA error-91 dialog. Its short desktop lease released; the
dialog was ended under a new lease. The corrected observer explicitly loads
before reading state and omits the unsafe held-object state read. The exact
failing statement was not established; no general unloaded-object error
contract is inferred. No VBE error/security option was changed.

This is native evidence only. CalcForms standard-module/default-instance
integration, Show/Hide/Unload lifetime, QueryClose veto and full held-reference
behavior remain .77 work. User stopped Computer Use with physical Escape
before that implementation. The observer is durable non-production tooling;
its temporary module was discarded with the owned workbook/process close.
run4-cleanup.json records the exact retained-handle termination fallback after
Quit and unchanged workbook hash. Both owned Excel and runtime are gone.
