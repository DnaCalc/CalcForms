"""Compose the W010 facade obligations without rewriting historical raw facts.

The .4 ledger remains the immutable declaration/current-baseline input to .5
captures. This companion is the next layer of the generated ledger: each row
points into that input, and host composition never changes a raw COM interface.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

from parity_ledger import load_json_strict

ROOT = Path(__file__).resolve().parents[2]
BASE_PATH = "docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.4/msforms_parity_ledger.v1.json"
BASE_SHA256 = "0e361935bab6490253224775154c7493e068a6e30a20fdcc2cd62f14e14342b0"
OUTPUT_PATH = "docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.6/msforms_facade_ledger.v1.json"
FM20_KEY = "{0D452EE1-E08F-101A-852E-02608C4D0BB4}:2.0:lcid=0:syskind=1"
HOST_EVENTS = ("Enter", "Exit", "BeforeUpdate", "AfterUpdate")
DESIGNER_MEMBERS = ("DesignMode", "ShowToolbox", "ShowGridDots", "SnapToGrid", "GridX", "GridY")
DOCUMENTED_PROGIDS = ("CheckBox", "ComboBox", "CommandButton", "Frame", "Image", "Label", "ListBox", "MultiPage", "OptionButton", "ScrollBar", "SpinButton", "TabStrip", "TextBox", "ToggleButton")


def encoded(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def load_base(root: Path = ROOT) -> dict:
    raw = (root / BASE_PATH).read_bytes()
    if hashlib.sha256(raw).hexdigest() != BASE_SHA256:
        raise ValueError("Historical .4 ledger bytes differ from the reviewed facade input")
    return load_json_strict(root / BASE_PATH)


def build(base: dict) -> dict:
    rows = base["rows"]
    by_id = {row["row_id"]: row for row in rows}
    if len(by_id) != len(rows):
        raise ValueError("Duplicate raw ledger row identity")
    types = {row["facade_owner_type_id"]: row for row in rows if row["row_kind"] == "type_contract"}
    primary = [row for row in types.values() if row["contract"]["view"] == "primary"]
    root_types = {row["exact_name"]: row for row in primary if row["contract"]["library_key"] == FM20_KEY}
    control = root_types["Control"]
    site_members = [row for row in rows if row["row_kind"] == "surface_member" and row["facade_owner_type_id"] == control["facade_owner_type_id"]]
    candidates = [row for row in primary if "TYPEFLAG_FCONTROL" in row["visibility"]["type_flags"]]
    # Page is a returned container, not FCONTROL. Retain that distinction and
    # include its applicability questions instead of dropping them from sight.
    candidates.append(root_types["Page"])
    event_contracts = {row["exact_name"]: row for row in rows if row["row_kind"] == "declaration_member" and row["declaration_owner_type_id"] == root_types["ControlEvents"]["facade_owner_type_id"] and row["exact_name"] in HOST_EVENTS}
    if set(event_contracts) != set(HOST_EVENTS):
        raise ValueError("Incomplete generic host-event declarations")

    shapes = []
    for row in primary:
        contract = row["contract"]
        kind = contract["typekind"]
        shapes.append({
            "type_id": row["facade_owner_type_id"],
            "contract_ref": row["row_id"],
            "library_name": "MSForms" if contract["library_key"] == FM20_KEY else "stdole",
            "exact_name": row["exact_name"],
            "guid": contract["guid"],
            "typekind": kind,
            "disposition": row["disposition"],
            "visibility_ref": row["row_id"],
            "source_shape": {
                "TKIND_COCLASS": "exact_named_class_with_canonical_interfaces",
                "TKIND_DISPATCH": "exact_named_dispatch_interface_or_returned_object",
                "TKIND_INTERFACE": "exact_interface_with_explicit_abi_adapter_if_required",
                "TKIND_ENUM": "exact_named_enum_and_values",
                "TKIND_ALIAS": "canonical_alias_target",
                "TKIND_RECORD": "exact_record_or_native_abi_contract",
            }.get(kind, "exact_raw_type_contract"),
            "implemented_interface_refs": [
                "contract:type:" + edge["target"]["library_key"] + "|" + str(edge["target"]["type_index"]) + "|" + edge["target"]["view"]
                for edge in contract["implemented_types"]
            ],
            "default_and_creatable_flags_ref": row["row_id"],
            "implementation_status": row["dimensions"]["bind"]["status"],
        })

    projections = []
    for owner in candidates:
        owner_id = owner["facade_owner_type_id"]
        native_members = {row["exact_name"].casefold(): row for row in rows if row["row_kind"] == "surface_member" and row["facade_owner_type_id"] == owner_id}
        for member in site_members:
            restricted = member["visibility"]["restricted"]
            collision = native_members.get(member["exact_name"].casefold())
            projections.append({
                "row_id": f"control-site:{owner_id}|memid={member['memid']}",
                "row_kind": "control_site_projection",
                "owner_type_id": owner_id,
                "owner_name": owner["exact_name"],
                "owner_contract_ref": owner["row_id"],
                "exact_name": member["exact_name"],
                "memid": member["memid"],
                "site_surface_ref": member["row_id"],
                "declaration_ref": member["source_refs"][0],
                "accessors": list(member["contract"]["accessors"]),
                "applicability": "excluded_restricted" if restricted else "unresolved",
                "applicability_evidence": [member["row_id"]] if restricted else [],
                "native_member_collision_ref": collision["row_id"] if collision else None,
                "binding_route": "container_site_composition",
                "implementation_status": "excluded_authoritative" if restricted else "missing",
                "implementation_evidence": [],
                "basis": "An exact restricted declaration is not a public VBA binding obligation." if restricted else "Requires this concrete owner and host context; a standalone Control implementation or FCONTROL flag cannot prove applicability or binding.",
            })

    event_rows = []
    for owner in candidates:
        owner_id = owner["facade_owner_type_id"]
        for name in HOST_EVENTS:
            source = event_contracts[name]
            observations = [row for row in rows if row["row_kind"] == "host_event_attachment" and row["facade_owner_type_id"] == owner_id and row["exact_name"] == name]
            event_rows.append({
                "row_id": f"host-applicability:{owner_id}|memid={source['memid']}",
                "row_kind": "host_event_applicability",
                "owner_type_id": owner_id,
                "owner_name": owner["exact_name"],
                "owner_contract_ref": owner["row_id"],
                "exact_name": name,
                "declaration_ref": source["row_id"],
                "applicability": "observed_attachment" if observations else "unresolved",
                "applicability_evidence": [row["row_id"] for row in observations],
                "implementation_status": "missing",
                "basis": "Preserved exact-family observations do not prove every event ordering, mutation, reentrancy, or other family's attachment.",
            })

    hidden_rows = []
    for interface in ("_UserForm", "IOptionFrame", "IPage"):
        names = DESIGNER_MEMBERS + (("DrawBuffer",) if interface == "_UserForm" else ())
        for name in names:
            matches = [row for row in rows if row["row_kind"] == "declaration_member" and row["declaration_owner_type_id"] == root_types[interface]["facade_owner_type_id"] and row["exact_name"] == name]
            if len(matches) != 1:
                raise ValueError(f"Expected one designer-band declaration: {interface}.{name}")
            member = matches[0]
            hidden_rows.append({
                "row_id": f"designer-callability:{member['row_id']}",
                "interface": interface,
                "exact_name": name,
                "declaration_ref": member["row_id"],
                "accessors": list(member["contract"]["accessors"]),
                "decision": "accepted_pending_live_probe",
                "evidence": [],
                "basis": "Hidden and non-browsable flags do not establish non-callability; exact accessor probes are required.",
            })

    member_shapes = []
    for row in rows:
        if row["row_kind"] not in ("declaration_member", "surface_member", "event_projection", "abi_adapter_member", "declaration_variable", "enum_value"):
            continue
        owner = types[row["facade_owner_type_id"] or row["declaration_owner_type_id"]]
        if owner["contract"]["view"] != "primary":
            continue
        member_shapes.append({
            "contract_ref": row["row_id"],
            "owner_type_id": owner["facade_owner_type_id"],
            "exact_owner_name": owner["exact_name"],
            "exact_member_name": row["exact_name"],
            "memid": row["memid"],
            "disposition": row["disposition"],
            "binding_kind": row["row_kind"],
            "accessor_shapes": [{
                "accessor": name, "signature_sha256": signature["signature_sha256"],
                "source_shape": (
                    "Event" if row["row_kind"] == "event_projection" else
                    "Native ABI adapter from exact signature and vtable layout" if owner["contract"]["typekind"] == "TKIND_INTERFACE" else
                    {"get": "Property Get", "put": "Property Let", "putref": "Property Set", "func": "Sub or Function from exact return contract"}[name]
                ),
                "default_member": signature["is_default_member"],
                "new_enum": signature["is_new_enum"],
            } for name, signature in row["contract"].get("accessors", {}).items()],
            "implementation_credit": False,
        })
    result = {
        "schema": "oxforms.msforms_facade_ledger.v1",
        "schema_version": 1,
        "base_ledger": {"path": BASE_PATH, "sha256": BASE_SHA256, "canonical_sha256": base["canonical_sha256"], "rows": len(rows)},
        "composition_rule": "Resolve references against the immutable base ledger; keep raw declarations unchanged. No projection or summary grants implementation credit to another owner.",
        "public_library": {"name": "MSForms", "guid": "{0D452EE1-E08F-101A-852E-02608C4D0BB4}", "major": 2, "minor": 0, "reference_policy": "Host-owned reference substitution preserves the original MSForms identity and priority without rewriting application source or requiring FM20 at runtime."},
        "type_shapes": shapes,
        "member_shapes": member_shapes,
        "progids": [{"owner_type_id": owner["facade_owner_type_id"], "owner_name": owner["exact_name"],
                     "prog_id": "Forms." + owner["exact_name"] + ".1" if owner["exact_name"] in DOCUMENTED_PROGIDS else None,
                     "authority": "https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/add-method-microsoft-forms" if owner["exact_name"] in DOCUMENTED_PROGIDS else None,
                     "status": "documented_not_runtime_verified" if owner["exact_name"] in DOCUMENTED_PROGIDS else "unresolved_no_invented_progid"}
                    for owner in primary if owner["contract"]["typekind"] == "TKIND_COCLASS"],
        "internal_bridge": {"name": "OxFormsRuntime.Dispatch", "visibility": "non_public_host_capability", "public_member": False,
                            "status": "blocked_D006_02", "implementation_owner": "oxforms-jbjp.7",
                            "rule": "The host alone obtains a bridge capability; no public Core/Perform/Notify members. Friend alone is insufficient on the pinned OxVba baseline."},
        "control_site_projections": projections,
        "host_event_applicability": event_rows,
        "designer_band_callability": hidden_rows,
        "host_overlay_refs": [row["row_id"] for row in rows if row["row_kind"].startswith("overlay_")],
        "summary": {
            "base_rows": len(rows),
            "primary_type_shapes": len(shapes),
            "primary_member_shapes": len(member_shapes),
            "fcontrol_types": len(candidates) - 1,
            "additional_returned_containers": 1,
            "control_site_rows": len(projections),
            "control_site_applicability": dict(sorted(Counter(row["applicability"] for row in projections).items())),
            "host_event_rows": len(event_rows),
            "host_event_applicability": dict(sorted(Counter(row["applicability"] for row in event_rows).items())),
            "designer_band_rows": len(hidden_rows),
            "green": False,
        },
    }
    for shape in shapes:
        if any(ref not in by_id for ref in shape["implemented_interface_refs"]):
            raise ValueError(f"Unresolved interface in {shape['exact_name']}")
    return result


def validate(document: dict, base: dict) -> None:
    # Re-derivation rejects coherent rehashes, omitted families, invented
    # signatures, status promotion, and swapping one concrete owner for another.
    if encoded(document) != encoded(build(base)):
        raise ValueError("Facade ledger differs from exact source-derived obligations")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Regenerate the canonical artifact for review")
    args = parser.parse_args()
    expected = build(load_base())
    target = ROOT / OUTPUT_PATH
    if args.write:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(encoded(expected))
    elif not target.is_file() or target.read_bytes() != encoded(expected):
        raise ValueError("Canonical facade ledger is missing or stale; regenerate and review the diff")
    print(json.dumps(expected["summary"], sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
