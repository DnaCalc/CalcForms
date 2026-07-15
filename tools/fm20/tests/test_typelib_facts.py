from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(TOOLS_DIR))

import typelib_facts  # noqa: E402


EVIDENCE_DIR = (
    REPO_ROOT
    / "docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.2"
)
FACTS_PATH = EVIDENCE_DIR / "fm20_typelib_facts.v1.json"
COMPARISON_PATH = EVIDENCE_DIR / "w005_event_reconciliation.v1.json"
W005_PATH = (
    REPO_ROOT
    / "docs/evidence/W005_input_interaction_model_exploration/fm20_typelib_w005_events.json"
)
W005_PIN_PATH = TOOLS_DIR / "pinned_w005_baseline.v1.json"
EXPECTED_CAPTURE_PATH = TOOLS_DIR / "expected_capture.v1.json"


class TypelibFactTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.facts = typelib_facts.load_json_strict(FACTS_PATH)
        cls.comparison = typelib_facts.load_json_strict(COMPARISON_PATH)
        cls.w005 = typelib_facts.load_json_strict(W005_PATH)
        cls.w005_pin = typelib_facts.load_json_strict(W005_PIN_PATH)
        cls.expected_capture = typelib_facts.load_json_strict(EXPECTED_CAPTURE_PATH)

    def test_committed_pack_and_reconciliation_are_valid(self) -> None:
        self.assertEqual(
            [], typelib_facts.validate_fact_pack(self.facts, require_sources=False)
        )
        self.assertEqual(
            [],
            typelib_facts.validate_w005_comparison(
                self.comparison,
                self.facts,
                self.w005,
                w005_pin=self.w005_pin,
                w005_pin_path=W005_PIN_PATH,
            ),
        )
        self.assertEqual(
            self.comparison,
            typelib_facts.build_w005_comparison(
                self.facts,
                self.w005,
                w005_path=W005_PATH,
                w005_pin=self.w005_pin,
                w005_pin_path=W005_PIN_PATH,
            ),
        )
        self.assertEqual(
            [],
            typelib_facts.validate_expected_capture(
                self.expected_capture, self.facts, self.comparison
            ),
        )

    def test_truncated_type_list_is_rejected(self) -> None:
        root = self.facts["libraries"][0]
        removed = root["types"].pop()
        try:
            errors = typelib_facts.validate_fact_pack(
                self.facts, require_sources=False
            )
            self.assertTrue(any("FM20 primary type indexes" in error for error in errors))
            self.assertTrue(any("canonical_sha256" in error for error in errors))
        finally:
            root["types"].append(removed)

    def test_unknown_high_flag_bit_is_rejected(self) -> None:
        function = next(
            item["functions"][0]
            for item in self.facts["libraries"][0]["types"]
            if item["functions"]
        )
        original = function["function_flags"]
        function["function_flags"] = {
            "value": original["value"] | 0x8000,
            "names": original["names"],
            "unknown_bits": 0x8000,
        }
        try:
            errors = typelib_facts.validate_fact_pack(
                self.facts, require_sources=False
            )
            self.assertTrue(any("unexplained function flag bits" in error for error in errors))
        finally:
            function["function_flags"] = original

    def test_reviewed_capture_pin_rejects_coherent_member_change(self) -> None:
        function = next(
            item["functions"][0]
            for item in self.facts["libraries"][0]["types"]
            if item["functions"]
        )
        original_memid = function["memid"]
        original_digest = self.facts["canonical_sha256"]
        function["memid"] = 123456789
        canonical = {
            "root_library_key": self.facts["root_library_key"],
            "flag_definitions": self.facts["flag_definitions"],
            "libraries": self.facts["libraries"],
            "type_references": self.facts["type_references"],
            "library_reference_edges": self.facts["library_reference_edges"],
        }
        self.facts["canonical_sha256"] = typelib_facts.sha256_bytes(
            typelib_facts.structural_json_bytes(canonical)
        )
        try:
            errors = typelib_facts.validate_expected_capture(
                self.expected_capture, self.facts, self.comparison
            )
            self.assertTrue(any("reviewed pin" in error for error in errors))
        finally:
            function["memid"] = original_memid
            self.facts["canonical_sha256"] = original_digest

    def test_omitted_generator_provenance_is_rejected(self) -> None:
        sources = self.facts["generator"]["source_files"]
        removed = sources.pop()
        try:
            errors = typelib_facts.validate_fact_pack(
                self.facts, require_sources=False
            )
            self.assertTrue(
                any("generator.source_files paths/order" in error for error in errors)
            )
        finally:
            sources.append(removed)

    def test_missing_reference_row_is_rejected_semantically(self) -> None:
        references = self.facts["type_references"]
        removed = references.pop()
        try:
            errors = typelib_facts.validate_fact_pack(
                self.facts, require_sources=False
            )
            self.assertTrue(
                any("do not exactly mirror" in error for error in errors)
            )
        finally:
            references.append(removed)
            references.sort(
                key=lambda row: (
                    row["from_library_key"],
                    row["from_type_index"],
                    {"primary": 0, "dual_interface": 1}[row["from_type_view"]],
                    row["context"],
                    row["reference_kind"],
                    row["raw_href"],
                    row["target"]["library_key"],
                    row["target"]["type_index"],
                    {"primary": 0, "dual_interface": 1}[row["target"]["view"]],
                )
            )

    def test_malformed_raw_descriptor_is_rejected_semantically(self) -> None:
        parameter = next(
            parameter
            for item in self.facts["libraries"][0]["types"]
            for function in item["functions"]
            for parameter in function["parameters"]
            if parameter["type"]["kind"] == "pointer"
        )
        original = parameter["raw"]
        parameter["raw"] = ["bogus"]
        try:
            errors = typelib_facts.validate_fact_pack(
                self.facts, require_sources=False
            )
            self.assertTrue(any("raw ELEMDESC" in error for error in errors))
        finally:
            parameter["raw"] = original

    def test_w005_interface_name_change_is_a_structural_delta(self) -> None:
        row = self.w005["rows"][0]
        original = row["source_interface"]
        row["source_interface"] = "RENAMED_INTERFACE"
        try:
            comparison = typelib_facts.build_w005_comparison(
                self.facts,
                self.w005,
                w005_path=W005_PATH,
                w005_pin=self.w005_pin,
                w005_pin_path=W005_PIN_PATH,
            )
            self.assertGreater(comparison["structural_delta_count"], 0)
        finally:
            row["source_interface"] = original

    def test_strict_loader_rejects_duplicate_keys(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "duplicate.json"
            path.write_text('{"schema": 1, "schema": 2}\n', encoding="utf-8")
            with self.assertRaisesRegex(typelib_facts.FactError, "Duplicate JSON key"):
                typelib_facts.load_json_strict(path)

    def test_default_state_is_distinct_from_encoded_null(self) -> None:
        self.assertEqual(
            {"state": "not_encoded"}, typelib_facts.default_fact(None, 0)
        )
        self.assertEqual(
            {"state": "encoded", "value": {"kind": "null", "value": None}},
            typelib_facts.default_fact(None, 0x20),
        )


if __name__ == "__main__":
    unittest.main()
