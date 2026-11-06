# Private unload event identity

`.95.1` corrects a fresh-review defect in the host event sink. Receiver/project
identity and a qualified form-name argument were insufficient: an application's
own event could use that same argument. The adapter now obtains the private
generated event's ordinal from CalcVBA's resolved module symbols. All events,
including private events, contribute to the compiler's source-order event ids.
The sink requires that id as well as the exact receiver/project and payload.

The required workbook regression adds a preceding public application event,
raises it with the identical qualified form-name argument, and requires the
existing default slot to survive. The real private unload event still clears
the slot at its shifted ordinal. All thirteen workbook UserForm tests pass.
Fresh review checked source-order resolution, project scope, public-event
collision, non-creating reset and retained original lifecycle differentials.
No native Office result is inferred from this host-integrity regression.

CalcVBA remains pinned to `8840f391`; no sibling repository was edited.
