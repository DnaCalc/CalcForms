Status: Open
Target: CalcVBA
Ask: Keep a project/interface receiver's static type through property and function results.

On pinned a4bf9792, the production `UserForm.MeasureControls` chain
`Control.Core.MeasureTextCount` raises 438 naming `MeasureTextCount`. `Control` is
`IOxControl`; `Core` returns `OxControlCore`; `MeasureTextCount` is a same-project
Friend property. Assigning `Control.Core` to `Dim Core As OxControlCore` first
executes correctly without changing visibility.

Similarly, `mForm.ControlByName(NewName).OnEnter` raises 438 naming the private
`ioxcontrol_OnEnter` implementation. `ControlByName` returns `IOxControl`; assigning
that result to a typed `IOxControl` local before calling `OnEnter` executes correctly.
The VM3 dispatch change selects public-only dispatch when the temporary receiver
loses its project/interface type. That explanation is an inference from the
public DNA source and the two runtime failures, not an Office implementation claim.

The library now uses explicit typed locals in these paths. The pinned native
setter/key scenarios and real workbook handlers then pass again. Preserve this
bounded take-up and the independent external typed/Object/CallByName Friend
rejection tests. Do not broaden visibility to make chained calls work.

Evidence: `.75` take-up; `measured_behaviour.rs` originally failed during Render
and key routing with the literal errors above. No sibling file was changed.
