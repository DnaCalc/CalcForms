# OxVba request: MSForms cross-project defaults and internal visibility

Owner in OxForms: `oxforms-o0fp`; blocks `oxforms-jbjp.6`.
Observed 2026-09-21 on pinned OxVba
`8f1aeccc683c4d41621bf137574b8a4d11bd9845`.

The compatibility target is unchanged VBA source referencing MSForms, with
OxForms supplying the library implementation. The facade must preserve default
members and expose no runtime implementation hooks.

Reproduce in OxForms:

```powershell
cargo test -p oxforms-oxvba-adapter --test oxvba_w010_facade_contract -- --nocapture
```

The fixture creates separate `MSForms` and `UnchangedClient` manifests, binds
with `bind_projects`, elaborates both, links an `OxImage` and invokes the
client. Explicit qualified members and Let/Set identity work. The two tests
named `discrepancy_*` deliberately assert current failing behavior; their
passing result is diagnostic, not an acceptance pass.

## D006-01: qualified referenced scalar default member

Fixture `MSForms.Label.Caption` is a String Property Get/Let marked
`Attribute Caption.VB_UserMemId = 0`. Client:

```vb
Dim label As MSForms.Label
Set label = New MSForms.Label
label.Caption = "unchanged"
Dim text As String
text = label
```

Required: `text = "unchanged"`. Observed: runtime error 13,
`cannot convert Object to String`. Explicit `text = label.Caption` works.
Changing only the declaration to `Dim label As Label` also makes the omitted
member execute correctly on the same baseline. Keep both tests: the failure is
specifically the qualified referenced type, and removing the qualifier is not
an acceptable application-source workaround.
The test places member attributes after `End Property` in the manifest source,
matching the pinned parser's accepted normalized source form. Exported-source
normalization remains the production loader's separate obligation.

Please cover cross-project default get, Let/Set, indexed get/set, argument
coercion, early/late-bound contexts and object-valued default chains without
rewriting the client. Keep error/coercion semantics consistent with VBA.

Read-only inspection of later sibling history found added cross-project default
tests at `8f0b9872`, `92d33543` and `66a3dc30`. The bare-default fixture declares
its variables with unqualified names. These are useful related tests but do not
establish that the qualified-name failure above is corrected in a newer revision.
No current-sibling runtime result is claimed and no floating path override is used.

## D006-02: Friend method reachable by referencing project

Library class:

```vb
Friend Function RuntimeDispatch(ByVal opcode As Long) As Long
    RuntimeDispatch = opcode + 100
End Function
```

An external client with `Dim label As MSForms.Label` successfully calls
`label.RuntimeDispatch(7)` and receives 107. Binding falls back to late dispatch
for the unavailable referenced member; runtime dispatch still exposes it.

Required: same-library callers may invoke Friend, typed external access must be
rejected, and casting to Object must not recover the internal member through
late binding/CallByName. Check private methods and non-exposed classes as part
of the same boundary. Internal dispatch should use an explicitly host-owned
capability, not an exposed MSForms member. This is a compatibility/encapsulation
requirement, not a claim that the forms runtime is a security sandbox.

## Integration acceptance

Publish a reviewed upstream revision and regression evidence. In OxForms, update
the dependency through its baseline policy, replace the two discrepancy tests
with required-outcome tests, replay both separate-project and production-library
fixtures, and rerun the full verification floor. Preserve the raw metadata and
the immutable `.5` capture. A baseline update must regenerate the current
implementation comparison and explicitly review/version the `.6` input pins;
do not change raw contracts to fit the implementation. Historical committed
snapshots retain their original hashes and observations. No sibling files were
modified for this handover.

2026-11-06 response: CalcForms now pins published CalcVBA a4bf9792. Its focused
VM3 probes require and pass qualified scalar defaults, same-library Friend calls,
typed external rejection at binding and late-bound error 438. The explicit
Let/Set identity probes also pass. The two discrepancy assertions are replaced
by required outcomes. Current source-ledger pins are refreshed; `.6`'s generated
snapshot remains historical and `.7` still owns the production facade refactor.
See [take-up evidence](../evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.75/README.md).
