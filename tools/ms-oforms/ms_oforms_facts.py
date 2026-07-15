"""Deterministic MS-OFORMS persistence/default fact extraction and validation.

The committed fact pack is deliberately standard-library-only.  Foundation's
normalized DOCX segments are the primary capture input; raw source documents,
capture manifests, the run index, and every selected figure are independently
pinned.  Absolute paths from Foundation never enter generated output.
"""

from __future__ import annotations

import copy
import csv
import hashlib
import io
import json
import re
import subprocess
from collections import Counter, defaultdict
from pathlib import Path, PurePosixPath
from typing import Any, Iterable


FACT_SCHEMA_VERSION = "oxforms.ms-oforms.persistence-facts.v1"
PIN_SCHEMA_VERSION = "oxforms.ms-oforms.source-pins.v1"
EXPECTED_SCHEMA_VERSION = "oxforms.ms-oforms.expected-capture.v1"
DOCUMENT_REVISION = "9.1"
DOCUMENT_DATE = "2025-08-19"

TOP_LEVEL_KEYS = {
    "algorithms",
    "bitfields",
    "boundaries",
    "cached_control_ids",
    "capture",
    "control_families",
    "default_matrix",
    "documented_unknowns",
    "enumerations",
    "external_references",
    "product_behavior",
    "properties",
    "property_types",
    "record_fields",
    "record_sections",
    "resource_formats",
    "schema_version",
    "sections",
    "source_rows",
    "sources",
    "summary",
    "table_rows",
    "value_maps",
    "worked_examples",
}

RAW_SEGMENT_KEYS = {
    "document_id",
    "is_blank",
    "kind",
    "segment_id",
    "source",
    "text",
}
RAW_SOURCE_BASE_KEYS = {"anchor", "local_path", "source_id", "source_url"}
RAW_SOURCE_TABLE_KEYS = RAW_SOURCE_BASE_KEYS | {"column", "row", "table"}
RAW_SOURCE_IMAGE_KEYS = RAW_SOURCE_BASE_KEYS | {
    "extracted_image_path",
    "relationship_id",
}

SOURCE_ROW_BASE_KEYS = {
    "anchor",
    "evidence_class",
    "heading",
    "is_blank",
    "kind",
    "section",
    "segment_id",
    "selection_range",
    "text",
}
SOURCE_ROW_TABLE_KEYS = SOURCE_ROW_BASE_KEYS | {"column", "row", "table"}
SOURCE_ROW_IMAGE_KEYS = SOURCE_ROW_BASE_KEYS | {"asset_id", "relationship_id"}

TOC_RE = re.compile(r"^(\d+(?:\.\d+)*)(.*?)(\d+)$")
FIELD_RE = re.compile(r"^(.+?) \(([^()]+)\):\s*(.+)$")
LABELED_BIT_RE = re.compile(r"^(\S+) - (.+?) \((\d+) bits?\):\s*(.+)$")
BIT_RE = re.compile(r"^(?:(\S+) - )?(.+?) \((\d+) bits?\):\s*(.+)$")
PROPERTY_SECTION_RE = re.compile(r"^2\.5\.\d+$")
APPLIES_RE = re.compile(r"^Applies to(?:<\d+>)?:\s*(.+)$")
PRODUCT_BEHAVIOR_RE = re.compile(r"^<(\d+)> Section ([^:]+):\s*(.+)$")
UNKNOWN_RE = re.compile(r"\b(?:(?:undefined|reserved|unused)\w*|ignored)\b", re.I)
HEX_RE = re.compile(r"0x[0-9A-Fa-f]+")
EXTERNAL_REFERENCE_RE = re.compile(r"\[([A-Za-z][A-Za-z0-9-]+)\]")

PERSISTENCE_CONTROLS = (
    "CheckBox",
    "ComboBox",
    "CommandButton",
    "DesignExtender",
    "Form",
    "Frame",
    "Image",
    "Label",
    "ListBox",
    "MultiPage",
    "OleSiteConcrete",
    "OptionButton",
    "Page",
    "ScrollBar",
    "SpinButton",
    "TabStrip",
    "TextBox",
    "TextProps",
    "ToggleButton",
)

VISIBLE_CONTROLS = (
    "CheckBox",
    "ComboBox",
    "CommandButton",
    "Frame",
    "Image",
    "Label",
    "ListBox",
    "MultiPage",
    "OptionButton",
    "Page",
    "ScrollBar",
    "SpinButton",
    "TabStrip",
    "TextBox",
    "ToggleButton",
    "UserForm",
)

FAMILY_SPECS = (
    ("command_button", "CommandButton", "2.2.1", (), ("CommandButton",)),
    ("frame", "Frame", "2.2.2", (), ("Frame",)),
    ("image", "Image", "2.2.3", (), ("Image",)),
    ("label", "Label", "2.2.4", (), ("Label",)),
    (
        "morph_data",
        "MorphData",
        "2.2.5",
        (),
        ("CheckBox", "ComboBox", "ListBox", "OptionButton", "TextBox", "ToggleButton"),
    ),
    ("multi_page", "MultiPage", "2.2.6", ("2.2.6.4",), ("MultiPage",)),
    ("page", "Page", "2.2.6.4", (), ("Page",)),
    ("scroll_bar", "ScrollBar", "2.2.7", (), ("ScrollBar",)),
    ("spin_button", "SpinButton", "2.2.8", (), ("SpinButton",)),
    ("tab_strip", "TabStrip", "2.2.9", (), ("TabStrip",)),
    (
        "user_form_site_container",
        "UserForm, site, and container records",
        "2.2.10",
        (),
        ("UserForm",),
    ),
)

FAMILY_MAPPING_SEGMENTS = {
    "frame": ("001093",),
    "morph_data": ("001630",),
    "multi_page": ("000827", "000828", "002141"),
    "page": ("000662", "000830", "002273"),
    "user_form_site_container": ("000820", "003371"),
}

FAMILY_DEPENDENCY_SPECS = {
    "frame": (
        (
            "parent_storage_and_shared_form_records",
            ("2.1.2.1", "2.1.2.2", "2.1.2.2.2", "2.2.10"),
            "001093",
        ),
    ),
    "multi_page": (
        (
            "form_tabstrip_page_composite",
            ("2.1.2.1", "2.1.2.2", "2.1.2.2.2", "2.2.9", "2.2.10"),
            "000827",
        ),
        (
            "x_stream_page_and_multipage_properties",
            ("2.1.2.3", "2.2.6", "2.2.6.4"),
            "000828",
        ),
    ),
    "page": (
        (
            "embedded_parent_form_and_page_properties",
            ("2.1.2.1", "2.1.2.2.2", "2.1.2.3", "2.1.2.3.1", "2.2.6.4", "2.2.10"),
            "000830",
        ),
    ),
    "user_form_site_container": (
        (
            "parent_storage_layout",
            ("2.1.1.2", "2.1.2.1", "2.1.2.2", "2.2.10"),
            "000820",
        ),
    ),
}

RESOURCE_TYPE_NAMES = {
    "ArrayString",
    "CountOfBytesWithCompressionFlag",
    "CountOfCharsWithCompressionFlag",
    "FormFont",
    "GuidAndFont",
    "GuidAndPicture",
    "StdFont",
    "StdPicture",
    "Strings",
    "fmString",
}

BOUNDARIES = {
    "derived_mapping_policy": (
        "Control-family, table-row, numeric, and concatenated-token mappings are "
        "deterministic derivatives of preserved documented rows and retain their raw cells."
    ),
    "extraction_unknowns": [],
    "oracle_only_rows": [],
    "oracle_policy": (
        "No black-box observation is represented by this pack. Product-behavior appendix "
        "rows remain documented product behavior, not oracle evidence."
    ),
    "runtime_api_claims": [],
    "runtime_api_policy": (
        "Persistence names, hidden persistence-only properties, values, and defaults do not "
        "establish callable runtime API shape or runtime initialization defaults."
    ),
}


class FactError(ValueError):
    """Raised when a source or committed fact violates the frozen contract."""


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise FactError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_nonfinite(value: str) -> None:
    raise FactError(f"non-finite JSON value: {value}")


def loads_json_strict(text: str) -> Any:
    return json.loads(
        text,
        object_pairs_hook=_reject_duplicate_keys,
        parse_constant=_reject_nonfinite,
    )


def _canonical_text_payload(raw: bytes, label: str) -> bytes:
    if b"\r" in raw.replace(b"\r\n", b""):
        raise FactError(f"bare CR is not valid canonical text: {label}")
    normalized = raw.replace(b"\r\n", b"\n")
    try:
        normalized.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise FactError(f"source is not UTF-8 text: {label}: {exc}") from exc
    return normalized


def canonical_text_bytes(path: Path) -> bytes:
    return _canonical_text_payload(path.read_bytes(), str(path))


def load_json_strict(path: Path, *, canonical_text: bool = False) -> Any:
    raw = canonical_text_bytes(path) if canonical_text else path.read_bytes()
    return loads_json_strict(raw.decode("utf-8-sig"))


def load_jsonl_strict(path: Path, *, canonical_text: bool = False) -> list[Any]:
    raw = canonical_text_bytes(path) if canonical_text else path.read_bytes()
    rows: list[Any] = []
    for line_number, line in enumerate(raw.decode("utf-8-sig").splitlines(), 1):
        if not line.strip():
            raise FactError(f"blank JSONL line at {path}:{line_number}")
        try:
            rows.append(loads_json_strict(line))
        except (json.JSONDecodeError, FactError) as exc:
            raise FactError(f"invalid JSONL at {path}:{line_number}: {exc}") from exc
    return rows


def canonical_json_bytes(value: Any) -> bytes:
    try:
        text = json.dumps(
            value,
            allow_nan=False,
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        )
    except (TypeError, ValueError) as exc:
        raise FactError(f"value is not canonical JSON: {exc}") from exc
    return (text + "\n").encode("utf-8")


def load_canonical_json(path: Path) -> Any:
    value = load_json_strict(path)
    if path.read_bytes() != canonical_json_bytes(value):
        raise FactError(f"JSON file is not canonical UTF-8/LF serialization: {path}")
    return value


def semantic_sha256(pack: dict[str, Any]) -> str:
    semantic = copy.deepcopy(pack)
    semantic["capture"].pop("semantic_sha256", None)
    return hashlib.sha256(canonical_json_bytes(semantic)).hexdigest()


def _exact_keys(value: dict[str, Any], expected: set[str], where: str) -> None:
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        raise FactError(f"{where} keys differ; missing={missing}; extra={extra}")


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _foundation_relative_posix_path(value: Any) -> PurePosixPath:
    if not isinstance(value, str) or not value:
        raise FactError(f"source path must be Foundation-relative POSIX: {value!r}")
    parts = value.split("/")
    path = PurePosixPath(value)
    if (
        "\\" in value
        or path.is_absolute()
        or re.match(r"^[A-Za-z]:", value)
        or ":" in value
        or any(part in {"", ".", ".."} for part in parts)
        or path.as_posix() != value
    ):
        raise FactError(f"source path must be Foundation-relative POSIX: {value}")
    return path


def load_pins(path: Path) -> dict[str, Any]:
    pins = load_json_strict(path)
    _exact_keys(
        pins,
        {"foundation_layout", "schema_version", "selection_ranges", "sources"},
        "source pins",
    )
    if pins["schema_version"] != PIN_SCHEMA_VERSION:
        raise FactError(f"unsupported source-pin schema: {pins['schema_version']}")
    _exact_keys(
        pins["foundation_layout"],
        {
            "capture_document_id",
            "capture_git_dirty",
            "capture_tool_commit",
            "extraction_run_id",
            "foundation_commit_observed",
            "source_id",
        },
        "foundation_layout",
    )
    if not pins["foundation_layout"]["capture_git_dirty"]:
        raise FactError("the pinned run-manifest dirty-capture caveat was lost")

    source_ids: set[str] = set()
    for index, source in enumerate(pins["sources"]):
        _exact_keys(
            source,
            {"bytes", "hash_mode", "id", "path", "role", "sha256"},
            f"sources[{index}]",
        )
        if source["id"] in source_ids:
            raise FactError(f"duplicate source id: {source['id']}")
        source_ids.add(source["id"])
        if source["hash_mode"] not in {"raw_bytes", "canonical_lf_utf8"}:
            raise FactError(f"unsupported hash mode for {source['id']}")
        if not isinstance(source["bytes"], int) or source["bytes"] < 0:
            raise FactError(f"invalid byte count for {source['id']}")
        if not re.fullmatch(r"[0-9a-f]{64}", source["sha256"]):
            raise FactError(f"invalid SHA-256 for {source['id']}")
        _foundation_relative_posix_path(source["path"])

    required = {
        "authoritative_docx",
        "authoritative_pdf",
        "document_manifest",
        "normalized_segments",
        "run_input_index",
        "run_manifest",
    }
    if not required.issubset(source_ids):
        raise FactError(f"missing required source pins: {sorted(required - source_ids)}")

    range_ids: set[str] = set()
    previous_last: int | None = None
    for index, selection in enumerate(pins["selection_ranges"]):
        _exact_keys(
            selection,
            {
                "classification",
                "end_heading_exclusive",
                "first_segment_id",
                "id",
                "last_segment_id",
                "start_heading",
            },
            f"selection_ranges[{index}]",
        )
        if selection["id"] in range_ids:
            raise FactError(f"duplicate selection range id: {selection['id']}")
        range_ids.add(selection["id"])
        first = _segment_number(selection["first_segment_id"])
        last = _segment_number(selection["last_segment_id"])
        if first > last:
            raise FactError(f"reversed selection range: {selection['id']}")
        if previous_last is not None and first != previous_last + 1:
            raise FactError("selection ranges must be ordered and contiguous")
        previous_last = last
    return pins


def source_by_id(pins: dict[str, Any], source_id: str) -> dict[str, Any]:
    matches = [source for source in pins["sources"] if source["id"] == source_id]
    if len(matches) != 1:
        raise FactError(f"expected exactly one source pin for {source_id}")
    return matches[0]


def verify_source_pins(foundation_root: Path, pins: dict[str, Any]) -> None:
    try:
        commit = subprocess.run(
            ["git", "-C", str(foundation_root), "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError) as exc:
        raise FactError(f"cannot verify the pinned Foundation commit: {exc}") from exc
    expected_commit = pins["foundation_layout"]["foundation_commit_observed"]
    if commit != expected_commit:
        raise FactError(
            f"Foundation commit drift: expected {expected_commit}, got {commit}"
        )
    source_paths = [
        _foundation_relative_posix_path(source["path"]).as_posix()
        for source in pins["sources"]
    ]
    try:
        pinned_status = subprocess.run(
            [
                "git",
                "-C",
                str(foundation_root),
                "status",
                "--porcelain=v1",
                "--untracked-files=all",
                "--",
                *source_paths,
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError) as exc:
        raise FactError(f"cannot verify pinned Foundation source status: {exc}") from exc
    if pinned_status:
        raise FactError(
            "pinned source paths are not clean at the expected Foundation commit: "
            f"{pinned_status}"
        )
    resolved_root = foundation_root.resolve(strict=True)
    for source in pins["sources"]:
        relative = _foundation_relative_posix_path(source["path"])
        try:
            committed_raw = subprocess.run(
                [
                    "git",
                    "-C",
                    str(foundation_root),
                    "show",
                    f"{expected_commit}:{relative.as_posix()}",
                ],
                check=True,
                capture_output=True,
            ).stdout
        except (OSError, subprocess.CalledProcessError) as exc:
            raise FactError(
                f"cannot read pinned source from the expected Foundation commit: "
                f"{source['path']}: {exc}"
            ) from exc
        committed_data = (
            _canonical_text_payload(
                committed_raw, f"{expected_commit}:{relative.as_posix()}"
            )
            if source["hash_mode"] == "canonical_lf_utf8"
            else committed_raw
        )
        if len(committed_data) != source["bytes"] or _sha256(
            committed_data
        ) != source["sha256"]:
            raise FactError(
                "pinned source digest does not match its expected-commit blob: "
                f"{source['path']}"
            )
        candidate = foundation_root.joinpath(*relative.parts)
        if not candidate.is_file():
            raise FactError(f"pinned source is missing: {candidate}")
        path = candidate.resolve(strict=True)
        try:
            path.relative_to(resolved_root)
        except ValueError as exc:
            raise FactError(f"pinned source escapes Foundation root: {source['path']}") from exc
        data = (
            canonical_text_bytes(path)
            if source["hash_mode"] == "canonical_lf_utf8"
            else path.read_bytes()
        )
        if len(data) != source["bytes"]:
            raise FactError(
                f"source byte count drift for {source['id']}: "
                f"expected {source['bytes']}, got {len(data)}"
            )
        actual = _sha256(data)
        if actual != source["sha256"]:
            raise FactError(
                f"source SHA-256 drift for {source['id']}: "
                f"expected {source['sha256']}, got {actual}"
            )


def public_sources(pins: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        {
            "bytes": source["bytes"],
            "hash_mode": source["hash_mode"],
            "id": source["id"],
            "path_from_oxforms": f"../Foundation/{source['path']}",
            "role": source["role"],
            "sha256": source["sha256"],
        }
        for source in pins["sources"]
    ]


def _segment_number(segment_id: str) -> int:
    match = re.search(r"-SEG-(\d{6})$", segment_id)
    if not match:
        raise FactError(f"invalid segment id: {segment_id}")
    return int(match.group(1))


def _normalize_heading(value: str) -> str:
    return "".join(character.lower() for character in value if character.isalnum())


def _in_section(section: str, root: str) -> bool:
    return section == root or section.startswith(root + ".")


def _section_category(section: str) -> str:
    if section.startswith("1."):
        return "persistence_context"
    if section == "2":
        return "normative_structure_root"
    if _in_section(section, "2.1"):
        return "storage_format"
    if _in_section(section, "2.2"):
        return "control_structure"
    if _in_section(section, "2.3"):
        return "common_text_structure"
    if _in_section(section, "2.4"):
        return "property_type"
    if _in_section(section, "2.5"):
        return "property_definition"
    if _in_section(section, "2.6"):
        return "normative_algorithm"
    if section == "3" or section.startswith("3."):
        return "worked_example"
    if section == "4" or section.startswith("4."):
        return "security_context"
    if section == "5" or section.startswith("5."):
        return "product_behavior"
    raise FactError(f"unclassified selected section: {section}")


def _range_for_number(number: int, pins: dict[str, Any]) -> dict[str, Any]:
    matches = [
        selection
        for selection in pins["selection_ranges"]
        if _segment_number(selection["first_segment_id"])
        <= number
        <= _segment_number(selection["last_segment_id"])
    ]
    if len(matches) != 1:
        raise FactError(f"segment {number} maps to {len(matches)} selection ranges")
    return matches[0]


def _validate_raw_segment(row: dict[str, Any], layout: dict[str, Any]) -> None:
    _exact_keys(row, RAW_SEGMENT_KEYS, f"raw segment {row.get('segment_id', '<unknown>')}")
    if row["document_id"] != layout["capture_document_id"]:
        raise FactError(f"unexpected document id in {row['segment_id']}")
    if row["kind"] not in {"heading", "image_ref", "paragraph", "table_cell"}:
        raise FactError(f"unsupported segment kind in {row['segment_id']}: {row['kind']}")
    if not isinstance(row["text"], str) or not isinstance(row["is_blank"], bool):
        raise FactError(f"malformed text/blank flag in {row['segment_id']}")
    source = row["source"]
    expected_source_keys = RAW_SOURCE_BASE_KEYS
    if row["kind"] == "table_cell":
        expected_source_keys = RAW_SOURCE_TABLE_KEYS
    elif row["kind"] == "image_ref":
        expected_source_keys = RAW_SOURCE_IMAGE_KEYS
    _exact_keys(source, expected_source_keys, f"raw source {row['segment_id']}")
    if source["source_id"] != layout["source_id"]:
        raise FactError(f"unexpected source id in {row['segment_id']}")
    if not source["anchor"].startswith(("p:", "tbl:")):
        raise FactError(f"invalid source anchor in {row['segment_id']}")
    if row["kind"] == "table_cell":
        for key in ("table", "row", "column"):
            if not isinstance(source[key], int) or source[key] <= 0:
                raise FactError(f"invalid table coordinate in {row['segment_id']}")


def _toc_entries(raw_segments: list[dict[str, Any]], before_number: int) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = []
    for row in raw_segments:
        if _segment_number(row["segment_id"]) >= before_number:
            break
        if row["kind"] != "paragraph":
            continue
        match = TOC_RE.match(row["text"])
        if match and match.group(2):
            entries.append((match.group(1), match.group(2)))
    return entries


def _selected_toc_sections(
    toc: list[tuple[str, str]],
    selected_headings: list[str],
    start_heading: str,
    end_heading_exclusive: str,
) -> list[str]:
    start_matches = [
        index
        for index, (_, title) in enumerate(toc)
        if _normalize_heading(title) == _normalize_heading(start_heading)
    ]
    if start_matches != [22]:
        raise FactError(f"Saving Controls TOC anchor drifted: {start_matches}")
    start = start_matches[0]
    selected_entries = toc[start : start + len(selected_headings)]
    if len(selected_entries) != len(selected_headings):
        raise FactError("TOC ends before the selected heading span")
    for index, (heading, (_, title)) in enumerate(
        zip(selected_headings, selected_entries, strict=True)
    ):
        if _normalize_heading(heading) != _normalize_heading(title):
            raise FactError(
                f"selected heading/TOC gap at offset {index}: {heading!r} != {title!r}"
            )
    following = start + len(selected_headings)
    if following >= len(toc) or _normalize_heading(toc[following][1]) != _normalize_heading(
        end_heading_exclusive
    ):
        raise FactError("selected TOC span does not end immediately before Change Tracking")
    return [section for section, _ in selected_entries]


def extract_source_rows(
    raw_segments: list[dict[str, Any]], pins: dict[str, Any]
) -> list[dict[str, Any]]:
    layout = pins["foundation_layout"]
    if len(raw_segments) != 9085:
        raise FactError(f"expected 9085 DOCX segments, got {len(raw_segments)}")
    seen_ids: set[str] = set()
    for expected_number, raw in enumerate(raw_segments, 1):
        _validate_raw_segment(raw, layout)
        if raw["segment_id"] in seen_ids:
            raise FactError(f"duplicate segment id: {raw['segment_id']}")
        seen_ids.add(raw["segment_id"])
        if _segment_number(raw["segment_id"]) != expected_number:
            raise FactError(f"non-contiguous source segment at ordinal {expected_number}")

    first_number = _segment_number(pins["selection_ranges"][0]["first_segment_id"])
    last_number = _segment_number(pins["selection_ranges"][-1]["last_segment_id"])
    selected = raw_segments[first_number - 1 : last_number]
    if len(selected) != last_number - first_number + 1:
        raise FactError("selected source span is not contiguous")

    toc = _toc_entries(raw_segments, first_number)
    selected_headings = [raw["text"] for raw in selected if raw["kind"] == "heading"]
    selected_sections = iter(
        _selected_toc_sections(
            toc,
            selected_headings,
            pins["selection_ranges"][0]["start_heading"],
            pins["selection_ranges"][-1]["end_heading_exclusive"],
        )
    )
    section: str | None = None
    heading: str | None = None
    rows: list[dict[str, Any]] = []
    figure_pins = {
        source["path"].rsplit("/", 1)[-1]: source["id"]
        for source in pins["sources"]
        if source["role"] == "selected_extracted_figure"
    }

    for raw in selected:
        number = _segment_number(raw["segment_id"])
        selection = _range_for_number(number, pins)
        if number == _segment_number(selection["first_segment_id"]):
            if raw["kind"] != "heading" or raw["text"] != selection["start_heading"]:
                raise FactError(f"range {selection['id']} does not start at its pinned heading")
        if number == _segment_number(selection["last_segment_id"]):
            following = raw_segments[number]
            if (
                following["kind"] != "heading"
                or following["text"] != selection["end_heading_exclusive"]
            ):
                raise FactError(f"range {selection['id']} does not end before its pinned heading")

        if raw["kind"] == "heading":
            section = next(selected_sections)
            heading = raw["text"]
        if section is None or heading is None:
            raise FactError(f"selected row precedes its heading: {raw['segment_id']}")

        source = raw["source"]
        output: dict[str, Any] = {
            "anchor": source["anchor"],
            "evidence_class": selection["classification"],
            "heading": heading,
            "is_blank": raw["is_blank"],
            "kind": raw["kind"],
            "section": section,
            "segment_id": raw["segment_id"],
            "selection_range": selection["id"],
            "text": raw["text"],
        }
        if raw["kind"] == "table_cell":
            output.update(
                {"column": source["column"], "row": source["row"], "table": source["table"]}
            )
        elif raw["kind"] == "image_ref":
            filename = source["extracted_image_path"].replace("\\", "/").rsplit("/", 1)[-1]
            if filename not in figure_pins:
                raise FactError(f"selected image is not independently pinned: {filename}")
            output.update(
                {"asset_id": figure_pins[filename], "relationship_id": source["relationship_id"]}
            )
        rows.append(output)

    if rows[0]["segment_id"] != pins["selection_ranges"][0]["first_segment_id"]:
        raise FactError("first selected segment drifted")
    if rows[-1]["segment_id"] != pins["selection_ranges"][-1]["last_segment_id"]:
        raise FactError("last selected segment drifted")
    return rows


def _source_ref(row: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {"anchor": row["anchor"], "segment_id": row["segment_id"]}
    if row["kind"] == "table_cell":
        result.update({"column": row["column"], "row": row["row"], "table": row["table"]})
    return result


def _group_sections(source_rows: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    groups: dict[str, list[dict[str, Any]]] = {}
    for row in source_rows:
        groups.setdefault(row["section"], []).append(row)
    return groups


def build_table_rows(source_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[tuple[int, int], list[dict[str, Any]]] = {}
    for source in source_rows:
        if source["kind"] == "table_cell":
            grouped.setdefault((source["table"], source["row"]), []).append(source)
    result: list[dict[str, Any]] = []
    seen_cells: set[tuple[int, int, int]] = set()
    for (table_id, row_number), cells in grouped.items():
        cells.sort(key=lambda cell: cell["column"])
        sections = {cell["section"] for cell in cells}
        headings = {cell["heading"] for cell in cells}
        if len(sections) != 1 or len(headings) != 1:
            raise FactError(f"table row crosses source sections: table {table_id}, row {row_number}")
        normalized_cells: list[dict[str, Any]] = []
        for cell in cells:
            identity = (table_id, row_number, cell["column"])
            if identity in seen_cells:
                raise FactError(f"duplicate table coordinate: {identity}")
            seen_cells.add(identity)
            normalized_cells.append(
                {
                    "column": cell["column"],
                    "segment_id": cell["segment_id"],
                    "text": cell["text"],
                }
            )
        result.append(
            {
                "cells": normalized_cells,
                "heading": cells[0]["heading"],
                "row": row_number,
                "section": cells[0]["section"],
                "table": table_id,
            }
        )
    result.sort(key=lambda row: (row["table"], row["row"]))
    return result


def build_sections(source_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    headings = [row for row in source_rows if row["kind"] == "heading"]
    groups = _group_sections(source_rows)
    sections: list[dict[str, Any]] = []
    seen: set[str] = set()
    for heading_row in headings:
        section = heading_row["section"]
        if section in seen:
            raise FactError(f"duplicate selected section: {section}")
        seen.add(section)
        rows = groups[section]
        counts = Counter(row["kind"] for row in rows)
        sections.append(
            {
                "category": _section_category(section),
                "evidence_class": heading_row["evidence_class"],
                "first_segment_id": rows[0]["segment_id"],
                "heading": heading_row["heading"],
                "kind_counts": {
                    "heading": counts["heading"],
                    "image_ref": counts["image_ref"],
                    "paragraph": counts["paragraph"],
                    "table_cell": counts["table_cell"],
                },
                "last_segment_id": rows[-1]["segment_id"],
                "row_count": len(rows),
                "section": section,
                "source": _source_ref(heading_row),
                "table_ids": sorted({row["table"] for row in rows if row["kind"] == "table_cell"}),
            }
        )
    return sections


def _constraint_markers(text: str) -> list[str]:
    markers: list[str] = []
    lowered = text.lower()
    if re.search(r"\b(?:must|should|may)\b", lowered):
        markers.append("normative_requirement")
    if "must be set" in lowered:
        markers.append("required_value")
    if "must be ignored" in lowered:
        markers.append("ignore_on_read")
    if "must not be stored" in lowered or "must not be persisted" in lowered:
        markers.append("forbidden_to_persist")
    if "file format default" in lowered:
        markers.append("file_format_default_semantics")
    if "0xffff" in lowered:
        markers.append("stream_presence_sentinel")
    return markers


def _size_bits(size_text: str) -> int | None:
    match = re.fullmatch(r"(\d+) bytes?", size_text)
    if match:
        return int(match.group(1)) * 8
    match = re.fullmatch(r"(\d+) bits?", size_text)
    if match:
        return int(match.group(1))
    return None


def _operation_classes(text: str) -> list[str]:
    operations: list[str] = []
    lowered = text.lower()
    if re.search(r"\b(?:must|should|may) not be set to\b", lowered):
        operations.append("forbid_value")
    elif re.search(r"\b(?:must|should|may) be set to\b", lowered) or re.search(
        r"\b(?:must|should|may) have .+? set to\b", lowered
    ):
        operations.append("set_value")
    for operation, phrase in (
        ("ignore_on_read", " be ignored"),
        ("forbid_storage", " not be stored"),
        ("forbid_persistence", " not be persisted"),
        ("forbid_presence", " not exist"),
        ("equality_constraint", " be equal"),
        ("range_constraint", " be greater than"),
        ("range_constraint", " be less than"),
        ("count_or_size_constraint", " contain exactly"),
    ):
        if phrase in lowered and operation not in operations:
            operations.append(operation)
    if re.search(
        r"\b(?:must|should|may)(?: not)? equal\b|"
        r"\b(?:must|should|may) be the same as\b",
        lowered,
    ) and "equality_constraint" not in operations:
        operations.append("equality_constraint")
    if re.search(r"\b(?:must|should|may) be the same as the order\b", lowered):
        operations.append("order_constraint")
    if re.search(r"\b(?:must|should|may) use the same order\b", lowered):
        operations.append("order_constraint")
    if re.search(r"\b(?:must|should|may) be in the range\b", lowered):
        operations.append("range_constraint")
    if re.search(
        r"\b(?:must|should|may) "
        r"(?:be (?:one of|a value specified in|in one of|the guid of one of)|"
        r"specify .+? in one of)\b",
        lowered,
    ):
        operations.append("domain_membership")
    if re.search(r"\b(?:must|should|may) be able to\b", lowered):
        operations.append("capability_requirement")
    if re.search(r"\b(?:must|should|may) be a zero-length string\b", lowered):
        operations.append("require_zero_length_string")
    if re.search(r"\b(?:must|should|may) conform to .+? grammar\b", lowered):
        operations.append("grammar_conformance")
    if re.search(r"\b(?:must|should|may) be a CountOf\w+", text, re.I):
        operations.append("representation_type")
    if re.search(r"\b(?:must|should|may) not store\b", lowered):
        operations.append("forbid_storage")
    if re.search(r"\b(?:must|should|may) not count\b", lowered):
        operations.append("exclude_from_count")
    if re.search(r"\b(?:must|should|may) be stored\b", lowered):
        operations.append("require_storage")
    if re.search(r"\b(?:must|should|may) exist\b", lowered):
        operations.append("require_presence")
    if "not present when" in lowered:
        operations.append("conditional_absence")
    if "present when" in lowered and "conditional_absence" not in operations:
        operations.append("conditional_presence")
    return operations


def _normative_clauses(text: str) -> list[dict[str, Any]]:
    """Split modal clauses and carry only real or inherited applicability scopes."""

    clauses: list[dict[str, Any]] = []
    sentence_start = 0
    sentence_ranges: list[tuple[int, int]] = []
    for sentence_end in re.finditer(r"\.(?:\s|$)", text):
        sentence_ranges.append((sentence_start, sentence_end.start()))
        sentence_start = sentence_end.end()
    if sentence_start < len(text):
        sentence_ranges.append((sentence_start, len(text)))

    for start, end in sentence_ranges:
        sentence = text[start:end].strip()
        if not sentence:
            continue
        modal_matches = list(re.finditer(r"\b(MUST|SHOULD|MAY)\b", sentence, re.I))
        if not modal_matches:
            continue
        inherited_scope: str | None = None
        for index, modal in enumerate(modal_matches):
            clause_end = (
                modal_matches[index + 1].start()
                if index + 1 < len(modal_matches)
                else len(sentence)
            )
            clause_text = sentence[modal.start() : clause_end].strip()
            clause_text = re.sub(
                r"[\s,;]*(?:and|but)\s*$", "", clause_text, flags=re.I
            ).strip()
            prefix = sentence[: modal.start()].strip(" ,;")
            explicit_scope_match = re.search(
                r"\b(?:for|if|when|unless|depending(?:\s+on)?)\b.+$",
                clause_text,
                re.I,
            )
            prefix_scope = (
                prefix
                if index == 0
                and re.search(
                    r"\b(?:if|when|unless|depending(?:\s+on)?|"
                    r"that do(?:es)? not apply|that are compressible)\b",
                    prefix,
                    re.I,
                )
                else None
            )
            otherwise_scope = None
            if index > 0:
                otherwise_match = re.search(
                    r"\botherwise\b[^.;]*$", prefix, re.I
                )
                if otherwise_match:
                    otherwise_scope = otherwise_match.group(0).strip(" ,;")
            if explicit_scope_match:
                scope_text = explicit_scope_match.group(0).strip(" ,;")
                scope_source = "explicit"
                inherited_scope = scope_text
            elif prefix_scope:
                scope_text = prefix_scope
                scope_source = "sentence_prefix"
                inherited_scope = scope_text
            elif otherwise_scope:
                scope_text = otherwise_scope
                scope_source = "explicit_inverse"
                inherited_scope = scope_text
            elif inherited_scope:
                scope_text = inherited_scope
                scope_source = "inherited"
            else:
                scope_text = None
                scope_source = None
            operations = _operation_classes(clause_text)
            clauses.append(
                {
                    "clause_text": clause_text,
                    "level": modal.group(1).lower(),
                    "operations": operations or ["other_normative_constraint"],
                    "scope_source": scope_source,
                    "scope_text": scope_text,
                    "sentence_prefix": prefix or None,
                }
            )
    return clauses


def _requirement_subject(prefix: str | None, default_subject: str) -> str:
    related_field = re.search(
        r"\b([A-Za-z][A-Za-z0-9_]*)(?: field)? of (?:this |the )?"
        r"([A-Z][A-Z0-9_]*)\b",
        prefix or "",
    )
    return (
        f"{related_field.group(2)}.{related_field.group(1)}"
        if related_field
        else default_subject
    )


def _normalized_requirement_value(raw_value: str) -> dict[str, Any]:
    if raw_value.lower() == "a zero-length string":
        return {"kind": "empty_string", "raw": raw_value, "value": ""}
    if re.fullmatch(r"\{[0-9A-Fa-f-]{36}\}", raw_value):
        return {
            "canonical": raw_value[1:-1].upper(),
            "kind": "guid",
            "raw": raw_value,
        }
    if re.fullmatch(r"0x[0-9A-Fa-f]+|\d+", raw_value) or raw_value.lower() in {
        "zero",
        "true",
        "false",
    }:
        return _numeric_value(raw_value)
    return {
        "kind": "symbolic_constant",
        "name": raw_value,
        "raw": raw_value,
    }


def _normative_requirement(
    text: str, default_subject: str = "current_subject"
) -> dict[str, Any] | None:
    levels = [
        level.lower()
        for level in ("MUST", "SHOULD", "MAY")
        if re.search(rf"\b{level}\b", text)
    ]
    if not levels:
        return None

    operation_constraints = _normative_clauses(text)
    operations: list[str] = []
    for clause in operation_constraints:
        for operation in clause["operations"]:
            if operation not in operations:
                operations.append(operation)

    value_constraints: list[dict[str, Any]] = []
    range_constraints: list[dict[str, Any]] = []
    for clause in operation_constraints:
        value_match = re.search(
            r"\b(must|should|may)( not)? be set to "
            r"(0x[0-9a-f]+|\{[0-9a-f-]{36}\}|zero|\d+|true|false|[A-Z][A-Z0-9_]+)",
            clause["clause_text"],
            re.I,
        )
        subject = _requirement_subject(clause["sentence_prefix"], default_subject)
        if not value_match:
            value_match = re.search(
                r"\b(must|should|may)() have (?:the )?(.+?) set to "
                r"(0x[0-9a-f]+|zero|\d+|true|false|[A-Z][A-Z0-9_]+)",
                clause["clause_text"],
                re.I,
            )
            if value_match:
                subject = re.sub(
                    r"\W+", "_", value_match.group(3).strip().lower()
                ).strip("_")
                raw_value = value_match.group(4)
            else:
                empty_match = re.search(
                    r"\b(must|should|may)() be (a zero-length string)\b",
                    clause["clause_text"],
                    re.I,
                )
                value_match = empty_match
                raw_value = empty_match.group(3) if empty_match else ""
        else:
            raw_value = value_match.group(3)
        if not value_match:
            bounded_range = re.search(
                r"\b(must|should|may) be in the range (?:from )?"
                r"(zero|-?\d+) through (zero|-?\d+)",
                clause["clause_text"],
                re.I,
            )
            greater_than = re.search(
                r"\b(must|should|may) be greater than (zero|-?\d+)",
                clause["clause_text"],
                re.I,
            )
            less_than_or_equal = re.search(
                r"\bless than or equal to (zero|-?\d+)",
                clause["clause_text"],
                re.I,
            )
            less_than = re.search(
                r"\b(must|should|may) be less than (zero|-?\d+)",
                clause["clause_text"],
                re.I,
            )

            def bound(value: str) -> int:
                return 0 if value.lower() == "zero" else int(value)

            if bounded_range or greater_than or less_than:
                level = (
                    bounded_range.group(1)
                    if bounded_range
                    else greater_than.group(1)
                    if greater_than
                    else less_than.group(1)
                ).lower()
                minimum = (
                    {"inclusive": True, "value": bound(bounded_range.group(2))}
                    if bounded_range
                    else {
                        "inclusive": False,
                        "value": bound(greater_than.group(2)),
                    }
                    if greater_than
                    else None
                )
                maximum = (
                    {"inclusive": True, "value": bound(bounded_range.group(3))}
                    if bounded_range
                    else {
                        "inclusive": True,
                        "value": bound(less_than_or_equal.group(1)),
                    }
                    if less_than_or_equal
                    else {
                        "inclusive": False,
                        "value": bound(less_than.group(2)),
                    }
                    if less_than
                    else None
                )
                range_constraints.append(
                    {
                        "clause_text": clause["clause_text"],
                        "level": level,
                        "maximum": maximum,
                        "minimum": minimum,
                        "scope_source": clause["scope_source"],
                        "scope_text": clause["scope_text"],
                        "subject": subject,
                    }
                )
        else:
            level = value_match.group(1).lower()
            negative = bool(value_match.group(2))
            obligation = {
                ("must", False): "required",
                ("must", True): "forbidden",
                ("should", False): "recommended",
                ("should", True): "discouraged",
                ("may", False): "permitted",
                ("may", True): "permitted_not_set",
            }[(level, negative)]
            value_constraints.append(
                {
                    "clause_text": clause["clause_text"],
                    "level": level,
                    "obligation": obligation,
                    "scope_source": clause["scope_source"],
                    "scope_text": clause["scope_text"],
                    "subject": subject,
                    "value": _normalized_requirement_value(raw_value),
                }
            )
    public_operation_constraints = [
        {key: value for key, value in clause.items() if key != "sentence_prefix"}
        for clause in operation_constraints
    ]
    return {
        "conditional": any(
            clause["scope_text"] is not None for clause in operation_constraints
        ),
        "levels": levels,
        "normalization": "typed_values_scoped_operation_clauses_and_raw_text",
        "operation_constraints": public_operation_constraints,
        "operations": operations or ["other_normative_constraint"],
        "range_constraints": range_constraints,
        "raw": text,
        "value_constraints": value_constraints,
    }


def _prop_mask_semantics(
    field_name: str, description: str, segment_id: str
) -> str:
    """Classify every property-mask bit without treating padding as presence."""

    lowered_name = field_name.lower()
    lowered_description = description.lower()
    if lowered_name.startswith(("unused", "reserved")):
        return "reserved_or_unused"
    if "stored in" in lowered_description:
        return "separate_storage_presence"
    if "file format default" in lowered_description:
        return "inline_default_state"
    if "must be equal" in lowered_description:
        return "correlated_constraint"
    raise FactError(
        f"unclassified property-mask semantics at {segment_id}: "
        f"{field_name}: {description}"
    )


def _parse_applies_row(
    row: dict[str, Any],
) -> tuple[list[str], str, list[dict[str, Any]]] | None:
    """Normalize one MS-OFORMS ``Applies to`` paragraph, including footnotes."""

    if row["kind"] != "paragraph":
        return None
    match = APPLIES_RE.match(row["text"])
    if not match:
        return None
    prefix = row["text"].split(":", 1)[0]
    behavior_refs = [
        {"control": None, "footnote": int(value), "scope": "applies_to"}
        for value in re.findall(r"<(\d+)>", prefix)
    ]
    controls: list[str] = []
    for raw_value in match.group(1).split("|"):
        value = re.sub(r"<\d+>", "", raw_value).strip().rstrip(".")
        if not value:
            raise FactError(f"empty Applies-to token in {row['segment_id']}")
        if value not in PERSISTENCE_CONTROLS:
            raise FactError(
                f"unknown Applies-to control {value!r} in {row['segment_id']}"
            )
        controls.append(value)
        behavior_refs.extend(
            {
                "control": value,
                "footnote": int(marker),
                "scope": "control",
            }
            for marker in re.findall(r"<(\d+)>", raw_value)
        )
    return controls, row["text"], behavior_refs


def _bitfield_supplemental_row(
    row: dict[str, Any], default_subject: str
) -> dict[str, Any]:
    """Preserve a bitfield paragraph that qualifies a section or bit entry."""

    applies = _parse_applies_row(row)
    requirement = _normative_requirement(row["text"], default_subject)
    return {
        "applies_to": applies[0] if applies else None,
        "applies_to_behavior_refs": applies[2] if applies else [],
        "applies_to_raw": applies[1] if applies else None,
        "requirements": [requirement] if requirement else [],
        "source": _source_ref(row),
        "text": row["text"],
    }


def build_bitfields(source_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    groups = _group_sections(source_rows)
    table_rows = build_table_rows(source_rows)
    table_ids_by_section: dict[str, list[int]] = defaultdict(list)
    for table_row in table_rows:
        if table_row["table"] not in table_ids_by_section[table_row["section"]]:
            table_ids_by_section[table_row["section"]].append(table_row["table"])

    result: list[dict[str, Any]] = []
    for section, rows in groups.items():
        paragraphs = [row for row in rows if row["kind"] == "paragraph"]
        if not any(BIT_RE.match(row["text"]) for row in paragraphs):
            continue
        entry_indices = [
            index
            for index, paragraph in enumerate(paragraphs)
            if BIT_RE.match(paragraph["text"])
        ]
        if not entry_indices:
            raise FactError(f"bitfield {section} has no parsed entries")
        section_rows = [
            _bitfield_supplemental_row(
                row, f"bitfield:{rows[0]['heading']}"
            )
            for row in paragraphs[: entry_indices[0]]
            if not FIELD_RE.match(row["text"])
        ]
        entries: list[dict[str, Any]] = []
        offset = 0
        for entry_ordinal, paragraph_index in enumerate(entry_indices):
            paragraph = paragraphs[paragraph_index]
            match = BIT_RE.match(paragraph["text"])
            if not match:  # pragma: no cover - guaranteed by entry_indices
                raise FactError(f"bitfield parser drift at {paragraph['segment_id']}")
            symbol, field_name, width_text, description = match.groups()
            width = int(width_text)
            if width <= 0:
                raise FactError(f"invalid bit width in {paragraph['segment_id']}")
            if rows[0]["heading"].endswith("PropMask"):
                semantics = _prop_mask_semantics(
                    field_name, description, paragraph["segment_id"]
                )
            elif field_name.lower().startswith(("unused", "reserved")):
                semantics = "reserved_or_unused"
            elif width == 1:
                semantics = "boolean_flag"
            else:
                semantics = "packed_scalar"
            requirement = _normative_requirement(
                description, f"bitfield_entry:{field_name}"
            )
            next_index = (
                entry_indices[entry_ordinal + 1]
                if entry_ordinal + 1 < len(entry_indices)
                else len(paragraphs)
            )
            entries.append(
                {
                    "bit_offset": offset,
                    "description": description,
                    "field_name": field_name,
                    "requirements": [requirement] if requirement else [],
                    "semantics": semantics,
                    "source": _source_ref(paragraph),
                    "supplemental_rows": [
                        _bitfield_supplemental_row(
                            row, f"bitfield_entry:{field_name}"
                        )
                        for row in paragraphs[paragraph_index + 1 : next_index]
                        if not FIELD_RE.match(row["text"])
                    ],
                    "symbol": symbol,
                    "width_bits": width,
                }
            )
            offset += width
        if offset not in {8, 16, 32, 64}:
            raise FactError(f"bitfield {section} has invalid total width {offset}")
        result.append(
            {
                "entries": entries,
                "kind": "property_presence_mask" if rows[0]["heading"].endswith("PropMask") else "value_bitfield",
                "name": rows[0]["heading"],
                "section": section,
                "section_rows": section_rows,
                "source": _source_ref(rows[0]),
                "table_ids": table_ids_by_section[section],
                "total_bits": offset,
            }
        )
    return result


def build_record_fields(
    source_rows: list[dict[str, Any]], bitfields: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    bitfield_segments = {
        entry["source"]["segment_id"]
        for bitfield in bitfields
        for entry in bitfield["entries"]
    }
    fields: list[dict[str, Any]] = []
    ordinal_by_section: Counter[str] = Counter()
    for row in source_rows:
        if row["kind"] != "paragraph":
            continue
        section = row["section"]
        if not any(_in_section(section, root) for root in ("2.2", "2.3", "2.4")):
            continue
        if row["segment_id"] in bitfield_segments:
            continue
        match = FIELD_RE.match(row["text"])
        if not match:
            continue
        name, size_text, description = match.groups()
        requirement = _normative_requirement(description, f"record_field:{name}")
        ordinal_by_section[section] += 1
        fields.append(
            {
                "constraints": _constraint_markers(description),
                "description": description,
                "name": name,
                "ordinal": ordinal_by_section[section],
                "record": row["heading"],
                "requirements": [requirement] if requirement else [],
                "section": section,
                "size_bits": _size_bits(size_text),
                "size_text": size_text,
                "source": _source_ref(row),
            }
        )
    return fields


def build_record_sections(
    source_rows: list[dict[str, Any]],
    record_fields: list[dict[str, Any]],
    bitfields: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Attach aggregate normative prose to its record section, not a random field."""

    groups = _group_sections(source_rows)
    fields_by_section: dict[str, list[str]] = defaultdict(list)
    for field in record_fields:
        fields_by_section[field["section"]].append(field["name"])
    bitfields_by_section: dict[str, list[str]] = defaultdict(list)
    bitfield_owned_segments: set[str] = set()
    for bitfield in bitfields:
        bitfields_by_section[bitfield["section"]].append(bitfield["name"])
        bitfield_owned_segments.update(
            entry["source"]["segment_id"] for entry in bitfield["entries"]
        )
        bitfield_owned_segments.update(
            row["source"]["segment_id"] for row in bitfield["section_rows"]
        )
        bitfield_owned_segments.update(
            row["source"]["segment_id"]
            for entry in bitfield["entries"]
            for row in entry["supplemental_rows"]
        )
    field_segments = {field["source"]["segment_id"] for field in record_fields}

    result: list[dict[str, Any]] = []
    for section, rows in groups.items():
        if section not in fields_by_section and section not in bitfields_by_section:
            continue
        section_requirements = []
        for row in rows:
            if (
                row["kind"] != "paragraph"
                or row["segment_id"] in field_segments
                or row["segment_id"] in bitfield_owned_segments
            ):
                continue
            requirement = _normative_requirement(
                row["text"], f"record_section:{section}"
            )
            if requirement:
                section_requirements.append(
                    {
                        "requirements": [requirement],
                        "source": _source_ref(row),
                        "text": row["text"],
                    }
                )
        result.append(
            {
                "bitfield_names": bitfields_by_section[section],
                "classification": "documented_record_section",
                "field_names": fields_by_section[section],
                "name": rows[0]["heading"],
                "section": section,
                "section_requirements": section_requirements,
                "source": _source_ref(rows[0]),
            }
        )
    return result


def _numeric_value(
    value_text: str,
    enum_symbols: dict[str, list[dict[str, Any]]] | None = None,
) -> dict[str, Any]:
    match = HEX_RE.search(value_text)
    if match:
        literal = match.group(0)
        digits = literal[2:]
        width_bits = len(digits) * 4
        unsigned = int(literal, 16)
        sign_bit = 1 << (width_bits - 1)
        signed = unsigned - (1 << width_bits) if unsigned & sign_bit else unsigned
        symbols: list[dict[str, Any]] = []
        if enum_symbols is not None:
            for token in re.findall(r"\b[A-Za-z][A-Za-z0-9_]*\b", value_text):
                for symbol in enum_symbols.get(token, []):
                    if symbol not in symbols:
                        symbols.append(symbol)
            if symbols:
                mask = (1 << width_bits) - 1
                combined = 0
                for symbol in symbols:
                    combined |= symbol["numeric_value"] & mask
                if combined != unsigned:
                    raise FactError(
                        f"default symbols do not equal {literal}: "
                        f"{[symbol['name'] for symbol in symbols]}"
                    )
        return {
            "hex": "0x" + digits.upper(),
            "kind": "hex_scalar",
            "raw": value_text,
            "signed": signed,
            "symbols": symbols,
            "unsigned": unsigned,
            "width_bits": width_bits,
        }
    boolean = re.match(r"^(FALSE|TRUE)\b", value_text.strip(), re.I)
    if boolean:
        return {
            "kind": "boolean",
            "raw": value_text,
            "value": boolean.group(1).upper() == "TRUE",
        }
    if re.match(r"^zero\b", value_text.strip(), re.I):
        return {"kind": "decimal_scalar", "raw": value_text, "value": 0}
    decimal = re.match(r"^[\u2212-]?(\d+)", value_text.strip())
    if decimal:
        normalized = value_text.strip().replace("\u2212", "-")
        number_match = re.match(r"^-?\d+", normalized)
        assert number_match is not None
        return {"kind": "decimal_scalar", "raw": value_text, "value": int(number_match.group(0))}
    return {"kind": "textual", "raw": value_text}


def _enum_symbol_catalog(
    enumerations: list[dict[str, Any]],
) -> dict[str, list[dict[str, Any]]]:
    catalog: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for enumeration in enumerations:
        for value in enumeration["values"]:
            catalog[value["name"]].append(
                {
                    "enumeration": enumeration["name"],
                    "name": value["name"],
                    "numeric_value": value["numeric_value"],
                    "source_refs": value["source_refs"],
                }
            )
    return dict(catalog)


def _structured_scalar_default(
    prop: dict[str, Any],
    value_text: str,
    enum_symbols: dict[str, list[dict[str, Any]]],
) -> dict[str, Any]:
    if value_text.lower() == "a zero-length string":
        return {"kind": "empty_string", "raw": value_text, "value": ""}

    size_match = re.fullmatch(
        r"a width of (\d+), ([0-9.]+) points,? and a height of (\d+), ([0-9.]+) points",
        value_text,
        re.I,
    )
    if size_match:
        width_units, width_points, height_units, height_points = size_match.groups()

        def number(value: str) -> int | float:
            return float(value) if "." in value else int(value)

        return {
            "height_himetric": int(height_units),
            "height_points": number(height_points),
            "kind": "size",
            "raw": value_text,
            "width_himetric": int(width_units),
            "width_points": number(width_points),
        }

    point_match = re.search(r"\((-?\d+),\s*(-?\d+)\)", value_text)
    if point_match:
        return {
            "kind": "point",
            "raw": value_text,
            "x_himetric": int(point_match.group(1)),
            "y_himetric": int(point_match.group(2)),
        }

    numeric = _numeric_value(value_text, enum_symbols)
    if numeric["kind"] != "textual":
        return numeric
    if prop["name"] == "FontName":
        return {"kind": "string", "raw": value_text, "value": value_text}
    raise FactError(
        f"unclassified scalar default for {prop['section']} {prop['name']}: {value_text}"
    )


def _parse_applies_to(
    rows: list[dict[str, Any]],
) -> tuple[list[str], dict[str, Any], str, list[dict[str, Any]]]:
    matches: list[tuple[list[str], dict[str, Any], str, list[dict[str, Any]]]] = []
    for row in rows:
        parsed = _parse_applies_row(row)
        if parsed:
            controls, raw, behavior_refs = parsed
            matches.append((controls, _source_ref(row), raw, behavior_refs))
    if len(matches) != 1:
        raise FactError(f"expected one Applies-to row in property section {rows[0]['section']}")
    return matches[0]


def build_properties(
    source_rows: list[dict[str, Any]], table_rows: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    groups = _group_sections(source_rows)
    properties: list[dict[str, Any]] = []
    for section, rows in groups.items():
        if not PROPERTY_SECTION_RE.fullmatch(section):
            continue
        default_rows = [
            row
            for row in rows
            if row["kind"] == "paragraph" and "file format default" in row["text"].lower()
        ]
        mandatory_rows = [
            row
            for row in rows
            if row["kind"] == "paragraph" and "must persist" in row["text"].lower()
        ]
        if len(default_rows) == 1 and not mandatory_rows:
            default_status = "documented_default"
            default_row = default_rows[0]
        elif len(mandatory_rows) == 1 and not default_rows:
            default_status = "mandatory_persist_no_default"
            default_row = mandatory_rows[0]
        else:
            raise FactError(
                f"property {section} must have exactly one default or mandatory-persist row"
            )
        supporting_default_rows: list[dict[str, Any]] = []
        for candidate in rows[rows.index(default_row) + 1 :]:
            if candidate["kind"] == "paragraph" and APPLIES_RE.match(candidate["text"]):
                break
            if candidate["kind"] == "paragraph":
                supporting_default_rows.append(
                    {"source": _source_ref(candidate), "text": candidate["text"]}
                )
        applies_to, applies_source, applies_raw, applies_behavior_refs = _parse_applies_to(rows)
        paragraphs = [row for row in rows if row["kind"] == "paragraph"]
        constraints = [
            {"source": _source_ref(row), "text": row["text"]}
            for row in paragraphs
            if re.search(r"\b(?:MUST|SHOULD|MAY)\b", row["text"])
        ]
        properties.append(
            {
                "applies_to": applies_to,
                "applies_to_behavior_refs": applies_behavior_refs,
                "applies_to_raw": applies_raw,
                "applies_to_source": applies_source,
                "constraints": constraints,
                "default": {
                    "source": _source_ref(default_row),
                    "status": default_status,
                    "supporting_rows": supporting_default_rows,
                    "text": default_row["text"],
                },
                "description": paragraphs[0]["text"],
                "name": rows[0]["heading"],
                "section": section,
                "source": _source_ref(rows[0]),
                "source_segment_ids": [row["segment_id"] for row in rows],
                "table_ids": sorted({row["table"] for row in rows if row["kind"] == "table_cell"}),
                "value_domain_rows": _property_value_domain_rows(
                    rows[0]["heading"], section, table_rows
                ),
            }
        )
    return properties


def _segment_concatenated(raw: str, vocabulary: Iterable[str], where: str) -> list[str]:
    tokens = tuple(sorted(set(vocabulary), key=lambda item: (-len(item), item)))
    memo: dict[int, list[list[str]]] = {}

    def solve(offset: int) -> list[list[str]]:
        if offset == len(raw):
            return [[]]
        if offset in memo:
            return memo[offset]
        solutions: list[list[str]] = []
        for token in tokens:
            if raw.startswith(token, offset):
                for suffix in solve(offset + len(token)):
                    solutions.append([token, *suffix])
                    if len(solutions) > 1:
                        memo[offset] = solutions
                        return solutions
        memo[offset] = solutions
        return solutions

    solutions = solve(0)
    if len(solutions) != 1:
        raise FactError(
            f"concatenated token cell has {len(solutions)} decodings at {where}: {raw!r}"
        )
    return solutions[0]


def _property_value_domain_rows(
    property_name: str,
    section: str,
    table_rows: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    expected_tables = {"BoundColumn": 99, "TextColumn": 127, "Value": 129}
    if property_name not in expected_tables:
        return []
    rows = [row for row in table_rows if row["section"] == section]
    expected_table = expected_tables[property_name]
    if not rows or {row["table"] for row in rows} != {expected_table}:
        raise FactError(
            f"property-domain table drift for {property_name}: expected {expected_table}"
        )
    rows.sort(key=lambda row: row["row"])
    if [row["row"] for row in rows] != list(range(1, len(rows) + 1)):
        raise FactError(f"property-domain rows are not contiguous for {property_name}")

    def cells(row: dict[str, Any]) -> tuple[str, str]:
        ordered = sorted(row["cells"], key=lambda cell: cell["column"])
        if len(ordered) != 2 or [cell["column"] for cell in ordered] != [1, 2]:
            raise FactError(f"property-domain row shape drift for {property_name}")
        return ordered[0]["text"], ordered[1]["text"]

    expected_headers = {
        "BoundColumn": ("BoundColumn", "Meaning"),
        "TextColumn": ("TextColumn", "Meaning"),
        "Value": ("Control", "Specifies"),
    }
    if cells(rows[0]) != expected_headers[property_name]:
        raise FactError(f"property-domain header drift for {property_name}")

    result: list[dict[str, Any]] = []
    for row in rows[1:]:
        selector_text, meaning = cells(row)
        if property_name == "Value":
            selector: dict[str, Any] = {
                "controls": _segment_concatenated(
                    selector_text,
                    PERSISTENCE_CONTROLS,
                    f"{section} table {expected_table} row {row['row']}",
                ),
                "kind": "control_set",
                "raw": selector_text,
            }
            classification = "documented_control_specific_value_semantics"
        else:
            exact = re.fullmatch(r"-?\d+", selector_text)
            minimum = re.fullmatch(r"(-?\d+) or greater", selector_text)
            if exact:
                selector = {
                    "kind": "exact_integer",
                    "raw": selector_text,
                    "value": int(selector_text),
                }
            elif minimum:
                selector = {
                    "inclusive_minimum": int(minimum.group(1)),
                    "kind": "integer_range",
                    "maximum_not_specified": True,
                    "raw": selector_text,
                }
            else:
                raise FactError(
                    f"unclassified property-domain selector for {property_name}: "
                    f"{selector_text!r}"
                )
            classification = "documented_numeric_value_domain"
        requirement = _normative_requirement(
            meaning, f"property:{property_name}"
        )
        result.append(
            {
                "classification": classification,
                "meaning": meaning,
                "requirements": [requirement] if requirement else [],
                "selector": selector,
                "source_refs": [
                    {
                        "column": cell["column"],
                        "row": row["row"],
                        "segment_id": cell["segment_id"],
                        "table": row["table"],
                    }
                    for cell in sorted(row["cells"], key=lambda cell: cell["column"])
                ],
                "table": row["table"],
                "table_row": row["row"],
            }
        )
    return result


def _table_rows_for_section(
    table_rows: list[dict[str, Any]], section: str
) -> list[dict[str, Any]]:
    return [row for row in table_rows if row["section"] == section]


def _normalize_bitfield_default(
    normalized: dict[str, Any],
    bitfield: dict[str, Any],
    flag_names: list[str],
) -> None:
    if normalized["kind"] != "hex_scalar":
        raise FactError(f"bitfield default for {bitfield['name']} is not hexadecimal")
    entry_by_name = {entry["field_name"]: entry for entry in bitfield["entries"]}
    if len(entry_by_name) != len(bitfield["entries"]):
        raise FactError(f"duplicate bitfield entry name in {bitfield['name']}")
    try:
        named_entries = [entry_by_name[name] for name in flag_names]
    except KeyError as exc:
        raise FactError(f"unknown default flag {exc.args[0]} for {bitfield['name']}") from exc
    if any(entry["width_bits"] != 1 for entry in named_entries):
        raise FactError(f"multi-bit entry named as a set flag in {bitfield['name']}")
    unsigned = normalized["unsigned"]
    active_entries = [
        entry
        for entry in bitfield["entries"]
        if entry["width_bits"] == 1 and unsigned & (1 << entry["bit_offset"])
    ]
    if [entry["field_name"] for entry in active_entries] != flag_names:
        raise FactError(
            f"documented set flags do not match numeric default for {bitfield['name']}"
        )
    normalized["bitfield"] = bitfield["name"]
    normalized["set_flags"] = [
        {
            "bit_offset": entry["bit_offset"],
            "name": entry["field_name"],
            "source": entry["source"],
        }
        for entry in named_entries
    ]


def build_default_matrix(
    properties: list[dict[str, Any]],
    table_rows: list[dict[str, Any]],
    bitfields: list[dict[str, Any]],
    enumerations: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    enum_symbols = _enum_symbol_catalog(enumerations)
    bitfield_by_name = {bitfield["name"]: bitfield for bitfield in bitfields}
    various = next(bitfield for bitfield in bitfields if bitfield["name"] == "VariousPropertiesBitfield")
    flag_names = [
        entry["field_name"]
        for entry in various["entries"]
        if not entry["field_name"].lower().startswith("unused")
    ]
    matrix: list[dict[str, Any]] = []
    for prop in properties:
        default = prop["default"]
        rows = _table_rows_for_section(table_rows, prop["section"])
        default_table = bool(rows) and "specified" in default["text"].lower()
        if default["status"] == "mandatory_persist_no_default":
            matrix.append(
                {
                    "applies_to": prop["applies_to"],
                    "control_cell_raw": None,
                    "default_kind": "mandatory_persist_no_default",
                    "meaning": None,
                    "normalized_value": {"kind": "mandatory_persist_no_default", "raw": None},
                    "property": prop["name"],
                    "property_section": prop["section"],
                    "row_id": f"default:{prop['section']}:001",
                    "source_refs": [default["source"]],
                    "value_text": None,
                }
            )
            continue
        if default_table:
            grouped: dict[int, list[dict[str, Any]]] = defaultdict(list)
            for row in rows:
                grouped[row["table"]].append(row)
            matching_tables = []
            for table_id, logical_rows in grouped.items():
                header = [cell["text"] for cell in logical_rows[0]["cells"]]
                if "File format default" in header:
                    matching_tables.append((table_id, logical_rows))
            if len(matching_tables) != 1:
                raise FactError(f"property {prop['section']} has ambiguous default table")
            _, logical_rows = matching_tables[0]
            for index, logical_row in enumerate(logical_rows[1:], 1):
                cells = logical_row["cells"]
                if len(cells) not in {2, 3}:
                    raise FactError(f"malformed default table row in {prop['section']}")
                control_raw = cells[0]["text"]
                controls = _segment_concatenated(
                    control_raw, PERSISTENCE_CONTROLS, f"{prop['section']} table controls"
                )
                value_text = cells[1]["text"]
                meaning = cells[2]["text"] if len(cells) == 3 else None
                normalized = _numeric_value(value_text, enum_symbols)
                if prop["name"] == "VariousPropertyBits" and meaning:
                    set_flags = _segment_concatenated(
                        meaning, flag_names, f"{prop['section']} default flags"
                    )
                    _normalize_bitfield_default(normalized, various, set_flags)
                matrix.append(
                    {
                        "applies_to": controls,
                        "control_cell_raw": control_raw,
                        "default_kind": "control_specific",
                        "meaning": meaning,
                        "normalized_value": normalized,
                        "property": prop["name"],
                        "property_section": prop["section"],
                        "row_id": f"default:{prop['section']}:{index:03d}",
                        "source_refs": [
                            default["source"],
                            *[
                                {
                                    "column": cell["column"],
                                    "row": logical_row["row"],
                                    "segment_id": cell["segment_id"],
                                    "table": logical_row["table"],
                                }
                                for cell in cells
                            ],
                        ],
                        "value_text": value_text,
                    }
                )
            continue

        prefix = "the file format default is "
        lowered = default["text"].lower()
        position = lowered.find(prefix)
        if position < 0:
            raise FactError(f"cannot extract scalar default for {prop['section']}")
        value_text = default["text"][position + len(prefix) :].rstrip(".")
        resource_type = next(
            (
                name
                for name in sorted(RESOURCE_TYPE_NAMES)
                if re.search(rf"\b{re.escape(name)}\b", prop["description"])
            ),
            None,
        )
        resource_absent = resource_type is not None and (
            value_text.lower().startswith("no ")
            or value_text.lower().startswith("not to store ")
        )
        normalized = (
            {
                "kind": "resource_absent",
                "raw": value_text,
                "resource_type": resource_type,
            }
            if resource_absent
            else _structured_scalar_default(prop, value_text, enum_symbols)
        )
        supporting_text = " ".join(
            [default["text"], *[row["text"] for row in default["supporting_rows"]]]
        )
        matching_bitfields = [
            bitfield
            for name, bitfield in bitfield_by_name.items()
            if re.search(rf"\b{re.escape(name)}\b", prop["description"])
        ]
        named_flags: list[str] = []
        if len(matching_bitfields) == 1:
            entry_names = {
                entry["field_name"] for entry in matching_bitfields[0]["entries"]
            }
            named_flags = [
                token
                for token in re.findall(r"\b[A-Za-z][A-Za-z0-9_]*\b", supporting_text)
                if token in entry_names
            ]
        if named_flags:
            _normalize_bitfield_default(normalized, matching_bitfields[0], named_flags)
        matrix.append(
            {
                "applies_to": prop["applies_to"],
                "control_cell_raw": None,
                "default_kind": "resource_absent" if resource_absent else "explicit_scalar",
                "meaning": None,
                "normalized_value": (
                    normalized
                ),
                "property": prop["name"],
                "property_section": prop["section"],
                "row_id": f"default:{prop['section']}:001",
                "source_refs": [
                    default["source"],
                    *[row["source"] for row in default["supporting_rows"]],
                ],
                "value_text": value_text,
            }
        )
    return matrix


def build_enumerations(
    source_rows: list[dict[str, Any]], table_rows: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    groups = _group_sections(source_rows)
    result: list[dict[str, Any]] = []
    for section, rows in groups.items():
        paragraphs = [row for row in rows if row["kind"] == "paragraph"]
        documented_enumeration = any(
            "enumeration" in row["text"].lower() and "following table" in row["text"].lower()
            for row in paragraphs
        )
        named_constant_table = section == "2.2.10.8"
        if not documented_enumeration and not named_constant_table:
            continue
        logical = _table_rows_for_section(table_rows, section)
        if not logical or [cell["text"] for cell in logical[0]["cells"]] != [
            "Name",
            "Value",
            "Meaning",
        ]:
            raise FactError(f"enumeration {section} lacks its exact header")
        values: list[dict[str, Any]] = []
        for ordinal, table_row in enumerate(logical[1:], 1):
            cells = table_row["cells"]
            if len(cells) != 3:
                raise FactError(f"enumeration {section} has a non-three-cell value row")
            try:
                numeric = int(cells[1]["text"], 0)
            except ValueError as exc:
                raise FactError(f"enumeration {section} has non-numeric value text") from exc
            values.append(
                {
                    "meaning": cells[2]["text"],
                    "name": cells[0]["text"],
                    "numeric_value": numeric,
                    "ordinal": ordinal,
                    "source_refs": [
                        {
                            "column": cell["column"],
                            "row": table_row["row"],
                            "segment_id": cell["segment_id"],
                            "table": table_row["table"],
                        }
                        for cell in cells
                    ],
                    "value_text": cells[1]["text"],
                }
            )
        result.append(
            {
                "classification": (
                    "documented_named_constant_table"
                    if named_constant_table
                    else "documented_enumeration"
                ),
                "name": rows[0]["heading"],
                "section": section,
                "source": _source_ref(rows[0]),
                "values": values,
            }
        )
    return result


def build_value_maps(
    source_rows: list[dict[str, Any]], table_rows: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    groups = _group_sections(source_rows)
    specs = (
        ("property_bag_tab_flag", "Property-bag TabFlag", "2.1.1.1.2.2", "decimal"),
        ("property_bag_bool", "Property-bag BOOL", "2.1.1.1.3.2", "decimal"),
        ("form_font_guid", "FormFont FontGUID", "2.4.6", "guid"),
    )
    result: list[dict[str, Any]] = []
    for map_id, name, section, value_kind in specs:
        rows = groups.get(section)
        if rows is None:
            raise FactError(f"value-map section is missing: {section}")
        logical = _table_rows_for_section(table_rows, section)
        if not logical or [cell["text"] for cell in logical[0]["cells"]] != [
            "Value",
            "Meaning",
        ]:
            raise FactError(f"value map {section} lacks its exact header")
        values: list[dict[str, Any]] = []
        for ordinal, table_row in enumerate(logical[1:], 1):
            cells = table_row["cells"]
            if len(cells) != 2:
                raise FactError(f"value map {section} has a non-two-cell row")
            raw_value = cells[0]["text"]
            if value_kind == "decimal":
                normalized_value: dict[str, Any] = {
                    "kind": "decimal_scalar",
                    "value": int(raw_value, 10),
                }
            else:
                guid_match = re.fullmatch(
                    r"\{([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-"
                    r"[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})\}",
                    raw_value,
                )
                if guid_match is None:
                    raise FactError(f"value map {section} has an invalid GUID")
                normalized_value = {
                    "canonical": guid_match.group(1).upper(),
                    "kind": "guid",
                }
            values.append(
                {
                    "meaning": cells[1]["text"],
                    "normalized_value": normalized_value,
                    "ordinal": ordinal,
                    "source_refs": [
                        {
                            "column": cell["column"],
                            "row": table_row["row"],
                            "segment_id": cell["segment_id"],
                            "table": table_row["table"],
                        }
                        for cell in cells
                    ],
                    "value_text": raw_value,
                }
            )
        result.append(
            {
                "classification": "documented_discriminator_or_value_map",
                "map_id": map_id,
                "name": name,
                "section": section,
                "source": _source_ref(rows[0]),
                "value_kind": value_kind,
                "values": values,
            }
        )
    return result


def build_control_families(
    sections: list[dict[str, Any]], source_rows: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    section_ids = [section["section"] for section in sections]
    heading_by_section = {
        row["section"]: row for row in source_rows if row["kind"] == "heading"
    }

    def row_for_suffix(suffix: str) -> dict[str, Any]:
        matches = [
            row for row in source_rows if row["segment_id"].endswith(f"-{suffix}")
        ]
        if len(matches) != 1:
            raise FactError(f"expected one family source segment ending {suffix}")
        return matches[0]

    families: list[dict[str, Any]] = []
    controls: list[str] = []
    for family_id, name, root, exclusions, persistence_controls in FAMILY_SPECS:
        members = [
            section
            for section in section_ids
            if _in_section(section, root)
            and not any(_in_section(section, excluded) for excluded in exclusions)
        ]
        if not members or members[0] != root:
            raise FactError(f"control family root is missing: {root}")
        dependency_rows: list[dict[str, Any]] = []
        for dependency_id, dependency_sections, source_suffix in FAMILY_DEPENDENCY_SPECS.get(
            family_id, ()
        ):
            missing_sections = [
                section for section in dependency_sections if section not in section_ids
            ]
            if missing_sections:
                raise FactError(
                    f"family {family_id} dependency sections are missing: {missing_sections}"
                )
            dependency_source = row_for_suffix(source_suffix)
            dependency_rows.append(
                {
                    "dependency_id": dependency_id,
                    "section_roots": list(dependency_sections),
                    "section_roots_semantics": "roots_include_all_lexical_descendants",
                    "source": _source_ref(dependency_source),
                    "source_text": dependency_source["text"],
                }
            )
        mapping_rows = [
            heading_by_section[root],
            *[
                row_for_suffix(suffix)
                for suffix in FAMILY_MAPPING_SEGMENTS.get(family_id, ())
            ],
        ]
        controls.extend(persistence_controls)
        families.append(
            {
                "classification": "derived_from_documented_structure",
                "family_id": family_id,
                "member_sections": members,
                "member_sections_semantics": "lexical_descendants_of_root",
                "mapping_sources": [
                    {"source": _source_ref(row), "text": row["text"]}
                    for row in mapping_rows
                ],
                "name": name,
                "persistence_dependencies": dependency_rows,
                "persistence_controls": list(persistence_controls),
                "root_section": root,
                "source": _source_ref(heading_by_section[root]),
            }
        )
    if sorted(controls) != sorted(VISIBLE_CONTROLS):
        raise FactError("control-family mapping does not cover the exact 16 persisted controls")
    return families


def build_documented_unknowns(source_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for row in source_rows:
        if not UNKNOWN_RE.search(row["text"]):
            continue
        lowered = row["text"].lower()
        classifications = [
            name
            for name, pattern in (
                ("undefined", r"\bundefined\w*\b"),
                ("reserved", r"\breserved\w*\b"),
                ("unused", r"\bunused\w*\b"),
                ("ignored", r"\bignored\b"),
            )
            if re.search(pattern, lowered)
        ]
        read_requirements: list[str] = []
        if re.search(r"\bmust be ignored\b", lowered):
            read_requirements.append("must_ignore")
        if re.search(r"\bshould be ignored\b", lowered):
            read_requirements.append("should_ignore")
        if re.search(
            r"\b(?:is|are)(?: not used and (?:is|are))? ignored\b", lowered
        ):
            read_requirements.append("documented_ignored")

        write_requirements: list[str] = []
        for requirement, pattern in (
            ("must_set_zero", r"\bmust be set to (?:zero|0)\b"),
            ("should_set_zero", r"\bshould be set to (?:zero|0)\b"),
            ("may_set_zero", r"\bmay be set to (?:zero|0)\b"),
            ("must_set_one", r"\bmust be set to 1\b"),
            ("should_set_one", r"\bshould be set to 1\b"),
            ("may_set_one", r"\bmay be set to 1\b"),
        ):
            if re.search(pattern, lowered):
                write_requirements.append(requirement)
        evidence_class = row["evidence_class"]
        if evidence_class == "documented_normative_structure_default_and_algorithm":
            classification = "documented_normative_unknown_constraint"
        elif evidence_class == "documented_worked_example":
            classification = "documented_worked_example_unknown_observation"
        else:
            raise FactError(
                f"unknown/reserved row has unexpected evidence class: {evidence_class}"
            )
        result.append(
            {
                "classification": classification,
                "classifications": classifications,
                "evidence_class": evidence_class,
                "heading": row["heading"],
                "handling": {
                    "read_requirements": read_requirements,
                    "write_requirements": write_requirements,
                },
                "kind": row["kind"],
                "section": row["section"],
                "selection_range": row["selection_range"],
                "source": _source_ref(row),
                "text": row["text"],
            }
        )
    return result


def build_external_references(source_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in source_rows:
        for reference in EXTERNAL_REFERENCE_RE.findall(row["text"]):
            if reference == "image":
                continue
            grouped[reference].append(row)
    result: list[dict[str, Any]] = []
    for reference in sorted(grouped):
        rows = grouped[reference]
        source_refs: list[dict[str, Any]] = []
        seen_segments: set[str] = set()
        for row in rows:
            if row["segment_id"] not in seen_segments:
                seen_segments.add(row["segment_id"])
                source_refs.append(_source_ref(row))
        result.append(
            {
                "capture_status": "referenced_external_dependency_not_captured_by_this_bead",
                "occurrences": len(rows),
                "reference": reference,
                "source_refs": source_refs,
            }
        )
    return result


def build_product_behavior(source_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    referenced_rows: dict[int, dict[str, Any]] = {}
    for row in source_rows:
        if row["evidence_class"] == "documented_product_behavior":
            continue
        for marker in re.findall(r"<(\d+)>", row["text"]):
            footnote = int(marker)
            if footnote in referenced_rows:
                raise FactError(f"duplicate product-behavior reference <{footnote}>")
            referenced_rows[footnote] = row
    if sorted(referenced_rows) != list(range(1, 21)):
        raise FactError("product-behavior references are not exactly 1 through 20")

    result: list[dict[str, Any]] = []
    for row in source_rows:
        if row["evidence_class"] != "documented_product_behavior" or row["kind"] != "paragraph":
            continue
        match = PRODUCT_BEHAVIOR_RE.match(row["text"])
        if not match:
            continue
        footnote, referenced_section, statement = match.groups()
        footnote_number = int(footnote)
        referenced_row = referenced_rows[footnote_number]
        if referenced_row["section"] != referenced_section:
            raise FactError(
                f"product-behavior section mismatch for <{footnote}>: "
                f"Appendix says {referenced_section}, source is {referenced_row['section']}"
            )
        result.append(
            {
                "classification": "documented_product_behavior",
                "footnote": footnote_number,
                "referenced_evidence_class": referenced_row["evidence_class"],
                "referenced_heading": referenced_row["heading"],
                "referenced_section": referenced_section,
                "referenced_source": _source_ref(referenced_row),
                "referenced_text": referenced_row["text"],
                "source": _source_ref(row),
                "statement": statement,
            }
        )
    if [row["footnote"] for row in result] != list(range(1, 21)):
        raise FactError("Appendix A product-behavior notes are not exactly 1 through 20")
    return result


def _section_digest_rows(
    section: str, groups: dict[str, list[dict[str, Any]]]
) -> tuple[list[str], list[int]]:
    rows = groups[section]
    return (
        [row["segment_id"] for row in rows],
        sorted({row["table"] for row in rows if row["kind"] == "table_cell"}),
    )


def build_algorithms(source_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    groups = _group_sections(source_rows)
    section_26_algorithms = [
        section
        for section in groups
        if _in_section(section, "2.6") and section != "2.6"
    ]
    if section_26_algorithms != ["2.6.1", "2.6.1.1", "2.6.1.2"]:
        raise FactError(
            f"unexpected algorithm section hierarchy: {section_26_algorithms}"
        )
    algorithm_sections = ["2.1.1.1.3.1", *section_26_algorithms]
    if any(section not in groups for section in algorithm_sections):
        raise FactError("documented number/property-bag algorithm section is missing")
    result: list[dict[str, Any]] = []
    first_step_segment = {
        "2.1.1.1.3.1": 750,
        "2.6.1.1": 6757,
        "2.6.1.2": 6799,
    }
    continuation_pairs = {
        6760: 6761,
        6769: 6770,
        6780: 6781,
        6788: 6789,
        6802: 6803,
        6811: 6812,
    }
    for section in algorithm_sections:
        rows = groups[section]
        if section == "2.6.1":
            classification = "documented_algorithm_context"
            member_sections = section_26_algorithms
        else:
            classification = "documented_normative_algorithm_procedure"
            member_sections = [section]
        member_rows = [row for member in member_sections for row in groups[member]]
        direct_paragraphs = [row for row in rows if row["kind"] == "paragraph"]
        step_start = first_step_segment.get(section)
        context_rows = (
            direct_paragraphs
            if step_start is None
            else [
                row
                for row in direct_paragraphs
                if _segment_number(row["segment_id"]) < step_start
            ]
        )
        step_rows = (
            []
            if step_start is None
            else [
                row
                for row in direct_paragraphs
                if _segment_number(row["segment_id"]) >= step_start
            ]
        )
        step_by_number = {
            _segment_number(row["segment_id"]): row for row in step_rows
        }
        continuation_numbers = set(continuation_pairs.values())
        step_groups: list[list[dict[str, Any]]] = []
        for row in step_rows:
            number = _segment_number(row["segment_id"])
            if number in continuation_numbers:
                continue
            group = [row]
            if number in continuation_pairs:
                continuation = step_by_number.get(continuation_pairs[number])
                if continuation is None:
                    raise FactError(
                        f"algorithm continuation row is missing after {row['segment_id']}"
                    )
                group.append(continuation)
            step_groups.append(group)
        steps = []
        for ordinal, group in enumerate(step_groups, 1):
            text = " ".join(row["text"] for row in group)
            requirement = _normative_requirement(text, f"algorithm:{section}")
            steps.append(
                {
                    "ordinal": ordinal,
                    "requirements": [requirement] if requirement else [],
                    "source_refs": [_source_ref(row) for row in group],
                    "text": text,
                }
            )
        result.append(
            {
                "classification": classification,
                "context_rows": [
                    {
                        "requirements": [requirement] if requirement else [],
                        "source": _source_ref(row),
                        "text": row["text"],
                    }
                    for row in context_rows
                    for requirement in [
                        _normative_requirement(row["text"], f"algorithm:{section}")
                    ]
                ],
                "member_sections": member_sections,
                "name": rows[0]["heading"],
                "section": section,
                "source": _source_ref(rows[0]),
                "source_segment_ids": [row["segment_id"] for row in member_rows],
                "steps": steps,
                "table_ids": sorted(
                    {row["table"] for row in member_rows if row["kind"] == "table_cell"}
                ),
            }
        )
    return result


def build_worked_examples(source_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    groups = _group_sections(source_rows)
    direct = [section for section in groups if re.fullmatch(r"3\.\d+", section)]
    result: list[dict[str, Any]] = []
    for root in direct:
        member_sections = [section for section in groups if _in_section(section, root)]
        member_rows = [row for section in member_sections for row in groups[section]]
        result.append(
            {
                "classification": "documented_worked_example_not_implementation_evidence",
                "member_sections": member_sections,
                "name": groups[root][0]["heading"],
                "root_section": root,
                "source": _source_ref(groups[root][0]),
                "source_segment_ids": [row["segment_id"] for row in member_rows],
                "table_ids": sorted(
                    {row["table"] for row in member_rows if row["kind"] == "table_cell"}
                ),
            }
        )
    return result


def build_property_types(
    source_rows: list[dict[str, Any]], record_fields: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    groups = _group_sections(source_rows)
    fields_by_section: dict[str, list[str]] = defaultdict(list)
    for field in record_fields:
        fields_by_section[field["section"]].append(field["name"])
    result: list[dict[str, Any]] = []
    for section, rows in groups.items():
        if not _in_section(section, "2.4") or section == "2.4":
            continue
        result.append(
            {
                "field_names": fields_by_section[section],
                "name": rows[0]["heading"],
                "section": section,
                "source": _source_ref(rows[0]),
                "table_ids": sorted({row["table"] for row in rows if row["kind"] == "table_cell"}),
            }
        )
    return result


def build_resource_formats(
    property_types: list[dict[str, Any]], source_rows: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    groups = _group_sections(source_rows)

    def row_ending(suffix: str) -> dict[str, Any]:
        matches = [
            row for row in source_rows if row["segment_id"].endswith(f"-{suffix}")
        ]
        if len(matches) != 1:
            raise FactError(f"expected one resource source row ending {suffix}")
        return matches[0]

    result: list[dict[str, Any]] = []
    for property_type in property_types:
        if property_type["name"] not in RESOURCE_TYPE_NAMES:
            continue
        root = property_type["section"]
        member_sections = [section for section in groups if _in_section(section, root)]
        member_rows = [row for section in member_sections for row in groups[section]]
        rules = []
        for row in member_rows:
            if row["kind"] != "paragraph":
                continue
            requirement = _normative_requirement(
                row["text"], f"resource:{property_type['name']}"
            )
            if requirement:
                rules.append(
                    {
                        "requirements": [requirement],
                        "source": _source_ref(row),
                        "text": row["text"],
                    }
                )
        supported_formats: list[dict[str, Any]] = []
        codec: dict[str, Any] | None = None
        if property_type["name"] == "StdPicture":
            format_rows = [row_ending(f"{number:06d}") for number in range(5181, 5187)]
            supported_formats = [
                {
                    "external_references": re.findall(r"\[([^\]]+)\]", row["text"]),
                    "format_name": row["text"].split(" [", 1)[0],
                    "source": _source_ref(row),
                    "text": row["text"],
                }
                for row in format_rows
            ]
        elif property_type["name"] == "Strings":
            selection = row_ending("005189")
            compression = row_ending("005190")
            terminators = row_ending("005193")
            zero_length = row_ending("005191")
            codec = {
                "character_encoding": "Unicode",
                "count_prefix": {
                    "array": "CountOfCharsWithCompressionFlag",
                    "non_array": "CountOfBytesWithCompressionFlag",
                    "source": _source_ref(selection),
                },
                "compression": {
                    "compressible_when": "every_character_high_order_byte_equals_0x00",
                    "mandatory_when_compressible": True,
                    "stored_size_basis": "post_compression",
                    "transformation": "remove_all_0x00_bytes",
                    "zero_length_compressible": False,
                    "requirements": [
                        _normative_requirement(
                            compression["text"], "resource:Strings"
                        )
                    ],
                    "source": _source_ref(compression),
                },
                "null_terminators": {
                    "included_in_count": False,
                    "requirements": [
                        _normative_requirement(
                            terminators["text"], "resource:Strings"
                        )
                    ],
                    "source": _source_ref(terminators),
                    "stored": False,
                },
                "zero_length_representation": {
                    "CountOfBytesWithCompressionFlag": {
                        "cb": 0,
                        "fCompressed": 0,
                    },
                    "CountOfCharsWithCompressionFlag": {
                        "cch": 0,
                        "fCompressed": 0,
                    },
                    "source": _source_ref(zero_length),
                },
            }
        result.append(
            {
                "codec": codec,
                "member_record_fields": [
                    {"name": field, "section": row["section"]}
                    for row in property_types
                    if row["section"] in member_sections
                    for field in row["field_names"]
                ],
                "member_sections": member_sections,
                "name": property_type["name"],
                "rules": rules,
                "section": root,
                "source": property_type["source"],
                "source_segment_ids": [row["segment_id"] for row in member_rows],
                "supported_formats": supported_formats,
                "table_ids": sorted(
                    {row["table"] for row in member_rows if row["kind"] == "table_cell"}
                ),
            }
        )
    if {row["name"] for row in result} != RESOURCE_TYPE_NAMES:
        raise FactError("font/picture/string resource format coverage drifted")
    return result


def build_cached_control_ids(
    source_rows: list[dict[str, Any]], table_rows: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    groups = _group_sections(source_rows)
    matches = [
        (section, rows)
        for section, rows in groups.items()
        if rows[0]["heading"] == "FormEmbeddedActiveXControlCached"
    ]
    if len(matches) != 1:
        raise FactError("FormEmbeddedActiveXControlCached section is missing or duplicated")
    section, _ = matches[0]
    logical = _table_rows_for_section(table_rows, section)
    if not logical or [cell["text"] for cell in logical[0]["cells"]] != ["Value", "Meaning"]:
        raise FactError("cached-control table header drifted")
    result: list[dict[str, Any]] = []
    for row in logical[1:]:
        if len(row["cells"]) != 2:
            raise FactError("cached-control row width drifted")
        value_cell, meaning_cell = row["cells"]
        result.append(
            {
                "cached_id": int(value_cell["text"], 10),
                "persistence_family": meaning_cell["text"],
                "source_refs": [
                    {
                        "column": cell["column"],
                        "row": row["row"],
                        "segment_id": cell["segment_id"],
                        "table": row["table"],
                    }
                    for cell in row["cells"]
                ],
            }
        )
    if len(result) != 16:
        raise FactError(f"expected 16 cached control IDs, got {len(result)}")
    return result


def _capture_base(
    pins: dict[str, Any], source_rows: list[dict[str, Any]]
) -> dict[str, Any]:
    layout = pins["foundation_layout"]
    return {
        "classification_policy": {
            "documented": "Direct source text/table facts retain exact segment and coordinate provenance.",
            "documented_product_behavior": "Appendix A facts are separate from normative structure rows.",
            "derived": "Normalized mappings retain raw source cells and reject ambiguous derivations.",
            "unknown": "Reserved, unused, undefined, ignored, and unknown rows are explicit.",
        },
        "source_selection": {
            "first_segment_id": source_rows[0]["segment_id"],
            "last_segment_id": source_rows[-1]["segment_id"],
            "range_ids": [selection["id"] for selection in pins["selection_ranges"]],
            "selected_segment_count": len(source_rows),
        },
        "source_standard": {
            "capture_document_id": layout["capture_document_id"],
            "capture_git_dirty": layout["capture_git_dirty"],
            "capture_tool_commit": layout["capture_tool_commit"],
            "document_date": DOCUMENT_DATE,
            "extraction_run_id": layout["extraction_run_id"],
            "foundation_commit_observed": layout["foundation_commit_observed"],
            "revision": DOCUMENT_REVISION,
            "source_id": layout["source_id"],
        },
    }


def _summary(pack: dict[str, Any]) -> dict[str, Any]:
    kind_counts = Counter(row["kind"] for row in pack["source_rows"])
    properties = pack["properties"]
    bitfields = pack["bitfields"]
    algorithms = pack["algorithms"]
    table_sections = {row["table"]: row["section"] for row in pack["table_rows"]}
    return {
        "algorithm_contexts": sum(
            row["classification"] == "documented_algorithm_context"
            for row in algorithms
        ),
        "algorithm_procedures": sum(
            row["classification"] == "documented_normative_algorithm_procedure"
            for row in algorithms
        ),
        "bit_entries": sum(len(row["entries"]) for row in bitfields),
        "bitfields": len(bitfields),
        "cached_control_ids": len(pack["cached_control_ids"]),
        "control_families": len(pack["control_families"]),
        "default_matrix_rows": len(pack["default_matrix"]),
        "documented_defaults": sum(
            prop["default"]["status"] == "documented_default" for prop in properties
        ),
        "documented_unknown_rows": len(pack["documented_unknowns"]),
        "enum_definitions": len(pack["enumerations"]),
        "enum_values": sum(len(row["values"]) for row in pack["enumerations"]),
        "example_vectors": len(pack["worked_examples"]),
        "external_reference_occurrences": sum(
            row["occurrences"] for row in pack["external_references"]
        ),
        "external_reference_standards": len(pack["external_references"]),
        "mandatory_persist_no_default": sum(
            prop["default"]["status"] == "mandatory_persist_no_default"
            for prop in properties
        ),
        "product_behavior_rows": len(pack["product_behavior"]),
        "prop_masks": sum(row["kind"] == "property_presence_mask" for row in bitfields),
        "properties": len(properties),
        "property_value_domain_rows": sum(
            len(row["value_domain_rows"]) for row in properties
        ),
        "property_value_domain_tables": sum(
            bool(row["value_domain_rows"]) for row in properties
        ),
        "property_types": len(pack["property_types"]),
        "record_fields": len(pack["record_fields"]),
        "record_section_requirements": sum(
            len(row["section_requirements"]) for row in pack["record_sections"]
        ),
        "record_sections": len(pack["record_sections"]),
        "record_tables": sum(
            _in_section(section, "2.2") or _in_section(section, "2.3")
            for section in table_sections.values()
        ),
        "resource_formats": len(pack["resource_formats"]),
        "runtime_api_claims": len(pack["boundaries"]["runtime_api_claims"]),
        "sections": len(pack["sections"]),
        "source_kind_counts": {
            "heading": kind_counts["heading"],
            "image_ref": kind_counts["image_ref"],
            "paragraph": kind_counts["paragraph"],
            "table_cell": kind_counts["table_cell"],
        },
        "source_segments": len(pack["source_rows"]),
        "tables": len(table_sections),
        "table_rows": len(pack["table_rows"]),
        "type_tables": sum(_in_section(section, "2.4") for section in table_sections.values()),
        "value_map_definitions": len(pack["value_maps"]),
        "value_map_values": sum(len(row["values"]) for row in pack["value_maps"]),
        "visible_controls_including_page": len(VISIBLE_CONTROLS),
    }


def build_fact_pack(source_rows: list[dict[str, Any]], pins: dict[str, Any]) -> dict[str, Any]:
    table_rows = build_table_rows(source_rows)
    sections = build_sections(source_rows)
    bitfields = build_bitfields(source_rows)
    record_fields = build_record_fields(source_rows, bitfields)
    record_sections = build_record_sections(source_rows, record_fields, bitfields)
    properties = build_properties(source_rows, table_rows)
    property_types = build_property_types(source_rows, record_fields)
    enumerations = build_enumerations(source_rows, table_rows)

    pack: dict[str, Any] = {
        "algorithms": build_algorithms(source_rows),
        "bitfields": bitfields,
        "boundaries": copy.deepcopy(BOUNDARIES),
        "cached_control_ids": build_cached_control_ids(source_rows, table_rows),
        "capture": _capture_base(pins, source_rows),
        "control_families": build_control_families(sections, source_rows),
        "default_matrix": build_default_matrix(
            properties, table_rows, bitfields, enumerations
        ),
        "documented_unknowns": build_documented_unknowns(source_rows),
        "enumerations": enumerations,
        "external_references": build_external_references(source_rows),
        "product_behavior": build_product_behavior(source_rows),
        "properties": properties,
        "property_types": property_types,
        "record_fields": record_fields,
        "record_sections": record_sections,
        "resource_formats": build_resource_formats(property_types, source_rows),
        "schema_version": FACT_SCHEMA_VERSION,
        "sections": sections,
        "source_rows": source_rows,
        "sources": public_sources(pins),
        "summary": {},
        "table_rows": table_rows,
        "value_maps": build_value_maps(source_rows, table_rows),
        "worked_examples": build_worked_examples(source_rows),
    }
    pack["summary"] = _summary(pack)
    pack["capture"]["semantic_sha256"] = semantic_sha256(pack)
    return pack


def _validate_source_rows(source_rows: list[dict[str, Any]], pins: dict[str, Any]) -> None:
    first = _segment_number(pins["selection_ranges"][0]["first_segment_id"])
    last = _segment_number(pins["selection_ranges"][-1]["last_segment_id"])
    if len(source_rows) != last - first + 1:
        raise FactError("committed source-row count is not the complete selected span")
    current_section: str | None = None
    current_heading: str | None = None
    seen_headings: set[str] = set()
    table_coordinates: set[tuple[int, int, int]] = set()
    image_assets: Counter[str] = Counter()
    document_id = pins["foundation_layout"]["capture_document_id"]
    for ordinal, row in enumerate(source_rows, first):
        if type(row) is not dict:
            raise FactError(f"source_rows[{ordinal - first}] is not an object")
        expected_keys = SOURCE_ROW_BASE_KEYS
        if row.get("kind") == "table_cell":
            expected_keys = SOURCE_ROW_TABLE_KEYS
        elif row.get("kind") == "image_ref":
            expected_keys = SOURCE_ROW_IMAGE_KEYS
        _exact_keys(row, expected_keys, f"source_rows[{ordinal - first}]")
        for key in SOURCE_ROW_BASE_KEYS - {"is_blank"}:
            if type(row[key]) is not str:
                raise FactError(
                    f"source_rows[{ordinal - first}].{key} must be a string"
                )
        if type(row["is_blank"]) is not bool:
            raise FactError(
                f"source_rows[{ordinal - first}].is_blank must be a Boolean"
            )
        if row["kind"] not in {"heading", "paragraph", "table_cell", "image_ref"}:
            raise FactError(
                f"source_rows[{ordinal - first}].kind is unsupported: {row['kind']!r}"
            )
        if row["kind"] == "table_cell":
            for key in ("column", "row", "table"):
                if type(row[key]) is not int or row[key] <= 0:
                    raise FactError(
                        f"source_rows[{ordinal - first}].{key} must be a positive integer"
                    )
        elif row["kind"] == "image_ref":
            for key in ("asset_id", "relationship_id"):
                if type(row[key]) is not str:
                    raise FactError(
                        f"source_rows[{ordinal - first}].{key} must be a string"
                    )
        expected_segment_id = f"{document_id}-SEG-{ordinal:06d}"
        if row["segment_id"] != expected_segment_id:
            raise FactError(f"committed source rows are not contiguous at {row['segment_id']}")
        if row["kind"] == "table_cell":
            if row["anchor"] != f"tbl:{row['table']}":
                raise FactError(f"table-cell anchor drift at {row['segment_id']}")
        elif not re.fullmatch(r"p:\d+", row["anchor"]):
            raise FactError(f"paragraph anchor drift at {row['segment_id']}")
        expected_blank = row["kind"] == "table_cell" and row["text"] == "<blank>"
        if row["is_blank"] is not expected_blank:
            raise FactError(f"blank-row marker drift at {row['segment_id']}")
        if not row["is_blank"] and (not row["text"].strip() or row["text"] == "<blank>"):
            raise FactError(f"nonblank source text is empty at {row['segment_id']}")
        selection = _range_for_number(ordinal, pins)
        if row["selection_range"] != selection["id"]:
            raise FactError(f"selection-range drift at {row['segment_id']}")
        if row["evidence_class"] != selection["classification"]:
            raise FactError(f"evidence-class drift at {row['segment_id']}")
        if row["kind"] == "heading":
            current_section = row["section"]
            current_heading = row["heading"]
            if row["text"] != current_heading:
                raise FactError(f"heading text mismatch at {row['segment_id']}")
            if current_section in seen_headings:
                raise FactError(f"duplicate section heading: {current_section}")
            seen_headings.add(current_section)
            _section_category(current_section)
        if row["section"] != current_section or row["heading"] != current_heading:
            raise FactError(f"source-row section context drift at {row['segment_id']}")
        if row["kind"] == "table_cell":
            coordinate = (row["table"], row["row"], row["column"])
            if coordinate in table_coordinates:
                raise FactError(f"duplicate committed table coordinate: {coordinate}")
            table_coordinates.add(coordinate)
        elif row["kind"] == "image_ref":
            image_assets[row["asset_id"]] += 1
    if source_rows[0]["segment_id"] != pins["selection_ranges"][0]["first_segment_id"]:
        raise FactError("committed first selected segment drifted")
    if source_rows[-1]["segment_id"] != pins["selection_ranges"][-1]["last_segment_id"]:
        raise FactError("committed last selected segment drifted")
    expected_images = Counter(
        source["id"]
        for source in pins["sources"]
        if source["role"] == "selected_extracted_figure"
    )
    if image_assets != expected_images:
        raise FactError(
            "selected image-reference census drifted: "
            f"expected {dict(expected_images)}, got {dict(image_assets)}"
        )


def validate_fact_pack(
    pack: dict[str, Any],
    pins: dict[str, Any],
    expected_capture: dict[str, Any] | None = None,
    *,
    pinned_sources_sha256: str | None = None,
) -> None:
    _exact_keys(pack, TOP_LEVEL_KEYS, "fact pack")
    if pack["schema_version"] != FACT_SCHEMA_VERSION:
        raise FactError(f"unsupported fact schema: {pack['schema_version']}")
    if canonical_json_bytes(pack["sources"]) != canonical_json_bytes(public_sources(pins)):
        raise FactError("committed public source pins differ from pinned_sources.v1.json")
    _validate_source_rows(pack["source_rows"], pins)

    rebuilt = build_fact_pack(copy.deepcopy(pack["source_rows"]), pins)
    for key in TOP_LEVEL_KEYS - {"capture", "schema_version", "sources"}:
        if canonical_json_bytes(pack[key]) != canonical_json_bytes(rebuilt[key]):
            raise FactError(f"derived fact surface drifted: {key}")

    expected_capture_base = _capture_base(pins, pack["source_rows"])
    actual_capture_base = dict(pack["capture"])
    actual_digest = actual_capture_base.pop("semantic_sha256", None)
    if canonical_json_bytes(actual_capture_base) != canonical_json_bytes(
        expected_capture_base
    ):
        raise FactError("capture provenance or selection metadata drifted")
    digest = semantic_sha256(pack)
    if actual_digest != digest:
        raise FactError(f"semantic digest mismatch: expected {actual_digest}, computed {digest}")

    summary = pack["summary"]
    required_counts = {
        "algorithm_contexts": 1,
        "algorithm_procedures": 3,
        "bit_entries": 320,
        "bitfields": 28,
        "cached_control_ids": 16,
        "control_families": 11,
        "default_matrix_rows": 107,
        "documented_defaults": 95,
        "documented_unknown_rows": 179,
        "enum_definitions": 26,
        "enum_values": 132,
        "example_vectors": 6,
        "external_reference_occurrences": 103,
        "external_reference_standards": 22,
        "mandatory_persist_no_default": 3,
        "product_behavior_rows": 20,
        "prop_masks": 15,
        "properties": 98,
        "property_value_domain_rows": 8,
        "property_value_domain_tables": 3,
        "property_types": 18,
        "record_fields": 431,
        "record_section_requirements": 37,
        "record_sections": 90,
        "record_tables": 71,
        "resource_formats": 10,
        "runtime_api_claims": 0,
        "source_segments": 8024,
        "sections": 292,
        "table_rows": 1226,
        "tables": 161,
        "type_tables": 16,
        "value_map_definitions": 3,
        "value_map_values": 8,
        "visible_controls_including_page": 16,
    }
    _exact_keys(summary, set(required_counts) | {"source_kind_counts"}, "summary")
    for key, value in required_counts.items():
        actual = summary.get(key)
        if type(actual) is not int or actual != value:
            raise FactError(
                f"coverage count {key} drifted: expected integer {value}, got {actual!r}"
            )
    required_source_kinds = {
        "heading": 292,
        "image_ref": 6,
        "paragraph": 1834,
        "table_cell": 5892,
    }
    if canonical_json_bytes(summary["source_kind_counts"]) != canonical_json_bytes(
        required_source_kinds
    ):
        raise FactError("source-kind coverage census drifted")
    masks = [bitfield for bitfield in pack["bitfields"] if bitfield["kind"] == "property_presence_mask"]
    if sorted(bitfield["total_bits"] for bitfield in masks) != [32] * 14 + [64]:
        raise FactError("property-mask width census is not 14x32 plus MorphData 64")
    if {prop["name"] for prop in pack["properties"] if prop["default"]["status"] == "mandatory_persist_no_default"} != {
        "DrawBuffer",
        "PageCount",
        "Size",
    }:
        raise FactError("mandatory-persist/no-default property set drifted")
    if canonical_json_bytes(pack["boundaries"]) != canonical_json_bytes(BOUNDARIES):
        raise FactError("runtime/oracle/unknown boundary policy drifted")

    table_owners: dict[int, set[str]] = defaultdict(set)
    for row in pack["default_matrix"]:
        for source in row["source_refs"]:
            if "table" in source:
                table_owners[source["table"]].add("default")
    for enumeration in pack["enumerations"]:
        for value in enumeration["values"]:
            for source in value["source_refs"]:
                if "table" in source:
                    table_owners[source["table"]].add("enumeration")
    for bitfield in pack["bitfields"]:
        for table in bitfield["table_ids"]:
            table_owners[table].add("bitfield")
    for prop in pack["properties"]:
        for row in prop["value_domain_rows"]:
            table_owners[row["table"]].add("property_value_domain")
    census_tables = set(range(92, 133))
    missing_owners = sorted(census_tables - set(table_owners))
    multiple_owners = {
        table: sorted(table_owners[table])
        for table in sorted(census_tables)
        if len(table_owners[table]) != 1
    }
    if missing_owners or multiple_owners:
        raise FactError(
            "default/enum/flag/property-domain table ownership drifted: "
            f"missing={missing_owners}, nonexclusive={multiple_owners}"
        )

    def other_normative_paths(value: Any, path: str = "") -> list[str]:
        paths: list[str] = []
        if isinstance(value, dict):
            if "other_normative_constraint" in value.get("operations", []):
                paths.append(path or "/")
            for key, child in value.items():
                paths.extend(other_normative_paths(child, f"{path}/{key}"))
        elif isinstance(value, list):
            for index, child in enumerate(value):
                paths.extend(other_normative_paths(child, f"{path}/{index}"))
        return paths

    unclassified_normative = other_normative_paths(pack)
    if unclassified_normative:
        raise FactError(
            "unclassified normative operation clauses remain: "
            f"{unclassified_normative}"
        )

    if expected_capture is not None:
        _exact_keys(
            expected_capture,
            {
                "fact_schema_version",
                "pinned_sources_sha256",
                "schema_version",
                "semantic_sha256",
                "summary",
            },
            "expected capture",
        )
        if expected_capture["schema_version"] != EXPECTED_SCHEMA_VERSION:
            raise FactError("unsupported expected-capture schema")
        if expected_capture["fact_schema_version"] != FACT_SCHEMA_VERSION:
            raise FactError("expected-capture fact schema drifted")
        if expected_capture["semantic_sha256"] != digest:
            raise FactError("reviewed expected semantic digest drifted")
        if canonical_json_bytes(expected_capture["summary"]) != canonical_json_bytes(
            summary
        ):
            raise FactError("reviewed expected summary drifted")
        if pinned_sources_sha256 is None:
            raise FactError("pinned source manifest SHA-256 is required with expected capture")
        if expected_capture["pinned_sources_sha256"] != pinned_sources_sha256:
            raise FactError("reviewed pinned-source manifest digest drifted")


def load_foundation_fact_pack(
    foundation_root: Path, pins: dict[str, Any]
) -> dict[str, Any]:
    verify_source_pins(foundation_root, pins)

    run_manifest_pin = source_by_id(pins, "run_manifest")
    run_manifest = load_json_strict(
        foundation_root / Path(run_manifest_pin["path"]), canonical_text=True
    )
    layout = pins["foundation_layout"]
    if run_manifest.get("run_id") != layout["extraction_run_id"]:
        raise FactError("Foundation run id differs from the pinned extraction")
    tooling = run_manifest.get("tooling", {})
    if tooling.get("git_commit") != layout["capture_tool_commit"]:
        raise FactError("Foundation capture-tool commit differs from the pinned caveat")
    if tooling.get("git_dirty") is not layout["capture_git_dirty"]:
        raise FactError("Foundation capture dirty-state caveat differs from the pin")

    document_pin = source_by_id(pins, "document_manifest")
    document_manifest = load_json_strict(
        foundation_root / Path(document_pin["path"]), canonical_text=True
    )
    if document_manifest.get("document_id") != layout["capture_document_id"]:
        raise FactError("Foundation document id differs from the pin")
    if document_manifest.get("source_sha256") != source_by_id(pins, "authoritative_docx")["sha256"]:
        raise FactError("Foundation document manifest does not point to the pinned DOCX")

    index_pin = source_by_id(pins, "run_input_index")
    index_text = canonical_text_bytes(foundation_root / Path(index_pin["path"])).decode("utf-8-sig")
    index_rows = list(csv.reader(io.StringIO(index_text)))
    source_hashes = {row[-1] for row in index_rows if len(row) >= 4 and row[3] == "MS-OFORMS"}
    for source_id in ("authoritative_docx", "authoritative_pdf"):
        if source_by_id(pins, source_id)["sha256"] not in source_hashes:
            raise FactError(f"Foundation run index does not contain {source_id}")

    segments_pin = source_by_id(pins, "normalized_segments")
    raw_segments = load_jsonl_strict(
        foundation_root / Path(segments_pin["path"]), canonical_text=True
    )
    source_rows = extract_source_rows(raw_segments, pins)
    return build_fact_pack(source_rows, pins)


def expected_capture_for(
    pack: dict[str, Any], pinned_sources_sha256: str
) -> dict[str, Any]:
    return {
        "fact_schema_version": FACT_SCHEMA_VERSION,
        "pinned_sources_sha256": pinned_sources_sha256,
        "schema_version": EXPECTED_SCHEMA_VERSION,
        "semantic_sha256": pack["capture"]["semantic_sha256"],
        "summary": pack["summary"],
    }
