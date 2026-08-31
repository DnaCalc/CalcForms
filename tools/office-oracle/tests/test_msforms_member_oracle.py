"""Adversarial tests for the manifest-driven live MSForms member oracle."""

from __future__ import annotations

import copy
import importlib.util
import io
import json
import py_compile
import re
import shutil
import struct
import sys
import tempfile
import unittest
import uuid
import zipfile
import zlib
from contextlib import contextmanager, redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[3]
TOOL_PATH = REPO_ROOT / "tools" / "office-oracle" / "msforms_member_oracle.py"
MANIFEST_PATH = (
    REPO_ROOT
    / "fixtures"
    / "office-oracle"
    / "excel-msforms"
    / "member-probes"
    / "representative-v1.json"
)
LEDGER_PATH = REPO_ROOT / (
    "docs/evidence/W010_complete_msforms_object_model_parity/beads/"
    "oxforms-jbjp.4/msforms_parity_ledger.v1.json"
)
LEDGER_SNAPSHOT_PATH = MANIFEST_PATH.with_name("representative-v1.ledger-slice.json")
CAPTURE_TEST_ROOT = (
    REPO_ROOT
    / "docs"
    / "evidence"
    / "W010_complete_msforms_object_model_parity"
    / "beads"
    / "oxforms-jbjp.5"
    / "captures"
)

SPEC = importlib.util.spec_from_file_location("msforms_member_oracle_under_test", TOOL_PATH)
if SPEC is None or SPEC.loader is None:  # pragma: no cover - importlib contract guard
    raise RuntimeError(f"cannot import {TOOL_PATH}")
oracle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(oracle)
ORIGINAL_LOAD_JSON = oracle.load_json
ORIGINAL_SHA256_FILE = oracle.sha256_file


class MSFormsMemberOracleTests(unittest.TestCase):
    maxDiff = None

    @classmethod
    def setUpClass(cls) -> None:
        cls.base_manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        cls.ledger = json.loads(LEDGER_PATH.read_text(encoding="utf-8"))
        cls.ledger_file_sha256 = oracle.sha256_file(LEDGER_PATH)
        temp_parent = REPO_ROOT / "target" / "test-msforms-member-oracle"
        temp_parent.mkdir(parents=True, exist_ok=True)
        cls.temp_owner = tempfile.TemporaryDirectory(
            prefix="case-", dir=temp_parent
        )
        cls.temp_root = Path(cls.temp_owner.name)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temp_owner.cleanup()

    def setUp(self) -> None:
        self.manifest = copy.deepcopy(self.base_manifest)
        self.manifest_path = self.temp_root / f"{self._testMethodName}.json"
        self._write_manifest()

    @contextmanager
    def _cached_ledger(self):
        def load_json(path: Path):
            candidate = Path(path)
            if candidate.resolve() == LEDGER_PATH.resolve():
                return self.ledger
            return ORIGINAL_LOAD_JSON(candidate)

        def sha256_file(path: Path) -> str:
            candidate = Path(path)
            if candidate.resolve() == LEDGER_PATH.resolve():
                return self.ledger_file_sha256
            return ORIGINAL_SHA256_FILE(candidate)

        with mock.patch.object(oracle, "load_json", side_effect=load_json), mock.patch.object(
            oracle, "sha256_file", side_effect=sha256_file
        ):
            yield

    def _write_manifest(self, manifest: dict | None = None) -> None:
        value = self.manifest if manifest is None else manifest
        self.manifest_path.write_bytes(oracle.canonical_json_bytes(value))

    def _write_raw_manifest(self, raw: bytes) -> None:
        self.manifest_path.write_bytes(raw)

    def _validate(self) -> dict:
        with self._cached_ledger():
            return oracle.validate_manifest(self.manifest_path, REPO_ROOT)

    def test_windows_command_line_replay_parser_is_strict(self) -> None:
        excel_path = r"C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE"
        self.assertEqual(
            oracle._parse_windows_command_line(
                f'"{excel_path}" /safe', "capture.excel.observed_command_line"
            ),
            [excel_path, "/safe"],
        )
        self.assertEqual(
            oracle._parse_windows_command_line(
                r'"C:\Office\\\"quoted\"\EXCEL.EXE" /safe',
                "capture.excel.observed_command_line",
            ),
            [r'C:\Office\"quoted"\EXCEL.EXE', "/safe"],
        )
        with self.assertRaisesRegex(oracle.OracleValidationError, "unterminated quote"):
            oracle._parse_windows_command_line(
                f'"{excel_path} /safe', "capture.excel.observed_command_line"
            )
        with self.assertRaisesRegex(oracle.OracleValidationError, "NUL"):
            oracle._parse_windows_command_line(
                f'"{excel_path}" /safe\x00/evil',
                "capture.excel.observed_command_line",
            )

    def _assert_rejected(self, fragment: str) -> None:
        with self.assertRaises(oracle.OracleValidationError) as caught:
            self._validate()
        self.assertIn(fragment, str(caught.exception))

    def test_foreground_attempt_is_bounded_to_capture_retry_contract(self) -> None:
        path = "window_manifest.screenshot.attempts[0].foreground_attempt"
        self.assertEqual(oracle._expect_foreground_attempt(1, path), 1)
        self.assertEqual(oracle._expect_foreground_attempt(4, path), 4)
        for adversarial in (0, 5, 10**100):
            with self.subTest(value=adversarial):
                with self.assertRaises(oracle.OracleValidationError) as caught:
                    oracle._expect_foreground_attempt(adversarial, path)
                self.assertIn(path, str(caught.exception))

    def _step(self, step_id: str) -> dict:
        return next(step for step in self.manifest["steps"] if step["id"] == step_id)

    def _event(self, event_id: str) -> dict:
        return next(event for event in self.manifest["events"] if event["id"] == event_id)

    @staticmethod
    def _frame(control_id: str, name: str, *, container: str = "root") -> dict:
        return {
            "id": control_id,
            "name": name,
            "prog_id": "Forms.Frame.1",
            "fm20_type": "Frame",
            "left_pt": 6,
            "top_pt": 144,
            "width_pt": 120,
            "height_pt": 54,
            "initial_properties": {
                "Caption": {"kind": "string", "value": name}
            },
            "container": container,
        }

    def test_representative_manifest_is_valid(self) -> None:
        validated = self._validate()
        self.assertEqual("W010RepresentativeMemberOracleV1", validated["id"])
        self.assertEqual(self.ledger_file_sha256, validated["ledger"]["file_sha256"])
        self.assertGreaterEqual(len(validated["form"]["controls"]), 5)

    def test_success_result_types_and_locale_prerequisites_are_exact(self) -> None:
        success = self._step("LabelCaptionRoundtrip")["expect"]
        success.pop("type_name")
        self._write_manifest()
        self._assert_rejected("must pin type_name")

        self.manifest = copy.deepcopy(self.base_manifest)
        success = self._step("LabelCaptionRoundtrip")["expect"]
        success["type_name"] = "Long"
        success["var_type"] = 3
        self._write_manifest()
        self._assert_rejected("does not match the expected scalar kind")

        self.manifest = copy.deepcopy(self.base_manifest)
        self.manifest["environment_requirements"].remove(
            oracle.ENGLISH_OFFICE_REQUIREMENT
        )
        self._write_manifest()
        self._assert_rejected("must include exact prerequisite")

        self.manifest = copy.deepcopy(self.base_manifest)
        self.manifest["environment_requirements"].remove(
            oracle.VBE_ERROR_TRAPPING_REQUIREMENT
        )
        self._write_manifest()
        self._assert_rejected("must include exact prerequisite")

    def test_cli_self_hash_pin_fails_closed(self) -> None:
        common = [
            "--repo-root",
            str(REPO_ROOT),
            "--expected-self-sha256",
        ]
        command = ["validate-manifest", "--manifest", str(self.manifest_path)]
        with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            self.assertEqual(1, oracle.main([*common, "0" * 64, *command]))
        with self._cached_ledger(), redirect_stdout(io.StringIO()), redirect_stderr(
            io.StringIO()
        ):
            self.assertEqual(
                0,
                oracle.main(
                    [*common, oracle.sha256_file(TOOL_PATH), *command]
                ),
            )

    def test_capture_integer_strings_are_canonical(self) -> None:
        for value, expected in (("0", 0), ("1", 1), ("-1", -1), (123, 123)):
            with self.subTest(value=value):
                self.assertEqual(expected, oracle._int_from_capture(value, "integer"))
        for value in ("00", "01", "-0", "-01", "+1", " 1", "1 "):
            with self.subTest(value=value), self.assertRaisesRegex(
                oracle.OracleValidationError,
                "canonical integer string",
            ):
                oracle._int_from_capture(value, "integer")

    def test_bound_file_bytes_are_checksum_pinned_and_retained(self) -> None:
        path = self.temp_root / f"{self._testMethodName}.bin"
        original = b"one exact retained byte snapshot"
        replacement = b"a later replacement must not change parsed bytes"
        path.write_bytes(original)
        digest = oracle.sha256_bytes(original)
        retained = oracle._read_bound_file(
            path,
            "test-bound-file",
            expected_sha256=digest,
            max_bytes=1024,
        )
        path.write_bytes(replacement)
        self.assertEqual(original, retained)
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "checksum mismatch"
        ):
            oracle._read_bound_file(
                path,
                "test-bound-file",
                expected_sha256=digest,
                max_bytes=1024,
            )

    def test_reusable_scalar_path_frx_and_event_window_guards(self) -> None:
        single = oracle.validate_scalar(
            {"kind": "single", "value": 0.1, "expected_text": "0.1"},
            "single",
        )
        self.assertEqual("0.1", oracle.scalar_expected_text(single))
        self.assertRegex(oracle.scalar_vba_literal(single), r"!$")
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "finite IEEE-754/VBA Single"
        ):
            oracle.validate_scalar(
                {"kind": "single", "value": 1e100, "expected_text": "overflow"},
                "single",
            )
        for scalar in (10**10000, 1e-300):
            with self.subTest(scalar_type=type(scalar).__name__), self.assertRaisesRegex(
                oracle.OracleValidationError, "finite IEEE-754/VBA Single"
            ):
                oracle.validate_scalar(
                    {"kind": "single", "value": scalar, "expected_text": "bad"},
                    "single",
                )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "bounded schema-v1 VBA physical line"
        ):
            oracle.validate_scalar(
                {"kind": "string", "value": "x" * 256}, "long_string"
            )
        for invalid_string in ("tab\tvalue", "line\u2028separator", "\ud800"):
            with self.subTest(invalid_string=repr(invalid_string)), self.assertRaises(
                oracle.OracleValidationError
            ):
                oracle.validate_scalar(
                    {"kind": "string", "value": invalid_string}, "invalid_string"
                )

        for unsafe_path in (
            "artifact.bin:stream",
            "CON.txt",
            "CONIN$",
            "CONOUT$.txt",
            "COM¹.txt",
            "LPT²",
            "folder/trailing.",
            "folder/trailing ",
            "folder//file",
            "folder/control\x01file",
            "folder/wild*card",
            'folder/quo"te',
        ):
            with self.subTest(unsafe_path=unsafe_path), self.assertRaises(
                oracle.OracleValidationError
            ):
                oracle._safe_capture_relative_path(unsafe_path, "artifact.path")
        self.assertEqual(
            "tool-snapshots/validator.py",
            oracle._safe_capture_relative_path(
                "tool-snapshots/validator.py", "artifact.path"
            ),
        )

        reference = {
            "property_name": "OleObjectBlob",
            "owner_block_index": 0,
            "path": "member-oracle.frx",
            "offset": 0,
            "offset_text": "0000",
            "is_safe_relative_basename": True,
            "unsafe_reasons": [],
        }
        oracle._validate_frx_reference([reference], "member-oracle.frx")
        oracle._validate_frm_frx_siblings(
            Path("capture/member-oracle.frm"),
            Path("capture/member-oracle.frx"),
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "must be exact siblings"
        ):
            oracle._validate_frm_frx_siblings(
                Path("capture/forms/member-oracle.frm"),
                Path("capture/resources/member-oracle.frx"),
            )
        for key, value in (
            ("path", "../member-oracle.frx"),
            ("offset", 16),
            ("owner_block_index", 1),
            ("is_safe_relative_basename", False),
        ):
            mutated = copy.deepcopy(reference)
            mutated[key] = value
            with self.subTest(key=key), self.assertRaisesRegex(
                oracle.OracleValidationError, "does not exactly bind"
            ):
                oracle._validate_frx_reference([mutated], "member-oracle.frx")

        probe_ids = [
            step["id"] for step in self.manifest["steps"] if step["kind"] == "probe"
        ]
        valid_result_sequences = [1, 2, 3, 4, 5, 6, 8, 9, 11, 12, 13]
        valid_results = [
            {"probe_id": probe_id, "sequence": sequence}
            for probe_id, sequence in zip(probe_ids, valid_result_sequences)
        ]
        valid_events = [
            {"event_id": "TextChangeEvent", "sequence": 7},
            {"event_id": "TextExitMutation", "sequence": 10},
        ]
        oracle._validate_event_timeline(valid_results, valid_events, self.manifest)
        late_change_results = copy.deepcopy(valid_results)
        late_change_results[6]["sequence"] = 7
        late_change_events = copy.deepcopy(valid_events)
        late_change_events[0]["sequence"] = 8
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "outside the execution window"
        ):
            oracle._validate_event_timeline(
                late_change_results, late_change_events, self.manifest
            )
        impossible_results = [
            {"probe_id": probe_id, "sequence": index + 1}
            for index, probe_id in enumerate(probe_ids)
        ]
        impossible_events = [
            {"event_id": "TextChangeEvent", "sequence": 12},
            {"event_id": "TextExitMutation", "sequence": 13},
        ]
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "outside the execution window"
        ):
            oracle._validate_event_timeline(
                impossible_results, impossible_events, self.manifest
            )

        manifest_sha = "f" * 64
        result_rows = []
        for step, sequence in zip(
            (step for step in self.manifest["steps"] if step["kind"] == "probe"),
            valid_result_sequences,
        ):
            expectation = step["expect"]
            is_error = expectation["outcome"] == "error"
            value = expectation.get("value", {"kind": "empty"})
            shapes = {
                "string": ("String", "8"),
                "integer": ("Long", "3"),
                "boolean": ("Boolean", "11"),
                "empty": ("Empty", "0"),
            }
            type_name, var_type = shapes[value["kind"]]
            error_number = expectation.get("error_number", 0)
            result_rows.append(
                {
                    "sequence": sequence,
                    "probe_id": step["id"],
                    "ledger_row_id": step["ledger_row_id"],
                    "target_id": step["target"],
                    "operation": step["operation"],
                    "member": step["member"],
                    "outcome": expectation["outcome"],
                    "value_text": "" if is_error else oracle.scalar_expected_text(value),
                    "type_name": "" if is_error else type_name,
                    "var_type": "" if is_error else var_type,
                    "is_object": "" if is_error else "False",
                    "is_array": "" if is_error else "False",
                    "error_number": error_number,
                    "error_last_dll_error": (
                        expectation.get("last_dll_error_equals", 0)
                        if is_error
                        else 0
                    ),
                    "error_hex": f"0x{error_number & 0xFFFFFFFF:08X}",
                    "error_description": (
                        expectation.get("description_equals", "") if is_error else ""
                    ),
                    "error_description_utf16_hex": (
                        expectation.get("description_utf16_hex_equals", "")
                        if is_error
                        else ""
                    ),
                    "error_source": (
                        expectation.get("source_equals", "") if is_error else ""
                    ),
                    "error_help_file": (
                        expectation.get("help_file_equals", "") if is_error else ""
                    ),
                    "error_help_context": (
                        expectation.get("help_context_equals", 0) if is_error else 0
                    ),
                    "error_line": expectation.get("line_equals", 0) if is_error else 0,
                    "error_stage": expectation.get("error_stage", ""),
                }
            )
        source_manifest = copy.deepcopy(self.manifest)
        results_doc = {
            "schema": oracle.RESULT_SCHEMA,
            "schema_version": 1,
            "manifest": {"id": source_manifest["id"], "sha256": manifest_sha},
            "rows": result_rows,
        }
        self.assertEqual(
            (10, 1), oracle._validate_results(results_doc, source_manifest, manifest_sha)
        )
        wrong_result_type = copy.deepcopy(results_doc)
        wrong_result_type["rows"][0]["type_name"] = "Long"
        wrong_result_type["rows"][0]["var_type"] = "3"
        with self.assertRaisesRegex(
            oracle.OracleValidationError,
            "does not match the exact expectation",
        ):
            oracle._validate_results(
                wrong_result_type, source_manifest, manifest_sha
            )
        wrong_raw_description = copy.deepcopy(results_doc)
        wrong_raw_description["rows"][9]["error_description_utf16_hex"] = (
            wrong_raw_description["rows"][9]["error_description_utf16_hex"][:-4]
            + "0001"
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError,
            "with one final U\\+0000 removed",
        ):
            oracle._validate_results(
                wrong_raw_description, source_manifest, manifest_sha
            )
        success_with_raw_error = copy.deepcopy(results_doc)
        success_with_raw_error["rows"][0]["error_description_utf16_hex"] = "0041"
        with self.assertRaisesRegex(
            oracle.OracleValidationError,
            "must not retain error metadata",
        ):
            oracle._validate_results(
                success_with_raw_error, source_manifest, manifest_sha
            )
        success_with_last_dll_error = copy.deepcopy(results_doc)
        success_with_last_dll_error["rows"][0]["error_last_dll_error"] = 1
        with self.assertRaisesRegex(
            oracle.OracleValidationError,
            "must not retain error metadata",
        ):
            oracle._validate_results(
                success_with_last_dll_error, source_manifest, manifest_sha
            )
        noncanonical_last_dll_error = copy.deepcopy(results_doc)
        noncanonical_last_dll_error["rows"][9]["error_last_dll_error"] = "00"
        with self.assertRaisesRegex(
            oracle.OracleValidationError,
            "canonical integer string",
        ):
            oracle._validate_results(
                noncanonical_last_dll_error, source_manifest, manifest_sha
            )
        wrong_last_dll_error = copy.deepcopy(results_doc)
        wrong_last_dll_error["rows"][9]["error_last_dll_error"] = 1
        with self.assertRaisesRegex(
            oracle.OracleValidationError,
            "expected 0, found 1",
        ):
            oracle._validate_results(
                wrong_last_dll_error, source_manifest, manifest_sha
            )
        wrong_source = copy.deepcopy(results_doc)
        wrong_source["rows"][9]["error_source"] = "Forms.TextBox.2"
        with self.assertRaisesRegex(
            oracle.OracleValidationError,
            "Forms.TextBox.1",
        ):
            oracle._validate_results(wrong_source, source_manifest, manifest_sha)
        auxiliary_tampers = (
            ("error_help_file", "other.hlp", "fm20.hlp"),
            ("error_help_context", 1, "expected 1000380, found 1"),
            ("error_line", 1, "expected 0, found 1"),
        )
        for field, bad_value, fragment in auxiliary_tampers:
            with self.subTest(result_error_field=field):
                tampered = copy.deepcopy(results_doc)
                tampered["rows"][9][field] = bad_value
                with self.assertRaisesRegex(
                    oracle.OracleValidationError,
                    re.escape(fragment),
                ):
                    oracle._validate_results(
                        tampered, source_manifest, manifest_sha
                    )
        result_rows[9]["error_source"] = "\x00"
        with self.assertRaisesRegex(oracle.OracleValidationError, "NUL"):
            oracle._validate_results(results_doc, source_manifest, manifest_sha)

    def test_persisted_graph_and_pcode_nonclaims_are_mandatory(self) -> None:
        self.manifest["non_claims"] = [
            text
            for text in self.manifest["non_claims"]
            if "MS-OFORMS" not in text
        ]
        self._write_manifest()
        self._assert_rejected("persisted-control-graph binding")

        self.manifest = copy.deepcopy(self.base_manifest)
        self.manifest["non_claims"] = [
            text for text in self.manifest["non_claims"] if "p-code" not in text
        ]
        self._write_manifest()
        self._assert_rejected("compiled-cache/p-code execution binding")

    def test_replay_validator_manifest_pins_are_exact_and_well_formed(self) -> None:
        self.manifest["replay_validators"]["frm_inventory"]["path"] = (
            "tools/forms-persistence/other.py"
        )
        self._write_manifest()
        self._assert_rejected("must be exactly")

        self.manifest = copy.deepcopy(self.base_manifest)
        self.manifest["replay_validators"]["cfb_inventory"]["sha256"] = "A" * 64
        self._write_manifest()
        self._assert_rejected("must be lowercase SHA-256")

    def test_exact_byte_module_loader_ignores_unchecked_hash_pyc(self) -> None:
        module_dir = self.temp_root / f"{self._testMethodName}-module"
        module_dir.mkdir()
        trusted_source = module_dir / "validator.py"
        trusted_source.write_text("VALUE = 'trusted'\n", encoding="utf-8")
        sentinel = module_dir / "pyc-executed.txt"
        malicious_source = module_dir / "malicious.py"
        malicious_source.write_text(
            f"from pathlib import Path\nPath({str(sentinel)!r}).write_text('executed')\nVALUE = 'malicious'\n",
            encoding="utf-8",
        )
        pyc_path = (
            module_dir
            / "__pycache__"
            / f"validator.{sys.implementation.cache_tag}.pyc"
        )
        pyc_path.parent.mkdir()
        py_compile.compile(
            str(malicious_source),
            cfile=str(pyc_path),
            dfile=str(trusted_source),
            doraise=True,
            invalidation_mode=py_compile.PycInvalidationMode.UNCHECKED_HASH,
        )

        loaded = oracle._load_python_module(
            trusted_source, f"oxforms_exact_bytes_{self._testMethodName}"
        )
        self.assertEqual("trusted", loaded.VALUE)
        self.assertFalse(sentinel.exists())

    def test_canonical_generation_is_sorted_deterministic_lf_and_direct(self) -> None:
        left = oracle.canonical_json_bytes({"z": 1, "a": {"y": 2, "b": 3}})
        right = oracle.canonical_json_bytes({"a": {"b": 3, "y": 2}, "z": 1})
        self.assertEqual(left, right)
        self.assertTrue(left.endswith(b"\n"))
        self.assertNotIn(b"\r", left)
        self.assertFalse(left.startswith(b"\xef\xbb\xbf"))

        manifest = self._validate()
        form_first = oracle.generate_form_code(manifest)
        module_first = oracle.generate_module_code(manifest)
        self.assertEqual(form_first, oracle.generate_form_code(manifest))
        self.assertEqual(module_first, oracle.generate_module_code(manifest))
        self.assertNotIn("CallByName", form_first + module_first)
        self.assertNotIn(".Value", form_first + module_first)
        self.assertNotIn("Err.Number", module_first)
        self.assertIn("Err.number", module_first)

        output_one = self.temp_root / f"{self._testMethodName}-one"
        output_two = self.temp_root / f"{self._testMethodName}-two"
        with self._cached_ledger():
            first = oracle.generate_sources(self.manifest_path, output_one, REPO_ROOT)
            second = oracle.generate_sources(self.manifest_path, output_two, REPO_ROOT)
        for role in first:
            self.assertEqual(Path(first[role]).read_bytes(), Path(second[role]).read_bytes())

    def test_default_member_and_trailing_omission_use_native_vba_syntax(self) -> None:
        code = oracle.generate_module_code(self._validate())
        default_block = re.search(
            r"Private Sub Probe_TextDefaultValueRead\(\)(.*?)End Sub",
            code,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(default_block)
        self.assertIn(
            "resultValue = W010MemberOracleForm.ProbeTextBox",
            default_block.group(1),
        )
        self.assertNotIn(
            "resultValue = W010MemberOracleForm.ProbeTextBox.Value",
            default_block.group(1),
        )
        self.assertIn(
            '    W010MemberOracleForm.ProbeListBox.AddItem "tail"\n', code
        )
        self.assertNotIn('ProbeListBox.AddItem "tail",', code)

    def test_generator_covers_middle_omission_pure_set_and_no_arg_method(self) -> None:
        manifest = self._validate()
        controls = {
            control["id"]: control for control in manifest["form"]["controls"]
        }
        common = {
            "ledger_row_id": "synthetic-unit-contract",
            "expect": {"outcome": "success"},
        }
        middle_omission = {
            **common,
            "id": "MiddleOmission",
            "target": "list_probe",
            "operation": "method",
            "member": "AddItem",
            "args": [
                {"kind": "string", "value": "item"},
                {"kind": "missing"},
                {"kind": "integer", "value": 2},
            ],
        }
        self.assertIn(
            'W010MemberOracleForm.ProbeListBox.AddItem "item", , 2',
            oracle._generate_probe_proc(
                middle_omission, manifest["form"]["name"], controls
            ),
        )

        pure_set = {
            **common,
            "id": "PureSet",
            "target": "label_probe",
            "operation": "property_set",
            "member": "Caption",
            "value": {"kind": "string", "value": "set-only"},
        }
        pure_set_code = oracle._generate_probe_proc(
            pure_set, manifest["form"]["name"], controls
        )
        self.assertIn(
            'W010MemberOracleForm.ProbeLabel.Caption = "set-only"', pure_set_code
        )
        self.assertNotIn("resultValue = W010MemberOracleForm.ProbeLabel.Caption", pure_set_code)

        no_arg_method = {
            **common,
            "id": "NoArgMethod",
            "target": "text_probe",
            "operation": "method",
            "member": "Copy",
        }
        no_arg_code = oracle._generate_probe_proc(
            no_arg_method, manifest["form"]["name"], controls
        )
        self.assertIn("    W010MemberOracleForm.ProbeTextBox.Copy\n", no_arg_code)
        self.assertNotIn("ProbeTextBox.Copy()", no_arg_code)

    def test_ledger_byte_and_canonical_pins_are_exact(self) -> None:
        for key, fragment in (
            ("file_sha256", "source-ledger identity"),
            ("canonical_sha256", "source-ledger identity"),
        ):
            with self.subTest(key=key):
                self.manifest = copy.deepcopy(self.base_manifest)
                self.manifest["ledger"][key] = "0" * 64
                self._write_manifest()
                self._assert_rejected(fragment)

    def test_ledger_row_owner_name_and_accessor_are_bound(self) -> None:
        label = self._step("LabelCaptionRoundtrip")
        button = self._step("ButtonCaptionRead")
        label["ledger_row_id"] = button["ledger_row_id"]
        self._write_manifest()
        self._assert_rejected("ledger facade owner")

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("ButtonCaptionRead")["operation"] = "method"
        self._write_manifest()
        self._assert_rejected("has no 'func' accessor")

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("ButtonCaptionRead")["ledger_row_id"] = "missing-row"
        self._write_manifest()
        self._assert_rejected("does not identify a row")

    def test_duplicate_unknown_bool_nan_and_bom_fail_closed(self) -> None:
        cases: list[tuple[str, bytes, str]] = []

        canonical = oracle.canonical_json_bytes(self.manifest)
        duplicate = canonical.replace(
            b'"schema_version": 1,',
            b'"schema_version": 1,\n  "schema_version": 1,',
            1,
        )
        cases.append(("duplicate", duplicate, "Duplicate JSON key"))

        unknown = copy.deepcopy(self.manifest)
        unknown["unexpected"] = True
        cases.append(("unknown", oracle.canonical_json_bytes(unknown), "unknown keys"))

        bool_version = copy.deepcopy(self.manifest)
        bool_version["schema_version"] = True
        cases.append(
            ("bool-version", oracle.canonical_json_bytes(bool_version), "must be integer 1")
        )

        nan_manifest = copy.deepcopy(self.manifest)
        nan_manifest["form"]["width_pt"] = float("nan")
        cases.append(
            (
                "nan",
                (json.dumps(nan_manifest, allow_nan=True) + "\n").encode("utf-8"),
                "Non-finite JSON number",
            )
        )
        cases.append(("bom", b"\xef\xbb\xbf" + canonical, "UTF-8 BOM"))

        for name, raw, fragment in cases:
            with self.subTest(name=name):
                self._write_raw_manifest(raw)
                self._assert_rejected(fragment)

    def test_identifiers_and_string_literals_are_injection_safe(self) -> None:
        invalid_mutations = (
            ("form-name", lambda value: value["form"].__setitem__("name", "Bad.Name")),
            (
                "control-name",
                lambda value: value["form"]["controls"][0].__setitem__(
                    "name", "ProbeLabel: End"
                ),
            ),
            (
                "member-name",
                lambda value: next(
                    step for step in value["steps"] if step["id"] == "ButtonCaptionRead"
                ).__setitem__("member", 'Caption": End Sub'),
            ),
        )
        for name, mutate in invalid_mutations:
            with self.subTest(name=name):
                self.manifest = copy.deepcopy(self.base_manifest)
                mutate(self.manifest)
                self._write_manifest()
                self._assert_rejected("safe VBA")

        for name, unsafe, fragment in (
            ("newline", "x\nEnd Sub", "VBA literal"),
            ("nul", "x\x00End Sub", "NUL"),
        ):
            with self.subTest(name=name):
                self.manifest = copy.deepcopy(self.base_manifest)
                self._step("LabelCaptionRoundtrip")["value"]["value"] = unsafe
                self._write_manifest()
                self._assert_rejected(fragment)

        self.manifest = copy.deepcopy(self.base_manifest)
        value = 'safe" : MsgBox "not code'
        self._step("LabelCaptionRoundtrip")["value"]["value"] = value
        self._write_manifest()
        code = oracle.generate_module_code(self._validate())
        self.assertIn('= "safe"" : MsgBox ""not code"', code)

    def test_html_progid_is_accepted(self) -> None:
        self.manifest["form"]["controls"].append(
            {
                "id": "html_text_probe",
                "name": "ProbeHtmlText",
                "prog_id": "Forms.HTML:Text.1",
                "fm20_type": "HTMLText",
                "left_pt": 18,
                "top_pt": 144,
                "width_pt": 132,
                "height_pt": 24,
                "initial_properties": {},
            }
        )
        self._write_manifest()
        validated = self._validate()
        self.assertEqual(
            "Forms.HTML:Text.1", validated["form"]["controls"][-1]["prog_id"]
        )

    def test_nested_frame_container_dag_is_accepted_and_cycles_are_rejected(self) -> None:
        frame = self._frame("frame_probe", "ProbeFrame")
        self.manifest["form"]["controls"].append(frame)
        self.manifest["form"]["controls"][0]["container"] = "control:frame_probe"
        self._write_manifest()
        self.assertEqual("control:frame_probe", self._validate()["form"]["controls"][0]["container"])

        self.manifest = copy.deepcopy(self.base_manifest)
        self.manifest["form"]["controls"].extend(
            [
                self._frame("frame_a", "ProbeFrameA", container="control:frame_b"),
                self._frame("frame_b", "ProbeFrameB", container="control:frame_a"),
            ]
        )
        self._write_manifest()
        self._assert_rejected("container cycle")

    def test_values_arguments_and_required_accessors_fail_closed(self) -> None:
        del self._step("LabelCaptionRoundtrip")["value"]
        self._write_manifest()
        self._assert_rejected("requires value")

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("ButtonCaptionRead")["args"] = [
            {"kind": "integer", "value": 1}
        ]
        self._write_manifest()
        self._assert_rejected("supplies 1 arguments")

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("ListAddItemDefaultIndex")["args"][0] = {"kind": "bogus"}
        self._write_manifest()
        self._assert_rejected("unsupported scalar kind")

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("ButtonCaptionRead")["operation"] = "property_roundtrip"
        self._step("ButtonCaptionRead")["value"] = {"kind": "string", "value": "x"}
        self._write_manifest()
        validated = self._validate()
        button_step = next(
            step for step in validated["steps"] if step["id"] == "ButtonCaptionRead"
        )
        self.assertEqual("property_roundtrip", button_step["operation"])

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("CheckValueCoercion")["expect"].pop("value")
        self._write_manifest()
        self._assert_rejected("must pin its returned scalar value")

        for missing_key in (
            "error_number",
            "last_dll_error_equals",
            "description_equals",
            "description_utf16_hex_equals",
            "source_equals",
            "help_file_equals",
            "help_context_equals",
            "line_equals",
            "error_stage",
        ):
            with self.subTest(missing_error_pin=missing_key):
                self.manifest = copy.deepcopy(self.base_manifest)
                self._step("TextMaxLengthInvalid")["expect"].pop(missing_key)
                self._write_manifest()
                self._assert_rejected(f"must pin {missing_key}")

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("TextMaxLengthInvalid")["expect"]["last_dll_error_equals"] = "0"
        self._write_manifest()
        self._assert_rejected("must be an integer")

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("TextMaxLengthInvalid")["expect"]["last_dll_error_equals"] = 2147483648
        self._write_manifest()
        self._assert_rejected("must fit a signed VBA Long")

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("ButtonCaptionRead")["expect"]["last_dll_error_equals"] = 0
        self._write_manifest()
        self._assert_rejected("success expectation cannot name an error")

    def test_error_description_display_and_raw_utf16_are_consistent(self) -> None:
        expectation = self._step("TextMaxLengthInvalid")["expect"]
        self.assertEqual("Forms.TextBox.1", expectation["source_equals"])
        self.assertEqual(0, expectation["last_dll_error_equals"])
        self.assertEqual("fm20.hlp", expectation["help_file_equals"])
        self.assertEqual(1000380, expectation["help_context_equals"])
        self.assertEqual(0, expectation["line_equals"])
        raw_description = expectation["description_equals"] + "\x00"
        self.assertEqual(
            oracle.utf16_code_unit_hex(raw_description),
            expectation["description_utf16_hex_equals"],
        )
        self.assertTrue(expectation["description_utf16_hex_equals"].endswith(" 0000"))

        mutations = (
            (
                "lowercase",
                lambda value: value.lower(),
                "canonical uppercase",
            ),
            (
                "double-space",
                lambda value: value.replace("0043 006F", "0043  006F", 1),
                "canonical uppercase",
            ),
            (
                "embedded-nul",
                lambda _value: "0041 0000 0042",
                "at most one U+0000",
            ),
            (
                "double-terminal-nul",
                lambda value: value + " 0000",
                "at most one U+0000",
            ),
        )
        for name, mutate, fragment in mutations:
            with self.subTest(name=name):
                self.manifest = copy.deepcopy(self.base_manifest)
                error_expectation = self._step("TextMaxLengthInvalid")["expect"]
                error_expectation["description_utf16_hex_equals"] = mutate(
                    error_expectation["description_utf16_hex_equals"]
                )
                if name == "embedded-nul":
                    error_expectation["description_equals"] = "AB"
                self._write_manifest()
                self._assert_rejected(fragment)

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("TextMaxLengthInvalid")["expect"]["description_equals"] += "x"
        self._write_manifest()
        self._assert_rejected("with one final U+0000 removed")

    def test_event_signature_type_passing_and_return_wrapper_are_bound(self) -> None:
        mutations = (
            (
                "type",
                lambda event: event["parameters"][0].__setitem__("type", "MSForms.ReturnInteger"),
                "ledger type",
            ),
            ("passing", lambda event: event["parameters"][0].__setitem__("passing", "ByRef"), "passing mode"),
            ("value-member", lambda event: event["parameters"][0].pop("value_member"), "mutable Value member"),
        )
        for name, mutate, fragment in mutations:
            with self.subTest(name=name):
                self.manifest = copy.deepcopy(self.base_manifest)
                mutate(self._event("TextExitMutation"))
                self._write_manifest()
                self._assert_rejected(fragment)

        self.manifest = copy.deepcopy(self.base_manifest)
        self._event("TextExitMutation")["parameters"][0]["type"] = "Boolean"
        self._write_manifest()
        self._assert_rejected("only valid for MSForms.Return* helper parameters")

        self.manifest = copy.deepcopy(self.base_manifest)
        self._write_manifest()
        form_code = oracle.generate_form_code(self._validate())
        self.assertIn("Cancel.value", form_code)
        self.assertNotIn("Cancel.Value", form_code)

    def test_event_mutations_must_target_the_declared_mutable_value(self) -> None:
        event = self._event("TextExitMutation")
        event["mutations"][0]["parameter"] = "Unknown"
        self._write_manifest()
        self._assert_rejected("does not identify an event parameter")

        self.manifest = copy.deepcopy(self.base_manifest)
        event = self._event("TextExitMutation")
        event["mutations"][0]["member"] = "Other"
        self._write_manifest()
        self._assert_rejected("mutable Value member")

    def test_immutable_ledger_slice_and_general_w010_bead_are_supported(self) -> None:
        verified = oracle.verify_current_ledger_snapshot(self.manifest_path, REPO_ROOT)
        self.assertEqual(15, verified["rows"])

        self.manifest["bead"] = "oxforms-jbjp.15"
        self._write_manifest()
        self.assertEqual("oxforms-jbjp.15", self._validate()["bead"])

        self.manifest = copy.deepcopy(self.base_manifest)
        self.manifest["ledger"]["snapshot_sha256"] = "0" * 64
        self._write_manifest()
        self._assert_rejected("immutable selected-row snapshot")

    def test_indexed_default_generation_and_causal_event_context_are_explicit(self) -> None:
        manifest = self._validate()
        controls = {control["id"]: control for control in manifest["form"]["controls"]}
        indexed = copy.deepcopy(self._step("TextDefaultValueRead"))
        indexed["args"] = [{"kind": "integer", "value": 2}]
        block = oracle._generate_probe_proc(indexed, manifest["form"]["name"], controls)
        self.assertIn("resultValue = W010MemberOracleForm.ProbeTextBox(2)", block)

        module = oracle.generate_module_code(manifest)
        self.assertIn('mCurrentStep = "TextValueForEvents"', module)
        self.assertIn('mCurrentStep = "AttemptExitTransfer"', module)
        self.assertIn('"trigger_step_id"', module)

        self.manifest["events"][0]["trigger_step_id"] = "UnknownStep"
        self._write_manifest()
        self._assert_rejected("does not identify a declared execution step")

    def test_focus_outcomes_are_strict_and_generated_with_scoped_error_handling(self) -> None:
        manifest = self._validate()
        success_step = next(
            step for step in manifest["steps"] if step["id"] == "FocusTextForExit"
        )
        veto_step = next(
            step for step in manifest["steps"] if step["id"] == "AttemptExitTransfer"
        )
        self.assertEqual({"outcome": "success"}, success_step["expect"])
        self.assertEqual(-2147467259, veto_step["expect"]["error_number"])
        self.assertEqual("Unspecified error.", veto_step["expect"]["description_equals"])
        self.assertEqual("Forms.Form.1", veto_step["expect"]["source_equals"])
        self.assertEqual("&H80004005", oracle.vba_long_literal(-2147467259))
        self.assertEqual("&H80000000", oracle.vba_long_literal(-2147483648))
        self.assertEqual("2147483647&", oracle.vba_long_literal(2147483647))

        module = oracle.generate_module_code(manifest)
        success_block = module.split('mCurrentStep = "FocusTextForExit"', 1)[1].split(
            'mCurrentStep = "TextValueForEvents"', 1
        )[0]
        veto_block = module.split('mCurrentStep = "AttemptExitTransfer"', 1)[1].split(
            'mCurrentStep = "DrainExitEvent"', 1
        )[0]
        for block in (success_block, veto_block):
            self.assertIn("On Error Resume Next", block)
            self.assertIn("Err.Clear", block)
            self.assertIn("failureNumber = Err.number", block)
            self.assertIn("failureDescription = Err.Description", block)
            self.assertIn("failureSource = Err.Source", block)
            self.assertIn("On Error GoTo HarnessFailed", block)
            self.assertLess(block.index("On Error Resume Next"), block.index(".SetFocus"))
            self.assertLess(block.index(".SetFocus"), block.index("failureNumber = Err.number"))
            self.assertLess(
                block.index("failureSource = Err.Source"),
                block.index("On Error GoTo HarnessFailed"),
            )
        self.assertIn("If failureNumber <> 0 Then", success_block)
        self.assertIn(
            'If failureNumber <> &H80004005 Or failureDescription <> "Unspecified error." '
            'Or failureSource <> "Forms.Form.1" Then',
            veto_block,
        )
        self.assertIn("Err.Raise vbObjectError + 2048", veto_block)

        form_code = oracle.generate_form_code(manifest)
        exit_handler = form_code.split("Private Sub ProbeTextBox_Exit", 1)[1].split(
            "End Sub", 1
        )[0]
        self.assertIn("If Not OracleRecordingEnabled() Then Exit Sub", exit_handler)
        self.assertLess(
            exit_handler.index("If Not OracleRecordingEnabled() Then Exit Sub"),
            exit_handler.index("Cancel.value = True"),
        )
        failure_handler = module.split("HarnessFailed:", 1)[1].split("End Sub", 1)[0]
        self.assertLess(
            failure_handler.index("mRecordingEnabled = False"),
            failure_handler.index("UnloadMemberOracleIfLoaded"),
        )
        self.assertNotIn("Unload W010MemberOracleForm", module)
        unload_helper = module.split(
            "Private Sub UnloadMemberOracleIfLoaded()", 1
        )[1].split("End Sub", 1)[0]
        self.assertIn("For Each loadedForm In UserForms", unload_helper)
        self.assertIn(
            'StrComp(TypeName(loadedForm), "W010MemberOracleForm", vbBinaryCompare)',
            unload_helper,
        )
        self.assertIn("Unload loadedForm", unload_helper)
        self.assertIn("Public Function OracleRecordingEnabled() As Boolean", module)
        close_handler = module.split("Public Sub CloseMemberOracle()", 1)[1].split(
            "End Sub", 1
        )[0]
        self.assertNotIn("On Error Resume Next", close_handler)
        self.assertLess(
            close_handler.index("mRecordingEnabled = False"),
            close_handler.index("UnloadMemberOracleIfLoaded"),
        )
        self.assertLess(
            close_handler.index("UnloadMemberOracleIfLoaded"),
            close_handler.index("DoEvents"),
        )

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("FocusTextForExit").pop("expect")
        self._write_manifest()
        self._assert_rejected("missing keys: expect")

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("FocusTextForExit")["expect"]["outcome"] = "ignored"
        self._write_manifest()
        self._assert_rejected("must be success or error")

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("FocusTextForExit")["expect"]["error_number"] = -1
        self._write_manifest()
        self._assert_rejected("successful focus expectation cannot name errors")

        for missing_key in ("error_number", "description_equals", "source_equals"):
            with self.subTest(missing_focus_error_pin=missing_key):
                self.manifest = copy.deepcopy(self.base_manifest)
                self._step("AttemptExitTransfer")["expect"].pop(missing_key)
                self._write_manifest()
                self._assert_rejected(f"focus error expectation must pin {missing_key}")

        for invalid_number, fragment in (
            (0, "must be nonzero"),
            (2147483648, "must fit a signed VBA Long"),
        ):
            with self.subTest(invalid_focus_error_number=invalid_number):
                self.manifest = copy.deepcopy(self.base_manifest)
                self._step("AttemptExitTransfer")["expect"]["error_number"] = invalid_number
                self._write_manifest()
                self._assert_rejected(fragment)

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("AttemptExitTransfer")["expect"]["description_equals"] = "two\nlines"
        self._write_manifest()
        self._assert_rejected("bounded single-line VBA string")

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("AttemptExitTransfer")["expect"]["source_equals"] = "Forms.Form.1\x00"
        self._write_manifest()
        self._assert_rejected("must not contain NUL")

        self.manifest = copy.deepcopy(self.base_manifest)
        self._step("AttemptExitTransfer")["expect"]["error_number"] = -1
        self._write_manifest()
        mutated_module = oracle.generate_module_code(self._validate())
        self.assertIn("failureNumber <> &HFFFFFFFF", mutated_module)

    def test_control_type_and_vba_case_collisions_fail_closed(self) -> None:
        self.manifest["form"]["controls"][0]["fm20_type"] = "TextBox"
        self._write_manifest()
        self._assert_rejected("canonical ProgID")

        self.manifest = copy.deepcopy(self.base_manifest)
        duplicate = copy.deepcopy(self.manifest["steps"][0])
        duplicate["id"] = self.manifest["steps"][0]["id"].swapcase()
        self.manifest["steps"].append(duplicate)
        self._write_manifest()
        self._assert_rejected("case-insensitive")

        self.manifest = copy.deepcopy(self.base_manifest)
        duplicate_event = copy.deepcopy(self.manifest["events"][0])
        duplicate_event["id"] = "DuplicateChangeHandler"
        self.manifest["events"].append(duplicate_event)
        self._write_manifest()
        self._assert_rejected("duplicate VBA handler")

    def test_err_fields_are_snapshotted_before_hex_helper_call(self) -> None:
        code = oracle.generate_module_code(self._validate())
        snapshot_count = 0
        for block in re.findall(r"Private Sub Probe_.*?End Sub", code, flags=re.DOTALL):
            for match in re.finditer(r"errorLastDllError = Err\.LastDllError(.*?)errorHex = OracleErrorHex", block, flags=re.DOTALL):
                snapshot_count += 1
                snapshot = match.group(1)
                self.assertIn("errorNumber = Err.number", snapshot)
                self.assertIn("errorDescription = Err.Description", snapshot)
                self.assertIn("errorSource = Err.Source", snapshot)
                self.assertIn("errorHelpFile = Err.HelpFile", snapshot)
                self.assertIn("errorHelpContext = Err.HelpContext", snapshot)
                self.assertIn("errorLine = Erl", snapshot)
                self.assertIn(
                    "errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)",
                    snapshot,
                )
                self.assertIn(
                    "errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)",
                    snapshot,
                )
                self.assertLess(
                    snapshot.index("errorNumber = Err.number"),
                    snapshot.index("errorDescription = Err.Description"),
                )
                self.assertLess(
                    snapshot.index("errorLine = Erl"),
                    snapshot.index("errorDescriptionUtf16Hex = OracleUtf16Hex"),
                )
                self.assertLess(
                    snapshot.index("errorDescriptionUtf16Hex = OracleUtf16Hex"),
                    snapshot.index(
                        "errorDescription = OracleWorksheetSafeErrorDescription"
                    ),
                )

        probe_steps = [step for step in self.manifest["steps"] if step["kind"] == "probe"]
        self.assertEqual(
            len(probe_steps)
            + sum(step["operation"] == "property_roundtrip" for step in probe_steps),
            snapshot_count,
        )

        self.assertIn("On Error GoTo HarnessFailed", code)
        self.assertIn('If index > 1 Then encoded = encoded & " "', code)
        self.assertIn("CLng(AscW(Mid$(value, index, 1))) And &HFFFF&", code)
        self.assertIn("If Len(value) > 0 Then", code)
        self.assertNotIn("Len(value) > 0 And AscW", code)
        self.assertIn("Left$(value, Len(value) - 1)", code)
        self.assertIn('"error_description_utf16_hex"', code)
        self.assertIn('"error_last_dll_error"', code)
        self.assertIn("Public Function GetMemberOracleHarnessError() As String", code)
        self.assertIn("Public Function OracleRecordingEnabled() As Boolean", code)
        self.assertIn("If Not mRecordingEnabled Then Exit Sub", code)
        self.assertIn("mRecordingEnabled = False", code)
        self.assertEqual(22, len(oracle.RESULT_HEADERS))
        self.assertEqual(9, len(oracle.EVENT_HEADERS))
        self.assertIn(
            "WriteOracleHeaders resultSheet, Array("
            + ", ".join(oracle._vba_string(header) for header in oracle.RESULT_HEADERS)
            + ")",
            code,
        )
        runner = (
            REPO_ROOT / "tools" / "office-oracle" / "Capture-MSFormsMemberOracle.ps1"
        ).read_text(encoding="utf-8")
        self.assertIn("!GetMemberOracleHarnessError", runner)
        self.assertIn("$workbooks.Add(-4167)", runner)
        self.assertIn("-Operation 'cleanup_close_member_oracle'", runner)
        self.assertGreaterEqual(runner.count("Wait-ForOwnedFormWindowClosed"), 3)
        self.assertIn("-IncludeHidden", runner)
        self.assertIn("GetClassNameW", runner)
        self.assertIn("'ThunderDFrame'", runner)
        self.assertNotIn("$buffer.ToString().Contains($Caption", runner)
        self.assertIn("$copied -le 0", runner)
        self.assertIn("$script:OwnedFormInspectionFailure", runner)
        self.assertIn("throw $script:OwnedFormInspectionFailure", runner)
        self.assertIn("Add-CleanupProgress", runner)
        cleanup_teardown = runner.index("-Operation 'cleanup_close_member_oracle'")
        cleanup_workbook_close = runner.index("$workbook.Close($false)", cleanup_teardown)
        self.assertLess(cleanup_teardown, cleanup_workbook_close)
        self.assertIn("$workbook = $null; $workbooks = $null", runner)
        self.assertIn("$excel = $null", runner)
        self.assertIn("'error_number','error_last_dll_error','error_hex'", runner)
        self.assertIn("'sequence','error_number','error_last_dll_error'", runner)
        runner_headers = re.search(r"\$resultHeaders = @\(([^)]*)\)", runner)
        self.assertIsNotNone(runner_headers)
        self.assertEqual(
            list(oracle.RESULT_HEADERS),
            re.findall(r"'([^']*)'", runner_headers.group(1)),
        )
        runner_event_headers = re.search(r"\$eventHeaders = @\(([^)]*)\)", runner)
        self.assertIsNotNone(runner_event_headers)
        self.assertEqual(
            list(oracle.EVENT_HEADERS),
            re.findall(r"'([^']*)'", runner_event_headers.group(1)),
        )

    def test_excel_default_bin_content_type_is_valid_for_vba_project(self) -> None:
        workbook = self.temp_root / f"{self._testMethodName}.xlsm"
        cfb_module = oracle._load_python_module(
            REPO_ROOT / "tools" / "forms-persistence" / "cfb_inventory.py",
            "oxforms_oracle_test_cfb_inventory",
        )
        captured_workbook = (
            REPO_ROOT
            / "docs"
            / "evidence"
            / "W003_excel_forms_oracle_capture"
            / "captures"
            / "rectangle-label-20260622T170958Z"
            / "rectangle-label-oracle.xlsm"
        )
        with zipfile.ZipFile(captured_workbook, "r") as package:
            vba_project = package.read("xl/vbaProject.bin")
        content_types = b'''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="bin" ContentType="application/vnd.ms-office.vbaProject"/>
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.ms-excel.sheet.macroEnabled.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
</Types>'''
        root_relationships = b'''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>'''
        workbook_xml = b'''<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="W010ProbeResults" sheetId="1" r:id="rId1"/>
    <sheet name="W010EventLog" sheetId="2" r:id="rId2"/>
  </sheets>
</workbook>'''
        workbook_relationships = b'''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
  <Relationship Id="rId3" Type="http://schemas.microsoft.com/office/2006/relationships/vbaProject" Target="vbaProject.bin"/>
  <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
</Relationships>'''
        shared_strings = b'''<?xml version="1.0" encoding="UTF-8"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <si><t>A</t></si><si><t>B</t></si><si><t>text</t></si>
</sst>'''
        result_sheet_xml = b'''<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>
<row r="2"><c r="A2"><v>1</v></c><c r="B2" t="s"><v>2</v></c></row>
</sheetData></worksheet>'''
        event_sheet_xml = b'''<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
<row r="1"><c r="A1" t="inlineStr"><is><t>event</t></is></c></row>
</sheetData></worksheet>'''
        with zipfile.ZipFile(workbook, "w", compression=zipfile.ZIP_DEFLATED) as package:
            package.writestr("[Content_Types].xml", content_types)
            package.writestr("_rels/.rels", root_relationships)
            package.writestr("xl/workbook.xml", workbook_xml)
            package.writestr("xl/_rels/workbook.xml.rels", workbook_relationships)
            package.writestr("xl/sharedStrings.xml", shared_strings)
            package.writestr("xl/worksheets/sheet1.xml", result_sheet_xml)
            package.writestr("xl/worksheets/sheet2.xml", event_sheet_xml)
            package.writestr(
                "xl/vbaProject.bin",
                vba_project,
            )

        expected_vba_sources = {
            "OxFormsRectangleOracle": (
                "Module",
                "Option Explicit\n\n"
                "Public Sub ShowRectangleLabelOracle()\n"
                "    OxFormsRectangleOracleForm.Show vbModeless\n"
                "End Sub\n\n"
                "Public Sub HideRectangleLabelOracle()\n"
                "    Unload OxFormsRectangleOracleForm\n"
                "End Sub\n",
            ),
            "OxFormsRectangleOracleForm": ("BaseClass", ""),
        }

        def validate_workbook(candidate: Path) -> dict[str, list[list[str]]]:
            return oracle._validate_xlsm_package(
                candidate,
                "W010ProbeResults",
                "W010EventLog",
                {"W010ProbeResults": (2, 2), "W010EventLog": (1, 1)},
                expected_vba_sources,
                cfb_module,
            )

        tables = validate_workbook(workbook)
        self.assertEqual([["A", "B"], ["1", "text"]], tables["W010ProbeResults"])
        self.assertEqual([["event"]], tables["W010EventLog"])

        preopen_workbook = self.temp_root / f"{self._testMethodName}-preopen.xlsm"
        preopen_content_types = content_types.replace(
            b'  <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\n',
            b"",
        ).replace(
            b'  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>\n',
            b"",
        )
        preopen_workbook_xml = b'''<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
</workbook>'''
        preopen_relationships = b'''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.microsoft.com/office/2006/relationships/vbaProject" Target="vbaProject.bin"/>
</Relationships>'''
        blank_sheet_xml = b'''<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData/></worksheet>'''

        def write_preopen(
            candidate: Path,
            workbook_part: bytes,
            *,
            worksheet_part: bytes = blank_sheet_xml,
            workbook_rels_part: bytes = preopen_relationships,
            extra_parts: dict[str, bytes] | None = None,
        ) -> None:
            with zipfile.ZipFile(
                candidate, "w", compression=zipfile.ZIP_DEFLATED
            ) as package:
                package.writestr("[Content_Types].xml", preopen_content_types)
                package.writestr("_rels/.rels", root_relationships)
                package.writestr("xl/workbook.xml", workbook_part)
                package.writestr(
                    "xl/_rels/workbook.xml.rels", workbook_rels_part
                )
                package.writestr("xl/worksheets/sheet1.xml", worksheet_part)
                package.writestr("xl/vbaProject.bin", vba_project)
                for name, content in (extra_parts or {}).items():
                    package.writestr(name, content)

        write_preopen(preopen_workbook, preopen_workbook_xml)
        self.assertEqual(
            {},
            oracle._validate_xlsm_package(
                preopen_workbook,
                "unused-results",
                "unused-events",
                {},
                expected_vba_sources,
                cfb_module,
                preopen=True,
                expected_package_sha256=oracle.sha256_file(preopen_workbook),
            ),
        )
        defined_name_preopen = self.temp_root / (
            f"{self._testMethodName}-preopen-defined-name.xlsm"
        )
        write_preopen(
            defined_name_preopen,
            preopen_workbook_xml.replace(
                b"<sheets>",
                b'<definedNames><definedName name="Auto_Open">Sheet1!$A$1</definedName></definedNames><sheets>',
            ),
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "must not contain defined names"
        ):
            oracle._validate_xlsm_package(
                defined_name_preopen,
                "unused-results",
                "unused-events",
                {},
                expected_vba_sources,
                cfb_module,
                preopen=True,
            )

        relationship_feature_preopen = self.temp_root / (
            f"{self._testMethodName}-preopen-worksheet-feature.xlsm"
        )
        write_preopen(
            relationship_feature_preopen,
            preopen_workbook_xml,
            worksheet_part=blank_sheet_xml.replace(
                b'<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
                b'<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
                b'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
            ).replace(
                b"<sheetData/>",
                b'<sheetData/><hyperlinks><hyperlink ref="A1" r:id="rId1"/></hyperlinks>',
            ),
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "non-plain feature elements"
        ):
            oracle._validate_xlsm_package(
                relationship_feature_preopen,
                "unused-results",
                "unused-events",
                {},
                expected_vba_sources,
                cfb_module,
                preopen=True,
            )

        worksheet_rels_preopen = self.temp_root / (
            f"{self._testMethodName}-preopen-worksheet-rels.xlsm"
        )
        write_preopen(
            worksheet_rels_preopen,
            preopen_workbook_xml,
            extra_parts={
                "xl/worksheets/_rels/sheet1.xml.rels": (
                    b'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                    b'<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" '
                    b'Target="https://example.invalid/" TargetMode="External"/>'
                    b"</Relationships>"
                )
            },
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "exact closed root/workbook graph"
        ):
            oracle._validate_xlsm_package(
                worksheet_rels_preopen,
                "unused-results",
                "unused-events",
                {},
                expected_vba_sources,
                cfb_module,
                preopen=True,
            )

        unbound_sheet_preopen = self.temp_root / (
            f"{self._testMethodName}-preopen-unbound-sheet.xlsm"
        )
        write_preopen(
            unbound_sheet_preopen,
            preopen_workbook_xml,
            workbook_rels_part=preopen_relationships.replace(
                b"</Relationships>",
                b'<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
                b'Target="worksheets/sheet2.xml"/></Relationships>',
            ),
            extra_parts={"xl/worksheets/sheet2.xml": blank_sheet_xml},
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError,
            "worksheet relationships and declared sheets must form one exact closure",
        ):
            oracle._validate_xlsm_package(
                unbound_sheet_preopen,
                "unused-results",
                "unused-events",
                {},
                expected_vba_sources,
                cfb_module,
                preopen=True,
            )

        parsed_vba = cfb_module.parse_cfb(vba_project, signature_offset=0)
        decompressed_dir = oracle._decompress_vba_container(
            parsed_vba.read_stream("/VBA/dir"), "test VBA dir stream"
        )
        self.assertEqual(1252, oracle._vba_project_code_page(decompressed_dir))
        code_page_record = struct.pack("<HI", 0x0003, 2)
        code_page_offset = decompressed_dir.find(code_page_record)
        self.assertGreaterEqual(code_page_offset, 0)
        unsupported_code_page = bytearray(decompressed_dir)
        struct.pack_into("<H", unsupported_code_page, code_page_offset + 6, 0xFFFF)
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "PROJECTCODEPAGE 65535 is not supported"
        ):
            oracle._vba_project_code_page(bytes(unsupported_code_page))
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "trailing bytes after PROJECTTERMINATOR"
        ):
            oracle._vba_module_records(decompressed_dir + b"\x00")

        class CfbOverlay:
            def __init__(
                self,
                stream_overrides: dict[str, bytes] | None = None,
                extra_entries: list[dict[str, str]] | None = None,
            ) -> None:
                self.stream_overrides = stream_overrides or {}
                self.extra_entries = extra_entries or []

            def read_stream(self, path: str) -> bytes:
                return self.stream_overrides.get(path, parsed_vba.read_stream(path))

            def to_dict(self) -> dict:
                inventory = copy.deepcopy(parsed_vba.to_dict())
                inventory["entries"].extend(self.extra_entries)
                return inventory

        project_text = parsed_vba.read_stream("/PROJECT")
        project_with_extra_module = project_text.replace(
            b'Name="VBAProject"', b"Module=HiddenExecutable\r\nName=\"VBAProject\""
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError,
            "executable module declarations do not exactly match",
        ):
            oracle._validate_vba_project_sources(
                CfbOverlay({"/PROJECT": project_with_extra_module}),
                expected_vba_sources,
            )

        project_with_late_declaration = project_text + b"Module=LateExecutable\r\n"
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "module declaration outside its main header"
        ):
            oracle._validate_vba_project_sources(
                CfbOverlay({"/PROJECT": project_with_late_declaration}),
                expected_vba_sources,
            )

        with self.assertRaisesRegex(
            oracle.OracleValidationError,
            "storage module streams do not exactly match PROJECT declarations",
        ):
            oracle._validate_vba_project_sources(
                CfbOverlay(
                    extra_entries=[
                        {"path": "/VBA/HiddenExecutable", "type": "stream"}
                    ]
                ),
                expected_vba_sources,
            )

        def compress_literal_container(source: bytes) -> bytes:
            self.assertLessEqual(len(source) + ((len(source) + 7) // 8), 4096)
            payload = bytearray()
            for offset in range(0, len(source), 8):
                payload.append(0)
                payload.extend(source[offset : offset + 8])
            header = 0x8000 | 0x3000 | (len(payload) - 1)
            return b"\x01" + struct.pack("<H", header) + bytes(payload)

        workbook_stream_name, workbook_source_offset = oracle._vba_module_record(
            decompressed_dir, "ThisWorkbook"
        )
        workbook_stream_path = f"/VBA/{workbook_stream_name}"
        workbook_stream = parsed_vba.read_stream(workbook_stream_path)
        workbook_source = oracle._decompress_vba_container(
            workbook_stream[workbook_source_offset:], "test workbook source"
        )
        injected_source = workbook_source + (
            b"Private Sub Workbook_Open()\r\n"
            b"    MsgBox \"hidden\"\r\n"
            b"End Sub\r\n"
        )
        injected_stream = workbook_stream[:workbook_source_offset] + (
            compress_literal_container(injected_source)
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "must have an empty source body"
        ):
            oracle._validate_vba_project_sources(
                CfbOverlay({workbook_stream_path: injected_stream}),
                expected_vba_sources,
            )

        original_module_contract = expected_vba_sources["OxFormsRectangleOracle"]
        expected_vba_sources["OxFormsRectangleOracle"] = (
            "Module",
            original_module_contract[1].replace("vbModeless", "vbModal"),
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "source does not match deterministic generation"
        ):
            validate_workbook(workbook)
        expected_vba_sources["OxFormsRectangleOracle"] = original_module_contract

        def rewrite_package(
            suffix: str, replacements: dict[str, bytes]
        ) -> Path:
            rewritten = self.temp_root / f"{self._testMethodName}-{suffix}.xlsm"
            with zipfile.ZipFile(workbook, "r") as source, zipfile.ZipFile(
                rewritten, "w", compression=zipfile.ZIP_DEFLATED
            ) as target:
                for info in source.infolist():
                    target.writestr(
                        info.filename,
                        replacements.get(info.filename, source.read(info.filename)),
                    )
            return rewritten

        oversized = rewrite_package(
            "oversized",
            {"xl/worksheets/sheet1.xml": result_sheet_xml.replace(b"B2", b"XFD2")},
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "exceeds its declared 2-column evidence table"
        ):
            validate_workbook(oversized)

        missing_office_document = rewrite_package(
            "missing-office-document",
            {
                "_rels/.rels": (
                    b'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>'
                )
            },
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "exactly one xl/workbook.xml officeDocument"
        ):
            validate_workbook(missing_office_document)

        phonetic_strings = shared_strings.replace(
            b"<si><t>A</t></si>",
            b'<si><t>A</t><rPh sb="0" eb="1"><t>hidden-phonetic</t></rPh></si>',
        )
        phonetic_package = rewrite_package(
            "phonetic", {"xl/sharedStrings.xml": phonetic_strings}
        )
        phonetic_tables = validate_workbook(phonetic_package)
        self.assertEqual("A", phonetic_tables["W010ProbeResults"][0][0])

        rich_strings = shared_strings.replace(
            b"<si><t>A</t></si>",
            b"<si><r><rPr/><t>A</t></r></si>",
        )
        rich_package = rewrite_package(
            "rich-string", {"xl/sharedStrings.xml": rich_strings}
        )
        self.assertEqual(
            "A", validate_workbook(rich_package)["W010ProbeResults"][0][0]
        )

        preserved_strings = shared_strings.replace(
            b"<si><t>A</t></si>",
            b'<si><t xml:space="preserve">A</t></si>',
        )
        preserved_package = rewrite_package(
            "preserved-string", {"xl/sharedStrings.xml": preserved_strings}
        )
        self.assertEqual(
            "A", validate_workbook(preserved_package)["W010ProbeResults"][0][0]
        )

        mixed_string_storage = rewrite_package(
            "mixed-string-storage",
            {
                "xl/sharedStrings.xml": shared_strings.replace(
                    b"<si><t>A</t></si>",
                    b"<si><t>A</t><r><t>hidden</t></r></si>",
                )
            },
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "exactly one direct text node"
        ):
            validate_workbook(mixed_string_storage)

        nested_text_leaf = rewrite_package(
            "nested-text-leaf",
            {
                "xl/sharedStrings.xml": shared_strings.replace(
                    b"<si><t>A</t></si>",
                    b"<si><t>A<ignored/>hidden</t></si>",
                )
            },
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "non-leaf/invalid text node"
        ):
            validate_workbook(nested_text_leaf)

        invalid_numeric = rewrite_package(
            "invalid-numeric",
            {
                "xl/worksheets/sheet1.xml": result_sheet_xml.replace(
                    b'<c r="B2" t="s"><v>2</v></c>',
                    b'<c r="B2"><v>text</v></c>',
                )
            },
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "invalid numeric value"
        ):
            validate_workbook(invalid_numeric)

        nested_value_leaf = rewrite_package(
            "nested-value-leaf",
            {
                "xl/worksheets/sheet1.xml": result_sheet_xml.replace(
                    b'<c r="A2"><v>1</v></c>',
                    b'<c r="A2"><v>1<ignored/>999</v></c>',
                )
            },
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "non-leaf/invalid value node"
        ):
            validate_workbook(nested_value_leaf)

        pathological_reference = result_sheet_xml.replace(
            b"B2", (b"A" * 10_000) + b"2"
        )
        pathological_package = rewrite_package(
            "pathological-reference",
            {"xl/worksheets/sheet1.xml": pathological_reference},
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "invalid cell reference"
        ):
            validate_workbook(pathological_package)

        nested_sheets = rewrite_package(
            "nested-sheets",
            {
                "xl/workbook.xml": workbook_xml.replace(
                    b"  <sheets>", b"  <extLst><sheets>"
                ).replace(b"  </sheets>", b"  </sheets></extLst>")
            },
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "exactly one direct sheets collection"
        ):
            validate_workbook(nested_sheets)

        nested_selected_sheet = rewrite_package(
            "nested-selected-sheet",
            {
                "xl/workbook.xml": workbook_xml.replace(
                    b'<sheet name="W010ProbeResults" sheetId="1" r:id="rId1"/>',
                    b'<sheet name="W010ProbeResults" sheetId="1" r:id="rId1"><ignored/></sheet>',
                )
            },
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "invalid worksheet declaration"
        ):
            validate_workbook(nested_selected_sheet)

        nested_sheet_data = rewrite_package(
            "nested-sheet-data",
            {
                "xl/worksheets/sheet1.xml": result_sheet_xml.replace(
                    b"<sheetData>", b"<extLst><sheetData>"
                ).replace(b"</sheetData>", b"</sheetData></extLst>")
            },
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError,
            "exactly one direct sheetData|non-plain feature elements",
        ):
            validate_workbook(nested_sheet_data)

        unexpected_row_child = rewrite_package(
            "unexpected-row-child",
            {
                "xl/worksheets/sheet1.xml": result_sheet_xml.replace(
                    b'<row r="1">', b'<row r="1"><ignored/>'
                )
            },
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "row 1 has invalid children"
        ):
            validate_workbook(unexpected_row_child)

        unexpected_cell_child = rewrite_package(
            "unexpected-cell-child",
            {
                "xl/worksheets/sheet1.xml": result_sheet_xml.replace(
                    b'<c r="A1" t="s"><v>0</v></c>',
                    b'<c r="A1" t="s"><ignored/><v>0</v></c>',
                )
            },
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "cell A1 has invalid children"
        ):
            validate_workbook(unexpected_cell_child)

        nested_relationship = rewrite_package(
            "nested-relationship",
            {
                "xl/_rels/workbook.xml.rels": workbook_relationships.replace(
                    b'<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>',
                    b'<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"><ignored/></Relationship>',
                )
            },
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "unexpected workbook-relationship element"
        ):
            validate_workbook(nested_relationship)

        aliased_evidence_part = rewrite_package(
            "aliased-evidence-part",
            {
                "xl/_rels/workbook.xml.rels": workbook_relationships.replace(
                    b'Target="worksheets/sheet2.xml"',
                    b'Target="worksheets/sheet1.xml"',
                )
            },
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError,
            "worksheet names, ids, relationships, and parts must be one-to-one",
        ):
            validate_workbook(aliased_evidence_part)

        decoy_sheet_alias = rewrite_package(
            "decoy-sheet-alias",
            {
                "xl/workbook.xml": workbook_xml.replace(
                    b"  </sheets>",
                    b'    <sheet name="Decoy" sheetId="3" r:id="rId1"/>\n  </sheets>',
                )
            },
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError,
            "worksheet names, ids, relationships, and parts must be one-to-one",
        ):
            validate_workbook(decoy_sheet_alias)

    def test_png_replay_checks_complete_rgba_scanlines(self) -> None:
        captured_png = (
            REPO_ROOT
            / "docs"
            / "evidence"
            / "W003_excel_forms_oracle_capture"
            / "captures"
            / "rectangle-label-20260622T170958Z"
            / "window-capture.png"
        )
        self.assertEqual((320, 240), oracle._png_dimensions(captured_png))

        def chunk(kind: bytes, payload: bytes) -> bytes:
            return (
                struct.pack(">I", len(payload))
                + kind
                + payload
                + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
            )

        malformed = self.temp_root / f"{self._testMethodName}.png"
        ihdr = struct.pack(">IIBBBBB", 2, 2, 8, 6, 0, 0, 0)
        malformed.write_bytes(
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(b"\x00" + (b"\x00" * 8)))
            + chunk(b"IEND", b"")
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "decoded scanlines have length"
        ):
            oracle._png_dimensions(malformed)

        solid = self.temp_root / f"{self._testMethodName}-solid.png"
        solid_pixels = b"\x00" + (b"\x00\x00\x00\xff" * 2)
        solid.write_bytes(
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(solid_pixels * 2))
            + chunk(b"IEND", b"")
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "fully opaque, visually varied"
        ):
            oracle._png_dimensions(solid)

        oversized = self.temp_root / f"{self._testMethodName}-oversized.png"
        oversized_ihdr = struct.pack(">IIBBBBB", 8193, 1, 8, 6, 0, 0, 0)
        oversized.write_bytes(
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", oversized_ihdr)
            + chunk(b"IDAT", zlib.compress(b""))
            + chunk(b"IEND", b"")
        )
        with self.assertRaisesRegex(oracle.OracleValidationError, "IHDR fields"):
            oracle._png_dimensions(oversized)

        trailing_zlib = self.temp_root / f"{self._testMethodName}-trailing-zlib.png"
        diverse_pixels = (
            b"\x00"
            + b"\xff\x00\x00\xff"
            + b"\x00\x00\xff\xff"
            + b"\x00"
            + b"\x00\xff\x00\xff"
            + b"\xff\xff\xff\xff"
        )
        trailing_zlib.write_bytes(
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", ihdr)
            + chunk(
                b"IDAT", zlib.compress(diverse_pixels) + zlib.compress(b"trailing")
            )
            + chunk(b"IEND", b"")
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "invalid/trailing payload"
        ):
            oracle._png_dimensions(trailing_zlib)

        compressed_diverse = zlib.compress(diverse_pixels)
        split_at = len(compressed_diverse) // 2
        nonconsecutive_idat = (
            self.temp_root / f"{self._testMethodName}-nonconsecutive-idat.png"
        )
        nonconsecutive_idat.write_bytes(
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", compressed_diverse[:split_at])
            + chunk(b"tEXt", b"gap")
            + chunk(b"IDAT", compressed_diverse[split_at:])
            + chunk(b"IEND", b"")
        )
        with self.assertRaisesRegex(oracle.OracleValidationError, "IDAT ordering"):
            oracle._png_dimensions(nonconsecutive_idat)

        unknown_critical = self.temp_root / f"{self._testMethodName}-critical.png"
        unknown_critical.write_bytes(
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", ihdr)
            + chunk(b"ABCD", b"")
            + chunk(b"IDAT", compressed_diverse)
            + chunk(b"IEND", b"")
        )
        with self.assertRaisesRegex(
            oracle.OracleValidationError, "unknown critical chunk"
        ):
            oracle._png_dimensions(unknown_critical)

    def test_reblessed_generated_source_tampering_is_rejected_by_replay(self) -> None:
        manifest = self._validate()
        CAPTURE_TEST_ROOT.mkdir(parents=True, exist_ok=True)
        capture_id = "ReplayTamperCase"
        capture_dir = (
            CAPTURE_TEST_ROOT
            / f".{capture_id}.capture-staging-{uuid.uuid4().hex}"
        )
        self.assertFalse(capture_dir.exists())
        capture_dir.mkdir()
        self.addCleanup(lambda: shutil.rmtree(capture_dir, ignore_errors=True))

        def write_capture_checksums() -> None:
            checksum_path = capture_dir / "checksums.sha256"
            if checksum_path.exists():
                checksum_path.unlink()
            lines = []
            for path in sorted(
                (candidate for candidate in capture_dir.rglob("*") if candidate.is_file()),
                key=lambda candidate: candidate.relative_to(capture_dir).as_posix(),
            ):
                relative = path.relative_to(capture_dir).as_posix()
                lines.append(f"{oracle.sha256_file(path)}  {relative}")
            checksum_path.write_text("\n".join(lines) + "\n", encoding="ascii")

        payloads = {
            "workbook": ("oracle.xlsm", b"PK-placeholder"),
            "form_export": (
                "oracle.frm",
                f"VERSION 5.00\r\nBegin VB.UserForm {manifest['form']['name']}\r\nEnd\r\n".encode(
                    "cp1252"
                ),
            ),
            "frx_export": ("oracle.frx", b"frx"),
            "probe_results": ("probe-results.json", b"{}\n"),
            "event_log": ("event-log.json", b"{}\n"),
            "screenshot": ("oracle.png", b"\x89PNG\r\n\x1a\n"),
            "window_manifest": ("window.json", b"{}\n"),
            "generated_form_code": (
                "generated-form-code.bas",
                oracle.generate_form_code(manifest).encode("utf-8"),
            ),
            "generated_module_code": (
                "generated-module-code.bas",
                oracle.generate_module_code(manifest).encode("utf-8")
                + b"' reblessed tamper\n",
            ),
            "normalized_manifest": (
                "normalized-manifest.v1.json",
                oracle.canonical_json_bytes(manifest),
            ),
            "capture_command": ("capture-command.txt", b"test\n"),
            "capture_progress": ("capture-progress.log", b"test\n"),
            "capture_attributes": ("capture-attributes.json", b"{}\n"),
            "generator_command": ("generator-command.txt", b"test\n"),
            "generator_stdout": ("generator.stdout.log", b"test\n"),
            "generator_stderr": ("generator.stderr.log", b"test\n"),
            "window_stdout": ("window.stdout.log", b"test\n"),
            "window_stderr": ("window.stderr.log", b"test\n"),
            "macro_watchdog": (
                "macro-watchdog.log",
                b"2026-07-15T00:00:00Z ARMED operation=build_phase pid=2 timeout_seconds=180 terminal_mode=disarm\n"
                b"2026-07-15T00:00:00Z DISARMED operation=build_phase pid=2 reason=explicit_disarm\n"
                b"2026-07-15T00:00:00Z ARMED operation=build_shutdown pid=2 timeout_seconds=15 terminal_mode=expected_exit\n"
                b"2026-07-15T00:00:00Z PROCESS_EXITED operation=build_shutdown pid=2 reason=expected_exit\n"
                b"2026-07-15T00:00:00Z ARMED operation=live_phase pid=1 timeout_seconds=180 terminal_mode=disarm\n"
                b"2026-07-15T00:00:00Z ARMED operation=run_member_oracle pid=1 timeout_seconds=60 terminal_mode=disarm\n"
                b"2026-07-15T00:00:00Z DISARMED operation=run_member_oracle pid=1 reason=explicit_disarm\n"
                b"2026-07-15T00:00:00Z ARMED operation=read_harness_error pid=1 timeout_seconds=60 terminal_mode=disarm\n"
                b"2026-07-15T00:00:00Z DISARMED operation=read_harness_error pid=1 reason=explicit_disarm\n"
                b"2026-07-15T00:00:00Z ARMED operation=close_member_oracle pid=1 timeout_seconds=60 terminal_mode=disarm\n"
                b"2026-07-15T00:00:00Z DISARMED operation=close_member_oracle pid=1 reason=explicit_disarm\n"
                b"2026-07-15T00:00:00Z DISARMED operation=live_phase pid=1 reason=explicit_disarm\n"
                b"2026-07-15T00:00:00Z ARMED operation=live_shutdown pid=1 timeout_seconds=15 terminal_mode=expected_exit\n"
                b"2026-07-15T00:00:01Z PROCESS_EXITED operation=live_shutdown pid=1 reason=expected_exit\n",
            ),
            "readme": (
                "README.md",
                (oracle.COM_ADDINS_CAPTURE_WARNING + "\n").encode("utf-8"),
            ),
        }
        artifacts = {}
        for role, (name, content) in payloads.items():
            path = capture_dir / name
            path.write_bytes(content)
            artifacts[role] = {"path": name, "sha256": oracle.sha256_file(path)}

        tool_sources = {
            "generator_validator": REPO_ROOT / "tools/office-oracle/msforms_member_oracle.py",
            "capture_runner": REPO_ROOT / "tools/office-oracle/Capture-MSFormsMemberOracle.ps1",
            "window_capture": REPO_ROOT / "tools/office-oracle/Capture-Window.ps1",
            "frm_inventory": REPO_ROOT / "tools/forms-persistence/frm_text_inventory.py",
            "cfb_inventory": REPO_ROOT / "tools/forms-persistence/cfb_inventory.py",
        }
        tool_refs = {}
        snapshot_dir = capture_dir / "tool-snapshots"
        snapshot_dir.mkdir()
        for role, source in tool_sources.items():
            snapshot = snapshot_dir / source.name
            snapshot.write_bytes(source.read_bytes())
            tool_refs[role] = {
                "source_path": source.relative_to(REPO_ROOT).as_posix(),
                "snapshot_path": snapshot.relative_to(capture_dir).as_posix(),
                "sha256": oracle.sha256_file(snapshot),
            }

        excel_path = r"C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE"

        def make_isolation_check(
            checkpoint: str,
            disposition: str,
            workbooks: list[dict[str, object]],
        ) -> dict[str, object]:
            return {
                "checkpoint": checkpoint,
                "window_observation": {
                    "enumeration_succeeded": True,
                    "enumeration_truncated": False,
                    "enumeration_limit": 512,
                    "enumeration_error_code": 0,
                    "owned_window_count": 8,
                    "top_level_windows": [
                        {
                            "hwnd": 1001,
                            "class_name": "XLMAIN",
                            "title": "Microsoft Excel - Safe Mode",
                            "visible": True,
                            "enabled": True,
                        }
                    ],
                },
                "workbook_disposition": disposition,
                "workbook_count": len(workbooks),
                "workbooks": workbooks,
                "startup_path": r"C:\Users\oracle\AppData\Roaming\Microsoft\Excel\XLSTART",
                "alt_startup_path": "",
                "protected_view_window_count": 0,
                "com_addins_access": {
                    "status": "unavailable_exact_excel_error_nonclaim",
                    "error_number": -2146827284,
                    "error_hex": "0x800A03EC",
                    "inventory_complete": False,
                    "connection_state_claim": "not_made",
                },
                "com_addins": [],
                "excel_addins": [],
                "excel_addins2": [],
                "loaded_xll_modules": [],
            }

        def make_excel_identity(role: str, process_id: int) -> dict[str, object]:
            middle = (
                make_isolation_check(
                    "pre_vbide_automation",
                    "expected_pathless_harness",
                    [{"path": "", "full_name": "Book1", "is_addin": False}],
                )
                if role == "build"
                else make_isolation_check(
                    "pre_macro_execution",
                    "exact_hash_pinned_harness",
                    [
                        {
                            "path": r"C:\capture",
                            "full_name": r"C:\capture\member-oracle.xlsm",
                            "is_addin": False,
                        }
                    ],
                )
            )
            return {
                "path": excel_path,
                "file_version": "test",
                "product_version": "test",
                "product_name": "Microsoft Office",
                "company_name": "Microsoft Corporation",
                "sha256": "1" * 64,
                "process_id": process_id,
                "process_start_utc": "2026-07-15T00:00:00Z",
                "bitness": "x64",
                "startup_mode": "safe",
                "launch_arguments": ["/safe"],
                "containment_method": (
                    "create_process_suspended_then_job_object_kill_on_close"
                ),
                "containment_membership_verified": True,
                "process_exclusivity_observation": {
                    "caller_snapshot_process_ids": [],
                    "pre_create_process_ids": [],
                    "post_create_process_ids": [process_id],
                },
                "command_line_observation_method": (
                    "cim_win32_process_command_line_to_argv_w"
                ),
                "observed_command_line": f'"{excel_path}" /safe',
                "observed_launch_argv": [excel_path, "/safe"],
                "binding_method": (
                    "oleacc_accessible_object_from_window_excel7_objid_nativeom"
                ),
                "binding_hwnd": process_id + 100,
                "owned_window_count_at_binding": 8,
                "startup_workbook_observation": {
                    "initial_workbook_count": 1,
                    "initial_workbooks": [
                        {"path": "", "full_name": "Book1", "is_addin": False}
                    ],
                    "post_close_workbook_count": 0,
                },
                "isolation_checks": [
                    make_isolation_check("post_startup_close", "none", []),
                    middle,
                    make_isolation_check("pre_shutdown", "none", []),
                ],
            }

        capture_manifest = {
            "schema": oracle.CAPTURE_SCHEMA,
            "schema_version": 1,
            "bead": manifest["bead"],
            "capture_id": capture_id,
            "status": "captured",
            "started_at_utc": "2026-07-15T00:00:00Z",
            "completed_at_utc": "2026-07-15T00:00:01Z",
            "probe_manifest": {
                "id": manifest["id"],
                "path": self.manifest_path.relative_to(REPO_ROOT).as_posix(),
                "sha256": oracle.sha256_file(self.manifest_path),
                "ledger_canonical_sha256": manifest["ledger"]["canonical_sha256"],
            },
            "tools": tool_refs,
            "preopen_workbook_sha256": "0" * 64,
            "platform": {
                "os": "test",
                "is_windows": True,
                "powershell": "test",
                "python": "test",
                "process_architecture": "x64",
                "culture": "en-US",
                "ui_culture": "en-US",
                "ansi_code_page": 1252,
                "oem_code_page": 437,
                "office_ui_lcid": 1033,
            },
            "excel": make_excel_identity("live", 1),
            "build_excel": make_excel_identity("build", 2),
            "vbe": {
                "path": r"C:\Program Files\Common Files\Microsoft Shared\VBA\VBA7.1\VBE7.DLL",
                "file_version": "test",
                "product_version": "test",
                "sha256": "2" * 64,
            },
            "fm20": {
                "path": r"C:\Windows\System32\FM20.DLL",
                "file_version": "test",
                "product_version": "test",
                "sha256": "3" * 64,
            },
            "artifacts": artifacts,
            "observed_coverage": {
                "control_families": sorted(
                    {control["fm20_type"] for control in manifest["form"]["controls"]}
                ),
                "probe_count": 0,
                "success_count": 0,
                "error_count": 0,
                "event_row_count": 0,
                "screenshot_count": 1,
                "export_pair_count": 1,
            },
            "provenance": manifest["provenance"],
            "warnings": [
                "synthetic replay test",
                oracle.COM_ADDINS_CAPTURE_WARNING,
            ],
            "non_claims": manifest["non_claims"],
        }
        (capture_dir / "oracle-capture-manifest.json").write_bytes(
            oracle.canonical_json_bytes(capture_manifest)
        )
        frozen_manifest_path = capture_dir / "input-snapshots" / "probe-manifest.json"
        frozen_manifest_path.parent.mkdir()
        frozen_manifest_path.write_bytes(self.manifest_path.read_bytes())
        alternate_manifest_path = capture_dir / "alternate-probe-manifest.json"
        alternate_manifest_path.write_bytes(self.manifest_path.read_bytes())

        original_inventory_digest = capture_manifest["tools"]["frm_inventory"][
            "sha256"
        ]
        capture_manifest["tools"]["frm_inventory"]["sha256"] = "0" * 64
        (capture_dir / "oracle-capture-manifest.json").write_bytes(
            oracle.canonical_json_bytes(capture_manifest)
        )
        write_capture_checksums()
        with self.assertRaises(oracle.OracleValidationError) as caught:
            with self._cached_ledger():
                oracle.validate_capture(capture_dir, self.manifest_path, REPO_ROOT)
        self.assertIn("manifest-pinned replay validator digest", str(caught.exception))

        capture_manifest["tools"]["frm_inventory"][
            "sha256"
        ] = original_inventory_digest

        def assert_capture_manifest_mutation_rejected(
            label: str,
            mutate,
            expected_fragment: str,
        ) -> None:
            adversarial = copy.deepcopy(capture_manifest)
            mutate(adversarial)
            (capture_dir / "oracle-capture-manifest.json").write_bytes(
                oracle.canonical_json_bytes(adversarial)
            )
            write_capture_checksums()
            with self.subTest(adversarial_capture=label):
                with self.assertRaises(oracle.OracleValidationError) as caught:
                    with self._cached_ledger():
                        oracle.validate_capture(
                            capture_dir, self.manifest_path, REPO_ROOT
                        )
                self.assertIn(expected_fragment, str(caught.exception))

        assert_capture_manifest_mutation_rejected(
            "wrong containment method",
            lambda candidate: candidate["excel"].__setitem__(
                "containment_method", "process_start_then_assign_job"
            ),
            "must use suspended creation",
        )
        assert_capture_manifest_mutation_rejected(
            "false containment membership",
            lambda candidate: candidate["excel"].__setitem__(
                "containment_membership_verified", False
            ),
            "must affirm exact Job membership before resume",
        )
        assert_capture_manifest_mutation_rejected(
            "extra post-create Excel process",
            lambda candidate: candidate["excel"][
                "process_exclusivity_observation"
            ].__setitem__("post_create_process_ids", [1, 99]),
            "must contain only the exact retained Excel process id",
        )
        assert_capture_manifest_mutation_rejected(
            "empty top-level window inventory",
            lambda candidate: candidate["excel"]["isolation_checks"][0][
                "window_observation"
            ].__setitem__("top_level_windows", []),
            "must be nonempty and contain an enabled XLMAIN root",
        )
        assert_capture_manifest_mutation_rejected(
            "non-Excel top-level window inventory",
            lambda candidate: candidate["excel"]["isolation_checks"][0][
                "window_observation"
            ]["top_level_windows"][0].__setitem__("class_name", "MSOSPLASH"),
            "must contain at least one enabled XLMAIN root",
        )

        def hide_and_disable_excel_root(candidate: dict) -> None:
            excel_root = candidate["excel"]["isolation_checks"][0][
                "window_observation"
            ]["top_level_windows"][0]
            excel_root["visible"] = False
            excel_root["enabled"] = False

        assert_capture_manifest_mutation_rejected(
            "hidden disabled Excel root",
            hide_and_disable_excel_root,
            "disabled Excel root consistent with a modal",
        )

        def replace_com_access(candidate: dict, **changes: object) -> None:
            candidate["excel"]["isolation_checks"][0]["com_addins_access"].update(
                changes
            )

        assert_capture_manifest_mutation_rejected(
            "wrong self-consistent COM HRESULT",
            lambda candidate: replace_com_access(
                candidate,
                error_number=-1,
                error_hex="0xFFFFFFFF",
            ),
            "must preserve exact 0x800A03EC",
        )
        assert_capture_manifest_mutation_rejected(
            "false complete COM inventory",
            lambda candidate: replace_com_access(
                candidate,
                inventory_complete=True,
            ),
            "make no connection-state claim",
        )
        assert_capture_manifest_mutation_rejected(
            "COM connection-state claim despite unavailable inventory",
            lambda candidate: replace_com_access(
                candidate,
                connection_state_claim="complete",
            ),
            "make no connection-state claim",
        )
        assert_capture_manifest_mutation_rejected(
            "COM inventory despite explicit incomplete nonclaim",
            lambda candidate: candidate["excel"]["isolation_checks"][0].__setitem__(
                "com_addins",
                [
                    {
                        "prog_id": "Synthetic.Addin",
                        "description": "synthetic adversarial add-in",
                        "connected": False,
                    }
                ],
            ),
            "must be empty when COMAddIns inventory is explicitly incomplete",
        )
        assert_capture_manifest_mutation_rejected(
            "missing incomplete COMAddIns capture warning",
            lambda candidate: candidate["warnings"].remove(
                oracle.COM_ADDINS_CAPTURE_WARNING
            ),
            "must disclose incomplete COMAddIns authority exactly",
        )

        readme_path = capture_dir / artifacts["readme"]["path"]
        original_readme = readme_path.read_bytes()
        readme_path.write_text("synthetic replay test\n", encoding="utf-8")
        readme_adversarial = copy.deepcopy(capture_manifest)
        readme_adversarial["artifacts"]["readme"]["sha256"] = oracle.sha256_file(
            readme_path
        )
        (capture_dir / "oracle-capture-manifest.json").write_bytes(
            oracle.canonical_json_bytes(readme_adversarial)
        )
        write_capture_checksums()
        with self.assertRaises(oracle.OracleValidationError) as caught:
            with self._cached_ledger():
                oracle.validate_capture(capture_dir, self.manifest_path, REPO_ROOT)
        self.assertIn(
            "must disclose the exact incomplete COMAddIns connection-state nonclaim",
            str(caught.exception),
        )
        readme_path.write_bytes(original_readme)

        def make_complete_com_addins(candidate: dict, *, connected: bool) -> None:
            for role in ("build_excel", "excel"):
                for check in candidate[role]["isolation_checks"]:
                    check["com_addins_access"] = {
                        "status": "available",
                        "error_number": 0,
                        "error_hex": "0x00000000",
                        "inventory_complete": True,
                        "connection_state_claim": "complete",
                    }
                    check["com_addins"] = [
                        {
                            "prog_id": "Synthetic.Addin",
                            "description": "synthetic available inventory",
                            "connected": connected,
                        }
                    ]
            candidate["warnings"].remove(oracle.COM_ADDINS_CAPTURE_WARNING)

        assert_capture_manifest_mutation_rejected(
            "connected COM add-in in complete inventory",
            lambda candidate: make_complete_com_addins(candidate, connected=True),
            "must not have a connected COM add-in",
        )

        complete_access = copy.deepcopy(capture_manifest)
        make_complete_com_addins(complete_access, connected=False)
        complete_readme = (
            "Application.COMAddIns was completely inventoried at every isolation "
            "checkpoint and every observed Connect value was false.\n"
        ).encode("utf-8")
        readme_path.write_bytes(complete_readme)
        complete_access["artifacts"]["readme"]["sha256"] = oracle.sha256_file(
            readme_path
        )
        (capture_dir / "oracle-capture-manifest.json").write_bytes(
            oracle.canonical_json_bytes(complete_access)
        )
        write_capture_checksums()
        with self.assertRaises(oracle.OracleValidationError) as caught:
            with self._cached_ledger():
                oracle.validate_capture(capture_dir, self.manifest_path, REPO_ROOT)
        self.assertIn("deterministic regeneration", str(caught.exception))
        readme_path.write_bytes(original_readme)

        (capture_dir / "oracle-capture-manifest.json").write_bytes(
            oracle.canonical_json_bytes(capture_manifest)
        )
        write_capture_checksums()

        with self.assertRaises(oracle.OracleValidationError) as caught:
            with self._cached_ledger():
                oracle.validate_capture(
                    capture_dir, alternate_manifest_path, REPO_ROOT
                )
        self.assertIn("exact capture-local frozen snapshot", str(caught.exception))

        with self.assertRaises(oracle.OracleValidationError) as caught:
            with self._cached_ledger():
                oracle.validate_capture(capture_dir, frozen_manifest_path, REPO_ROOT)
        self.assertIn("deterministic regeneration", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
