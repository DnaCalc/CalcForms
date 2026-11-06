# FORMS PARITY: 1,191 pass / 427 fail; 356 missing measurements

The genuine saved greeter now supplies 22 previously missing observations:
application event order and value changes for all five controls, and InputName
selection at both scales. The caption setters explicitly observe no application
events. Text replacement records Change, selected text and exact caret position;
repeated True records no second checkbox event. MSAA invokes the native button.
VM3 uses the original imported handlers and real reducer button input.

All sixteen native before/after state, value, event and selection rows match.
The required Rust differential compares every saved field against each native
scale. `greeter_setter_reference.py` regenerates the new report from the complete
native/runtime artifacts and the hash-pinned `.101` report. All earlier images,
observations and 427 remaining failures are retained. No pixel threshold changes.

Fresh review checked that this is original application-event coverage, rather
than every FM20 event; missing fields outside this scenario receive no credit.
Original workbook bytes and handler source are unchanged. Native observation
reused hidden Excel PID 22924, launch one, with no owner input or focus change.
The relevant Rust test, Clippy, formatting and evidence replay are green; the
existing 66-check evidence suite also passed before this additional check.
