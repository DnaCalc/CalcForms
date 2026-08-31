#!/usr/bin/env python3
"""Generate and validate manifest-driven live Excel/MSForms member probes.

The generator emits repo-owned VBA used only by the black-box Office oracle.
It deliberately does not import, execute, or compare OxForms output.  The
capture validator replays declarative expectations against preserved worksheet
rows and verifies every linked artifact and checksum.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import ntpath
import os
import re
import stat
import struct
import sys
import types
import zlib
import zipfile
from datetime import datetime, timedelta
from pathlib import Path, PurePosixPath
from typing import Any, Iterable
from xml.etree import ElementTree


if sys.version_info < (3, 12):
    raise RuntimeError(
        "The MSForms member-oracle path-safety contract requires Python 3.12 or newer."
    )


MANIFEST_SCHEMA = "oxforms.office_oracle.msforms_member_probe_manifest.v1"
RESULT_SCHEMA = "oxforms.office_oracle.msforms_member_probe_results.v1"
EVENT_SCHEMA = "oxforms.office_oracle.msforms_member_event_log.v1"
CAPTURE_SCHEMA = "oxforms.office_oracle.msforms_member_capture.v1"
LEDGER_SNAPSHOT_SCHEMA = "oxforms.office_oracle.msforms_ledger_slice.v1"
SCHEMA_VERSION = 1
RESULT_HEADERS = (
    "sequence",
    "probe_id",
    "ledger_row_id",
    "target_id",
    "operation",
    "member",
    "outcome",
    "value_text",
    "type_name",
    "var_type",
    "is_object",
    "is_array",
    "error_number",
    "error_last_dll_error",
    "error_hex",
    "error_description",
    "error_description_utf16_hex",
    "error_source",
    "error_help_file",
    "error_help_context",
    "error_line",
    "error_stage",
)
EVENT_HEADERS = (
    "sequence",
    "event_id",
    "ledger_row_id",
    "target_id",
    "target_kind",
    "event_name",
    "arguments_before",
    "arguments_after",
    "trigger_step_id",
)
OBSERVATION_SOURCE = "live_excel_msforms_black_box"
CANONICAL_LEDGER = (
    "docs/evidence/W010_complete_msforms_object_model_parity/beads/"
    "oxforms-jbjp.4/msforms_parity_ledger.v1.json"
)
REPLAY_VALIDATOR_SOURCES = {
    "frm_inventory": "tools/forms-persistence/frm_text_inventory.py",
    "cfb_inventory": "tools/forms-persistence/cfb_inventory.py",
}
ENGLISH_OFFICE_REQUIREMENT = (
    "Microsoft Office and VBA UI language LCID 1033 (English - United States), "
    "so worksheet-safe display and raw UTF-16 Err.Description expectations are stable."
)
VBE_ERROR_TRAPPING_REQUIREMENT = (
    "VBE Tools > Options > General > Error Trapping is manually set to Break on "
    "Unhandled Errors; the runner does not mutate this user-wide setting."
)
COM_ADDINS_NONCLAIM = (
    "When safe-mode Excel returns exact error 0x800A03EC for Application.COMAddIns, "
    "the capture records an incomplete inventory and makes no COM-add-in "
    "connection-state claim."
)
COM_ADDINS_CAPTURE_WARNING = (
    "Application.COMAddIns returned exact 0x800A03EC at one or more safe-mode "
    "isolation checkpoints; its inventory is incomplete and this capture makes no "
    "COM-add-in connection-state claim."
)
CONTENT_TYPES_NS = "http://schemas.openxmlformats.org/package/2006/content-types"
PACKAGE_REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
OFFICE_REL_NS = (
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
)
SPREADSHEET_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
WORKSHEET_CONTENT_TYPE = (
    "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"
)
SHARED_STRINGS_CONTENT_TYPE = (
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"
)
RUNTIME_MODULE_NAME = "W010MemberOracleRuntime"
IDENTIFIER_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]{0,39}$")
MEMBER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]{0,79}$")
W010_BEAD_RE = re.compile(r"^oxforms-jbjp\.[1-9][0-9]*$")
PROGID_RE = re.compile(r"^Forms\.(?:[A-Za-z][A-Za-z0-9]*|HTML:[A-Za-z][A-Za-z0-9]*)\.1$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
UTF16_CODE_UNIT_HEX_RE = re.compile(r"^[0-9A-F]{4}(?: [0-9A-F]{4})*$")
ALLOWED_SCALAR_KINDS = {"string", "integer", "single", "boolean", "empty"}
SCALAR_RESULT_SHAPES = {
    "string": {("String", 8)},
    "integer": {
        ("Byte", 17),
        ("Integer", 2),
        ("Long", 3),
        ("LongLong", 20),
    },
    "single": {("Single", 4), ("Double", 5), ("Decimal", 14)},
    "boolean": {("Boolean", 11)},
    "empty": {("Empty", 0)},
}
ALLOWED_OPERATIONS = {
    "property_get",
    "property_set",
    "property_roundtrip",
    "default_get",
    "method",
}
ALLOWED_EVENT_TYPES = {
    "Boolean",
    "Integer",
    "Long",
    "Single",
    "String",
    "MSForms.ReturnBoolean",
    "MSForms.ReturnEffect",
    "MSForms.ReturnInteger",
    "MSForms.ReturnSingle",
    "MSForms.ReturnString",
    "MSForms.DataObject",
    "MSForms.Control",
    "MSForms.fmAction",
    "MSForms.fmDragState",
    "MSForms.fmScrollAction",
}
PROGID_TO_FM20_TYPE = {
    "Forms.CommandButton.1": "CommandButton",
    "Forms.TextBox.1": "TextBox",
    "Forms.ListBox.1": "ListBox",
    "Forms.ComboBox.1": "ComboBox",
    "Forms.CheckBox.1": "CheckBox",
    "Forms.OptionButton.1": "OptionButton",
    "Forms.ToggleButton.1": "ToggleButton",
    "Forms.Frame.1": "Frame",
    "Forms.Label.1": "Label",
    "Forms.Image.1": "Image",
    "Forms.SpinButton.1": "SpinButton",
    "Forms.ScrollBar.1": "ScrollBar",
    "Forms.TabStrip.1": "TabStrip",
    "Forms.MultiPage.1": "MultiPage",
    "Forms.HTML:Submit.1": "HTMLSubmit",
    "Forms.HTML:Image.1": "HTMLImage",
    "Forms.HTML:Reset.1": "HTMLReset",
    "Forms.HTML:Checkbox.1": "HTMLCheckbox",
    "Forms.HTML:Option.1": "HTMLOption",
    "Forms.HTML:Text.1": "HTMLText",
    "Forms.HTML:Hidden.1": "HTMLHidden",
    "Forms.HTML:Password.1": "HTMLPassword",
    "Forms.HTML:Select.1": "HTMLSelect",
    "Forms.HTML:TextArea.1": "HTMLTextArea",
}


class OracleValidationError(ValueError):
    """Raised when a manifest or capture fails closed validation."""


def _reject_constant(value: str) -> None:
    raise OracleValidationError(f"Non-finite JSON number is forbidden: {value}")


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise OracleValidationError(f"Duplicate JSON key is forbidden: {key}")
        result[key] = value
    return result


def load_json_bytes(raw: bytes, location: str | Path) -> Any:
    """Parse one retained byte snapshot as strict JSON."""
    if raw.startswith(b"\xef\xbb\xbf"):
        raise OracleValidationError(f"UTF-8 BOM is forbidden: {location}")
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise OracleValidationError(f"JSON must be UTF-8: {location}: {exc}") from exc
    try:
        return json.loads(
            text,
            object_pairs_hook=_unique_object,
            parse_constant=_reject_constant,
        )
    except (json.JSONDecodeError, OracleValidationError) as exc:
        raise OracleValidationError(f"Invalid JSON {location}: {exc}") from exc


def load_json(path: Path) -> Any:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise OracleValidationError(f"Cannot read JSON file {path}: {exc}") from exc
    return load_json_bytes(raw, path)


def canonical_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _read_bound_file(
    path: Path,
    location: str,
    *,
    expected_sha256: str | None = None,
    max_bytes: int,
) -> bytes:
    """Read once from one regular-file handle and bind the retained bytes.

    Parsing callers consume the returned bytes rather than reopening ``path``.
    The open-handle and post-read path identities must still agree, so a regular
    file replaced while it is being captured cannot be silently accepted.
    """
    if max_bytes < 0:
        raise AssertionError("max_bytes must be nonnegative")
    if expected_sha256 is not None and SHA256_RE.fullmatch(expected_sha256) is None:
        raise AssertionError("expected_sha256 must be lowercase SHA-256")
    try:
        with path.open("rb") as stream:
            before = os.fstat(stream.fileno())
            if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
                _fail(location, "must be a real non-hard-linked file")
            raw = stream.read(max_bytes + 1)
            after = os.fstat(stream.fileno())
        current = path.stat()
    except OSError as exc:
        _fail(location, f"cannot read a stable regular file: {exc}")
    if len(raw) > max_bytes:
        _fail(location, f"exceeds the {max_bytes}-byte evidence cap")

    def identity(value: os.stat_result) -> tuple[int, int, int, int, int]:
        return (
            value.st_dev,
            value.st_ino,
            value.st_size,
            value.st_nlink,
            value.st_mtime_ns,
        )

    if identity(before) != identity(after) or identity(after) != identity(current):
        _fail(location, "file identity/metadata changed while exact bytes were retained")
    if len(raw) != before.st_size:
        _fail(location, "file size changed while exact bytes were retained")
    if expected_sha256 is not None:
        actual_sha256 = sha256_bytes(raw)
        if actual_sha256 != expected_sha256:
            _fail(
                location,
                f"checksum mismatch: expected {expected_sha256}, actual {actual_sha256}",
            )
    return raw


def _load_python_module_bytes(
    source: bytes, path: Path, module_name: str
) -> Any:
    """Execute exact source bytes without import caches or a second file read."""
    module = types.ModuleType(module_name)
    module.__file__ = str(path)
    module.__package__ = ""
    sys.modules[module_name] = module
    try:
        code = compile(source, str(path), "exec")
        exec(code, module.__dict__)
    except Exception:
        sys.modules.pop(module_name, None)
        raise
    return module


def _load_python_module(path: Path, module_name: str) -> Any:
    try:
        source = path.read_bytes()
    except OSError as exc:
        raise OracleValidationError(f"Cannot read validation module {path}: {exc}") from exc
    return _load_python_module_bytes(source, path, module_name)


def _fail(path: str, message: str) -> None:
    raise OracleValidationError(f"{path}: {message}")


def _expect_dict(value: Any, path: str) -> dict[str, Any]:
    if type(value) is not dict:
        _fail(path, "must be an object")
    return value


def _expect_list(value: Any, path: str) -> list[Any]:
    if type(value) is not list:
        _fail(path, "must be an array")
    return value


def _expect_string(value: Any, path: str, *, nonempty: bool = True) -> str:
    if type(value) is not str:
        _fail(path, "must be a string")
    if nonempty and not value.strip():
        _fail(path, "must be nonempty")
    if "\x00" in value:
        _fail(path, "must not contain NUL")
    return value


def _expect_int(value: Any, path: str, *, minimum: int | None = None) -> int:
    if type(value) is not int:
        _fail(path, "must be an integer (booleans are not integers)")
    if minimum is not None and value < minimum:
        _fail(path, f"must be >= {minimum}")
    return value


def _expect_foreground_attempt(value: Any, path: str) -> int:
    attempt = _expect_int(value, path, minimum=1)
    if attempt > 4:
        _fail(path, "must be <= 4")
    return attempt


def _expect_bool(value: Any, path: str) -> bool:
    if type(value) is not bool:
        _fail(path, "must be a boolean")
    return value


def _parse_windows_command_line(command_line: str, path: str) -> list[str]:
    """Independently parse the Windows argv quoting used by CreateProcess."""
    if "\x00" in command_line:
        _fail(path, "must not contain NUL")
    arguments: list[str] = []
    index = 0
    length = len(command_line)
    while True:
        while index < length and command_line[index] in " \t":
            index += 1
        if index >= length:
            break
        value: list[str] = []
        in_quotes = False
        while index < length:
            if command_line[index] in " \t" and not in_quotes:
                break
            if command_line[index] == "\\":
                slash_start = index
                while index < length and command_line[index] == "\\":
                    index += 1
                slash_count = index - slash_start
                if index < length and command_line[index] == '"':
                    value.extend("\\" * (slash_count // 2))
                    if slash_count % 2:
                        value.append('"')
                    else:
                        in_quotes = not in_quotes
                    index += 1
                else:
                    value.extend("\\" * slash_count)
                continue
            if command_line[index] == '"':
                in_quotes = not in_quotes
                index += 1
                continue
            value.append(command_line[index])
            index += 1
        if in_quotes:
            _fail(path, "contains an unterminated quote")
        arguments.append("".join(value))
    return arguments


def _expect_utc_timestamp(value: Any, path: str) -> datetime:
    text = _expect_string(value, path)
    normalized = text[:-1] + "+00:00" if text.endswith("Z") else text
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        _fail(path, "must be an ISO-8601 timestamp")
        raise AssertionError from exc
    if parsed.tzinfo is None or parsed.utcoffset() != timedelta(0):
        _fail(path, "must carry an explicit UTC offset")
    return parsed


def _expect_exact_keys(
    value: dict[str, Any],
    path: str,
    required: Iterable[str],
    optional: Iterable[str] = (),
) -> None:
    required_set = set(required)
    optional_set = set(optional)
    missing = sorted(required_set - set(value))
    unknown = sorted(set(value) - required_set - optional_set)
    if missing:
        _fail(path, f"missing keys: {', '.join(missing)}")
    if unknown:
        _fail(path, f"unknown keys: {', '.join(unknown)}")


def _expect_identifier(value: Any, path: str) -> str:
    result = _expect_string(value, path)
    if not IDENTIFIER_RE.fullmatch(result):
        _fail(path, "must be a safe VBA identifier (1-40 ASCII alphanumerics/underscore)")
    return result


def _expect_member_identifier(value: Any, path: str) -> str:
    result = _expect_string(value, path)
    if not MEMBER_RE.fullmatch(result):
        _fail(path, "must be a safe VBA member identifier")
    return result


def _expect_w010_bead(value: Any, path: str) -> str:
    result = _expect_string(value, path)
    if not W010_BEAD_RE.fullmatch(result):
        _fail(path, "must be a numbered W010 bead id such as 'oxforms-jbjp.15'")
    return result


def _resolve_repo_path(repo_root: Path, relative: Any, path: str) -> Path:
    text = _expect_string(relative, path)
    root = Path(os.path.abspath(repo_root))
    candidate = Path(os.path.abspath(root / text.replace("/", os.sep)))
    try:
        common = os.path.commonpath([str(root), str(candidate)])
    except ValueError:
        _fail(path, "must resolve inside the repository")
    if os.path.normcase(common) != os.path.normcase(str(root)):
        _fail(path, "must resolve inside the repository")
    current = candidate
    chain: list[Path] = []
    while True:
        chain.append(current)
        if current == root or current.parent == current:
            break
        current = current.parent
    for component in reversed(chain):
        if component.exists() and (component.is_symlink() or component.is_junction()):
            _fail(path, f"reparse/symbolic paths are forbidden: {component}")
    candidate = candidate.resolve()
    root = root.resolve()
    try:
        candidate.relative_to(root)
    except ValueError:
        _fail(path, "must resolve inside the repository")
    if not candidate.is_file():
        _fail(path, f"file does not exist: {text}")
    if candidate.stat().st_nlink != 1:
        _fail(path, "hard-linked authority inputs are forbidden")
    return candidate


def validate_scalar(value: Any, path: str) -> dict[str, Any]:
    obj = _expect_dict(value, path)
    kind = _expect_string(obj.get("kind"), f"{path}.kind")
    if kind not in ALLOWED_SCALAR_KINDS:
        _fail(f"{path}.kind", f"unsupported scalar kind: {kind}")
    if kind == "empty":
        _expect_exact_keys(obj, path, ["kind"])
        return obj
    if kind == "single":
        _expect_exact_keys(obj, path, ["kind", "value", "expected_text"])
    else:
        _expect_exact_keys(obj, path, ["kind", "value"])
    scalar = obj["value"]
    if kind == "string":
        text = _expect_string(scalar, f"{path}.value", nonempty=False)
        if re.search(r"[\x00-\x1f\x7f\u2028\u2029]", text):
            _fail(
                f"{path}.value",
                "control/multiline VBA literals are not supported in schema v1",
            )
        escaped = text.replace('"', '""')
        try:
            escaped_length = len(escaped.encode("utf-8", "strict"))
        except UnicodeEncodeError:
            _fail(f"{path}.value", "must be valid Unicode without lone surrogates")
        if len(text) > 255 or escaped_length > 512:
            _fail(
                f"{path}.value",
                "string is too long for a bounded schema-v1 VBA physical line",
            )
    elif kind == "integer":
        number = _expect_int(scalar, f"{path}.value")
        if number < -2147483648 or number > 2147483647:
            _fail(f"{path}.value", "must fit a signed VBA Long")
    elif kind == "single":
        if type(scalar) not in (int, float) or type(scalar) is bool:
            _fail(f"{path}.value", "must be a finite number")
        try:
            numeric = float(scalar)
            if not math.isfinite(numeric):
                _fail(f"{path}.value", "must be finite")
            quantized = struct.unpack("<f", struct.pack("<f", numeric))[0]
        except (OverflowError, struct.error):
            _fail(f"{path}.value", "must fit a finite IEEE-754/VBA Single")
        if not math.isfinite(quantized) or (numeric != 0 and quantized == 0):
            _fail(f"{path}.value", "must fit a finite IEEE-754/VBA Single")
        expected_text = _expect_string(
            obj["expected_text"], f"{path}.expected_text", nonempty=False
        )
        if len(expected_text) > 64 or "\r" in expected_text or "\n" in expected_text:
            _fail(f"{path}.expected_text", "must be a bounded single-line observation")
    elif kind == "boolean":
        _expect_bool(scalar, f"{path}.value")
    return obj


def validate_argument(value: Any, path: str) -> dict[str, Any]:
    obj = _expect_dict(value, path)
    if obj.get("kind") == "missing":
        _expect_exact_keys(obj, path, ["kind"])
        return obj
    return validate_scalar(obj, path)


def scalar_expected_text(value: dict[str, Any]) -> str:
    kind = value["kind"]
    if kind == "empty":
        return ""
    scalar = value["value"]
    if kind == "boolean":
        return "True" if scalar else "False"
    if kind == "single":
        return value["expected_text"]
    return str(scalar)


def scalar_vba_literal(value: dict[str, Any]) -> str:
    kind = value["kind"]
    if kind == "empty":
        return "Empty"
    scalar = value["value"]
    if kind == "string":
        return '"' + scalar.replace('"', '""') + '"'
    if kind == "integer":
        return str(scalar)
    if kind == "single":
        quantized = struct.unpack("<f", struct.pack("<f", float(scalar)))[0]
        return format(quantized, ".9g") + "!"
    if kind == "boolean":
        return "True" if scalar else "False"
    raise AssertionError(kind)


def vba_long_literal(value: int) -> str:
    """Render an already-validated signed VBA Long without decimal overflow."""

    if value < 0:
        return f"&H{value & 0xFFFFFFFF:08X}"
    return f"{value}&"


def utf16_code_unit_hex(value: str) -> str:
    """Return exact UTF-16 code units without a BOM, using uppercase hex."""

    compact = value.encode("utf-16-be", errors="surrogatepass").hex().upper()
    return " ".join(
        compact[index : index + 4] for index in range(0, len(compact), 4)
    )


def validate_error_description_encoding(
    visible: Any,
    raw_hex: Any,
    path: str,
    *,
    visible_field: str = "description_equals",
    raw_field: str = "description_utf16_hex_equals",
) -> tuple[str, str]:
    """Validate the worksheet-safe text and its exact raw UTF-16 representation.

    Excel worksheet cells cannot be trusted to retain U+0000.  The VBA harness
    therefore removes one final U+0000 from the human-readable column, when
    present, and records every original UTF-16 code unit in a separate exact
    hex column.  Embedded U+0000 is outside the safe v1 worksheet vocabulary.
    """

    visible_text = _expect_string(visible, f"{path}.{visible_field}")
    raw_hex_text = _expect_string(raw_hex, f"{path}.{raw_field}")
    if not UTF16_CODE_UNIT_HEX_RE.fullmatch(raw_hex_text):
        _fail(
            f"{path}.{raw_field}",
            "must be canonical uppercase four-digit UTF-16 code units separated by one space",
        )
    raw_units = raw_hex_text.split(" ")
    visible_units = raw_units[:-1] if raw_units[-1] == "0000" else raw_units
    if "0000" in visible_units:
        _fail(
            f"{path}.{raw_field}",
            "v1 permits at most one U+0000 and only as the final raw code unit",
        )
    visible_hex = " ".join(visible_units)
    if visible_hex != utf16_code_unit_hex(visible_text):
        _fail(
            path,
            f"{visible_field} must equal {raw_field} with one final U+0000 removed when present",
        )
    return visible_text, raw_hex_text


def argument_vba_text(args: list[dict[str, Any]]) -> str:
    """Render positional args, preserving omitted middle and trailing slots."""
    rendered: list[str] = []
    for arg in args:
        rendered.append("" if arg["kind"] == "missing" else scalar_vba_literal(arg))
    while rendered and rendered[-1] == "":
        rendered.pop()
    return ", ".join(rendered)


def _vba_string(value: str) -> str:
    if "\r" in value or "\n" in value or "\x00" in value:
        raise OracleValidationError("Unsafe multiline/NUL VBA string")
    return '"' + value.replace('"', '""') + '"'


def _ledger_maps(ledger: dict[str, Any]) -> tuple[dict[str, Any], dict[str, str]]:
    rows = _expect_list(ledger.get("rows"), "ledger.rows")
    by_id: dict[str, Any] = {}
    type_names: dict[str, str] = {}
    for index, row_value in enumerate(rows):
        row = _expect_dict(row_value, f"ledger.rows[{index}]")
        row_id = _expect_string(row.get("row_id"), f"ledger.rows[{index}].row_id")
        if row_id in by_id:
            _fail("ledger.rows", f"duplicate row_id: {row_id}")
        by_id[row_id] = row
        if row.get("row_kind") == "type_contract" and type(row.get("facade_owner_type_id")) is str:
            type_names[row["facade_owner_type_id"]] = _expect_string(
                row.get("exact_name"), f"ledger.rows[{index}].exact_name"
            )
    return by_id, type_names


def _validate_ledger_link(
    *,
    row_id: Any,
    member: str,
    fm20_type: str,
    allowed_kinds: set[str],
    rows: dict[str, Any],
    type_names: dict[str, str],
    path: str,
) -> str:
    link = _expect_string(row_id, path)
    row = rows.get(link)
    if row is None:
        _fail(path, "does not identify a row in the pinned parity ledger")
    if row.get("row_kind") not in allowed_kinds:
        _fail(path, f"row kind {row.get('row_kind')!r} is not valid here")
    if row.get("exact_name") != member:
        _fail(path, f"ledger row exact_name {row.get('exact_name')!r} != {member!r}")
    owner = type_names.get(row.get("facade_owner_type_id"), row.get("facade_owner_type_id"))
    if owner != fm20_type:
        _fail(path, f"ledger facade owner {owner!r} != target type {fm20_type!r}")
    if row.get("disposition") not in {
        "accepted_callable",
        "accepted_event",
        "accepted_host_event_attachment",
    }:
        _fail(path, f"ledger row disposition is not accepted: {row.get('disposition')!r}")
    return link


def _validate_probe_accessor(step: dict[str, Any], row: dict[str, Any], path: str) -> None:
    accessors = _expect_dict(row.get("contract", {}).get("accessors"), f"{path}.contract.accessors")
    operation = step["operation"]
    required_accessors: tuple[str, ...]
    if operation == "method":
        required_accessors = ("func",)
    elif operation in {"property_get", "default_get"}:
        required_accessors = ("get",)
    elif operation == "property_set":
        required_accessors = ("put",)
    elif operation == "property_roundtrip":
        required_accessors = ("put", "get")
    else:
        raise AssertionError(operation)
    for accessor_name in required_accessors:
        if accessor_name not in accessors:
            _fail(path, f"ledger row has no {accessor_name!r} accessor for {operation}")
    if operation == "default_get":
        if row.get("contract", {}).get("default_member") is not True:
            _fail(path, "default_get requires a canonical default member")
        if accessors["get"].get("is_default_member") is not True:
            _fail(path, "default_get requires the selected get accessor to be canonical default")

    if operation == "method":
        call_accessor = accessors["func"]
        declared_params = _expect_list(call_accessor.get("parameters"), f"{path}.parameters")
    elif operation == "property_set":
        put_params_for_call = _expect_list(accessors["put"].get("parameters"), f"{path}.put.parameters")
        declared_params = put_params_for_call[:-1]
    else:
        call_accessor = accessors["get"]
        declared_params = _expect_list(call_accessor.get("parameters"), f"{path}.parameters")
    args = step.get("args", [])
    if len(args) > len(declared_params):
        _fail(path, f"supplies {len(args)} arguments but accessor declares {len(declared_params)}")
    for index, parameter in enumerate(declared_params):
        flags = set(parameter.get("flags", {}).get("names", []))
        supplied = index < len(args) and args[index]["kind"] != "missing"
        if not supplied and "PARAMFLAG_FOPT" not in flags:
            _fail(path, f"omits required argument at position {index}")

    if operation in {"property_set", "property_roundtrip"}:
        put_params = _expect_list(accessors["put"].get("parameters"), f"{path}.put.parameters")
        # COM property puts carry the assigned value as the final parameter; the
        # manifest's value field represents it separately from index arguments.
        index_params = put_params[:-1]
        if len(args) > len(index_params):
            _fail(path, f"supplies {len(args)} property indices but put declares {len(index_params)}")
        for index, parameter in enumerate(index_params):
            flags = set(parameter.get("flags", {}).get("names", []))
            supplied = index < len(args) and args[index]["kind"] != "missing"
            if not supplied and "PARAMFLAG_FOPT" not in flags:
                _fail(path, f"omits required property index at position {index}")


def _event_parameter_type_name(type_desc: Any) -> str | None:
    current = type_desc
    while type(current) is dict and current.get("kind") == "pointer":
        current = current.get("target")
    if type(current) is not dict:
        return None
    if current.get("kind") == "userdefined":
        target = current.get("target")
        if type(target) is dict and type(target.get("name")) is str:
            return "MSForms." + target["name"]
    scalar_names = {
        "VT_BOOL": "Boolean",
        "VT_I2": "Integer",
        "VT_I4": "Long",
        "VT_R4": "Single",
        "VT_BSTR": "String",
    }
    return scalar_names.get(current.get("vt_name"))


def _validate_event_signature(event: dict[str, Any], row: dict[str, Any], path: str) -> None:
    signature = _expect_dict(row.get("contract", {}).get("event_signature"), f"{path}.event_signature")
    canonical_params = _expect_list(signature.get("parameters"), f"{path}.event_signature.parameters")
    manifest_params = event["parameters"]
    if len(canonical_params) != len(manifest_params):
        _fail(path, f"event declares {len(manifest_params)} parameters but ledger declares {len(canonical_params)}")
    for index, (canonical, declared) in enumerate(zip(canonical_params, manifest_params)):
        ppath = f"{path}.parameters[{index}]"
        canonical_name = canonical.get("name")
        if canonical_name is not None and declared["name"] != canonical_name:
            _fail(ppath, f"parameter name {declared['name']!r} != ledger name {canonical_name!r}")
        expected_type = _event_parameter_type_name(canonical.get("type"))
        if expected_type is None or declared["type"] != expected_type:
            _fail(ppath, f"parameter type {declared['type']!r} != ledger type {expected_type!r}")
        flags = set(canonical.get("flags", {}).get("names", []))
        # FM20 Return* helper pointers are passed ByVal; mutation occurs through
        # their Value property. A scalar FIN|FOUT pointer is the ByRef lane.
        expected_passing = "ByVal" if expected_type.startswith("MSForms.Return") else (
            "ByRef" if "PARAMFLAG_FOUT" in flags else "ByVal"
        )
        if declared["passing"] != expected_passing:
            _fail(ppath, f"passing mode {declared['passing']!r} != {expected_passing!r}")
        if expected_type.startswith("MSForms.Return") and declared.get("value_member") != "Value":
            _fail(ppath, "Return* helper parameters must capture their mutable Value member")


def _load_ledger_snapshot(
    ledger_ref: dict[str, Any], repo_root: Path
) -> tuple[dict[str, Any], dict[str, Any], dict[str, str]]:
    _expect_exact_keys(
        ledger_ref,
        "manifest.ledger",
        [
            "path",
            "file_sha256",
            "canonical_sha256",
            "snapshot_path",
            "snapshot_sha256",
        ],
    )
    if ledger_ref["path"] != CANONICAL_LEDGER:
        _fail("manifest.ledger.path", f"must be exactly {CANONICAL_LEDGER!r}")
    for key in ("file_sha256", "canonical_sha256", "snapshot_sha256"):
        digest = _expect_string(ledger_ref[key], f"manifest.ledger.{key}")
        if not SHA256_RE.fullmatch(digest):
            _fail(f"manifest.ledger.{key}", "must be lowercase SHA-256")
    snapshot_path = _resolve_repo_path(
        repo_root, ledger_ref["snapshot_path"], "manifest.ledger.snapshot_path"
    )
    snapshot_bytes = _read_bound_file(
        snapshot_path,
        "manifest.ledger.snapshot_path",
        max_bytes=16 * 1024 * 1024,
    )
    if sha256_bytes(snapshot_bytes) != ledger_ref["snapshot_sha256"]:
        _fail(
            "manifest.ledger.snapshot_sha256",
            "does not match the immutable selected-row snapshot",
        )
    snapshot = _expect_dict(
        load_json_bytes(snapshot_bytes, snapshot_path), "ledger_snapshot"
    )
    _expect_exact_keys(
        snapshot,
        "ledger_snapshot",
        ["schema", "schema_version", "source_ledger", "rows"],
    )
    if (
        snapshot["schema"] != LEDGER_SNAPSHOT_SCHEMA
        or type(snapshot["schema_version"]) is not int
        or snapshot["schema_version"] != 1
    ):
        _fail("ledger_snapshot", "unexpected schema/version")
    source = _expect_dict(snapshot["source_ledger"], "ledger_snapshot.source_ledger")
    _expect_exact_keys(
        source,
        "ledger_snapshot.source_ledger",
        ["path", "file_sha256", "canonical_sha256"],
    )
    expected_source = {
        key: ledger_ref[key] for key in ("path", "file_sha256", "canonical_sha256")
    }
    if source != expected_source:
        _fail(
            "ledger_snapshot.source_ledger",
            "does not bind the manifest's exact source-ledger identity",
        )
    rows, type_names = _ledger_maps(snapshot)
    return snapshot, rows, type_names


def validate_manifest(
    path: Path,
    repo_root: Path,
    *,
    source_bytes: bytes | None = None,
) -> dict[str, Any]:
    manifest = _expect_dict(
        load_json(path) if source_bytes is None else load_json_bytes(source_bytes, path),
        "manifest",
    )
    _expect_exact_keys(
        manifest,
        "manifest",
        [
            "schema",
            "schema_version",
            "id",
            "bead",
            "ledger",
            "replay_validators",
            "form",
            "steps",
            "events",
            "capture",
            "provenance",
            "environment_requirements",
            "non_claims",
        ],
    )
    if manifest["schema"] != MANIFEST_SCHEMA:
        _fail("manifest.schema", f"must be exactly {MANIFEST_SCHEMA!r}")
    if type(manifest["schema_version"]) is not int or manifest["schema_version"] != SCHEMA_VERSION:
        _fail("manifest.schema_version", "must be integer 1")
    _expect_identifier(manifest["id"], "manifest.id")
    _expect_w010_bead(manifest["bead"], "manifest.bead")

    ledger_ref = _expect_dict(manifest["ledger"], "manifest.ledger")
    _snapshot, rows, type_names = _load_ledger_snapshot(ledger_ref, repo_root)
    referenced_ledger_rows: set[str] = set()

    replay_validators = _expect_dict(
        manifest["replay_validators"], "manifest.replay_validators"
    )
    _expect_exact_keys(
        replay_validators,
        "manifest.replay_validators",
        REPLAY_VALIDATOR_SOURCES,
    )
    for role, expected_path in REPLAY_VALIDATOR_SOURCES.items():
        validator = _expect_dict(
            replay_validators[role], f"manifest.replay_validators.{role}"
        )
        _expect_exact_keys(
            validator,
            f"manifest.replay_validators.{role}",
            ["path", "sha256"],
        )
        if validator["path"] != expected_path:
            _fail(
                f"manifest.replay_validators.{role}.path",
                f"must be exactly {expected_path!r}",
            )
        digest = _expect_string(
            validator["sha256"], f"manifest.replay_validators.{role}.sha256"
        )
        if not SHA256_RE.fullmatch(digest):
            _fail(
                f"manifest.replay_validators.{role}.sha256",
                "must be lowercase SHA-256",
            )

    form = _expect_dict(manifest["form"], "manifest.form")
    _expect_exact_keys(
        form,
        "manifest.form",
        ["name", "caption", "width_pt", "height_pt", "startup_position", "controls"],
    )
    form_name = _expect_identifier(form["name"], "manifest.form.name")
    if len(form_name) > 31:
        _fail("manifest.form.name", "Excel/VBIDE component names are limited to 31 characters")
    if form_name.casefold() == RUNTIME_MODULE_NAME.casefold():
        _fail("manifest.form.name", "collides with the durable oracle runtime module")
    caption = _expect_string(form["caption"], "manifest.form.caption")
    if "\r" in caption or "\n" in caption:
        _fail("manifest.form.caption", "must be a single-line window title")
    for key in ("width_pt", "height_pt"):
        number = form[key]
        if type(number) not in (int, float) or type(number) is bool or not math.isfinite(float(number)) or number <= 0:
            _fail(f"manifest.form.{key}", "must be a positive finite number")
    _expect_int(form["startup_position"], "manifest.form.startup_position", minimum=0)
    controls = _expect_list(form["controls"], "manifest.form.controls")
    if len(controls) < 3:
        _fail("manifest.form.controls", "representative batch requires at least three control families")
    control_by_id: dict[str, dict[str, Any]] = {}
    control_ids_casefold: set[str] = set()
    control_names: set[str] = set()
    control_types: set[str] = set()
    for index, control_value in enumerate(controls):
        cpath = f"manifest.form.controls[{index}]"
        control = _expect_dict(control_value, cpath)
        _expect_exact_keys(
            control,
            cpath,
            [
                "id",
                "name",
                "prog_id",
                "fm20_type",
                "left_pt",
                "top_pt",
                "width_pt",
                "height_pt",
                "initial_properties",
            ],
            ["container"],
        )
        control_id = _expect_identifier(control["id"], f"{cpath}.id")
        if control_id.casefold() in control_ids_casefold:
            _fail(f"{cpath}.id", "duplicate control id (case-insensitive)")
        control_ids_casefold.add(control_id.casefold())
        name = _expect_identifier(control["name"], f"{cpath}.name")
        if len(name) > 31:
            _fail(f"{cpath}.name", "MSForms designer control names are limited to 31 characters")
        if name.casefold() in control_names:
            _fail(f"{cpath}.name", "duplicate control name (case-insensitive)")
        control_names.add(name.casefold())
        prog_id = _expect_string(control["prog_id"], f"{cpath}.prog_id")
        if not PROGID_RE.fullmatch(prog_id):
            _fail(f"{cpath}.prog_id", "must be a Forms.<Class>.1 ProgID")
        fm20_type = _expect_identifier(control["fm20_type"], f"{cpath}.fm20_type")
        expected_fm20_type = PROGID_TO_FM20_TYPE.get(prog_id)
        if expected_fm20_type is None or fm20_type != expected_fm20_type:
            _fail(
                f"{cpath}.fm20_type",
                f"must be {expected_fm20_type!r} for canonical ProgID {prog_id!r}",
            )
        control_types.add(fm20_type)
        for key in ("left_pt", "top_pt", "width_pt", "height_pt"):
            number = control[key]
            if type(number) not in (int, float) or type(number) is bool or not math.isfinite(float(number)):
                _fail(f"{cpath}.{key}", "must be a finite number")
            if key in {"width_pt", "height_pt"} and number <= 0:
                _fail(f"{cpath}.{key}", "must be positive")
        properties = _expect_dict(control["initial_properties"], f"{cpath}.initial_properties")
        for prop_name, prop_value in properties.items():
            _expect_member_identifier(prop_name, f"{cpath}.initial_properties key")
            validate_scalar(prop_value, f"{cpath}.initial_properties.{prop_name}")
        control_by_id[control_id] = control
    parent_by_id: dict[str, str] = {}
    for index, control in enumerate(controls):
        cpath = f"manifest.form.controls[{index}]"
        container = control.get("container", "root")
        _expect_string(container, f"{cpath}.container")
        if container == "root":
            continue
        if not container.startswith("control:"):
            _fail(f"{cpath}.container", "schema v1 supports root or control:<control-id>")
        parent_id = container.split(":", 1)[1]
        if parent_id not in control_by_id:
            _fail(f"{cpath}.container", "unknown parent control id")
        if parent_id == control["id"]:
            _fail(f"{cpath}.container", "a control cannot contain itself")
        if control_by_id[parent_id]["fm20_type"] not in {"Frame"}:
            _fail(f"{cpath}.container", "schema v1 nested Controls.Add parents must be an FM20 Frame")
        parent_by_id[control["id"]] = parent_id
    for control_id in control_by_id:
        seen: set[str] = set()
        current = control_id
        while current in parent_by_id:
            if current in seen:
                _fail("manifest.form.controls", f"container cycle includes {current!r}")
            seen.add(current)
            current = parent_by_id[current]
    if len(control_types) < 3:
        _fail("manifest.form.controls", "representative batch must span at least three FM20 families")

    steps = _expect_list(manifest["steps"], "manifest.steps")
    if not steps:
        _fail("manifest.steps", "must not be empty")
    step_ids: set[str] = set()
    step_id_exact: dict[str, str] = {}
    probe_count = 0
    saw_method = False
    saw_error_expectation = False
    saw_optional_omission = False
    for index, step_value in enumerate(steps):
        spath = f"manifest.steps[{index}]"
        step = _expect_dict(step_value, spath)
        kind = _expect_string(step.get("kind"), f"{spath}.kind")
        if kind == "probe":
            _expect_exact_keys(
                step,
                spath,
                ["kind", "id", "target", "ledger_row_id", "operation", "member", "expect"],
                ["args", "value"],
            )
            probe_count += 1
            step_id = _expect_identifier(step["id"], f"{spath}.id")
            target = _expect_identifier(step["target"], f"{spath}.target")
            if target not in control_by_id:
                _fail(f"{spath}.target", "unknown control id")
            operation = _expect_string(step["operation"], f"{spath}.operation")
            if operation not in ALLOWED_OPERATIONS:
                _fail(f"{spath}.operation", f"unsupported operation: {operation}")
            saw_method = saw_method or operation == "method"
            member = _expect_member_identifier(step["member"], f"{spath}.member")
            linked_row_id = _validate_ledger_link(
                row_id=step["ledger_row_id"],
                member=member,
                fm20_type=control_by_id[target]["fm20_type"],
                allowed_kinds={"surface_member"},
                rows=rows,
                type_names=type_names,
                path=f"{spath}.ledger_row_id",
            )
            referenced_ledger_rows.add(linked_row_id)
            _validate_probe_accessor(step, rows[linked_row_id], f"{spath}.ledger_row_id")
            args = _expect_list(step.get("args", []), f"{spath}.args")
            for arg_index, arg in enumerate(args):
                validate_argument(arg, f"{spath}.args[{arg_index}]")
            if operation in {"property_set", "property_roundtrip"}:
                if "value" not in step:
                    _fail(spath, f"{operation} requires value")
                validate_scalar(step["value"], f"{spath}.value")
            elif "value" in step:
                _fail(spath, f"{operation} forbids value")
            if any(arg["kind"] == "missing" for arg in args):
                saw_optional_omission = True
            expect = _expect_dict(step["expect"], f"{spath}.expect")
            _expect_exact_keys(
                expect,
                f"{spath}.expect",
                ["outcome"],
                [
                    "value",
                    "type_name",
                    "var_type",
                    "error_number",
                    "last_dll_error_equals",
                    "description_equals",
                    "description_utf16_hex_equals",
                    "source_equals",
                    "help_file_equals",
                    "help_context_equals",
                    "line_equals",
                    "error_stage",
                ],
            )
            outcome = _expect_string(expect["outcome"], f"{spath}.expect.outcome")
            if outcome not in {"success", "error"}:
                _fail(f"{spath}.expect.outcome", "must be success or error")
            if outcome == "success":
                if any(
                    key in expect
                    for key in (
                        "error_number",
                        "last_dll_error_equals",
                        "description_equals",
                        "description_utf16_hex_equals",
                        "source_equals",
                        "help_file_equals",
                        "help_context_equals",
                        "line_equals",
                        "error_stage",
                    )
                ):
                    _fail(f"{spath}.expect", "success expectation cannot name an error")
                for result_type_key in ("type_name", "var_type"):
                    if result_type_key not in expect:
                        _fail(
                            f"{spath}.expect",
                            f"success expectation must pin {result_type_key}",
                        )
                expected_type_name = _expect_string(
                    expect["type_name"], f"{spath}.expect.type_name"
                )
                expected_var_type = _expect_int(
                    expect["var_type"],
                    f"{spath}.expect.var_type",
                    minimum=0,
                )
                if operation in {"property_get", "default_get", "property_roundtrip"} and "value" not in expect:
                    _fail(
                        f"{spath}.expect",
                        f"successful {operation} must pin its returned scalar value",
                    )
                if "value" in expect:
                    validate_scalar(expect["value"], f"{spath}.expect.value")
                    result_kind = expect["value"]["kind"]
                else:
                    result_kind = "empty"
                if (
                    expected_type_name,
                    expected_var_type,
                ) not in SCALAR_RESULT_SHAPES[result_kind]:
                    _fail(
                        f"{spath}.expect",
                        "type_name/var_type does not match the expected scalar kind "
                        f"{result_kind!r}",
                    )
            else:
                saw_error_expectation = True
                forbidden_error_keys = sorted(
                    key
                    for key in ("value", "type_name", "var_type")
                    if key in expect
                )
                if forbidden_error_keys:
                    _fail(
                        f"{spath}.expect",
                        "error expectation cannot name returned value fields: "
                        + ", ".join(forbidden_error_keys),
                    )
                for required_error_key in (
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
                    if required_error_key not in expect:
                        _fail(
                            f"{spath}.expect",
                            f"error expectation must pin {required_error_key}",
                        )
                error_number = _expect_int(
                    expect["error_number"], f"{spath}.expect.error_number"
                )
                if error_number == 0:
                    _fail(f"{spath}.expect.error_number", "must be nonzero")
                for long_expectation in (
                    "last_dll_error_equals",
                    "help_context_equals",
                    "line_equals",
                ):
                    long_value = _expect_int(
                        expect[long_expectation],
                        f"{spath}.expect.{long_expectation}",
                    )
                    if long_value < -2147483648 or long_value > 2147483647:
                        _fail(
                            f"{spath}.expect.{long_expectation}",
                            "must fit a signed VBA Long",
                        )
                validate_error_description_encoding(
                    expect["description_equals"],
                    expect["description_utf16_hex_equals"],
                    f"{spath}.expect",
                )
                for string_expectation in ("source_equals", "help_file_equals"):
                    _expect_string(
                        expect[string_expectation],
                        f"{spath}.expect.{string_expectation}",
                        nonempty=False,
                    )
                error_stage = _expect_string(
                    expect["error_stage"], f"{spath}.expect.error_stage"
                )
                allowed_error_stages = {
                    "property_get": {"get"},
                    "property_set": {"set"},
                    "property_roundtrip": {"set", "get"},
                    "default_get": {"default_get"},
                    "method": {"method"},
                }[operation]
                if error_stage not in allowed_error_stages:
                    _fail(
                        f"{spath}.expect.error_stage",
                        f"must be one of {sorted(allowed_error_stages)} for {operation}",
                    )
        elif kind == "focus":
            _expect_exact_keys(step, spath, ["kind", "id", "target", "expect"])
            step_id = _expect_identifier(step["id"], f"{spath}.id")
            target = _expect_identifier(step["target"], f"{spath}.target")
            if target not in control_by_id:
                _fail(f"{spath}.target", "unknown control id")
            focus_expect = _expect_dict(step["expect"], f"{spath}.expect")
            _expect_exact_keys(
                focus_expect,
                f"{spath}.expect",
                ["outcome"],
                ["error_number", "description_equals", "source_equals"],
            )
            focus_outcome = _expect_string(
                focus_expect["outcome"], f"{spath}.expect.outcome"
            )
            if focus_outcome not in {"success", "error"}:
                _fail(f"{spath}.expect.outcome", "must be success or error")
            focus_error_keys = (
                "error_number",
                "description_equals",
                "source_equals",
            )
            if focus_outcome == "success":
                named_error_keys = sorted(
                    key for key in focus_error_keys if key in focus_expect
                )
                if named_error_keys:
                    _fail(
                        f"{spath}.expect",
                        "successful focus expectation cannot name errors: "
                        + ", ".join(named_error_keys),
                    )
            else:
                for required_key in focus_error_keys:
                    if required_key not in focus_expect:
                        _fail(
                            f"{spath}.expect",
                            f"focus error expectation must pin {required_key}",
                        )
                focus_error_number = _expect_int(
                    focus_expect["error_number"],
                    f"{spath}.expect.error_number",
                )
                if focus_error_number == 0:
                    _fail(f"{spath}.expect.error_number", "must be nonzero")
                if focus_error_number < -2147483648 or focus_error_number > 2147483647:
                    _fail(
                        f"{spath}.expect.error_number",
                        "must fit a signed VBA Long",
                    )
                for string_key in ("description_equals", "source_equals"):
                    focus_text = _expect_string(
                        focus_expect[string_key], f"{spath}.expect.{string_key}"
                    )
                    if (
                        len(focus_text) > 255
                        or "\r" in focus_text
                        or "\n" in focus_text
                    ):
                        _fail(
                            f"{spath}.expect.{string_key}",
                            "must be a bounded single-line VBA string",
                        )
        elif kind == "do_events":
            _expect_exact_keys(step, spath, ["kind", "id"])
            step_id = _expect_identifier(step["id"], f"{spath}.id")
        else:
            _fail(f"{spath}.kind", f"unsupported step kind: {kind}")
        if step_id.casefold() in step_ids:
            _fail(f"{spath}.id", "duplicate step id (case-insensitive)")
        step_ids.add(step_id.casefold())
        step_id_exact[step_id.casefold()] = step_id
    if probe_count < 6:
        _fail("manifest.steps", "representative batch requires at least six member probes")
    if not saw_method:
        _fail("manifest.steps", "representative batch requires a method probe")
    if not saw_error_expectation:
        _fail("manifest.steps", "representative batch requires an error probe")
    if not saw_optional_omission:
        _fail("manifest.steps", "representative batch requires an omitted optional/default argument")

    events = _expect_list(manifest["events"], "manifest.events")
    if not events:
        _fail("manifest.events", "must declare at least one event")
    event_ids: set[str] = set()
    event_handlers: set[tuple[str, str]] = set()
    saw_mutation = False
    for index, event_value in enumerate(events):
        epath = f"manifest.events[{index}]"
        event = _expect_dict(event_value, epath)
        _expect_exact_keys(
            event,
            epath,
            [
                "id",
                "target",
                "name",
                "ledger_row_id",
                "parameters",
                "mutations",
                "expected_occurrences",
                "trigger_step_id",
                "expect",
            ],
        )
        event_id = _expect_identifier(event["id"], f"{epath}.id")
        if event_id.casefold() in event_ids:
            _fail(f"{epath}.id", "duplicate event id (case-insensitive)")
        event_ids.add(event_id.casefold())
        target = _expect_identifier(event["target"], f"{epath}.target")
        if target not in control_by_id:
            _fail(f"{epath}.target", "unknown control id")
        name = _expect_member_identifier(event["name"], f"{epath}.name")
        handler_key = (target.casefold(), name.casefold())
        if handler_key in event_handlers:
            _fail(epath, "duplicate VBA handler for the same target/event pair")
        event_handlers.add(handler_key)
        linked_event_row_id = _validate_ledger_link(
            row_id=event["ledger_row_id"],
            member=name,
            fm20_type=control_by_id[target]["fm20_type"],
            allowed_kinds={"event_projection", "host_event_attachment"},
            rows=rows,
            type_names=type_names,
            path=f"{epath}.ledger_row_id",
        )
        referenced_ledger_rows.add(linked_event_row_id)
        trigger_step_id = _expect_identifier(
            event["trigger_step_id"], f"{epath}.trigger_step_id"
        )
        if trigger_step_id.casefold() not in step_ids:
            _fail(f"{epath}.trigger_step_id", "does not identify a declared execution step")
        if trigger_step_id != step_id_exact[trigger_step_id.casefold()]:
            _fail(f"{epath}.trigger_step_id", "must preserve the exact declared step spelling")
        params = _expect_list(event["parameters"], f"{epath}.parameters")
        param_by_name: dict[str, dict[str, Any]] = {}
        for pindex, parameter_value in enumerate(params):
            ppath = f"{epath}.parameters[{pindex}]"
            parameter = _expect_dict(parameter_value, ppath)
            _expect_exact_keys(parameter, ppath, ["name", "passing", "type"], ["value_member"])
            pname = _expect_identifier(parameter["name"], f"{ppath}.name")
            if pname.casefold() in {name.casefold() for name in param_by_name}:
                _fail(f"{ppath}.name", "duplicate parameter name")
            passing = _expect_string(parameter["passing"], f"{ppath}.passing")
            if passing not in {"ByVal", "ByRef"}:
                _fail(f"{ppath}.passing", "must be ByVal or ByRef")
            ptype = _expect_string(parameter["type"], f"{ppath}.type")
            if ptype not in ALLOWED_EVENT_TYPES:
                _fail(f"{ppath}.type", f"unsupported event parameter type: {ptype}")
            if "value_member" in parameter:
                _expect_member_identifier(parameter["value_member"], f"{ppath}.value_member")
                if not ptype.startswith("MSForms.Return"):
                    _fail(
                        f"{ppath}.value_member",
                        "is only valid for MSForms.Return* helper parameters",
                    )
            param_by_name[pname] = parameter
        _validate_event_signature(event, rows[linked_event_row_id], f"{epath}.ledger_row_id")
        mutations = _expect_list(event["mutations"], f"{epath}.mutations")
        for mindex, mutation_value in enumerate(mutations):
            mpath = f"{epath}.mutations[{mindex}]"
            mutation = _expect_dict(mutation_value, mpath)
            _expect_exact_keys(mutation, mpath, ["parameter", "value"], ["member"])
            pname = _expect_identifier(mutation["parameter"], f"{mpath}.parameter")
            if pname not in param_by_name:
                _fail(f"{mpath}.parameter", "does not identify an event parameter")
            if "member" in mutation:
                _expect_member_identifier(mutation["member"], f"{mpath}.member")
            declared_value_member = param_by_name[pname].get("value_member")
            if declared_value_member is not None and mutation.get("member") != declared_value_member:
                _fail(
                    f"{mpath}.member",
                    f"must target the declared mutable Value member {declared_value_member!r}",
                )
            if declared_value_member is None:
                if "member" in mutation:
                    _fail(f"{mpath}.member", "plain scalar mutation cannot name an object member")
                if param_by_name[pname]["passing"] != "ByRef":
                    _fail(
                        f"{mpath}.parameter",
                        "plain scalar mutation requires a ByRef event parameter",
                    )
            validate_scalar(mutation["value"], f"{mpath}.value")
            saw_mutation = True
        _expect_int(event["expected_occurrences"], f"{epath}.expected_occurrences", minimum=1)
        expected = _expect_dict(event["expect"], f"{epath}.expect")
        _expect_exact_keys(expected, f"{epath}.expect", ["arguments_before", "arguments_after"])
        _expect_string(expected["arguments_before"], f"{epath}.expect.arguments_before", nonempty=False)
        _expect_string(expected["arguments_after"], f"{epath}.expect.arguments_after", nonempty=False)
    if not saw_mutation:
        _fail("manifest.events", "representative batch requires a mutable event argument")

    required_snapshot_rows = set(referenced_ledger_rows)
    for row_id in referenced_ledger_rows:
        owner_id = rows[row_id].get("facade_owner_type_id")
        owner_contracts = [
            candidate_id
            for candidate_id, candidate in rows.items()
            if candidate.get("row_kind") == "type_contract"
            and candidate.get("facade_owner_type_id") == owner_id
        ]
        if len(owner_contracts) != 1:
            _fail(
                "ledger_snapshot.rows",
                f"owner {owner_id!r} must have exactly one preserved type contract",
            )
        required_snapshot_rows.add(owner_contracts[0])
    if set(rows) != required_snapshot_rows:
        missing = sorted(required_snapshot_rows - set(rows))
        extra = sorted(set(rows) - required_snapshot_rows)
        _fail(
            "ledger_snapshot.rows",
            f"must be the exact selected-row closure; missing={missing}, extra={extra}",
        )

    capture = _expect_dict(manifest["capture"], "manifest.capture")
    _expect_exact_keys(
        capture,
        "manifest.capture",
        ["screenshot", "export_frm_frx", "workbook", "result_sheet", "event_sheet"],
    )
    for key in ("screenshot", "export_frm_frx", "workbook"):
        if not _expect_bool(capture[key], f"manifest.capture.{key}"):
            _fail(f"manifest.capture.{key}", "must be true for the representative closure batch")
    result_sheet = _expect_identifier(capture["result_sheet"], "manifest.capture.result_sheet")
    event_sheet = _expect_identifier(capture["event_sheet"], "manifest.capture.event_sheet")
    if len(result_sheet) > 31 or len(event_sheet) > 31:
        _fail("manifest.capture", "Excel worksheet names are limited to 31 characters")
    if capture["result_sheet"].casefold() == capture["event_sheet"].casefold():
        _fail("manifest.capture", "result_sheet and event_sheet must differ")

    provenance = _expect_dict(manifest["provenance"], "manifest.provenance")
    _expect_exact_keys(
        provenance,
        "manifest.provenance",
        ["observation_source", "oxforms_output_paths", "clean_room_basis", "prohibited"],
    )
    if provenance["observation_source"] != OBSERVATION_SOURCE:
        _fail("manifest.provenance.observation_source", f"must be {OBSERVATION_SOURCE!r}")
    oxforms_paths = _expect_list(provenance["oxforms_output_paths"], "manifest.provenance.oxforms_output_paths")
    if oxforms_paths:
        _fail("manifest.provenance.oxforms_output_paths", "must be empty; oracle input cannot contain OxForms output")
    _expect_string(provenance["clean_room_basis"], "manifest.provenance.clean_room_basis")
    _expect_string(provenance["prohibited"], "manifest.provenance.prohibited")

    requirements = _expect_list(manifest["environment_requirements"], "manifest.environment_requirements")
    if len(requirements) < 3:
        _fail("manifest.environment_requirements", "must state Windows, Excel/VBIDE, and desktop requirements")
    for index, requirement in enumerate(requirements):
        _expect_string(requirement, f"manifest.environment_requirements[{index}]")
    for required_environment_statement in (
        ENGLISH_OFFICE_REQUIREMENT,
        VBE_ERROR_TRAPPING_REQUIREMENT,
    ):
        if required_environment_statement not in requirements:
            _fail(
                "manifest.environment_requirements",
                f"must include exact prerequisite {required_environment_statement!r}",
            )
    non_claims = _expect_list(manifest["non_claims"], "manifest.non_claims")
    if len(non_claims) < 2:
        _fail("manifest.non_claims", "must preserve at least two nonclaims")
    for index, non_claim in enumerate(non_claims):
        _expect_string(non_claim, f"manifest.non_claims[{index}]")
    if not any("OxForms" in text for text in non_claims):
        _fail("manifest.non_claims", "must explicitly disclaim an OxForms behavior claim")
    if COM_ADDINS_NONCLAIM not in non_claims:
        _fail(
            "manifest.non_claims",
            "must preserve the conditional COMAddIns connection-state nonclaim",
        )
    if not any(
        "MS-OFORMS" in text and "not yet semantically bound" in text
        for text in non_claims
    ):
        _fail(
            "manifest.non_claims",
            "must disclaim semantic persisted-control-graph binding",
        )
    if not any(
        "p-code" in text and "VBA-stomp resistance" in text for text in non_claims
    ):
        _fail(
            "manifest.non_claims",
            "must disclaim compiled-cache/p-code execution binding",
        )
    return manifest


def _safe_proc_suffix(identifier: str) -> str:
    return identifier


def _generate_probe_proc(
    step: dict[str, Any], form_name: str, controls: dict[str, dict[str, Any]]
) -> str:
    proc = _safe_proc_suffix(step["id"])
    args = step.get("args", [])
    arg_text = argument_vba_text(args)
    index_suffix = f"({arg_text})" if arg_text else ""
    member_name = step["member"]
    persisted_member_name = "value" if member_name == "Value" else member_name
    member = _vba_string(member_name)
    target_id = _vba_string(step["target"])
    target_expression = f"{form_name}.{controls[step['target']]['name']}"
    ledger_id = _vba_string(step["ledger_row_id"])
    operation = step["operation"]

    def error_snapshot(indent: str = "    ") -> list[str]:
        return [
            f"{indent}errorLastDllError = Err.LastDllError",
            f"{indent}errorNumber = Err.number",
            f"{indent}errorDescription = Err.Description",
            f"{indent}errorSource = Err.Source",
            f"{indent}errorHelpFile = Err.HelpFile",
            f"{indent}errorHelpContext = Err.HelpContext",
            f"{indent}errorLine = Erl",
            f"{indent}errorDescriptionUtf16Hex = OracleUtf16Hex(errorDescription)",
            f"{indent}errorDescription = OracleWorksheetSafeErrorDescription(errorDescription)",
            f"{indent}errorHex = OracleErrorHex(errorNumber)",
        ]

    lines = [
        f"Private Sub Probe_{proc}()",
        "    Dim resultValue As Variant",
        "    Dim errorNumber As Long",
        "    Dim errorLastDllError As Long",
        "    Dim errorHex As String",
        "    Dim errorDescription As String",
        "    Dim errorDescriptionUtf16Hex As String",
        "    Dim errorSource As String",
        "    Dim errorHelpFile As String",
        "    Dim errorHelpContext As Long",
        "    Dim errorLine As Long",
        "    Dim errorStage As String",
        "    On Error Resume Next",
        "    Err.Clear",
    ]
    if operation == "property_get":
        lines += [
            '    errorStage = "get"',
            f"    resultValue = {target_expression}.{persisted_member_name}{index_suffix}",
        ] + error_snapshot()
    elif operation == "default_get":
        lines += [
            '    errorStage = "default_get"',
            f"    resultValue = {target_expression}{index_suffix}",
        ] + error_snapshot()
    elif operation == "property_set":
        value = scalar_vba_literal(step["value"])
        lines += [
            "    resultValue = Empty",
            '    errorStage = "set"',
            f"    {target_expression}.{persisted_member_name}{index_suffix} = {value}",
        ] + error_snapshot()
    elif operation == "property_roundtrip":
        value = scalar_vba_literal(step["value"])
        lines += [
            '    errorStage = "set"',
            f"    {target_expression}.{persisted_member_name}{index_suffix} = {value}",
        ] + error_snapshot() + [
            "    If errorNumber = 0 Then",
            "        Err.Clear",
            '        errorStage = "get"',
            f"        resultValue = {target_expression}.{persisted_member_name}{index_suffix}",
        ] + error_snapshot("        ") + ["    End If"]
    elif operation == "method":
        invocation = f"{target_expression}.{persisted_member_name}"
        if arg_text:
            invocation += " " + arg_text
        lines += [
            "    resultValue = Empty",
            '    errorStage = "method"',
            f"    {invocation}",
        ] + error_snapshot()
    else:
        raise AssertionError(operation)
    lines += [
        "    Err.Clear",
        "    On Error GoTo 0",
        "    AppendOracleProbe "
        + ", ".join(
            [
                _vba_string(step["id"]),
                ledger_id,
                target_id,
                _vba_string(operation),
                member,
                "resultValue",
                "errorNumber",
                "errorLastDllError",
                "errorHex",
                "errorDescription",
                "errorDescriptionUtf16Hex",
                "errorSource",
                "errorHelpFile",
                "errorHelpContext",
                "errorLine",
                "errorStage",
            ]
        ),
        "End Sub",
    ]
    return "\n".join(lines)


def _event_value_expression(parameter: dict[str, Any]) -> str:
    expression = parameter["name"]
    if parameter.get("value_member"):
        # The FM20/VBIDE source canonicalizer exports Return* helpers with the
        # dispatch member spelling ``value``.  Emit that stable spelling up
        # front so the preserved generated source can be compared to the real
        # Office export without a broad case-insensitive normalization.
        expression += "." + parameter["value_member"].casefold()
    return expression


def _event_pairs(parameters: list[dict[str, Any]]) -> str:
    if not parameters:
        return '""'
    parts: list[str] = []
    for parameter in parameters:
        label = _vba_string(parameter["name"] + "=")
        expression = _event_value_expression(parameter)
        parts.append(f"{label} & OracleEscapePair(OracleValueText({expression}))")
    return ' & ";" & '.join(parts)


def generate_form_code(manifest: dict[str, Any]) -> str:
    controls = {control["id"]: control for control in manifest["form"]["controls"]}
    blocks = ["Option Explicit"]
    for event in manifest["events"]:
        control = controls[event["target"]]
        parameters = event["parameters"]
        signature = ", ".join(
            f"{parameter['passing']} {parameter['name']} As {parameter['type']}"
            for parameter in parameters
        )
        lines = [
            f"Private Sub {control['name']}_{event['name']}({signature})",
            "    Dim argumentsBefore As String",
            "    Dim argumentsAfter As String",
            "    If Not OracleRecordingEnabled() Then Exit Sub",
        ]
        if parameters:
            lines.append(f"    argumentsBefore = {_event_pairs(parameters)}")
        for mutation in event["mutations"]:
            lhs = mutation["parameter"]
            if mutation.get("member"):
                lhs += "." + mutation["member"].casefold()
            lines.append(f"    {lhs} = {scalar_vba_literal(mutation['value'])}")
        if parameters:
            lines.append(f"    argumentsAfter = {_event_pairs(parameters)}")
        else:
            lines.append('    argumentsBefore = ""')
            lines.append('    argumentsAfter = ""')
        lines.append(
            "    RecordOracleEvent "
            + ", ".join(
                [
                    _vba_string(event["id"]),
                    _vba_string(event["ledger_row_id"]),
                    _vba_string(event["target"]),
                    _vba_string(control["fm20_type"]),
                    _vba_string(event["name"]),
                    "argumentsBefore",
                    "argumentsAfter",
                ]
            )
        )
        lines.append("End Sub")
        blocks.append("\n".join(lines))
    return "\n\n".join(blocks) + "\n"


def generate_module_code(manifest: dict[str, Any]) -> str:
    form_name = manifest["form"]["name"]
    result_sheet = manifest["capture"]["result_sheet"]
    event_sheet = manifest["capture"]["event_sheet"]
    result_headers_vba = ", ".join(_vba_string(header) for header in RESULT_HEADERS)
    event_headers_vba = ", ".join(_vba_string(header) for header in EVENT_HEADERS)
    controls = {control["id"]: control for control in manifest["form"]["controls"]}
    run_lines = [
        "Public Sub RunMemberOracle()",
        "    Dim failureNumber As Long",
        "    Dim failureDescription As String",
        "    Dim failureSource As String",
        "    On Error GoTo HarnessFailed",
        "    ResetOracleSheets",
        '    mCurrentStep = "ShowForm"',
        f"    {form_name}.Show vbModeless",
        "    DoEvents",
    ]
    for step in manifest["steps"]:
        run_lines.append(f"    mCurrentStep = {_vba_string(step['id'])}")
        if step["kind"] == "probe":
            run_lines.append(f"    Probe_{_safe_proc_suffix(step['id'])}")
        elif step["kind"] == "focus":
            control = controls[step["target"]]
            focus_expect = step["expect"]
            run_lines += [
                "    On Error Resume Next",
                "    Err.Clear",
                f"    {form_name}.{control['name']}.SetFocus",
                "    failureNumber = Err.number",
                "    failureDescription = Err.Description",
                "    failureSource = Err.Source",
                "    Err.Clear",
                "    On Error GoTo HarnessFailed",
            ]
            if focus_expect["outcome"] == "success":
                focus_mismatch = "failureNumber <> 0"
            else:
                focus_mismatch = " Or ".join(
                    [
                        "failureNumber <> "
                        + vba_long_literal(focus_expect["error_number"]),
                        "failureDescription <> "
                        + _vba_string(focus_expect["description_equals"]),
                        "failureSource <> "
                        + _vba_string(focus_expect["source_equals"]),
                    ]
                )
            run_lines += [
                f"    If {focus_mismatch} Then",
                "        Err.Raise vbObjectError + 2048, "
                + _vba_string("OxForms.MemberOracle")
                + ", "
                + _vba_string(f"Focus step {step['id']} observed an unexpected outcome")
                + " & vbTab & CStr(failureNumber) & vbTab & failureDescription & vbTab & failureSource",
                "    End If",
            ]
            run_lines.append("    DoEvents")
        else:
            run_lines.append("    DoEvents")
    run_lines += [
        "    Exit Sub",
        "HarnessFailed:",
        "    failureNumber = Err.number",
        "    failureDescription = Err.Description",
        "    failureSource = Err.Source",
        '    mHarnessError = CStr(failureNumber) & vbTab & failureDescription & vbTab & failureSource & vbTab & mCurrentStep',
        "    mRecordingEnabled = False",
        "    On Error Resume Next",
        "    UnloadMemberOracleIfLoaded",
        "    On Error GoTo 0",
        "End Sub",
    ]

    helpers = f'''Option Explicit

Private Const RESULT_SHEET As String = {_vba_string(result_sheet)}
Private Const EVENT_SHEET As String = {_vba_string(event_sheet)}
Private mSequence As Long
Private mCurrentStep As String
Private mHarnessError As String
Private mRecordingEnabled As Boolean

{os.linesep.join(run_lines)}

Private Sub UnloadMemberOracleIfLoaded()
    Dim loadedForm As Object
    For Each loadedForm In UserForms
        If StrComp(TypeName(loadedForm), {_vba_string(form_name)}, vbBinaryCompare) = 0 Then
            Unload loadedForm
            Exit For
        End If
    Next loadedForm
End Sub

Public Sub CloseMemberOracle()
    mRecordingEnabled = False
    UnloadMemberOracleIfLoaded
    DoEvents
End Sub

Public Function GetMemberOracleHarnessError() As String
    GetMemberOracleHarnessError = mHarnessError
End Function

Public Function OracleRecordingEnabled() As Boolean
    OracleRecordingEnabled = mRecordingEnabled
End Function

Private Sub ResetOracleSheets()
    Dim resultSheet As Worksheet
    Dim eventSheet As Worksheet
    mSequence = 0
    mHarnessError = ""
    mRecordingEnabled = True
    Set resultSheet = GetOrCreateOracleSheet(RESULT_SHEET)
    Set eventSheet = GetOrCreateOracleSheet(EVENT_SHEET)
    resultSheet.Cells.Clear
    eventSheet.Cells.Clear
    WriteOracleHeaders resultSheet, Array({result_headers_vba})
    WriteOracleHeaders eventSheet, Array({event_headers_vba})
End Sub

Private Function GetOrCreateOracleSheet(ByVal sheetName As String) As Worksheet
    On Error Resume Next
    Set GetOrCreateOracleSheet = ThisWorkbook.Worksheets(sheetName)
    On Error GoTo 0
    If GetOrCreateOracleSheet Is Nothing Then
        Set GetOrCreateOracleSheet = ThisWorkbook.Worksheets.Add
        GetOrCreateOracleSheet.Name = sheetName
    End If
End Function

Private Sub WriteOracleHeaders(ByVal sheet As Worksheet, ByVal headers As Variant)
    Dim index As Long
    For index = LBound(headers) To UBound(headers)
        sheet.Cells(1, index + 1).value = CStr(headers(index))
    Next index
End Sub

Private Sub AppendOracleProbe(ByVal probeId As String, ByVal ledgerRowId As String, ByVal targetId As String, ByVal operation As String, ByVal memberName As String, ByVal resultValue As Variant, ByVal errorNumber As Long, ByVal errorLastDllError As Long, ByVal errorHex As String, ByVal errorDescription As String, ByVal errorDescriptionUtf16Hex As String, ByVal errorSource As String, ByVal errorHelpFile As String, ByVal errorHelpContext As Long, ByVal errorLine As Long, ByVal errorStage As String)
    Dim sheet As Worksheet
    Dim rowNumber As Long
    Set sheet = GetOrCreateOracleSheet(RESULT_SHEET)
    mSequence = mSequence + 1
    rowNumber = sheet.Cells(sheet.Rows.Count, 1).End(xlUp).Row + 1
    sheet.Cells(rowNumber, 1).value = mSequence
    sheet.Cells(rowNumber, 2).value = probeId
    sheet.Cells(rowNumber, 3).value = ledgerRowId
    sheet.Cells(rowNumber, 4).value = targetId
    sheet.Cells(rowNumber, 5).value = operation
    sheet.Cells(rowNumber, 6).value = memberName
    If errorNumber = 0 Then
        sheet.Cells(rowNumber, 7).value = "success"
        sheet.Cells(rowNumber, 8).value = OracleValueText(resultValue)
        sheet.Cells(rowNumber, 9).value = TypeName(resultValue)
        sheet.Cells(rowNumber, 10).value = CStr(VarType(resultValue))
        sheet.Cells(rowNumber, 11).value = CStr(IsObject(resultValue))
        sheet.Cells(rowNumber, 12).value = CStr(IsArray(resultValue))
    Else
        sheet.Cells(rowNumber, 7).value = "error"
        sheet.Cells(rowNumber, 8).value = ""
        sheet.Cells(rowNumber, 9).value = ""
        sheet.Cells(rowNumber, 10).value = ""
        sheet.Cells(rowNumber, 11).value = ""
        sheet.Cells(rowNumber, 12).value = ""
    End If
    sheet.Cells(rowNumber, 13).value = errorNumber
    sheet.Cells(rowNumber, 14).value = errorLastDllError
    sheet.Cells(rowNumber, 15).value = errorHex
    sheet.Cells(rowNumber, 16).value = errorDescription
    sheet.Cells(rowNumber, 17).value = errorDescriptionUtf16Hex
    sheet.Cells(rowNumber, 18).value = errorSource
    sheet.Cells(rowNumber, 19).value = errorHelpFile
    sheet.Cells(rowNumber, 20).value = errorHelpContext
    sheet.Cells(rowNumber, 21).value = errorLine
    sheet.Cells(rowNumber, 22).value = errorStage
End Sub

Public Sub RecordOracleEvent(ByVal eventId As String, ByVal ledgerRowId As String, ByVal targetId As String, ByVal targetKind As String, ByVal eventName As String, ByVal argumentsBefore As String, ByVal argumentsAfter As String)
    Dim sheet As Worksheet
    Dim rowNumber As Long
    If Not mRecordingEnabled Then Exit Sub
    Set sheet = GetOrCreateOracleSheet(EVENT_SHEET)
    mSequence = mSequence + 1
    rowNumber = sheet.Cells(sheet.Rows.Count, 1).End(xlUp).Row + 1
    sheet.Cells(rowNumber, 1).value = mSequence
    sheet.Cells(rowNumber, 2).value = eventId
    sheet.Cells(rowNumber, 3).value = ledgerRowId
    sheet.Cells(rowNumber, 4).value = targetId
    sheet.Cells(rowNumber, 5).value = targetKind
    sheet.Cells(rowNumber, 6).value = eventName
    sheet.Cells(rowNumber, 7).value = argumentsBefore
    sheet.Cells(rowNumber, 8).value = argumentsAfter
    sheet.Cells(rowNumber, 9).value = mCurrentStep
End Sub

Public Function OracleValueText(ByVal value As Variant) As String
    On Error GoTo Failed
    If IsObject(value) Then
        OracleValueText = TypeName(value)
    ElseIf IsEmpty(value) Then
        OracleValueText = ""
    ElseIf IsNull(value) Then
        OracleValueText = "<Null>"
    Else
        OracleValueText = CStr(value)
    End If
    Exit Function
Failed:
    OracleValueText = "<unavailable>"
End Function

Public Function OracleEscapePair(ByVal value As String) As String
    OracleEscapePair = Replace(Replace(Replace(value, "\\", "\\\\"), ";", "\\;"), "=", "\\=")
End Function

Public Function OracleErrorHex(ByVal number As Long) As String
    OracleErrorHex = "0x" & Right$("00000000" & Hex$(number), 8)
End Function

Public Function OracleUtf16Hex(ByVal value As String) As String
    Dim index As Long
    Dim codeUnit As Long
    Dim encoded As String
    For index = 1 To Len(value)
        codeUnit = CLng(AscW(Mid$(value, index, 1))) And &HFFFF&
        If index > 1 Then encoded = encoded & " "
        encoded = encoded & Right$("0000" & Hex$(codeUnit), 4)
    Next index
    OracleUtf16Hex = encoded
End Function

Public Function OracleWorksheetSafeErrorDescription(ByVal value As String) As String
    If Len(value) > 0 Then
        If AscW(Right$(value, 1)) = 0 Then
            OracleWorksheetSafeErrorDescription = Left$(value, Len(value) - 1)
            Exit Function
        End If
    End If
    OracleWorksheetSafeErrorDescription = value
End Function
'''
    probe_blocks = [
        _generate_probe_proc(step, form_name, controls)
        for step in manifest["steps"]
        if step["kind"] == "probe"
    ]
    return helpers.replace("\r\n", "\n") + "\n" + "\n\n".join(probe_blocks) + "\n"


def generate_sources(manifest_path: Path, output_dir: Path, repo_root: Path) -> dict[str, str]:
    manifest = validate_manifest(manifest_path, repo_root)
    if output_dir.exists() and (output_dir.is_symlink() or output_dir.is_junction()):
        raise OracleValidationError("Generated source directory must not be a reparse point")
    output_dir.mkdir(parents=True, exist_ok=True)
    outputs = {
        "normalized_manifest": output_dir / "normalized-manifest.v1.json",
        "form_code": output_dir / "generated-form-code.bas",
        "module_code": output_dir / "generated-module-code.bas",
    }
    existing = [path for path in outputs.values() if path.exists()]
    if existing:
        raise OracleValidationError(
            "Refusing to overwrite generated source files: " + ", ".join(str(path) for path in existing)
        )
    outputs["normalized_manifest"].write_bytes(canonical_json_bytes(manifest))
    outputs["form_code"].write_text(generate_form_code(manifest), encoding="utf-8", newline="\n")
    outputs["module_code"].write_text(generate_module_code(manifest), encoding="utf-8", newline="\n")
    return {key: str(path) for key, path in outputs.items()}


def _repo_output_path(repo_root: Path, relative: Any, path: str) -> Path:
    text = _expect_string(relative, path)
    if "\\" in text or Path(text).is_absolute() or ".." in Path(text).parts or text.startswith("/"):
        _fail(path, "must be a safe repository-relative forward-slash path")
    root = repo_root.resolve()
    candidate = (root / Path(text)).absolute()
    try:
        candidate.relative_to(root)
    except ValueError:
        _fail(path, "must resolve inside the repository")
    current = candidate.parent
    while True:
        if current.exists() and (current.is_symlink() or current.is_junction()):
            _fail(path, f"reparse/symbolic output parent is forbidden: {current}")
        if current == root or current.parent == current:
            break
        current = current.parent
    return candidate


def _build_ledger_snapshot_document(manifest: dict[str, Any], ledger: dict[str, Any]) -> dict[str, Any]:
    ledger_ref = _expect_dict(manifest.get("ledger"), "manifest.ledger")
    selected_ids: set[str] = set()
    for index, step_value in enumerate(_expect_list(manifest.get("steps"), "manifest.steps")):
        step = _expect_dict(step_value, f"manifest.steps[{index}]")
        if step.get("kind") == "probe":
            selected_ids.add(
                _expect_string(step.get("ledger_row_id"), f"manifest.steps[{index}].ledger_row_id")
            )
    for index, event_value in enumerate(_expect_list(manifest.get("events"), "manifest.events")):
        event = _expect_dict(event_value, f"manifest.events[{index}]")
        selected_ids.add(
            _expect_string(event.get("ledger_row_id"), f"manifest.events[{index}].ledger_row_id")
        )
    ledger_rows, _type_names = _ledger_maps(ledger)
    for row_id in list(selected_ids):
        row = ledger_rows.get(row_id)
        if row is None:
            _fail("manifest", f"selected row is absent from the source ledger: {row_id}")
        owner_id = row.get("facade_owner_type_id")
        owner_contracts = [
            candidate_id
            for candidate_id, candidate in ledger_rows.items()
            if candidate.get("row_kind") == "type_contract"
            and candidate.get("facade_owner_type_id") == owner_id
        ]
        if len(owner_contracts) != 1:
            _fail("ledger", f"selected owner {owner_id!r} has {len(owner_contracts)} type contracts")
        selected_ids.add(owner_contracts[0])
    ordered_rows = [
        row for row in _expect_list(ledger.get("rows"), "ledger.rows") if row.get("row_id") in selected_ids
    ]
    if len(ordered_rows) != len(selected_ids):
        _fail("ledger", "selected-row closure was not retained exactly")
    return {
        "schema": LEDGER_SNAPSHOT_SCHEMA,
        "schema_version": 1,
        "source_ledger": {
            key: ledger_ref[key] for key in ("path", "file_sha256", "canonical_sha256")
        },
        "rows": ordered_rows,
    }


def freeze_ledger_snapshot(manifest_path: Path, output_path: Path, repo_root: Path) -> dict[str, Any]:
    manifest = _expect_dict(load_json(manifest_path), "manifest")
    ledger_ref = _expect_dict(manifest.get("ledger"), "manifest.ledger")
    if ledger_ref.get("path") != CANONICAL_LEDGER:
        _fail("manifest.ledger.path", f"must be exactly {CANONICAL_LEDGER!r}")
    expected_output = _repo_output_path(
        repo_root, ledger_ref.get("snapshot_path"), "manifest.ledger.snapshot_path"
    )
    if output_path.resolve() != expected_output.resolve():
        _fail("output", f"must be the manifest-declared snapshot path {expected_output}")
    if expected_output.exists():
        _fail("output", "refusing to overwrite an existing ledger snapshot")
    ledger_path = _resolve_repo_path(repo_root, ledger_ref.get("path"), "manifest.ledger.path")
    if ledger_ref.get("file_sha256") != sha256_file(ledger_path):
        _fail("manifest.ledger.file_sha256", "does not match the current source ledger bytes")
    ledger = _expect_dict(load_json(ledger_path), "ledger")
    if ledger_ref.get("canonical_sha256") != ledger.get("canonical_sha256"):
        _fail("manifest.ledger.canonical_sha256", "does not match the current source ledger")
    document = _build_ledger_snapshot_document(manifest, ledger)
    expected_output.parent.mkdir(parents=True, exist_ok=True)
    expected_output.write_bytes(canonical_json_bytes(document))
    return {
        "path": expected_output.relative_to(repo_root.resolve()).as_posix(),
        "sha256": sha256_file(expected_output),
        "rows": len(document["rows"]),
    }


def verify_current_ledger_snapshot(manifest_path: Path, repo_root: Path) -> dict[str, Any]:
    manifest = validate_manifest(manifest_path, repo_root)
    ledger_ref = manifest["ledger"]
    ledger_path = _resolve_repo_path(repo_root, ledger_ref["path"], "manifest.ledger.path")
    if sha256_file(ledger_path) != ledger_ref["file_sha256"]:
        _fail("manifest.ledger.file_sha256", "current source ledger bytes have changed")
    ledger = _expect_dict(load_json(ledger_path), "ledger")
    if ledger.get("canonical_sha256") != ledger_ref["canonical_sha256"]:
        _fail("manifest.ledger.canonical_sha256", "current source ledger semantics have changed")
    expected = canonical_json_bytes(_build_ledger_snapshot_document(manifest, ledger))
    snapshot_path = _resolve_repo_path(
        repo_root, ledger_ref["snapshot_path"], "manifest.ledger.snapshot_path"
    )
    if snapshot_path.read_bytes() != expected:
        _fail("manifest.ledger.snapshot_path", "snapshot differs from a fresh selected-row extraction")
    return {"rows": len(load_json(snapshot_path)["rows"])}


def _safe_capture_relative_path(value: Any, path: str) -> str:
    relative = _expect_string(value, path)
    if (
        "\\" in relative
        or re.search(r"[<>:\"|?*\x00-\x1f\x7f]", relative)
        or relative.startswith("/")
        or "//" in relative
    ):
        _fail(path, "must be a safe capture-directory-relative forward-slash path")
    parts = relative.split("/")
    superscript_digits = str.maketrans({"¹": "1", "²": "2", "³": "3"})

    def is_device_name(part: str) -> bool:
        stem = part.split(".", 1)[0].translate(superscript_digits).casefold()
        return stem in {"con", "prn", "aux", "nul", "conin$", "conout$", "clock$"} or (
            re.fullmatch(r"(?:com|lpt)[1-9]", stem) is not None
        )

    if any(
        part in {"", ".", ".."}
        or part.endswith((".", " "))
        or is_device_name(part)
        for part in parts
    ):
        _fail(path, "contains an unsafe Windows path component")
    pure = PurePosixPath(relative)
    if pure.is_absolute() or ".." in pure.parts:
        _fail(path, "must be a safe capture-directory-relative forward-slash path")
    return relative


def _artifact_path(
    repo_root: Path,
    capture_dir: Path,
    artifact: Any,
    path: str,
    *,
    must_be_inside_capture: bool = True,
) -> Path:
    artifact_path, _retained_bytes = _artifact_snapshot(
        repo_root,
        capture_dir,
        artifact,
        path,
        must_be_inside_capture=must_be_inside_capture,
        max_bytes=128 * 1024 * 1024,
    )
    return artifact_path


def _artifact_snapshot(
    repo_root: Path,
    capture_dir: Path,
    artifact: Any,
    path: str,
    *,
    must_be_inside_capture: bool = True,
    max_bytes: int,
) -> tuple[Path, bytes]:
    obj = _expect_dict(artifact, path)
    _expect_exact_keys(obj, path, ["path", "sha256"])
    if must_be_inside_capture:
        relative = _safe_capture_relative_path(obj["path"], f"{path}.path")
        pure = Path(*PurePosixPath(relative).parts)
        lexical_artifact = capture_dir / pure
        current = lexical_artifact
        while True:
            if current.exists() and (current.is_symlink() or current.is_junction()):
                _fail(f"{path}.path", f"reparse/symbolic artifact path is forbidden: {current}")
            if current == capture_dir or current.parent == current:
                break
            current = current.parent
        artifact_path = lexical_artifact.resolve()
        try:
            artifact_path.relative_to(capture_dir.resolve())
        except ValueError:
            _fail(f"{path}.path", "generated artifact escapes the capture directory")
        if not artifact_path.is_file() or artifact_path.stat().st_nlink != 1:
            _fail(f"{path}.path", "generated artifact must be a real file")
    else:
        artifact_path = _resolve_repo_path(repo_root, obj["path"], f"{path}.path")
    expected = _expect_string(obj["sha256"], f"{path}.sha256")
    if not SHA256_RE.fullmatch(expected):
        _fail(f"{path}.sha256", "must be lowercase SHA-256")
    retained_bytes = _read_bound_file(
        artifact_path,
        path,
        expected_sha256=expected,
        max_bytes=max_bytes,
    )
    return artifact_path, retained_bytes


def _int_from_capture(value: Any, path: str) -> int:
    if type(value) is int:
        return value
    if type(value) is str and re.fullmatch(r"(?:0|[1-9][0-9]*|-[1-9][0-9]*)", value):
        return int(value)
    _fail(path, "must be an integer or canonical integer string")
    raise AssertionError


def _png_dimensions(
    path: Path, *, retained_bytes: bytes | None = None
) -> tuple[int, int]:
    max_file_bytes = 16 * 1024 * 1024
    if retained_bytes is None:
        with path.open("rb") as stream:
            raw = stream.read(max_file_bytes + 1)
    else:
        raw = retained_bytes
    if len(raw) > max_file_bytes:
        raise OracleValidationError(f"PNG exceeds the 16 MiB evidence cap: {path}")
    if len(raw) < 45 or raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise OracleValidationError(f"Invalid PNG signature/length: {path}")
    offset = 8
    chunk_index = 0
    width = height = 0
    saw_ihdr = False
    saw_plte = False
    saw_idat = False
    saw_iend = False
    idat_closed = False
    compressed = bytearray()
    while offset < len(raw):
        if offset + 12 > len(raw):
            raise OracleValidationError(f"Truncated PNG chunk header: {path}")
        length = struct.unpack(">I", raw[offset : offset + 4])[0]
        chunk_type = raw[offset + 4 : offset + 8]
        if (
            re.fullmatch(rb"[A-Za-z]{4}", chunk_type) is None
            or 97 <= chunk_type[2] <= 122
            or (65 <= chunk_type[0] <= 90 and chunk_type not in {b"IHDR", b"PLTE", b"IDAT", b"IEND"})
        ):
            raise OracleValidationError(f"PNG has an invalid/unknown critical chunk: {path}")
        data_start = offset + 8
        data_end = data_start + length
        crc_end = data_end + 4
        if crc_end > len(raw):
            raise OracleValidationError(f"Truncated PNG chunk payload: {path}")
        expected_crc = struct.unpack(">I", raw[data_end:crc_end])[0]
        actual_crc = zlib.crc32(chunk_type + raw[data_start:data_end]) & 0xFFFFFFFF
        if expected_crc != actual_crc:
            raise OracleValidationError(f"PNG chunk CRC mismatch: {path}")
        if chunk_index == 0 and chunk_type != b"IHDR":
            raise OracleValidationError(f"PNG IHDR must be first: {path}")
        if saw_idat and chunk_type != b"IDAT":
            idat_closed = True
        if chunk_type == b"IHDR":
            if saw_ihdr or length != 13:
                raise OracleValidationError(f"Invalid duplicate/length PNG IHDR: {path}")
            width, height = struct.unpack(">II", raw[data_start : data_start + 8])
            bit_depth = raw[data_start + 8]
            color_type = raw[data_start + 9]
            compression, filtering, interlace = raw[data_start + 10 : data_start + 13]
            if (
                width <= 0
                or height <= 0
                or width > 8192
                or height > 8192
                or width * height > 16_000_000
                or bit_depth != 8
                or color_type != 6
                or compression != 0
                or filtering != 0
                or interlace != 0
            ):
                raise OracleValidationError(f"Invalid PNG IHDR fields: {path}")
            saw_ihdr = True
        elif chunk_type == b"IDAT":
            if not saw_ihdr or saw_iend or idat_closed:
                raise OracleValidationError(f"Invalid PNG IDAT ordering: {path}")
            saw_idat = True
            compressed.extend(raw[data_start:data_end])
        elif chunk_type == b"PLTE":
            if (
                not saw_ihdr
                or saw_plte
                or saw_idat
                or length == 0
                or length > 768
                or length % 3
            ):
                raise OracleValidationError(f"Invalid PNG PLTE ordering/length: {path}")
            saw_plte = True
        elif chunk_type == b"IEND":
            if length != 0 or saw_iend:
                raise OracleValidationError(f"Invalid PNG IEND: {path}")
            saw_iend = True
            if crc_end != len(raw):
                raise OracleValidationError(f"PNG contains trailing bytes after IEND: {path}")
        offset = crc_end
        chunk_index += 1
    if not (saw_ihdr and saw_idat and saw_iend):
        raise OracleValidationError(f"PNG is missing required chunks: {path}")
    scanline_length = 1 + (width * 4)
    expected_decoded_length = height * scanline_length
    if expected_decoded_length > 64 * 1024 * 1024:
        raise OracleValidationError(f"PNG decoded pixels exceed the evidence cap: {path}")
    try:
        decompressor = zlib.decompressobj()
        decoded = decompressor.decompress(
            bytes(compressed), expected_decoded_length + 1
        )
        if len(decoded) > expected_decoded_length or decompressor.unconsumed_tail:
            raise OracleValidationError(
                f"PNG IDAT expands beyond its declared pixel dimensions: {path}"
            )
    except zlib.error as exc:
        raise OracleValidationError(f"PNG IDAT zlib stream is invalid: {path}: {exc}") from exc
    if not decompressor.eof or decompressor.unused_data or decompressor.unconsumed_tail:
        raise OracleValidationError(f"PNG IDAT zlib stream has an invalid/trailing payload: {path}")
    if len(decoded) != expected_decoded_length:
        raise OracleValidationError(
            f"PNG decoded scanlines have length {len(decoded)}, expected {expected_decoded_length}: {path}"
        )
    previous = bytearray(width * 4)
    distinct_colors: set[tuple[int, int, int]] = set()
    min_luma = 255
    max_luma = 0
    nonopaque_pixels = 0

    def paeth(left: int, above: int, upper_left: int) -> int:
        estimate = left + above - upper_left
        left_distance = abs(estimate - left)
        above_distance = abs(estimate - above)
        upper_left_distance = abs(estimate - upper_left)
        if left_distance <= above_distance and left_distance <= upper_left_distance:
            return left
        if above_distance <= upper_left_distance:
            return above
        return upper_left

    for row in range(height):
        row_start = row * scanline_length
        filter_byte = decoded[row_start]
        if filter_byte > 4:
            raise OracleValidationError(
                f"PNG scanline {row} has invalid filter byte {filter_byte}: {path}"
            )
        filtered = decoded[row_start + 1 : row_start + scanline_length]
        reconstructed = bytearray(len(filtered))
        for index, byte in enumerate(filtered):
            left = reconstructed[index - 4] if index >= 4 else 0
            above = previous[index]
            upper_left = previous[index - 4] if index >= 4 else 0
            if filter_byte == 0:
                predictor = 0
            elif filter_byte == 1:
                predictor = left
            elif filter_byte == 2:
                predictor = above
            elif filter_byte == 3:
                predictor = (left + above) // 2
            else:
                predictor = paeth(left, above, upper_left)
            reconstructed[index] = (byte + predictor) & 0xFF
        for index in range(0, len(reconstructed), 4):
            red, green, blue, alpha = reconstructed[index : index + 4]
            if alpha != 255:
                nonopaque_pixels += 1
            color = (red, green, blue)
            if len(distinct_colors) < 8:
                distinct_colors.add(color)
            luma = (red * 299 + green * 587 + blue * 114) // 1000
            min_luma = min(min_luma, luma)
            max_luma = max(max_luma, luma)
        previous = reconstructed
    if nonopaque_pixels != 0 or len(distinct_colors) < 8 or max_luma - min_luma < 16:
        raise OracleValidationError(
            f"PNG has no credible fully opaque, visually varied window content: {path}"
        )
    return width, height


def _decompress_vba_container(data: bytes, location: str) -> bytes:
    """Strict MS-OVBA CompressedContainer decompression with evidence caps."""
    if not data or data[0] != 0x01:
        _fail("capture.artifacts.workbook", f"{location} has no compressed-container signature")
    if len(data) > 4 * 1024 * 1024:
        _fail("capture.artifacts.workbook", f"{location} is unexpectedly large")
    output = bytearray()
    position = 1
    while position < len(data):
        if position + 2 > len(data):
            _fail("capture.artifacts.workbook", f"{location} has a truncated chunk header")
        chunk_start = position
        header = struct.unpack_from("<H", data, position)[0]
        chunk_size = (header & 0x0FFF) + 3
        signature = (header >> 12) & 0x07
        compressed = (header >> 15) & 0x01
        chunk_end = chunk_start + chunk_size
        if signature != 0b011 or not 3 <= chunk_size <= 4098 or chunk_end > len(data):
            _fail("capture.artifacts.workbook", f"{location} has an invalid compressed chunk")
        position += 2
        decompressed_chunk_start = len(output)
        if compressed == 0:
            if chunk_size != 4098 or position + 4096 != chunk_end:
                _fail("capture.artifacts.workbook", f"{location} has an invalid raw chunk")
            output.extend(data[position:chunk_end])
            position = chunk_end
        else:
            while position < chunk_end:
                flags = data[position]
                position += 1
                for bit_index in range(8):
                    if position >= chunk_end:
                        break
                    if ((flags >> bit_index) & 1) == 0:
                        output.append(data[position])
                        position += 1
                    else:
                        if position + 2 > chunk_end:
                            _fail(
                                "capture.artifacts.workbook",
                                f"{location} has a truncated copy token",
                            )
                        difference = len(output) - decompressed_chunk_start
                        if difference <= 0:
                            _fail(
                                "capture.artifacts.workbook",
                                f"{location} copy token has no prior chunk bytes",
                            )
                        token = struct.unpack_from("<H", data, position)[0]
                        position += 2
                        bit_count = max(4, (difference - 1).bit_length())
                        length_mask = 0xFFFF >> bit_count
                        offset_mask = 0xFFFF ^ length_mask
                        length = (token & length_mask) + 3
                        offset = ((token & offset_mask) >> (16 - bit_count)) + 1
                        if offset > difference or difference + length > 4096:
                            _fail(
                                "capture.artifacts.workbook",
                                f"{location} has an out-of-range copy token",
                            )
                        copy_at = len(output) - offset
                        for _ in range(length):
                            output.append(output[copy_at])
                            copy_at += 1
                    if len(output) - decompressed_chunk_start > 4096:
                        _fail(
                            "capture.artifacts.workbook",
                            f"{location} expands beyond one 4096-byte chunk",
                        )
        if len(output) > 8 * 1024 * 1024:
            _fail("capture.artifacts.workbook", f"{location} expands beyond the evidence cap")
    return bytes(output)


def _vba_project_code_page(decompressed_dir: bytes) -> int:
    """Read PROJECTCODEPAGE from the fixed ProjectInformation prefix."""
    position = 0

    def take_record(expected_id: int, expected_size: int) -> bytes:
        nonlocal position
        if position + 6 > len(decompressed_dir):
            _fail(
                "capture.artifacts.workbook",
                "VBA dir stream has a truncated ProjectInformation record",
            )
        record_id, record_size = struct.unpack_from("<HI", decompressed_dir, position)
        position += 6
        if record_id != expected_id or record_size != expected_size:
            _fail(
                "capture.artifacts.workbook",
                "VBA dir stream has an invalid ProjectInformation record sequence",
            )
        if position + record_size > len(decompressed_dir):
            _fail(
                "capture.artifacts.workbook",
                "VBA dir stream has truncated ProjectInformation data",
            )
        value = decompressed_dir[position : position + record_size]
        position += record_size
        return value

    take_record(0x0001, 4)  # PROJECTSYSKIND
    if position + 2 <= len(decompressed_dir) and struct.unpack_from(
        "<H", decompressed_dir, position
    )[0] == 0x004A:
        take_record(0x004A, 4)  # PROJECTCOMPATVERSION (optional)
    take_record(0x0002, 4)  # PROJECTLCID
    take_record(0x0014, 4)  # PROJECTLCIDINVOKE
    code_page = struct.unpack("<H", take_record(0x0003, 2))[0]
    if code_page == 0:
        _fail("capture.artifacts.workbook", "VBA PROJECTCODEPAGE must be nonzero")
    try:
        "".encode(f"cp{code_page}")
    except LookupError as exc:
        _fail(
            "capture.artifacts.workbook",
            f"VBA PROJECTCODEPAGE {code_page} is not supported: {exc}",
        )
    return code_page


def _vba_module_records(decompressed_dir: bytes) -> dict[str, dict[str, Any]]:
    """Parse the complete PROJECTMODULES tail of a decompressed dir stream."""
    codec = f"cp{_vba_project_code_page(decompressed_dir)}"
    marker = struct.pack("<HI", 0x000F, 2)
    marker_positions = [
        position
        for position in range(0, len(decompressed_dir) - len(marker) + 1)
        if decompressed_dir.startswith(marker, position)
    ]
    if len(marker_positions) != 1:
        _fail(
            "capture.artifacts.workbook",
            "VBA dir stream must contain exactly one PROJECTMODULES record",
        )
    position = marker_positions[0] + len(marker)

    def take(count: int, label: str, *, cap: int = 1024) -> bytes:
        nonlocal position
        if count < 0 or count > cap or position + count > len(decompressed_dir):
            _fail(
                "capture.artifacts.workbook",
                f"VBA dir stream has truncated/oversized {label}",
            )
        value = decompressed_dir[position : position + count]
        position += count
        return value

    def take_u16(label: str) -> int:
        return struct.unpack("<H", take(2, label, cap=2))[0]

    def take_u32(label: str) -> int:
        return struct.unpack("<I", take(4, label, cap=4))[0]

    def take_header(expected_id: int, expected_size: int, label: str) -> None:
        if take_u16(f"{label} id") != expected_id or take_u32(
            f"{label} size"
        ) != expected_size:
            _fail(
                "capture.artifacts.workbook",
                f"VBA dir stream has an invalid {label} record",
            )

    module_count = take_u16("PROJECTMODULES count")
    if not 1 <= module_count <= 64:
        _fail(
            "capture.artifacts.workbook",
            "VBA dir stream has an invalid PROJECTMODULES count",
        )
    take_header(0x0013, 2, "PROJECTCOOKIE")
    take_u16("PROJECTCOOKIE value")

    records: dict[str, dict[str, Any]] = {}
    folded_names: set[str] = set()
    folded_stream_names: set[str] = set()

    def take_text_record(
        expected_id: int,
        label: str,
        encoding: str,
        *,
        unicode_text: bool = False,
    ) -> str:
        if take_u16(f"{label} id") != expected_id:
            _fail(
                "capture.artifacts.workbook",
                f"VBA dir stream is missing a {label} record",
            )
        length = take_u32(f"{label} length")
        if unicode_text and length % 2:
            _fail(
                "capture.artifacts.workbook",
                f"VBA dir stream has an odd UTF-16 length for {label}",
            )
        try:
            return take(length, label).decode(encoding, "strict")
        except UnicodeDecodeError as exc:
            _fail(
                "capture.artifacts.workbook",
                f"VBA dir stream cannot decode {label}: {exc}",
            )

    for _index in range(module_count):
        module_name = take_text_record(0x0019, "MODULENAME", codec)
        unicode_module_name = take_text_record(
            0x0047, "MODULENAMEUNICODE", "utf-16-le", unicode_text=True
        )
        if unicode_module_name != module_name:
            _fail(
                "capture.artifacts.workbook",
                "VBA dir stream has a mismatched MODULENAME Unicode mirror",
            )
        stream_name = take_text_record(0x001A, "MODULESTREAMNAME", codec)
        unicode_stream_name = take_text_record(
            0x0032,
            "MODULESTREAMNAMEUNICODE",
            "utf-16-le",
            unicode_text=True,
        )
        if unicode_stream_name != stream_name:
            _fail(
                "capture.artifacts.workbook",
                "VBA dir stream has a mismatched MODULESTREAMNAME Unicode mirror",
            )
        docstring = take_text_record(0x001C, "MODULEDOCSTRING", codec)
        unicode_docstring = take_text_record(
            0x0048,
            "MODULEDOCSTRINGUNICODE",
            "utf-16-le",
            unicode_text=True,
        )
        if unicode_docstring != docstring:
            _fail(
                "capture.artifacts.workbook",
                "VBA dir stream has a mismatched MODULEDOCSTRING Unicode mirror",
            )
        take_header(0x0031, 4, "MODULEOFFSET")
        text_offset = take_u32("MODULEOFFSET value")
        take_header(0x001E, 4, "MODULEHELPCONTEXT")
        take_u32("MODULEHELPCONTEXT value")
        take_header(0x002C, 2, "MODULECOOKIE")
        take_u16("MODULECOOKIE value")

        module_type_id = take_u16("module type id")
        module_type_size = take_u32("module type size")
        if module_type_id not in {0x0021, 0x0022} or module_type_size != 0:
            _fail(
                "capture.artifacts.workbook",
                "VBA dir stream has an invalid module type record",
            )
        flags: set[int] = set()
        last_flag = 0
        while True:
            record_id = take_u16("module flag/terminator id")
            record_size = take_u32("module flag/terminator size")
            if record_id == 0x002B:
                if record_size != 0:
                    _fail(
                        "capture.artifacts.workbook",
                        "VBA dir stream has an invalid MODULETERMINATOR",
                    )
                break
            if (
                record_id not in {0x0025, 0x0028}
                or record_size != 0
                or record_id in flags
                or record_id <= last_flag
            ):
                _fail(
                    "capture.artifacts.workbook",
                    "VBA dir stream has invalid module flags",
                )
            flags.add(record_id)
            last_flag = record_id

        identifier = r"[A-Za-z_][A-Za-z0-9_]*"
        if (
            re.fullmatch(identifier, module_name) is None
            or re.fullmatch(identifier, stream_name) is None
            or module_name != stream_name
        ):
            _fail(
                "capture.artifacts.workbook",
                "VBA dir stream has a noncanonical module/stream name",
            )
        folded_name = module_name.casefold()
        folded_stream_name = stream_name.casefold()
        if folded_name in folded_names or folded_stream_name in folded_stream_names:
            _fail(
                "capture.artifacts.workbook",
                "VBA dir stream has duplicate/colliding module records",
            )
        folded_names.add(folded_name)
        folded_stream_names.add(folded_stream_name)
        records[module_name] = {
            "stream_name": stream_name,
            "text_offset": text_offset,
            "module_type": "procedural" if module_type_id == 0x0021 else "document",
            "read_only": 0x0025 in flags,
            "private": 0x0028 in flags,
        }

    take_header(0x0010, 0, "PROJECTTERMINATOR")
    if position != len(decompressed_dir):
        _fail(
            "capture.artifacts.workbook",
            "VBA dir stream has trailing bytes after PROJECTTERMINATOR",
        )
    return records


def _vba_module_record(
    decompressed_dir: bytes, module_name: str
) -> tuple[str, int]:
    record = _vba_module_records(decompressed_dir).get(module_name)
    if record is None:
        _fail(
            "capture.artifacts.workbook",
            f"VBA dir stream has no module record for {module_name!r}",
        )
    return record["stream_name"], record["text_offset"]


def _validate_vba_project_sources(
    vba_cfb: Any,
    expected_sources: dict[str, tuple[str, str]],
) -> None:
    try:
        decompressed_dir = _decompress_vba_container(
            vba_cfb.read_stream("/VBA/dir"), "VBA dir stream"
        )
        codec = f"cp{_vba_project_code_page(decompressed_dir)}"
        project_text = vba_cfb.read_stream("/PROJECT").decode(codec, "strict")
    except (KeyError, LookupError, UnicodeDecodeError) as exc:
        _fail("capture.artifacts.workbook", f"cannot read VBA project metadata: {exc}")

    expected_names: set[str] = set()
    expected_declarations: set[tuple[str, str]] = set()
    for module_name, (declaration_kind, _expected_source) in expected_sources.items():
        if declaration_kind not in {"Module", "BaseClass"}:
            raise AssertionError(declaration_kind)
        folded_name = module_name.casefold()
        if folded_name in expected_names:
            raise AssertionError(f"duplicate expected VBA module name: {module_name}")
        expected_names.add(folded_name)
        expected_declarations.add((declaration_kind, module_name))

    normalized_project_lines = (
        project_text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    )
    declarations: list[tuple[str, str]] = []
    in_project_header = True
    for line in normalized_project_lines:
        if line.startswith("["):
            in_project_header = False
            continue
        match = re.fullmatch(r"(Document|Module|Class|BaseClass)=(.+)", line)
        if match is None:
            continue
        if not in_project_header:
            _fail(
                "capture.artifacts.workbook",
                "VBA PROJECT stream has a module declaration outside its main header",
            )
        declaration_kind, raw_name = match.groups()
        if declaration_kind == "Document":
            document_match = re.fullmatch(
                r"([A-Za-z_][A-Za-z0-9_]*)/&H00000000", raw_name
            )
            if document_match is None:
                _fail(
                    "capture.artifacts.workbook",
                    f"VBA PROJECT stream has an invalid Document declaration: {line}",
                )
            module_name = document_match.group(1)
        else:
            if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", raw_name) is None:
                _fail(
                    "capture.artifacts.workbook",
                    f"VBA PROJECT stream has an invalid module declaration: {line}",
                )
            module_name = raw_name
        declarations.append((declaration_kind, module_name))

    if not declarations:
        _fail("capture.artifacts.workbook", "VBA PROJECT stream declares no modules")
    folded_declarations = [name.casefold() for _kind, name in declarations]
    if len(folded_declarations) != len(set(folded_declarations)):
        _fail(
            "capture.artifacts.workbook",
            "VBA PROJECT stream has duplicate/colliding module declarations",
        )
    actual_expected_declarations = {
        declaration
        for declaration in declarations
        if declaration[0] != "Document"
    }
    if actual_expected_declarations != expected_declarations:
        _fail(
            "capture.artifacts.workbook",
            "VBA PROJECT executable module declarations do not exactly match deterministic generation",
        )
    document_declarations = [
        declaration for declaration in declarations if declaration[0] == "Document"
    ]
    if not document_declarations:
        _fail(
            "capture.artifacts.workbook",
            "VBA PROJECT stream must declare its host document modules",
        )
    module_records = _vba_module_records(decompressed_dir)
    declared_module_names = {name for _kind, name in declarations}
    if set(module_records) != declared_module_names:
        _fail(
            "capture.artifacts.workbook",
            "VBA dir module records do not exactly match PROJECT declarations",
        )

    resolved_stream_paths: set[str] = set()
    workbook_document_count = 0
    worksheet_document_count = 0
    guid = r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
    form_base_pattern = re.compile(rf'"0\{{{guid}\}}\{{{guid}\}}"')

    for declaration_kind, module_name in declarations:
        expected_source = (
            expected_sources[module_name][1]
            if declaration_kind != "Document"
            else None
        )
        expected_kind = (
            expected_sources[module_name][0]
            if declaration_kind != "Document"
            else "Document"
        )
        if expected_kind != declaration_kind:
            _fail(
                "capture.artifacts.workbook",
                f"VBA PROJECT stream has an unexpected declaration kind for {module_name!r}",
            )
        module_record = module_records[module_name]
        expected_record_shape = {
            "Module": ("procedural", False),
            "BaseClass": ("document", True),
            "Document": ("document", False),
        }[declaration_kind]
        if (
            module_record["module_type"] != expected_record_shape[0]
            or module_record["private"] is not expected_record_shape[1]
            or module_record["read_only"] is not False
        ):
            _fail(
                "capture.artifacts.workbook",
                f"VBA dir module flags/type do not match {declaration_kind}={module_name}",
            )
        stream_name = module_record["stream_name"]
        text_offset = module_record["text_offset"]
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", stream_name) is None:
            _fail(
                "capture.artifacts.workbook",
                f"VBA module {module_name!r} has an invalid stream name",
            )
        stream_path = f"/VBA/{stream_name}"
        folded_stream_path = stream_path.casefold()
        if folded_stream_path in resolved_stream_paths:
            _fail(
                "capture.artifacts.workbook",
                "VBA module declarations resolve to duplicate/colliding streams",
            )
        resolved_stream_paths.add(folded_stream_path)
        try:
            module_stream = vba_cfb.read_stream(stream_path)
        except KeyError:
            _fail(
                "capture.artifacts.workbook",
                f"VBA module stream is missing: {stream_path}",
            )
        if text_offset >= len(module_stream):
            _fail(
                "capture.artifacts.workbook",
                f"VBA module {module_name!r} has an out-of-range source offset",
            )
        source_bytes = _decompress_vba_container(
            module_stream[text_offset:], f"VBA module {module_name!r} source"
        )
        try:
            actual_source = source_bytes.decode(codec, "strict")
        except UnicodeDecodeError as exc:
            _fail(
                "capture.artifacts.workbook",
                f"VBA module {module_name!r} source is not valid {codec}: {exc}",
            )
        actual_lines = actual_source.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        attribute_lines: list[str] = []
        while actual_lines and actual_lines[0].startswith("Attribute "):
            attribute_lines.append(actual_lines.pop(0))
        attributes: dict[str, str] = {}
        for attribute_line in attribute_lines:
            match = re.fullmatch(r"Attribute ([A-Za-z_][A-Za-z0-9_]*) = (.+)", attribute_line)
            if match is None or match.group(1) in attributes:
                _fail(
                    "capture.artifacts.workbook",
                    f"VBA module {module_name!r} has invalid/duplicate attributes",
                )
            attributes[match.group(1)] = match.group(2)
        if attributes.get("VB_Name") != f'"{module_name}"':
            _fail(
                "capture.artifacts.workbook",
                f"VBA module {module_name!r} has a mismatched VB_Name attribute",
            )
        if declaration_kind == "Module":
            if set(attributes) != {"VB_Name"}:
                _fail(
                    "capture.artifacts.workbook",
                    f"standard module {module_name!r} has unexpected persisted attributes",
                )
        elif declaration_kind == "BaseClass":
            expected_form_attributes = {
                "VB_GlobalNameSpace": "False",
                "VB_Creatable": "False",
                "VB_PredeclaredId": "True",
                "VB_Exposed": "False",
                "VB_TemplateDerived": "False",
                "VB_Customizable": "False",
            }
            if set(attributes) != {
                "VB_Name",
                "VB_Base",
                *expected_form_attributes,
            } or any(
                attributes.get(name) != value
                for name, value in expected_form_attributes.items()
            ) or form_base_pattern.fullmatch(attributes.get("VB_Base", "")) is None:
                _fail(
                    "capture.artifacts.workbook",
                    f"UserForm module {module_name!r} has unexpected persisted attributes",
                )
        else:
            expected_document_attributes = {
                "VB_GlobalNameSpace": "False",
                "VB_Creatable": "False",
                "VB_PredeclaredId": "True",
                "VB_Exposed": "True",
                "VB_TemplateDerived": "False",
                "VB_Customizable": "True",
            }
            base = attributes.get("VB_Base")
            if base == '"0{00020819-0000-0000-C000-000000000046}"':
                workbook_document_count += 1
            elif base == '"0{00020820-0000-0000-C000-000000000046}"':
                worksheet_document_count += 1
            else:
                _fail(
                    "capture.artifacts.workbook",
                    f"host document module {module_name!r} has an unexpected VB_Base",
                )
            if set(attributes) != {
                "VB_Name",
                "VB_Base",
                *expected_document_attributes,
            } or any(
                attributes.get(name) != value
                for name, value in expected_document_attributes.items()
            ):
                _fail(
                    "capture.artifacts.workbook",
                    f"host document module {module_name!r} has unexpected persisted attributes",
                )
            if actual_lines != [""]:
                _fail(
                    "capture.artifacts.workbook",
                    f"host document module {module_name!r} must have an empty source body",
                )

        if expected_source is not None:
            normalized_actual = "\n".join(actual_lines)
            normalized_expected = expected_source.replace("\r\n", "\n").replace(
                "\r", "\n"
            )
            if normalized_actual == normalized_expected + "\n":
                normalized_actual = normalized_actual[:-1]
            if normalized_actual != normalized_expected:
                _fail(
                    "capture.artifacts.workbook",
                    f"VBA module {module_name!r} source does not match deterministic generation",
                )

    if workbook_document_count != 1 or worksheet_document_count < 1:
        _fail(
            "capture.artifacts.workbook",
            "VBA project must have exactly one empty workbook module and at least one empty worksheet module",
        )

    vba_descendants = [
        entry
        for entry in vba_cfb.to_dict().get("entries", [])
        if entry.get("path", "").casefold().startswith("/vba/")
    ]
    if any(
        entry.get("type") != "stream"
        or re.fullmatch(r"/VBA/[^/]+", entry.get("path", "")) is None
        for entry in vba_descendants
    ):
        _fail(
            "capture.artifacts.workbook",
            "VBA storage contains an unexpected nested entry",
        )
    direct_vba_stream_paths = [
        entry.get("path", "").casefold() for entry in vba_descendants
    ]
    if len(direct_vba_stream_paths) != len(set(direct_vba_stream_paths)):
        _fail(
            "capture.artifacts.workbook",
            "VBA storage contains duplicate/colliding stream paths",
        )
    direct_vba_streams = set(direct_vba_stream_paths)
    cache_indexes = sorted(
        int(match.group(1))
        for path in direct_vba_streams
        if (match := re.fullmatch(r"/vba/__srp_([0-9]+)", path)) is not None
    )
    if cache_indexes != list(range(len(cache_indexes))):
        _fail(
            "capture.artifacts.workbook",
            "VBA compiled-cache stream numbering is noncanonical",
        )
    system_streams = {
        path
        for path in direct_vba_streams
        if path in {"/vba/_vba_project", "/vba/dir"}
        or re.fullmatch(r"/vba/__srp_[0-9]+", path) is not None
    }
    module_streams = direct_vba_streams - system_streams
    if module_streams != resolved_stream_paths:
        _fail(
            "capture.artifacts.workbook",
            "VBA storage module streams do not exactly match PROJECT declarations",
        )


def _validate_xlsm_package(
    path: Path,
    result_sheet: str,
    event_sheet: str,
    expected_dimensions: dict[str, tuple[int, int]],
    expected_vba_sources: dict[str, tuple[str, str]],
    cfb_module: Any,
    *,
    preopen: bool = False,
    expected_package_sha256: str | None = None,
    retained_package_bytes: bytes | None = None,
) -> dict[str, list[list[str]]]:
    if path.suffix.casefold() != ".xlsm":
        _fail("capture.artifacts.workbook", "must have an .xlsm extension")
    try:
        if retained_package_bytes is None:
            with path.open("rb") as package_stream:
                package_bytes = package_stream.read((64 * 1024 * 1024) + 1)
        else:
            package_bytes = retained_package_bytes
        if len(package_bytes) > 64 * 1024 * 1024:
            _fail(
                "capture.artifacts.workbook",
                "OOXML package file is unexpectedly large",
            )
        package_sha256 = sha256_bytes(package_bytes)
        if expected_package_sha256 is not None:
            if not SHA256_RE.fullmatch(expected_package_sha256):
                raise AssertionError("expected_package_sha256 must be lowercase SHA-256")
            if package_sha256 != expected_package_sha256:
                _fail(
                    "capture.artifacts.workbook",
                    "package bytes changed after their pre-validation identity was pinned",
                )
        with zipfile.ZipFile(io.BytesIO(package_bytes), "r") as package:
            infos = package.infolist()
            names = [info.filename for info in infos]
            if len(names) != len(set(names)):
                _fail("capture.artifacts.workbook", "OOXML package has duplicate entries")
            info_by_name = {info.filename: info for info in infos}
            total_uncompressed = 0
            for info in infos:
                pure = Path(info.filename)
                if (
                    "\\" in info.filename
                    or info.filename.startswith("/")
                    or pure.is_absolute()
                    or ".." in pure.parts
                    or info.flag_bits & 0x1
                ):
                    _fail("capture.artifacts.workbook", f"unsafe/encrypted OOXML entry: {info.filename}")
                total_uncompressed += info.file_size
                if info.file_size > 32 * 1024 * 1024:
                    _fail("capture.artifacts.workbook", f"oversized OOXML entry: {info.filename}")
            if total_uncompressed > 64 * 1024 * 1024:
                _fail("capture.artifacts.workbook", "OOXML package is unexpectedly large")
            required = {
                "[Content_Types].xml",
                "_rels/.rels",
                "xl/workbook.xml",
                "xl/_rels/workbook.xml.rels",
                "xl/vbaProject.bin",
            }
            missing = sorted(required - set(names))
            if missing:
                _fail("capture.artifacts.workbook", f"missing OOXML/VBA entries: {missing}")
            bad_crc = package.testzip()
            if bad_crc is not None:
                _fail("capture.artifacts.workbook", f"OOXML CRC failure: {bad_crc}")

            def read_xml_part(
                entry: str, expected_root_tag: str, *, max_bytes: int = 2 * 1024 * 1024
            ) -> ElementTree.Element:
                info = info_by_name.get(entry)
                if info is None:
                    _fail("capture.artifacts.workbook", f"missing XML part: {entry}")
                if info.file_size > max_bytes:
                    _fail(
                        "capture.artifacts.workbook",
                        f"evidence XML part is oversized: {entry}",
                    )
                raw = package.read(entry)
                if re.search(br"(?i)<!DOCTYPE|<!ENTITY", raw):
                    _fail(
                        "capture.artifacts.workbook",
                        f"DTD/entity declarations are forbidden in evidence XML: {entry}",
                    )
                root = ElementTree.fromstring(raw)
                if root.tag != expected_root_tag:
                    _fail(
                        "capture.artifacts.workbook",
                        f"XML part {entry} has unexpected root/namespace {root.tag!r}",
                    )
                return root

            def relationship_target(target: str, base: PurePosixPath) -> str:
                if (
                    not re.fullmatch(r"/?[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*", target)
                    or "\\" in target
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        f"unsafe OOXML relationship target: {target}",
                    )
                pure_target = PurePosixPath(target)
                if ".." in pure_target.parts:
                    _fail(
                        "capture.artifacts.workbook",
                        f"unsafe OOXML relationship target: {target}",
                    )
                return (
                    pure_target.as_posix().lstrip("/")
                    if target.startswith("/")
                    else (base / pure_target).as_posix()
                )

            content_types = read_xml_part(
                "[Content_Types].xml", f"{{{CONTENT_TYPES_NS}}}Types"
            )
            overrides: dict[str | None, str | None] = {}
            defaults: dict[str, str | None] = {}
            for node in content_types:
                if len(node) != 0:
                    _fail(
                        "capture.artifacts.workbook",
                        "content-type records must not contain child elements",
                    )
                if node.tag == f"{{{CONTENT_TYPES_NS}}}Override":
                    if set(node.attrib) != {"PartName", "ContentType"}:
                        _fail(
                            "capture.artifacts.workbook",
                            "content-type override must have exactly PartName and ContentType",
                        )
                    part_name = node.attrib.get("PartName")
                    content_type = node.attrib.get("ContentType")
                    if (
                        not part_name
                        or not content_type
                        or not part_name.startswith("/")
                        or relationship_target(part_name, PurePosixPath(""))
                        not in names
                    ):
                        _fail(
                            "capture.artifacts.workbook",
                            f"content-type override does not bind one existing safe part: {part_name}",
                        )
                    if part_name in overrides:
                        _fail(
                            "capture.artifacts.workbook",
                            f"duplicate OOXML content-type override: {part_name}",
                        )
                    overrides[part_name] = content_type
                elif node.tag == f"{{{CONTENT_TYPES_NS}}}Default":
                    if set(node.attrib) != {"Extension", "ContentType"}:
                        _fail(
                            "capture.artifacts.workbook",
                            "default content type must have exactly Extension and ContentType",
                        )
                    extension = (node.attrib.get("Extension") or "").casefold()
                    content_type = node.attrib.get("ContentType")
                    if (
                        re.fullmatch(r"[A-Za-z0-9]+", extension) is None
                        or not content_type
                    ):
                        _fail(
                            "capture.artifacts.workbook",
                            "default content type has an invalid extension or empty ContentType",
                        )
                    if extension in defaults:
                        _fail(
                            "capture.artifacts.workbook",
                            f"duplicate OOXML default content type: {extension}",
                        )
                    defaults[extension] = content_type
                else:
                    _fail(
                        "capture.artifacts.workbook",
                        f"unexpected content-type element: {node.tag!r}",
                    )
            if overrides.get("/xl/workbook.xml") != "application/vnd.ms-excel.sheet.macroEnabled.main+xml":
                _fail("capture.artifacts.workbook", "workbook is not macro-enabled OOXML")
            vba_content_type = overrides.get(
                "/xl/vbaProject.bin", defaults.get("bin")
            )
            if vba_content_type != "application/vnd.ms-office.vbaProject":
                _fail("capture.artifacts.workbook", "vbaProject.bin content type is missing")

            root_relationships = read_xml_part(
                "_rels/.rels", f"{{{PACKAGE_REL_NS}}}Relationships"
            )
            root_relationship_ids: set[str] = set()
            office_document_targets: list[str] = []
            root_relationship_types: list[str] = []
            root_relationship_targets: set[str] = set()
            root_relationship_records: list[tuple[str, str]] = []
            for node in root_relationships:
                if (
                    node.tag != f"{{{PACKAGE_REL_NS}}}Relationship"
                    or len(node) != 0
                    or not set(node.attrib).issubset(
                        {"Id", "Type", "Target", "TargetMode"}
                    )
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        f"unexpected package-relationship element: {node.tag!r}",
                    )
                relationship_id = node.attrib.get("Id")
                relationship_type = node.attrib.get("Type")
                target = node.attrib.get("Target")
                if not relationship_id or not relationship_type or not target:
                    _fail(
                        "capture.artifacts.workbook",
                        "package relationship is missing Id, Type, or Target",
                    )
                if relationship_id in root_relationship_ids:
                    _fail(
                        "capture.artifacts.workbook",
                        f"duplicate package relationship id: {relationship_id}",
                    )
                root_relationship_ids.add(relationship_id)
                root_relationship_types.append(relationship_type)
                if node.attrib.get("TargetMode", "Internal") != "Internal":
                    _fail(
                        "capture.artifacts.workbook",
                        f"external package relationship is forbidden: {relationship_id}",
                    )
                target_entry = relationship_target(target, PurePosixPath(""))
                if target_entry not in names:
                    _fail(
                        "capture.artifacts.workbook",
                        f"package relationship target is missing: {target_entry}",
                    )
                if target_entry in root_relationship_targets:
                    _fail(
                        "capture.artifacts.workbook",
                        f"package relationships alias one target: {target_entry}",
                    )
                root_relationship_targets.add(target_entry)
                root_relationship_records.append((relationship_type, target_entry))
                if relationship_type == f"{OFFICE_REL_NS}/officeDocument":
                    office_document_targets.append(target_entry)
            allowed_root_relationships = {
                f"{OFFICE_REL_NS}/officeDocument",
                "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties",
                f"{OFFICE_REL_NS}/extended-properties",
                f"{OFFICE_REL_NS}/custom-properties",
            }
            if any(
                relationship_type not in allowed_root_relationships
                for relationship_type in root_relationship_types
            ) or any(
                root_relationship_types.count(relationship_type) > 1
                for relationship_type in allowed_root_relationships
            ):
                _fail(
                    "capture.artifacts.workbook",
                    "package root relationships are not the closed Office document/property graph",
                )
            expected_root_targets = {
                "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties": (
                    "docProps/core.xml",
                    "application/vnd.openxmlformats-package.core-properties+xml",
                ),
                f"{OFFICE_REL_NS}/extended-properties": (
                    "docProps/app.xml",
                    "application/vnd.openxmlformats-officedocument.extended-properties+xml",
                ),
                f"{OFFICE_REL_NS}/custom-properties": (
                    "docProps/custom.xml",
                    "application/vnd.openxmlformats-officedocument.custom-properties+xml",
                ),
            }
            for relationship_type, target_entry in root_relationship_records:
                expected_root_target = expected_root_targets.get(relationship_type)
                if expected_root_target is None:
                    continue
                expected_target, expected_content_type = expected_root_target
                extension = PurePosixPath(target_entry).suffix.lstrip(".").casefold()
                actual_content_type = overrides.get(
                    "/" + target_entry, defaults.get(extension)
                )
                if (
                    target_entry != expected_target
                    or actual_content_type != expected_content_type
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        f"package property relationship {relationship_type!r} does not bind its exact canonical part/type",
                    )
            if office_document_targets != ["xl/workbook.xml"]:
                _fail(
                    "capture.artifacts.workbook",
                    "package relationships do not bind exactly one xl/workbook.xml officeDocument",
                )
            vba_project = package.read("xl/vbaProject.bin")
            try:
                vba_cfb = cfb_module.parse_cfb(
                    vba_project, signature_offset=0
                )
                vba_inventory = vba_cfb.to_dict()
            except Exception as exc:
                _fail(
                    "capture.artifacts.workbook",
                    f"vbaProject.bin is not a strict CFB container: {exc}",
                )
            vba_entries = {
                (entry.get("path"), entry.get("type"))
                for entry in vba_inventory.get("entries", [])
            }
            required_vba_entries = {
                ("/PROJECT", "stream"),
                ("/VBA", "storage"),
                ("/VBA/_VBA_PROJECT", "stream"),
                ("/VBA/dir", "stream"),
            }
            if (
                vba_inventory.get("signature_offset") != 0
                or vba_inventory.get("cfb_length") != len(vba_project)
                or not required_vba_entries.issubset(vba_entries)
            ):
                _fail(
                    "capture.artifacts.workbook",
                    "vbaProject.bin is not a complete VBA project CFB container",
                )
            _validate_vba_project_sources(vba_cfb, expected_vba_sources)
            workbook_xml = read_xml_part(
                "xl/workbook.xml", f"{{{SPREADSHEET_NS}}}workbook"
            )
            workbook_relationships = read_xml_part(
                "xl/_rels/workbook.xml.rels",
                f"{{{PACKAGE_REL_NS}}}Relationships",
            )
            relationships: dict[str, tuple[str, str]] = {}
            for node in workbook_relationships:
                if (
                    node.tag != f"{{{PACKAGE_REL_NS}}}Relationship"
                    or len(node) != 0
                    or not set(node.attrib).issubset(
                        {"Id", "Type", "Target", "TargetMode"}
                    )
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        f"unexpected workbook-relationship element: {node.tag!r}",
                    )
                relationship_id = node.attrib.get("Id")
                relationship_type = node.attrib.get("Type")
                target = node.attrib.get("Target")
                if not relationship_id or not relationship_type or not target:
                    _fail(
                        "capture.artifacts.workbook",
                        "workbook relationship is missing Id, Type, or Target",
                    )
                if relationship_id in relationships:
                    _fail(
                        "capture.artifacts.workbook",
                        f"duplicate workbook relationship id: {relationship_id}",
                    )
                if node.attrib.get("TargetMode", "Internal") != "Internal":
                    _fail(
                        "capture.artifacts.workbook",
                        f"external workbook relationship is forbidden: {relationship_id}",
                    )
                target_entry = relationship_target(target, PurePosixPath("xl"))
                if target_entry not in names:
                    _fail(
                        "capture.artifacts.workbook",
                        f"workbook relationship target is missing: {target_entry}",
                    )
                relationships[relationship_id] = (relationship_type, target_entry)

            worksheet_relationship_type = (
                "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"
            )
            allowed_workbook_relationship_types = {
                worksheet_relationship_type,
                f"{OFFICE_REL_NS}/styles",
                f"{OFFICE_REL_NS}/theme",
                f"{OFFICE_REL_NS}/sharedStrings",
                "http://schemas.microsoft.com/office/2006/relationships/vbaProject",
            }
            relationship_types = [
                relationship_type
                for relationship_type, _target in relationships.values()
            ]
            if any(
                relationship_type not in allowed_workbook_relationship_types
                for relationship_type in relationship_types
            ) or any(
                relationship_types.count(relationship_type) > 1
                for relationship_type in allowed_workbook_relationship_types
                if relationship_type != worksheet_relationship_type
            ):
                _fail(
                    "capture.artifacts.workbook",
                    "workbook relationships are not the closed worksheet/style/theme/string/VBA graph",
                )

            expected_workbook_targets = {
                f"{OFFICE_REL_NS}/styles": (
                    "xl/styles.xml",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml",
                ),
                f"{OFFICE_REL_NS}/theme": (
                    "xl/theme/theme1.xml",
                    "application/vnd.openxmlformats-officedocument.theme+xml",
                ),
                f"{OFFICE_REL_NS}/sharedStrings": (
                    "xl/sharedStrings.xml",
                    SHARED_STRINGS_CONTENT_TYPE,
                ),
                "http://schemas.microsoft.com/office/2006/relationships/vbaProject": (
                    "xl/vbaProject.bin",
                    "application/vnd.ms-office.vbaProject",
                ),
            }
            for relationship_type, target_entry in relationships.values():
                expected_workbook_target = expected_workbook_targets.get(
                    relationship_type
                )
                if expected_workbook_target is None:
                    continue
                expected_target, expected_content_type = expected_workbook_target
                extension = PurePosixPath(target_entry).suffix.lstrip(".").casefold()
                actual_content_type = overrides.get(
                    "/" + target_entry, defaults.get(extension)
                )
                if (
                    target_entry != expected_target
                    or actual_content_type != expected_content_type
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        f"workbook relationship {relationship_type!r} does not bind its exact canonical part/type",
                    )

            vba_relationships = [
                target
                for relationship_type, target in relationships.values()
                if relationship_type
                == "http://schemas.microsoft.com/office/2006/relationships/vbaProject"
            ]
            if vba_relationships != ["xl/vbaProject.bin"]:
                _fail(
                    "capture.artifacts.workbook",
                    "workbook relationships do not bind exactly one xl/vbaProject.bin",
                )

            relationship_id_attribute = f"{{{OFFICE_REL_NS}}}id"
            sheet_containers = [
                node
                for node in workbook_xml
                if node.tag == f"{{{SPREADSHEET_NS}}}sheets"
            ]
            if len(sheet_containers) != 1:
                _fail(
                    "capture.artifacts.workbook",
                    "workbook must contain exactly one direct sheets collection",
                )
            sheets = list(sheet_containers[0])
            if any(node.tag != f"{{{SPREADSHEET_NS}}}sheet" for node in sheets):
                _fail(
                    "capture.artifacts.workbook",
                    "workbook sheets collection has an unexpected child",
                )
            if not sheets:
                _fail("capture.artifacts.workbook", "workbook has no worksheets")
            sheets_by_name: dict[str, ElementTree.Element] = {}
            all_sheet_relationship_ids: set[str] = set()
            all_sheet_targets: set[str] = set()
            all_sheet_ids: set[int] = set()
            for sheet in sheets:
                sheet_name = sheet.attrib.get("name")
                relationship_id = sheet.attrib.get(relationship_id_attribute)
                sheet_id_text = sheet.attrib.get("sheetId")
                if (
                    len(sheet) != 0
                    or not sheet_name
                    or len(sheet_name) > 31
                    or not relationship_id
                    or not sheet_id_text
                    or re.fullmatch(r"[1-9][0-9]{0,9}", sheet_id_text) is None
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        "workbook has an invalid worksheet declaration",
                    )
                sheet_id = int(sheet_id_text)
                folded_sheet_name = sheet_name.casefold()
                relationship = relationships.get(relationship_id)
                if (
                    folded_sheet_name in sheets_by_name
                    or relationship_id in all_sheet_relationship_ids
                    or sheet_id in all_sheet_ids
                    or relationship is None
                    or relationship[0] != worksheet_relationship_type
                    or not relationship[1].startswith("xl/worksheets/")
                    or relationship[1] in all_sheet_targets
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        "workbook worksheet names, ids, relationships, and parts must be one-to-one",
                    )
                if overrides.get("/" + relationship[1]) != WORKSHEET_CONTENT_TYPE:
                    _fail(
                        "capture.artifacts.workbook",
                        f"worksheet {sheet_name!r} content type is missing or invalid",
                    )
                sheets_by_name[folded_sheet_name] = sheet
                all_sheet_relationship_ids.add(relationship_id)
                all_sheet_targets.add(relationship[1])
                all_sheet_ids.add(sheet_id)
            worksheet_relationship_ids = {
                relationship_id
                for relationship_id, (relationship_type, _target) in relationships.items()
                if relationship_type == worksheet_relationship_type
            }
            if worksheet_relationship_ids != all_sheet_relationship_ids:
                _fail(
                    "capture.artifacts.workbook",
                    "worksheet relationships and declared sheets must form one exact closure",
                )

            relationship_targets = [
                target for _relationship_type, target in relationships.values()
            ]
            if len(relationship_targets) != len(set(relationship_targets)):
                _fail(
                    "capture.artifacts.workbook",
                    "workbook relationships must not alias one package part",
                )

            expected_package_parts = {
                "[Content_Types].xml",
                "_rels/.rels",
                "xl/workbook.xml",
                "xl/_rels/workbook.xml.rels",
                *root_relationship_targets,
                *relationship_targets,
            }
            if set(names) != expected_package_parts:
                missing_parts = sorted(expected_package_parts - set(names))
                extra_parts = sorted(set(names) - expected_package_parts)
                _fail(
                    "capture.artifacts.workbook",
                    "OPC package parts must be the exact closed root/workbook graph; "
                    f"missing={missing_parts}, extra={extra_parts}",
                )

            for package_part in expected_package_parts - {"[Content_Types].xml"}:
                leaf = PurePosixPath(package_part).name
                extension = (
                    leaf.lstrip(".").casefold()
                    if leaf.startswith(".")
                    else PurePosixPath(package_part).suffix.lstrip(".").casefold()
                )
                content_type = overrides.get("/" + package_part, defaults.get(extension))
                if not content_type:
                    _fail(
                        "capture.artifacts.workbook",
                        f"closed OPC part has no content type: {package_part}",
                    )

            allowed_plain_sheet_children = {
                f"{{{SPREADSHEET_NS}}}sheetPr",
                f"{{{SPREADSHEET_NS}}}dimension",
                f"{{{SPREADSHEET_NS}}}sheetViews",
                f"{{{SPREADSHEET_NS}}}sheetFormatPr",
                f"{{{SPREADSHEET_NS}}}sheetData",
                f"{{{SPREADSHEET_NS}}}phoneticPr",
                f"{{{SPREADSHEET_NS}}}printOptions",
                f"{{{SPREADSHEET_NS}}}pageMargins",
                f"{{{SPREADSHEET_NS}}}pageSetup",
                f"{{{SPREADSHEET_NS}}}headerFooter",
            }
            plain_sheet_roots: dict[str, ElementTree.Element] = {}
            relationship_attribute_prefix = "{" + OFFICE_REL_NS + "}"
            for sheet_target in all_sheet_targets:
                relationship_part = (
                    PurePosixPath(sheet_target).parent
                    / "_rels"
                    / (PurePosixPath(sheet_target).name + ".rels")
                ).as_posix()
                if relationship_part in names:
                    _fail(
                        "capture.artifacts.workbook",
                        f"worksheet relationship parts are forbidden: {relationship_part}",
                    )
                sheet_root = read_xml_part(
                    sheet_target, f"{{{SPREADSHEET_NS}}}worksheet"
                )
                plain_sheet_roots[sheet_target] = sheet_root
                unexpected_children = [
                    child.tag
                    for child in sheet_root
                    if child.tag not in allowed_plain_sheet_children
                ]
                if unexpected_children:
                    _fail(
                        "capture.artifacts.workbook",
                        f"worksheet {sheet_target!r} has non-plain feature elements: {unexpected_children}",
                    )
                if any(
                    any(
                        attribute_name.startswith(relationship_attribute_prefix)
                        for attribute_name in node.attrib
                    )
                    for node in sheet_root.iter()
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        f"worksheet {sheet_target!r} contains a relationship-bearing feature",
                    )
            if preopen:
                if len(sheets) != 1:
                    _fail(
                        "capture.artifacts.workbook",
                        "pre-open workbook must contain exactly one plain worksheet",
                    )
                if f"{OFFICE_REL_NS}/sharedStrings" in relationship_types:
                    _fail(
                        "capture.artifacts.workbook",
                        "pre-open workbook must not contain a shared-string relationship",
                    )
                if any(
                    node.tag == f"{{{SPREADSHEET_NS}}}definedNames"
                    for node in workbook_xml
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        "pre-open workbook must not contain defined names",
                    )
                only_sheet_target = next(iter(all_sheet_targets))
                blank_sheet = plain_sheet_roots[only_sheet_target]
                blank_sheet_data = [
                    node
                    for node in blank_sheet
                    if node.tag == f"{{{SPREADSHEET_NS}}}sheetData"
                ]
                if len(blank_sheet_data) != 1 or len(blank_sheet_data[0]) != 0:
                    _fail(
                        "capture.artifacts.workbook",
                        "pre-open worksheet must have one empty direct sheetData",
                    )
                return {}
            sheet_names = [node.attrib.get("name") for node in sheets]
            sheet_entries: dict[str, str] = {}
            evidence_relationship_ids: set[str] = set()
            for expected in (result_sheet, event_sheet):
                if sheet_names.count(expected) != 1:
                    _fail(
                        "capture.artifacts.workbook",
                        f"worksheet {expected!r} must occur exactly once",
                    )
                sheet = next(node for node in sheets if node.attrib.get("name") == expected)
                relationship_id = sheet.attrib.get(relationship_id_attribute)
                if not relationship_id or relationship_id in evidence_relationship_ids:
                    _fail(
                        "capture.artifacts.workbook",
                        "evidence worksheets must use distinct relationship ids",
                    )
                evidence_relationship_ids.add(relationship_id)
                relationship = relationships.get(relationship_id or "")
                if (
                    relationship is None
                    or relationship[0] != worksheet_relationship_type
                    or not relationship[1].startswith("xl/worksheets/")
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        f"worksheet {expected!r} is not bound to an internal worksheet part",
                    )
                sheet_entries[expected] = relationship[1]
                if (
                    overrides.get("/" + relationship[1])
                    != WORKSHEET_CONTENT_TYPE
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        f"worksheet {expected!r} content type is missing or invalid",
                    )
            if len(set(sheet_entries.values())) != len(sheet_entries):
                _fail(
                    "capture.artifacts.workbook",
                    "evidence worksheets must bind distinct worksheet parts",
                )

            shared_string_targets = [
                target
                for relationship_type, target in relationships.values()
                if relationship_type
                == "http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings"
            ]
            if len(shared_string_targets) > 1:
                _fail(
                    "capture.artifacts.workbook",
                    "workbook has multiple shared-string relationships",
                )

            def logical_string(container: ElementTree.Element, location: str) -> str:
                def leaf_text(node: ElementTree.Element) -> str:
                    xml_space = "{http://www.w3.org/XML/1998/namespace}space"
                    if (
                        len(node) != 0
                        or any(name != xml_space for name in node.attrib)
                        or (
                            xml_space in node.attrib
                            and node.attrib[xml_space] != "preserve"
                        )
                    ):
                        _fail(
                            "capture.artifacts.workbook",
                            f"{location} has a non-leaf/invalid text node",
                        )
                    return node.text or ""

                text_nodes: list[ElementTree.Element] = []
                run_nodes: list[ElementTree.Element] = []
                for child in container:
                    if child.tag == f"{{{SPREADSHEET_NS}}}t":
                        text_nodes.append(child)
                    elif child.tag == f"{{{SPREADSHEET_NS}}}r":
                        run_nodes.append(child)
                    elif child.tag in {
                        f"{{{SPREADSHEET_NS}}}rPh",
                        f"{{{SPREADSHEET_NS}}}phoneticPr",
                        f"{{{SPREADSHEET_NS}}}extLst",
                    }:
                        # Phonetic and extension text is metadata, not the
                        # logical cell string compared with JSON evidence.
                        continue
                    else:
                        _fail(
                            "capture.artifacts.workbook",
                            f"{location} has an unexpected string element {child.tag!r}",
                        )
                if (len(text_nodes) != 1 or run_nodes) and (
                    text_nodes or not run_nodes
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        f"{location} must use exactly one direct text node or one-or-more rich-text runs",
                    )
                if text_nodes:
                    return leaf_text(text_nodes[0])
                parts: list[str] = []
                for run in run_nodes:
                    run_children = list(run)
                    run_text = [
                        node
                        for node in run_children
                        if node.tag == f"{{{SPREADSHEET_NS}}}t"
                    ]
                    run_properties = [
                        node
                        for node in run_children
                        if node.tag == f"{{{SPREADSHEET_NS}}}rPr"
                    ]
                    if (
                        len(run_text) != 1
                        or len(run_properties) > 1
                        or any(
                            node.tag
                            not in {
                                f"{{{SPREADSHEET_NS}}}rPr",
                                f"{{{SPREADSHEET_NS}}}t",
                            }
                            for node in run_children
                        )
                        or run_children[-1] is not run_text[0]
                        or (run_properties and run_children[0] is not run_properties[0])
                    ):
                        _fail(
                            "capture.artifacts.workbook",
                            f"{location} has an invalid rich-text run",
                        )
                    parts.append(leaf_text(run_text[0]))
                return "".join(parts)

            shared_strings: list[str] = []
            if shared_string_targets:
                shared_target = shared_string_targets[0]
                if (
                    overrides.get("/" + shared_target)
                    != SHARED_STRINGS_CONTENT_TYPE
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        "shared-string content type is missing or invalid",
                    )
                shared_root = read_xml_part(
                    shared_target, f"{{{SPREADSHEET_NS}}}sst"
                )
                for item in shared_root:
                    if item.tag != f"{{{SPREADSHEET_NS}}}si":
                        _fail(
                            "capture.artifacts.workbook",
                            f"unexpected shared-string element: {item.tag!r}",
                        )
                    shared_strings.append(logical_string(item, "shared string"))

            tables: dict[str, list[list[str]]] = {}
            for sheet_name, sheet_entry in sheet_entries.items():
                if sheet_name not in expected_dimensions:
                    _fail(
                        "capture.artifacts.workbook",
                        f"worksheet {sheet_name!r} has no declared evidence dimensions",
                    )
                expected_rows, expected_columns = expected_dimensions[sheet_name]
                if (
                    not 1 <= expected_rows <= 1_048_576
                    or not 1 <= expected_columns <= 16_384
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        f"worksheet {sheet_name!r} has invalid declared evidence dimensions",
                    )
                sheet_root = read_xml_part(
                    sheet_entry, f"{{{SPREADSHEET_NS}}}worksheet"
                )
                sheet_data_nodes = [
                    node
                    for node in sheet_root
                    if node.tag == f"{{{SPREADSHEET_NS}}}sheetData"
                ]
                if len(sheet_data_nodes) != 1:
                    _fail(
                        "capture.artifacts.workbook",
                        f"worksheet {sheet_name!r} must contain exactly one direct sheetData",
                    )
                row_nodes = list(sheet_data_nodes[0])
                if any(
                    node.tag != f"{{{SPREADSHEET_NS}}}row" for node in row_nodes
                ):
                    _fail(
                        "capture.artifacts.workbook",
                        f"worksheet {sheet_name!r} sheetData has an unexpected child",
                    )
                cells: dict[tuple[int, int], str] = {}
                seen_rows: set[int] = set()
                max_row = 0
                max_column = 0
                for row_node in row_nodes:
                    row_text = row_node.attrib.get("r")
                    if not row_text or not re.fullmatch(r"[1-9][0-9]{0,6}", row_text):
                        _fail(
                            "capture.artifacts.workbook",
                            f"worksheet {sheet_name!r} has an invalid row reference",
                        )
                    row_number = int(row_text)
                    if row_number > expected_rows:
                        _fail(
                            "capture.artifacts.workbook",
                            f"worksheet {sheet_name!r} row {row_number} exceeds its declared {expected_rows}-row evidence table",
                        )
                    if row_number in seen_rows:
                        _fail(
                            "capture.artifacts.workbook",
                            f"worksheet {sheet_name!r} has duplicate row {row_number}",
                        )
                    seen_rows.add(row_number)
                    row_children = list(row_node)
                    extension_nodes = [
                        index
                        for index, node in enumerate(row_children)
                        if node.tag == f"{{{SPREADSHEET_NS}}}extLst"
                    ]
                    if (
                        len(extension_nodes) > 1
                        or (extension_nodes and extension_nodes[0] != len(row_children) - 1)
                        or any(
                            node.tag
                            not in {
                                f"{{{SPREADSHEET_NS}}}c",
                                f"{{{SPREADSHEET_NS}}}extLst",
                            }
                            for node in row_children
                        )
                    ):
                        _fail(
                            "capture.artifacts.workbook",
                            f"worksheet {sheet_name!r} row {row_number} has invalid children",
                        )
                    for cell in row_children:
                        if cell.tag == f"{{{SPREADSHEET_NS}}}extLst":
                            continue
                        reference = cell.attrib.get("r", "")
                        reference_match = re.fullmatch(
                            r"([A-Z]{1,3})([1-9][0-9]{0,6})", reference
                        )
                        if reference_match is None or int(reference_match.group(2)) != row_number:
                            _fail(
                                "capture.artifacts.workbook",
                                f"worksheet {sheet_name!r} has an invalid cell reference {reference!r}",
                            )
                        column_number = 0
                        for character in reference_match.group(1):
                            column_number = (column_number * 26) + (
                                ord(character) - ord("A") + 1
                            )
                        if column_number > expected_columns:
                            _fail(
                                "capture.artifacts.workbook",
                                f"worksheet {sheet_name!r} cell {reference} exceeds its declared {expected_columns}-column evidence table",
                            )
                        key = (row_number, column_number)
                        if key in cells:
                            _fail(
                                "capture.artifacts.workbook",
                                f"worksheet {sheet_name!r} has duplicate cell {reference}",
                            )
                        cell_children = list(cell)
                        allowed_cell_children = {
                            f"{{{SPREADSHEET_NS}}}f",
                            f"{{{SPREADSHEET_NS}}}v",
                            f"{{{SPREADSHEET_NS}}}is",
                            f"{{{SPREADSHEET_NS}}}extLst",
                        }
                        child_counts = {
                            tag: sum(node.tag == tag for node in cell_children)
                            for tag in allowed_cell_children
                        }
                        cell_extension_positions = [
                            index
                            for index, node in enumerate(cell_children)
                            if node.tag == f"{{{SPREADSHEET_NS}}}extLst"
                        ]
                        if (
                            any(node.tag not in allowed_cell_children for node in cell_children)
                            or any(count > 1 for count in child_counts.values())
                            or (
                                cell_extension_positions
                                and cell_extension_positions[0] != len(cell_children) - 1
                            )
                        ):
                            _fail(
                                "capture.artifacts.workbook",
                                f"worksheet {sheet_name!r} cell {reference} has invalid children",
                            )
                        if child_counts[f"{{{SPREADSHEET_NS}}}f"]:
                            _fail(
                                "capture.artifacts.workbook",
                                f"worksheet {sheet_name!r} evidence cell {reference} must not contain a formula",
                            )
                        cell_type = cell.attrib.get("t", "n")
                        value_nodes = [
                            node
                            for node in cell
                            if node.tag == f"{{{SPREADSHEET_NS}}}v"
                        ]
                        if any(len(node) != 0 or node.attrib for node in value_nodes):
                            _fail(
                                "capture.artifacts.workbook",
                                f"worksheet {sheet_name!r} cell {reference} has a non-leaf/invalid value node",
                            )
                        if cell_type == "inlineStr":
                            inline_nodes = [
                                node
                                for node in cell
                                if node.tag == f"{{{SPREADSHEET_NS}}}is"
                            ]
                            if len(inline_nodes) != 1 or value_nodes:
                                _fail(
                                    "capture.artifacts.workbook",
                                    f"worksheet {sheet_name!r} cell {reference} has invalid inline-string storage",
                                )
                            value = logical_string(
                                inline_nodes[0],
                                f"worksheet {sheet_name!r} cell {reference}",
                            )
                        else:
                            if child_counts[f"{{{SPREADSHEET_NS}}}is"]:
                                _fail(
                                    "capture.artifacts.workbook",
                                    f"worksheet {sheet_name!r} cell {reference} has inline-string content without inlineStr type",
                                )
                            if len(value_nodes) > 1:
                                _fail(
                                    "capture.artifacts.workbook",
                                    f"worksheet {sheet_name!r} cell {reference} has multiple values",
                                )
                            raw_value = (
                                value_nodes[0].text or "" if value_nodes else ""
                            )
                            if cell_type == "s":
                                if not re.fullmatch(r"[0-9]{1,7}", raw_value):
                                    _fail(
                                        "capture.artifacts.workbook",
                                        f"worksheet {sheet_name!r} cell {reference} has an invalid shared-string index",
                                    )
                                shared_index = int(raw_value)
                                if shared_index >= len(shared_strings):
                                    _fail(
                                        "capture.artifacts.workbook",
                                        f"worksheet {sheet_name!r} cell {reference} shared-string index is out of range",
                                    )
                                value = shared_strings[shared_index]
                            elif cell_type == "b":
                                if raw_value not in {"0", "1"}:
                                    _fail(
                                        "capture.artifacts.workbook",
                                        f"worksheet {sheet_name!r} cell {reference} has an invalid Boolean",
                                    )
                                value = "True" if raw_value == "1" else "False"
                            elif cell_type in {"n", "str"}:
                                value = raw_value
                                if cell_type == "n" and value:
                                    if (
                                        len(value) > 64
                                        or re.fullmatch(
                                            r"-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[Ee][+-]?[0-9]+)?",
                                            value,
                                        )
                                        is None
                                    ):
                                        _fail(
                                            "capture.artifacts.workbook",
                                            f"worksheet {sheet_name!r} cell {reference} has an invalid numeric value",
                                        )
                                    try:
                                        finite_value = math.isfinite(float(value))
                                    except ValueError:
                                        finite_value = False
                                    if not finite_value:
                                        _fail(
                                            "capture.artifacts.workbook",
                                            f"worksheet {sheet_name!r} cell {reference} has a non-finite numeric value",
                                        )
                                    if re.fullmatch(r"-?[0-9]+\.0+", value):
                                        value = value.split(".", 1)[0]
                            else:
                                _fail(
                                    "capture.artifacts.workbook",
                                    f"worksheet {sheet_name!r} cell {reference} has unsupported type {cell_type!r}",
                                )
                        cells[key] = value
                        max_row = max(max_row, row_number)
                        max_column = max(max_column, column_number)
                tables[sheet_name] = [
                    [
                        cells.get((row_number, column_number), "")
                        for column_number in range(1, max_column + 1)
                    ]
                    for row_number in range(1, max_row + 1)
                ]
            return tables
    except (
        zipfile.BadZipFile,
        zipfile.LargeZipFile,
        ElementTree.ParseError,
        OSError,
        OverflowError,
        ValueError,
    ) as exc:
        _fail("capture.artifacts.workbook", f"invalid OOXML package: {exc}")


def validate_preopen_workbook(
    workbook_path: Path,
    manifest_path: Path,
    cfb_validator_path: Path,
    repo_root: Path,
) -> dict[str, str]:
    """Fail closed before Excel opens the generated macro-enabled workbook."""
    resolved_manifest = _resolve_repo_path(
        repo_root, str(manifest_path), "preopen.manifest"
    )
    resolved_workbook = _resolve_repo_path(
        repo_root, str(workbook_path), "preopen.workbook"
    )
    resolved_cfb_validator = _resolve_repo_path(
        repo_root, str(cfb_validator_path), "preopen.cfb_validator"
    )
    manifest = validate_manifest(resolved_manifest, repo_root)
    try:
        cfb_source = resolved_cfb_validator.read_bytes()
    except OSError as exc:
        _fail("preopen.cfb_validator", f"cannot read exact validator bytes: {exc}")
    expected_cfb_sha256 = manifest["replay_validators"]["cfb_inventory"][
        "sha256"
    ]
    if sha256_bytes(cfb_source) != expected_cfb_sha256:
        _fail(
            "preopen.cfb_validator",
            "capture-local CFB validator bytes do not match the manifest pin",
        )
    try:
        cfb_module = _load_python_module_bytes(
            cfb_source,
            resolved_cfb_validator,
            "oxforms_oracle_preopen_cfb_inventory",
        )
    except Exception as exc:
        _fail("preopen.cfb_validator", f"cannot load exact validator bytes: {exc}")

    expected_vba_sources = {
        RUNTIME_MODULE_NAME: (
            "Module",
            generate_module_code(manifest),
        ),
        manifest["form"]["name"]: (
            "BaseClass",
            generate_form_code(manifest),
        ),
    }
    workbook_bytes = _read_bound_file(
        resolved_workbook,
        "preopen.workbook",
        max_bytes=64 * 1024 * 1024,
    )
    workbook_sha256 = sha256_bytes(workbook_bytes)
    _validate_xlsm_package(
        resolved_workbook,
        manifest["capture"]["result_sheet"],
        manifest["capture"]["event_sheet"],
        {},
        expected_vba_sources,
        cfb_module,
        preopen=True,
        expected_package_sha256=workbook_sha256,
        retained_package_bytes=workbook_bytes,
    )
    if _read_bound_file(
        resolved_workbook,
        "preopen.workbook",
        expected_sha256=workbook_sha256,
        max_bytes=64 * 1024 * 1024,
    ) != workbook_bytes:
        _fail(
            "preopen.workbook",
            "workbook bytes changed during strict pre-open validation",
        )
    return {"workbook_sha256": workbook_sha256}


def _validate_results(
    results: dict[str, Any], manifest: dict[str, Any], manifest_sha: str
) -> tuple[int, int]:
    _expect_exact_keys(results, "results", ["schema", "schema_version", "manifest", "rows"])
    if results["schema"] != RESULT_SCHEMA or type(results["schema_version"]) is not int or results["schema_version"] != 1:
        _fail("results", "unexpected schema/version")
    manifest_ref = _expect_dict(results["manifest"], "results.manifest")
    _expect_exact_keys(manifest_ref, "results.manifest", ["id", "sha256"])
    if manifest_ref != {"id": manifest["id"], "sha256": manifest_sha}:
        _fail("results.manifest", "does not bind the exact probe manifest")
    expected_steps = [step for step in manifest["steps"] if step["kind"] == "probe"]
    rows = _expect_list(results["rows"], "results.rows")
    if len(rows) != len(expected_steps):
        _fail("results.rows", f"expected {len(expected_steps)} rows, found {len(rows)}")
    success_count = 0
    error_count = 0
    previous_sequence = -1
    for index, (row_value, step) in enumerate(zip(rows, expected_steps)):
        rpath = f"results.rows[{index}]"
        row = _expect_dict(row_value, rpath)
        _expect_exact_keys(
            row,
            rpath,
            RESULT_HEADERS,
        )
        sequence = _int_from_capture(row["sequence"], f"{rpath}.sequence")
        if sequence <= previous_sequence:
            _fail(f"{rpath}.sequence", "must be strictly increasing")
        previous_sequence = sequence
        exact = {
            "probe_id": step["id"],
            "ledger_row_id": step["ledger_row_id"],
            "target_id": step["target"],
            "operation": step["operation"],
            "member": step["member"],
        }
        for key, expected in exact.items():
            if row[key] != expected:
                _fail(f"{rpath}.{key}", f"expected {expected!r}, found {row[key]!r}")
        expectation = step["expect"]
        if row["outcome"] != expectation["outcome"]:
            _fail(f"{rpath}.outcome", f"expected {expectation['outcome']!r}, found {row['outcome']!r}")
        error_number = _int_from_capture(row["error_number"], f"{rpath}.error_number")
        error_last_dll_error = _int_from_capture(
            row["error_last_dll_error"], f"{rpath}.error_last_dll_error"
        )
        if error_last_dll_error < -2147483648 or error_last_dll_error > 2147483647:
            _fail(
                f"{rpath}.error_last_dll_error",
                "must fit a signed VBA Long",
            )
        expected_hex = f"0x{error_number & 0xFFFFFFFF:08X}"
        if row["error_hex"] != expected_hex:
            _fail(f"{rpath}.error_hex", f"expected {expected_hex!r}, found {row['error_hex']!r}")
        error_help_context = _int_from_capture(
            row["error_help_context"], f"{rpath}.error_help_context"
        )
        error_line = _int_from_capture(row["error_line"], f"{rpath}.error_line")
        for text_field in (
            "error_description",
            "error_description_utf16_hex",
            "error_source",
            "error_help_file",
            "error_stage",
        ):
            _expect_string(row[text_field], f"{rpath}.{text_field}", nonempty=False)
        if row["outcome"] == "success":
            success_count += 1
            if error_number != 0:
                _fail(f"{rpath}.error_number", "successful row must record zero")
            if any(
                row[field]
                for field in (
                    "error_description",
                    "error_description_utf16_hex",
                    "error_source",
                    "error_help_file",
                )
            ) or error_last_dll_error != 0 or error_help_context != 0 or error_line != 0:
                _fail(rpath, "successful row must not retain error metadata")
            if row["is_object"] != "False" or row["is_array"] != "False":
                _fail(rpath, "schema v1 representative scalar result must be neither object nor array")
            vartype = _int_from_capture(row["var_type"], f"{rpath}.var_type")
            type_name = _expect_string(row["type_name"], f"{rpath}.type_name")
            if not any(
                (type_name, vartype) in shapes
                for shapes in SCALAR_RESULT_SHAPES.values()
            ):
                _fail(rpath, f"unsupported or incoherent scalar result shape {type_name}/{vartype}")
            if (
                type_name != expectation["type_name"]
                or vartype != expectation["var_type"]
            ):
                _fail(
                    rpath,
                    "returned scalar type does not match the exact expectation: "
                    f"expected {expectation['type_name']}/{expectation['var_type']}, "
                    f"found {type_name}/{vartype}",
                )
            if type(row["value_text"]) is not str:
                _fail(f"{rpath}.value_text", "must be a string")
            if "value" in expectation:
                expected_text = scalar_expected_text(expectation["value"])
                if row["value_text"] != expected_text:
                    _fail(f"{rpath}.value_text", f"expected {expected_text!r}, found {row['value_text']!r}")
                if (
                    type_name,
                    vartype,
                ) not in SCALAR_RESULT_SHAPES[expectation["value"]["kind"]]:
                    _fail(rpath, f"typed value shape {type_name}/{vartype} does not match {expectation['value']['kind']}")
        else:
            error_count += 1
            if error_number == 0:
                _fail(f"{rpath}.error_number", "error row must record a nonzero exact Err.Number")
            validate_error_description_encoding(
                row["error_description"],
                row["error_description_utf16_hex"],
                rpath,
                visible_field="error_description",
                raw_field="error_description_utf16_hex",
            )
            _expect_string(
                row["error_source"], f"{rpath}.error_source", nonempty=False
            )
            error_stage = _expect_string(row["error_stage"], f"{rpath}.error_stage")
            allowed_error_stages = {
                "property_get": {"get"},
                "property_set": {"set"},
                "property_roundtrip": {"set", "get"},
                "default_get": {"default_get"},
                "method": {"method"},
            }[step["operation"]]
            if error_stage not in allowed_error_stages:
                _fail(
                    f"{rpath}.error_stage",
                    f"must be one of {sorted(allowed_error_stages)} for {step['operation']}",
                )
            for key in ("value_text", "type_name", "var_type", "is_object", "is_array"):
                if row[key] != "":
                    _fail(f"{rpath}.{key}", "error row cannot carry a returned value")
            if "error_number" in expectation and error_number != expectation["error_number"]:
                _fail(f"{rpath}.error_number", f"expected {expectation['error_number']}, found {error_number}")
            if error_last_dll_error != expectation["last_dll_error_equals"]:
                _fail(
                    f"{rpath}.error_last_dll_error",
                    "expected "
                    f"{expectation['last_dll_error_equals']}, found {error_last_dll_error}",
                )
            if (
                "description_equals" in expectation
                and row["error_description"] != expectation["description_equals"]
            ):
                _fail(
                    f"{rpath}.error_description",
                    f"expected {expectation['description_equals']!r}, found {row['error_description']!r}",
                )
            if (
                "description_utf16_hex_equals" in expectation
                and row["error_description_utf16_hex"]
                != expectation["description_utf16_hex_equals"]
            ):
                _fail(
                    f"{rpath}.error_description_utf16_hex",
                    "does not match the exact raw UTF-16 Err.Description expectation",
                )
            if row["error_source"] != expectation["source_equals"]:
                _fail(
                    f"{rpath}.error_source",
                    f"expected {expectation['source_equals']!r}, found {row['error_source']!r}",
                )
            if row["error_help_file"] != expectation["help_file_equals"]:
                _fail(
                    f"{rpath}.error_help_file",
                    f"expected {expectation['help_file_equals']!r}, found {row['error_help_file']!r}",
                )
            if error_help_context != expectation["help_context_equals"]:
                _fail(
                    f"{rpath}.error_help_context",
                    "expected "
                    f"{expectation['help_context_equals']}, found {error_help_context}",
                )
            if error_line != expectation["line_equals"]:
                _fail(
                    f"{rpath}.error_line",
                    f"expected {expectation['line_equals']}, found {error_line}",
                )
            if "error_stage" in expectation and error_stage != expectation["error_stage"]:
                _fail(
                    f"{rpath}.error_stage",
                    f"expected {expectation['error_stage']!r}, found {error_stage!r}",
                )
    return success_count, error_count


def _validate_events(events_doc: dict[str, Any], manifest: dict[str, Any], manifest_sha: str) -> int:
    _expect_exact_keys(events_doc, "events", ["schema", "schema_version", "manifest", "rows"])
    if events_doc["schema"] != EVENT_SCHEMA or type(events_doc["schema_version"]) is not int or events_doc["schema_version"] != 1:
        _fail("events", "unexpected schema/version")
    manifest_ref = _expect_dict(events_doc["manifest"], "events.manifest")
    if manifest_ref != {"id": manifest["id"], "sha256": manifest_sha}:
        _fail("events.manifest", "does not bind the exact probe manifest")
    rows = _expect_list(events_doc["rows"], "events.rows")
    definitions = {event["id"]: event for event in manifest["events"]}
    counts = {event_id: 0 for event_id in definitions}
    previous_sequence = -1
    for index, row_value in enumerate(rows):
        rpath = f"events.rows[{index}]"
        row = _expect_dict(row_value, rpath)
        _expect_exact_keys(
            row,
            rpath,
            EVENT_HEADERS,
        )
        sequence = _int_from_capture(row["sequence"], f"{rpath}.sequence")
        if sequence <= previous_sequence:
            _fail(f"{rpath}.sequence", "must be strictly increasing")
        previous_sequence = sequence
        event_id = row["event_id"]
        if event_id not in definitions:
            _fail(f"{rpath}.event_id", "undeclared event row")
        event = definitions[event_id]
        control = next(control for control in manifest["form"]["controls"] if control["id"] == event["target"])
        exact = {
            "ledger_row_id": event["ledger_row_id"],
            "target_id": event["target"],
            "target_kind": control["fm20_type"],
            "event_name": event["name"],
            "trigger_step_id": event["trigger_step_id"],
        }
        for key, expected in exact.items():
            if row[key] != expected:
                _fail(f"{rpath}.{key}", f"expected {expected!r}, found {row[key]!r}")
        if row["arguments_before"] != event["expect"]["arguments_before"]:
            _fail(f"{rpath}.arguments_before", f"expected exact {event['expect']['arguments_before']!r}")
        if row["arguments_after"] != event["expect"]["arguments_after"]:
            _fail(f"{rpath}.arguments_after", f"expected exact {event['expect']['arguments_after']!r}")
        counts[event_id] += 1
    for event_id, event in definitions.items():
        if counts[event_id] != event["expected_occurrences"]:
            _fail("events.rows", f"event {event_id!r} expected exactly {event['expected_occurrences']}, found {counts[event_id]}")
    return len(rows)


def _validate_event_timeline(
    result_rows: list[Any], event_rows: list[Any], manifest: dict[str, Any]
) -> None:
    probe_sequences = {
        _expect_string(row.get("probe_id"), f"results.rows[{index}].probe_id"):
        _int_from_capture(row.get("sequence"), f"results.rows[{index}].sequence")
        for index, row in enumerate(result_rows)
        if isinstance(row, dict)
    }
    event_definitions = {event["id"]: event for event in manifest["events"]}
    step_indexes = {step["id"]: index for index, step in enumerate(manifest["steps"])}
    probe_steps = [
        (index, step["id"])
        for index, step in enumerate(manifest["steps"])
        if step["kind"] == "probe"
    ]
    total_rows = len(result_rows) + len(event_rows)
    for index, row_value in enumerate(event_rows):
        row = _expect_dict(row_value, f"events.rows[{index}]")
        event_id = _expect_string(row.get("event_id"), f"events.rows[{index}].event_id")
        event = event_definitions[event_id]
        trigger_index = step_indexes[event["trigger_step_id"]]
        preceding = [
            probe_id for step_index, probe_id in probe_steps if step_index < trigger_index
        ]
        following = [
            probe_id for step_index, probe_id in probe_steps if step_index > trigger_index
        ]
        lower_bound = probe_sequences[preceding[-1]] if preceding else 0
        upper_bound = (
            probe_sequences[event["trigger_step_id"]]
            if event["trigger_step_id"] in probe_sequences
            else (probe_sequences[following[0]] if following else total_rows + 1)
        )
        sequence = _int_from_capture(row.get("sequence"), f"events.rows[{index}].sequence")
        if not lower_bound < sequence < upper_bound:
            _fail(
                f"events.rows[{index}].sequence",
                f"event {event_id!r} falls outside the execution window for trigger step {event['trigger_step_id']!r}",
            )


def _validate_frx_reference(references: Any, expected_leaf: str) -> None:
    rows = _expect_list(references, "frm.external_resource_references")
    if len(rows) != 1:
        _fail(
            "capture.artifacts.form_export",
            "FRM must contain exactly one external-resource reference",
        )
    reference = _expect_dict(rows[0], "frm.external_resource_references[0]")
    if (
        reference.get("property_name") != "OleObjectBlob"
        or reference.get("owner_block_index") != 0
        or reference.get("path") != expected_leaf
        or reference.get("offset") != 0
        or reference.get("offset_text") != "0000"
        or reference.get("is_safe_relative_basename") is not True
        or reference.get("unsafe_reasons") != []
    ):
        _fail(
            "capture.artifacts.form_export",
            "FRM OleObjectBlob does not exactly bind the captured sibling FRX at offset 0000",
        )


def _validate_frm_frx_siblings(form_path: Path, frx_path: Path) -> None:
    if form_path.parent != frx_path.parent:
        _fail(
            "capture.artifacts.form_export",
            "FRM and referenced FRX artifacts must be exact siblings",
        )


def _validate_checksum_manifest(capture_dir: Path) -> tuple[dict[str, str], bytes]:
    checksum_path = capture_dir / "checksums.sha256"
    if not checksum_path.is_file():
        _fail("checksums.sha256", "missing")
    if checksum_path.is_symlink() or checksum_path.is_junction() or checksum_path.stat().st_nlink != 1:
        _fail("checksums.sha256", "must be a real non-hard-linked file")
    try:
        checksum_bytes = _read_bound_file(
            checksum_path,
            "checksums.sha256",
            max_bytes=128 * 1024,
        )
        checksum_text = checksum_bytes.decode("ascii")
    except (OSError, UnicodeDecodeError) as exc:
        _fail("checksums.sha256", f"cannot read strict ASCII manifest: {exc}")
    entries: dict[str, str] = {}
    for line_number, line in enumerate(checksum_text.splitlines(), 1):
        match = re.fullmatch(r"([0-9a-f]{64})  ([^\\]+)", line)
        if not match:
            _fail("checksums.sha256", f"malformed line {line_number}")
        digest, relative = match.groups()
        try:
            _safe_capture_relative_path(
                relative, f"checksums.sha256 line {line_number} path"
            )
        except OracleValidationError:
            _fail("checksums.sha256", f"unsafe relative path on line {line_number}")
        if relative in entries:
            _fail("checksums.sha256", f"duplicate path: {relative}")
        entries[relative] = digest
    root_checksum = checksum_path.resolve()
    actual_files: set[str] = set()
    pending_directories = [capture_dir]
    while pending_directories:
        directory = pending_directories.pop()
        try:
            children = list(os.scandir(directory))
        except OSError as exc:
            _fail("checksums.sha256", f"cannot enumerate capture tree: {exc}")
        for child in children:
            path = Path(child.path)
            if path.is_symlink() or path.is_junction():
                _fail(
                    "checksums.sha256",
                    f"reparse/symbolic capture entry is forbidden: {path}",
                )
            if child.is_dir(follow_symlinks=False):
                pending_directories.append(path)
                continue
            if not child.is_file(follow_symlinks=False):
                _fail(
                    "checksums.sha256", f"special capture entry is forbidden: {path}"
                )
            if path.resolve() == root_checksum:
                continue
            if path.stat().st_nlink != 1:
                _fail("checksums.sha256", f"hard-linked capture file is forbidden: {path}")
            actual_relative = path.relative_to(capture_dir).as_posix()
            _safe_capture_relative_path(
                actual_relative, "checksums.sha256 capture-tree path"
            )
            actual_files.add(actual_relative)
            if len(actual_files) > 256:
                _fail("checksums.sha256", "capture contains unexpectedly many files")
    if set(entries) != actual_files:
        missing = sorted(actual_files - set(entries))
        extra = sorted(set(entries) - actual_files)
        _fail("checksums.sha256", f"coverage mismatch; missing={missing}, extra={extra}")
    for relative, expected in entries.items():
        _read_bound_file(
            capture_dir / Path(*PurePosixPath(relative).parts),
            f"checksums.sha256 entry {relative}",
            expected_sha256=expected,
            max_bytes=128 * 1024 * 1024,
        )
    return entries, checksum_bytes


def validate_capture(capture_dir: Path, manifest_path: Path, repo_root: Path) -> dict[str, int]:
    resolved_manifest_path = _resolve_repo_path(
        repo_root, str(manifest_path), "manifest"
    )
    manifest_bytes = _read_bound_file(
        resolved_manifest_path,
        "manifest",
        max_bytes=4 * 1024 * 1024,
    )
    manifest_sha = sha256_bytes(manifest_bytes)
    manifest = validate_manifest(
        resolved_manifest_path,
        repo_root,
        source_bytes=manifest_bytes,
    )
    lexical_capture = Path(os.path.abspath(capture_dir))
    if not lexical_capture.is_dir():
        _fail("capture_dir", "must be a directory")
    current = lexical_capture
    while True:
        if current.is_symlink() or current.is_junction():
            _fail("capture_dir", f"reparse/symbolic path is forbidden: {current}")
        if current == repo_root.resolve() or current.parent == current:
            break
        current = current.parent
    capture_dir = lexical_capture.resolve()
    try:
        capture_dir.relative_to(repo_root.resolve())
    except ValueError:
        _fail("capture_dir", "must be inside the repository")
    if not capture_dir.is_dir():
        _fail("capture_dir", "must be a real directory")
    expected_capture_root = (
        repo_root
        / "docs"
        / "evidence"
        / "W010_complete_msforms_object_model_parity"
        / "beads"
        / manifest["bead"]
        / "captures"
    ).resolve()
    try:
        capture_relative = capture_dir.relative_to(expected_capture_root)
    except ValueError:
        _fail(
            "capture_dir",
            f"must be below the manifest bead capture root {expected_capture_root}",
        )
    if not capture_relative.parts:
        _fail("capture_dir", "must name a capture below the manifest bead capture root")
    # Validate the complete immutable tree before parsing or executing any
    # capture-local content. Executable validator bytes are additionally read,
    # hashed, and retained once below to close hash/use races.
    checksum_entries, checksum_bytes = _validate_checksum_manifest(capture_dir)
    capture_manifest_relative = "oracle-capture-manifest.json"
    capture_manifest_digest = checksum_entries.get(capture_manifest_relative)
    if capture_manifest_digest is None:
        _fail("checksums.sha256", "capture manifest is not checksum-bound")
    capture_manifest_path = capture_dir / capture_manifest_relative
    capture_manifest_bytes = _read_bound_file(
        capture_manifest_path,
        "capture manifest",
        expected_sha256=capture_manifest_digest,
        max_bytes=4 * 1024 * 1024,
    )
    capture = _expect_dict(
        load_json_bytes(capture_manifest_bytes, capture_manifest_path), "capture"
    )
    _expect_exact_keys(
        capture,
        "capture",
        [
            "schema",
            "schema_version",
            "bead",
            "capture_id",
            "status",
            "started_at_utc",
            "completed_at_utc",
            "probe_manifest",
            "tools",
            "preopen_workbook_sha256",
            "platform",
            "build_excel",
            "excel",
            "vbe",
            "fm20",
            "artifacts",
            "observed_coverage",
            "provenance",
            "warnings",
            "non_claims",
        ],
    )
    if capture["schema"] != CAPTURE_SCHEMA or type(capture["schema_version"]) is not int or capture["schema_version"] != 1:
        _fail("capture", "unexpected schema/version")
    if capture["bead"] != manifest["bead"] or capture["status"] != "captured":
        _fail("capture", "must be a captured artifact for the manifest-declared W010 bead")
    preopen_workbook_sha256 = _expect_string(
        capture["preopen_workbook_sha256"],
        "capture.preopen_workbook_sha256",
    )
    if not SHA256_RE.fullmatch(preopen_workbook_sha256):
        _fail(
            "capture.preopen_workbook_sha256",
            "must be the lowercase SHA-256 returned by strict pre-open validation",
        )
    _expect_identifier(capture["capture_id"], "capture.capture_id")
    capture_leaf = capture_relative.parts[0]
    canonical_leaf = capture["capture_id"]
    staging_leaf = re.fullmatch(
        rf"\.{re.escape(canonical_leaf)}\.capture-staging-[0-9a-f]{{32}}",
        capture_leaf,
    )
    if len(capture_relative.parts) != 1 or (
        capture_leaf != canonical_leaf and staging_leaf is None
    ):
        _fail(
            "capture.capture_id",
            "must match the canonical directory leaf or its exact atomic-staging form",
        )
    started_at = _expect_utc_timestamp(capture["started_at_utc"], "capture.started_at_utc")
    completed_at = _expect_utc_timestamp(capture["completed_at_utc"], "capture.completed_at_utc")
    if completed_at < started_at:
        _fail("capture.completed_at_utc", "must not precede capture.started_at_utc")
    probe_ref = _expect_dict(capture["probe_manifest"], "capture.probe_manifest")
    _expect_exact_keys(probe_ref, "capture.probe_manifest", ["id", "path", "sha256", "ledger_canonical_sha256"])
    if probe_ref["id"] != manifest["id"] or probe_ref["sha256"] != manifest_sha:
        _fail("capture.probe_manifest", "does not bind the exact source manifest")
    if probe_ref["ledger_canonical_sha256"] != manifest["ledger"]["canonical_sha256"]:
        _fail("capture.probe_manifest.ledger_canonical_sha256", "ledger digest drift")
    source_manifest = _resolve_repo_path(repo_root, probe_ref["path"], "capture.probe_manifest.path")
    canonical_source_relative = source_manifest.relative_to(repo_root.resolve()).as_posix()
    if probe_ref["path"] != canonical_source_relative:
        _fail(
            "capture.probe_manifest.path",
            "must be the canonical repository-relative source-manifest path",
        )
    validated_manifest = resolved_manifest_path.resolve()
    source_manifest = source_manifest.resolve()
    frozen_manifest = (capture_dir / "input-snapshots" / "probe-manifest.json").resolve()
    if validated_manifest == source_manifest:
        pass
    elif validated_manifest == frozen_manifest:
        frozen_relative = "input-snapshots/probe-manifest.json"
        if checksum_entries.get(frozen_relative) != manifest_sha:
            _fail(
                "capture.probe_manifest.path",
                "frozen validator input is not checksum-bound to the declared source manifest",
            )
        _read_bound_file(
            source_manifest,
            "capture.probe_manifest.path",
            expected_sha256=manifest_sha,
            max_bytes=4 * 1024 * 1024,
        )
    else:
        _fail(
            "capture.probe_manifest.path",
            "validator input must be the canonical source manifest or the exact capture-local frozen snapshot",
        )

    tools = _expect_dict(capture["tools"], "capture.tools")
    expected_tool_sources = {
        "generator_validator": "tools/office-oracle/msforms_member_oracle.py",
        "capture_runner": "tools/office-oracle/Capture-MSFormsMemberOracle.ps1",
        "window_capture": "tools/office-oracle/Capture-Window.ps1",
        **REPLAY_VALIDATOR_SOURCES,
    }
    _expect_exact_keys(tools, "capture.tools", expected_tool_sources)
    tool_snapshot_paths: set[Path] = set()
    tool_snapshots_by_role: dict[str, Path] = {}
    executable_tool_bytes: dict[str, bytes] = {}
    for name, expected_source in expected_tool_sources.items():
        tool = _expect_dict(tools[name], f"capture.tools.{name}")
        _expect_exact_keys(
            tool,
            f"capture.tools.{name}",
            ["source_path", "snapshot_path", "sha256"],
        )
        if tool["source_path"] != expected_source:
            _fail(
                f"capture.tools.{name}.source_path",
                f"must be exactly {expected_source!r}",
            )
        validator_pin = manifest["replay_validators"].get(name)
        if validator_pin is not None:
            if tool["source_path"] != validator_pin["path"]:
                _fail(
                    f"capture.tools.{name}.source_path",
                    "does not match the independently manifest-pinned replay validator path",
                )
            if tool["sha256"] != validator_pin["sha256"]:
                _fail(
                    f"capture.tools.{name}.sha256",
                    "does not match the independently manifest-pinned replay validator digest",
                )
        snapshot, exact_bytes = _artifact_snapshot(
            repo_root,
            capture_dir,
            {"path": tool["snapshot_path"], "sha256": tool["sha256"]},
            f"capture.tools.{name}",
            max_bytes=16 * 1024 * 1024,
        )
        if snapshot.name.casefold() != Path(expected_source).name.casefold():
            _fail(f"capture.tools.{name}.snapshot_path", "snapshot leaf does not match its tool")
        if snapshot in tool_snapshot_paths:
            _fail("capture.tools", "each tool role must have a distinct snapshot file")
        tool_snapshot_paths.add(snapshot)
        tool_snapshots_by_role[name] = snapshot
        if validator_pin is not None:
            if sha256_bytes(exact_bytes) != validator_pin["sha256"]:
                _fail(
                    f"capture.tools.{name}.sha256",
                    "exact executable bytes do not match the independently manifest-pinned digest",
                )
            executable_tool_bytes[name] = exact_bytes

    platform = _expect_dict(capture["platform"], "capture.platform")
    _expect_exact_keys(
        platform,
        "capture.platform",
        [
            "os",
            "is_windows",
            "powershell",
            "python",
            "process_architecture",
            "culture",
            "ui_culture",
            "ansi_code_page",
            "oem_code_page",
            "office_ui_lcid",
        ],
    )
    if platform["is_windows"] is not True:
        _fail("capture.platform.is_windows", "live representative capture must be Windows")
    for key in ("os", "powershell", "python", "process_architecture", "culture", "ui_culture"):
        _expect_string(platform[key], f"capture.platform.{key}")
    _expect_int(platform["ansi_code_page"], "capture.platform.ansi_code_page", minimum=1)
    _expect_int(platform["oem_code_page"], "capture.platform.oem_code_page", minimum=1)
    if _expect_int(
        platform["office_ui_lcid"],
        "capture.platform.office_ui_lcid",
        minimum=1,
    ) != 1033:
        _fail(
            "capture.platform.office_ui_lcid",
            "exact English Err.Description expectations require Office UI LCID 1033",
        )
    excel_identity_keys = [
        "path",
        "file_version",
        "product_version",
        "product_name",
        "company_name",
        "sha256",
        "process_id",
        "process_start_utc",
        "bitness",
        "startup_mode",
        "launch_arguments",
        "containment_method",
        "containment_membership_verified",
        "process_exclusivity_observation",
        "command_line_observation_method",
        "observed_command_line",
        "observed_launch_argv",
        "binding_method",
        "binding_hwnd",
        "owned_window_count_at_binding",
        "startup_workbook_observation",
        "isolation_checks",
    ]

    def validate_com_addins(value: Any, path: str) -> list[dict[str, Any]]:
        inventory = _expect_list(value, path)
        keys: list[tuple[str, str]] = []
        for index, raw in enumerate(inventory):
            item_path = f"{path}[{index}]"
            item = _expect_dict(raw, item_path)
            _expect_exact_keys(
                item,
                item_path,
                ["prog_id", "description", "connected"],
            )
            prog_id = _expect_string(item["prog_id"], f"{item_path}.prog_id")
            description = _expect_string(
                item["description"], f"{item_path}.description", nonempty=False
            )
            if _expect_bool(item["connected"], f"{item_path}.connected"):
                _fail(item_path, "safe-mode capture must not have a connected COM add-in")
            keys.append((prog_id.casefold(), description.casefold()))
        if keys != sorted(keys) or len(keys) != len(set(keys)):
            _fail(path, "must be sorted and unique by ProgID/description")
        return inventory

    def validate_excel_addins(value: Any, path: str) -> list[dict[str, Any]]:
        inventory = _expect_list(value, path)
        keys: list[tuple[str, str]] = []
        for index, raw in enumerate(inventory):
            item_path = f"{path}[{index}]"
            item = _expect_dict(raw, item_path)
            _expect_exact_keys(
                item,
                item_path,
                ["name", "title", "path", "full_name", "installed", "is_open"],
            )
            name = _expect_string(item["name"], f"{item_path}.name", nonempty=False)
            _expect_string(item["title"], f"{item_path}.title", nonempty=False)
            _expect_string(item["path"], f"{item_path}.path", nonempty=False)
            full_name = _expect_string(
                item["full_name"], f"{item_path}.full_name", nonempty=False
            )
            _expect_bool(item["installed"], f"{item_path}.installed")
            if _expect_bool(item["is_open"], f"{item_path}.is_open"):
                _fail(item_path, "safe-mode capture must not have an open Excel add-in")
            keys.append((full_name.casefold(), name.casefold()))
        if keys != sorted(keys) or len(keys) != len(set(keys)):
            _fail(path, "must be sorted and unique by full-name/name")
        return inventory

    def validate_isolation_checks(
        role: str, value: Any
    ) -> list[dict[str, Any]]:
        checks = _expect_list(value, f"capture.{role}.isolation_checks")
        expected = (
            [
                ("post_startup_close", "none"),
                ("pre_vbide_automation", "expected_pathless_harness"),
                ("pre_shutdown", "none"),
            ]
            if role == "build_excel"
            else [
                ("post_startup_close", "none"),
                ("pre_macro_execution", "exact_hash_pinned_harness"),
                ("pre_shutdown", "none"),
            ]
        )
        if len(checks) != len(expected):
            _fail(
                f"capture.{role}.isolation_checks",
                f"must contain the exact {len(expected)} safe-mode checkpoints",
            )
        stable_inventory: dict[str, Any] | None = None
        for index, (checkpoint, disposition) in enumerate(expected):
            item_path = f"capture.{role}.isolation_checks[{index}]"
            item = _expect_dict(checks[index], item_path)
            _expect_exact_keys(
                item,
                item_path,
                [
                    "checkpoint",
                    "window_observation",
                    "workbook_disposition",
                    "workbook_count",
                    "workbooks",
                    "startup_path",
                    "alt_startup_path",
                    "protected_view_window_count",
                    "com_addins_access",
                    "com_addins",
                    "excel_addins",
                    "excel_addins2",
                    "loaded_xll_modules",
                ],
            )
            if item["checkpoint"] != checkpoint or item["workbook_disposition"] != disposition:
                _fail(item_path, "checkpoint/disposition sequence is not authoritative")
            window_observation = _expect_dict(
                item["window_observation"], f"{item_path}.window_observation"
            )
            _expect_exact_keys(
                window_observation,
                f"{item_path}.window_observation",
                [
                    "enumeration_succeeded",
                    "enumeration_truncated",
                    "enumeration_limit",
                    "enumeration_error_code",
                    "owned_window_count",
                    "top_level_windows",
                ],
            )
            if _expect_bool(
                window_observation["enumeration_succeeded"],
                f"{item_path}.window_observation.enumeration_succeeded",
            ) is not True:
                _fail(item_path, "exact-PID window enumeration did not succeed")
            if _expect_bool(
                window_observation["enumeration_truncated"],
                f"{item_path}.window_observation.enumeration_truncated",
            ) is not False:
                _fail(item_path, "exact-PID window enumeration was truncated")
            if _expect_int(
                window_observation["enumeration_limit"],
                f"{item_path}.window_observation.enumeration_limit",
            ) != 512:
                _fail(item_path, "exact-PID window enumeration limit drifted")
            if _expect_int(
                window_observation["enumeration_error_code"],
                f"{item_path}.window_observation.enumeration_error_code",
            ) != 0:
                _fail(item_path, "exact-PID window enumeration recorded an error")
            owned_window_count = _expect_int(
                window_observation["owned_window_count"],
                f"{item_path}.window_observation.owned_window_count",
                minimum=1,
            )
            if owned_window_count > 512:
                _fail(item_path, "exact-PID owned-window count exceeds its bound")
            top_level_windows = _expect_list(
                window_observation["top_level_windows"],
                f"{item_path}.window_observation.top_level_windows",
            )
            top_level_hwnds: list[int] = []
            has_enabled_excel_root = False
            for window_index, raw_window in enumerate(top_level_windows):
                window_path = (
                    f"{item_path}.window_observation.top_level_windows"
                    f"[{window_index}]"
                )
                window = _expect_dict(raw_window, window_path)
                _expect_exact_keys(
                    window,
                    window_path,
                    ["hwnd", "class_name", "title", "visible", "enabled"],
                )
                hwnd = _expect_int(window["hwnd"], f"{window_path}.hwnd", minimum=1)
                class_name = _expect_string(
                    window["class_name"], f"{window_path}.class_name"
                )
                _expect_string(window["title"], f"{window_path}.title", nonempty=False)
                visible = _expect_bool(window["visible"], f"{window_path}.visible")
                enabled = _expect_bool(window["enabled"], f"{window_path}.enabled")
                if visible and class_name not in {"XLMAIN", "MSOSPLASH", "MsoSplash"}:
                    _fail(window_path, "is an unexpected visible top-level window")
                if class_name == "XLMAIN" and not enabled:
                    _fail(window_path, "is a disabled Excel root consistent with a modal")
                if class_name == "XLMAIN" and enabled:
                    has_enabled_excel_root = True
                top_level_hwnds.append(hwnd)
            if not top_level_windows:
                _fail(
                    f"{item_path}.window_observation.top_level_windows",
                    "must be nonempty and contain an enabled XLMAIN root",
                )
            if not has_enabled_excel_root:
                _fail(
                    f"{item_path}.window_observation.top_level_windows",
                    "must contain at least one enabled XLMAIN root",
                )
            if top_level_hwnds != sorted(top_level_hwnds) or len(top_level_hwnds) != len(
                set(top_level_hwnds)
            ):
                _fail(
                    f"{item_path}.window_observation.top_level_windows",
                    "must be sorted and unique by HWND",
                )
            if len(top_level_windows) > owned_window_count:
                _fail(item_path, "top-level window count exceeds owned-window count")
            workbooks = _expect_list(item["workbooks"], f"{item_path}.workbooks")
            workbook_count = _expect_int(
                item["workbook_count"], f"{item_path}.workbook_count", minimum=0
            )
            if workbook_count != len(workbooks):
                _fail(f"{item_path}.workbook_count", "does not match workbooks")
            for workbook_index, raw_workbook in enumerate(workbooks):
                workbook_path = f"{item_path}.workbooks[{workbook_index}]"
                workbook = _expect_dict(raw_workbook, workbook_path)
                _expect_exact_keys(
                    workbook, workbook_path, ["path", "full_name", "is_addin"]
                )
                _expect_string(workbook["path"], f"{workbook_path}.path", nonempty=False)
                _expect_string(workbook["full_name"], f"{workbook_path}.full_name")
                if _expect_bool(workbook["is_addin"], f"{workbook_path}.is_addin"):
                    _fail(workbook_path, "the sole harness workbook must not be an add-in")
            if disposition == "none" and workbooks:
                _fail(f"{item_path}.workbooks", "must be empty at a no-workbook checkpoint")
            if disposition == "expected_pathless_harness":
                if len(workbooks) != 1 or workbooks[0]["path"] != "":
                    _fail(
                        f"{item_path}.workbooks",
                        "must contain exactly one pathless harness workbook",
                    )
            if disposition == "exact_hash_pinned_harness":
                if len(workbooks) != 1 or not workbooks[0]["path"].strip():
                    _fail(
                        f"{item_path}.workbooks",
                        "must contain exactly one path-bound harness workbook",
                    )
                if ntpath.basename(workbooks[0]["full_name"]).casefold() != "member-oracle.xlsm":
                    _fail(
                        f"{item_path}.workbooks[0].full_name",
                        "must name the exact generated member-oracle workbook",
                    )
            startup_path = _expect_string(
                item["startup_path"], f"{item_path}.startup_path", nonempty=False
            )
            alt_startup_path = _expect_string(
                item["alt_startup_path"],
                f"{item_path}.alt_startup_path",
                nonempty=False,
            )
            if _expect_int(
                item["protected_view_window_count"],
                f"{item_path}.protected_view_window_count",
                minimum=0,
            ) != 0:
                _fail(item_path, "safe-mode capture must have no Protected View windows")
            com_addins_access = _expect_dict(
                item["com_addins_access"], f"{item_path}.com_addins_access"
            )
            _expect_exact_keys(
                com_addins_access,
                f"{item_path}.com_addins_access",
                [
                    "status",
                    "error_number",
                    "error_hex",
                    "inventory_complete",
                    "connection_state_claim",
                ],
            )
            access_status = _expect_string(
                com_addins_access["status"],
                f"{item_path}.com_addins_access.status",
            )
            access_error = _expect_int(
                com_addins_access["error_number"],
                f"{item_path}.com_addins_access.error_number",
            )
            access_hex = _expect_string(
                com_addins_access["error_hex"],
                f"{item_path}.com_addins_access.error_hex",
            )
            if access_hex != f"0x{access_error & 0xFFFFFFFF:08X}":
                _fail(
                    f"{item_path}.com_addins_access.error_hex",
                    "does not encode the recorded signed error number",
                )
            if access_status == "available":
                if (
                    access_error != 0
                    or not _expect_bool(
                        com_addins_access["inventory_complete"],
                        f"{item_path}.com_addins_access.inventory_complete",
                    )
                    or com_addins_access["connection_state_claim"] != "complete"
                ):
                    _fail(
                        f"{item_path}.com_addins_access",
                        "available COMAddIns access must be complete with zero error",
                    )
            elif access_status == "unavailable_exact_excel_error_nonclaim":
                if (
                    access_error != -2146827284
                    or _expect_bool(
                        com_addins_access["inventory_complete"],
                        f"{item_path}.com_addins_access.inventory_complete",
                    )
                    or com_addins_access["connection_state_claim"] != "not_made"
                ):
                    _fail(
                        f"{item_path}.com_addins_access",
                        "unavailable COMAddIns access must preserve exact 0x800A03EC and make no connection-state claim",
                    )
            else:
                _fail(
                    f"{item_path}.com_addins_access.status",
                    "must describe complete access or the exact Excel-error nonclaim",
                )
            com_addins = validate_com_addins(item["com_addins"], f"{item_path}.com_addins")
            if access_status != "available" and com_addins:
                _fail(
                    f"{item_path}.com_addins",
                    "must be empty when COMAddIns inventory is explicitly incomplete",
                )
            excel_addins = validate_excel_addins(
                item["excel_addins"], f"{item_path}.excel_addins"
            )
            excel_addins2 = validate_excel_addins(
                item["excel_addins2"], f"{item_path}.excel_addins2"
            )
            if _expect_list(
                item["loaded_xll_modules"], f"{item_path}.loaded_xll_modules"
            ):
                _fail(item_path, "safe-mode capture must have no loaded XLL modules")
            current_stable = {
                "startup_path": startup_path,
                "alt_startup_path": alt_startup_path,
                "com_addins_access": com_addins_access,
                "com_addins": com_addins,
                "excel_addins": excel_addins,
                "excel_addins2": excel_addins2,
            }
            if stable_inventory is None:
                stable_inventory = current_stable
            elif current_stable != stable_inventory:
                _fail(item_path, "safe-mode startup/add-in inventory drifted between checkpoints")
        return checks

    def validate_excel_identity(role: str) -> dict[str, Any]:
        identity = _expect_dict(capture[role], f"capture.{role}")
        _expect_exact_keys(identity, f"capture.{role}", excel_identity_keys)
        for key in (
            "path",
            "file_version",
            "product_version",
            "product_name",
            "company_name",
            "bitness",
        ):
            _expect_string(identity[key], f"capture.{role}.{key}")
        if re.split(r"[\\/]", identity["path"])[-1].casefold() != "excel.exe":
            _fail(f"capture.{role}.path", "must name EXCEL.EXE")
        if "microsoft" not in identity["company_name"].casefold():
            _fail(f"capture.{role}.company_name", "must identify Microsoft")
        if not (
            {"office", "excel"}
            & set(re.findall(r"[a-z]+", identity["product_name"].casefold()))
        ):
            _fail(
                f"capture.{role}.product_name",
                "must identify Microsoft Office or Excel",
            )
        process_start = _expect_utc_timestamp(
            identity["process_start_utc"],
            f"capture.{role}.process_start_utc",
        )
        if not started_at <= process_start <= completed_at:
            _fail(
                f"capture.{role}.process_start_utc",
                "must fall inside the capture interval for its dedicated Excel instance",
            )
        # The runner computes this against the live binary. Replay checks the
        # immutable recorded observation, not mutable machine state outside the repo.
        if not SHA256_RE.fullmatch(
            _expect_string(identity["sha256"], f"capture.{role}.sha256")
        ):
            _fail(f"capture.{role}.sha256", "must be lowercase SHA-256")
        _expect_int(identity["process_id"], f"capture.{role}.process_id", minimum=1)
        if identity["startup_mode"] != "safe":
            _fail(f"capture.{role}.startup_mode", "must be exactly 'safe'")
        launch_arguments = _expect_list(
            identity["launch_arguments"], f"capture.{role}.launch_arguments"
        )
        if launch_arguments != ["/safe"]:
            _fail(
                f"capture.{role}.launch_arguments",
                "must contain the sole exact /safe launch switch",
            )
        if (
            identity["containment_method"]
            != "create_process_suspended_then_job_object_kill_on_close"
        ):
            _fail(
                f"capture.{role}.containment_method",
                "must use suspended creation followed by verified kill-on-close Job containment",
            )
        if not _expect_bool(
            identity["containment_membership_verified"],
            f"capture.{role}.containment_membership_verified",
        ):
            _fail(
                f"capture.{role}.containment_membership_verified",
                "must affirm exact Job membership before resume",
            )
        exclusivity = _expect_dict(
            identity["process_exclusivity_observation"],
            f"capture.{role}.process_exclusivity_observation",
        )
        _expect_exact_keys(
            exclusivity,
            f"capture.{role}.process_exclusivity_observation",
            [
                "caller_snapshot_process_ids",
                "pre_create_process_ids",
                "post_create_process_ids",
            ],
        )
        for key in ("caller_snapshot_process_ids", "pre_create_process_ids"):
            if _expect_list(
                exclusivity[key],
                f"capture.{role}.process_exclusivity_observation.{key}",
            ):
                _fail(
                    f"capture.{role}.process_exclusivity_observation.{key}",
                    "must be empty",
                )
        post_create_ids = _expect_list(
            exclusivity["post_create_process_ids"],
            f"capture.{role}.process_exclusivity_observation.post_create_process_ids",
        )
        if post_create_ids != [identity["process_id"]]:
            _fail(
                f"capture.{role}.process_exclusivity_observation.post_create_process_ids",
                "must contain only the exact retained Excel process id",
            )
        if (
            identity["command_line_observation_method"]
            != "cim_win32_process_command_line_to_argv_w"
        ):
            _fail(
                f"capture.{role}.command_line_observation_method",
                "must use the pinned Win32_Process/CommandLineToArgvW observation",
            )
        observed_command_line = _expect_string(
            identity["observed_command_line"],
            f"capture.{role}.observed_command_line",
        )
        observed_argv = _expect_list(
            identity["observed_launch_argv"],
            f"capture.{role}.observed_launch_argv",
        )
        for index, value in enumerate(observed_argv):
            _expect_string(value, f"capture.{role}.observed_launch_argv[{index}]")
        independently_parsed_argv = _parse_windows_command_line(
            observed_command_line,
            f"capture.{role}.observed_command_line",
        )
        if observed_argv != independently_parsed_argv:
            _fail(
                f"capture.{role}.observed_launch_argv",
                "does not match independent replay parsing of the raw command line",
            )
        if len(observed_argv) != 2 or observed_argv[1] != "/safe":
            _fail(
                f"capture.{role}.observed_launch_argv",
                "must be the exact executable followed by the sole /safe switch",
            )
        if ntpath.normcase(ntpath.normpath(observed_argv[0])) != ntpath.normcase(
            ntpath.normpath(identity["path"])
        ):
            _fail(
                f"capture.{role}.observed_launch_argv[0]",
                "does not bind the observed command line to the recorded Excel binary",
            )
        if (
            identity["binding_method"]
            != "oleacc_accessible_object_from_window_excel7_objid_nativeom"
        ):
            _fail(
                f"capture.{role}.binding_method",
                "must use exact-PID EXCEL7 OBJID_NATIVEOM binding",
            )
        _expect_int(identity["binding_hwnd"], f"capture.{role}.binding_hwnd", minimum=1)
        owned_window_count = _expect_int(
            identity["owned_window_count_at_binding"],
            f"capture.{role}.owned_window_count_at_binding",
            minimum=1,
        )
        if owned_window_count > 512:
            _fail(
                f"capture.{role}.owned_window_count_at_binding",
                "exceeds the fail-closed exact-process enumeration bound",
            )
        startup = _expect_dict(
            identity["startup_workbook_observation"],
            f"capture.{role}.startup_workbook_observation",
        )
        _expect_exact_keys(
            startup,
            f"capture.{role}.startup_workbook_observation",
            [
                "initial_workbook_count",
                "initial_workbooks",
                "post_close_workbook_count",
            ],
        )
        initial_count = _expect_int(
            startup["initial_workbook_count"],
            f"capture.{role}.startup_workbook_observation.initial_workbook_count",
            minimum=0,
        )
        if initial_count > 1:
            _fail(
                f"capture.{role}.startup_workbook_observation.initial_workbook_count",
                "safe mode may expose at most one pathless startup workbook",
            )
        initial_workbooks = _expect_list(
            startup["initial_workbooks"],
            f"capture.{role}.startup_workbook_observation.initial_workbooks",
        )
        if len(initial_workbooks) != initial_count:
            _fail(
                f"capture.{role}.startup_workbook_observation.initial_workbooks",
                "does not match initial_workbook_count",
            )
        for index, raw_workbook in enumerate(initial_workbooks):
            workbook_path = (
                f"capture.{role}.startup_workbook_observation.initial_workbooks[{index}]"
            )
            workbook = _expect_dict(raw_workbook, workbook_path)
            _expect_exact_keys(workbook, workbook_path, ["path", "full_name", "is_addin"])
            if _expect_string(
                workbook["path"], f"{workbook_path}.path", nonempty=False
            ) != "":
                _fail(workbook_path, "safe-mode startup workbook must be pathless")
            _expect_string(workbook["full_name"], f"{workbook_path}.full_name")
            if _expect_bool(workbook["is_addin"], f"{workbook_path}.is_addin"):
                _fail(workbook_path, "safe-mode startup workbook must not be an add-in")
        if _expect_int(
            startup["post_close_workbook_count"],
            f"capture.{role}.startup_workbook_observation.post_close_workbook_count",
            minimum=0,
        ) != 0:
            _fail(
                f"capture.{role}.startup_workbook_observation.post_close_workbook_count",
                "must be zero before oracle workbook creation/open",
            )
        validate_isolation_checks(role, identity["isolation_checks"])
        return identity

    build_excel = validate_excel_identity("build_excel")
    excel = validate_excel_identity("excel")
    if build_excel["process_id"] == excel["process_id"]:
        _fail(
            "capture.build_excel.process_id",
            "phase 1 and phase 2 must use distinct dedicated Excel processes",
        )
    if os.path.normcase(os.path.abspath(build_excel["path"])) != os.path.normcase(
        os.path.abspath(excel["path"])
    ):
        _fail(
            "capture.build_excel.path",
            "phase 1 and phase 2 must bind the same Excel binary",
        )
    for key in (
        "file_version",
        "product_version",
        "product_name",
        "company_name",
        "sha256",
        "bitness",
    ):
        if build_excel[key] != excel[key]:
            _fail(
                f"capture.build_excel.{key}",
                "phase 1 and phase 2 Excel binary identities differ",
            )
    for binary_name in ("vbe", "fm20"):
        binary = _expect_dict(capture[binary_name], f"capture.{binary_name}")
        _expect_exact_keys(binary, f"capture.{binary_name}", ["path", "file_version", "product_version", "sha256"])
        for key in ("path", "file_version", "product_version"):
            _expect_string(binary[key], f"capture.{binary_name}.{key}")
        leaf = re.split(r"[\\/]", binary["path"])[-1]
        if binary_name == "fm20" and leaf.casefold() != "fm20.dll":
            _fail("capture.fm20.path", "must name FM20.DLL")
        if binary_name == "vbe" and not re.fullmatch(r"(?i:VBE[0-9]*\.DLL)", leaf):
            _fail("capture.vbe.path", "must name a VBE*.DLL binary")
        digest = _expect_string(binary["sha256"], f"capture.{binary_name}.sha256")
        # These are capture-time environment observations. Replay validates the
        # preserved shape and digest without requiring Office to remain installed
        # at the same absolute path (or forbidding a later Office update).
        if not SHA256_RE.fullmatch(digest):
            _fail(f"capture.{binary_name}.sha256", "must be lowercase SHA-256")

    artifacts = _expect_dict(capture["artifacts"], "capture.artifacts")
    required_artifacts = {
        "workbook",
        "form_export",
        "frx_export",
        "probe_results",
        "event_log",
        "screenshot",
        "window_manifest",
        "generated_form_code",
        "generated_module_code",
        "normalized_manifest",
        "capture_command",
        "capture_progress",
        "capture_attributes",
        "generator_command",
        "generator_stdout",
        "generator_stderr",
        "window_stdout",
        "window_stderr",
        "macro_watchdog",
        "readme",
    }
    _expect_exact_keys(artifacts, "capture.artifacts", required_artifacts)
    artifact_caps = {
        "workbook": 64 * 1024 * 1024,
        "form_export": 16 * 1024 * 1024,
        "frx_export": 32 * 1024 * 1024,
        "screenshot": 16 * 1024 * 1024,
    }
    resolved_artifacts: dict[str, Path] = {}
    retained_artifacts: dict[str, bytes] = {}
    for name, artifact in artifacts.items():
        artifact_path, artifact_bytes = _artifact_snapshot(
            repo_root,
            capture_dir,
            artifact,
            f"capture.artifacts.{name}",
            max_bytes=artifact_caps.get(name, 8 * 1024 * 1024),
        )
        resolved_artifacts[name] = artifact_path
        retained_artifacts[name] = artifact_bytes
    if len(set(resolved_artifacts.values())) != len(resolved_artifacts):
        _fail("capture.artifacts", "distinct artifact roles must not alias one file")
    warnings = _expect_list(capture["warnings"], "capture.warnings")
    non_claims = _expect_list(capture["non_claims"], "capture.non_claims")
    if not warnings or non_claims != manifest["non_claims"]:
        _fail("capture", "warnings/nonclaims are incomplete or drifted")
    for index, warning in enumerate(warnings):
        _expect_string(warning, f"capture.warnings[{index}]")
    incomplete_com_addins = any(
        not check["com_addins_access"]["inventory_complete"]
        for identity in (build_excel, excel)
        for check in identity["isolation_checks"]
    )
    warning_present = COM_ADDINS_CAPTURE_WARNING in warnings
    if incomplete_com_addins != warning_present:
        _fail(
            "capture.warnings",
            "must disclose incomplete COMAddIns authority exactly when a checkpoint makes no connection-state claim",
        )
    try:
        capture_readme = retained_artifacts["readme"].decode("utf-8")
    except UnicodeDecodeError as exc:
        _fail("capture.artifacts.readme", f"cannot read UTF-8 capture README: {exc}")
    readme_warning_present = COM_ADDINS_CAPTURE_WARNING in capture_readme
    if incomplete_com_addins != readme_warning_present:
        _fail(
            "capture.artifacts.readme",
            "must disclose the exact incomplete COMAddIns connection-state nonclaim exactly when authority is incomplete",
        )
    if sha256_bytes(retained_artifacts["workbook"]) == preopen_workbook_sha256:
        _fail(
            "capture.preopen_workbook_sha256",
            "final evidence workbook must differ from the pre-execution workbook",
        )
    try:
        watchdog_lines = retained_artifacts["macro_watchdog"].decode(
            "utf-8"
        ).splitlines()
    except UnicodeDecodeError as exc:
        _fail("capture.artifacts.macro_watchdog", f"cannot read UTF-8 watchdog log: {exc}")
    watchdog_record_specs = (
        ("build_phase", "ARMED", build_excel, "disarm"),
        ("build_phase", "DISARMED", build_excel, "explicit_disarm"),
        ("build_shutdown", "ARMED", build_excel, "expected_exit"),
        ("build_shutdown", "PROCESS_EXITED", build_excel, "expected_exit"),
        ("live_phase", "ARMED", excel, "disarm"),
        ("run_member_oracle", "ARMED", excel, "disarm"),
        ("run_member_oracle", "DISARMED", excel, "explicit_disarm"),
        ("read_harness_error", "ARMED", excel, "disarm"),
        ("read_harness_error", "DISARMED", excel, "explicit_disarm"),
        ("close_member_oracle", "ARMED", excel, "disarm"),
        ("close_member_oracle", "DISARMED", excel, "explicit_disarm"),
        ("live_phase", "DISARMED", excel, "explicit_disarm"),
        ("live_shutdown", "ARMED", excel, "expected_exit"),
        ("live_shutdown", "PROCESS_EXITED", excel, "expected_exit"),
    )
    if len(watchdog_lines) != len(watchdog_record_specs):
        _fail(
            "capture.artifacts.macro_watchdog",
            "successful capture must preserve the exact guarded build/live phase, "
            "VBA entry-point, and expected-shutdown transcript",
        )
    watchdog_timestamps: list[datetime] = []
    watchdog_timeouts: dict[str, int] = {}
    for index, (operation, record_kind, identity, terminal_detail) in enumerate(
        watchdog_record_specs
    ):
        if record_kind == "ARMED":
            record = re.fullmatch(
                rf"(\S+) ARMED operation={operation} pid=([1-9][0-9]*) "
                rf"timeout_seconds=([1-9][0-9]*) terminal_mode={terminal_detail}",
                watchdog_lines[index],
            )
        else:
            record = re.fullmatch(
                rf"(\S+) {record_kind} operation={operation} pid=([1-9][0-9]*) "
                rf"reason={terminal_detail}",
                watchdog_lines[index],
            )
        if record is None:
            _fail(
                "capture.artifacts.macro_watchdog",
                f"watchdog record {index + 1} is not the exact successful {record_kind} "
                f"record for {operation}",
            )
        observed_at = _expect_utc_timestamp(
            record.group(1),
            f"macro_watchdog.{operation}.{record_kind.casefold()}_at_utc",
        )
        if not started_at <= observed_at <= completed_at:
            _fail(
                "capture.artifacts.macro_watchdog",
                "watchdog timestamps must fall inside the capture interval",
            )
        watchdog_timestamps.append(observed_at)
        if int(record.group(2)) != identity["process_id"]:
            _fail(
                "capture.artifacts.macro_watchdog",
                f"watchdog operation {operation!r} does not bind its captured Excel process",
            )
        if record_kind == "ARMED":
            timeout_seconds = int(record.group(3))
            if operation in {"build_shutdown", "live_shutdown"}:
                if timeout_seconds != 15:
                    _fail(
                        "capture.artifacts.macro_watchdog",
                        "expected-shutdown watchdog timeout must be exactly 15 seconds",
                    )
            elif operation in {"build_phase", "live_phase"}:
                if not 60 <= timeout_seconds <= 1200:
                    _fail(
                        "capture.artifacts.macro_watchdog",
                        "outer COM-phase watchdog timeout is outside its bounded policy",
                    )
            elif not 10 <= timeout_seconds <= 300:
                _fail(
                    "capture.artifacts.macro_watchdog",
                    "VBA entry-point watchdog timeout is outside its bounded policy",
                )
            watchdog_timeouts[operation] = timeout_seconds
    if watchdog_timestamps != sorted(watchdog_timestamps):
        _fail(
            "capture.artifacts.macro_watchdog",
            "watchdog records must be globally time-ordered",
        )
    macro_timeouts = {
        watchdog_timeouts[operation]
        for operation in (
            "run_member_oracle",
            "read_harness_error",
            "close_member_oracle",
        )
    }
    if len(macro_timeouts) != 1:
        _fail(
            "capture.artifacts.macro_watchdog",
            "all VBA entry points must share one exact timeout policy",
        )
    expected_normalized = canonical_json_bytes(manifest)
    expected_form = generate_form_code(manifest).encode("utf-8")
    expected_module = generate_module_code(manifest).encode("utf-8")
    # Generate twice in memory so accidental nondeterminism cannot be hidden by
    # merely updating the captured hashes.
    if expected_form != generate_form_code(manifest).encode("utf-8") or expected_module != generate_module_code(manifest).encode("utf-8"):
        _fail("capture.artifacts", "VBA source generation is nondeterministic")
    replay_bytes = {
        "normalized_manifest": expected_normalized,
        "generated_form_code": expected_form,
        "generated_module_code": expected_module,
    }
    for role, expected_bytes in replay_bytes.items():
        actual_bytes = retained_artifacts[role]
        if actual_bytes != expected_bytes:
            _fail(f"capture.artifacts.{role}", "does not byte-match deterministic regeneration")
    frm_module = _load_python_module_bytes(
        executable_tool_bytes["frm_inventory"],
        tool_snapshots_by_role["frm_inventory"],
        "oxforms_oracle_frm_inventory",
    )
    cfb_module = _load_python_module_bytes(
        executable_tool_bytes["cfb_inventory"],
        tool_snapshots_by_role["cfb_inventory"],
        "oxforms_oracle_cfb_inventory",
    )
    png_width, png_height = _png_dimensions(
        resolved_artifacts["screenshot"],
        retained_bytes=retained_artifacts["screenshot"],
    )
    workbook_tables = _validate_xlsm_package(
        resolved_artifacts["workbook"],
        manifest["capture"]["result_sheet"],
        manifest["capture"]["event_sheet"],
        {
            manifest["capture"]["result_sheet"]: (
                1 + sum(step["kind"] == "probe" for step in manifest["steps"]),
                len(RESULT_HEADERS),
            ),
            manifest["capture"]["event_sheet"]: (
                1 + sum(event["expected_occurrences"] for event in manifest["events"]),
                len(EVENT_HEADERS),
            ),
        },
        {
            RUNTIME_MODULE_NAME: (
                "Module",
                expected_module.decode("utf-8"),
            ),
            manifest["form"]["name"]: (
                "BaseClass",
                expected_form.decode("utf-8"),
            ),
        },
        cfb_module,
        retained_package_bytes=retained_artifacts["workbook"],
    )
    if not retained_artifacts["frx_export"]:
        _fail("capture.artifacts.frx_export", "must be nonempty")
    try:
        frm_inventory = frm_module.inventory_frm(
            retained_artifacts["form_export"],
            capture["platform"].get("ansi_code_page", 1252),
            profile=frm_module.OFFICE_VBA_USERFORM_EXPORT,
        )
        cfb_inventory = cfb_module.inventory_cfb(retained_artifacts["frx_export"])
    except Exception as exc:
        _fail("capture.artifacts.form_export", f"strict FRM/FRX inventory failed: {exc}")
    if frm_inventory.get("root", {}).get("name") != manifest["form"]["name"]:
        _fail("capture.artifacts.form_export", "strict inventory root name does not match the manifest")
    if frm_inventory.get("root", {}).get("guid", "").casefold() != "c62a69f0-16dc-11ce-9e98-00aa00574a4f":
        _fail("capture.artifacts.form_export", "strict inventory root is not an Office VBA UserForm")
    root_properties = {
        prop.get("name"): prop.get("parsed_value")
        for prop in frm_inventory.get("root_properties", [])
    }
    if root_properties.get("Caption") != manifest["form"]["caption"]:
        _fail("capture.artifacts.form_export", "exported caption does not match the manifest")
    if root_properties.get("StartUpPosition") != manifest["form"]["startup_position"]:
        _fail("capture.artifacts.form_export", "exported StartUpPosition does not match the manifest")
    attributes = {
        attribute.get("name"): attribute.get("parsed_value")
        for attribute in frm_inventory.get("class_header", {}).get("attributes", [])
    }
    if (
        attributes.get("VB_Name") != manifest["form"]["name"]
        or attributes.get("VB_PredeclaredId") is not True
        or attributes.get("VB_Exposed") is not False
    ):
        _fail("capture.artifacts.form_export", "exported class header identity is inconsistent")
    code_span = frm_inventory.get("code_body", {}).get("span", {})
    code_start = code_span.get("byte_start")
    code_end = code_span.get("byte_end")
    if type(code_start) is not int or type(code_end) is not int or code_start < 0 or code_end < code_start:
        _fail("capture.artifacts.form_export", "strict inventory code-body span is invalid")
    frm_bytes = retained_artifacts["form_export"]
    try:
        exported_code = frm_bytes[code_start:code_end].decode(
            f"cp{capture['platform']['ansi_code_page']}"
        )
    except (LookupError, UnicodeDecodeError) as exc:
        _fail("capture.artifacts.form_export", f"cannot decode exported code body: {exc}")
    normalized_exported_code = exported_code.replace("\r\n", "\n").replace("\r", "\n")
    if normalized_exported_code.endswith("\n\n"):
        # VBIDE adds one terminal blank separator line to exported UserForm
        # code regardless of the AddFromString input.  Tolerate exactly that
        # known export transform; all other source bytes remain exact.
        normalized_exported_code = normalized_exported_code[:-1]
    if normalized_exported_code != expected_form.decode("utf-8"):
        _fail("capture.artifacts.form_export", "exported code body does not match generated form code")
    _validate_frm_frx_siblings(
        resolved_artifacts["form_export"], resolved_artifacts["frx_export"]
    )
    _validate_frx_reference(
        frm_inventory.get("external_resource_references", []),
        resolved_artifacts["frx_export"].name,
    )
    if (
        cfb_inventory.get("signature_offset") != 24
        or cfb_inventory.get("cfb_length") != len(retained_artifacts["frx_export"]) - 24
        or len(cfb_inventory.get("entries", [])) < 3
    ):
        _fail("capture.artifacts.frx_export", "strict CFB inventory is not a complete Office FRX container")

    results = _expect_dict(
        load_json_bytes(
            retained_artifacts["probe_results"], resolved_artifacts["probe_results"]
        ),
        "results",
    )
    success_count, error_count = _validate_results(results, manifest, manifest_sha)
    events_doc = _expect_dict(
        load_json_bytes(
            retained_artifacts["event_log"], resolved_artifacts["event_log"]
        ),
        "events",
    )
    event_count = _validate_events(events_doc, manifest, manifest_sha)
    result_headers = list(RESULT_HEADERS)
    event_headers = list(EVENT_HEADERS)

    def expected_workbook_table(
        headers: list[str], rows: list[dict[str, Any]]
    ) -> list[list[str]]:
        table = [headers]
        for row in rows:
            rendered: list[str] = []
            for header in headers:
                value = row[header]
                if type(value) is int:
                    rendered.append(str(value))
                elif type(value) is str:
                    rendered.append(value)
                else:
                    _fail(
                        "capture.artifacts.workbook",
                        f"JSON field {header!r} cannot be represented in the evidence worksheet",
                    )
            table.append(rendered)
        return table

    for sheet_name, headers, rows in (
        (manifest["capture"]["result_sheet"], result_headers, results["rows"]),
        (manifest["capture"]["event_sheet"], event_headers, events_doc["rows"]),
    ):
        expected_table = expected_workbook_table(headers, rows)
        actual_table = workbook_tables[sheet_name]
        if actual_table != expected_table:
            mismatch = "table dimensions differ"
            for row_index in range(min(len(actual_table), len(expected_table))):
                for column_index in range(
                    min(len(actual_table[row_index]), len(expected_table[row_index]))
                ):
                    if (
                        actual_table[row_index][column_index]
                        != expected_table[row_index][column_index]
                    ):
                        mismatch = (
                            f"cell row {row_index + 1}, column {column_index + 1} "
                            f"is {actual_table[row_index][column_index]!r}, "
                            f"expected {expected_table[row_index][column_index]!r}"
                        )
                        break
                if mismatch != "table dimensions differ":
                    break
            _fail(
                "capture.artifacts.workbook",
                f"worksheet {sheet_name!r} does not byte-semantically match its JSON rows: {mismatch}",
            )
    timeline = [
        _int_from_capture(row["sequence"], "timeline.sequence")
        for row in results["rows"] + events_doc["rows"]
    ]
    if sorted(timeline) != list(range(1, len(timeline) + 1)):
        _fail("capture.timeline", "probe/event sequences must form one unique contiguous global timeline")
    _validate_event_timeline(results["rows"], events_doc["rows"], manifest)
    window_manifest = _expect_dict(
        load_json_bytes(
            retained_artifacts["window_manifest"],
            resolved_artifacts["window_manifest"],
        ),
        "window_manifest",
    )
    _expect_exact_keys(
        window_manifest,
        "window_manifest",
        [
            "schema",
            "tool",
            "mode",
            "timestamp_utc",
            "command",
            "host",
            "query",
            "status",
            "diagnostics",
            "visible_top_level_window_count",
            "match_count",
            "candidates",
            "selected_window",
            "screenshot",
            "manifest_path",
        ],
    )
    if window_manifest.get("schema") != "oxforms.office_oracle.window_capture.v1":
        _fail("window_manifest.schema", "unexpected screenshot manifest schema")
    if (
        window_manifest["tool"] != "tools/office-oracle/Capture-Window.ps1"
        or window_manifest["mode"] != "capture"
    ):
        _fail("window_manifest", "must identify the exact production capture tool/mode")
    window_at = _expect_utc_timestamp(
        window_manifest["timestamp_utc"], "window_manifest.timestamp_utc"
    )
    if not started_at <= window_at <= completed_at:
        _fail("window_manifest.timestamp_utc", "must fall inside the capture interval")
    _expect_string(window_manifest["command"], "window_manifest.command")
    window_host = _expect_dict(window_manifest["host"], "window_manifest.host")
    _expect_exact_keys(window_host, "window_manifest.host", ["os", "is_windows", "powershell"])
    if window_host["is_windows"] is not True:
        _fail("window_manifest.host.is_windows", "screenshot capture must run on Windows")
    _expect_string(window_host["os"], "window_manifest.host.os")
    _expect_string(window_host["powershell"], "window_manifest.host.powershell")
    expected_window_query = {
        "title_contains": manifest["form"]["caption"],
        "process_name": "EXCEL",
        "process_contains": "",
        "process_id": excel["process_id"],
        "class_name": "ThunderDFrame",
    }
    if window_manifest["query"] != expected_window_query:
        _fail("window_manifest.query", "does not bind the exact caption and live Excel PID")
    if window_manifest.get("status") != "ok" or window_manifest.get("match_count") != 1:
        _fail("window_manifest", "must identify exactly one successful target window")
    diagnostics = _expect_list(window_manifest["diagnostics"], "window_manifest.diagnostics")
    if diagnostics:
        _fail("window_manifest.diagnostics", "successful screenshot capture must be warning-free")
    _expect_int(
        window_manifest["visible_top_level_window_count"],
        "window_manifest.visible_top_level_window_count",
        minimum=1,
    )
    candidates = _expect_list(window_manifest["candidates"], "window_manifest.candidates")
    if len(candidates) != 1:
        _fail("window_manifest.candidates", "must preserve exactly the selected candidate")
    selected = _expect_dict(window_manifest.get("selected_window"), "window_manifest.selected_window")
    _expect_exact_keys(
        selected,
        "window_manifest.selected_window",
        [
            "handle",
            "title",
            "class_name",
            "process_id",
            "process_name",
            "process_path",
            "process_start_time_utc",
            "bounds",
            "dpi",
        ],
    )
    if selected.get("title") != manifest["form"]["caption"] or selected.get("class_name") != "ThunderDFrame" or selected.get("process_name") != "EXCEL":
        _fail("window_manifest.selected_window", "does not bind the exact live MSForms UserForm")
    if re.fullmatch(r"0x[1-9A-F][0-9A-F]*", _expect_string(selected["handle"], "window_manifest.selected_window.handle")) is None:
        _fail("window_manifest.selected_window.handle", "must be a nonzero canonical HWND")
    if _int_from_capture(selected.get("process_id"), "window_manifest.selected_window.process_id") != excel["process_id"]:
        _fail("window_manifest.selected_window.process_id", "does not bind the captured Excel instance")
    if selected["process_start_time_utc"] != excel["process_start_utc"]:
        _fail(
            "window_manifest.selected_window.process_start_time_utc",
            "does not bind the captured Excel process start identity",
        )
    _expect_utc_timestamp(
        selected["process_start_time_utc"],
        "window_manifest.selected_window.process_start_time_utc",
    )
    _expect_int(selected["dpi"], "window_manifest.selected_window.dpi", minimum=1)
    selected_process_path = _expect_string(
        selected.get("process_path"), "window_manifest.selected_window.process_path"
    )
    windows_path_key = lambda value: value.replace("/", "\\").casefold()
    if windows_path_key(selected_process_path) != windows_path_key(excel["path"]):
        _fail("window_manifest.selected_window.process_path", "does not bind the captured Excel binary")
    screenshot_meta = _expect_dict(window_manifest.get("screenshot"), "window_manifest.screenshot")
    _expect_exact_keys(
        screenshot_meta,
        "window_manifest.screenshot",
        [
            "path",
            "sha256",
            "width",
            "height",
            "format",
            "capture_method",
            "visual_review_required",
            "state_bracket",
            "attempts",
        ],
    )
    if screenshot_meta.get("format") != "png" or screenshot_meta.get("sha256") != sha256_bytes(retained_artifacts["screenshot"]):
        _fail("window_manifest.screenshot", "format/hash does not bind the captured PNG")
    if re.split(r"[\\/]", _expect_string(screenshot_meta["path"], "window_manifest.screenshot.path"))[-1] != "window-capture.png":
        _fail("window_manifest.screenshot.path", "must name the canonical screenshot leaf")
    if screenshot_meta["capture_method"] != "screen_coordinates":
        _fail(
            "window_manifest.screenshot.capture_method",
            "must identify the coordinate-based CopyFromScreen observation",
        )
    if _expect_bool(
        screenshot_meta["visual_review_required"],
        "window_manifest.screenshot.visual_review_required",
    ) is not True:
        _fail(
            "window_manifest.screenshot.visual_review_required",
            "must remain true for coordinate-based screenshot evidence",
        )
    screenshot_attempts = _expect_list(
        screenshot_meta["attempts"], "window_manifest.screenshot.attempts"
    )
    if not 1 <= len(screenshot_attempts) <= 6:
        _fail("window_manifest.screenshot.attempts", "must preserve one to six bounded attempts")
    for attempt_index, attempt_value in enumerate(screenshot_attempts, start=1):
        attempt = _expect_dict(
            attempt_value, f"window_manifest.screenshot.attempts[{attempt_index - 1}]"
        )
        if attempt.get("status") == "ok":
            _expect_exact_keys(
                attempt,
                f"window_manifest.screenshot.attempts[{attempt_index - 1}]",
                ["attempt", "status", "foreground_attempt"],
            )
            if attempt_index != len(screenshot_attempts):
                _fail(
                    "window_manifest.screenshot.attempts",
                    "only the final bounded attempt may succeed",
                )
            _expect_foreground_attempt(
                attempt["foreground_attempt"],
                f"window_manifest.screenshot.attempts[{attempt_index - 1}].foreground_attempt",
            )
        elif attempt.get("status") == "error":
            _expect_exact_keys(
                attempt,
                f"window_manifest.screenshot.attempts[{attempt_index - 1}]",
                ["attempt", "status", "message"],
            )
            _expect_string(
                attempt["message"],
                f"window_manifest.screenshot.attempts[{attempt_index - 1}].message",
            )
        else:
            _fail(
                f"window_manifest.screenshot.attempts[{attempt_index - 1}].status",
                "must be error or ok",
            )
        if _int_from_capture(
            attempt["attempt"],
            f"window_manifest.screenshot.attempts[{attempt_index - 1}].attempt",
        ) != attempt_index:
            _fail("window_manifest.screenshot.attempts", "attempt numbers must be contiguous")
    if screenshot_attempts[-1]["status"] != "ok":
        _fail("window_manifest.screenshot.attempts", "final bounded attempt must succeed")
    if _int_from_capture(screenshot_meta.get("width"), "window_manifest.screenshot.width") != png_width or _int_from_capture(screenshot_meta.get("height"), "window_manifest.screenshot.height") != png_height:
        _fail("window_manifest.screenshot", "declared dimensions do not match PNG IHDR")
    bounds = _expect_dict(selected.get("bounds"), "window_manifest.selected_window.bounds")
    _expect_exact_keys(
        bounds,
        "window_manifest.selected_window.bounds",
        ["left", "top", "right", "bottom", "width", "height"],
    )
    bound_values = {
        key: _int_from_capture(
            bounds[key], f"window_manifest.selected_window.bounds.{key}"
        )
        for key in ("left", "top", "right", "bottom", "width", "height")
    }
    if (
        bound_values["right"] - bound_values["left"] != bound_values["width"]
        or bound_values["bottom"] - bound_values["top"] != bound_values["height"]
        or bound_values["width"] <= 0
        or bound_values["height"] <= 0
    ):
        _fail("window_manifest.selected_window.bounds", "bounds geometry is incoherent")
    if _int_from_capture(bounds.get("width"), "window_manifest.selected_window.bounds.width") != png_width or _int_from_capture(bounds.get("height"), "window_manifest.selected_window.bounds.height") != png_height:
        _fail("window_manifest.selected_window.bounds", "window bounds do not match screenshot dimensions")
    state_bracket = _expect_dict(
        screenshot_meta["state_bracket"], "window_manifest.screenshot.state_bracket"
    )
    _expect_exact_keys(
        state_bracket,
        "window_manifest.screenshot.state_bracket",
        ["comparator", "before", "after"],
    )
    if state_bracket["comparator"] != "exact_selected_current_v1":
        _fail(
            "window_manifest.screenshot.state_bracket.comparator",
            "must identify the exact selected/current comparator",
        )
    bracket_states: list[dict[str, Any]] = []
    for phase in ("before", "after"):
        state_path = f"window_manifest.screenshot.state_bracket.{phase}"
        state = _expect_dict(state_bracket[phase], state_path)
        _expect_exact_keys(
            state,
            state_path,
            [
                "handle",
                "title",
                "class_name",
                "process_id",
                "process_name",
                "process_start_time_utc",
                "process_path",
                "bounds",
                "visible",
                "foreground",
            ],
        )
        for field in ("handle", "title", "class_name", "process_start_time_utc"):
            if _expect_string(state[field], f"{state_path}.{field}") != selected[field]:
                _fail(f"{state_path}.{field}", "does not exactly match the selected window")
        if _int_from_capture(state["process_id"], f"{state_path}.process_id") != _int_from_capture(
            selected["process_id"], "window_manifest.selected_window.process_id"
        ):
            _fail(f"{state_path}.process_id", "does not match the selected window")
        if _expect_string(state["process_name"], f"{state_path}.process_name").casefold() != _expect_string(
            selected["process_name"], "window_manifest.selected_window.process_name"
        ).casefold():
            _fail(f"{state_path}.process_name", "does not match the selected process")
        if windows_path_key(
            _expect_string(state["process_path"], f"{state_path}.process_path")
        ) != windows_path_key(selected_process_path):
            _fail(f"{state_path}.process_path", "does not match the selected executable")
        _expect_utc_timestamp(state["process_start_time_utc"], f"{state_path}.process_start_time_utc")
        state_bounds = _expect_dict(state["bounds"], f"{state_path}.bounds")
        _expect_exact_keys(
            state_bounds,
            f"{state_path}.bounds",
            ["left", "top", "right", "bottom", "width", "height"],
        )
        for field, selected_value in bound_values.items():
            if _int_from_capture(state_bounds[field], f"{state_path}.bounds.{field}") != selected_value:
                _fail(f"{state_path}.bounds.{field}", "does not match the selected bounds")
        if _expect_bool(state["visible"], f"{state_path}.visible") is not True:
            _fail(f"{state_path}.visible", "must remain true across the screen read")
        if _expect_bool(state["foreground"], f"{state_path}.foreground") is not True:
            _fail(f"{state_path}.foreground", "must remain true across the screen read")
        bracket_states.append(state)
    if bracket_states[0] != bracket_states[1]:
        _fail(
            "window_manifest.screenshot.state_bracket",
            "before/after observations must be exactly stable across CopyFromScreen",
        )
    expected_candidate = {
        key: selected[key]
        for key in (
            "handle",
            "title",
            "class_name",
            "process_id",
            "process_name",
            "bounds",
        )
    }
    if candidates[0] != expected_candidate:
        _fail("window_manifest.candidates", "candidate summary does not exactly bind the selected window")
    if re.split(
        r"[\\/]",
        _expect_string(window_manifest["manifest_path"], "window_manifest.manifest_path"),
    )[-1] != "window-capture-manifest.json":
        _fail("window_manifest.manifest_path", "must name the canonical manifest leaf")

    coverage = _expect_dict(capture["observed_coverage"], "capture.observed_coverage")
    _expect_exact_keys(
        coverage,
        "capture.observed_coverage",
        ["control_families", "probe_count", "success_count", "error_count", "event_row_count", "screenshot_count", "export_pair_count"],
    )
    if sorted(coverage["control_families"]) != sorted({control["fm20_type"] for control in manifest["form"]["controls"]}):
        _fail("capture.observed_coverage.control_families", "does not match manifest control families")
    expected_coverage = {
        "probe_count": len([step for step in manifest["steps"] if step["kind"] == "probe"]),
        "success_count": success_count,
        "error_count": error_count,
        "event_row_count": event_count,
        "screenshot_count": 1,
        "export_pair_count": 1,
    }
    for key, expected in expected_coverage.items():
        if _int_from_capture(coverage[key], f"capture.observed_coverage.{key}") != expected:
            _fail(f"capture.observed_coverage.{key}", f"expected {expected}")

    provenance = _expect_dict(capture["provenance"], "capture.provenance")
    _expect_exact_keys(provenance, "capture.provenance", ["observation_source", "oxforms_output_paths", "clean_room_basis", "prohibited"])
    if provenance != manifest["provenance"]:
        _fail("capture.provenance", "must exactly preserve the manifest provenance boundary")
    # Recheck the complete tree after all parsing/execution. Every parser above
    # consumed a retained, checksum-bound byte snapshot; this final comparison
    # additionally rejects persistent tree/manifest drift during validation.
    final_checksum_entries, final_checksum_bytes = _validate_checksum_manifest(
        capture_dir
    )
    if (
        final_checksum_entries != checksum_entries
        or final_checksum_bytes != checksum_bytes
    ):
        _fail("checksums.sha256", "checksum manifest changed during replay")
    if _read_bound_file(
        resolved_manifest_path,
        "manifest",
        expected_sha256=manifest_sha,
        max_bytes=4 * 1024 * 1024,
    ) != manifest_bytes:
        _fail("manifest", "source manifest bytes changed during replay")
    return {
        "probes": expected_coverage["probe_count"],
        "successes": success_count,
        "errors": error_count,
        "events": event_count,
    }


def _repo_root_from_script() -> Path:
    return Path(__file__).resolve().parents[2]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=_repo_root_from_script())
    parser.add_argument("--expected-self-sha256")
    sub = parser.add_subparsers(dest="command", required=True)
    freeze = sub.add_parser("freeze-ledger-snapshot")
    freeze.add_argument("--manifest", type=Path, required=True)
    freeze.add_argument("--output", type=Path, required=True)
    verify_snapshot = sub.add_parser("verify-current-ledger-snapshot")
    verify_snapshot.add_argument("--manifest", type=Path, required=True)
    validate = sub.add_parser("validate-manifest")
    validate.add_argument("--manifest", type=Path, required=True)
    generate = sub.add_parser("generate")
    generate.add_argument("--manifest", type=Path, required=True)
    generate.add_argument("--output-dir", type=Path, required=True)
    capture = sub.add_parser("validate-capture")
    capture.add_argument("--manifest", type=Path, required=True)
    capture.add_argument("--capture-dir", type=Path, required=True)
    preopen = sub.add_parser("validate-preopen-workbook")
    preopen.add_argument("--manifest", type=Path, required=True)
    preopen.add_argument("--workbook", type=Path, required=True)
    preopen.add_argument("--cfb-validator", type=Path, required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    repo_root = args.repo_root.resolve()
    try:
        if args.expected_self_sha256 is not None:
            expected_self_sha256 = _expect_string(
                args.expected_self_sha256, "expected_self_sha256"
            )
            if not SHA256_RE.fullmatch(expected_self_sha256):
                _fail(
                    "expected_self_sha256",
                    "must be a lowercase SHA-256 digest",
                )
            self_path = Path(os.path.abspath(__file__))
            if self_path.is_symlink() or self_path.is_junction():
                _fail("expected_self_sha256", "executing script is a reparse path")
            if self_path.stat().st_nlink != 1:
                _fail("expected_self_sha256", "executing script is hard-linked")
            if sha256_file(self_path) != expected_self_sha256:
                _fail(
                    "expected_self_sha256",
                    "executing script bytes do not match the caller's pin",
                )
        if args.command == "freeze-ledger-snapshot":
            result = freeze_ledger_snapshot(args.manifest, args.output, repo_root)
            print(json.dumps({"status": "ok", **result}, separators=(",", ":")))
        elif args.command == "verify-current-ledger-snapshot":
            result = verify_current_ledger_snapshot(args.manifest, repo_root)
            print(json.dumps({"status": "ok", **result}, separators=(",", ":")))
        elif args.command == "validate-manifest":
            manifest = validate_manifest(args.manifest, repo_root)
            print(
                json.dumps(
                    {
                        "status": "ok",
                        "manifest_id": manifest["id"],
                        "controls": len(manifest["form"]["controls"]),
                        "probes": len([step for step in manifest["steps"] if step["kind"] == "probe"]),
                        "events": len(manifest["events"]),
                    },
                    separators=(",", ":"),
                )
            )
        elif args.command == "generate":
            outputs = generate_sources(args.manifest, args.output_dir, repo_root)
            print(json.dumps(outputs, separators=(",", ":")))
        elif args.command == "validate-capture":
            counts = validate_capture(args.capture_dir, args.manifest, repo_root)
            print(json.dumps({"status": "ok", **counts}, separators=(",", ":")))
        elif args.command == "validate-preopen-workbook":
            result = validate_preopen_workbook(
                args.workbook,
                args.manifest,
                args.cfb_validator,
                repo_root,
            )
            print(json.dumps({"status": "ok", **result}, separators=(",", ":")))
        else:
            raise AssertionError(args.command)
    except OracleValidationError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
