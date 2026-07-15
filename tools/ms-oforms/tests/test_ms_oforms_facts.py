from __future__ import annotations

import copy
import hashlib
import subprocess
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path
from unittest.mock import patch


MODULE_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = MODULE_DIR.parents[1]
sys.path.insert(0, str(MODULE_DIR))

from ms_oforms_facts import (  # noqa: E402
    FactError,
    _segment_concatenated,
    _selected_toc_sections,
    build_fact_pack,
    canonical_json_bytes,
    canonical_text_bytes,
    load_canonical_json,
    load_json_strict,
    load_pins,
    loads_json_strict,
    validate_fact_pack,
    verify_source_pins,
)


PINS_PATH = MODULE_DIR / "pinned_sources.v1.json"
EXPECTED_PATH = MODULE_DIR / "expected_capture.v1.json"
FACTS_PATH = (
    REPO_ROOT
    / "docs"
    / "evidence"
    / "W010_complete_msforms_object_model_parity"
    / "beads"
    / "oxforms-jbjp.3"
    / "ms_oforms_persistence_facts.v1.json"
)


class MSOFormsFactsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.pins = load_pins(PINS_PATH)
        cls.expected = load_json_strict(EXPECTED_PATH)
        cls.pack = load_canonical_json(FACTS_PATH)
        cls.pins_sha = hashlib.sha256(PINS_PATH.read_bytes()).hexdigest()

    def validate(self, pack: dict) -> None:
        validate_fact_pack(
            pack,
            self.pins,
            self.expected,
            pinned_sources_sha256=self.pins_sha,
        )

    def test_committed_pack_is_valid(self) -> None:
        self.validate(self.pack)

    def test_exact_census_and_boundaries_are_frozen(self) -> None:
        summary = self.pack["summary"]
        self.assertEqual(summary["source_segments"], 8024)
        self.assertEqual(summary["properties"], 98)
        self.assertEqual(summary["documented_defaults"], 95)
        self.assertEqual(summary["mandatory_persist_no_default"], 3)
        self.assertEqual(summary["prop_masks"], 15)
        self.assertEqual(summary["bitfields"], 28)
        self.assertEqual(summary["bit_entries"], 320)
        self.assertEqual(summary["record_fields"], 431)
        self.assertEqual(summary["record_sections"], 90)
        self.assertEqual(summary["record_section_requirements"], 37)
        self.assertEqual(summary["record_tables"], 71)
        self.assertEqual(summary["type_tables"], 16)
        self.assertEqual(summary["documented_unknown_rows"], 179)
        self.assertEqual(summary["enum_definitions"], 26)
        self.assertEqual(summary["enum_values"], 132)
        self.assertEqual(summary["product_behavior_rows"], 20)
        self.assertEqual(summary["external_reference_standards"], 22)
        self.assertEqual(summary["external_reference_occurrences"], 103)
        self.assertEqual(summary["algorithm_contexts"], 1)
        self.assertEqual(summary["algorithm_procedures"], 3)
        self.assertEqual(summary["property_value_domain_tables"], 3)
        self.assertEqual(summary["property_value_domain_rows"], 8)
        self.assertEqual(summary["resource_formats"], 10)
        self.assertEqual(summary["value_map_definitions"], 3)
        self.assertEqual(summary["value_map_values"], 8)
        self.assertEqual(self.pack["boundaries"]["runtime_api_claims"], [])
        self.assertEqual(self.pack["boundaries"]["oracle_only_rows"], [])

    def test_record_fields_cover_mixed_bitfield_sections_and_normative_constraints(self) -> None:
        mixed = {
            row["name"]
            for row in self.pack["record_fields"]
            if row["section"] == "2.2.10.7"
        }
        self.assertIn("Depth", mixed)
        self.assertIn("OptionalType", mixed)
        mixed_bitfield = next(
            row for row in self.pack["bitfields"] if row["section"] == "2.2.10.7"
        )
        count_entry = next(
            row for row in mixed_bitfield["entries"] if row["field_name"] == "fCount"
        )
        self.assertEqual(count_entry["supplemental_rows"], [])
        self.assertEqual(
            sum(
                row["name"] in {"Depth", "OptionalType"}
                for row in self.pack["record_fields"]
                if row["section"] == "2.2.10.7"
            ),
            2,
        )

        normative = [row for row in self.pack["record_fields"] if row["requirements"]]
        self.assertEqual(len(normative), 157)
        self.assertTrue(all("normative_requirement" in row["constraints"] for row in normative))
        set_value_rows = [
            row
            for row in self.pack["record_fields"]
            if "must be set to" in row["description"].lower()
        ]
        self.assertEqual(len(set_value_rows), 63)
        self.assertTrue(
            all(row["requirements"][0]["value_constraints"] for row in set_value_rows)
        )
        for name in ("GetBindIndex", "PutBindIndex", "GetValueIndex", "PutValueIndex"):
            field = next(
                row
                for row in self.pack["record_fields"]
                if row["section"] == "2.2.10.10.3" and row["name"] == name
            )
            subjects = {
                value["subject"]
                for value in field["requirements"][0]["value_constraints"]
            }
            self.assertEqual(subjects, {"FUNCDESC.invkind", "FUNCDESC.memid"})
            expected_operations = (
                [["forbid_value"], ["set_value"]]
                if name in {"GetBindIndex", "PutBindIndex"}
                else [["set_value"], ["set_value"]]
            )
            self.assertEqual(
                [
                    clause["operations"]
                    for clause in field["requirements"][0]["operation_constraints"]
                ],
                expected_operations,
            )

        ranges = {
            row["name"]: row["requirements"][0]["range_constraints"]
            for row in self.pack["record_fields"]
            if row["name"]
            in {
                "ItemsSize",
                "TipStringsSize",
                "NamesSize",
                "TagsSize",
                "AcceleratorsSize",
                "sWeight",
                "ulHeight",
                "bFaceLen",
            }
        }
        self.assertEqual(len(ranges), 8)
        self.assertTrue(all(len(value) == 1 for value in ranges.values()))
        self.assertEqual(
            ranges["ulHeight"][0]["maximum"],
            {"inclusive": True, "value": 655350000},
        )
        self.assertEqual(
            ranges["bFaceLen"][0]["maximum"],
            {"inclusive": False, "value": 32},
        )

    def test_property_mask_semantics_are_exhaustive_and_non_conflating(self) -> None:
        semantics = Counter(
            entry["semantics"]
            for bitfield in self.pack["bitfields"]
            if bitfield["kind"] == "property_presence_mask"
            for entry in bitfield["entries"]
        )
        self.assertEqual(
            semantics,
            Counter(
                {
                    "separate_storage_presence": 176,
                    "reserved_or_unused": 33,
                    "inline_default_state": 8,
                    "correlated_constraint": 4,
                }
            ),
        )

        non_masks = [
            entry
            for bitfield in self.pack["bitfields"]
            if bitfield["kind"] != "property_presence_mask"
            for entry in bitfield["entries"]
        ]
        self.assertEqual(
            Counter(entry["semantics"] for entry in non_masks),
            Counter(
                {
                    "boolean_flag": 74,
                    "reserved_or_unused": 19,
                    "packed_scalar": 6,
                }
            ),
        )
        site_flag = next(row for row in self.pack["bitfields"] if row["name"] == "SITE_FLAG")
        promote = next(row for row in site_flag["entries"] if row["field_name"] == "fPromoteControls")
        self.assertTrue(promote["requirements"])
        self.assertTrue(promote["requirements"][0]["conditional"])
        self.assertTrue(
            all(
                value["scope_text"]
                for value in promote["requirements"][0]["value_constraints"]
            )
        )
        various = next(
            row for row in self.pack["bitfields"] if row["name"] == "VariousPropertiesBitfield"
        )
        editable = next(row for row in various["entries"] if row["field_name"] == "Editable")
        self.assertEqual(editable["semantics"], "boolean_flag")
        self.assertTrue(editable["requirements"][0]["conditional"])
        self.assertEqual(
            [value["level"] for value in editable["requirements"][0]["value_constraints"]],
            ["must", "must", "should", "may"],
        )
        self.assertEqual(
            [
                value["obligation"]
                for value in editable["requirements"][0]["value_constraints"]
            ],
            ["required", "required", "recommended", "permitted"],
        )
        should_value, may_value = editable["requirements"][0]["value_constraints"][-2:]
        self.assertEqual(should_value["scope_source"], "explicit")
        self.assertEqual(may_value["scope_source"], "inherited")
        self.assertEqual(should_value["scope_text"], may_value["scope_text"])
        ignore = next(
            clause
            for clause in editable["requirements"][0]["operation_constraints"]
            if clause["operations"] == ["ignore_on_read"]
        )
        self.assertEqual(ignore["scope_source"], "inherited")
        self.assertEqual(ignore["scope_text"], may_value["scope_text"])

        font_pitch = next(
            row
            for row in self.pack["bitfields"]
            if row["name"] == "fmFontPitchAndFamily"
        )
        self.assertEqual(font_pitch["total_bits"], 8)
        self.assertEqual(
            [entry["field_name"] for entry in font_pitch["entries"]],
            ["Pitch", "Family"],
        )

    def test_bitfield_section_and_entry_qualifiers_are_preserved(self) -> None:
        applies_rows = [
            row
            for bitfield in self.pack["bitfields"]
            for entry in bitfield["entries"]
            for row in entry["supplemental_rows"]
            if row["applies_to"] is not None
        ]
        self.assertEqual(len(applies_rows), 23)
        self.assertTrue(all(row["applies_to"] for row in applies_rows))
        self.assertTrue(
            all(control == control.rstrip(".") for row in applies_rows for control in row["applies_to"])
        )
        various = next(
            row
            for row in self.pack["bitfields"]
            if row["name"] == "VariousPropertiesBitfield"
        )
        autosize = next(
            row for row in various["entries"] if row["field_name"] == "AutoSize"
        )
        autosize_rule = next(
            row
            for row in autosize["supplemental_rows"]
            if row["source"]["segment_id"].endswith("SEG-006678")
        )
        self.assertTrue(autosize_rule["requirements"])
        self.assertEqual(
            autosize_rule["requirements"][0]["value_constraints"][0]["value"]["value"],
            0,
        )
        self.assertNotIn("Image", autosize["supplemental_rows"][-1]["applies_to"])

        for name, segment in (
            ("MorphDataPropMask", "SEG-001691"),
            ("SITE_FLAG", "SEG-005350"),
        ):
            bitfield = next(row for row in self.pack["bitfields"] if row["name"] == name)
            qualifier = next(
                row
                for row in bitfield["section_rows"]
                if row["source"]["segment_id"].endswith(segment)
            )
            self.assertTrue(qualifier["requirements"])

    def test_record_section_requirements_preserve_aggregate_invariants(self) -> None:
        self.assertEqual(len(self.pack["record_sections"]), 90)
        requirements = [
            row
            for section in self.pack["record_sections"]
            for row in section["section_requirements"]
        ]
        self.assertEqual(len(requirements), 37)
        tab_strip = next(
            row
            for row in self.pack["record_sections"]
            if row["name"] == "TabStripExtraDataBlock"
        )
        by_segment = {
            row["source"]["segment_id"].rsplit("-", 1)[-1]: row
            for row in tab_strip["section_requirements"]
        }
        self.assertEqual(set(by_segment), {"003202", "003203", "003204"})
        self.assertEqual(
            by_segment["003203"]["requirements"][0]["operations"],
            ["require_storage"],
        )
        self.assertEqual(
            by_segment["003204"]["requirements"][0]["operations"],
            ["order_constraint"],
        )

    def test_defaults_are_typed_and_symbolic_flag_provenance_is_complete(self) -> None:
        kinds = Counter(row["normalized_value"]["kind"] for row in self.pack["default_matrix"])
        self.assertEqual(
            kinds,
            Counter(
                {
                    "hex_scalar": 76,
                    "empty_string": 9,
                    "boolean": 7,
                    "decimal_scalar": 4,
                    "mandatory_persist_no_default": 3,
                    "resource_absent": 3,
                    "size": 2,
                    "point": 2,
                    "string": 1,
                }
            ),
        )
        by_section = {
            row["property_section"]: row
            for row in self.pack["default_matrix"]
            if row["default_kind"] != "control_specific"
        }
        self.assertEqual(
            by_section["2.5.49"]["normalized_value"]["resource_type"],
            "GuidAndPicture",
        )
        dx_mode = by_section["2.5.5"]
        self.assertEqual(len(dx_mode["source_refs"]), 12)
        self.assertEqual(
            [row["name"] for row in dx_mode["normalized_value"]["set_flags"]],
            [
                "fInheritDesign",
                "fInheritShowToolbox",
                "fInheritShowGrid",
                "fInheritSnapToGrid",
                "fInheritGridX",
                "fInheritGridY",
                "fInheritClickControl",
                "fInheritDblClickControl",
                "fInheritShowInvisible",
                "fInheritShowTooltips",
                "fInheritLayoutImmediate",
            ],
        )
        self.assertEqual(
            {row["name"] for row in by_section["2.5.29"]["normalized_value"]["symbols"]},
            {"DEFAULT_PITCH", "FF_DONTCARE"},
        )

    def test_property_value_domains_and_table_ownership_are_complete(self) -> None:
        properties = {
            row["name"]: row
            for row in self.pack["properties"]
            if row["value_domain_rows"]
        }
        self.assertEqual(set(properties), {"BoundColumn", "TextColumn", "Value"})
        self.assertEqual(
            [row["selector"] for row in properties["BoundColumn"]["value_domain_rows"]],
            [
                {"kind": "exact_integer", "raw": "0", "value": 0},
                {
                    "inclusive_minimum": 1,
                    "kind": "integer_range",
                    "maximum_not_specified": True,
                    "raw": "1 or greater",
                },
            ],
        )
        self.assertEqual(
            [row["selector"]["kind"] for row in properties["TextColumn"]["value_domain_rows"]],
            ["exact_integer", "exact_integer", "integer_range"],
        )
        value_rows = properties["Value"]["value_domain_rows"]
        self.assertEqual(
            [row["selector"]["controls"] for row in value_rows],
            [
                ["CheckBox", "OptionButton", "ToggleButton"],
                ["ComboBox", "ListBox"],
                ["TextBox"],
            ],
        )
        value_requirement = value_rows[1]["requirements"][0]
        self.assertEqual(value_requirement["operations"], ["require_zero_length_string"])
        self.assertEqual(
            value_requirement["value_constraints"][0]["subject"], "property:Value"
        )

        owners: dict[int, set[str]] = {}

        def own(table: int, owner: str) -> None:
            owners.setdefault(table, set()).add(owner)

        for row in self.pack["default_matrix"]:
            for source in row["source_refs"]:
                if "table" in source:
                    own(source["table"], "default")
        for enumeration in self.pack["enumerations"]:
            for value in enumeration["values"]:
                for source in value["source_refs"]:
                    if "table" in source:
                        own(source["table"], "enumeration")
        for bitfield in self.pack["bitfields"]:
            for table in bitfield["table_ids"]:
                own(table, "bitfield")
        for prop in properties.values():
            for row in prop["value_domain_rows"]:
                own(row["table"], "property_value_domain")
        self.assertEqual(set(range(92, 133)), set(owners) & set(range(92, 133)))
        self.assertTrue(all(len(owners[table]) == 1 for table in range(92, 133)))

    def test_applicability_tokens_and_behavior_markers_are_separate(self) -> None:
        properties = {row["section"]: row for row in self.pack["properties"]}
        for section in ("2.5.56", "2.5.69"):
            self.assertEqual(properties[section]["applies_to"], ["ScrollBar", "SpinButton"])
        caption = properties["2.5.10"]
        self.assertIn("Form", caption["applies_to"])
        self.assertNotIn("Form<2>", caption["applies_to"])
        self.assertEqual(
            caption["applies_to_behavior_refs"],
            [{"control": "Form", "footnote": 2, "scope": "control"}],
        )

    def test_unknown_handling_preserves_combined_read_write_obligations(self) -> None:
        by_suffix = {
            row["source"]["segment_id"].rsplit("-", 1)[-1]: row
            for row in self.pack["documented_unknowns"]
        }
        self.assertNotIn("000645", by_suffix)
        self.assertNotIn("005651", by_suffix)
        self.assertIn("006471", by_suffix)
        self.assertEqual(
            by_suffix["003504"]["handling"],
            {
                "read_requirements": ["must_ignore"],
                "write_requirements": ["must_set_zero"],
            },
        )
        self.assertEqual(
            by_suffix["007094"]["handling"]["read_requirements"],
            ["documented_ignored"],
        )
        self.assertEqual(
            Counter(row["classification"] for row in self.pack["documented_unknowns"]),
            Counter(
                {
                    "documented_normative_unknown_constraint": 155,
                    "documented_worked_example_unknown_observation": 24,
                }
            ),
        )

    def test_external_reference_boundary_includes_mixed_case_names(self) -> None:
        expected = {
            "ECMA-376",
            "GIF89a",
            "JFIF",
            "MC-IcoWin32",
            "MS-CFB",
            "MS-DOC",
            "MS-DTYP",
            "MS-EMF",
            "MS-OAUT",
            "MS-OLEDS",
            "MS-OSHARED",
            "MS-OVBA",
            "MS-PPT",
            "MS-WMF",
            "MS-XLS",
            "MS-XLSB",
            "MSDN-IDPD",
            "MSDN-IPersistStream",
            "MSDN-IPropertyBag",
            "MSDN-IStorage",
            "MSDN-IStream",
            "RFC4234",
        }
        self.assertEqual(
            {row["reference"] for row in self.pack["external_references"]}, expected
        )
        self.assertNotIn("image", expected)

    def test_product_behavior_has_exact_bidirectional_source_links(self) -> None:
        self.assertEqual(
            [row["footnote"] for row in self.pack["product_behavior"]], list(range(1, 21))
        )
        self.assertEqual(
            len({row["referenced_source"]["segment_id"] for row in self.pack["product_behavior"]}),
            20,
        )
        self.assertTrue(
            all(row["referenced_section"] for row in self.pack["product_behavior"])
        )

    def test_algorithm_hierarchy_and_discriminator_maps_are_explicit(self) -> None:
        algorithms = {row["section"]: row for row in self.pack["algorithms"]}
        number = algorithms["2.1.1.1.3.1"]
        self.assertEqual(
            number["classification"], "documented_normative_algorithm_procedure"
        )
        self.assertEqual((len(number["context_rows"]), len(number["steps"])), (4, 15))
        self.assertEqual(algorithms["2.6.1"]["classification"], "documented_algorithm_context")
        self.assertEqual(algorithms["2.6.1"]["steps"], [])
        self.assertEqual(
            algorithms["2.6.1"]["member_sections"],
            ["2.6.1", "2.6.1.1", "2.6.1.2"],
        )
        self.assertEqual(
            {algorithms[section]["classification"] for section in ("2.6.1.1", "2.6.1.2")},
            {"documented_normative_algorithm_procedure"},
        )
        self.assertEqual(len(algorithms["2.6.1.1"]["steps"]), 36)
        self.assertEqual(len(algorithms["2.6.1.2"]["steps"]), 20)
        continued = [
            step
            for section in ("2.6.1.1", "2.6.1.2")
            for step in algorithms[section]["steps"]
            if len(step["source_refs"]) == 2
        ]
        self.assertEqual(len(continued), 6)
        self.assertTrue(
            all("source" not in step and len(step["source_refs"]) >= 1 for step in continued)
        )
        site_type = next(row for row in self.pack["enumerations"] if row["name"] == "SITE_TYPE")
        self.assertEqual(site_type["classification"], "documented_named_constant_table")
        self.assertEqual(site_type["values"][0]["name"], "ST_Ole")
        self.assertEqual(
            {row["map_id"] for row in self.pack["value_maps"]},
            {"property_bag_tab_flag", "property_bag_bool", "form_font_guid"},
        )

    def test_resource_formats_expose_picture_and_string_decoder_rules(self) -> None:
        resources = {row["name"]: row for row in self.pack["resource_formats"]}
        self.assertEqual(len(resources), 10)
        picture = resources["StdPicture"]
        self.assertEqual(
            [row["format_name"] for row in picture["supported_formats"]],
            [
                "Bitmap",
                "GIF image",
                "JPEG image",
                "Windows Metafile",
                "Enhanced Metafile",
                "Icon",
            ],
        )
        strings = resources["Strings"]
        self.assertEqual(
            strings["member_sections"],
            ["2.4.14", "2.4.14.1", "2.4.14.2", "2.4.14.3", "2.4.14.4"],
        )
        codec = strings["codec"]
        self.assertEqual(codec["compression"]["transformation"], "remove_all_0x00_bytes")
        self.assertFalse(codec["compression"]["zero_length_compressible"])
        self.assertEqual(
            codec["zero_length_representation"]["CountOfBytesWithCompressionFlag"],
            {"cb": 0, "fCompressed": 0},
        )
        self.assertFalse(codec["null_terminators"]["stored"])
        self.assertFalse(codec["null_terminators"]["included_in_count"])

        unclassified = []

        def visit(value: object, path: str = "") -> None:
            if isinstance(value, dict):
                if value.get("normalization") and "other_normative_constraint" in value.get(
                    "operations", []
                ):
                    unclassified.append(path)
                for key, child in value.items():
                    visit(child, f"{path}/{key}")
            elif isinstance(value, list):
                for index, child in enumerate(value):
                    visit(child, f"{path}/{index}")

        visit(self.pack)
        self.assertEqual(unclassified, [])

    def test_composite_control_families_link_shared_records_and_mapping_prose(self) -> None:
        families = {row["family_id"]: row for row in self.pack["control_families"]}
        morph_sources = {
            row["source"]["segment_id"].rsplit("-", 1)[-1]
            for row in families["morph_data"]["mapping_sources"]
        }
        self.assertIn("001630", morph_sources)
        frame_roots = {
            section
            for dependency in families["frame"]["persistence_dependencies"]
            for section in dependency["section_roots"]
        }
        self.assertIn("2.2.10", frame_roots)
        multipage_roots = {
            section
            for dependency in families["multi_page"]["persistence_dependencies"]
            for section in dependency["section_roots"]
        }
        self.assertTrue({"2.2.9", "2.2.10", "2.2.6.4"}.issubset(multipage_roots))
        user_form_roots = {
            section
            for dependency in families["user_form_site_container"]["persistence_dependencies"]
            for section in dependency["section_roots"]
        }
        self.assertIn("2.1.1.2", user_form_roots)

    def test_strict_json_rejects_duplicate_and_nonfinite_values(self) -> None:
        with self.assertRaisesRegex(FactError, "duplicate JSON key"):
            loads_json_strict('{"same": 1, "same": 2}')
        with self.assertRaisesRegex(FactError, "non-finite JSON value"):
            loads_json_strict('{"value": NaN}')

    def test_canonical_json_loader_rejects_formatting_and_crlf_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "facts.json"
            path.write_bytes(b'{"value": 1}\r\n')
            with self.assertRaisesRegex(FactError, "not canonical"):
                load_canonical_json(path)
            path.write_bytes(canonical_json_bytes({"value": 1}))
            self.assertEqual(load_canonical_json(path), {"value": 1})

    def test_source_pin_paths_reject_escape_drive_and_empty_components(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "pins.json"
            for invalid in ("../escape", "C:/escape", "a//b", "a/./b"):
                changed = copy.deepcopy(self.pins)
                changed["sources"][0]["path"] = invalid
                path.write_bytes(canonical_json_bytes(changed))
                with self.subTest(invalid=invalid):
                    with self.assertRaisesRegex(FactError, "Foundation-relative POSIX"):
                        load_pins(path)

    def test_selected_toc_span_rejects_a_middle_gap(self) -> None:
        prefix = [(f"0.{index}", f"Before {index}") for index in range(22)]
        toc = [
            *prefix,
            ("1.3.1", "Saving Controls"),
            ("2.1", "Middle"),
            ("4", "Change Tracking"),
        ]
        self.assertEqual(
            _selected_toc_sections(
                toc,
                ["Saving Controls", "Middle"],
                "Saving Controls",
                "Change Tracking",
            ),
            ["1.3.1", "2.1"],
        )
        del toc[23]
        with self.assertRaisesRegex(FactError, "heading/TOC gap"):
            _selected_toc_sections(
                toc,
                ["Saving Controls", "Middle"],
                "Saving Controls",
                "Change Tracking",
            )

    def test_source_row_deletion_is_rejected(self) -> None:
        changed = copy.deepcopy(self.pack)
        del changed["source_rows"][100]
        with self.assertRaisesRegex(FactError, "source-row count"):
            self.validate(changed)

    def test_source_row_leaf_types_are_exact(self) -> None:
        source_rows = copy.deepcopy(self.pack["source_rows"])
        source_rows[0]["is_blank"] = 0
        changed = build_fact_pack(source_rows, self.pins)
        with self.assertRaisesRegex(FactError, "is_blank must be a Boolean"):
            validate_fact_pack(changed, self.pins)

        source_rows = copy.deepcopy(self.pack["source_rows"])
        table_cell = next(row for row in source_rows if row["kind"] == "table_cell")
        table_cell["column"] = float(table_cell["column"])
        changed = build_fact_pack(source_rows, self.pins)
        with self.assertRaisesRegex(FactError, "column must be a positive integer"):
            validate_fact_pack(changed, self.pins)

        source_rows = copy.deepcopy(self.pack["source_rows"])
        table_cell = next(row for row in source_rows if row["kind"] == "table_cell")
        table_cell["column"] = 0
        changed = build_fact_pack(source_rows, self.pins)
        with self.assertRaisesRegex(FactError, "column must be a positive integer"):
            validate_fact_pack(changed, self.pins)

        source_rows = copy.deepcopy(self.pack["source_rows"])
        source_rows[0]["anchor"] = "invented"
        changed = build_fact_pack(source_rows, self.pins)
        with self.assertRaisesRegex(FactError, "paragraph anchor drift"):
            validate_fact_pack(changed, self.pins)

        source_rows = copy.deepcopy(self.pack["source_rows"])
        source_rows[0]["segment_id"] = "invented-SEG-000631"
        changed = build_fact_pack(source_rows, self.pins)
        with self.assertRaisesRegex(FactError, "not contiguous"):
            validate_fact_pack(changed, self.pins)

        source_rows = copy.deepcopy(self.pack["source_rows"])
        image = next(row for row in source_rows if row["kind"] == "image_ref")
        image["asset_id"] = "invented"
        changed = build_fact_pack(source_rows, self.pins)
        with self.assertRaisesRegex(FactError, "image-reference census drifted"):
            validate_fact_pack(changed, self.pins)

        source_rows = copy.deepcopy(self.pack["source_rows"])
        blank = next(row for row in source_rows if row["is_blank"])
        blank["text"] = ""
        changed = build_fact_pack(source_rows, self.pins)
        with self.assertRaisesRegex(FactError, "blank-row marker drift"):
            validate_fact_pack(changed, self.pins)

    def test_property_default_rewrite_is_rejected(self) -> None:
        changed = copy.deepcopy(self.pack)
        changed["properties"][0]["default"]["text"] = "The file format default is invented."
        with self.assertRaisesRegex(FactError, "derived fact surface drifted: properties"):
            self.validate(changed)

    def test_mask_offset_rewrite_is_rejected(self) -> None:
        changed = copy.deepcopy(self.pack)
        changed["bitfields"][0]["entries"][0]["bit_offset"] = 7
        with self.assertRaisesRegex(FactError, "derived fact surface drifted: bitfields"):
            self.validate(changed)

    def test_equal_numeric_type_mutations_are_rejected_without_review_freeze(self) -> None:
        mutations = []

        changed = copy.deepcopy(self.pack)
        changed["summary"]["source_segments"] = 8024.0
        mutations.append((changed, "summary"))

        changed = copy.deepcopy(self.pack)
        entry = next(
            item
            for bitfield in changed["bitfields"]
            for item in bitfield["entries"]
            if item["bit_offset"] == 1
        )
        entry["bit_offset"] = True
        mutations.append((changed, "bitfields"))

        for changed, surface in mutations:
            with self.subTest(surface=surface):
                with self.assertRaisesRegex(
                    FactError, f"derived fact surface drifted: {surface}"
                ):
                    validate_fact_pack(changed, self.pins)

    def test_reviewed_summary_numeric_types_are_exact(self) -> None:
        expected = copy.deepcopy(self.expected)
        expected["summary"]["source_segments"] = 8024.0
        with self.assertRaisesRegex(FactError, "reviewed expected summary drifted"):
            validate_fact_pack(
                self.pack,
                self.pins,
                expected,
                pinned_sources_sha256=self.pins_sha,
            )

    def test_cached_control_mapping_rewrite_is_rejected(self) -> None:
        changed = copy.deepcopy(self.pack)
        changed["cached_control_ids"][0]["persistence_family"] = "Invented"
        with self.assertRaisesRegex(FactError, "derived fact surface drifted: cached_control_ids"):
            self.validate(changed)

    def test_product_behavior_reclassification_is_rejected(self) -> None:
        changed = copy.deepcopy(self.pack)
        changed["product_behavior"][0]["classification"] = "oracle_only"
        with self.assertRaisesRegex(FactError, "derived fact surface drifted: product_behavior"):
            self.validate(changed)

    def test_runtime_api_claim_is_rejected(self) -> None:
        changed = copy.deepcopy(self.pack)
        changed["boundaries"]["runtime_api_claims"].append({"invented": True})
        with self.assertRaisesRegex(FactError, "derived fact surface drifted: boundaries"):
            self.validate(changed)

    def test_external_reference_omission_is_rejected(self) -> None:
        changed = copy.deepcopy(self.pack)
        changed["external_references"].pop()
        with self.assertRaisesRegex(FactError, "derived fact surface drifted: external_references"):
            self.validate(changed)

    def test_reviewed_digest_rejects_a_coherently_rebuilt_source_rewrite(self) -> None:
        source_rows = copy.deepcopy(self.pack["source_rows"])
        row = next(
            item
            for item in source_rows
            if item["segment_id"].endswith("000632")
        )
        row["text"] += " Invented semantic drift."
        coherently_rebuilt = build_fact_pack(source_rows, self.pins)
        with self.assertRaisesRegex(FactError, "reviewed expected semantic digest drifted"):
            self.validate(coherently_rebuilt)

    def test_concatenated_cells_require_one_exact_vocabulary_decode(self) -> None:
        self.assertEqual(
            _segment_concatenated(
                "CheckBoxComboBoxToggleButton",
                ("CheckBox", "ComboBox", "ToggleButton"),
                "test",
            ),
            ["CheckBox", "ComboBox", "ToggleButton"],
        )
        with self.assertRaisesRegex(FactError, "0 decodings"):
            _segment_concatenated("CheckBoxUnknown", ("CheckBox",), "test")
        with self.assertRaisesRegex(FactError, "2 decodings"):
            _segment_concatenated("AA", ("A", "AA"), "test")

    def test_canonical_text_hashing_is_checkout_independent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "source.jsonl"
            path.write_bytes(b'{"x":1}\r\n{"x":2}\r\n')
            self.assertEqual(canonical_text_bytes(path), b'{"x":1}\n{"x":2}\n')
            path.write_bytes(b'{"x":1}\r{"x":2}\n')
            with self.assertRaisesRegex(FactError, "bare CR"):
                canonical_text_bytes(path)

    def test_foundation_commit_drift_is_rejected_before_capture(self) -> None:
        changed_pins = copy.deepcopy(self.pins)
        changed_pins["foundation_layout"]["foundation_commit_observed"] = "0" * 40
        observed = self.pins["foundation_layout"]["foundation_commit_observed"]
        with patch("ms_oforms_facts.subprocess.run") as run_git:
            run_git.return_value.stdout = observed + "\n"
            with self.assertRaisesRegex(FactError, "Foundation commit drift"):
                verify_source_pins(Path("unused-foundation-root"), changed_pins)
            run_git.assert_called_once()

    def test_dirty_pinned_foundation_path_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(dir=REPO_ROOT) as temporary:
            repository = Path(temporary)

            def git(*args: str) -> str:
                return subprocess.run(
                    ["git", "-C", str(repository), *args],
                    check=True,
                    capture_output=True,
                    text=True,
                ).stdout.strip()

            git("init", "--quiet")
            git("config", "user.name", "OxForms test")
            git("config", "user.email", "oxforms-test@example.invalid")
            source = repository / "pinned.txt"
            source.write_bytes(b"committed\n")
            git("add", "pinned.txt")
            git("commit", "--quiet", "-m", "fixture")
            commit = git("rev-parse", "HEAD")
            source.write_bytes(b"dirty replacement\n")
            git("update-index", "--assume-unchanged", "pinned.txt")
            payload = source.read_bytes()
            pins = {
                "foundation_layout": {"foundation_commit_observed": commit},
                "sources": [
                    {
                        "bytes": len(payload),
                        "hash_mode": "raw_bytes",
                        "id": "dirty_fixture",
                        "path": "pinned.txt",
                        "role": "fixture",
                        "sha256": hashlib.sha256(payload).hexdigest(),
                    }
                ],
            }
            with self.assertRaisesRegex(FactError, "expected-commit blob"):
                verify_source_pins(repository, pins)


if __name__ == "__main__":
    unittest.main()
