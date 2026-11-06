# FORMS PARITY: Escape focus and pending edit rollback

The genuine inventory form now matches **all 320 State, Trace and focus fields**
at both native scales. The `.119` reports preserve the former four focus failures.
No original saved workbook handler or byte is changed.

Five additional scenarios at each scale qualify clean Submit/TextBox focus,
dirty text, a BeforeUpdate veto, and an Exit veto. Escape restores the pending
TextBox edit and raises Change before Exit. An accepted Exit is followed by
Cancel.Enter and Cancel.Click; an Exit veto retains the old control and suppresses
Click. BeforeUpdate does not run again after rollback. Hide/Show retains Cancel
focus. Required VM3 comparisons assert focus, text, visibility, full application
Trace and the ordered Escape event delta, with no skipped State/focus fields.

The observer queues messages inside the owned Excel thread on its private
desktop. It uses the form object model for setup and never sends system input
or takes owner focus. The read-only workbook is closed without saving. Its
instrumented source, input helper, observations and runtime replay are retained.

Native setup can emit BeforeUpdate/AfterUpdate after programmatic Text, Show and
redundant SetFocus. The runtime setup lacks that observer prefix. Both before
logs remain visible; `.124` owns isolating that discrepancy. Escape comparison
starts from the saved before state and requires the exact subsequent event delta.
This does not claim arbitrary TextBox editing or all-control keyboard parity.

Fresh review checked swallowed-key routing, rollback Change ordering, Exit veto,
same-focus avoidance, retained Hide/Show focus, full original Trace and the
unchanged `.119` failures. Broader workbook/input coverage remains `.105/.105.1`.
