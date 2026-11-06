# FORMS PARITY: ListBox viewport and initial Show focus

**1,126 pass / 492 fail; 418 missing measurements.** The [replay](forms-parity.md)
preserves prior window captures and replaces only runtime behavior transcripts.
The retained native overflow transcript now requires ListIndex 1/7/13/0 and
TopIndex 0/1/7/0 after initial/PageDown/PageDown/Home at both scales. The full
transcript is asserted; the former top_error=438 allowance has been removed.
Painting, focus rectangles and row hit testing share the absolute TopIndex.
Keyboard pages use full visible rows minus one; public scrolling includes the
partially visible final row. Wheel/drag behavior remains unmeasured.

[native/observations.json](native/observations.json) retains 54 independent public
property observations from the existing hidden Excel PID 68232 (one launch).
They cover negative/large TopIndex, invalid ListIndex error 380, empty-list
E_FAIL, clear, shrink/expand and repeated offscreen assignments. Same-index
assignment retains the viewport. The first native Show adjusts Height from 72
to 71.25; this IntegralHeight discrepancy remains open as `.118` and is excluded only
from the initial height comparison. All other boundary fields are required.

The [Show capture](../oxforms-jbjp.105.1/show-focus/observations.json) records
NameInput initially, appending dynamic controls after the five designer sites,
and TeamChoice after Hide/Show. Runtime Add now appends TabIndex. The FRM
materializer still restores the persisted omitted default TabIndex=0.
Show asks the reducer to establish its first eligible focus once; no physical
keyboard, pointer or owner focus is used. The original order-entry test now
asserts NameInput and immediately presses Enter without its former extra Tab.
All ten original State/Trace outcomes remain required. Broader .105.1 work stays open.

CalcVBA a4bf9792 silently drops statements after same-line Case labels in the
saved native observer. The Rust differential expands those separators only;
property calls and expected native values remain unchanged. Upstream ask:
[oxforms-jbjp.117](../../../../handovers/HANDOVER_CalcVBA_inline_case.md).

Fresh review checked viewport/selection independence, same-value quietness,
empty and resize paths, paint/hit agreement and preservation of native errors.
Pixels remain a coarse check; this is not full ListBox or focus parity.

Validation: 222 Rust tests pass, seven existing ignored; fmt/clippy and all 55
oracle unit tests pass. All 63 evidence checks pass after refreshing source pins
and repairing exact-process cleanup; neither the containment deadline nor any
required check was weakened. Canonical W010 remains 2,452 verified / 4,682 gaps /
621 unexpected-public rows, green=false, with 839 source declarations.
