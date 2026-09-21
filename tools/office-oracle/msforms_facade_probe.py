"""Fixed .6 black-box discovery probes; observations are not OxForms parity."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys

import msforms_member_oracle as oracle

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/msforms-parity"))
import facade_contract as facade

BASE_MANIFEST = ROOT / "fixtures/office-oracle/excel-msforms/member-probes/representative-v1.json"


def encoded(value: object) -> bytes:
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def definition() -> tuple[dict, dict[str, str]]:
    manifest = copy.deepcopy(oracle.validate_manifest(BASE_MANIFEST, ROOT))
    manifest["schema"] = "oxforms.office_oracle.msforms_facade_discovery.v1"
    manifest["bead"] = "oxforms-jbjp.6"
    manifest["id"] = "W010FacadeDiscoveryV1"
    manifest["form"]["caption"] = "OxForms W010 Facade Discovery"
    manifest["form"]["height_pt"] = 340
    for index, kind in enumerate(("Frame", "MultiPage")):
        manifest["form"]["controls"].append({
            "id": kind.lower(), "name": "Probe" + kind,
            "prog_id": "Forms." + kind + ".1", "fm20_type": kind,
            "left_pt": 18 + index * 150, "top_pt": 170,
            "width_pt": 132, "height_pt": 110, "initial_properties": {},
        })
    targets = {"_UserForm": "FacadeTarget(0)", "IOptionFrame": "FacadeTarget(1)", "IPage": "FacadeTarget(2)"}
    obligations = facade.build(facade.load_base())["designer_band_callability"]
    # Two distinct accessor probes: a failing put must not suppress the get.
    for row in obligations:
        for operation in ("property_get", "property_set"):
            step = {"kind": "probe", "id": row["interface"].replace("_", "") + row["exact_name"] + operation,
                    "target": row["interface"], "ledger_row_id": row["declaration_ref"],
                    "operation": operation, "member": row["exact_name"]}
            if operation == "property_set":
                # Keep DesignMode and toolbox off; don't create designer UI.
                value = 6 if row["exact_name"] in ("GridX", "GridY") else (32000 if row["exact_name"] == "DrawBuffer" else 0)
                step["value"] = {"kind": "integer", "value": value}
            manifest["steps"].append(step)
    manifest["discovery_scope"] = "Late-bound get and put on runtime UserForm, Frame, and Page; all 19 named designer-band members. No production behavior credit."
    return manifest, targets


def sources(manifest: dict, targets: dict[str, str]) -> dict[str, tuple[str, str]]:
    form_name = manifest["form"]["name"]
    module = oracle.generate_module_code(manifest, target_expressions=targets)
    module += ("\nPrivate Function FacadeTarget(ByVal which As Long) As Object\n"
               "    Select Case which\n"
               f"        Case 0: Set FacadeTarget = {form_name}\n"
               f"        Case 1: Set FacadeTarget = {form_name}.ProbeFrame\n"
               f"        Case 2: Set FacadeTarget = {form_name}.ProbeMultiPage.Pages(0)\n"
               "    End Select\nEnd Function\n")
    return {oracle.RUNTIME_MODULE_NAME: ("Module", module), form_name: ("BaseClass", oracle.generate_form_code(manifest))}


def check_package(directory: Path, *, preopen: bool) -> dict:
    manifest, targets = definition()
    if (directory / "probe-definition.json").read_bytes() != encoded(manifest):
        raise ValueError("Capture definition differs from the fixed reviewed probes")
    expected = sources(manifest, targets)
    for name, (_, source) in expected.items():
        if (directory / (name + ".vba")).read_bytes() != source.encode("utf-8"):
            raise ValueError("Generated VBA source differs: " + name)
    spec = manifest["replay_validators"]["cfb_inventory"]
    cfb_path = ROOT / spec["path"]
    cfb_bytes = cfb_path.read_bytes()
    if hashlib.sha256(cfb_bytes).hexdigest() != spec["sha256"]:
        raise ValueError("CFB validator changed")
    cfb = oracle._load_python_module_bytes(cfb_bytes, cfb_path, "facade_cfb_validator")
    workbook = directory / "facade-probe.xlsm"
    data = oracle._read_bound_file(workbook, "facade.workbook", max_bytes=64 * 1024 * 1024)
    digest = hashlib.sha256(data).hexdigest()
    dimensions = {}
    if not preopen:
        live = json.loads((directory / "observations.json").read_text(encoding="utf-8"))
        dimensions = {manifest["capture"]["result_sheet"]: (len(live["results"]) + 1, len(oracle.RESULT_HEADERS)),
                      manifest["capture"]["event_sheet"]: (len(live["events"]) + 1, len(oracle.EVENT_HEADERS))}
    tables = oracle._validate_xlsm_package(workbook, manifest["capture"]["result_sheet"], manifest["capture"]["event_sheet"],
                                         dimensions, expected, cfb, preopen=preopen,
                                         expected_package_sha256=digest, retained_package_bytes=data)
    oracle._read_bound_file(workbook, "facade.workbook", expected_sha256=digest, max_bytes=64 * 1024 * 1024)
    if not preopen:
        for category, headers, sheet in (("results", oracle.RESULT_HEADERS, manifest["capture"]["result_sheet"]),
                                          ("events", oracle.EVENT_HEADERS, manifest["capture"]["event_sheet"])):
            expected_table = [list(headers)] + [[str(row[h]) for h in headers] for row in live[category]]
            if tables[sheet] != expected_table:
                raise ValueError("Workbook and recorded " + category + " differ")
        steps = [s for s in manifest["steps"] if s["kind"] == "probe"]
        if len(live["results"]) != len(steps):
            raise ValueError("Missing discovery observations")
        for index, (step, row) in enumerate(zip(steps, live["results"], strict=True), 1):
            if row["sequence"] != index or any(row[key] != step[field] for key, field in
                  (("probe_id", "id"), ("ledger_row_id", "ledger_row_id"), ("target_id", "target"), ("operation", "operation"), ("member", "member"))):
                raise ValueError("Probe identity/order mismatch")
            if row["outcome"] != ("success" if row["error_number"] == 0 else "error"):
                raise ValueError("Observation outcome contradicts Err.Number")
    return {"workbook_sha256": digest, "mode": "preopen" if preopen else "replay", "probe_count": len([s for s in manifest["steps"] if s["kind"] == "probe"])}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("generate", "preopen", "replay"))
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    directory = args.directory.resolve()
    allowed = ROOT / "docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.6/captures"
    if not directory.is_relative_to(allowed) or directory == allowed or directory.is_symlink():
        raise ValueError("Output must be a capture child inside the .6 evidence root")
    if args.command == "generate":
        manifest, targets = definition()
        directory.mkdir(parents=True, exist_ok=True)
        for name, (_, source) in sources(manifest, targets).items():
            with (directory / (name + ".vba")).open("xb") as stream:
                stream.write(source.encode("utf-8"))
        with (directory / "probe-definition.json").open("xb") as stream:
            stream.write(encoded(manifest))
        print(json.dumps({"generated": True}))
    else:
        print(json.dumps(check_package(directory, preopen=args.command == "preopen")))


if __name__ == "__main__":
    main()
