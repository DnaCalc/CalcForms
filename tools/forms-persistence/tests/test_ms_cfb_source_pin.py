from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
import unittest


MODULE_DIRECTORY = Path(__file__).resolve().parents[1]
REPO_ROOT = MODULE_DIRECTORY.parents[1]
sys.path.insert(0, str(MODULE_DIRECTORY))

import extract_ms_cfb_selected_rows as source_pin  # noqa: E402


DOCX = REPO_ROOT / "reference" / "ms-cfb" / "[MS-CFB]-240423.docx"
SELECTED = REPO_ROOT / "reference" / "ms-cfb" / "ms_cfb_selected_rows.v1.jsonl"
RULES = MODULE_DIRECTORY / "ms_cfb_selected_rules.v1.json"
PINS = MODULE_DIRECTORY / "pinned_sources.v1.json"
EXTRACTOR = MODULE_DIRECTORY / "extract_ms_cfb_selected_rows.py"


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class MsCfbSourcePinTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.records = [json.loads(line) for line in SELECTED.read_text(encoding="utf-8").splitlines()]
        cls.rules = json.loads(RULES.read_text(encoding="utf-8"))
        cls.pins = json.loads(PINS.read_text(encoding="utf-8"))

    def test_official_docx_and_selected_rows_are_byte_exact(self) -> None:
        self.assertEqual(DOCX.stat().st_size, source_pin.SOURCE_LENGTH)
        self.assertEqual(_sha256(DOCX), source_pin.SOURCE_SHA256)
        self.assertEqual(source_pin.canonical_bytes(DOCX), SELECTED.read_bytes())
        source_pin.verify_bindings(REPO_ROOT, DOCX, SELECTED, RULES, PINS)
        self.assertEqual(len(self.records), 84)
        self.assertEqual(self.records[0]["selected_row_count"], 83)
        self.assertEqual(self.records[0]["total_document_rows"], 982)

    def test_selection_is_unique_complete_and_section_bound(self) -> None:
        expected = [
            row
            for _section, _purpose, row_numbers in source_pin.SELECTIONS
            for row in row_numbers
        ]
        observed = [record["document_row"] for record in self.records[1:]]
        self.assertEqual(observed, expected)
        self.assertEqual(len(observed), len(set(observed)))
        self.assertEqual(
            {record["section"] for record in self.records[1:]},
            {"revision", "2.1", "2.2", "2.3", "2.4", "2.5", "2.6", "2.7", "2.8"},
        )
        for record in self.records[1:]:
            self.assertEqual(
                record["text_sha256"],
                hashlib.sha256(record["text"].encode("utf-8")).hexdigest(),
            )

    def test_rules_reference_every_selected_normative_row(self) -> None:
        rule_rows = {
            row
            for section in self.rules["selected_sections"]
            for row in section["source_rows"]
        }
        source_rows = {
            record["document_row"]
            for record in self.records[1:]
            if record["section"] != "revision"
        }
        self.assertEqual(rule_rows, source_rows)
        self.assertEqual(len(self.rules["selected_sections"]), 5)
        for section in self.rules["selected_sections"]:
            self.assertNotIn("rules", section)
            self.assertTrue(section["project_interpretations"])

    def test_source_wording_preserves_should_and_tree_boundaries(self) -> None:
        by_row = {record.get("document_row"): record.get("text") for record in self.records[1:]}
        self.assertIn("SHOULD be set to 0x003E", by_row[279])
        self.assertIn("its color is irrelevant", by_row[462])
        self.assertIn("Two consecutive nodes MUST NOT both be red", by_row[463])
        self.assertFalse(any("black height" in text.lower() for text in by_row.values()))
        directory_rules = self.rules["selected_sections"][3]["project_interpretations"]
        self.assertIn(
            "The MS-CFB sibling-tree rules do not impose the classical equal-black-height invariant.",
            directory_rules,
        )

    def test_rules_and_pin_manifest_bind_all_source_artifacts(self) -> None:
        source = self.rules["source"]
        self.assertEqual(source["raw_artifact"]["length"], DOCX.stat().st_size)
        self.assertEqual(source["raw_artifact"]["sha256"], _sha256(DOCX))
        self.assertEqual(source["normalized_selected_rows"]["length"], SELECTED.stat().st_size)
        self.assertEqual(source["normalized_selected_rows"]["sha256"], _sha256(SELECTED))
        self.assertEqual(source["extractor"]["length"], EXTRACTOR.stat().st_size)
        self.assertEqual(source["extractor"]["sha256"], _sha256(EXTRACTOR))

        by_id = {row["source_id"]: row for row in self.pins["local_dependencies"]}
        expected = {
            "MS-CFB-DOCX": DOCX,
            "MS-CFB-SELECTED-ROWS": SELECTED,
            "MS-CFB-EXTRACTOR": EXTRACTOR,
            "MS-CFB-SELECTED-RULES": RULES,
        }
        for source_id, path in expected.items():
            self.assertEqual(by_id[source_id]["length"], path.stat().st_size)
            self.assertEqual(by_id[source_id]["sha256"], _sha256(path))


if __name__ == "__main__":
    unittest.main()
