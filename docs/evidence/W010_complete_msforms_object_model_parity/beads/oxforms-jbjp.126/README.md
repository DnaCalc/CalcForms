# Genuine planner workbook: 208 measured fields match

The saved Excel workbook adds SpinButton, ScrollBar, ToggleButton and TabStrip
to genuine-workbook coverage. Its original Initialize creates these controls;
the saved static Title, Summary and Close button use supported Office persistence.
Handlers update an appointment summary and record original application events.
VM3 imports the same workbook and requires the unchanged handler source.

Thirteen steps at each native scale compare all six business-state fields,
full cumulative Trace and error number: **208 pass / 0 fail, no missing fields**.
The scenarios cover spin/scroll value changes, repeated values, ToggleButton
Change then Click, tab changes, endpoint values and invalid public assignments.
Native error 380 for values above Max now also occurs in the runtime without
changing values or raising events (`.127`). Internal key/range stepping still
clamps. This proves these scenarios, not all control input or rendering.

The native setup observer uses FM20 Controls' default member. Runtime observation
uses explicit Item and an Object local; original workbook handlers are untouched.
Native Zoom/window setup is omitted from the runtime observer because the host
owns setup. The Boolean scenario explicitly uses CBool. The first observer's
numeric ToggleButton assignment produced an original-handler Null/error-94 dialog;
the historical observer and dialog remain, with coercion follow-up `.128`.

The bounded helper stopped at its deadline. Public MSAA invoked End on only that
recorded owned VBA dialog. A fresh helper then ran both scales in the same Excel
PID 22924, launch one. The workbook was not saved after adding observers.
Recovery used no owner input/focus, security change, registration or Office internals.
Fresh review checked original source, exact state/event/error coverage, repeated
value suppression, error-before-mutation and all retained diagnostic failures.
