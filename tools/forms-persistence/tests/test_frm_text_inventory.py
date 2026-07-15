from __future__ import annotations

import importlib
import json
from pathlib import Path
import sys
import tempfile
import unittest


MODULE_DIRECTORY = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODULE_DIRECTORY))
frm = importlib.import_module("frm_text_inventory")

REPO_ROOT = Path(__file__).resolve().parents[3]
LIVE_FIXTURE_DIRECTORY = (
    REPO_ROOT
    / "fixtures"
    / "forms-persistence"
    / "office-vba-userform-export"
    / "20260715-excel-16.0.20131.20112"
)
USERFORM_GUID = "C62A69F0-16DC-11CE-9E98-00AA00574A4F"


def _strict_source(
    *,
    name: str = "FormProbe",
    caption: str = 'Caption         =   "probe"',
    blob_path: str | None = "FormProbe.frx",
    newline: str = "\r\n",
    code: list[str] | None = None,
) -> str:
    rows = [
        "VERSION 5.00",
        f"Begin {{{USERFORM_GUID}}} {name} ",
        f"   {caption}",
    ]
    if blob_path is not None:
        escaped = blob_path.replace('"', '""')
        rows.append(f'   OleObjectBlob   =   "{escaped}":0000')
    rows.extend(
        [
            "End",
            f'Attribute VB_Name = "{name}"',
            "Attribute VB_GlobalNameSpace = False",
            "Attribute VB_Creatable = False",
            "Attribute VB_PredeclaredId = True",
            "Attribute VB_Exposed = False",
        ]
    )
    rows.extend(code if code is not None else ["Option Explicit", ""])
    return newline.join(rows)


class FRMTextInventoryTests(unittest.TestCase):
    def test_parses_all_live_office_exports_with_exact_boundaries(self) -> None:
        paths = sorted(LIVE_FIXTURE_DIRECTORY.glob("*.frm"))
        self.assertEqual(len(paths), 3)

        for path in paths:
            with self.subTest(path=path.name):
                raw = path.read_bytes()
                document = frm.parse_frm(raw, 1252)
                inventory = document.to_dict()

                self.assertEqual(document.profile, frm.OFFICE_VBA_USERFORM_EXPORT)
                self.assertEqual(document.root_name, path.stem)
                self.assertEqual(document.root_guid, USERFORM_GUID)
                self.assertEqual(document.newline_style, "crlf")
                self.assertEqual(document.bom_length, 0)
                self.assertTrue(document.standard_office_class_header)
                self.assertEqual(len(document.blocks), 1)
                self.assertEqual(len(document.external_references), 1)
                self.assertEqual(
                    document.external_references[0].path, f"{path.stem}.frx"
                )
                self.assertTrue(
                    document.external_references[0].is_safe_relative_basename
                )
                self.assertEqual(document.code_start_offset, raw.index(b"Option Explicit"))
                self.assertEqual(document.code_body, raw[document.code_start_offset :])
                self.assertEqual(
                    inventory["coverage"]["classified_length"], len(raw)
                )
                self.assertTrue(inventory["coverage"]["all_bytes_classified_once"])
                self.assertEqual(
                    [region.span.byte_start for region in document.byte_regions],
                    [0]
                    + [region.span.byte_end for region in document.byte_regions[:-1]],
                )

    def test_preserves_cp1252_strings_quotes_comments_order_and_spans(self) -> None:
        path = LIVE_FIXTURE_DIRECTORY / "W010OuterNonDefaults.frm"
        raw = path.read_bytes()
        document = frm.parse_frm_file(path, "windows-1252")
        rows = {row.name: row for row in document.properties}

        self.assertEqual(
            [row.name for row in document.properties],
            [
                "Caption",
                "ClientHeight",
                "ClientLeft",
                "ClientTop",
                "ClientWidth",
                "Enabled",
                "HelpContextID",
                "OleObjectBlob",
                "ShowModal",
                "Tag",
                "WhatsThisButton",
                "WhatsThisHelp",
            ],
        )
        self.assertEqual(rows["Caption"].parsed_value, 'Café "quoted"')
        self.assertEqual(rows["Enabled"].parsed_value, 0)
        self.assertEqual(rows["Enabled"].comment, "'False")
        self.assertEqual(rows["Enabled"].comment_text, "False")
        self.assertEqual(rows["Tag"].parsed_value, "tag;one=1")
        caption_bytes = raw[
            rows["Caption"].value_span.byte_start : rows["Caption"].value_span.byte_end
        ]
        self.assertEqual(caption_bytes.decode("cp1252"), '"Café ""quoted"""')
        enabled_line = raw[
            rows["Enabled"].span.byte_start : rows["Enabled"].span.byte_end
        ]
        self.assertTrue(enabled_line.endswith(b"'False\r\n"))

    def test_code_after_header_is_opaque_even_when_assignment_shaped(self) -> None:
        path = LIVE_FIXTURE_DIRECTORY / "W010OuterNonDefaults.frm"
        document = frm.parse_frm_file(path, "cp1252")

        self.assertIn(b'Caption = "this is code, not designer metadata"', document.code_body)
        self.assertNotIn(
            "AssignmentShapedCode", [property_row.name for property_row in document.properties]
        )

        raw = _strict_source(
            code=["Option Explicit", 'Attribute Fake = "still code"', ""]
        ).encode("cp1252")
        with_attribute_in_code = frm.parse_frm(raw, "cp1252")
        self.assertEqual(len(with_attribute_in_code.attributes), 5)
        self.assertIn(b"Attribute Fake", with_attribute_in_code.code_body)

    def test_legacy_inventory_detects_utf8_bom_lf_and_terminal_newline(self) -> None:
        text = _strict_source(caption='Caption = "snowman ☃"', newline="\n")
        raw = b"\xEF\xBB\xBF" + text.encode("utf-8")
        document = frm.parse_frm(
            raw, "utf-8", profile=frm.LEGACY_SYNTHETIC_NESTED
        )

        self.assertEqual(document.bom_kind, "utf-8")
        self.assertEqual(document.bom_length, 3)
        self.assertEqual(document.newline_style, "lf")
        self.assertTrue(document.terminal_newline)
        self.assertEqual(document.byte_regions[0].classification, "bom")
        self.assertEqual(document.byte_regions[1].span.byte_start, 3)
        self.assertEqual(document.properties[0].parsed_value, "snowman ☃")

    def test_comment_scanner_distinguishes_apostrophes_inside_strings(self) -> None:
        raw = _strict_source(
            caption='Caption = "don\'t call ""this"" a comment"  \'outside'
        ).encode("cp1252")
        row = frm.parse_frm(raw, 1252).properties[0]

        self.assertEqual(row.parsed_value, 'don\'t call "this" a comment')
        self.assertEqual(row.comment_text, "outside")

    def test_inventories_unsafe_resource_path_without_following_it(self) -> None:
        raw = _strict_source(blob_path=r"..\outside\payload.frx").encode("cp1252")
        document = frm.parse_frm(raw, 1252)
        reference = document.external_references[0]

        self.assertFalse(reference.is_safe_relative_basename)
        self.assertIn("path_separator", reference.unsafe_reasons)
        self.assertIn("relative_traversal_component", reference.unsafe_reasons)
        self.assertEqual(reference.path, r"..\outside\payload.frx")

    def test_resource_path_control_characters_are_never_safe(self) -> None:
        for character in ("\t", "\x01", "\x7f"):
            with self.subTest(code_point=ord(character)):
                raw = _strict_source(
                    blob_path=f"evil{character}name.frx"
                ).encode("cp1252")
                reference = frm.parse_frm(raw, 1252).external_references[0]
                self.assertFalse(reference.is_safe_relative_basename)
                self.assertIn("control_character", reference.unsafe_reasons)

    def test_resource_path_rejects_all_windows_device_aliases_and_long_names(
        self,
    ) -> None:
        cases = {
            "CONIN$.frx": "windows_reserved_name",
            "CONOUT$.frx": "windows_reserved_name",
            "COM¹.txt": "windows_reserved_name",
            "LPT².frx": "windows_reserved_name",
            "x" * 252 + ".frx": (
                "filename_component_exceeds_255_utf16_code_units"
            ),
            "\U0001f600" * 126 + ".frx": (
                "filename_component_exceeds_255_utf16_code_units"
            ),
        }
        for path, reason in cases.items():
            with self.subTest(path=path):
                codec = "utf-8" if "\U0001f600" in path else "cp1252"
                reference = frm.parse_frm(
                    _strict_source(blob_path=path).encode(codec), codec
                ).external_references[0]
                self.assertFalse(reference.is_safe_relative_basename)
                self.assertIn(reason, reference.unsafe_reasons)

    def test_module_identifier_uses_broad_lexical_rule_but_identity_must_match(
        self,
    ) -> None:
        name = "Résumé Form"
        source = _strict_source(name=name, blob_path=f"{name}.frx").replace(
            f'Attribute VB_Name = "{name}"',
            'Attribute VB_Name = "FormProbe"',
        )
        with self.assertRaisesRegex(frm.FRMError, "must equal"):
            frm.parse_frm(source.encode("cp1252"), 1252)

        with self.assertRaisesRegex(frm.FRMError, "31-character"):
            frm.parse_frm(
                _strict_source(
                    name="X" * 32,
                    blob_path="LongName.frx",
                ).encode("cp1252"),
                1252,
            )

    def test_legacy_profile_inventories_balanced_nested_trees_separately(self) -> None:
        source = "\r\n".join(
            [
                "VERSION 5.00",
                "Begin VB.Form Form1",
                '   Caption = "root"',
                "   Begin VB.Frame Frame1",
                '      Caption = "child"',
                f"      BeginProperty Font {{{USERFORM_GUID}}}",
                '         Name = "Tahoma"',
                "      EndProperty",
                "   End",
                '   OleObjectBlob = "Form1.frx":0010',
                "End",
                'Attribute VB_Name = "Form1"',
                "Option Explicit",
                "",
            ]
        ).encode("cp1252")
        document = frm.parse_frm(
            source,
            1252,
            profile=frm.LEGACY_SYNTHETIC_NESTED,
        )
        inventory = document.to_dict()

        self.assertEqual(
            document.profile_disposition, "inventory_only_not_canonical_office_export"
        )
        self.assertFalse(
            inventory["legacy_nested_inventory"][
                "promotable_to_office_export_profile"
            ]
        )
        self.assertEqual(
            [(block.kind, block.name, block.parent_index) for block in document.blocks],
            [
                ("object", "Form1", None),
                ("object", "Frame1", 0),
                ("property", "Font", 1),
            ],
        )
        self.assertEqual(document.blocks[2].arguments, f"{{{USERFORM_GUID}}}")
        self.assertEqual(document.blocks[2].path, "/Form1/Frame1/@Font")
        self.assertEqual(
            [(row.name, row.owner_block_index) for row in document.properties],
            [("Caption", 0), ("Caption", 1), ("Name", 2), ("OleObjectBlob", 0)],
        )
        self.assertEqual(document.external_references[0].offset, 0x10)
        for block in document.blocks:
            self.assertLess(block.header_span.byte_start, block.end_span.byte_start)
            self.assertEqual(block.span.byte_start, block.header_span.byte_start)
            self.assertEqual(block.span.byte_end, block.end_span.byte_end)

    def test_legacy_profile_rejects_mismatched_and_unclosed_blocks(self) -> None:
        mismatched = "\n".join(
            [
                "VERSION 5.00",
                "Begin VB.Form Form1",
                "EndProperty",
                'Attribute VB_Name = "Form1"',
            ]
        ).encode("ascii")
        with self.assertRaisesRegex(frm.FRMError, "EndProperty does not match"):
            frm.parse_frm(
                mismatched, "ascii", profile=frm.LEGACY_SYNTHETIC_NESTED
            )

        unclosed = "\n".join(
            [
                "VERSION 5.00",
                "Begin VB.Form Form1",
                "   Begin VB.Frame Frame1",
                "   End",
            ]
        ).encode("ascii")
        with self.assertRaises(frm.FRMError):
            frm.parse_frm(unclosed, "ascii", profile=frm.LEGACY_SYNTHETIC_NESTED)

    def test_strict_profile_rejects_nested_text_designer_blocks(self) -> None:
        source = _strict_source().replace(
            '   Caption         =   "probe"',
            "   Begin Forms.Label.1 Label1\r\n   End",
        )
        with self.assertRaisesRegex(frm.FRMError, "nested designer blocks"):
            frm.parse_frm(source.encode("ascii"), "ascii")

    def test_strict_profile_rejects_wrong_version_and_root_shape(self) -> None:
        wrong_version = _strict_source().replace("VERSION 5.00", "VERSION 3.00")
        with self.assertRaisesRegex(frm.FRMError, "unsupported .frm VERSION"):
            frm.parse_frm(wrong_version.encode("ascii"), "ascii")

        legacy_root = _strict_source().replace(
            f"Begin {{{USERFORM_GUID}}} FormProbe ", "Begin VB.Form FormProbe"
        )
        with self.assertRaisesRegex(frm.FRMError, "root must be"):
            frm.parse_frm(legacy_root.encode("ascii"), "ascii")

    def test_strict_profile_rejects_missing_or_malformed_ole_object_blob(self) -> None:
        with self.assertRaisesRegex(frm.FRMError, "exactly one OleObjectBlob"):
            frm.parse_frm(_strict_source(blob_path=None).encode("ascii"), "ascii")

        malformed = _strict_source().replace(
            '"FormProbe.frx":0000', '"FormProbe.frx":xyz'
        )
        with self.assertRaisesRegex(frm.FRMError, "exactly one OleObjectBlob"):
            frm.parse_frm(malformed.encode("ascii"), "ascii")

    def test_strict_profile_rejects_duplicate_and_unterminated_properties(self) -> None:
        duplicate = _strict_source().replace(
            '   Caption         =   "probe"',
            '   Caption = "one"\r\n   Caption = "two"',
        )
        with self.assertRaisesRegex(frm.FRMError, "duplicate root property"):
            frm.parse_frm(duplicate.encode("ascii"), "ascii")

        unterminated = _strict_source(caption='Caption = "unterminated')
        with self.assertRaisesRegex(frm.FRMError, "unterminated quoted string"):
            frm.parse_frm(unterminated.encode("ascii"), "ascii")

    def test_strict_profile_applies_normative_class_header_rules(self) -> None:
        missing_end = _strict_source().replace(
            "\r\nEnd\r\nAttribute", "\r\nAttribute"
        )
        with self.assertRaises(frm.FRMError):
            frm.parse_frm(missing_end.encode("ascii"), "ascii")

        missing_attribute = _strict_source().replace(
            "Attribute VB_Creatable = False\r\n", ""
        )
        missing_document = frm.parse_frm(missing_attribute.encode("ascii"), "ascii")
        self.assertFalse(missing_document.standard_office_class_header)

        different_valid_name = _strict_source().replace(
            'Attribute VB_Name = "FormProbe"', 'Attribute VB_Name = "Other"'
        )
        with self.assertRaisesRegex(frm.FRMError, "must equal"):
            frm.parse_frm(different_valid_name.encode("ascii"), "ascii")

        invalid_spaced_name = _strict_source().replace(
            'Attribute VB_Name = "FormProbe"', 'Attribute VB_Name = "Bad Name"'
        )
        with self.assertRaisesRegex(frm.FRMError, "quoted identifier"):
            frm.parse_frm(invalid_spaced_name.encode("ascii"), "ascii")

        repeated = _strict_source().replace(
            'Attribute VB_Name = "FormProbe"',
            'Attribute VB_Name = "Earlier"\r\n'
            'Attribute VB_Customizable = True\r\n'
            'Attribute VB_Name = "FormProbe"',
        )
        repeated_document = frm.parse_frm(repeated.encode("ascii"), "ascii")
        self.assertFalse(repeated_document.standard_office_class_header)
        self.assertEqual(
            [row.name for row in repeated_document.attributes].count("VB_Name"), 2
        )

        invalid_global = _strict_source().replace(
            "Attribute VB_GlobalNameSpace = False",
            "Attribute VB_GlobalNameSpace = True",
        )
        with self.assertRaisesRegex(frm.FRMError, "VB_GlobalNameSpace must be False"):
            frm.parse_frm(invalid_global.encode("ascii"), "ascii")

    def test_strict_profile_accepts_both_normative_nwln_forms(self) -> None:
        for newline, style in (("\r\n", "crlf"), ("\n\r", "lfcr")):
            with self.subTest(style=style):
                document = frm.parse_frm(
                    _strict_source(newline=newline).encode("ascii"), "ascii"
                )
                self.assertEqual(document.newline_style, style)

    def test_strict_profile_rejects_non_normative_or_mixed_newlines(self) -> None:
        source = _strict_source()
        cases = {
            "mixed": source.replace("\r\n", "\n", 1),
            "lf": _strict_source(newline="\n"),
            "cr": _strict_source(newline="\r"),
        }
        for name, value in cases.items():
            with self.subTest(name=name), self.assertRaisesRegex(
                frm.FRMError, "normative NWLN"
            ):
                frm.parse_frm(value.encode("ascii"), "ascii")

        bom = b"\xEF\xBB\xBF" + _strict_source().encode("utf-8")
        with self.assertRaisesRegex(frm.FRMError, "must not have a BOM"):
            frm.parse_frm(bom, "utf-8")

    def test_rejects_conflicting_bom_bad_code_page_and_decode_failure(self) -> None:
        raw = b"\xEF\xBB\xBF" + _strict_source().encode("utf-8")
        with self.assertRaisesRegex(frm.FRMError, "BOM conflicts"):
            frm.parse_frm(raw, "cp1252")
        with self.assertRaisesRegex(frm.FRMError, "unknown code page"):
            frm.parse_frm(raw, "not-a-code-page")
        with self.assertRaisesRegex(frm.FRMError, "not valid cp1252"):
            frm.parse_frm(_strict_source().encode("ascii") + b"\x81", 1252)

    def test_rejects_unknown_profile_and_non_bytes_input(self) -> None:
        raw = _strict_source().encode("ascii")
        with self.assertRaisesRegex(frm.FRMError, "unsupported .frm profile"):
            frm.parse_frm(raw, "ascii", profile="invented")
        with self.assertRaises(TypeError):
            frm.parse_frm(_strict_source(), "ascii")
        with self.assertRaises(TypeError):
            frm.parse_frm(raw, True)

    def test_serializable_and_file_apis_are_deterministic(self) -> None:
        raw = _strict_source().encode("cp1252")
        first = frm.inventory_frm(raw, 1252)
        second = frm.parse_frm(raw, 1252).to_dict()

        self.assertEqual(first, second)
        self.assertEqual(
            json.dumps(first, sort_keys=True, separators=(",", ":")),
            json.dumps(second, sort_keys=True, separators=(",", ":")),
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "probe.frm")
            path.write_bytes(raw)
            self.assertEqual(frm.inventory_frm_file(path, 1252), first)


if __name__ == "__main__":
    unittest.main()
