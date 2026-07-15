"""Deterministically extract the MS-CFB rows used by the FRX inventory.

The input is Microsoft's byte-pinned revision 12.0 DOCX.  The extractor walks
top-level WordprocessingML paragraphs and table rows in document order, assigns
a one-based row number to each non-empty normalized item, and emits only the
explicitly selected normative rows.  It deliberately does not infer Word list
numbers or rewrite the source prose.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
import zipfile


SCHEMA = "oxforms.forms-persistence.ms-cfb-selected-source-rows.v1"
SOURCE_URL = (
    "https://winprotocoldocs-bhdugrdyduf5h2e4.b02.azurefd.net/"
    "MS-CFB/%5BMS-CFB%5D-240423.docx"
)
SOURCE_LENGTH = 220_697
SOURCE_SHA256 = "2d650184072a148ba98ad0b68072fd5ad7780e46f3528d7f263f3127b2dadab5"
EXPECTED_DOCUMENT_ROWS = 982

W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
W = f"{{{W_NS}}}"

# These are normalized-document row numbers, not page or paragraph numbers.
# Heading rows are retained so each selected normative span is self-identifying.
SELECTIONS: tuple[tuple[str, str, tuple[int, ...]], ...] = (
    ("revision", "revision identity", (1, 2, 45)),
    (
        "2.1",
        "sector numbers, allocation types, and chain invariants",
        (229, 230, 235, 236, 237, 238, 249, 251, 252),
    ),
    (
        "2.2",
        "header identity, versions, shifts, cutoff, and padding",
        (253, 254, 277, 278, 279, 282, 286, 287, 288, 289, 293, 294, 302, 308),
    ),
    (
        "2.3",
        "FAT representation, sector offsets, role markers, and EOF coverage",
        (315, 316, 320, 321, 322, 330),
    ),
    (
        "2.4",
        "mini FAT allocation, offsets, root mini stream, and cutoff behavior",
        (336, 337, 339, 340, 341, 342),
    ),
    (
        "2.5",
        "DIFAT representation, allocation, chaining, and termination",
        (352, 353, 355, 357, 359, 368),
    ),
    (
        "2.6",
        "directory entries, stream placement, unused entries, and sibling trees",
        (
            371,
            372,
            381,
            382,
            403,
            404,
            405,
            411,
            415,
            420,
            425,
            442,
            443,
            444,
            445,
            446,
            447,
            455,
            456,
            457,
            458,
            459,
            461,
            462,
            463,
            464,
            465,
            466,
            467,
            468,
            469,
            470,
            471,
        ),
    ),
    (
        "2.7",
        "arbitrary user data, chain sizing, and last-sector slack",
        (472, 473, 476),
    ),
    (
        "2.8",
        "range-lock allocation and exclusion from structural chains",
        (477, 478, 479),
    ),
)


class SourcePinError(ValueError):
    """Raised when the source artifact or normalized selection drifts."""


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _paragraph_text(element: ET.Element) -> str:
    parts: list[str] = []
    for node in element.iter():
        local = node.tag.rsplit("}", 1)[-1]
        if local == "t":
            parts.append(node.text or "")
        elif local == "tab":
            parts.append("\t")
        elif local in {"br", "cr"}:
            parts.append("\n")
    return "".join(parts).strip()


def _paragraph_style(element: ET.Element) -> str | None:
    style = element.find(f"{W}pPr/{W}pStyle")
    return style.get(f"{W}val") if style is not None else None


def _table_row_text(row: ET.Element) -> str:
    cells: list[str] = []
    for cell in row.findall(f"{W}tc"):
        paragraphs = [
            text
            for paragraph in cell.findall(f"{W}p")
            if (text := _paragraph_text(paragraph))
        ]
        cells.append(" ".join(paragraphs))
    return " | ".join(cells).strip()


def _document_rows(document_xml: bytes) -> list[dict[str, object]]:
    try:
        root = ET.fromstring(document_xml)
    except ET.ParseError as exc:
        raise SourcePinError(f"invalid word/document.xml: {exc}") from exc
    body = root.find(f"{W}body")
    if body is None:
        raise SourcePinError("word/document.xml has no w:body")

    rows: list[dict[str, object]] = []
    for element in body:
        local = element.tag.rsplit("}", 1)[-1]
        if local == "p":
            text = _paragraph_text(element)
            if text:
                rows.append(
                    {
                        "kind": "paragraph",
                        "style": _paragraph_style(element),
                        "text": text,
                    }
                )
        elif local == "tbl":
            for table_row in element.findall(f"{W}tr"):
                text = _table_row_text(table_row)
                if text:
                    rows.append({"kind": "table_row", "style": None, "text": text})
    return rows


def extract(source_path: Path) -> list[dict[str, object]]:
    raw = source_path.read_bytes()
    if len(raw) != SOURCE_LENGTH or _sha256(raw) != SOURCE_SHA256:
        raise SourcePinError("MS-CFB DOCX length/SHA-256 mismatch")

    try:
        with zipfile.ZipFile(source_path) as package:
            names = [entry.filename for entry in package.infolist()]
            if names.count("word/document.xml") != 1:
                raise SourcePinError("DOCX must contain exactly one word/document.xml")
            document_xml = package.read("word/document.xml")
    except (OSError, zipfile.BadZipFile, KeyError) as exc:
        raise SourcePinError(f"cannot read pinned MS-CFB DOCX: {exc}") from exc

    rows = _document_rows(document_xml)
    if len(rows) != EXPECTED_DOCUMENT_ROWS:
        raise SourcePinError(
            f"normalized MS-CFB document row count is {len(rows)}, "
            f"expected {EXPECTED_DOCUMENT_ROWS}"
        )

    selected: list[dict[str, object]] = []
    seen: set[int] = set()
    for section, purpose, row_numbers in SELECTIONS:
        for row_number in row_numbers:
            if row_number in seen:
                raise SourcePinError(f"duplicate selected document row {row_number}")
            seen.add(row_number)
            if row_number < 1 or row_number > len(rows):
                raise SourcePinError(f"selected document row {row_number} is out of range")
            row = rows[row_number - 1]
            text = str(row["text"])
            selected.append(
                {
                    "document_row": row_number,
                    "kind": row["kind"],
                    "purpose": purpose,
                    "section": section,
                    "style": row["style"],
                    "text": text,
                    "text_sha256": _sha256(text.encode("utf-8")),
                }
            )
    return selected


def canonical_bytes(source_path: Path) -> bytes:
    rows = extract(source_path)
    records: list[dict[str, object]] = [
        {
            "artifact": {
                "length": SOURCE_LENGTH,
                "sha256": SOURCE_SHA256,
                "url": SOURCE_URL,
            },
            "normalization": (
                "Top-level non-empty WordprocessingML paragraphs and table rows in "
                "document order; w:t concatenated, tabs/breaks explicit, outer "
                "whitespace stripped, table cells separated by ' | '."
            ),
            "record_type": "source",
            "schema": SCHEMA,
            "selected_row_count": len(rows),
            "total_document_rows": EXPECTED_DOCUMENT_ROWS,
        }
    ]
    records.extend({"record_type": "source_row", **row} for row in rows)
    return b"".join(
        (
            json.dumps(
                record,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            )
            + "\n"
        ).encode("utf-8")
        for record in records
    )


def _reject_duplicate_keys(pairs: list[tuple[str, object]]) -> dict[str, object]:
    value: dict[str, object] = {}
    for key, item in pairs:
        if key in value:
            raise SourcePinError(f"duplicate JSON key: {key!r}")
        value[key] = item
    return value


def _load_json(path: Path) -> dict[str, object]:
    try:
        value = json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=_reject_duplicate_keys,
            parse_constant=lambda token: (_ for _ in ()).throw(
                SourcePinError(f"non-finite JSON token: {token}")
            ),
        )
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise SourcePinError(f"cannot load {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise SourcePinError(f"expected a JSON object: {path}")
    return value


def _file_pin(path: Path) -> dict[str, object]:
    raw = path.read_bytes()
    return {"length": len(raw), "sha256": _sha256(raw)}


def verify_bindings(
    repo_root: Path,
    source_path: Path,
    selected_path: Path,
    rules_path: Path,
    pins_path: Path,
) -> None:
    """Verify that rules, source rows, local pins, and files bind each other."""

    rules = _load_json(rules_path)
    pins = _load_json(pins_path)
    if rules.get("schema") != "oxforms.forms-persistence.ms-cfb-selected-rules.v1":
        raise SourcePinError("unexpected MS-CFB selected-rules schema")
    if pins.get("schema") != "oxforms.forms-persistence.pinned-sources.v1":
        raise SourcePinError("unexpected forms-persistence pin schema")

    local_dependencies = pins.get("local_dependencies")
    if not isinstance(local_dependencies, list):
        raise SourcePinError("local_dependencies is not an array")
    by_id: dict[str, dict[str, object]] = {}
    for item in local_dependencies:
        if not isinstance(item, dict) or not isinstance(item.get("source_id"), str):
            raise SourcePinError("invalid local dependency record")
        source_id = str(item["source_id"])
        if source_id in by_id:
            raise SourcePinError(f"duplicate local dependency: {source_id}")
        by_id[source_id] = item

    extractor_path = Path(__file__).resolve()
    expected_files = {
        "MS-CFB-DOCX": source_path.resolve(),
        "MS-CFB-SELECTED-ROWS": selected_path.resolve(),
        "MS-CFB-EXTRACTOR": extractor_path,
        "MS-CFB-SELECTED-RULES": rules_path.resolve(),
    }
    for source_id, path in expected_files.items():
        pin = by_id.get(source_id)
        if pin is None:
            raise SourcePinError(f"missing local dependency pin: {source_id}")
        try:
            relative = path.relative_to(repo_root.resolve()).as_posix()
        except ValueError as exc:
            raise SourcePinError(f"source-pin path leaves repository: {path}") from exc
        facts = _file_pin(path)
        if pin.get("path") != relative or any(pin.get(key) != value for key, value in facts.items()):
            raise SourcePinError(f"local dependency pin drift: {source_id}")

    source = rules.get("source")
    if not isinstance(source, dict):
        raise SourcePinError("MS-CFB rules source is not an object")
    nested_bindings = {
        "raw_artifact": "MS-CFB-DOCX",
        "normalized_selected_rows": "MS-CFB-SELECTED-ROWS",
        "extractor": "MS-CFB-EXTRACTOR",
    }
    for nested_name, source_id in nested_bindings.items():
        nested = source.get(nested_name)
        pin = by_id[source_id]
        if not isinstance(nested, dict):
            raise SourcePinError(f"missing nested source binding: {nested_name}")
        for key in ("path", "length", "sha256"):
            if nested.get(key) != pin.get(key):
                raise SourcePinError(f"nested source binding drift: {nested_name}.{key}")

    try:
        selected_records = [
            json.loads(
                line,
                object_pairs_hook=_reject_duplicate_keys,
                parse_constant=lambda token: (_ for _ in ()).throw(
                    SourcePinError(f"non-finite JSON token: {token}")
                ),
            )
            for line in selected_path.read_text(encoding="utf-8").splitlines()
        ]
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise SourcePinError(f"cannot load selected source rows: {exc}") from exc
    if not selected_records or not isinstance(selected_records[0], dict):
        raise SourcePinError("selected source-row metadata is missing")
    metadata = selected_records[0]
    normalized = source["normalized_selected_rows"]
    raw_artifact = source["raw_artifact"]
    if (
        metadata.get("schema") != normalized.get("schema")
        or metadata.get("selected_row_count") != normalized.get("source_row_count")
        or metadata.get("artifact") != {
            "length": raw_artifact.get("length"),
            "sha256": raw_artifact.get("sha256"),
            "url": raw_artifact.get("url"),
        }
    ):
        raise SourcePinError("selected source-row metadata binding drift")

    selected_by_number = {
        record.get("document_row"): record
        for record in selected_records[1:]
        if isinstance(record, dict)
    }
    try:
        source_id_text = str(selected_by_number[1]["text"])
        title_text = str(selected_by_number[2]["text"])
        revision_text = str(selected_by_number[45]["text"])
    except (KeyError, TypeError) as exc:
        raise SourcePinError("source/revision identity rows are missing") from exc
    revision_cells = [cell.strip() for cell in revision_text.split("|")]
    if len(revision_cells) != 4:
        raise SourcePinError("MS-CFB revision row shape drift")
    month_day_year, revision, revision_class, revision_comment = revision_cells
    try:
        month, day, year = (int(value) for value in month_day_year.split("/"))
        release_date = f"{year:04d}-{month:02d}-{day:02d}"
    except (TypeError, ValueError) as exc:
        raise SourcePinError("MS-CFB revision date shape drift") from exc
    expected_source_metadata = {
        "source_id": source_id_text.removeprefix("[").removesuffix(":").removesuffix("]"),
        "title": title_text,
        "publisher": "Microsoft Corporation",
        "protocol_revision": revision,
        "release_date": release_date,
        "revision_class": revision_class,
        "revision_comment": revision_comment,
        "index_url": (
            "https://learn.microsoft.com/en-us/openspecs/windows_protocols/"
            "ms-cfb/53989ce4-7b05-4f8d-829b-d08d6148375b"
        ),
    }
    for key, expected_value in expected_source_metadata.items():
        if source.get(key) != expected_value:
            raise SourcePinError(f"MS-CFB source metadata drift: {key}")

    rows_by_section = {
        section: list(row_numbers)
        for section, _purpose, row_numbers in SELECTIONS
        if section != "revision"
    }
    expected_sections: tuple[dict[str, object], ...] = (
        {
            "section": "2.1",
            "title": "Compound File Sector Numbers and Types",
            "url": "https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/9d33df18-7aee-4065-9121-4eabe41c29d4",
            "source_rows": rows_by_section["2.1"],
        },
        {
            "section": "2.2",
            "title": "Compound File Header",
            "url": "https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/05060311-bfce-4b12-874d-71fd4ce63aea",
            "source_rows": rows_by_section["2.2"],
        },
        {
            "section": "2.3-2.5",
            "title": "FAT, Mini FAT, and DIFAT Sectors",
            "urls": [
                "https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/30e1013a-a0ff-4404-9ccf-d75d835ff404",
                "https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/c5d235f7-b73c-4ec5-bf8d-5c08306cd023",
                "https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/0afa4e43-b18f-432a-9917-4f276eca7a73",
            ],
            "source_rows": rows_by_section["2.3"] + rows_by_section["2.4"] + rows_by_section["2.5"],
        },
        {
            "section": "2.6-2.6.4",
            "title": "Directory Entries and Sibling Trees",
            "urls": [
                "https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/a94d7445-c4be-49cd-b6b9-2f4abc663817",
                "https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/026fde6e-143d-41bf-a7da-c08b2130d50e",
                "https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/b37413bb-f3ef-4adc-b18e-29bddd62c26e",
                "https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/d30e462c-5f8a-435b-9c4c-cc0b9ea89956",
            ],
            "source_rows": rows_by_section["2.6"],
        },
        {
            "section": "2.7-2.8",
            "title": "User-Defined Data and Range Lock Sectors",
            "urls": [
                "https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/b089deda-be20-4b4a-aad5-fbe68bb19672",
                "https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/947df128-1f4a-4c02-b6ed-6d1d0c04c02f",
            ],
            "source_rows": rows_by_section["2.7"] + rows_by_section["2.8"],
        },
    )
    selected_sections = rules.get("selected_sections")
    if not isinstance(selected_sections, list) or len(selected_sections) != len(expected_sections):
        raise SourcePinError("selected MS-CFB rule-section coverage drift")
    for section, expected_section in zip(selected_sections, expected_sections):
        if not isinstance(section, dict):
            raise SourcePinError("selected MS-CFB rule section is not an object")
        expected_name = str(expected_section["section"])
        if any(section.get(key) != value for key, value in expected_section.items()):
            raise SourcePinError(f"selected MS-CFB source metadata/row drift: {expected_name}")
        interpretations = section.get("project_interpretations")
        if (
            "rules" in section
            or not isinstance(interpretations, list)
            or not interpretations
            or not all(isinstance(item, str) and item for item in interpretations)
        ):
            raise SourcePinError(f"unlabeled/invalid project interpretations: {expected_name}")


def _default_paths() -> tuple[Path, Path, Path, Path, Path]:
    repo_root = Path(__file__).resolve().parents[2]
    reference = repo_root / "reference" / "ms-cfb"
    return (
        repo_root,
        reference / "[MS-CFB]-240423.docx",
        reference / "ms_cfb_selected_rows.v1.jsonl",
        repo_root / "tools" / "forms-persistence" / "ms_cfb_selected_rules.v1.json",
        repo_root / "tools" / "forms-persistence" / "pinned_sources.v1.json",
    )


def main(argv: list[str] | None = None) -> int:
    repo_root, default_source, default_expected, default_rules, default_pins = _default_paths()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=default_source)
    parser.add_argument("--expected", type=Path, default=default_expected)
    parser.add_argument("--rules", type=Path, default=default_rules)
    parser.add_argument("--pins", type=Path, default=default_pins)
    parser.add_argument(
        "--print",
        action="store_true",
        dest="print_output",
        help="write the canonical selected JSONL bytes to stdout",
    )
    args = parser.parse_args(argv)

    try:
        actual = canonical_bytes(args.source)
        if args.print_output:
            sys.stdout.buffer.write(actual)
            return 0
        expected = args.expected.read_bytes()
        if actual != expected:
            raise SourcePinError(
                f"selected source rows drift: {args.expected}; regenerate with "
                f"{Path(__file__).name} --print and review the patch"
            )
        verify_bindings(repo_root, args.source, args.expected, args.rules, args.pins)
    except (OSError, SourcePinError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(
        f"verified {args.expected} ({len(actual)} bytes, sha256={_sha256(actual)})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
