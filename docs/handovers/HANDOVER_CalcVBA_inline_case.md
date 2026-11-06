# CalcVBA: same-line Case statements

Tracked by oxforms-jbjp.117; observed with a4bf9792. No OxVba files changed.

The [native ListBox observer](../evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.112/native/observer.bas)
contains `Case "top": C.TopIndex = Value` and analogous index/height/clear
branches. Excel executes the selected statement. CalcVBA returned unchanged
index=1/top=0/count=23/height=72 with error=0 for every branch, including invalid
indices and Clear. The differential initially failed all affected observations.
Moving each statement after the Case colon onto its own line makes all 54
captured native observations pass (apart from the explicitly separate first
Show IntegralHeight adjustment). Reproduce a scalar assignment and a property
put after a Case label, then fix lowering/binding as appropriate. Keep native
transcripts unchanged; remove the separator-only workaround when taken up.
