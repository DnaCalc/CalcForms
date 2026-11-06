Status: Open
Target: CalcVBA (read-only sibling OxVba)
Ask: Provide a non-creating default-instance identity/reset operation or a canonical host form-lifecycle hook, and establish final-reference termination in cyclic control/event graphs.
Context: CalcForms now attaches the Windows host to the same compiler-owned predeclared singleton as original workbook entry code. VBA Unload can reset that singleton with Set FormName = Nothing after QueryClose permits it. Testing whether Me is FormName creates the default when only an explicit New form existed; no source-provider rewrite should silently change original procedure bodies to hide this.
Evidence: oxforms-jbjp.95; docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.77/; crates/calcforms-calcvba-adapter/tests/workbook_userform.rs. The original eight native lifetime rows and new private-desktop QueryClose veto now agree. Held references retain identity; precise released-control and last-reference Terminate behavior remain unproved.

2026-11-06 run 9: CalcVBA 8840f391 includes ce3b7085's `default_instances`,
`reset_if_same`, `release_class_instance` and `drain_object_terminations`.
CalcForms consumes these without sibling edits. The explicit-form Unload check
requires an absent default to remain absent. Fresh native observations establish
UserForm_Terminate during Unload despite held form/control references; CalcForms
now matches that loaded episode independently of Class_Terminate. Remaining
form/control graph and reload parity is CalcForms work until a reduced VM repro
proves otherwise. Earlier final-reference assumptions did not establish MSForms
Unload behavior and are superseded by the retained native observations.
