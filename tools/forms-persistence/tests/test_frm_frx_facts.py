from __future__ import annotations

import copy
import importlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


MODULE_DIRECTORY = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODULE_DIRECTORY))
facts = importlib.import_module("frm_frx_facts")

REPO_ROOT = Path(__file__).resolve().parents[3]
PINS_PATH = MODULE_DIRECTORY / "pinned_sources.v1.json"
EXPECTED_PATH = MODULE_DIRECTORY / "expected_capture.v1.json"
FACTS_PATH = (
    REPO_ROOT
    / "docs"
    / "evidence"
    / "W010_complete_msforms_object_model_parity"
    / "beads"
    / "oxforms-jbjp.43"
    / "frm_frx_export_facts.v1.json"
)
CAPTURE_MANIFEST_PATH = (
    REPO_ROOT
    / "fixtures"
    / "forms-persistence"
    / "office-vba-userform-export"
    / "20260715-excel-16.0.20131.20112"
    / "capture_manifest.v2.json"
)
CAPTURE_SPEC_PATH = MODULE_DIRECTORY / "capture_spec.v1.json"
EXPORT_SCRIPT = MODULE_DIRECTORY / "export_frm_frx_facts.py"
VALIDATE_SCRIPT = MODULE_DIRECTORY / "validate_frm_frx_facts.py"


def _resign(pack: dict[str, object]) -> dict[str, object]:
    pack["canonical_sha256"] = facts.semantic_sha256(pack)
    return pack


def _refresh_summary(pack: dict[str, object]) -> None:
    """Keep summary-derived counts honest while testing deeper invariants."""

    pack["summary"] = facts._summary(
        pack["source_rows"],
        pack["fixtures"],
        pack["resource_references"],
        pack["cfb_inventories"],
        pack["designer_properties"]["normative_ordered_universe"],
        pack["property_mappings"],
        pack["control_identifiers"],
        pack["legacy_synthetic_corpus"],
        pack["binary_persistence_contract"],
    )


def _write(path: Path, payload: bytes) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    return path


def _copy_capture_tree(destination: Path) -> tuple[dict[str, object], Path]:
    """Copy only the small live-capture surface into a disposable repo root."""

    capture = json.loads(CAPTURE_MANIFEST_PATH.read_text(encoding="utf-8"))
    source_paths = [capture["capture_tool"]["path"], capture["capture_spec"]["path"]]
    source_paths.extend(
        exported["path"]
        for form in capture["forms"]
        for exported in form["exported_files"]
    )
    for relative_text in source_paths:
        relative = Path(*Path(relative_text).parts)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REPO_ROOT / relative, target)

    manifest_relative = CAPTURE_MANIFEST_PATH.relative_to(REPO_ROOT)
    manifest = destination / manifest_relative
    _write(manifest, facts.canonical_json_bytes(capture))
    return capture, manifest


def _exported_path(
    root: Path,
    capture: dict[str, object],
    suffix: str,
    *,
    fixture_id: str | None = None,
) -> Path:
    forms = capture["forms"]
    form = next(
        row for row in forms if fixture_id is None or row["fixture_id"] == fixture_id
    )
    exported = next(
        row for row in form["exported_files"] if Path(row["path"]).suffix == suffix
    )
    return root / Path(*Path(exported["path"]).parts)


class StrictJsonTests(unittest.TestCase):
    def test_rejects_duplicate_keys_at_any_depth(self) -> None:
        cases = (
            b'{"a":1,"a":2}',
            b'{"outer":{"a":1,"a":2}}',
        )
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "input.json"
            for payload in cases:
                with self.subTest(payload=payload):
                    path.write_bytes(payload)
                    with self.assertRaisesRegex(facts.FactError, "duplicate JSON key"):
                        facts.load_json_strict(path)

    def test_rejects_every_nonfinite_json_spelling(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "input.json"
            for spelling in ("NaN", "Infinity", "-Infinity"):
                with self.subTest(spelling=spelling):
                    path.write_text(f'{{"value":{spelling}}}', encoding="utf-8")
                    with self.assertRaisesRegex(facts.FactError, "non-finite"):
                        facts.load_json_strict(path)

    def test_rejects_invalid_utf8(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = _write(Path(temporary) / "input.json", b'{"x":"\xff"}')
            with self.assertRaisesRegex(facts.FactError, "not UTF-8"):
                facts.load_json_strict(path)

    def test_canonical_json_is_sorted_utf8_lf_and_finite(self) -> None:
        self.assertEqual(
            facts.canonical_json_bytes({"z": 1, "a": "Caf\N{LATIN SMALL LETTER E WITH ACUTE}"}),
            b'{\n  "a": "Caf\xc3\xa9",\n  "z": 1\n}\n',
        )
        for value in (float("nan"), float("inf"), float("-inf")):
            with self.subTest(value=value), self.assertRaises(ValueError):
                facts.canonical_json_bytes({"value": value})

    def test_canonical_fact_loader_rejects_reformatting_and_crlf(self) -> None:
        committed = facts.load_canonical_fact_pack(FACTS_PATH)
        self.assertEqual(committed["schema"], facts.FACT_SCHEMA)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            variants = {
                "minified": json.dumps(committed, sort_keys=True).encode("utf-8"),
                "crlf": facts.canonical_json_bytes(committed).replace(b"\n", b"\r\n"),
            }
            for name, payload in variants.items():
                with self.subTest(name=name):
                    path = _write(root / f"{name}.json", payload)
                    with self.assertRaisesRegex(facts.FactError, "not canonical"):
                        facts.load_canonical_fact_pack(path)


class FactPackMutationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.pins = facts.load_pins(PINS_PATH)
        cls.pack = facts.load_canonical_fact_pack(FACTS_PATH)
        cls.expected = facts.load_json_strict(EXPECTED_PATH)

    def fresh_pack(self) -> dict[str, object]:
        return copy.deepcopy(self.pack)

    def assert_mutation_rejected(self, mutate, message: str) -> None:
        pack = self.fresh_pack()
        mutate(pack)
        _resign(pack)
        with self.assertRaisesRegex(facts.FactError, message):
            facts.validate_fact_pack(pack, pins=self.pins)

    def test_committed_pack_and_expected_capture_validate(self) -> None:
        facts.validate_fact_pack(self.pack, pins=self.pins, expected=self.expected)
        self.assertEqual(
            self.pack["canonical_sha256"], facts.semantic_sha256(self.pack)
        )

    def test_rejects_stale_semantic_digest_and_top_level_schema_drift(self) -> None:
        stale = self.fresh_pack()
        stale["summary"]["cfb_streams"] += 1
        with self.assertRaisesRegex(facts.FactError, "canonical_sha256 mismatch"):
            facts.validate_fact_pack(stale, pins=self.pins)

        for name, mutation in (
            ("missing", lambda pack: pack.pop("coverage")),
            ("extra", lambda pack: pack.update({"invented": None})),
        ):
            with self.subTest(name=name):
                pack = self.fresh_pack()
                mutation(pack)
                _resign(pack)
                with self.assertRaisesRegex(facts.FactError, "fact pack keys differ"):
                    facts.validate_fact_pack(pack, pins=self.pins)

        for key, value in (("schema", "wrong"), ("schema_version", 2)):
            with self.subTest(key=key):
                self.assert_mutation_rejected(
                    lambda pack, key=key, value=value: pack.__setitem__(key, value),
                    "schema/version mismatch",
                )

    def test_rejects_pin_digest_drift(self) -> None:
        self.assert_mutation_rejected(
            lambda pack: pack["generator"].__setitem__(
                "pinned_sources_sha256", "0" * 64
            ),
            "pinned_sources digest mismatch",
        )

    def test_rejects_deleted_and_duplicate_property_mapping(self) -> None:
        self.assert_mutation_rejected(
            lambda pack: pack["property_mappings"].pop(),
            "property coverage is not exactly 98",
        )

        def duplicate(pack) -> None:
            pack["property_mappings"][-1] = copy.deepcopy(
                pack["property_mappings"][0]
            )

        self.assert_mutation_rejected(duplicate, "duplicate MS-OFORMS")

    def test_rejects_binary_or_runtime_property_overclaim(self) -> None:
        for key in ("binary_value_decoded", "runtime_api_claim"):
            with self.subTest(key=key):
                self.assert_mutation_rejected(
                    lambda pack, key=key: pack["property_mappings"][0].__setitem__(
                        key, True
                    ),
                    "overclaims decoded binary/runtime API",
                )

    def test_rejects_binary_length_count_universe_drift(self) -> None:
        self.assert_mutation_rejected(
            lambda pack: pack["binary_persistence_contract"][
                "binary_length_forms"
            ]["record_fields"].pop(),
            "binary persistence contract coverage drift",
        )
        self.assert_mutation_rejected(
            lambda pack: pack["binary_persistence_contract"][
                "binary_length_forms"
            ]["record_fields"][0].__setitem__("name", "invented"),
            "length/count field identity drift",
        )

    def test_rejects_same_count_binary_contract_substitutions(self) -> None:
        def substitute_object_property(pack) -> None:
            rows = pack["binary_persistence_contract"]["object_valued_encodings"][
                "properties"
            ]
            rows[0] = copy.deepcopy(rows[1])

        def substitute_resource_format(pack) -> None:
            rows = pack["binary_persistence_contract"]["object_valued_encodings"][
                "resource_formats"
            ]
            rows[0] = copy.deepcopy(rows[1])

        def substitute_property_default(pack) -> None:
            rows = pack["binary_persistence_contract"]["omission_and_defaults"][
                "property_defaults"
            ]
            rows[0] = copy.deepcopy(rows[1])

        def substitute_storage_requirement(pack) -> None:
            rows = pack["binary_persistence_contract"]["omission_and_defaults"][
                "storage_requirements"
            ]
            rows[0] = copy.deepcopy(rows[1])

        for name, mutation in (
            ("object property", substitute_object_property),
            ("resource format", substitute_resource_format),
            ("property default", substitute_property_default),
            ("storage requirement", substitute_storage_requirement),
        ):
            with self.subTest(name=name):
                pack = self.fresh_pack()
                mutation(pack)
                _resign(pack)
                with self.assertRaises(facts.FactError):
                    facts.validate_fact_pack(pack, pins=self.pins)

    def test_rejects_unsupported_live_object_persistence_claims(self) -> None:
        mutations = (
            (
                "nondefault object probe",
                lambda pack: pack["binary_persistence_contract"][
                    "object_valued_encodings"
                ]["live_nondefault_object_probes"].append(
                    {"claim": "unsupported live object decode"}
                ),
            ),
            (
                "boolean decoded-value count",
                lambda pack: pack["binary_persistence_contract"][
                    "object_valued_encodings"
                ].__setitem__("decoded_live_values", False),
            ),
        )
        for name, mutation in mutations:
            with self.subTest(name=name):
                pack = self.fresh_pack()
                mutation(pack)
                _resign(pack)
                with self.assertRaises(facts.FactError):
                    facts.validate_fact_pack(pack, pins=self.pins)

    def test_property_row_classification_must_match_family_evidence(self) -> None:
        pack = self.fresh_pack()
        row = next(
            item
            for item in pack["property_mappings"]
            if item["classification"] == "live_public_property_probe_exact_name"
            and any(
                coverage["status"] == "exact_name_live_probe"
                for coverage in item["family_coverage"]
            )
        )
        row["classification"] = "failed_live_public_property_probe_exact_name"
        _refresh_summary(pack)
        _resign(pack)
        with self.assertRaises(facts.FactError):
            facts.validate_fact_pack(pack, pins=self.pins)

        pack = self.fresh_pack()
        row = next(
            item for item in pack["property_mappings"]
            if item["name"] == "ClsidCacheIndex"
        )
        row["family_coverage"][0]["probe_owners"] = ["None:None"]
        _resign(pack)
        with self.assertRaisesRegex(facts.FactError, "reconciliation drift"):
            facts.validate_fact_pack(pack, pins=self.pins)

    def test_rejects_synthetic_authority_promotion(self) -> None:
        self.assert_mutation_rejected(
            lambda pack: pack["legacy_synthetic_corpus"][0].__setitem__(
                "may_establish_office_export_facts", True
            ),
            "synthetic fixture was promoted",
        )

    def test_rejects_unknown_preservation_policy_drift(self) -> None:
        self.assert_mutation_rejected(
            lambda pack: pack["unknown_preservation"][0].__setitem__(
                "write", "discard silently"
            ),
            "unknown-preservation contract drift",
        )

    def test_rejects_boundary_claims(self) -> None:
        for key in ("runtime_api_claims", "codec_claims", "vb6_claims"):
            with self.subTest(key=key):
                self.assert_mutation_rejected(
                    lambda pack, key=key: pack["boundaries"][key].append(
                        "unsupported claim"
                    ),
                    "boundary non-claim arrays must remain empty",
                )

    def test_rejects_fixed_coverage_and_boundary_narrative_drift(self) -> None:
        mutations = (
            (
                "coverage",
                lambda pack: pack["coverage"].__setitem__(
                    "frm", "Mutated coverage narrative."
                ),
            ),
            (
                "boundary",
                lambda pack: pack["boundaries"].__setitem__(
                    "frx_prefix", "Mutated boundary narrative."
                ),
            ),
        )
        for name, mutation in mutations:
            with self.subTest(name=name):
                pack = self.fresh_pack()
                mutation(pack)
                _resign(pack)
                with self.assertRaises(facts.FactError):
                    facts.validate_fact_pack(pack, pins=self.pins)

    def test_rejects_real_fixture_authority_profile_and_coverage_drift(self) -> None:
        mutations = (
            (
                "authority",
                lambda pack: pack["fixtures"][0].__setitem__(
                    "authority_class", "synthetic"
                ),
                "authority class drift",
            ),
            (
                "profile",
                lambda pack: pack["fixtures"][0].__setitem__(
                    "profile", "legacy_synthetic_nested"
                ),
                "profile drift",
            ),
            (
                "frm coverage",
                lambda pack: pack["fixtures"][0]["frm_inventory"][
                    "coverage"
                ].__setitem__("all_bytes_classified_once", False),
                "FRM inventory lacks full coverage",
            ),
            (
                "prefix length",
                lambda pack: pack["fixtures"][0]["frx_prefix"].__setitem__(
                    "length", 23
                ),
                "FRX prefix boundary drift",
            ),
            (
                "prefix interpretation",
                lambda pack: pack["fixtures"][0]["frx_prefix"].__setitem__(
                    "interpretation", "decoded_header"
                ),
                "FRX prefix boundary drift",
            ),
        )
        for name, mutation, message in mutations:
            with self.subTest(name=name):
                self.assert_mutation_rejected(mutation, message)

    def test_rejects_cfb_boundary_and_coverage_drift(self) -> None:
        for name, key, value in (
            ("signature", "signature_offset", 0),
            ("coverage", "all_bytes_accounted_for", False),
        ):
            with self.subTest(name=name):
                if name == "signature":
                    mutation = lambda pack, key=key, value=value: pack[
                        "cfb_inventories"
                    ][0]["inventory"].__setitem__(key, value)
                else:
                    mutation = lambda pack, key=key, value=value: pack[
                        "cfb_inventories"
                    ][0]["inventory"]["coverage"].__setitem__(key, value)
                self.assert_mutation_rejected(
                    mutation, "CFB inventory boundary/coverage drift"
                )

    def test_rejects_designer_order_or_count_and_omission_count_drift(self) -> None:
        mutations = (
            (
                lambda pack: pack["designer_properties"][
                    "normative_ordered_universe"
                ].pop(),
                "exactly 15",
            ),
            (
                lambda pack: pack["designer_properties"][
                    "normative_ordered_universe"
                ][0].__setitem__("order", 1),
                "order/name drift",
            ),
            (
                lambda pack: pack["designer_properties"][
                    "controlled_omission_pairs"
                ].pop(),
                "omission pair count drift",
            ),
        )
        for mutation, message in mutations:
            with self.subTest(message=message):
                self.assert_mutation_rejected(mutation, message)

    def test_rejects_control_family_or_html_probe_coverage_drift(self) -> None:
        self.assert_mutation_rejected(
            lambda pack: pack["control_identifiers"][
                "observed_intrinsic_families"
            ].pop(),
            "intrinsic family coverage drift",
        )
        self.assert_mutation_rejected(
            lambda pack: pack["control_identifiers"]["designer_add_probes"].pop(),
            "HTML designer-add probe coverage drift",
        )

    def test_rejects_checkout_path_leak_even_when_json_escaped(self) -> None:
        self.assert_mutation_rejected(
            lambda pack: pack["boundaries"].__setitem__(
                "html_claim", r"C:\Work\private\fixture.frx"
            ),
            "absolute .* path leaked",
        )

    def test_expected_capture_schema_and_digest_mutations_are_rejected(self) -> None:
        mutations = (
            ("extra key", lambda value: value.update({"extra": 1}), "keys differ"),
            ("schema", lambda value: value.__setitem__("schema", "wrong"), "schema drift"),
            (
                "fact schema",
                lambda value: value.__setitem__("fact_schema", "wrong"),
                "schema drift",
            ),
            (
                "pin digest",
                lambda value: value.__setitem__("pinned_sources_sha256", "0" * 64),
                "pin digest drift",
            ),
            (
                "fact digest",
                lambda value: value.__setitem__("canonical_sha256", "0" * 64),
                "canonical digest drift",
            ),
            (
                "summary",
                lambda value: value["summary"].__setitem__(
                    "cfb_streams", value["summary"]["cfb_streams"] + 1
                ),
                "summary drift",
            ),
        )
        for name, mutation, message in mutations:
            with self.subTest(name=name):
                expected = copy.deepcopy(self.expected)
                mutation(expected)
                with self.assertRaisesRegex(facts.FactError, message):
                    facts.validate_fact_pack(
                        self.pack, pins=self.pins, expected=expected
                    )


class CaptureAndParserMutationTests(unittest.TestCase):
    def test_number_invariant_must_parse_and_equal_the_numeric_value(self) -> None:
        for invariant in ("not-a-number", "2.5"):
            with self.subTest(invariant=invariant), self.assertRaisesRegex(
                facts.FactError, "invariant"
            ):
                facts._validate_observed_value(
                    {"kind": "number", "value": 1.25, "invariant": invariant},
                    "numeric mutation",
                )

    def test_integer_capture_values_must_fit_the_declared_width(self) -> None:
        for kind, value in (
            ("int16", -32769),
            ("int16", 32768),
            ("int32", -2147483649),
            ("int32", 2147483648),
        ):
            with self.subTest(kind=kind, value=value), self.assertRaisesRegex(
                facts.FactError, "out of range"
            ):
                facts._expected_observed_value(kind, value)

    def test_spec_and_observed_required_flags_must_be_booleans(self) -> None:
        for location in ("spec", "observation"):
            with self.subTest(location=location):
                spec_probe = {
                    "name": "Width",
                    "kind": "single",
                    "value": 1.25,
                    "required": True,
                }
                observed_probe = {
                    "name": "Width",
                    "requested": {
                        "kind": "number",
                        "value": 1.25,
                        "invariant": "1.25",
                    },
                    "required": True,
                    "readback": {
                        "kind": "number",
                        "value": 1.25,
                        "invariant": "1.25",
                    },
                    "succeeded": True,
                    "error": None,
                    "hresult": None,
                }
                if location == "spec":
                    spec_probe["required"] = 1
                else:
                    observed_probe["required"] = 1
                with self.assertRaisesRegex(facts.FactError, "required.*boolean"):
                    facts._validate_probe_binding(
                        spec_probe, observed_probe, "required-flag mutation"
                    )

    def test_capture_spec_manifest_binding_rejects_semantic_drift(self) -> None:
        def load_pair():
            return (
                facts.load_json_strict(CAPTURE_SPEC_PATH),
                facts.load_json_strict(CAPTURE_MANIFEST_PATH),
            )

        mutations = (
            (
                "spec requested value",
                lambda spec, capture: spec["forms"][0]["component_properties"][0].__setitem__(
                    "value", "mutated"
                ),
                "requested value differs",
            ),
            (
                "manifest requested value",
                lambda spec, capture: capture["forms"][0]["component_properties"][0]["requested"].__setitem__(
                    "value", "mutated"
                ),
                "requested value differs",
            ),
            (
                "duplicate property",
                lambda spec, capture: capture["forms"][0]["component_properties"].append(
                    copy.deepcopy(capture["forms"][0]["component_properties"][0])
                ),
                "duplicate .* component property",
            ),
            (
                "required flag",
                lambda spec, capture: capture["forms"][0]["component_properties"][0].__setitem__(
                    "required",
                    not capture["forms"][0]["component_properties"][0]["required"],
                ),
                "required flag differs",
            ),
            (
                "geometry type",
                lambda spec, capture: next(
                    row
                    for row in capture["forms"]
                    if row["fixture_id"] == "intrinsic-containers-resources"
                )["controls"][0]["geometry_readback"].__setitem__("height", "24"),
                "geometry readback .* is not a finite number",
            ),
            (
                "list items",
                lambda spec, capture: next(
                    row
                    for row in next(
                        form
                        for form in capture["forms"]
                        if form["fixture_id"] == "intrinsic-containers-resources"
                    )["controls"]
                    if row["name"] == "ListBoxProbe"
                )["list_items_readback"]["items"].__setitem__(0, "invented"),
                "list-item readback drift",
            ),
            (
                "pages",
                lambda spec, capture: next(
                    row
                    for row in next(
                        form
                        for form in capture["forms"]
                        if form["fixture_id"] == "intrinsic-containers-resources"
                    )["controls"]
                    if row["name"] == "MultiPageProbe"
                )["pages"].pop(),
                "page observation drift",
            ),
            (
                "tabs",
                lambda spec, capture: next(
                    row
                    for row in next(
                        form
                        for form in capture["forms"]
                        if form["fixture_id"] == "intrinsic-containers-resources"
                    )["controls"]
                    if row["name"] == "TabStripProbe"
                )["tabs"].pop(),
                "tab observation drift",
            ),
            (
                "code hash",
                lambda spec, capture: capture["forms"][0]["code_input"].__setitem__(
                    "utf8_sha256", "0" * 64
                ),
                "code-input digest",
            ),
            (
                "click-to-run backing escape",
                lambda spec, capture: capture["exporter_binary_identity"]["binary"].__setitem__(
                    "path", r"C:\Temp\VBE7.DLL"
                ),
                "backing escaped",
            ),
            (
                "exporter original filename",
                lambda spec, capture: capture["exporter_binary_identity"]["binary"].__setitem__(
                    "original_filename", "WRONG.DLL"
                ),
                "original filename differs",
            ),
            (
                "designer-add HRESULT",
                lambda spec, capture: capture["designer_add_probes"][0].__setitem__(
                    "hresult", "0x80004005"
                ),
                "designer-add rejection drift",
            ),
            (
                "designer-add added type",
                lambda spec, capture: capture["designer_add_probes"][0].__setitem__(
                    "added", ""
                ),
                "designer-add added must be a boolean",
            ),
        )
        for name, mutation, message in mutations:
            with self.subTest(name=name):
                spec, capture = load_pair()
                mutation(spec, capture)
                with self.assertRaisesRegex(facts.FactError, message):
                    facts._validate_capture_pair(spec, capture)

    def test_fm20_control_binding_rejects_registration_drift(self) -> None:
        pins = facts.load_pins(PINS_PATH)
        local = facts.verify_local_dependencies(REPO_ROOT, pins)
        fm20 = local["W010-FM20-FACTS"]["value"]
        ms_oforms = local["W010-MS-OFORMS-FACTS"]["value"]
        capture = copy.deepcopy(local["LIVE-EXPORT-CAPTURE-MANIFEST"]["value"])
        capture["progid_registrations"][0]["clsid"] = (
            "{00000000-0000-0000-0000-000000000000}"
        )
        with self.assertRaisesRegex(facts.FactError, "ProgID/CLSID/FM20 coclass drift"):
            facts._control_identifiers(ms_oforms, capture, fm20)

        capture = copy.deepcopy(local["LIVE-EXPORT-CAPTURE-MANIFEST"]["value"])
        capture["progid_registrations"][0]["inproc_server"]["path"] = (
            r"C:\Windows\System32\not-fm20.dll"
        )
        with self.assertRaisesRegex(facts.FactError, "malformed server facts"):
            facts._control_identifiers(ms_oforms, capture, fm20)

    def test_designer_property_table_is_derived_from_every_pinned_abnf_lane(self) -> None:
        pack = facts.load_canonical_fact_pack(FACTS_PATH)
        for row_number, replacement, message in (
            (2866, 'DesignerHeight = "Wrong" EQ FLOAT', "DesignerHeight"),
            (2892, "Specifies modal behavior without a default.", "default row"),
            (2916, "DesignerTagText = INT32", "DesignerTag"),
        ):
            with self.subTest(row_number=row_number):
                rows = copy.deepcopy(pack["source_rows"])
                target = next(
                    row
                    for row in rows
                    if row["source_id"] == "MS-OVBA-SEGMENTS"
                    and row["row_number"] == row_number
                )
                target["record"]["text"] = replacement
                with self.assertRaisesRegex(facts.FactError, message):
                    facts._derive_designer_property_specs(rows)

    def test_manifest_self_pins_accept_exact_disposable_copy(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            capture, manifest = _copy_capture_tree(root)
            facts._validate_manifest_self_pins(root, capture, manifest)

    def test_manifest_self_pins_reject_missing_and_hash_drifted_export(self) -> None:
        for mutation in ("missing", "hash"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                capture, manifest = _copy_capture_tree(root)
                path = _exported_path(root, capture, ".frm")
                if mutation == "missing":
                    path.unlink()
                    message = "missing"
                else:
                    raw = bytearray(path.read_bytes())
                    raw[-1] ^= 1
                    path.write_bytes(raw)
                    message = "SHA-256 drift"
                with self.assertRaisesRegex(facts.FactError, message):
                    facts._validate_manifest_self_pins(root, capture, manifest)

    def test_manifest_self_pins_rejects_unsafe_path_and_unmanifested_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            capture, manifest = _copy_capture_tree(root)
            capture["forms"][0]["exported_files"][0]["path"] = "../escaped.frm"
            with self.assertRaisesRegex(facts.FactError, "not a safe repository-relative"):
                facts._validate_manifest_self_pins(root, capture, manifest)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            capture, manifest = _copy_capture_tree(root)
            _write(manifest.parent / "unmanifested.bin", b"surprise")
            with self.assertRaisesRegex(facts.FactError, "file set differs"):
                facts._validate_manifest_self_pins(root, capture, manifest)

    def test_manifest_self_pins_rejects_unexpected_subdirectory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            capture, manifest = _copy_capture_tree(root)
            (manifest.parent / "unexpected-directory").mkdir()
            with self.assertRaisesRegex(
                facts.FactError, "file set differs|regular non-reparse"
            ):
                facts._validate_manifest_self_pins(root, capture, manifest)

    def test_manifest_self_pins_rejects_symlinked_export_masquerade(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            capture, manifest = _copy_capture_tree(root)
            exported = _exported_path(root, capture, ".frm")
            target = root / "symlink-target.frm"
            shutil.copyfile(exported, target)
            exported.unlink()
            try:
                exported.symlink_to(target)
            except (NotImplementedError, OSError) as exc:
                self.skipTest(f"symbolic links are unavailable: {exc}")
            with self.assertRaisesRegex(facts.FactError, "symlink|reparse"):
                facts._validate_manifest_self_pins(root, capture, manifest)

    def test_exported_file_rows_cannot_be_duplicated_or_shape_extended(self) -> None:
        spec = facts.load_json_strict(CAPTURE_SPEC_PATH)
        capture = facts.load_json_strict(CAPTURE_MANIFEST_PATH)
        capture["forms"][0]["exported_files"].append(
            copy.deepcopy(capture["forms"][0]["exported_files"][0])
        )
        with self.assertRaisesRegex(facts.FactError, "exactly one .frm and one .frx"):
            facts._validate_capture_pair(spec, capture)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            copied, manifest = _copy_capture_tree(root)
            copied["forms"][0]["exported_files"].append(
                copy.deepcopy(copied["forms"][0]["exported_files"][0])
            )
            with self.assertRaisesRegex(facts.FactError, "exactly one .frm and one .frx"):
                facts._validate_manifest_self_pins(root, copied, manifest)
            with self.assertRaisesRegex(facts.FactError, "exactly one .frm and one .frx"):
                facts._fixture_facts(root, copied, spec)

        capture = facts.load_json_strict(CAPTURE_MANIFEST_PATH)
        capture["forms"][0]["exported_files"][0]["invented"] = True
        with self.assertRaisesRegex(facts.FactError, "keys differ"):
            facts._validate_capture_pair(spec, capture)

    def test_failed_property_probe_cannot_be_counted_as_successful_coverage(self) -> None:
        pins = facts.load_pins(PINS_PATH)
        local = facts.verify_local_dependencies(REPO_ROOT, pins)
        ms_oforms = local["W010-MS-OFORMS-FACTS"]["value"]
        capture = copy.deepcopy(local["LIVE-EXPORT-CAPTURE-MANIFEST"]["value"])
        image = next(
            control
            for form in capture["forms"]
            for control in form["controls"]
            if control["name"] == "ImageProbe"
        )
        auto_size = next(
            probe for probe in image["properties"] if probe["name"] == "AutoSize"
        )
        auto_size.update(
            {
                "succeeded": False,
                "error": "forced failure for mutation test",
                "hresult": "0x80004005",
                "readback": None,
            }
        )
        mapping = next(
            row
            for row in facts._property_mappings(ms_oforms, capture)
            if row["name"] == "AutoSize"
        )
        self.assertEqual(
            mapping["classification"],
            "failed_live_public_property_probe_exact_name",
        )
        self.assertEqual(mapping["family_coverage"][0]["status"], "failed_exact_name_live_probe")
        self.assertEqual(mapping["family_coverage"][0]["successful_probe_count"], 0)
        self.assertEqual(mapping["family_coverage"][0]["failed_probe_count"], 1)

        clsid_mapping = next(
            row
            for row in facts._property_mappings(ms_oforms, capture)
            if row["name"] == "ClsidCacheIndex"
        )
        owners = clsid_mapping["family_coverage"][0]["probe_owners"]
        self.assertEqual(len(owners), 24)
        self.assertTrue(all(owner.startswith("registry:Forms.") for owner in owners))

    def test_failed_userform_geometry_cannot_be_contextual_success(self) -> None:
        ms_oforms = facts.load_json_strict(
            REPO_ROOT
            / "docs"
            / "evidence"
            / "W010_complete_msforms_object_model_parity"
            / "beads"
            / "oxforms-jbjp.3"
            / "ms_oforms_persistence_facts.v1.json"
        )
        capture = facts.load_json_strict(CAPTURE_MANIFEST_PATH)
        geometry_names = {
            "Left",
            "Top",
            "Width",
            "Height",
            "ScrollLeft",
            "ScrollTop",
            "ScrollWidth",
            "ScrollHeight",
        }
        for form in capture["forms"]:
            for probe in form["component_properties"]:
                if probe["name"] in geometry_names:
                    probe.update(
                        {
                            "succeeded": False,
                            "error": "forced failure for mutation test",
                            "hresult": "0x80004005",
                            "readback": None,
                        }
                    )
        mapping = next(
            row
            for row in facts._property_mappings(ms_oforms, capture)
            if row["name"] == "LogicalSize"
        )
        coverage = next(
            row for row in mapping["family_coverage"] if row["family"] == "Form"
        )
        self.assertNotEqual(
            mapping["classification"],
            "live_context_only_not_exact_property_probe",
        )
        self.assertNotEqual(coverage["status"], "context_only_not_exact_probe")
        self.assertEqual(coverage["successful_probe_count"], 0)

    def test_fixture_rebuild_rejects_unsafe_or_missing_resource_reference(self) -> None:
        for mutation in ("unsafe", "missing"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                capture, _ = _copy_capture_tree(root)
                path = _exported_path(root, capture, ".frm")
                raw = path.read_bytes()
                line = next(
                    row for row in raw.splitlines(keepends=True) if b"OleObjectBlob" in row
                )
                if mutation == "unsafe":
                    changed = line.replace(b'"W010OuterDefaults.frx"', b'"../outside.frx"')
                else:
                    changed = b""
                self.assertNotEqual(line, changed)
                path.write_bytes(raw.replace(line, changed, 1))
                error = facts.FactError if mutation == "unsafe" else facts.FRMError
                with self.assertRaises(error):
                    facts._fixture_facts(
                        root,
                        capture,
                        facts.load_json_strict(CAPTURE_SPEC_PATH),
                    )

    def test_fixture_rebuild_rejects_wrong_encoding_mixed_newlines_and_bad_grammar(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            capture, _ = _copy_capture_tree(root)
            capture["environment"]["ansi_code_page"] = "cputf-8"
            with self.assertRaisesRegex(facts.FactError, "positive integer"):
                facts._fixture_facts(
                    root,
                    capture,
                    facts.load_json_strict(CAPTURE_SPEC_PATH),
                )

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            capture, _ = _copy_capture_tree(root)
            capture["environment"]["ansi_code_page"] = 65001
            with self.assertRaisesRegex(facts.FRMError, "not valid utf-8"):
                facts._fixture_facts(
                    root,
                    capture,
                    facts.load_json_strict(CAPTURE_SPEC_PATH),
                )

        mutations = (
            ("mixed newline", lambda raw: raw.replace(b"\r\n", b"\n", 1), "newline"),
            (
                "bad version",
                lambda raw: raw.replace(b"VERSION 5.00", b"VERSION 4.00", 1),
                "VERSION",
            ),
        )
        for name, mutation, message in mutations:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                capture, _ = _copy_capture_tree(root)
                path = _exported_path(root, capture, ".frm")
                path.write_bytes(mutation(path.read_bytes()))
                with self.assertRaisesRegex(facts.FRMError, message):
                    facts._fixture_facts(
                        root,
                        capture,
                        facts.load_json_strict(CAPTURE_SPEC_PATH),
                    )

    def test_fixture_rebuild_rejects_truncated_or_signatureless_cfb(self) -> None:
        for mutation in ("truncated", "signature"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                capture, _ = _copy_capture_tree(root)
                path = _exported_path(root, capture, ".frx")
                raw = path.read_bytes()
                if mutation == "truncated":
                    path.write_bytes(raw[:-1])
                else:
                    changed = bytearray(raw)
                    changed[24] ^= 0xFF
                    path.write_bytes(changed)
                with self.assertRaises(facts.CFBError):
                    facts._fixture_facts(
                        root,
                        capture,
                        facts.load_json_strict(CAPTURE_SPEC_PATH),
                    )


class DeterministicSurfaceIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.pins = facts.load_pins(PINS_PATH)
        cls.pack = facts.load_canonical_fact_pack(FACTS_PATH)

    def test_committed_local_surfaces_rebuild_exactly(self) -> None:
        facts.validate_local_surfaces(self.pack, REPO_ROOT, self.pins)

    def test_local_rebuild_detects_mutated_derived_surfaces(self) -> None:
        mutations = (
            (
                "fixtures",
                lambda pack: pack["fixtures"][0].__setitem__(
                    "component_name", "MutatedForm"
                ),
                "committed fixtures differs",
            ),
            (
                "property mappings",
                lambda pack: pack["property_mappings"][0].__setitem__(
                    "reason", "invented"
                ),
                "committed property_mappings differs",
            ),
            (
                "designer",
                lambda pack: pack["designer_properties"][
                    "controlled_omission_pairs"
                ][0].__setitem__("proof", "invented"),
                "committed designer_properties differs",
            ),
            (
                "summary",
                lambda pack: pack["summary"].__setitem__(
                    "cfb_streams", pack["summary"]["cfb_streams"] + 1
                ),
                "committed summary differs",
            ),
        )
        for name, mutation, message in mutations:
            with self.subTest(name=name):
                pack = copy.deepcopy(self.pack)
                mutation(pack)
                with self.assertRaisesRegex(facts.FactError, message):
                    facts.validate_local_surfaces(pack, REPO_ROOT, self.pins)

    @unittest.skipUnless(
        os.environ.get("OXFORMS_REQUIRE_PERSISTENCE_SOURCES") == "1",
        "set OXFORMS_REQUIRE_PERSISTENCE_SOURCES=1 for pinned Foundation checks",
    )
    def test_validator_performs_source_required_full_regeneration(self) -> None:
        result = subprocess.run(
            [sys.executable, str(VALIDATE_SCRIPT), "--require-sources"],
            cwd=REPO_ROOT,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("FRM/FRX export facts valid", result.stdout)

    @unittest.skipUnless(
        os.environ.get("OXFORMS_REQUIRE_PERSISTENCE_SOURCES") == "1",
        "set OXFORMS_REQUIRE_PERSISTENCE_SOURCES=1 for pinned Foundation checks",
    )
    def test_exporter_check_generates_twice_and_matches_committed_bytes(self) -> None:
        result = subprocess.run(
            [sys.executable, str(EXPORT_SCRIPT), "--check"],
            cwd=REPO_ROOT,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=180,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("matched", result.stdout)


if __name__ == "__main__":
    unittest.main()
