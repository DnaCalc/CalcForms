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

Run 4 stopped before runtime integration. The observer is durable non-production tooling;
its temporary module was discarded with the owned workbook/process close.
run4-cleanup.json records the exact retained-handle termination fallback after
Quit and unchanged workbook hash. Both owned Excel and runtime are gone.

Run 5 compiles the original standard modules and resolves the compiler's default
singleton for the host. The unchanged eight-row observer now matches on VM3.
The VBA source provider supplies per-instance initialization, modeless visibility,
Unload/default reset and QueryClose veto; the Windows host uses those decisions.
Code-behind Hide/Unload tests read the held object's lifetime without accidentally
creating its replacement. An original ShowGreeter entry shares the same instance.

`run5/` records new native Text/Value/SelText and QueryClose probes from one owned
Excel PID 53464 on private desktop CalcFormsOracle_341f737931a8 (2026-11-05).
No input desktop switch, owner input/focus, Computer Use, or security changes.
Programmatic changes raise Change; identical text and selection-only writes do
not. The private desktop supplies no Activate event merely because Show returns.
Both new native transcripts are compared byte-for-byte after newline normalization
by workbook_userform.rs, alongside the prior eight-row lifetime transcript.

Remaining `.95` work keeps `.77` open: comparing an explicit form with an absent
default during Unload can instantiate that default. Exact released-control,
held-reference reload and last-reference Terminate behavior is not established.
Modal pumps, arbitrary host modules, multiple windows and UserForms are open.
The source templates implement the form provider; probe drivers remain test-only.
