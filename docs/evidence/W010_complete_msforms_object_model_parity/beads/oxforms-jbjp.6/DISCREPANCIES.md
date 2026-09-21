# Facade discrepancies

Reviewed 2026-09-21. All entries remain open; no runtime parity is claimed.

| ID | Required outcome | Observed outcome | Evidence / owner |
|---|---|---|---|
| D006-01 | Qualified referenced DISPID-0 scalar member executes in a value context | Error 13: cannot convert Object to String | `discrepancy_d006_01_qualified_default_member_is_not_executed`; `oxforms-o0fp` |
| D006-02 | Friend bridge inaccessible outside its library | Typed external invocation returns 107 | `discrepancy_d006_02_friend_bridge_leaks_to_referencing_project`; `oxforms-o0fp` |
| D006-03 | Live get/put observations for 19 designer-band declarations | Safe-mode Excel opens startup dialog; harness refuses macro automation | Capture attempts and startup diagnostic; `.6` remains open |
| D006-04 | Every applicable owner has its site and generic event obligations proven | 2,295 site applicability rows unresolved; 194 event applicability rows unresolved | Generated facade ledger; later owner-specific W010 captures |
| D006-05 | Original library reference resolves to exact production classes | Mechanism fixture uses MSForms identity; production basproj is still OxForms and has subset classes | Facade spec; `.7`, `.44`, `.46`, `.57` and class implementation beads |

The Rust discrepancy tests are observations of the pinned baseline. They must
be replaced with required-outcome assertions when corrected; their passing
result must never be counted as a passed compatibility requirement.
