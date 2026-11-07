# Show after default-instance replacement

`.95.2` corrects host Show after an accepted Unload. Ordinary runtime calls
resolved the compiler-owned default, but Show used its old held object. The
order-entry native comparison exposed fresh State/Trace followed by empty focus.
Show now uses the same default-reference refresh as ordinary calls and releases
the previous host-held reference before showing the replacement.

The required original-workbook differential covers edited-name BeforeUpdate
veto, accepted Tab, Escape, retained Hide/Show and fresh unload/reload. Every
state, event trace and focus field agrees at both native scales (308 fields).
The new greeter differential also checks held controls before and after default
replacement. These are precise additions to `.95`; held-form reload, old-control
events and loaded-object final-reference release remain open.

Fresh review checked resolver ownership, no default creation during window-close
readback, release timing, Show's public member name, fresh initial focus and the
existing QueryClose/lifecycle/visibility tests. CalcVBA remains `8840f391`.
