"""Deterministic facts for real Office/VBIDE ``.frm``/``.frx`` exports.

This module joins three deliberately separate evidence classes:

* normative MS-OVBA/MS-VBAL text grammar copied from pinned source rows;
* byte-exact observations from a controlled public ``VBComponent.Export`` run;
* MS-OFORMS persistence names and cached identifiers from the preceding W010
  fact pack.

The joins are explicit.  In particular, a textual Office UserForm export is
not treated as the nested ``Begin MSForms.*`` dialect used by the repository's
older synthetic fixtures, and an opaque byte in an FRX is never promoted to a
decoded MS-OFORMS field merely because a property was set before export.
"""

from __future__ import annotations

import copy
from datetime import datetime, timezone
import hashlib
import json
import math
import re
import stat
import subprocess
from collections import Counter, defaultdict
from pathlib import Path, PurePosixPath, PureWindowsPath
from typing import Any, Iterable

from cfb_inventory import CFBError, inventory_cfb_file
from frm_text_inventory import (
    FRMError,
    LEGACY_SYNTHETIC_NESTED,
    OFFICE_VBA_USERFORM_EXPORT,
    inventory_frm_file,
)


FACT_SCHEMA = "oxforms.forms-persistence.export-facts.v1"
PIN_SCHEMA = "oxforms.forms-persistence.pinned-sources.v1"
EXPECTED_SCHEMA = "oxforms.forms-persistence.expected-capture.v1"
CAPTURE_SCHEMA = "oxforms.forms-persistence.live-export-capture.v2"
CAPTURE_SPEC_SCHEMA = "oxforms.forms-persistence.capture-spec.v1"
DESIGNER_ADD_REJECTED_HRESULT = "0x80070057"
USERFORM_CLSID = "C62A69F0-16DC-11CE-9E98-00AA00574A4F"
EXPORTER_ATTRIBUTION_BASIS = (
    "Unique loaded Excel-process module whose ModuleName matches VBE[0-9]*.DLL."
)
EXPORTER_CLAIM_SCOPE = (
    "Exact loaded VBE binary identity; this does not independently prove "
    "which binary owns VBComponent.Export."
)
DIRECT_MODULE_PATH_RESOLUTION = (
    "module_reported_path_is_directly_readable",
    "Bytes were hashed from the exact path reported by the loaded Excel process module.",
)
CLICK_TO_RUN_MODULE_PATH_RESOLUTION = (
    "office_click_to_run_vfs_common_files_backing",
    "The loaded module path was not directly readable; bytes were hashed from the "
    "unique deterministic Click-to-Run VFS backing path under the frozen Excel "
    "Office root.",
)
FILE_ATTRIBUTE_REPARSE_POINT = getattr(
    stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x00000400
)

TOP_LEVEL_KEYS = {
    "boundaries",
    "binary_persistence_contract",
    "canonical_sha256",
    "cfb_source_rules",
    "cfb_inventories",
    "code_boundaries",
    "component_headers",
    "control_identifiers",
    "coverage",
    "designer_properties",
    "fixtures",
    "generator",
    "grammar",
    "legacy_synthetic_corpus",
    "profiles",
    "property_mappings",
    "resource_references",
    "schema",
    "schema_version",
    "source_rows",
    "sources",
    "summary",
    "unknown_preservation",
}

DESIGNER_PROPERTY_SPECS: tuple[dict[str, Any], ...] = (
    {"production": "DesignerCaption", "name": "Caption", "lexical": "DQUOTE *130QUOTEDCHAR DQUOTE", "section": "2.3.5.2", "default": None},
    {"production": "DesignerHeight", "name": "ClientHeight", "lexical": "FLOAT", "section": "2.3.5.3", "default": None},
    {"production": "DesignerLeft", "name": "ClientLeft", "lexical": "FLOAT", "section": "2.3.5.4", "default": None},
    {"production": "DesignerTop", "name": "ClientTop", "lexical": "FLOAT", "section": "2.3.5.5", "default": None},
    {"production": "DesignerWidth", "name": "ClientWidth", "lexical": "FLOAT", "section": "2.3.5.6", "default": None},
    {"production": "DesignerEnabled", "name": "Enabled", "lexical": "VBABOOL", "section": "2.3.5.7", "default": True},
    {"production": "DesignerHelpContextId", "name": "HelpContextID", "lexical": "INT32", "section": "2.3.5.8", "default": None},
    {"production": "DesignerRTL", "name": "RightToLeft", "lexical": "VBABOOL", "section": "2.3.5.9", "default": None},
    {"production": "DesignerShowModal", "name": "ShowModal", "lexical": "VBABOOL", "section": "2.3.5.10", "default": True},
    {"production": "DesignerStartupPosition", "name": "StartUpPosition", "lexical": '"0" / "1" / "2" / "3"', "section": "2.3.5.11", "default": None},
    {"production": "DesignerTag", "name": "Tag", "lexical": "DQUOTE *130QUOTEDCHAR DQUOTE", "section": "2.3.5.12", "default": None},
    {"production": "DesignerTypeInfoVer", "name": "TypeInfoVer", "lexical": "INT32", "section": "2.3.5.13", "default": 0},
    {"production": "DesignerVisible", "name": "Visible", "lexical": "VBABOOL", "section": "2.3.5.14", "default": True},
    {"production": "DesignerWhatsThisButton", "name": "WhatsThisButton", "lexical": "VBABOOL", "section": "2.3.5.15", "default": False},
    {"production": "DesignerWhatsThisHelp", "name": "WhatsThisHelp", "lexical": "VBABOOL", "section": "2.3.5.16", "default": None},
)

UNKNOWN_POLICIES: tuple[dict[str, str], ...] = (
    {"class": "unknown_outer_property", "surface": "frm", "read": "preserve raw line, order, indentation, comment, and byte span", "write": "emit preserved bytes or reject a lossy rewrite"},
    {"class": "unknown_outer_value_lexeme", "surface": "frm", "read": "preserve the exact value slice", "write": "do not normalize an unrecognized lexeme"},
    {"class": "unknown_designer_block", "surface": "frm", "read": "preserve the balanced raw block only in its declared profile", "write": "reject cross-profile promotion"},
    {"class": "module_attribute_header", "surface": "frm", "read": "preserve ordered attribute lines and exact boundary", "write": "emit losslessly or reject"},
    {"class": "opaque_code_body", "surface": "frm", "read": "preserve all bytes after the class-header boundary", "write": "never parse assignment-shaped code as designer metadata"},
    {"class": "unsafe_external_resource_path", "surface": "frm", "read": "inventory without dereferencing", "write": "reject traversal, rooted, drive, UNC, alternate-stream, or non-basename paths"},
    {"class": "frx_prefix_before_cfb", "surface": "frx", "read": "preserve exact bytes without field interpretation", "write": "round-trip exact bytes or reject"},
    {"class": "unknown_cfb_storage", "surface": "frx", "read": "preserve directory metadata and descendants", "write": "round-trip or reject"},
    {"class": "unknown_cfb_stream", "surface": "frx", "read": "preserve exact stream bytes and path", "write": "round-trip or reject"},
    {"class": "allocated_cfb_sector_slack", "surface": "frx", "read": "hash every allocated sector in full, including bytes outside logical structure and stream lengths", "write": "preserve exact sector bytes or reject a lossy rewrite"},
    {"class": "allocated_mini_sector_slack", "surface": "frx", "read": "hash every allocated mini-sector in full, including bytes after a logical stream tail", "write": "preserve exact mini-sector bytes or reject a lossy rewrite"},
    {"class": "unallocated_cfb_sector", "surface": "frx", "read": "inventory exact byte region", "write": "preserve in lossless mode; canonical writers may reject with an explicit policy"},
    {"class": "unallocated_mini_sector", "surface": "frx", "read": "inventory exact mini-stream region", "write": "preserve in lossless mode; canonical writers may reject with an explicit policy"},
    {"class": "trailing_frx_bytes", "surface": "frx", "read": "preserve exact bytes", "write": "round-trip or reject"},
    {"class": "documented_ms_oforms_unknown", "surface": "frx", "read": "retain the preceding fact-pack unknown classification", "write": "apply its documented preserve/ignore rule; never invent semantics"},
)

# Complete, explicitly reviewed selection of fields whose own or directly
# linked MS-OFORMS definitions control byte extents, string
# count/compression, serialized structural-array counts, or variable resource
# payload lengths. Runtime property
# counts such as ColumnCount/TabsAllocated are deliberately not
# reclassified as binary layout lengths; they remain in the complete pinned
# .3 record-field/property universe.
BINARY_LENGTH_FIELD_GROUPS: dict[
    str, tuple[tuple[str, str, str], ...]
] = {
    "aggregate_record_byte_lengths": (
        ("2.2.1.1", "CommandButtonControl", "cbCommandButton"),
        ("2.2.3.1", "ImageControl", "cbImage"),
        ("2.2.4.1", "LabelControl", "cbLabel"),
        ("2.2.5.1", "MorphDataControl", "cbMorphData"),
        ("2.2.5.6", "MorphDataColumnInfo", "cbColumnInfo"),
        ("2.2.6.1", "MultiPageProperties", "cbMultiPageControlProperties"),
        ("2.2.6.4.1", "PageProperties", "cbPage"),
        ("2.2.7.1", "ScrollBarControl", "cbScrollBar"),
        ("2.2.8.1", "SpinButtonControl", "cbSpinButton"),
        ("2.2.9.1", "TabStripControl", "cbTabStrip"),
        ("2.2.10.1", "FormControl", "cbForm"),
        ("2.2.10.10.1", "SiteClassInfo", "cbClassTable"),
        ("2.2.10.11.1", "DesignExtender", "cbDesignExtender"),
        ("2.2.10.12.1", "OleSiteConcreteControl", "cbSite"),
        ("2.3.1", "TextProps", "cbTextProps"),
    ),
    "string_count_and_compression_fields": (
        ("2.2.1.3", "CommandButtonDataBlock", "Caption"),
        ("2.2.4.3", "LabelDataBlock", "Caption"),
        ("2.2.5.3", "MorphDataDataBlock", "Value"),
        ("2.2.5.3", "MorphDataDataBlock", "Caption"),
        ("2.2.5.3", "MorphDataDataBlock", "GroupName"),
        ("2.2.10.3", "FormDataBlock", "LengthAndCompression"),
        ("2.2.10.12.3", "SiteDataBlock", "NameData"),
        ("2.2.10.12.3", "SiteDataBlock", "TagData"),
        ("2.2.10.12.3", "SiteDataBlock", "ControlTipTextData"),
        ("2.2.10.12.3", "SiteDataBlock", "RuntimeLicKeyData"),
        ("2.2.10.12.3", "SiteDataBlock", "ControlSourceData"),
        ("2.2.10.12.3", "SiteDataBlock", "RowSourceData"),
        ("2.3.3", "TextPropsDataBlock", "FontName"),
        ("2.4.14.1", "ArrayString", "CountAndCompression"),
    ),
    "variable_region_byte_lengths": (
        ("2.2.9.3", "TabStripDataBlock", "ItemsSize"),
        ("2.2.9.3", "TabStripDataBlock", "TipStringsSize"),
        ("2.2.9.3", "TabStripDataBlock", "NamesSize"),
        ("2.2.9.3", "TabStripDataBlock", "TagsSize"),
        ("2.2.9.3", "TabStripDataBlock", "AcceleratorsSize"),
        ("2.2.10.6", "FormSiteData", "CountOfBytes"),
        ("2.2.10.12.3", "SiteDataBlock", "ObjectStreamSize"),
    ),
    "collection_counts": (
        ("2.2.5.3", "MorphDataDataBlock", "cColumnInfo"),
        ("2.2.6.3", "MultiPagePropertiesDataBlock", "PageCount"),
        ("2.2.9.3", "TabStripDataBlock", "TabData"),
        ("2.2.10.6", "FormSiteData", "CountOfSiteClassInfo"),
        ("2.2.10.6", "FormSiteData", "CountOfSites"),
    ),
    "resource_payload_lengths": (
        ("2.4.12", "StdFont", "bFaceLen"),
        ("2.4.13", "StdPicture", "Size"),
    ),
}

BINARY_LENGTH_CODEC_NAMES = (
    "Strings",
    "ArrayString",
    "CountOfBytesWithCompressionFlag",
    "CountOfCharsWithCompressionFlag",
)

# Exact semantic pins for each source-linked binary-contract projection. Counts
# alone are intentionally insufficient: a same-sized substitution must not be
# able to turn a different MS-OFORMS row into accepted normative evidence.
BINARY_CONTRACT_SURFACE_DIGESTS = {
    "object_properties": "8d00c5fa5b5393826477c2bcf82ecb52a90428318268be96fb3a87a236aaae27",
    "object_types": "934eb2f78789ca688c1026b62a476a524eb22921821329bcb0bb202f58e350ef",
    "object_formats": "56b7c2e6e1045fef8fab70eecc1483aa6947d2da2f5bae8779bb1ce1cc844148",
    "stream_slots": "f7e71ed1a7516f6b2ff1e61e9ff5ca629a45295716e8b7db2d8b944be0e4e4ed",
    "presence_flags": "f8efd7d52acf0d09e954cd988bb1d9f483202b09d4849754f898f9295dffe4f8",
    "property_defaults": "8b32cb60313edd831f32954f1d187b13024139f6167d09769865f65fbba57aed",
    "default_matrix": "ffbfcba3b5eba6c432207d17c2006d128cf44468412bea73456ce13868af51d9",
    "property_masks": "6bea1423480d0e9d00e0d3249b75a49a31287581f842561d4f706edccf6cee68",
    "storage_requirements": "627b821efae961af63e5dd0ac1971576d9ddc3e65c9546d33583b21563b57e5c",
    "length_fields": "a58cda1eb97b69f45944309c0655e8dd03bb38cd890f18965586a7ea6565954d",
    "length_codecs": "7d5c51ca2cab8cf65d79ade1069ad16bac6337721ea326edb735395129904486",
}

BINARY_SOURCE_UNIVERSE_COUNTS = {
    "bitfields": 28,
    "cached_control_ids": 16,
    "control_families": 11,
    "default_matrix": 107,
    "documented_unknowns": 179,
    "properties": 98,
    "property_types": 18,
    "record_fields": 431,
    "record_sections": 90,
    "resource_formats": 10,
}


class FactError(ValueError):
    """Raised when source, fixture, or generated facts violate the contract."""


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise FactError(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


def _reject_nonfinite(value: str) -> None:
    raise FactError(f"non-finite JSON number is forbidden: {value}")


def load_json_strict(path: Path) -> Any:
    try:
        value = json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=_reject_duplicate_keys,
            parse_constant=_reject_nonfinite,
        )
    except UnicodeDecodeError as exc:
        raise FactError(f"{path} is not UTF-8: {exc}") from exc
    _validate_finite(value, str(path))
    return value


def _validate_finite(value: Any, location: str) -> None:
    if isinstance(value, float) and not math.isfinite(value):
        raise FactError(f"non-finite number at {location}")
    if isinstance(value, dict):
        for key, child in value.items():
            _validate_finite(child, f"{location}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            _validate_finite(child, f"{location}[{index}]")


def _walk_strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, child in value.items():
            yield key
            yield from _walk_strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_strings(child)


def canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            allow_nan=False,
            indent=2,
            sort_keys=True,
            separators=(",", ": "),
        )
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def semantic_sha256(pack: dict[str, Any]) -> str:
    semantic = copy.deepcopy(pack)
    semantic.pop("canonical_sha256", None)
    return sha256_bytes(canonical_json_bytes(semantic))


def _require_keys(value: dict[str, Any], expected: set[str], where: str) -> None:
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        raise FactError(f"{where} keys differ; missing={missing}, extra={extra}")


def _require_relative_repo_path(text: str, where: str) -> PurePosixPath:
    if not isinstance(text, str) or not text:
        raise FactError(f"{where} is not a non-empty path string")
    path = PurePosixPath(text)
    if (
        path.is_absolute()
        or ".." in path.parts
        or "\\" in text
        or path.as_posix() != text
        or ":" in text
        or any(ord(character) < 32 or ord(character) == 127 for character in text)
    ):
        raise FactError(f"{where} is not a safe repository-relative POSIX path: {text!r}")
    return path


def _is_reparse_point(path: Path) -> bool:
    if path.is_symlink():
        return True
    try:
        attributes = path.lstat().st_file_attributes
    except (AttributeError, FileNotFoundError):
        return False
    except OSError:
        # An existing path whose metadata cannot be inspected is not safe to
        # accept as an ordinary file/directory in a self-pinned evidence tree.
        return True
    return bool(attributes & FILE_ATTRIBUTE_REPARSE_POINT)


def _reject_reparse_path(repo_root: Path, path: Path, where: str) -> None:
    try:
        relative = path.absolute().relative_to(repo_root.absolute())
    except ValueError as exc:
        raise FactError(f"{where} escaped the repository") from exc
    cursor = repo_root.absolute()
    for part in relative.parts:
        cursor /= part
        if _is_reparse_point(cursor):
            raise FactError(f"{where} traverses a symlink/reparse point: {cursor}")


def _canonical_lf(raw: bytes) -> bytes:
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise FactError(f"canonical UTF-8/LF source is not UTF-8: {exc}") from exc
    return text.replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")


def load_pins(path: Path) -> dict[str, Any]:
    pins = load_json_strict(path)
    if not isinstance(pins, dict) or pins.get("schema") != PIN_SCHEMA:
        raise FactError(f"unexpected pin schema in {path}")
    _require_keys(pins, {"schema", "foundation", "local_dependencies"}, "pins")
    return pins


def _verify_length_hash(path: Path, length: int, sha256: str, where: str) -> bytes:
    if not path.is_file():
        raise FactError(f"missing {where}: {path}")
    raw = path.read_bytes()
    if len(raw) != length:
        raise FactError(f"{where} length drift: expected {length}, got {len(raw)}")
    actual = sha256_bytes(raw)
    if actual != sha256:
        raise FactError(f"{where} SHA-256 drift: expected {sha256}, got {actual}")
    return raw


def _git(repo: Path, *arguments: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *arguments],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if result.returncode != 0:
        raise FactError(
            f"git {' '.join(arguments)} failed in {repo}: {result.stderr.strip()}"
        )
    return result.stdout.strip()


def verify_foundation(repo_root: Path, pins: dict[str, Any], *, require_clean: bool) -> Path:
    foundation_pin = pins["foundation"]
    foundation = (repo_root / foundation_pin["repo_path"]).resolve()
    expected_commit = foundation_pin["expected_commit"]
    if _git(foundation, "rev-parse", "HEAD") != expected_commit:
        raise FactError("Foundation HEAD does not match the pinned commit")
    if require_clean and _git(foundation, "status", "--porcelain"):
        raise FactError("Foundation working tree is dirty; source-required validation refuses it")
    for artifact in foundation_pin["artifacts"]:
        relative = _require_relative_repo_path(artifact["path"], artifact["source_id"])
        path = foundation / Path(*relative.parts)
        raw = path.read_bytes() if path.is_file() else b""
        if not raw:
            raise FactError(f"missing or empty pinned Foundation artifact: {path}")
        if artifact["hash_mode"] == "raw":
            if len(raw) != artifact["length"] or sha256_bytes(raw) != artifact["sha256"]:
                raise FactError(f"raw Foundation artifact drift: {artifact['source_id']}")
        elif artifact["hash_mode"] == "canonical_utf8_lf":
            if len(raw) != artifact["raw_length"] or sha256_bytes(raw) != artifact["raw_sha256"]:
                raise FactError(f"raw normalized-source drift: {artifact['source_id']}")
            if sha256_bytes(_canonical_lf(raw)) != artifact["sha256"]:
                raise FactError(f"canonical normalized-source drift: {artifact['source_id']}")
        else:
            raise FactError(f"unsupported Foundation hash mode: {artifact['hash_mode']}")
        # Prove the pinned commit, not merely the checkout, owns the same bytes.
        blob = subprocess.run(
            ["git", "-C", str(foundation), "show", f"{expected_commit}:{artifact['path']}"],
            check=False,
            capture_output=True,
        )
        blob_matches = (
            blob.stdout == raw
            if artifact["hash_mode"] == "raw"
            else _canonical_lf(blob.stdout) == _canonical_lf(raw)
        )
        if blob.returncode != 0 or not blob_matches:
            raise FactError(f"artifact is not the exact pinned-commit blob: {artifact['source_id']}")
    return foundation


def verify_local_dependencies(repo_root: Path, pins: dict[str, Any]) -> dict[str, dict[str, Any]]:
    loaded: dict[str, dict[str, Any]] = {}
    for pin in pins["local_dependencies"]:
        relative = _require_relative_repo_path(pin["path"], pin["source_id"])
        path = repo_root / Path(*relative.parts)
        _verify_length_hash(path, pin["length"], pin["sha256"], pin["source_id"])
        value = load_json_strict(path) if path.suffix == ".json" else None
        if "semantic_sha256" in pin:
            if not isinstance(value, dict):
                raise FactError(f"semantic dependency is not a JSON object: {pin['source_id']}")
            discovered = (
                value.get("capture", {}).get("semantic_sha256")
                or value.get("canonical_sha256")
            )
            if discovered != pin["semantic_sha256"]:
                raise FactError(f"semantic digest drift: {pin['source_id']}")
        loaded[pin["source_id"]] = {"pin": pin, "path": path, "value": value}
    return loaded


def _load_selected_source_rows(foundation: Path, pins: dict[str, Any]) -> list[dict[str, Any]]:
    artifact_by_id = {row["source_id"]: row for row in pins["foundation"]["artifacts"]}
    selected: list[dict[str, Any]] = []
    for source_id, ranges in pins["foundation"]["selected_segments"].items():
        artifact = artifact_by_id[source_id]
        path = foundation / Path(*PurePosixPath(artifact["path"]).parts)
        rows = [
            json.loads(line, object_pairs_hook=_reject_duplicate_keys, parse_constant=_reject_nonfinite)
            for line in _canonical_lf(path.read_bytes()).decode("utf-8").splitlines()
        ]
        for selection in ranges:
            first, last = selection["first"], selection["last"]
            if first < 1 or last < first or last > len(rows):
                raise FactError(f"invalid selected range for {source_id}: {first}-{last}")
            for row_number in range(first, last + 1):
                record = copy.deepcopy(rows[row_number - 1])
                if isinstance(record.get("source"), dict):
                    record["source"].pop("local_path", None)
                selected.append(
                    {
                        "source_id": source_id,
                        "row_number": row_number,
                        "purpose": selection["purpose"],
                        "record": record,
                    }
                )
    return selected


def _public_sources(pins: dict[str, Any], local: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    sources: list[dict[str, Any]] = []
    local_authority_classes = {
        "MS-CFB-DOCX": "authoritative_protocol_document",
        "MS-CFB-SELECTED-ROWS": "pinned_normalized_extraction",
        "MS-CFB-EXTRACTOR": "deterministic_extraction_tool",
        "MS-CFB-SELECTED-RULES": "project_interpretation",
    }
    for artifact in pins["foundation"]["artifacts"]:
        row = {key: value for key, value in artifact.items() if key != "path"}
        row["path_from_oxforms"] = f"../Foundation/{artifact['path']}"
        row["authority_class"] = (
            "authoritative_protocol_document"
            if artifact["source_id"].endswith(("DOCX", "PDF"))
            else "pinned_normalized_extraction"
        )
        sources.append(row)
    for source_id, item in sorted(local.items()):
        pin = item["pin"]
        sources.append(
            {
                "source_id": source_id,
                "path_from_oxforms": pin["path"],
                "length": pin["length"],
                "sha256": pin["sha256"],
                "semantic_sha256": pin.get("semantic_sha256"),
                "authority_class": (
                    "observed_real_office_export"
                    if source_id == "LIVE-EXPORT-CAPTURE-MANIFEST"
                    else local_authority_classes.get(
                        source_id, "pinned_local_dependency"
                    )
                ),
            }
        )
    return sources


def _expected_observed_value(kind: str, value: Any) -> dict[str, Any]:
    if kind == "string":
        return {"kind": "string", "value": str(value)}
    if kind == "boolean":
        if not isinstance(value, bool):
            raise FactError(f"boolean capture value is not boolean: {value!r}")
        return {"kind": "boolean", "value": value}
    if kind in {"int16", "int32"}:
        if isinstance(value, bool) or not isinstance(value, int):
            raise FactError(f"integer capture value is not integer: {value!r}")
        lower, upper = (
            (-32768, 32767)
            if kind == "int16"
            else (-2147483648, 2147483647)
        )
        if not lower <= value <= upper:
            raise FactError(f"{kind} capture value is out of range: {value!r}")
        return {"kind": "integer", "value": value}
    if kind == "single":
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise FactError(f"single capture value is not numeric: {value!r}")
        number = float(value)
        return {
            "kind": "number",
            "value": number,
            "invariant": format(number, ".15g"),
        }
    raise FactError(f"unsupported capture-spec value kind: {kind!r}")


def _validate_observed_value(value: dict[str, Any], where: str) -> None:
    if not isinstance(value, dict) or "kind" not in value:
        raise FactError(f"{where} is not a typed observed value")
    kind = value["kind"]
    expected_keys = {
        "null": {"kind", "value"},
        "boolean": {"kind", "value"},
        "string": {"kind", "value"},
        "integer": {"kind", "value"},
        "number": {"kind", "value", "invariant"},
        "com_object": {"kind", "value"},
        "other": {"kind", "value", "dotnet_type"},
    }
    if kind not in expected_keys:
        raise FactError(f"{where} has unsupported observed kind {kind!r}")
    _require_keys(value, expected_keys[kind], where)
    observed = value["value"]
    valid = {
        "null": observed is None,
        "boolean": isinstance(observed, bool),
        "string": isinstance(observed, str),
        "integer": isinstance(observed, int) and not isinstance(observed, bool),
        "number": isinstance(observed, (int, float)) and not isinstance(observed, bool),
        "com_object": observed is None,
        "other": isinstance(observed, str),
    }[kind]
    if not valid:
        raise FactError(f"{where} value does not match kind {kind!r}")
    if kind == "number":
        invariant = value["invariant"]
        if not isinstance(invariant, str) or not invariant:
            raise FactError(f"{where}.invariant is not a non-empty numeric string")
        try:
            parsed = float(invariant)
        except ValueError as exc:
            raise FactError(f"{where}.invariant is not numeric") from exc
        if not math.isfinite(parsed) or parsed != float(observed):
            raise FactError(f"{where}.invariant differs from its numeric value")
    elif kind == "other":
        if not isinstance(value["dotnet_type"], str) or not value["dotnet_type"]:
            raise FactError(f"{where}.dotnet_type is not a non-empty string")


def _validate_probe_binding(
    expected: dict[str, Any],
    actual: dict[str, Any],
    where: str,
) -> None:
    _require_keys(expected, {"name", "kind", "value", "required"}, f"{where} spec")
    _require_keys(
        actual,
        {"name", "requested", "required", "readback", "succeeded", "error", "hresult"},
        f"{where} observation",
    )
    if not isinstance(expected["required"], bool):
        raise FactError(f"{where} spec required flag is not boolean")
    if not isinstance(actual["required"], bool):
        raise FactError(f"{where} observation required flag is not boolean")
    if actual["name"] != expected["name"]:
        raise FactError(f"{where} name differs from capture spec")
    requested = _expected_observed_value(expected["kind"], expected["value"])
    if actual["requested"] != requested:
        raise FactError(f"{where} requested value differs from capture spec")
    if actual["required"] is not expected["required"]:
        raise FactError(f"{where} required flag differs from capture spec")
    _validate_observed_value(actual["requested"], f"{where}.requested")
    _validate_observed_value(actual["readback"], f"{where}.readback")
    if not isinstance(actual["succeeded"], bool):
        raise FactError(f"{where} succeeded flag is not boolean")
    if actual["succeeded"]:
        if actual["error"] is not None or actual["hresult"] is not None:
            raise FactError(f"{where} succeeded but retained error data")
    else:
        if not isinstance(actual["error"], str) or not actual["error"]:
            raise FactError(f"{where} failed without an error message")
        if not isinstance(actual["hresult"], str) or re.fullmatch(
            r"0x[0-9A-F]{8}", actual["hresult"]
        ) is None:
            raise FactError(f"{where} failed without a canonical HRESULT")
    if expected["required"] and not actual["succeeded"]:
        raise FactError(f"required capture probe failed: {where}")


def _unique_sequence(rows: list[dict[str, Any]], key: str, where: str) -> list[Any]:
    values = [row[key] for row in rows]
    if len(values) != len(set(values)):
        raise FactError(f"duplicate {where} {key}")
    return values


def _validated_exported_files(
    rows: Any,
    where: str,
) -> dict[str, dict[str, Any]]:
    if not isinstance(rows, list) or len(rows) != 2:
        raise FactError(f"{where} must contain exactly one .frm and one .frx row")
    by_suffix: dict[str, dict[str, Any]] = {}
    seen_paths: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise FactError(f"{where}[{index}] is not an object")
        _require_keys(row, {"path", "length", "sha256"}, f"{where}[{index}]")
        relative = _require_relative_repo_path(row["path"], f"{where}[{index}].path")
        if relative.as_posix() in seen_paths:
            raise FactError(f"{where} contains a duplicate exported path")
        seen_paths.add(relative.as_posix())
        if (
            isinstance(row["length"], bool)
            or not isinstance(row["length"], int)
            or row["length"] <= 0
        ):
            raise FactError(f"{where}[{index}].length is not a positive integer")
        if (
            not isinstance(row["sha256"], str)
            or re.fullmatch(r"[0-9a-f]{64}", row["sha256"]) is None
        ):
            raise FactError(f"{where}[{index}].sha256 is not canonical SHA-256")
        suffix = relative.suffix.lower()
        if suffix not in {".frm", ".frx"} or suffix in by_suffix:
            raise FactError(f"{where} must contain exactly one .frm and one .frx row")
        by_suffix[suffix] = row
    if set(by_suffix) != {".frm", ".frx"}:
        raise FactError(f"{where} must contain exactly one .frm and one .frx row")
    return by_suffix


def _validate_pinned_binary_identity(value: Any, where: str) -> None:
    if not isinstance(value, dict):
        raise FactError(f"{where} is not an object")
    _require_keys(
        value,
        {"module_name", "length", "sha256", "file_version", "product_version"},
        where,
    )
    if (
        not isinstance(value["module_name"], str)
        or re.fullmatch(r"(?i:VBE[0-9]*\.DLL)", value["module_name"]) is None
        or isinstance(value["length"], bool)
        or not isinstance(value["length"], int)
        or value["length"] <= 0
        or not isinstance(value["sha256"], str)
        or re.fullmatch(r"[0-9a-f]{64}", value["sha256"]) is None
        or not all(
            isinstance(value[key], str) and value[key]
            for key in ("file_version", "product_version")
        )
    ):
        raise FactError(f"{where} is malformed")


def _validate_frozen_capture_identity(
    identity: Any,
    capture_id: str,
    where: str,
) -> None:
    if not isinstance(identity, dict):
        raise FactError(f"{where} is not an object")
    _require_keys(
        identity,
        {
            "capture_date_utc",
            "output_directory",
            "excel_executable",
            "excel_automation",
            "vbe_binary",
        },
        where,
    )
    capture_date = identity["capture_date_utc"]
    if (
        not isinstance(capture_date, str)
        or re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", capture_date) is None
    ):
        raise FactError(f"{where}.capture_date_utc is not YYYY-MM-DD")
    try:
        datetime.strptime(capture_date, "%Y-%m-%d")
    except ValueError as exc:
        raise FactError(f"{where}.capture_date_utc is not a real calendar date") from exc
    date_token = capture_date.replace("-", "")
    output = _require_relative_repo_path(
        identity["output_directory"], f"{where}.output_directory"
    )
    if date_token not in capture_id or date_token not in output.name:
        raise FactError(f"{where} date is not bound to capture id/output directory")

    executable = identity["excel_executable"]
    if not isinstance(executable, dict):
        raise FactError(f"{where}.excel_executable is not an object")
    _require_keys(
        executable,
        {"length", "sha256", "file_version", "product_version"},
        f"{where}.excel_executable",
    )
    if (
        isinstance(executable["length"], bool)
        or not isinstance(executable["length"], int)
        or executable["length"] <= 0
        or not isinstance(executable["sha256"], str)
        or re.fullmatch(r"[0-9a-f]{64}", executable["sha256"]) is None
        or not all(
            isinstance(executable[key], str) and executable[key]
            for key in ("file_version", "product_version")
        )
    ):
        raise FactError(f"{where}.excel_executable is malformed")
    expected_output_name = f"{date_token}-excel-{executable['file_version']}"
    if output.name != expected_output_name:
        raise FactError(
            f"{where}.output_directory is not bound to frozen Excel version"
        )

    automation = identity["excel_automation"]
    if not isinstance(automation, dict):
        raise FactError(f"{where}.excel_automation is not an object")
    _require_keys(
        automation,
        {"version", "build", "vbe_version"},
        f"{where}.excel_automation",
    )
    if not all(isinstance(automation[key], str) and automation[key] for key in automation):
        raise FactError(f"{where}.excel_automation is malformed")
    _validate_pinned_binary_identity(identity["vbe_binary"], f"{where}.vbe_binary")


def _validate_exporter_binary_identity(
    value: Any,
    frozen: dict[str, Any],
    excel_path: PureWindowsPath,
    where: str,
) -> None:
    if not isinstance(value, dict):
        raise FactError(f"{where} is not an object")
    status = value.get("status")
    if status == "identified_loaded_vbe_binary":
        _require_keys(
            value,
            {
                "status",
                "host_process_id",
                "attribution_basis",
                "claim_scope",
                "binary",
            },
            where,
        )
        if (
            isinstance(value["host_process_id"], bool)
            or not isinstance(value["host_process_id"], int)
            or value["host_process_id"] <= 0
            or value["attribution_basis"] != EXPORTER_ATTRIBUTION_BASIS
            or value["claim_scope"] != EXPORTER_CLAIM_SCOPE
        ):
            raise FactError(f"{where} identified status is malformed")
        binary = value["binary"]
        if not isinstance(binary, dict):
            raise FactError(f"{where}.binary is not an object")
        _require_keys(
            binary,
            {
                "module_name",
                "module_reported_path",
                "path",
                "path_resolution_basis",
                "path_resolution_caveat",
                "length",
                "sha256",
                "file_version",
                "product_version",
                "original_filename",
            },
            f"{where}.binary",
        )
        pinned_projection = {
            key: binary[key]
            for key in ("module_name", "length", "sha256", "file_version", "product_version")
        }
        _validate_pinned_binary_identity(pinned_projection, f"{where}.binary")
        if pinned_projection != frozen["vbe_binary"]:
            raise FactError(f"{where}.binary differs from frozen VBE identity")
        if not all(
            isinstance(binary[key], str) and binary[key]
            for key in (
                "module_reported_path",
                "path",
                "path_resolution_basis",
                "path_resolution_caveat",
            )
        ) or (
            binary["original_filename"] is not None
            and (
                not isinstance(binary["original_filename"], str)
                or not binary["original_filename"]
            )
        ):
            raise FactError(f"{where}.binary path/name facts are malformed")
        reported_path = PureWindowsPath(binary["module_reported_path"])
        binary_path = PureWindowsPath(binary["path"])
        if (
            not reported_path.is_absolute()
            or not binary_path.is_absolute()
            or reported_path.name.upper() != binary["module_name"].upper()
            or binary_path.name.upper() != binary["module_name"].upper()
        ):
            raise FactError(f"{where}.binary path/name facts are malformed")
        if (
            binary["original_filename"] is not None
            and binary["original_filename"].upper()
            != binary["module_name"].upper()
        ):
            raise FactError(f"{where}.binary original filename differs from module")
        resolution = (
            binary["path_resolution_basis"],
            binary["path_resolution_caveat"],
        )
        if resolution not in {
            DIRECT_MODULE_PATH_RESOLUTION,
            CLICK_TO_RUN_MODULE_PATH_RESOLUTION,
        }:
            raise FactError(f"{where}.binary path-resolution facts are unsupported")
        if resolution == DIRECT_MODULE_PATH_RESOLUTION and binary_path != reported_path:
            raise FactError(f"{where}.binary direct path resolution differs")
        if (
            resolution == CLICK_TO_RUN_MODULE_PATH_RESOLUTION
            and binary_path == reported_path
        ):
            raise FactError(f"{where}.binary Click-to-Run backing path was not distinct")
        if resolution == CLICK_TO_RUN_MODULE_PATH_RESOLUTION:
            office_root = excel_path.parent.parent
            root_parts = tuple(part.casefold() for part in office_root.parts)
            backing_parts = tuple(part.casefold() for part in binary_path.parts)
            if backing_parts[: len(root_parts)] != root_parts:
                raise FactError(
                    f"{where}.binary Click-to-Run backing escaped the Excel Office root"
                )
            relative_parts = binary_path.parts[len(root_parts) :]
            if (
                len(relative_parts) < 3
                or relative_parts[0].casefold() != "vfs"
                or relative_parts[1].casefold()
                not in {"programfilescommonx64", "programfilescommonx86"}
            ):
                raise FactError(
                    f"{where}.binary Click-to-Run backing path shape is malformed"
                )
            reported_lower = [part.casefold() for part in reported_path.parts]
            try:
                common_index = reported_lower.index("common files")
            except ValueError as exc:
                raise FactError(
                    f"{where}.binary module-reported path lacks Common Files"
                ) from exc
            reported_suffix = tuple(reported_lower[common_index + 1 :])
            backing_suffix = tuple(
                part.casefold() for part in relative_parts[2:]
            )
            if not reported_suffix or reported_suffix != backing_suffix:
                raise FactError(
                    f"{where}.binary reported/backing Click-to-Run suffix differs"
                )
        return
    raise FactError(
        f"{where} must identify the exact loaded VBE binary for this frozen capture"
    )


def _validate_capture_pair(spec: dict[str, Any], capture: dict[str, Any]) -> None:
    _require_keys(
        spec,
        {
            "schema",
            "capture_id",
            "profile",
            "description",
            "frozen_capture_identity",
            "forms",
            "designer_add_probes",
        },
        "capture spec",
    )
    _require_keys(
        capture,
        {
            "schema", "capture_id", "profile", "authority_class",
            "capture_started_utc", "capture_completed_utc", "clean_room", "git",
            "capture_tool", "capture_spec", "frozen_capture_identity",
            "environment", "excel_file",
            "excel_automation", "progid_registrations", "forms", "designer_add_probes",
            "exporter_binary_identity",
        },
        "capture manifest",
    )
    if spec.get("schema") != CAPTURE_SPEC_SCHEMA:
        raise FactError("unexpected live capture-spec schema")
    if capture.get("schema") != CAPTURE_SCHEMA:
        raise FactError("unexpected live capture-manifest schema")
    for key in ("capture_id", "profile"):
        if capture.get(key) != spec.get(key):
            raise FactError(f"capture {key} differs from capture spec")
    _validate_frozen_capture_identity(
        spec["frozen_capture_identity"], spec["capture_id"], "capture spec identity"
    )
    if capture["frozen_capture_identity"] != spec["frozen_capture_identity"]:
        raise FactError("capture frozen identity differs from capture spec")
    _validate_frozen_capture_identity(
        capture["frozen_capture_identity"],
        capture["capture_id"],
        "capture manifest identity",
    )
    frozen = spec["frozen_capture_identity"]

    for timestamp_key in ("capture_started_utc", "capture_completed_utc"):
        timestamp = capture[timestamp_key]
        if (
            not isinstance(timestamp, str)
            or re.fullmatch(
                r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:"
                r"[0-9]{2}\.[0-9]{7}Z",
                timestamp,
            )
            is None
        ):
            raise FactError(f"capture {timestamp_key} is not an ISO timestamp")
        try:
            parsed = datetime.fromisoformat(timestamp[:-1] + "+00:00")
        except ValueError as exc:
            raise FactError(f"capture {timestamp_key} is not an ISO timestamp") from exc
        if parsed.tzinfo is None or parsed.utcoffset() != timezone.utc.utcoffset(parsed):
            raise FactError(f"capture {timestamp_key} is not canonical UTC")
        if parsed.date().isoformat() != frozen["capture_date_utc"]:
            raise FactError(f"capture {timestamp_key} differs from frozen capture date")
    started = datetime.fromisoformat(capture["capture_started_utc"][:-1] + "+00:00")
    completed = datetime.fromisoformat(capture["capture_completed_utc"][:-1] + "+00:00")
    if completed < started:
        raise FactError("capture completed before it started")

    excel_file = capture["excel_file"]
    if not isinstance(excel_file, dict):
        raise FactError("capture excel_file is not an object")
    _require_keys(
        excel_file,
        {
            "path",
            "process_id",
            "length",
            "sha256",
            "file_version",
            "product_version",
        },
        "capture excel_file",
    )
    if (
        not isinstance(excel_file["path"], str)
        or isinstance(excel_file["process_id"], bool)
        or not isinstance(excel_file["process_id"], int)
        or excel_file["process_id"] <= 0
    ):
        raise FactError("capture Excel executable path/process identity is malformed")
    excel_path = PureWindowsPath(excel_file["path"])
    if not excel_path.is_absolute() or excel_path.name.upper() != "EXCEL.EXE":
        raise FactError("capture Excel executable path is malformed")
    if {
        key: excel_file[key]
        for key in ("length", "sha256", "file_version", "product_version")
    } != frozen["excel_executable"]:
        raise FactError("capture Excel executable differs from frozen identity")

    automation = capture["excel_automation"]
    if not isinstance(automation, dict):
        raise FactError("capture excel_automation is not an object")
    _require_keys(
        automation,
        {
            "application_name",
            "version",
            "build",
            "vbe_version",
            "access_vbom",
            "component_type",
            "export_api",
            "workbook_saved",
        },
        "capture excel_automation",
    )
    if {
        key: automation[key] for key in ("version", "build", "vbe_version")
    } != frozen["excel_automation"]:
        raise FactError("capture Excel automation differs from frozen identity")
    _validate_exporter_binary_identity(
        capture["exporter_binary_identity"],
        frozen,
        excel_path,
        "capture exporter_binary_identity",
    )
    if (
        capture["exporter_binary_identity"]["host_process_id"]
        != excel_file["process_id"]
    ):
        raise FactError("capture Excel/exporter process identity differs")
    if capture.get("authority_class") != "observed_real_office_export":
        raise FactError("capture authority class was weakened")
    clean_room = capture.get("clean_room", {})
    required_clean = {
        "project_authored_inputs": True,
        "third_party_form_content": False,
        "public_automation_only": True,
        "transient_workbook_saved": False,
    }
    if clean_room != required_clean:
        raise FactError("capture clean-room declaration differs from the frozen contract")
    git_state = capture["git"]
    if not isinstance(git_state, dict):
        raise FactError("capture git state is not an object")
    _require_keys(git_state, {"head", "dirty", "status_line_count"}, "capture git state")
    if (
        not isinstance(git_state["head"], str)
        or re.fullmatch(r"[0-9a-f]{40}", git_state["head"]) is None
        or not isinstance(git_state["dirty"], bool)
        or isinstance(git_state["status_line_count"], bool)
        or not isinstance(git_state["status_line_count"], int)
        or git_state["status_line_count"] < 0
        or git_state["dirty"] != (git_state["status_line_count"] > 0)
    ):
        raise FactError("capture git state is malformed")

    environment = capture["environment"]
    if not isinstance(environment, dict):
        raise FactError("capture environment is not an object")
    _require_keys(
        environment,
        {
            "os_version",
            "os_architecture",
            "process_architecture",
            "culture",
            "ui_culture",
            "ansi_code_page",
            "oem_code_page",
            "powershell_version",
        },
        "capture environment",
    )
    if (
        not all(
            isinstance(environment[key], str) and environment[key]
            for key in (
                "os_version",
                "os_architecture",
                "process_architecture",
                "culture",
                "ui_culture",
                "powershell_version",
            )
        )
        or any(
            isinstance(environment[key], bool)
            or not isinstance(environment[key], int)
            or environment[key] <= 0
            for key in ("ansi_code_page", "oem_code_page")
        )
    ):
        raise FactError("capture environment is malformed")
    if (
        not isinstance(automation["application_name"], str)
        or not automation["application_name"]
        or automation["access_vbom"] is not True
        or automation["component_type"] != 3
        or automation["export_api"] != "VBComponent.Export"
        or automation["workbook_saved"] is not False
    ):
        raise FactError("capture Excel automation contract is malformed")
    spec_form_ids = _unique_sequence(spec["forms"], "fixture_id", "capture-spec form")
    capture_form_ids = _unique_sequence(capture["forms"], "fixture_id", "captured form")
    _unique_sequence(spec["forms"], "name", "capture-spec form")
    _unique_sequence(capture["forms"], "component_name", "captured form")
    if capture_form_ids != spec_form_ids:
        raise FactError("capture form set differs from capture spec")
    for expected, actual in zip(spec["forms"], capture["forms"], strict=True):
        fixture_id = expected["fixture_id"]
        _require_keys(
            expected,
            {"fixture_id", "name", "component_properties", "controls", "code_lines"},
            f"capture-spec form {fixture_id}",
        )
        _require_keys(
            actual,
            {"fixture_id", "component_name", "component_properties", "controls", "code_input", "exported_files"},
            f"captured form {fixture_id}",
        )
        if actual["component_name"] != expected["name"]:
            raise FactError(f"component-name drift for {fixture_id}")
        exported_files = _validated_exported_files(
            actual["exported_files"], f"captured form {fixture_id}.exported_files"
        )
        expected_component_names = _unique_sequence(
            expected["component_properties"], "name", f"{fixture_id} component property"
        )
        actual_component_names = _unique_sequence(
            actual["component_properties"], "name", f"{fixture_id} observed component property"
        )
        if actual_component_names != expected_component_names:
            raise FactError(f"component-property probe set/order drift for {fixture_id}")
        for property_spec, observation in zip(
            expected["component_properties"], actual["component_properties"], strict=True
        ):
            _validate_probe_binding(
                property_spec, observation, f"{fixture_id}.{property_spec['name']}"
            )

        expected_control_names = _unique_sequence(
            expected["controls"], "name", f"{fixture_id} control"
        )
        actual_control_names = _unique_sequence(
            actual["controls"], "name", f"{fixture_id} observed control"
        )
        if actual_control_names != expected_control_names:
            raise FactError(f"control instance set drift for {fixture_id}")
        for control, observed in zip(expected["controls"], actual["controls"], strict=True):
            allowed_control_keys = {
                "name", "family", "progid", "container", "geometry", "properties",
                "geometry_readback_expectation", "list_items", "pages", "tabs",
            }
            if not set(control).issubset(allowed_control_keys) or not {
                "name", "family", "progid", "container", "geometry", "properties"
            }.issubset(control):
                raise FactError(f"capture-spec control keys differ for {control.get('name')}")
            _require_keys(
                observed,
                {
                    "name",
                    "family",
                    "progid",
                    "container",
                    "geometry_requested",
                    "geometry_readback",
                    "geometry_result",
                    "properties",
                    "requested_list_items",
                    "list_items_readback",
                    "pages",
                    "tabs",
                },
                f"captured control {control['name']}",
            )
            for key in ("family", "progid", "container"):
                if observed[key] != control[key]:
                    raise FactError(f"control {key} drift for {control['name']}")
            _require_keys(control["geometry"], {"left", "top", "width", "height"}, f"{control['name']} geometry")
            _require_keys(
                observed["geometry_requested"],
                {"left", "top", "width", "height"},
                f"{control['name']} geometry request",
            )
            _require_keys(
                observed["geometry_readback"],
                {"left", "top", "width", "height"},
                f"{control['name']} geometry readback",
            )
            for label, geometry in (
                ("requested", control["geometry"]),
                ("manifest requested", observed["geometry_requested"]),
                ("readback", observed["geometry_readback"]),
            ):
                for key in ("left", "top", "width", "height"):
                    value = geometry[key]
                    if (
                        isinstance(value, bool)
                        or not isinstance(value, (int, float))
                        or not math.isfinite(float(value))
                    ):
                        raise FactError(
                            f"control geometry {label} {control['name']}.{key} "
                            "is not a finite number"
                        )
                if geometry["width"] <= 0 or geometry["height"] <= 0:
                    raise FactError(
                        f"control geometry {label} {control['name']} has a "
                        "non-positive width/height"
                    )
            if observed["geometry_requested"] != control["geometry"]:
                raise FactError(f"control geometry request drift for {control['name']}")
            result = observed["geometry_result"]
            if not isinstance(result, dict):
                raise FactError(f"control geometry result is malformed for {control['name']}")
            _require_keys(
                result,
                {"classification", "changed_fields", "basis"},
                f"{control['name']} geometry result",
            )
            expectation = control.get("geometry_readback_expectation")
            if expectation is None:
                if observed["geometry_readback"] != control["geometry"] or result != {
                    "classification": "exact",
                    "changed_fields": [],
                    "basis": None,
                }:
                    raise FactError(f"unpinned control geometry drift for {control['name']}")
            else:
                if not isinstance(expectation, dict):
                    raise FactError(
                        f"control geometry expectation is malformed for {control['name']}"
                    )
                _require_keys(
                    expectation,
                    {"classification", "values", "basis"},
                    f"{control['name']} geometry expectation",
                )
                if (
                    expectation["classification"]
                    != "expected_msforms_normalization"
                    or not isinstance(expectation["basis"], str)
                    or not expectation["basis"]
                    or not isinstance(expectation["values"], dict)
                ):
                    raise FactError(
                        f"control geometry expectation is malformed for {control['name']}"
                    )
                expected_readback = expectation["values"]
                _require_keys(
                    expected_readback,
                    {"left", "top", "width", "height"},
                    f"{control['name']} expected geometry readback",
                )
                for key in ("left", "top", "width", "height"):
                    value = expected_readback[key]
                    if (
                        isinstance(value, bool)
                        or not isinstance(value, (int, float))
                        or not math.isfinite(float(value))
                    ):
                        raise FactError(
                            f"control expected geometry {control['name']}.{key} "
                            "is not a finite number"
                        )
                if expected_readback["width"] <= 0 or expected_readback["height"] <= 0:
                    raise FactError(
                        f"control expected geometry {control['name']} has a "
                        "non-positive width/height"
                    )
                changed_fields = [
                    key
                    for key in ("left", "top", "width", "height")
                    if expected_readback[key] != control["geometry"][key]
                ]
                if not changed_fields:
                    raise FactError(
                        f"control geometry expectation changes nothing for {control['name']}"
                    )
                if observed["geometry_readback"] != expected_readback or result != {
                    "classification": expectation["classification"],
                    "changed_fields": changed_fields,
                    "basis": expectation["basis"],
                }:
                    raise FactError(
                        f"control expected geometry normalization drift for {control['name']}"
                    )
            expected_property_names = _unique_sequence(
                control["properties"], "name", f"{control['name']} property"
            )
            actual_property_names = _unique_sequence(
                observed["properties"], "name", f"{control['name']} observed property"
            )
            if actual_property_names != expected_property_names:
                raise FactError(f"control-property probe set/order drift for {control['name']}")
            for property_spec, observation in zip(
                control["properties"], observed["properties"], strict=True
            ):
                _validate_probe_binding(
                    property_spec,
                    observation,
                    f"{fixture_id}.{control['name']}.{property_spec['name']}",
                )
            requested_list_items = control.get("list_items")
            if requested_list_items is None:
                if (
                    observed["requested_list_items"] is not None
                    or observed["list_items_readback"] is not None
                ):
                    raise FactError(f"unexpected list-item provenance for {control['name']}")
            else:
                if observed["requested_list_items"] != requested_list_items:
                    raise FactError(f"requested list-item drift for {control['name']}")
                readback = observed["list_items_readback"]
                if not isinstance(readback, dict):
                    raise FactError(f"missing list-item readback for {control['name']}")
                _require_keys(
                    readback,
                    {"list_count", "items"},
                    f"{control['name']} list-item readback",
                )
                if (
                    isinstance(readback["list_count"], bool)
                    or not isinstance(readback["list_count"], int)
                    or not isinstance(readback["items"], list)
                    or not all(isinstance(item, str) for item in readback["items"])
                    or readback["list_count"] != len(readback["items"])
                ):
                    raise FactError(f"malformed list-item readback for {control['name']}")
                if readback["items"] != requested_list_items:
                    raise FactError(f"list-item readback drift for {control['name']}")
            if observed["pages"] != control.get("pages", []):
                raise FactError(f"page observation drift for {control['name']}")
            expected_tabs = [
                {
                    "index": row.get("index", index),
                    "name": row.get("name", row.get("add_name")),
                    "caption": row["caption"],
                }
                for index, row in enumerate(control.get("tabs", []))
            ]
            if observed["tabs"] != expected_tabs:
                raise FactError(f"tab observation drift for {control['name']}")

        code_text = "\r\n".join(str(line) for line in expected["code_lines"]) + "\r\n"
        expected_code_input = {
            "line_count": len(expected["code_lines"]),
            "utf8_sha256": sha256_bytes(code_text.encode("utf-8")),
        }
        if actual["code_input"] != expected_code_input:
            raise FactError(f"code-input digest/line-count drift for {fixture_id}")
        expected_export_names = {f"{expected['name']}.frm", f"{expected['name']}.frx"}
        if {
            PurePosixPath(row["path"]).name for row in exported_files.values()
        } != expected_export_names:
            raise FactError(f"exported file-name set drift for {fixture_id}")

    expected_probe_keys = _unique_sequence(
        spec["designer_add_probes"], "progid", "capture-spec designer-add probe"
    )
    actual_probe_keys = _unique_sequence(
        capture["designer_add_probes"], "progid", "captured designer-add probe"
    )
    if actual_probe_keys != expected_probe_keys:
        raise FactError("designer-add probe set differs from capture spec")
    for expected, actual in zip(
        spec["designer_add_probes"], capture["designer_add_probes"], strict=True
    ):
        _require_keys(expected, {"family", "progid", "expected"}, "designer-add spec")
        _require_keys(
            actual,
            {"family", "progid", "expected", "added", "error", "hresult"},
            "designer-add observation",
        )
        for key in ("family", "progid", "expected"):
            if actual[key] != expected[key]:
                raise FactError(f"designer-add {key} drift for {expected['family']}")
        if not isinstance(actual["added"], bool):
            raise FactError(
                f"designer-add added must be a boolean for {expected['family']}"
            )
        rejected = (
            actual["added"] is False
            and actual["hresult"] == DESIGNER_ADD_REJECTED_HRESULT
        )
        if expected["expected"] != "rejected" or not rejected:
            raise FactError(f"designer-add rejection drift for {expected['family']}")
        if not isinstance(actual["error"], str) or not actual["error"]:
            raise FactError(f"designer-add rejection lacks error text for {expected['family']}")

    expected_progids = {
        control["progid"] for form in spec["forms"] for control in form["controls"]
    } | {row["progid"] for row in spec["designer_add_probes"]}
    registered_progids = _unique_sequence(
        capture["progid_registrations"], "progid", "ProgID registration"
    )
    if set(registered_progids) != expected_progids:
        raise FactError("captured ProgID registration set differs from capture spec")


def _validate_manifest_self_pins(
    repo_root: Path,
    capture: dict[str, Any],
    capture_path: Path,
) -> None:
    canonical_source_paths = {
        "capture_tool": "tools/forms-persistence/Capture-MSFormsExports.ps1",
        "capture_spec": "tools/forms-persistence/capture_spec.v1.json",
    }
    try:
        capture_directory = capture_path.parent.resolve().relative_to(
            repo_root.resolve()
        ).as_posix()
    except ValueError as exc:
        raise FactError("capture manifest directory escaped the repository") from exc
    frozen_directory = capture["frozen_capture_identity"]["output_directory"]
    if capture_directory != frozen_directory:
        raise FactError("capture manifest directory differs from frozen output identity")
    if capture_path.name != "capture_manifest.v2.json":
        raise FactError("capture manifest filename differs from the v2 contract")
    _reject_reparse_path(repo_root, capture_path, "capture manifest path")
    for manifest_key in ("capture_tool", "capture_spec"):
        pin = capture[manifest_key]
        if not isinstance(pin, dict):
            raise FactError(f"capture.{manifest_key} is not an object")
        _require_keys(
            pin,
            {"path", "length", "sha256"},
            f"capture.{manifest_key}",
        )
        relative = _require_relative_repo_path(pin["path"], f"capture.{manifest_key}.path")
        if relative.as_posix() != canonical_source_paths[manifest_key]:
            raise FactError(f"capture.{manifest_key}.path differs from canonical path")
        dependency_path = repo_root / Path(*relative.parts)
        _reject_reparse_path(
            repo_root, dependency_path, f"capture {manifest_key} path"
        )
        _verify_length_hash(
            dependency_path,
            pin["length"],
            pin["sha256"],
            f"capture {manifest_key}",
        )
    expected_files = {capture_path.name}
    for form in capture["forms"]:
        exported_files = _validated_exported_files(
            form.get("exported_files"),
            f"captured form {form.get('fixture_id')}.exported_files",
        )
        for exported in exported_files.values():
            relative = _require_relative_repo_path(exported["path"], "exported fixture path")
            path = repo_root / Path(*relative.parts)
            _reject_reparse_path(repo_root, path, f"exported fixture {exported['path']}")
            _verify_length_hash(path, exported["length"], exported["sha256"], exported["path"])
            if path.parent.resolve() != capture_path.parent.resolve():
                raise FactError("exported fixture escaped its capture directory")
            expected_files.add(path.name)
    actual_entries = list(capture_path.parent.iterdir())
    actual_names = {path.name for path in actual_entries}
    if actual_names != expected_files:
        raise FactError(
            f"capture directory file set differs; missing={sorted(expected_files-actual_names)}, "
            f"extra={sorted(actual_names-expected_files)}"
        )
    for entry in actual_entries:
        if _is_reparse_point(entry) or not entry.is_file():
            raise FactError(
                f"capture directory entry is not a regular non-reparse file: {entry.name}"
            )


def _fixture_facts(
    repo_root: Path,
    capture: dict[str, Any],
    capture_spec: dict[str, Any],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    fixtures: list[dict[str, Any]] = []
    references: list[dict[str, Any]] = []
    cfb_inventories: list[dict[str, Any]] = []
    code_boundaries: list[dict[str, Any]] = []
    code_page = capture["environment"]["ansi_code_page"]
    if (
        isinstance(code_page, bool)
        or not isinstance(code_page, int)
        or code_page <= 0
    ):
        raise FactError(
            "capture environment ansi_code_page must be a positive integer"
        )
    spec_forms = {row["fixture_id"]: row for row in capture_spec["forms"]}
    for form in capture["forms"]:
        form_spec = spec_forms[form["fixture_id"]]
        files = _validated_exported_files(
            form.get("exported_files"),
            f"fixture {form['fixture_id']}.exported_files",
        )
        frm_path = repo_root / Path(*PurePosixPath(files[".frm"]["path"]).parts)
        frx_path = repo_root / Path(*PurePosixPath(files[".frx"]["path"]).parts)
        frm = inventory_frm_file(frm_path, code_page, profile=OFFICE_VBA_USERFORM_EXPORT)
        cfb = inventory_cfb_file(frx_path)
        frx_raw = frx_path.read_bytes()
        if frm["root"]["guid"].upper() != USERFORM_CLSID:
            raise FactError(f"unexpected UserForm CLSID in {frm_path}")
        if frm["root"]["name"] != form["component_name"]:
            raise FactError(f"root form name differs from component name: {frm_path}")
        if not frm["coverage"]["all_bytes_classified_once"]:
            raise FactError(f"FRM byte coverage is incomplete: {frm_path}")
        cfb_end = cfb["signature_offset"] + cfb["cfb_length"]
        if cfb_end > len(frx_raw):
            raise FactError(f"CFB logical extent exceeds FRX bytes: {frx_path}")
        frm_refs = frm["external_resource_references"]
        if len(frm_refs) != 1 or frm_refs[0]["property_name"] != "OleObjectBlob":
            raise FactError(f"Office UserForm fixture lacks one OleObjectBlob reference: {frm_path}")
        ref = frm_refs[0]
        if not ref["is_safe_relative_basename"] or ref["path"] != frx_path.name:
            raise FactError(f"unsafe or mismatched FRX reference: {frm_path}")
        if ref["offset"] != 0 or ref["offset_text"] != "0000":
            raise FactError(
                f"observed OleObjectBlob reference changed from exact :0000: {frm_path}"
            )
        if cfb["signature_offset"] != 24:
            raise FactError(f"observed embedded CFB signature offset changed from 24: {frx_path}")
        prefix = frx_raw[: cfb["signature_offset"]]
        physical_regions = cfb["physical_regions"]
        cursor = 0
        for region in physical_regions:
            if region["offset"] != cursor or region["length"] <= 0:
                raise FactError(
                    f"CFB physical regions are not a contiguous partition: {frx_path}"
                )
            cursor += region["length"]
        all_bytes_accounted_for = cursor == len(frx_raw)
        if not all_bytes_accounted_for:
            raise FactError(
                f"CFB physical regions cover {cursor} of {len(frx_raw)} bytes: {frx_path}"
            )

        frm_raw = frm_path.read_bytes()
        code_span = frm["code_body"]["span"]
        code_bytes = frm_raw[code_span["byte_start"] : code_span["byte_end"]]
        code_text = code_bytes.decode(frm["encoding"]["codec"])
        requested_code_text = (
            "\r\n".join(str(line) for line in form_spec["code_lines"]) + "\r\n"
        )
        if code_text != requested_code_text + "\r\n":
            raise FactError(
                "exported code body differs from the requested text plus the "
                f"observed one-blank-line VBIDE normalization: {frm_path}"
            )
        requested_code_input = {
            "line_count": len(form_spec["code_lines"]),
            "utf8_sha256": sha256_bytes(requested_code_text.encode("utf-8")),
        }
        if requested_code_input != form["code_input"]:
            raise FactError(
                f"requested code differs from manifest code-input pin: {frm_path}"
            )
        exported_code_body = {
            "length": len(code_bytes),
            "sha256": sha256_bytes(code_bytes),
            "normalization_from_request": "one additional CRLF blank line",
        }

        cfb = {
            **cfb,
            "source": {
                "length": len(frx_raw),
                "sha256": sha256_bytes(frx_raw),
            },
            "coverage": {
                "source_length": len(frx_raw),
                "prefix_length": cfb["signature_offset"],
                "cfb_length": cfb["cfb_length"],
                "trailing_length": len(frx_raw) - cfb_end,
                "all_cfb_allocation_structures_and_stream_chains_validated": True,
                "all_unallocated_and_trailing_regions_inventoried": True,
                "physical_region_count": len(physical_regions),
                "mini_physical_region_count": len(cfb["mini_physical_regions"]),
                "physical_partition_hashes_each_source_byte_once": (
                    all_bytes_accounted_for
                ),
                "all_bytes_accounted_for": all_bytes_accounted_for,
            },
        }
        spec_controls = {
            row["name"]: row for row in form_spec["controls"]
        }
        captured_controls = copy.deepcopy(form["controls"])
        for control in captured_controls:
            control["geometry_requested"] = copy.deepcopy(
                spec_controls[control["name"]]["geometry"]
            )
        fixture = {
            "fixture_id": form["fixture_id"],
            "authority_class": "observed_real_office_export",
            "profile": OFFICE_VBA_USERFORM_EXPORT,
            "capture_environment": {
                "excel_version": capture["excel_file"]["file_version"],
                "vbe_version": capture["excel_automation"]["vbe_version"],
                "ansi_code_page": code_page,
                "culture": capture["environment"]["culture"],
                "os_architecture": capture["environment"]["os_architecture"],
            },
            "component_name": form["component_name"],
            "component_properties": form["component_properties"],
            "controls": captured_controls,
            "code_input": requested_code_input,
            "exported_code_body": exported_code_body,
            "frm_path": files[".frm"]["path"],
            "frm_sha256": files[".frm"]["sha256"],
            "frm_inventory": frm,
            "frx_path": files[".frx"]["path"],
            "frx_sha256": files[".frx"]["sha256"],
            "frx_prefix": {
                "offset": 0,
                "length": len(prefix),
                "sha256": sha256_bytes(prefix),
                "interpretation": "opaque_observed_prefix",
            },
        }
        fixtures.append(fixture)
        references.append(
            {
                "fixture_id": form["fixture_id"],
                "frm_path": files[".frm"]["path"],
                "property": "OleObjectBlob",
                "lexical_path": ref["path"],
                "lexical_offset_text": ref["offset_text"],
                "lexical_offset": ref["offset"],
                "resolved_frx_path": files[".frx"]["path"],
                "resolved_frx_length": files[".frx"]["length"],
                "resolved_frx_sha256": files[".frx"]["sha256"],
                "embedded_cfb_signature_offset": cfb["signature_offset"],
                "boundary": "OleObjectBlob is observed Office-export syntax outside the MS-OVBA DesignerProperties grammar; its offset is not reinterpreted as the CFB signature offset.",
            }
        )
        cfb_inventories.append(
            {
                "fixture_id": form["fixture_id"],
                "frx_path": files[".frx"]["path"],
                "inventory": cfb,
            }
        )
        code_boundaries.append(
            {
                "fixture_id": form["fixture_id"],
                "frm_path": files[".frm"]["path"],
                "class_header": frm["class_header"],
                "code_body": frm["code_body"],
                "proof": "MS-VBAL module-header rows plus byte-exact Office export inventory",
            }
        )
    fixtures.sort(key=lambda row: row["fixture_id"])
    references.sort(key=lambda row: row["fixture_id"])
    cfb_inventories.sort(key=lambda row: row["fixture_id"])
    code_boundaries.sort(key=lambda row: row["fixture_id"])
    return fixtures, references, cfb_inventories, code_boundaries


def _designer_property_facts(fixtures: list[dict[str, Any]]) -> list[dict[str, Any]]:
    occurrences: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for fixture in fixtures:
        for row in fixture["frm_inventory"]["root_properties"]:
            occurrences[row["name"]].append(
                {
                    "fixture_id": fixture["fixture_id"],
                    "order": row["order"],
                    "value_text": row["value_text"],
                    "parsed_value": row["parsed_value"],
                    "span": row["span"],
                }
            )
    results: list[dict[str, Any]] = []
    for order, spec in enumerate(DESIGNER_PROPERTY_SPECS):
        results.append(
            {
                "order": order,
                **spec,
                "normative_source": "MS-OVBA-SEGMENTS rows 2841-2932",
                "observed_occurrences": occurrences.get(spec["name"], []),
                "authority": "normative_grammar_with_separate_live_observation",
            }
        )
    return results


def _derive_designer_property_specs(
    source_rows: list[dict[str, Any]],
) -> tuple[dict[str, Any], ...]:
    """Derive the full DesignerProperties universe from pinned MS-OVBA rows."""

    by_number = {
        row["row_number"]: row["record"].get("text")
        for row in source_rows
        if row["source_id"] == "MS-OVBA-SEGMENTS"
    }
    definitions: tuple[tuple[str, int, int | None, int | None], ...] = (
        ("DesignerCaption", 2861, 2862, None),
        ("DesignerHeight", 2866, None, None),
        ("DesignerLeft", 2870, None, None),
        ("DesignerTop", 2874, None, None),
        ("DesignerWidth", 2878, None, None),
        ("DesignerEnabled", 2882, None, 2880),
        ("DesignerHelpContextId", 2886, None, None),
        ("DesignerRTL", 2890, None, None),
        ("DesignerShowModal", 2894, None, 2892),
        ("DesignerStartupPosition", 2898, 2899, None),
        ("DesignerTag", 2915, 2916, None),
        ("DesignerTypeInfoVer", 2920, None, 2918),
        ("DesignerVisible", 2924, None, 2922),
        ("DesignerWhatsThisButton", 2928, None, 2926),
        ("DesignerWhatsThisHelp", 2932, None, None),
    )
    ordered = []
    for row_number in range(2841, 2856):
        text = by_number.get(row_number, "")
        matches = re.findall(r"\b(Designer[A-Za-z]+)\b", text or "")
        if not matches:
            raise FactError(f"MS-OVBA DesignerProperties row {row_number} drift")
        ordered.append(matches[-1])
    if ordered != [row[0] for row in definitions]:
        raise FactError("MS-OVBA DesignerProperties production order drift")

    derived: list[dict[str, Any]] = []
    for index, (production, abnf_row, auxiliary_row, default_row) in enumerate(
        definitions
    ):
        text = by_number.get(abnf_row)
        match = re.fullmatch(
            rf'{re.escape(production)} = "(?P<name>[^"]+)" EQ (?P<rhs>.+)',
            text or "",
        )
        if match is None:
            raise FactError(f"MS-OVBA {production} ABNF row drift")
        lexical = match.group("rhs")
        if auxiliary_row is not None:
            auxiliary = by_number.get(auxiliary_row, "") or ""
            auxiliary_match = re.fullmatch(r"(?P<name>[A-Za-z]+) = (?P<rhs>.+)", auxiliary)
            if auxiliary_match is None or auxiliary_match.group("name") not in lexical:
                raise FactError(f"MS-OVBA {production} auxiliary ABNF row drift")
            lexical = lexical.replace(
                auxiliary_match.group("name"), auxiliary_match.group("rhs")
            )
        default: Any = None
        if default_row is not None:
            default_text = by_number.get(default_row, "") or ""
            default_match = re.search(r"The default is (TRUE|FALSE|0)\.", default_text)
            if default_match is None:
                raise FactError(f"MS-OVBA {production} default row drift")
            default = {
                "TRUE": True,
                "FALSE": False,
                "0": 0,
            }[default_match.group(1)]
        derived.append(
            {
                "production": production,
                "name": match.group("name"),
                "lexical": lexical,
                "section": f"2.3.5.{index + 2}",
                "default": default,
            }
        )
    result = tuple(derived)
    for actual, expected in zip(result, DESIGNER_PROPERTY_SPECS, strict=True):
        if actual != expected:
            raise FactError(
                f"pinned MS-OVBA-derived {expected['production']} differs from "
                "the frozen Designer property contract"
            )
    return result


def _omission_pairs(fixtures: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_id = {row["fixture_id"]: row for row in fixtures}
    baseline = by_id["outer-defaults"]
    nondefault = by_id["outer-nondefaults"]
    base_props = {row["name"]: row for row in baseline["component_properties"]}
    changed_props = {row["name"]: row for row in nondefault["component_properties"]}
    base_text = {row["name"]: row for row in baseline["frm_inventory"]["root_properties"]}
    changed_text = {row["name"]: row for row in nondefault["frm_inventory"]["root_properties"]}
    names = (
        "Enabled",
        "HelpContextID",
        "RightToLeft",
        "ShowModal",
        "StartUpPosition",
        "Tag",
        "WhatsThisButton",
        "WhatsThisHelp",
    )
    pairs: list[dict[str, Any]] = []
    for name in names:
        before = base_props[name]
        after = changed_props[name]
        pairs.append(
            {
                "property": name,
                "baseline_requested": before["requested"],
                "baseline_readback": before["readback"],
                "baseline_emitted": name in base_text,
                "baseline_value_text": base_text.get(name, {}).get("value_text"),
                "nondefault_requested": after["requested"],
                "nondefault_readback": after["readback"],
                "nondefault_emitted": name in changed_text,
                "nondefault_value_text": changed_text.get(name, {}).get("value_text"),
                "scope": "same Excel/VBE build, controlled public VBComponent.Export pair",
                "interpretation": (
                    "serialization observation only; this does not establish a runtime API default"
                ),
            }
        )
    return pairs


def _profiles() -> list[dict[str, Any]]:
    return [
        {
            "id": OFFICE_VBA_USERFORM_EXPORT,
            "authority_class": "canonical_for_captured_office_vba_export",
            "representation": "MS-OVBA VBFrame root text, Office OleObjectBlob extension, class attributes, then opaque VBA code; the control graph is in FRX CFB data",
            "may_establish_office_export_facts": True,
        },
        {
            "id": "vb6_frm_export",
            "authority_class": "uncaptured_separate_profile",
            "representation": "classic VB6 textual form dialect",
            "may_establish_office_export_facts": False,
            "reason": "No authenticated VB6 export was captured by this bead.",
        },
        {
            "id": LEGACY_SYNTHETIC_NESTED,
            "authority_class": "oxforms_canonical_extension_and_legacy_synthetic_only",
            "representation": "nested textual Begin/End control blocks used by existing repository fixtures",
            "may_establish_office_export_facts": False,
            "reason": "These project-authored fixtures are useful compatibility inputs, not Office-export authority.",
        },
    ]


def _grammar(source_rows: list[dict[str, Any]], fixtures: list[dict[str, Any]]) -> dict[str, Any]:
    by_number = {(row["source_id"], row["row_number"]): row["record"].get("text") for row in source_rows}
    required = {
        ("MS-OVBA-SEGMENTS", 651),
        ("MS-OVBA-SEGMENTS", 652),
        ("MS-OVBA-SEGMENTS", 656),
        ("MS-OVBA-SEGMENTS", 2833),
        ("MS-OVBA-SEGMENTS", 2834),
        ("MS-OVBA-SEGMENTS", 2835),
        ("MS-OVBA-SEGMENTS", 2841),
        ("MS-OVBA-SEGMENTS", 2855),
        ("MS-VBAL-SEGMENTS", 1482),
        ("MS-VBAL-SEGMENTS", 1488),
        ("MS-VBAL-SEGMENTS", 1491),
        ("MS-VBAL-SEGMENTS", 1497),
        ("MS-VBAL-SEGMENTS", 1506),
        ("MS-VBAL-SEGMENTS", 1521),
        ("MS-VBAL-SEGMENTS", 1525),
    }
    if not required.issubset(by_number):
        raise FactError("selected normative rows do not contain the frozen VBFrame grammar")
    observed_property_orders = [
        {
            "fixture_id": fixture["fixture_id"],
            "properties": [row["name"] for row in fixture["frm_inventory"]["root_properties"]],
        }
        for fixture in fixtures
    ]
    return {
        "normative_vbframe": {
            "module_identifier_heading": by_number[("MS-OVBA-SEGMENTS", 651)],
            "module_identifier_rules": by_number[("MS-OVBA-SEGMENTS", 652)],
            "newline": by_number[("MS-OVBA-SEGMENTS", 656)],
            "vbframe_text": by_number[("MS-OVBA-SEGMENTS", 2833)],
            "designer_clsid": by_number[("MS-OVBA-SEGMENTS", 2834)],
            "designer_name": by_number[("MS-OVBA-SEGMENTS", 2835)],
            "designer_properties_first": by_number[("MS-OVBA-SEGMENTS", 2841)],
            "designer_properties_last": by_number[("MS-OVBA-SEGMENTS", 2855)],
            "property_order": [row["production"] for row in DESIGNER_PROPERTY_SPECS],
            "authority": "MS-OVBA 2.3.5 selected pinned rows",
        },
        "observed_office_extension": {
            "ole_object_blob_lexeme": 'OleObjectBlob = "<safe sibling basename>.frx":0000',
            "parser_acceptance_policy": "The inventory parser accepts four to eight hexadecimal offset digits as a bounded parser policy; only exact :0000 is an observed Office-export fact.",
            "location": "one root property inside the VBFrame Begin/End block",
            "observed_property_orders": observed_property_orders,
            "authority": "same-build public VBComponent.Export capture",
            "normative_status": "not defined by the selected MS-OVBA DesignerProperties grammar",
        },
        "class_header_and_body": {
            "header": "contiguous Attribute name = value rows after designer End",
            "body": "all remaining bytes after the contiguous class header",
            "body_interpretation": "opaque for persistence inventory",
            "module_two_part_rule": by_number[("MS-VBAL-SEGMENTS", 1482)],
            "class_module_rule": by_number[("MS-VBAL-SEGMENTS", 1488)],
            "class_attribute_cardinality": by_number[("MS-VBAL-SEGMENTS", 1491)],
            "customizable_attribute_rule": by_number[("MS-VBAL-SEGMENTS", 1497)],
            "duplicate_attribute_rule": by_number[("MS-VBAL-SEGMENTS", 1506)],
            "module_name_length_rule": by_number[("MS-VBAL-SEGMENTS", 1521)],
            "source_project_false_rule": by_number[("MS-VBAL-SEGMENTS", 1525)],
            "authority": "MS-VBAL rows 1480-1526 plus observed Office exports",
        },
        "profile_separation": {
            "office_nested_text_controls": False,
            "legacy_nested_text_controls": True,
            "cross_profile_promotion": "forbidden",
        },
    }


def _component_headers(fixtures: list[dict[str, Any]]) -> dict[str, Any]:
    headers = []
    sequences = set()
    for fixture in fixtures:
        header = fixture["frm_inventory"]["class_header"]
        names = tuple(row["name"] for row in header["attributes"])
        sequences.add(names)
        headers.append(
            {
                "fixture_id": fixture["fixture_id"],
                "standard_office_userform_header": header["standard_office_userform_header"],
                "attributes": header["attributes"],
            }
        )
    if len(sequences) != 1:
        raise FactError("captured Office UserForms do not share one class-header sequence")
    return {
        "observed_attribute_order": list(next(iter(sequences))),
        "fixtures": headers,
        "boundary_policy": "Only the contiguous class-module Attribute header is metadata; subsequent assignment-shaped lines are opaque code.",
    }


def _live_property_probes(capture: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    probes: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for form in capture["forms"]:
        for prop in form["component_properties"]:
            probes[prop["name"]].append(
                {
                    "fixture_id": form["fixture_id"],
                    "owner_kind": "UserForm",
                    "owner_name": form["component_name"],
                    **prop,
                }
            )
        for control in form["controls"]:
            for prop in control["properties"]:
                probes[prop["name"]].append(
                    {
                        "fixture_id": form["fixture_id"],
                        "owner_kind": control["family"],
                        "owner_name": control["name"],
                        **prop,
                    }
                )
    return probes


def _property_mappings(ms_oforms: dict[str, Any], capture: dict[str, Any]) -> list[dict[str, Any]]:
    probes = _live_property_probes(capture)
    context_probes: dict[str, tuple[str, str]] = {
        "ScrollBars (UserForm)": ("ScrollBars", "UserForm-specific source-name qualification"),
        "ScrollBars (MorphData)": ("ScrollBars", "MorphData-specific source-name qualification"),
        "Position (ScrollBar and SpinButton)": ("Value", "public Value probe on ScrollBar/SpinButton; binary Position was not decoded"),
        "Position (OleSiteConcrete)": ("geometry_readback", "control-site position is represented by captured geometry; binary field was not decoded"),
        "ListIndex": ("Value", "selected-value probe; no binary ListIndex field decoding claimed"),
        "TabStyle": ("Style", "public TabStrip/MultiPage Style alias; binary field was not decoded"),
        "Tooltip": ("ControlTipText", "public control tooltip spelling"),
        "Name": ("control_name", "captured designer site/control name"),
        "Width": ("geometry_readback", "context only: whole-control geometry is not the MS-OFORMS column-width property"),
        "Size": ("geometry_readback", "context only: public geometry exists, but the binary Size field was not decoded"),
        "DisplayedSize": ("geometry_readback", "context only: external/client dimensions differ and do not prove DisplayedSize"),
        "LogicalSize": ("geometry_readback", "context only: only one form has ScrollWidth/ScrollHeight and the binary field was not decoded"),
        "PageCount": ("pages", "captured MultiPage page collection cardinality"),
        "TabsAllocated": ("tabs", "context only: current tab cardinality does not prove the cumulative allocation counter"),
        "TabData": ("tabs", "context only: names/captions do not prove the TabData field"),
        "ClsidCacheIndex": ("progid_registration", "context only: a registry census does not prove a per-site cache-table index"),
    }
    structural = {
        "BitFlags (OleSiteConcrete)",
        "BitFlags (DesignExtender)",
        "BooleanProperties",
        "cColumnInfo",
        "ClickControlMode",
        "DblClickControlMode",
        "Flags",
        "GroupCount",
        "GroupID",
        "ID",
        "NewVersion",
        "NextAvailableID",
        "NextEnabled",
        "ObjectStreamSize",
        "PrevEnabled",
        "ShapeCookie",
        "Tooltips",
        "VariousPropertyBits",
    }
    rows: list[dict[str, Any]] = []
    properties = ms_oforms.get("properties")
    if not isinstance(properties, list) or len(properties) != 98:
        raise FactError("preceding MS-OFORMS fact pack no longer contains exactly 98 properties")
    for prop in properties:
        name = prop["name"]
        applies_to = set(prop["applies_to"])

        def applies(probe: dict[str, Any]) -> bool:
            owner = probe["owner_kind"]
            if owner == "UserForm":
                return bool({"Form", "DesignExtender"} & applies_to)
            return owner in applies_to or "OleSiteConcrete" in applies_to

        relevant_exact = [probe for probe in probes.get(name, []) if applies(probe)]
        successful_exact = [
            probe for probe in relevant_exact if probe.get("succeeded") is True
        ]
        if successful_exact:
            classification = "live_public_property_probe_exact_name"
            observed_as = name
            reason = "At least one applicable public-property probe was set and read back successfully before export; failed family-specific attempts remain explicit, and no binary field/value decoding is claimed."
            live = relevant_exact
        elif relevant_exact:
            classification = "failed_live_public_property_probe_exact_name"
            observed_as = name
            reason = "Applicable exact-name public-property probes were attempted but all failed; this is failure evidence, not a successful live or binary-value probe."
            live = relevant_exact
        elif name in context_probes:
            classification = "live_context_only_not_exact_property_probe"
            observed_as, reason = context_probes[name]
            if observed_as in probes:
                live = [probe for probe in probes[observed_as] if applies(probe)]
            else:
                live = []
                for form in capture["forms"]:
                    if observed_as == "geometry_readback" and "Form" in applies_to:
                        geometry_names = {
                            "Left", "Top", "Width", "Height", "ScrollLeft",
                            "ScrollTop", "ScrollWidth", "ScrollHeight",
                        }
                        candidates = [
                            row
                            for row in form["component_properties"]
                            if row["name"] in geometry_names
                        ]
                        selected = {
                            row["name"]: row["readback"]
                            for row in candidates
                            if row.get("succeeded") is True
                        }
                        if selected:
                            live.append(
                                {
                                    "fixture_id": form["fixture_id"],
                                    "owner_kind": "UserForm",
                                    "owner_name": form["component_name"],
                                    "geometry_readback": selected,
                                }
                            )
                        elif candidates:
                            live.append(
                                {
                                    "fixture_id": form["fixture_id"],
                                    "owner_kind": "UserForm",
                                    "owner_name": form["component_name"],
                                    "geometry_readback": {},
                                    "succeeded": False,
                                    "failed_property_names": sorted(
                                        row["name"] for row in candidates
                                    ),
                                }
                            )
                    for control in form["controls"]:
                        if control["family"] in applies_to or "OleSiteConcrete" in applies_to:
                            if observed_as == "geometry_readback":
                                live.append(
                                    {
                                        "fixture_id": form["fixture_id"],
                                        "owner_kind": control["family"],
                                        "owner_name": control["name"],
                                        "geometry_readback": control["geometry_readback"],
                                    }
                                )
                            elif observed_as == "control_name":
                                live.append(
                                    {
                                        "fixture_id": form["fixture_id"],
                                        "owner_kind": control["family"],
                                        "owner_name": control["name"],
                                        "value": control["name"],
                                    }
                                )
                            elif observed_as == "pages" and control["family"] == "MultiPage":
                                live.append(
                                    {
                                        "fixture_id": form["fixture_id"],
                                        "owner_kind": control["family"],
                                        "owner_name": control["name"],
                                        "pages": control["pages"],
                                    }
                                )
                            elif observed_as == "tabs" and control["family"] == "TabStrip":
                                live.append(
                                    {
                                        "fixture_id": form["fixture_id"],
                                        "owner_kind": control["family"],
                                        "owner_name": control["name"],
                                        "tabs": control["tabs"],
                                    }
                                )
                if observed_as == "progid_registration":
                    live = [
                        {
                            "progid": row["progid"],
                            "clsid": row["clsid"],
                            "class_name": row["class_name"],
                        }
                        for row in capture["progid_registrations"]
                    ]
        elif name in structural:
            classification = "documented_internal_structure_only"
            observed_as = None
            reason = "MS-OFORMS documents this internal persistence field; the live FRX is inventoried opaquely and does not decode it."
            live = []
        else:
            classification = "documented_no_exact_live_probe"
            observed_as = None
            reason = "The property remains in the complete MS-OFORMS universe, but this controlled capture does not establish its binary encoding."
            live = []
        if classification == "live_context_only_not_exact_property_probe" and not any(
            probe.get("succeeded", True) is True for probe in live
        ):
            classification = "failed_live_context_only_not_exact_property_probe"
            reason = (
                "Applicable contextual probes were attempted but none succeeded; "
                "this is failure evidence, not a successful live or binary-value probe."
            )
        def probe_matches_family(probe: dict[str, Any], family: str) -> bool:
            owner = probe.get("owner_kind")
            if family == "OleSiteConcrete" and "progid" in probe:
                return True
            if family in {"Form", "DesignExtender"}:
                return owner == "UserForm"
            if family == "OleSiteConcrete":
                return owner is not None and owner != "UserForm"
            return owner == family

        def observation_succeeded(probe: dict[str, Any]) -> bool:
            # Captured property probes carry an explicit succeeded flag. The
            # structural observations synthesized above (geometry, names,
            # pages, tabs, and registry rows) exist only after their owning
            # capture succeeded and intentionally have no such flag.
            return probe.get("succeeded", True) is True

        def probe_owner_label(probe: dict[str, Any]) -> str:
            fixture_id = probe.get("fixture_id")
            owner_name = probe.get("owner_name")
            if isinstance(fixture_id, str) and isinstance(owner_name, str):
                return f"{fixture_id}:{owner_name}"
            progid = probe.get("progid")
            if isinstance(progid, str) and progid:
                return f"registry:{progid}"
            raise FactError(f"property probe owner is unidentifiable for {name}")

        family_coverage = []
        for family in prop["applies_to"]:
            exact_family = [
                probe
                for probe in probes.get(name, [])
                if probe_matches_family(probe, family)
            ]
            context_family = [
                probe
                for probe in live
                if probe_matches_family(probe, family)
            ]
            exact_successes = [
                probe for probe in exact_family if observation_succeeded(probe)
            ]
            context_successes = [
                probe for probe in context_family if observation_succeeded(probe)
            ]
            if exact_successes:
                status = "exact_name_live_probe"
                selected = exact_family
            elif exact_family:
                status = "failed_exact_name_live_probe"
                selected = exact_family
            elif classification == "documented_internal_structure_only":
                status = "documented_internal_only"
                selected = []
            elif context_successes:
                status = "context_only_not_exact_probe"
                selected = context_family
            elif context_family:
                status = "failed_context_probe"
                selected = context_family
            else:
                status = "unprobed"
                selected = []
            family_coverage.append(
                {
                    "family": family,
                    "status": status,
                    "probe_count": len(selected),
                    "successful_probe_count": sum(
                        observation_succeeded(probe) for probe in selected
                    ),
                    "failed_probe_count": sum(
                        not observation_succeeded(probe) for probe in selected
                    ),
                    "probe_owners": sorted(
                        {probe_owner_label(probe) for probe in selected}
                    ),
                }
            )
        rows.append(
            {
                "name": name,
                "section": prop["section"],
                "applies_to": prop["applies_to"],
                "source_segment_ids": prop["source_segment_ids"],
                "classification": classification,
                "observed_as": observed_as,
                "reason": reason,
                "live_probes": live,
                "family_coverage": family_coverage,
                "binary_value_decoded": False,
                "runtime_api_claim": False,
            }
        )
    if len(rows) != 98 or len({row["name"] for row in rows}) != 98:
        raise FactError("property-mapping coverage is not one-to-one with MS-OFORMS")
    return rows


def _fm20_control_universe(fm20: dict[str, Any]) -> dict[str, Any]:
    roots = [row for row in fm20.get("libraries", []) if row.get("role") == "root"]
    if len(roots) != 1:
        raise FactError("FM20 fact pack does not contain exactly one root library")
    root = roots[0]
    attrs = root["attributes"]
    primary_coclasses = [
        row
        for row in root["types"]
        if row["view"] == "primary"
        and row["attributes"]["typekind_name"] == "TKIND_COCLASS"
    ]

    def fact(row: dict[str, Any]) -> dict[str, Any]:
        return {
            "name": row["documentation"]["name"],
            "guid": row["attributes"]["guid"].upper(),
            "type_flags": row["attributes"]["type_flags"]["names"],
        }

    controls = [
        fact(row)
        for row in primary_coclasses
        if "TYPEFLAG_FCONTROL" in row["attributes"]["type_flags"]["names"]
        and "TYPEFLAG_FHIDDEN" not in row["attributes"]["type_flags"]["names"]
    ]
    hidden_controls = [
        fact(row)
        for row in primary_coclasses
        if "TYPEFLAG_FCONTROL" in row["attributes"]["type_flags"]["names"]
        and "TYPEFLAG_FHIDDEN" in row["attributes"]["type_flags"]["names"]
    ]
    html_controls = [row for row in controls if row["name"].startswith("HTML")]
    intrinsic_controls = [
        row for row in controls if not row["name"].startswith("HTML")
    ]
    pages = [
        fact(row)
        for row in primary_coclasses
        if row["documentation"]["name"] == "Page"
    ]
    if (
        len(controls) != 25
        or len(intrinsic_controls) != 15
        or len(html_controls) != 10
        or len(pages) != 1
        or "TYPEFLAG_FCANCREATE" not in pages[0]["type_flags"]
    ):
        raise FactError("FM20 primary control/Page coclass universe drift")
    return {
        "typelib": {
            "guid": attrs["guid"].upper(),
            "major_version": attrs["major_version"],
            "minor_version": attrs["minor_version"],
            "syskind_name": attrs["syskind_name"],
            "source_file_name": root["source"]["file_name"],
            "source_file_version": root["source"]["file_version"],
            "source_length": root["source"]["size_bytes"],
            "source_sha256": root["source"]["sha256"],
        },
        "primary_nonhidden_fcontrol_coclasses": controls,
        "primary_intrinsic_fcontrol_coclasses": intrinsic_controls,
        "primary_html_fcontrol_coclasses": html_controls,
        "page_coclass": pages[0],
        "hidden_fcontrol_coclasses_not_covered_by_forward_progids": hidden_controls,
    }


def _control_identifiers(
    ms_oforms: dict[str, Any],
    capture: dict[str, Any],
    fm20: dict[str, Any],
) -> dict[str, Any]:
    universe = _fm20_control_universe(fm20)
    observed_instances: list[dict[str, Any]] = [
        {
            "fixture_id": form["fixture_id"],
            "name": form["component_name"],
            "family": "UserForm",
            "progid": None,
            "container": None,
            "observation": "exported root designer",
        }
        for form in capture["forms"]
    ]
    for form in capture["forms"]:
        for control in form["controls"]:
            observed_instances.append(
                {
                    "fixture_id": form["fixture_id"],
                    "name": control["name"],
                    "family": control["family"],
                    "progid": control["progid"],
                    "container": control["container"],
                    "observation": "public designer Controls.Add instance",
                }
            )
        for control in form["controls"]:
            for page in control.get("pages", []):
                observed_instances.append(
                    {
                        "fixture_id": form["fixture_id"],
                        "name": page.get("readback_name") or page.get("name"),
                        "family": "Page",
                        "progid": None,
                        "container": f"control:{control['name']}",
                        "observation": "MultiPage Pages collection instance",
                    }
                )
    registrations = []
    for row in capture["progid_registrations"]:
        _require_keys(
            row,
            {"progid", "clsid", "class_name", "inproc_server"},
            f"ProgID registration {row.get('progid')}",
        )
        server = row["inproc_server"]
        if not isinstance(row["class_name"], str) or not row["class_name"]:
            raise FactError(f"ProgID {row['progid']} lacks a registered class name")
        if re.fullmatch(r"\{[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}\}", row["clsid"]) is None:
            raise FactError(f"ProgID {row['progid']} lacks a canonical CLSID")
        if not isinstance(server, dict):
            raise FactError(f"ProgID {row['progid']} lacks an in-process server")
        _require_keys(
            server,
            {"path", "length", "sha256", "file_version", "product_version"},
            f"ProgID {row['progid']} in-process server",
        )
        server_path = PureWindowsPath(server["path"])
        if (
            not server_path.is_absolute()
            or server_path.name.upper() != "FM20.DLL"
            or not isinstance(server["length"], int)
            or server["length"] <= 0
            or re.fullmatch(r"[0-9a-f]{64}", server["sha256"]) is None
            or not all(
                isinstance(server[key], str) and server[key]
                for key in ("file_version", "product_version")
            )
        ):
            raise FactError(f"ProgID {row['progid']} has malformed server facts")
        registrations.append(
            {
                "progid": row["progid"],
                "clsid": row["clsid"],
                "class_name": row["class_name"],
                "inproc_server": {
                    "file_name": server_path.name,
                    "length": server["length"],
                    "sha256": server["sha256"],
                    "file_version": server["file_version"],
                    "product_version": server["product_version"],
                },
            }
        )
    primary_by_name = {
        row["name"]: row
        for row in universe["primary_nonhidden_fcontrol_coclasses"]
    }
    expected_add_families = set(primary_by_name) - {"UserForm"}
    family_progids: dict[str, str] = {}
    for form in capture["forms"]:
        for control in form["controls"]:
            previous = family_progids.setdefault(control["family"], control["progid"])
            if previous != control["progid"]:
                raise FactError(f"multiple ProgIDs captured for {control['family']}")
    for probe in capture["designer_add_probes"]:
        previous = family_progids.setdefault(probe["family"], probe["progid"])
        if previous != probe["progid"]:
            raise FactError(f"multiple ProgIDs captured for {probe['family']}")
    if set(family_progids) != expected_add_families:
        raise FactError("capture family/ProgID universe differs from FM20 primary controls")
    registration_by_progid = {row["progid"]: row for row in registrations}
    if set(registration_by_progid) != set(family_progids.values()):
        raise FactError("registered ProgID set differs from the FM20-bound capture set")
    joins = []
    for family, progid in sorted(family_progids.items()):
        registration = registration_by_progid[progid]
        expected_coclass = primary_by_name[family]
        if registration["clsid"] != expected_coclass["guid"]:
            raise FactError(f"ProgID/CLSID/FM20 coclass drift for {family}")
        server = registration["inproc_server"]
        typelib = universe["typelib"]
        if (
            server["length"] != typelib["source_length"]
            or server["sha256"] != typelib["source_sha256"]
            or server["file_version"] != typelib["source_file_version"]
        ):
            raise FactError(f"FM20 server identity drift for {family}")
        joins.append(
            {
                "family": family,
                "progid": progid,
                "registered_clsid": registration["clsid"],
                "fm20_coclass_guid": expected_coclass["guid"],
                "match": True,
            }
        )

    families = sorted({row["family"] for row in observed_instances})
    expected_intrinsic = {
        row["name"]
        for row in universe["primary_intrinsic_fcontrol_coclasses"]
    } | {universe["page_coclass"]["name"]}
    if set(families) != expected_intrinsic:
        raise FactError(f"intrinsic observed family set differs: {families}")
    if primary_by_name["UserForm"]["guid"].strip("{}") != USERFORM_CLSID:
        raise FactError("captured UserForm CLSID differs from pinned FM20 coclass")
    return {
        "fm20_control_universe": universe,
        "forward_progid_fm20_coclass_joins": joins,
        "ms_oforms_cached_control_ids": ms_oforms["cached_control_ids"],
        "live_progid_registrations": registrations,
        "observed_instances": observed_instances,
        "observed_intrinsic_families": families,
        "designer_add_probes": capture["designer_add_probes"],
        "html_probe_boundary": "All ten primary/original HTML forward ProgIDs were registered on the capture machine, but designer Controls.Add rejected them with E_INVALIDARG. The ten hidden HTML*2 coclasses and other hidden second-generation control coclasses are explicitly not covered. This proves only forward-ProgID designer-add rejection in this host/build, not runtime non-callability.",
    }


def _binary_persistence_contract(ms_oforms: dict[str, Any]) -> dict[str, Any]:
    """Project source-linked binary obligations from the pinned .3 fact pack."""

    object_property_names = {"Font", "MouseIcon", "Picture"}
    object_type_names = {
        "FormFont",
        "GuidAndFont",
        "GuidAndPicture",
        "StdFont",
        "StdPicture",
    }
    object_properties = [
        copy.deepcopy(row)
        for row in ms_oforms["properties"]
        if row["name"] in object_property_names
    ]
    object_types = [
        copy.deepcopy(row)
        for row in ms_oforms["property_types"]
        if row["name"] in object_type_names
    ]
    object_formats = [
        copy.deepcopy(row)
        for row in ms_oforms["resource_formats"]
        if row["name"] in object_type_names
    ]
    stream_slots = [
        copy.deepcopy(row)
        for row in ms_oforms["record_sections"]
        if row["name"].endswith("StreamData")
    ]
    presence_flags = []
    for bitfield in ms_oforms["bitfields"]:
        for entry in bitfield["entries"]:
            if entry.get("field_name") in {"fFont", "fPicture", "fMouseIcon"}:
                presence_flags.append(
                    {
                        "bitfield": bitfield["name"],
                        "section": bitfield["section"],
                        **copy.deepcopy(entry),
                    }
                )
    if not (
        len(object_properties) == 3
        and len(object_types) == 5
        and len(object_formats) == 5
        and len(stream_slots) == 8
        and len(presence_flags) == 14
    ):
        raise FactError("MS-OFORMS object-valued encoding universe drift")

    fields_by_identity: dict[tuple[str, str, str], dict[str, Any]] = {}
    for row in ms_oforms["record_fields"]:
        identity = (row["section"], row["record"], row["name"])
        if identity in fields_by_identity:
            raise FactError(f"duplicate MS-OFORMS record-field identity: {identity}")
        fields_by_identity[identity] = row
    length_fields: list[dict[str, Any]] = []
    field_group_counts: dict[str, int] = {}
    selected_identities: set[tuple[str, str, str]] = set()
    for group, identities in BINARY_LENGTH_FIELD_GROUPS.items():
        field_group_counts[group] = len(identities)
        for identity in identities:
            if identity in selected_identities:
                raise FactError(f"duplicate binary length/count selection: {identity}")
            selected_identities.add(identity)
            if identity not in fields_by_identity:
                raise FactError(f"missing MS-OFORMS binary length/count field: {identity}")
            length_fields.append(
                {
                    "selection_group": group,
                    **copy.deepcopy(fields_by_identity[identity]),
                }
            )
    if len(length_fields) != 43 or field_group_counts != {
        "aggregate_record_byte_lengths": 15,
        "string_count_and_compression_fields": 14,
        "variable_region_byte_lengths": 7,
        "collection_counts": 5,
        "resource_payload_lengths": 2,
    }:
        raise FactError("MS-OFORMS binary length/count field universe drift")
    resource_formats_by_name = {
        row["name"]: row for row in ms_oforms["resource_formats"]
    }
    if not all(name in resource_formats_by_name for name in BINARY_LENGTH_CODEC_NAMES):
        raise FactError("MS-OFORMS binary length/count codec universe drift")
    length_codecs = [
        copy.deepcopy(resource_formats_by_name[name])
        for name in BINARY_LENGTH_CODEC_NAMES
    ]

    property_defaults = [
        {
            "name": row["name"],
            "section": row["section"],
            "applies_to": row["applies_to"],
            "default": copy.deepcopy(row["default"]),
            "source_segment_ids": row["source_segment_ids"],
        }
        for row in ms_oforms["properties"]
    ]
    default_statuses = Counter(row["default"]["status"] for row in property_defaults)
    propmasks = [
        copy.deepcopy(row)
        for row in ms_oforms["bitfields"]
        if "PropMask" in row["name"]
    ]
    if (
        len(property_defaults) != 98
        or default_statuses
        != Counter({"documented_default": 95, "mandatory_persist_no_default": 3})
        or len(ms_oforms["default_matrix"]) != 107
        or len(propmasks) != 15
        or sum(len(row["entries"]) for row in propmasks) != 221
    ):
        raise FactError("MS-OFORMS omission/default universe drift")

    storage_requirements = []
    for collection_name in ("record_sections", "record_fields"):
        requirement_key = (
            "section_requirements"
            if collection_name == "record_sections"
            else "requirements"
        )
        for row in ms_oforms[collection_name]:
            if row.get(requirement_key):
                storage_requirements.append(
                    {
                        "collection": collection_name,
                        "name": row["name"],
                        "section": row["section"],
                        "requirements": copy.deepcopy(row[requirement_key]),
                    }
                )

    contract = {
        "authority": "normative/source-linked projection of the pinned oxforms-jbjp.3 MS-OFORMS fact pack; no live FRX value decoding is implied",
        "object_valued_encodings": {
            "properties": object_properties,
            "type_layouts": object_types,
            "resource_formats": object_formats,
            "stream_data_slots": stream_slots,
            "presence_flags": presence_flags,
            "live_nondefault_object_probes": [],
            "decoded_live_values": 0,
        },
        "binary_length_forms": {
            "record_fields": length_fields,
            "record_field_group_counts": field_group_counts,
            "resource_format_codecs": length_codecs,
            "selection_boundary": "Complete explicit selection of source fields whose own or directly linked normative definitions control aggregate bytes, string count/compression, variable byte regions, serialized structural-array counts, or resource payload lengths. Other runtime property counts remain in the complete pinned source universe when no pinned requirement makes them an array/byte-extent driver; CountOfMethods reports type-information semantics rather than a serialized-array extent.",
            "textual_ole_object_blob_observation": "three exact :0000 references; no nonzero textual offset or lexical length claim",
            "nonzero_textual_offset_claims": [],
            "textual_length_claims": [],
        },
        "omission_and_defaults": {
            "property_defaults": property_defaults,
            "property_default_status_counts": dict(sorted(default_statuses.items())),
            "control_specific_default_matrix": copy.deepcopy(
                ms_oforms["default_matrix"]
            ),
            "property_masks": propmasks,
            "storage_requirements": storage_requirements,
        },
        "source_universe_counts": {
            key: len(ms_oforms[key])
            for key in (
                "properties",
                "property_types",
                "resource_formats",
                "record_sections",
                "record_fields",
                "bitfields",
                "default_matrix",
                "control_families",
                "cached_control_ids",
                "documented_unknowns",
            )
        },
    }
    _validate_binary_persistence_contract(contract)
    return contract


def _validate_binary_persistence_contract(contract: Any) -> None:
    if not isinstance(contract, dict):
        raise FactError("binary persistence contract is not an object")
    _require_keys(
        contract,
        {
            "authority",
            "object_valued_encodings",
            "binary_length_forms",
            "omission_and_defaults",
            "source_universe_counts",
        },
        "binary persistence contract",
    )
    if contract["authority"] != (
        "normative/source-linked projection of the pinned oxforms-jbjp.3 "
        "MS-OFORMS fact pack; no live FRX value decoding is implied"
    ):
        raise FactError("binary persistence authority boundary drift")

    object_contract = contract["object_valued_encodings"]
    length_contract = contract["binary_length_forms"]
    omission_contract = contract["omission_and_defaults"]
    if not all(
        isinstance(value, dict)
        for value in (object_contract, length_contract, omission_contract)
    ):
        raise FactError("binary persistence contract surface is not an object")
    _require_keys(
        object_contract,
        {
            "properties",
            "type_layouts",
            "resource_formats",
            "stream_data_slots",
            "presence_flags",
            "live_nondefault_object_probes",
            "decoded_live_values",
        },
        "binary object-valued contract",
    )
    _require_keys(
        length_contract,
        {
            "record_fields",
            "record_field_group_counts",
            "resource_format_codecs",
            "selection_boundary",
            "textual_ole_object_blob_observation",
            "nonzero_textual_offset_claims",
            "textual_length_claims",
        },
        "binary length/count contract",
    )
    _require_keys(
        omission_contract,
        {
            "property_defaults",
            "property_default_status_counts",
            "control_specific_default_matrix",
            "property_masks",
            "storage_requirements",
        },
        "binary omission/default contract",
    )

    surfaces = {
        "object_properties": object_contract["properties"],
        "object_types": object_contract["type_layouts"],
        "object_formats": object_contract["resource_formats"],
        "stream_slots": object_contract["stream_data_slots"],
        "presence_flags": object_contract["presence_flags"],
        "property_defaults": omission_contract["property_defaults"],
        "default_matrix": omission_contract["control_specific_default_matrix"],
        "property_masks": omission_contract["property_masks"],
        "storage_requirements": omission_contract["storage_requirements"],
        "length_fields": length_contract["record_fields"],
        "length_codecs": length_contract["resource_format_codecs"],
    }
    if (
        not isinstance(length_contract["record_fields"], list)
        or len(length_contract["record_fields"]) != 43
        or not isinstance(length_contract["resource_format_codecs"], list)
        or len(length_contract["resource_format_codecs"]) != 4
    ):
        raise FactError("binary persistence contract coverage drift")
    expected_length_identities = [
        (group, section, record, name)
        for group, identities in BINARY_LENGTH_FIELD_GROUPS.items()
        for section, record, name in identities
    ]
    actual_length_identities = [
        (
            row.get("selection_group"),
            row.get("section"),
            row.get("record"),
            row.get("name"),
        )
        for row in length_contract["record_fields"]
        if isinstance(row, dict)
    ]
    if actual_length_identities != expected_length_identities:
        raise FactError("binary persistence length/count field identity drift")
    for name, value in surfaces.items():
        digest = sha256_bytes(canonical_json_bytes(value))
        if digest != BINARY_CONTRACT_SURFACE_DIGESTS[name]:
            raise FactError(f"binary persistence {name} identity drift")

    if object_contract["live_nondefault_object_probes"] != []:
        raise FactError("unsupported live object-valued probe claim was introduced")
    if (
        isinstance(object_contract["decoded_live_values"], bool)
        or not isinstance(object_contract["decoded_live_values"], int)
        or object_contract["decoded_live_values"] != 0
    ):
        raise FactError("unsupported decoded live object-valued claim was introduced")
    expected_group_counts = {
        "aggregate_record_byte_lengths": 15,
        "string_count_and_compression_fields": 14,
        "variable_region_byte_lengths": 7,
        "collection_counts": 5,
        "resource_payload_lengths": 2,
    }
    if length_contract["record_field_group_counts"] != expected_group_counts:
        raise FactError("binary persistence record-field group counts drift")
    if not all(
        isinstance(value, int) and not isinstance(value, bool) and value > 0
        for value in length_contract["record_field_group_counts"].values()
    ):
        raise FactError("binary persistence record-field group count is malformed")
    if length_contract["selection_boundary"] != (
        "Complete explicit selection of source fields whose own or directly linked "
        "normative definitions control aggregate bytes, string count/compression, "
        "variable byte regions, serialized structural-array counts, or resource "
        "payload lengths. Other runtime property counts remain in the complete "
        "pinned source universe when no pinned requirement makes them an array/byte-"
        "extent driver; CountOfMethods reports type-information semantics rather than "
        "a serialized-array extent."
    ):
        raise FactError("binary persistence length-selection boundary drift")
    if length_contract["textual_ole_object_blob_observation"] != (
        "three exact :0000 references; no nonzero textual offset or lexical length claim"
    ):
        raise FactError("binary persistence textual-reference boundary drift")
    if (
        length_contract["nonzero_textual_offset_claims"] != []
        or length_contract["textual_length_claims"] != []
    ):
        raise FactError("unsupported textual offset/length claim was introduced")
    if omission_contract["property_default_status_counts"] != {
        "documented_default": 95,
        "mandatory_persist_no_default": 3,
    }:
        raise FactError("binary persistence default-status counts drift")
    if sum(
        len(row.get("entries", []))
        for row in omission_contract["property_masks"]
        if isinstance(row, dict)
    ) != 221:
        raise FactError("binary persistence property-mask entry coverage drift")
    if contract["source_universe_counts"] != BINARY_SOURCE_UNIVERSE_COUNTS:
        raise FactError("binary persistence source-universe counts drift")


def _legacy_corpus(repo_root: Path) -> list[dict[str, Any]]:
    corpus_root = repo_root / "fixtures" / "frm"
    rows: list[dict[str, Any]] = []
    for path in sorted(corpus_root.rglob("*.frm")):
        raw = path.read_bytes()
        base = {
            "path": path.relative_to(repo_root).as_posix(),
            "length": len(raw),
            "sha256": sha256_bytes(raw),
            "profile": LEGACY_SYNTHETIC_NESTED,
            "authority_class": "project_authored_synthetic_not_office_export",
            "may_establish_office_export_facts": False,
        }
        try:
            inventory = inventory_frm_file(path, 65001, profile=LEGACY_SYNTHETIC_NESTED)
            base.update({"parse_status": "complete", "inventory": inventory, "parse_error": None})
        except FRMError as exc:
            base.update(
                {
                    "parse_status": "partial_designer_only_fixture_rejected_by_complete_profile",
                    "inventory": None,
                    "parse_error": str(exc),
                }
            )
        rows.append(base)
    for path in sorted(corpus_root.rglob("*.frx")):
        raw = path.read_bytes()
        try:
            inventory = inventory_cfb_file(path)
            status, error = "cfb_inventory", None
        except CFBError as exc:
            inventory, status, error = None, "non_cfb_stub", str(exc)
        rows.append(
            {
                "path": path.relative_to(repo_root).as_posix(),
                "length": len(raw),
                "sha256": sha256_bytes(raw),
                "profile": LEGACY_SYNTHETIC_NESTED,
                "authority_class": "project_authored_synthetic_not_office_export",
                "may_establish_office_export_facts": False,
                "parse_status": status,
                "inventory": inventory,
                "parse_error": error,
            }
        )
    return rows


def _summary(
    source_rows: list[dict[str, Any]],
    fixtures: list[dict[str, Any]],
    references: list[dict[str, Any]],
    cfb_inventories: list[dict[str, Any]],
    designer_properties: list[dict[str, Any]],
    mappings: list[dict[str, Any]],
    control_identifiers: dict[str, Any],
    legacy: list[dict[str, Any]],
    binary_contract: dict[str, Any],
) -> dict[str, Any]:
    source_kinds = Counter(row["record"]["kind"] for row in source_rows)
    mapping_classes = Counter(row["classification"] for row in mappings)
    mapping_family_classes = Counter(
        family["status"]
        for row in mappings
        for family in row["family_coverage"]
    )
    cfb_entries = [
        entry
        for row in cfb_inventories
        for entry in row["inventory"]["entries"]
    ]
    cfb_regions = [
        region
        for row in cfb_inventories
        for region in row["inventory"]["byte_regions"]
    ]
    mini_regions = [
        region
        for row in cfb_inventories
        for region in row["inventory"]["mini_regions"]
    ]
    physical_regions = [
        region
        for row in cfb_inventories
        for region in row["inventory"]["physical_regions"]
    ]
    mini_physical_regions = [
        region
        for row in cfb_inventories
        for region in row["inventory"]["mini_physical_regions"]
    ]
    controls = [control for fixture in fixtures for control in fixture["controls"]]
    return {
        "source_rows": len(source_rows),
        "source_kind_counts": dict(sorted(source_kinds.items())),
        "profiles": 3,
        "real_office_fixture_pairs": len(fixtures),
        "real_office_frm_bytes": sum(fixture["frm_inventory"]["source"]["length"] for fixture in fixtures),
        "real_office_frx_bytes": sum(row["inventory"]["source"]["length"] for row in cfb_inventories),
        "resource_references": len(references),
        "designer_properties": len(designer_properties),
        "controlled_omission_pairs": 8,
        "component_headers": len(fixtures),
        "opaque_code_bodies": len(fixtures),
        "cfb_storages": sum(entry["type"] == "storage" for entry in cfb_entries),
        "cfb_streams": sum(entry["type"] == "stream" for entry in cfb_entries),
        "cfb_roots": sum(entry["type"] == "root" for entry in cfb_entries),
        "cfb_byte_regions": len(cfb_regions),
        "cfb_mini_regions": len(mini_regions),
        "cfb_physical_regions": len(physical_regions),
        "cfb_mini_physical_regions": len(mini_physical_regions),
        "captured_control_instances": len(controls),
        "observed_intrinsic_families": len(control_identifiers["observed_intrinsic_families"]),
        "registered_progids": len(control_identifiers["live_progid_registrations"]),
        "html_designer_add_rejections": len(control_identifiers["designer_add_probes"]),
        "ms_oforms_cached_control_ids": len(control_identifiers["ms_oforms_cached_control_ids"]),
        "ms_oforms_property_mappings": len(mappings),
        "property_mapping_class_counts": dict(sorted(mapping_classes.items())),
        "property_mapping_family_pairs": sum(
            len(row["family_coverage"]) for row in mappings
        ),
        "property_mapping_family_pair_counts": dict(
            sorted(mapping_family_classes.items())
        ),
        "exact_name_rows_with_full_family_coverage": sum(
            row["classification"] == "live_public_property_probe_exact_name"
            and all(
                item["status"] == "exact_name_live_probe"
                for item in row["family_coverage"]
            )
            for row in mappings
        ),
        "normative_object_valued_properties": len(
            binary_contract["object_valued_encodings"]["properties"]
        ),
        "normative_object_type_layouts": len(
            binary_contract["object_valued_encodings"]["type_layouts"]
        ),
        "normative_binary_length_fields": len(
            binary_contract["binary_length_forms"]["record_fields"]
        ),
        "normative_default_matrix_rows": len(
            binary_contract["omission_and_defaults"][
                "control_specific_default_matrix"
            ]
        ),
        "normative_property_masks": len(
            binary_contract["omission_and_defaults"]["property_masks"]
        ),
        "fm20_primary_nonhidden_control_coclasses": len(
            control_identifiers["fm20_control_universe"][
                "primary_nonhidden_fcontrol_coclasses"
            ]
        ),
        "fm20_hidden_control_coclasses_not_forward_progid_covered": len(
            control_identifiers["fm20_control_universe"][
                "hidden_fcontrol_coclasses_not_covered_by_forward_progids"
            ]
        ),
        "unknown_preservation_classes": len(UNKNOWN_POLICIES),
        "legacy_synthetic_files": len(legacy),
        "legacy_complete_inventory_files": sum(row["parse_status"] in {"complete", "cfb_inventory"} for row in legacy),
        "runtime_api_claims": 0,
        "decoded_frx_property_values": 0,
    }


def _coverage_contract() -> dict[str, str]:
    return {
        "frm": "Every captured FRM byte is classified exactly once by the strict Office profile.",
        "frx": "Every captured FRX byte is accounted for by the opaque prefix plus the strict CFB logical extent and any inventoried trailing region; CFB sector ownership, chains, streams, free sectors, and mini-stream allocation are validated without decoding control-property values.",
        "ms_oforms_properties": "One mapping row exists for each of the 98 independently generated MS-OFORMS properties.",
        "controls": "The capture contains all 14 intrinsic Controls.Add families plus UserForm and Page structural instances.",
        "unknowns": "Unknown text, prefix, stream, storage, free, and trailing classes each have an explicit preserve-or-reject rule.",
    }


def _boundaries_contract() -> dict[str, Any]:
    return {
        "observed_export_profile": OFFICE_VBA_USERFORM_EXPORT,
        "ole_object_blob": "Observed Office/VBIDE extension; not promoted to normative MS-OVBA DesignerProperties grammar.",
        "frx_prefix": "Opaque. No meaning is assigned to any of the 24 pre-CFB bytes.",
        "frx_binary_values": "No control property value is decoded from FRX by this bead.",
        "nested_text": "Legacy nested Begin/End fixtures are non-authoritative for Office VBA export.",
        "runtime_api_claims": [],
        "codec_claims": [],
        "vb6_claims": [],
        "html_claim": "Registered ProgIDs plus same-build designer-add E_INVALIDARG only.",
    }


def build_fact_pack(
    repo_root: Path,
    pins_path: Path,
    *,
    require_clean_foundation: bool = True,
) -> tuple[dict[str, Any], dict[str, Any]]:
    repo_root = repo_root.resolve()
    pins = load_pins(pins_path)
    foundation = verify_foundation(repo_root, pins, require_clean=require_clean_foundation)
    local = verify_local_dependencies(repo_root, pins)
    capture_spec = local["LIVE-EXPORT-CAPTURE-SPEC"]["value"]
    capture = local["LIVE-EXPORT-CAPTURE-MANIFEST"]["value"]
    fm20 = local["W010-FM20-FACTS"]["value"]
    ms_oforms = local["W010-MS-OFORMS-FACTS"]["value"]
    ms_cfb = local["MS-CFB-SELECTED-RULES"]["value"]
    if not all(
        isinstance(row, dict)
        for row in (capture_spec, capture, fm20, ms_oforms, ms_cfb)
    ):
        raise FactError("required local JSON dependencies did not load as objects")
    if ms_cfb.get("schema") != "oxforms.forms-persistence.ms-cfb-selected-rules.v1":
        raise FactError("unexpected selected MS-CFB rule schema")
    _validate_capture_pair(capture_spec, capture)
    _validate_manifest_self_pins(
        repo_root,
        capture,
        local["LIVE-EXPORT-CAPTURE-MANIFEST"]["path"],
    )
    source_rows = _load_selected_source_rows(foundation, pins)
    _derive_designer_property_specs(source_rows)
    fixtures, references, cfb_inventories, code_boundaries = _fixture_facts(
        repo_root, capture, capture_spec
    )
    designer_properties = _designer_property_facts(fixtures)
    omission_pairs = _omission_pairs(fixtures)
    property_mappings = _property_mappings(ms_oforms, capture)
    control_identifiers = _control_identifiers(ms_oforms, capture, fm20)
    binary_contract = _binary_persistence_contract(ms_oforms)
    legacy = _legacy_corpus(repo_root)
    profiles = _profiles()
    grammar = _grammar(source_rows, fixtures)
    component_headers = _component_headers(fixtures)
    summary = _summary(
        source_rows,
        fixtures,
        references,
        cfb_inventories,
        designer_properties,
        property_mappings,
        control_identifiers,
        legacy,
        binary_contract,
    )
    pack: dict[str, Any] = {
        "schema": FACT_SCHEMA,
        "schema_version": 1,
        "canonical_sha256": "",
        "generator": {
            "tool": "tools/forms-persistence/export_frm_frx_facts.py",
            "library": "tools/forms-persistence/frm_frx_facts.py",
            "pinned_sources": pins_path.relative_to(repo_root).as_posix(),
            "pinned_sources_sha256": sha256_bytes(canonical_json_bytes(pins)),
            "determinism": "canonical UTF-8/LF JSON; no timestamps or absolute checkout paths",
        },
        "sources": _public_sources(pins, local),
        "source_rows": source_rows,
        "profiles": profiles,
        "fixtures": fixtures,
        "grammar": grammar,
        "designer_properties": {
            "normative_ordered_universe": designer_properties,
            "controlled_omission_pairs": omission_pairs,
        },
        "component_headers": component_headers,
        "code_boundaries": code_boundaries,
        "resource_references": references,
        "cfb_source_rules": ms_cfb,
        "cfb_inventories": cfb_inventories,
        "binary_persistence_contract": binary_contract,
        "control_identifiers": control_identifiers,
        "property_mappings": property_mappings,
        "unknown_preservation": list(UNKNOWN_POLICIES),
        "legacy_synthetic_corpus": legacy,
        "coverage": _coverage_contract(),
        "boundaries": _boundaries_contract(),
        "summary": summary,
    }
    pack["canonical_sha256"] = semantic_sha256(pack)
    validate_fact_pack(pack, pins=pins)
    return pins, pack


def validate_fact_pack(
    pack: dict[str, Any],
    *,
    pins: dict[str, Any],
    expected: dict[str, Any] | None = None,
) -> None:
    if not isinstance(pack, dict):
        raise FactError("fact pack is not a JSON object")
    _require_keys(pack, TOP_LEVEL_KEYS, "fact pack")
    if pack["schema"] != FACT_SCHEMA or pack["schema_version"] != 1:
        raise FactError("fact-pack schema/version mismatch")
    actual_digest = semantic_sha256(pack)
    if pack["canonical_sha256"] != actual_digest:
        raise FactError("canonical_sha256 mismatch")
    if pack["generator"]["pinned_sources_sha256"] != sha256_bytes(canonical_json_bytes(pins)):
        # This is the semantic digest of the strict, duplicate-key-free pin
        # object. Whitespace/key-order changes to the source file are accepted.
        raise FactError("pinned_sources digest mismatch")
    if pack["profiles"] != _profiles():
        raise FactError("profile boundary table drift")
    if pack["unknown_preservation"] != list(UNKNOWN_POLICIES):
        raise FactError("unknown-preservation contract drift")
    windows_absolute = re.compile(r"(?i)(?:^|[\s\"'])(?:[a-z]:[\\/]|\\\\[^\\/]+[\\/])")
    if any(windows_absolute.search(value) for value in _walk_strings(pack)):
        raise FactError("absolute checkout path leaked into generated fact pack")
    if pack["coverage"] != _coverage_contract():
        raise FactError("coverage narrative contract drift")
    boundaries = pack["boundaries"]
    if isinstance(boundaries, dict) and any(
        boundaries.get(key) for key in ("runtime_api_claims", "codec_claims", "vb6_claims")
    ):
        raise FactError("boundary non-claim arrays must remain empty")
    if pack["boundaries"] != _boundaries_contract():
        raise FactError("evidence-boundary contract drift")
    if len(pack["designer_properties"]["normative_ordered_universe"]) != 15:
        raise FactError("DesignerProperties universe must contain exactly 15 ordered rows")
    for index, row in enumerate(pack["designer_properties"]["normative_ordered_universe"]):
        if row["order"] != index or row["name"] != DESIGNER_PROPERTY_SPECS[index]["name"]:
            raise FactError("DesignerProperties order/name drift")
    if len(pack["designer_properties"]["controlled_omission_pairs"]) != 8:
        raise FactError("controlled omission pair count drift")
    if len(pack["property_mappings"]) != 98:
        raise FactError("MS-OFORMS property coverage is not exactly 98")
    binary_contract = pack["binary_persistence_contract"]
    _validate_binary_persistence_contract(binary_contract)
    if (
        pack["cfb_source_rules"].get("schema")
        != "oxforms.forms-persistence.ms-cfb-selected-rules.v1"
        or len(pack["cfb_source_rules"].get("selected_sections", [])) != 5
    ):
        raise FactError("selected MS-CFB source-rule coverage drift")
    if len({row["name"] for row in pack["property_mappings"]}) != 98:
        raise FactError("duplicate MS-OFORMS property mapping")
    for row in pack["property_mappings"]:
        if row.get("classification") not in {
            "live_public_property_probe_exact_name",
            "failed_live_public_property_probe_exact_name",
            "live_context_only_not_exact_property_probe",
            "failed_live_context_only_not_exact_property_probe",
            "documented_internal_structure_only",
            "documented_no_exact_live_probe",
        }:
            raise FactError(f"unknown property classification for {row['name']}")
        coverage = row.get("family_coverage", [])
        if not isinstance(coverage, list) or not all(
            isinstance(item, dict) for item in coverage
        ):
            raise FactError(f"property-family coverage is malformed for {row['name']}")
        if [item.get("family") for item in coverage] != row["applies_to"]:
            raise FactError(f"property-family coverage drift for {row['name']}")
        for item in coverage:
            if not isinstance(item, dict):
                raise FactError(f"property-family row is malformed for {row['name']}")
            _require_keys(
                item,
                {
                    "family",
                    "status",
                    "probe_count",
                    "successful_probe_count",
                    "failed_probe_count",
                    "probe_owners",
                },
                f"property-family coverage for {row['name']}",
            )
            if item.get("status") not in {
                "exact_name_live_probe",
                "failed_exact_name_live_probe",
                "context_only_not_exact_probe",
                "failed_context_probe",
                "documented_internal_only",
                "unprobed",
            }:
                raise FactError(f"unknown property-family status for {row['name']}")
            probe_count = item.get("probe_count")
            successful_count = item.get("successful_probe_count")
            failed_count = item.get("failed_probe_count")
            if (
                not all(
                    isinstance(value, int) and not isinstance(value, bool) and value >= 0
                    for value in (probe_count, successful_count, failed_count)
                )
                or probe_count != successful_count + failed_count
            ):
                raise FactError(f"property-family probe count drift for {row['name']}")
            if item["status"] in {
                "exact_name_live_probe",
                "context_only_not_exact_probe",
            }:
                if successful_count <= 0:
                    raise FactError(
                        f"successful property-family evidence drift for {row['name']}"
                    )
            elif item["status"] in {
                "failed_exact_name_live_probe",
                "failed_context_probe",
            }:
                if successful_count != 0 or failed_count <= 0:
                    raise FactError(
                        f"failed property-family evidence drift for {row['name']}"
                    )
            elif probe_count != 0:
                raise FactError(f"property-family probe count drift for {row['name']}")
        classification = row["classification"]
        statuses = [item["status"] for item in coverage]
        live_probes = row.get("live_probes")
        if not isinstance(live_probes, list) or not all(
            isinstance(probe, dict) for probe in live_probes
        ):
            raise FactError(f"property live-probe surface drift for {row['name']}")
        successful_live = sum(
            probe.get("succeeded", True) is True for probe in live_probes
        )
        failed_live = sum(
            probe.get("succeeded", True) is not True for probe in live_probes
        )
        if classification in {
            "live_public_property_probe_exact_name",
            "failed_live_public_property_probe_exact_name",
        } and any(
            probe.get("name") != row["name"]
            or not isinstance(probe.get("succeeded"), bool)
            for probe in live_probes
        ):
            raise FactError(f"exact-name live-probe identity drift for {row['name']}")

        def validator_probe_matches_family(
            probe: dict[str, Any], family: str
        ) -> bool:
            owner = probe.get("owner_kind")
            if family == "OleSiteConcrete" and "progid" in probe:
                return True
            if family in {"Form", "DesignExtender"}:
                return owner == "UserForm"
            if family == "OleSiteConcrete":
                return owner is not None and owner != "UserForm"
            return owner == family

        def validator_probe_owner(probe: dict[str, Any]) -> str:
            fixture_id = probe.get("fixture_id")
            owner_name = probe.get("owner_name")
            if isinstance(fixture_id, str) and isinstance(owner_name, str):
                return f"{fixture_id}:{owner_name}"
            progid = probe.get("progid")
            if isinstance(progid, str) and progid:
                return f"registry:{progid}"
            raise FactError(f"property probe owner drift for {row['name']}")

        for family_row in coverage:
            family_probes = [
                probe
                for probe in live_probes
                if validator_probe_matches_family(probe, family_row["family"])
            ]
            family_successes = sum(
                probe.get("succeeded", True) is True for probe in family_probes
            )
            family_failures = len(family_probes) - family_successes
            if classification in {
                "live_public_property_probe_exact_name",
                "failed_live_public_property_probe_exact_name",
            }:
                expected_status = (
                    "exact_name_live_probe"
                    if family_successes
                    else "failed_exact_name_live_probe"
                    if family_probes
                    else "unprobed"
                )
            elif classification in {
                "live_context_only_not_exact_property_probe",
                "failed_live_context_only_not_exact_property_probe",
            }:
                expected_status = (
                    "context_only_not_exact_probe"
                    if family_successes
                    else "failed_context_probe"
                    if family_probes
                    else "unprobed"
                )
            elif classification == "documented_internal_structure_only":
                expected_status = "documented_internal_only"
            else:
                expected_status = "unprobed"
            expected_count = (
                0
                if expected_status in {"documented_internal_only", "unprobed"}
                else len(family_probes)
            )
            expected_owners = (
                []
                if expected_count == 0
                else sorted({validator_probe_owner(probe) for probe in family_probes})
            )
            if (
                family_row["status"] != expected_status
                or family_row["probe_count"] != expected_count
                or family_row["successful_probe_count"]
                != (family_successes if expected_count else 0)
                or family_row["failed_probe_count"]
                != (family_failures if expected_count else 0)
                or family_row["probe_owners"] != expected_owners
            ):
                raise FactError(
                    f"property-family/live-probe reconciliation drift for {row['name']}"
                )
        if classification == "live_public_property_probe_exact_name":
            valid_classification = (
                row.get("observed_as") == row["name"]
                and "exact_name_live_probe" in statuses
                and successful_live > 0
            )
        elif classification == "failed_live_public_property_probe_exact_name":
            valid_classification = (
                row.get("observed_as") == row["name"]
                and "exact_name_live_probe" not in statuses
                and "failed_exact_name_live_probe" in statuses
                and successful_live == 0
                and failed_live > 0
            )
        elif classification == "live_context_only_not_exact_property_probe":
            valid_classification = (
                isinstance(row.get("observed_as"), str)
                and bool(row["observed_as"])
                and not any(
                    status in {
                        "exact_name_live_probe",
                        "failed_exact_name_live_probe",
                    }
                    for status in statuses
                )
                and "context_only_not_exact_probe" in statuses
                and successful_live > 0
            )
        elif classification == "failed_live_context_only_not_exact_property_probe":
            valid_classification = (
                isinstance(row.get("observed_as"), str)
                and bool(row["observed_as"])
                and not any(
                    status in {
                        "exact_name_live_probe",
                        "failed_exact_name_live_probe",
                    }
                    for status in statuses
                )
                and "failed_context_probe" in statuses
                and successful_live == 0
                and failed_live > 0
            )
        elif classification == "documented_internal_structure_only":
            valid_classification = (
                row.get("observed_as") is None
                and live_probes == []
                and statuses
                and set(statuses) == {"documented_internal_only"}
            )
        else:
            valid_classification = (
                row.get("observed_as") is None
                and live_probes == []
                and statuses
                and set(statuses) == {"unprobed"}
            )
        if not valid_classification:
            raise FactError(
                f"property row classification/family evidence drift for {row['name']}"
            )
    if any(row["binary_value_decoded"] or row["runtime_api_claim"] for row in pack["property_mappings"]):
        raise FactError("property mapping overclaims decoded binary/runtime API evidence")
    for fixture in pack["fixtures"]:
        if fixture["authority_class"] != "observed_real_office_export":
            raise FactError("real fixture authority class drift")
        if fixture["profile"] != OFFICE_VBA_USERFORM_EXPORT:
            raise FactError("real fixture profile drift")
        if not fixture["frm_inventory"]["coverage"]["all_bytes_classified_once"]:
            raise FactError("committed FRM inventory lacks full coverage")
        if fixture["frx_prefix"]["length"] != 24 or fixture["frx_prefix"]["interpretation"] != "opaque_observed_prefix":
            raise FactError("FRX prefix boundary drift")
    for row in pack["cfb_inventories"]:
        inventory = row["inventory"]
        if inventory["signature_offset"] != 24 or not inventory["coverage"]["all_bytes_accounted_for"]:
            raise FactError("committed CFB inventory boundary/coverage drift")
        cursor = 0
        for region in inventory["physical_regions"]:
            if region["offset"] != cursor or region["length"] <= 0:
                raise FactError("committed CFB physical partition is not contiguous")
            cursor += region["length"]
        if cursor != inventory["source"]["length"]:
            raise FactError("committed CFB physical partition length drift")
    if any(
        row["lexical_offset_text"] != "0000" or row["lexical_offset"] != 0
        for row in pack["resource_references"]
    ):
        raise FactError("committed OleObjectBlob observation is not exact :0000")
    if any(row["may_establish_office_export_facts"] for row in pack["legacy_synthetic_corpus"]):
        raise FactError("synthetic fixture was promoted to Office-export authority")
    control_ids = pack["control_identifiers"]
    universe = control_ids["fm20_control_universe"]
    expected_intrinsic = {
        row["name"]
        for row in universe["primary_intrinsic_fcontrol_coclasses"]
    } | {universe["page_coclass"]["name"]}
    if set(control_ids["observed_intrinsic_families"]) != expected_intrinsic:
        raise FactError("observed intrinsic family coverage drift")
    if len(control_ids["designer_add_probes"]) != len(
        universe["primary_html_fcontrol_coclasses"]
    ):
        raise FactError("actual HTML designer-add probe coverage drift")
    joins = control_ids["forward_progid_fm20_coclass_joins"]
    if len(joins) != 24 or any(not row["match"] for row in joins):
        raise FactError("forward ProgID/FM20 coclass join coverage drift")
    source_authority = {
        row["source_id"]: row["authority_class"] for row in pack["sources"]
    }
    required_local_authority = {
        "MS-CFB-DOCX": "authoritative_protocol_document",
        "MS-CFB-SELECTED-ROWS": "pinned_normalized_extraction",
        "MS-CFB-EXTRACTOR": "deterministic_extraction_tool",
        "MS-CFB-SELECTED-RULES": "project_interpretation",
        "LIVE-EXPORT-CAPTURE-MANIFEST": "observed_real_office_export",
    }
    if any(
        source_authority.get(source_id) != authority
        for source_id, authority in required_local_authority.items()
    ):
        raise FactError("public-source authority classification drift")
    rebuilt_summary = _summary(
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
    if pack["summary"] != rebuilt_summary:
        raise FactError("fact-pack summary differs from contained surfaces")
    if expected is not None:
        _require_keys(
            expected,
            {"schema", "fact_schema", "pinned_sources_sha256", "canonical_sha256", "summary"},
            "expected capture",
        )
        if expected["schema"] != EXPECTED_SCHEMA or expected["fact_schema"] != FACT_SCHEMA:
            raise FactError("expected-capture schema drift")
        if expected["pinned_sources_sha256"] != pack["generator"]["pinned_sources_sha256"]:
            raise FactError("expected-capture pin digest drift")
        if expected["canonical_sha256"] != pack["canonical_sha256"]:
            raise FactError("expected-capture canonical digest drift")
        if expected["summary"] != pack["summary"]:
            raise FactError("expected-capture summary drift")


def validate_local_surfaces(
    pack: dict[str, Any],
    repo_root: Path,
    pins: dict[str, Any],
) -> None:
    """Rebuild every surface that does not require the Foundation checkout."""

    repo_root = repo_root.resolve()
    local = verify_local_dependencies(repo_root, pins)
    spec = local["LIVE-EXPORT-CAPTURE-SPEC"]["value"]
    capture = local["LIVE-EXPORT-CAPTURE-MANIFEST"]["value"]
    fm20 = local["W010-FM20-FACTS"]["value"]
    ms_oforms = local["W010-MS-OFORMS-FACTS"]["value"]
    _validate_capture_pair(spec, capture)
    _validate_manifest_self_pins(
        repo_root,
        capture,
        local["LIVE-EXPORT-CAPTURE-MANIFEST"]["path"],
    )
    fixtures, references, cfb_inventories, code_boundaries = _fixture_facts(
        repo_root, capture, spec
    )
    _derive_designer_property_specs(pack["source_rows"])
    designer_properties = _designer_property_facts(fixtures)
    omission_pairs = _omission_pairs(fixtures)
    property_mappings = _property_mappings(ms_oforms, capture)
    control_identifiers = _control_identifiers(ms_oforms, capture, fm20)
    binary_contract = _binary_persistence_contract(ms_oforms)
    legacy = _legacy_corpus(repo_root)
    comparisons = {
        "sources": _public_sources(pins, local),
        "coverage": _coverage_contract(),
        "boundaries": _boundaries_contract(),
        "fixtures": fixtures,
        "resource_references": references,
        "cfb_source_rules": local["MS-CFB-SELECTED-RULES"]["value"],
        "cfb_inventories": cfb_inventories,
        "binary_persistence_contract": binary_contract,
        "code_boundaries": code_boundaries,
        "component_headers": _component_headers(fixtures),
        "grammar": _grammar(pack["source_rows"], fixtures),
        "property_mappings": property_mappings,
        "control_identifiers": control_identifiers,
        "legacy_synthetic_corpus": legacy,
    }
    for key, rebuilt in comparisons.items():
        if canonical_json_bytes(pack[key]) != canonical_json_bytes(rebuilt):
            raise FactError(f"committed {key} differs from local deterministic rebuild")
    if pack["designer_properties"] != {
        "normative_ordered_universe": designer_properties,
        "controlled_omission_pairs": omission_pairs,
    }:
        raise FactError("committed designer_properties differs from local rebuild")
    summary = _summary(
        pack["source_rows"],
        fixtures,
        references,
        cfb_inventories,
        designer_properties,
        property_mappings,
        control_identifiers,
        legacy,
        binary_contract,
    )
    if pack["summary"] != summary:
        raise FactError("committed summary differs from local deterministic rebuild")


def load_canonical_fact_pack(path: Path) -> dict[str, Any]:
    value = load_json_strict(path)
    if not isinstance(value, dict):
        raise FactError(f"fact pack is not an object: {path}")
    if path.read_bytes() != canonical_json_bytes(value):
        raise FactError(f"fact pack is not canonical UTF-8/LF JSON: {path}")
    return value


__all__ = [
    "EXPECTED_SCHEMA",
    "FACT_SCHEMA",
    "FactError",
    "build_fact_pack",
    "canonical_json_bytes",
    "load_canonical_fact_pack",
    "load_json_strict",
    "load_pins",
    "semantic_sha256",
    "validate_fact_pack",
    "validate_local_surfaces",
    "verify_local_dependencies",
]
