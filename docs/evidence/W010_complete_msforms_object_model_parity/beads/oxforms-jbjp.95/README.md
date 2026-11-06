# FORMS PARITY: non-creating unload and held references

The headline stays **1,166 pass / 452 fail; 378 missing measurements**.
CalcVBA is pinned to `8840f391676d0796870e9c486ba2ca6586c5b8c7`.
No OxVba file is edited. The adapter consumes its non-creating default-instance
reset and explicit reference release/finalizer draining on the owning thread.

The private source-provider lifecycle callback resets the slot only when it
still denotes the unloading object. An explicit New form can unload with no
default present; a VM3 regression requires lookup to remain empty. No original
application procedure is rewritten and no public facade member is added.

[Native observations](native-release/observations.json) were captured in the
one hidden Excel, PID 22924, reused on its private desktop. The observer adds
Initialize/Terminate counters in memory and restores the original source in a
finally block. It never saves the workbook. The saved observer and instrumented
source are the exact input to the VM3 differential test.

Accepted Unload raises UserForm_Terminate immediately, even with held form
references; releasing those references must not raise it again. Separately held
TextBox Text can still be read and assigned without an error. All fourteen
recorded lines agree on VM3. Host reference replacement and runtime disposal
release while the session can still drain eligible object finalizers.

`.95` remains open for held-object reload, old-control events/detachment and
loaded-object final-reference release. Generic object refcounting alone does
not establish MSForms loaded-lifetime behavior. `.77` remains open as well.
The earlier eight-row lifetime, QueryClose veto and original handlers still pass.

Fresh review checked callback receiver/project identity, absence of public host
members, original-source restoration, reference replacement/disposal and repeat
termination suppression. Validation: 227 Rust tests pass (seven existing ignored),
fmt/clippy pass; all 95 ledger tests pass. The evidence suite's other 64 checks
pass; its stale expected-manifest pin was corrected and the ledger check rerun.
The canonical ledger stays red at 2,452 verified / 4,682 gaps / 621 unexpected
public rows. This step does not change the FORMS PARITY headline.
