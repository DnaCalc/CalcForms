"""Byte-exact inventory parser for exported VBA/MSForms ``.frm`` text.

The module deliberately stops at inventory.  It does not instantiate controls,
interpret code-behind, or follow resource paths.  Two explicitly different
profiles are available:

``office_vba_userform_export``
    A strict profile for the text wrapper emitted by Office/VBIDE when a VBA
    UserForm is exported.  The designer portion contains one GUID-rooted block;
    the actual control graph remains in the referenced ``.frx`` payload.

``legacy_synthetic_nested``
    An inventory-only profile for classic/synthetic text fixtures which place
    nested ``Begin``/``End`` and ``BeginProperty``/``EndProperty`` blocks in the
    ``.frm`` text.  Accepting this profile is not evidence that Office emits or
    consumes that representation for VBA UserForms.

All public offsets are half-open byte offsets into the original supplied byte
slice.  Line numbers are one-based and inclusive.  Parsing fails closed on
malformed structure, ambiguous encoding declarations, or incomplete coverage.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import codecs
import hashlib
import ntpath
from pathlib import Path, PureWindowsPath
import re
from typing import Any, Sequence


OFFICE_VBA_USERFORM_EXPORT = "office_vba_userform_export"
LEGACY_SYNTHETIC_NESTED = "legacy_synthetic_nested"

_SUPPORTED_PROFILES = {
    OFFICE_VBA_USERFORM_EXPORT,
    LEGACY_SYNTHETIC_NESTED,
}
_GUID_TEXT = r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
_IDENTIFIER = r"[A-Za-z_][A-Za-z0-9_]*"
_PROPERTY_IDENTIFIER = r"[A-Za-z_][A-Za-z0-9_.]*"
_STRICT_BEGIN_RE = re.compile(
    rf"^Begin[ \t]+\{{(?P<guid>{_GUID_TEXT})\}}[ \t]+(?P<name>.*?)[ \t]*$"
)
_OBJECT_BEGIN_RE = re.compile(
    rf"^[ \t]*Begin[ \t]+(?P<type>\{{{_GUID_TEXT}\}}|[^ \t]+)[ \t]+"
    rf"(?P<name>{_IDENTIFIER})[ \t]*$"
)
_PROPERTY_BEGIN_RE = re.compile(
    rf"^[ \t]*BeginProperty[ \t]+(?P<name>{_PROPERTY_IDENTIFIER})"
    r"(?:[ \t]+(?P<arguments>.*?))?[ \t]*$"
)
_END_RE = re.compile(r"^[ \t]*End[ \t]*$")
_END_PROPERTY_RE = re.compile(r"^[ \t]*EndProperty[ \t]*$")
_VERSION_RE = re.compile(r"^VERSION[ \t]+(?P<version>[0-9]+\.[0-9]+)[ \t]*$")
_ASSIGNMENT_RE = re.compile(
    rf"^(?P<indent>[ \t]+)(?P<name>{_PROPERTY_IDENTIFIER})(?P<before_eq>[ \t]*)="
    r"(?P<after_eq>[ \t]*)(?P<rhs>.*)$"
)
_ATTRIBUTE_RE = re.compile(
    rf"^Attribute[ \t]+(?P<name>{_PROPERTY_IDENTIFIER})(?P<before_eq>[ \t]*)="
    r"(?P<after_eq>[ \t]*)(?P<rhs>.*)$"
)
_VB_STRING_RE = re.compile(r'^"(?:[^"]|"")*"$')
_RESOURCE_RE = re.compile(
    r'^(?P<literal>"(?:[^"]|"")*"):(?P<offset>[0-9A-Fa-f]{4,8})$'
)
_INTEGER_RE = re.compile(r"^[+-]?[0-9]+$")
_DECIMAL_RE = re.compile(
    r"^[+-]?(?:[0-9]+\.[0-9]*|\.[0-9]+|[0-9]+)(?:[Ee][+-]?[0-9]+)?$"
)
_HEX_RE = re.compile(r"^&[Hh][0-9A-Fa-f]+&?$")

_STANDARD_ATTRIBUTES: tuple[tuple[str, str, Any], ...] = (
    ("VB_Name", "string", None),
    ("VB_GlobalNameSpace", "boolean", False),
    ("VB_Creatable", "boolean", False),
    ("VB_PredeclaredId", "boolean", True),
    ("VB_Exposed", "boolean", False),
)
_CLASS_ATTRIBUTE_NAMES = frozenset(
    {
        "VB_Name",
        "VB_GlobalNameSpace",
        "VB_Creatable",
        "VB_PredeclaredId",
        "VB_Exposed",
        "VB_Customizable",
    }
)

_BOMS: tuple[tuple[bytes, str, frozenset[str]], ...] = (
    (b"\x00\x00\xFE\xFF", "utf-32-be", frozenset({"utf-32", "utf-32-be"})),
    (b"\xFF\xFE\x00\x00", "utf-32-le", frozenset({"utf-32", "utf-32-le"})),
    (b"\xEF\xBB\xBF", "utf-8", frozenset({"utf-8", "utf-8-sig"})),
    (b"\xFE\xFF", "utf-16-be", frozenset({"utf-16", "utf-16-be"})),
    (b"\xFF\xFE", "utf-16-le", frozenset({"utf-16", "utf-16-le"})),
)


class FRMError(ValueError):
    """Raised when a byte slice is not valid for the selected ``.frm`` profile."""


@dataclass(frozen=True)
class SourceSpan:
    """A half-open byte span and its inclusive one-based line range."""

    byte_start: int
    byte_end: int
    line_start: int | None
    line_end: int | None

    @property
    def length(self) -> int:
        return self.byte_end - self.byte_start

    def to_dict(self) -> dict[str, Any]:
        return {
            "byte_start": self.byte_start,
            "byte_end": self.byte_end,
            "length": self.length,
            "line_start": self.line_start,
            "line_end": self.line_end,
        }


@dataclass(frozen=True)
class ByteRegion:
    """One non-overlapping classification of source bytes."""

    classification: str
    span: SourceSpan
    sha256: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "classification": self.classification,
            "span": self.span.to_dict(),
            "sha256": self.sha256,
        }


@dataclass(frozen=True)
class PropertyRow:
    """One ordered designer-property assignment."""

    order: int
    owner_block_index: int
    name: str
    indentation: str
    value_text: str
    value_kind: str
    parsed_value: Any
    comment: str | None
    comment_text: str | None
    span: SourceSpan
    value_span: SourceSpan
    comment_span: SourceSpan | None

    def to_dict(self) -> dict[str, Any]:
        return {
            "order": self.order,
            "owner_block_index": self.owner_block_index,
            "name": self.name,
            "indentation": self.indentation,
            "value_text": self.value_text,
            "value_kind": self.value_kind,
            "parsed_value": self.parsed_value,
            "comment": self.comment,
            "comment_text": self.comment_text,
            "span": self.span.to_dict(),
            "value_span": self.value_span.to_dict(),
            "comment_span": (
                None if self.comment_span is None else self.comment_span.to_dict()
            ),
        }


@dataclass(frozen=True)
class AttributeRow:
    """One contiguous class-header ``Attribute`` assignment."""

    order: int
    name: str
    value_text: str
    value_kind: str
    parsed_value: Any
    span: SourceSpan
    value_span: SourceSpan

    def to_dict(self) -> dict[str, Any]:
        return {
            "order": self.order,
            "name": self.name,
            "value_text": self.value_text,
            "value_kind": self.value_kind,
            "parsed_value": self.parsed_value,
            "span": self.span.to_dict(),
            "value_span": self.value_span.to_dict(),
        }


@dataclass(frozen=True)
class ExternalResourceReference:
    """A quoted external-resource path plus its hexadecimal byte offset."""

    property_order: int
    owner_block_index: int
    property_name: str
    path: str
    offset_text: str
    offset: int
    is_safe_relative_basename: bool
    unsafe_reasons: tuple[str, ...]
    span: SourceSpan

    def to_dict(self) -> dict[str, Any]:
        return {
            "property_order": self.property_order,
            "owner_block_index": self.owner_block_index,
            "property_name": self.property_name,
            "path": self.path,
            "offset_text": self.offset_text,
            "offset": self.offset,
            "is_safe_relative_basename": self.is_safe_relative_basename,
            "unsafe_reasons": list(self.unsafe_reasons),
            "span": self.span.to_dict(),
        }


@dataclass(frozen=True)
class BlockRecord:
    """One balanced object or property block in source order."""

    index: int
    kind: str
    type_identifier: str | None
    name: str
    arguments: str | None
    depth: int
    parent_index: int | None
    path: str
    header_span: SourceSpan
    end_span: SourceSpan
    span: SourceSpan

    def to_dict(self) -> dict[str, Any]:
        return {
            "index": self.index,
            "kind": self.kind,
            "type_identifier": self.type_identifier,
            "name": self.name,
            "arguments": self.arguments,
            "depth": self.depth,
            "parent_index": self.parent_index,
            "path": self.path,
            "header_span": self.header_span.to_dict(),
            "end_span": self.end_span.to_dict(),
            "span": self.span.to_dict(),
        }


@dataclass(frozen=True)
class FRMInventory:
    """Deterministic, JSON-serializable ``.frm`` inventory."""

    profile: str
    profile_disposition: str
    raw_length: int
    sha256: str
    requested_code_page: str
    codec_name: str
    bom_kind: str | None
    bom_length: int
    newline_style: str
    newline_counts: tuple[tuple[str, int], ...]
    terminal_newline: bool
    line_count: int
    version: str
    version_span: SourceSpan
    root_type_identifier: str
    root_guid: str | None
    root_name: str
    root_begin_span: SourceSpan
    root_end_span: SourceSpan
    root_span: SourceSpan
    properties: tuple[PropertyRow, ...]
    blocks: tuple[BlockRecord, ...]
    attributes: tuple[AttributeRow, ...]
    standard_office_class_header: bool
    external_references: tuple[ExternalResourceReference, ...]
    ole_object_blob_reference_indexes: tuple[int, ...]
    code_start_offset: int
    code_start_line: int
    code_span: SourceSpan
    byte_regions: tuple[ByteRegion, ...]
    _raw: bytes = field(repr=False, compare=False)

    @property
    def code_body(self) -> bytes:
        """Return the untouched code-behind byte slice."""

        return self._raw[self.code_start_offset :]

    def to_dict(self) -> dict[str, Any]:
        """Return the stable JSON-ready representation (without source bytes)."""

        classified = sum(region.span.length for region in self.byte_regions)
        root_properties = [
            row.to_dict() for row in self.properties if row.owner_block_index == 0
        ]
        return {
            "schema": "oxforms.frm-text-inventory.v1",
            "profile": self.profile,
            "profile_disposition": self.profile_disposition,
            "source": {
                "length": self.raw_length,
                "sha256": self.sha256,
                "line_count": self.line_count,
            },
            "encoding": {
                "requested_code_page": self.requested_code_page,
                "codec": self.codec_name,
                "bom": {
                    "present": self.bom_length != 0,
                    "kind": self.bom_kind,
                    "length": self.bom_length,
                },
            },
            "newlines": {
                "style": self.newline_style,
                "counts": dict(self.newline_counts),
                "terminal_newline": self.terminal_newline,
            },
            "version": {
                "value": self.version,
                "span": self.version_span.to_dict(),
            },
            "root": {
                "type_identifier": self.root_type_identifier,
                "guid": self.root_guid,
                "name": self.root_name,
                "name_character_count": len(self.root_name),
                "name_vb_identifier_should_conformance": re.fullmatch(
                    _IDENTIFIER, self.root_name
                )
                is not None,
                "begin_span": self.root_begin_span.to_dict(),
                "end_span": self.root_end_span.to_dict(),
                "span": self.root_span.to_dict(),
            },
            "root_properties": root_properties,
            "properties": [row.to_dict() for row in self.properties],
            "blocks": [block.to_dict() for block in self.blocks],
            "legacy_nested_inventory": {
                "present": self.profile == LEGACY_SYNTHETIC_NESTED,
                "promotable_to_office_export_profile": False,
                "block_count": len(self.blocks),
            },
            "class_header": {
                "normative_ms_vbal_class_header": True,
                "standard_office_userform_header": self.standard_office_class_header,
                "attributes": [row.to_dict() for row in self.attributes],
            },
            "external_resource_references": [
                reference.to_dict() for reference in self.external_references
            ],
            "ole_object_blob": {
                "present": bool(self.ole_object_blob_reference_indexes),
                "reference_indexes": list(self.ole_object_blob_reference_indexes),
            },
            "code_body": {
                "boundary_byte_offset": self.code_start_offset,
                "boundary_line": self.code_start_line,
                "length": len(self.code_body),
                "sha256": hashlib.sha256(self.code_body).hexdigest(),
                "span": self.code_span.to_dict(),
                "interpretation": "opaque",
            },
            "byte_regions": [region.to_dict() for region in self.byte_regions],
            "coverage": {
                "classified_length": classified,
                "source_length": self.raw_length,
                "all_bytes_classified_once": classified == self.raw_length,
            },
        }


@dataclass(frozen=True)
class _Line:
    number: int
    text: str
    newline: str
    span: SourceSpan
    content_span: SourceSpan
    codec_name: str

    def byte_offset(self, character_offset: int) -> int:
        if character_offset < 0 or character_offset > len(self.text):
            raise AssertionError("character offset outside line")
        return self.content_span.byte_start + len(
            self.text[:character_offset].encode(self.codec_name, errors="strict")
        )

    def token_span(self, start: int, end: int) -> SourceSpan:
        return SourceSpan(
            self.byte_offset(start),
            self.byte_offset(end),
            self.number,
            self.number,
        )


@dataclass
class _BlockBuilder:
    index: int
    kind: str
    type_identifier: str | None
    name: str
    arguments: str | None
    depth: int
    parent_index: int | None
    path: str
    header_span: SourceSpan
    end_span: SourceSpan | None = None

    def finish(self, end_span: SourceSpan) -> None:
        if self.end_span is not None:
            raise AssertionError("block closed twice")
        self.end_span = end_span

    def freeze(self) -> BlockRecord:
        if self.end_span is None:
            raise AssertionError("unclosed block cannot be frozen")
        return BlockRecord(
            index=self.index,
            kind=self.kind,
            type_identifier=self.type_identifier,
            name=self.name,
            arguments=self.arguments,
            depth=self.depth,
            parent_index=self.parent_index,
            path=self.path,
            header_span=self.header_span,
            end_span=self.end_span,
            span=SourceSpan(
                self.header_span.byte_start,
                self.end_span.byte_end,
                self.header_span.line_start,
                self.end_span.line_end,
            ),
        )


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _normalise_code_page(code_page: str | int) -> tuple[str, str, str]:
    if isinstance(code_page, bool) or not isinstance(code_page, (str, int)):
        raise TypeError("code_page must be an explicit string or integer")
    requested = str(code_page)
    lookup_name = f"cp{code_page}" if isinstance(code_page, int) else code_page.strip()
    if isinstance(code_page, str) and lookup_name.isdecimal():
        lookup_name = f"cp{lookup_name}"
    if not lookup_name:
        raise TypeError("code_page must not be empty")
    try:
        canonical = codecs.lookup(lookup_name).name
    except LookupError as exc:
        raise FRMError(f"unknown code page {requested!r}") from exc
    decode_name = "utf-8" if canonical == "utf-8-sig" else canonical
    try:
        encoded_probe = "VERSION\r\n".encode(decode_name, errors="strict")
    except (LookupError, UnicodeError) as exc:
        raise FRMError(f"code page {requested!r} cannot encode .frm syntax") from exc
    if encoded_probe != b"VERSION\r\n":
        raise FRMError(
            f"code page {requested!r} is not ASCII-compatible; use an explicit "
            "ASCII-compatible export code page"
        )
    return requested, canonical, decode_name


def _detect_bom(raw: bytes, codec_name: str) -> tuple[str | None, int]:
    for marker, kind, matching_codecs in _BOMS:
        if raw.startswith(marker):
            if codec_name not in matching_codecs:
                raise FRMError(
                    f"{kind} BOM conflicts with explicit code page {codec_name!r}"
                )
            return kind, len(marker)
    return None, 0


def _split_lines(
    payload: bytes,
    *,
    byte_base: int,
    codec_name: str,
) -> tuple[tuple[_Line, ...], tuple[tuple[str, int], ...], str, bool]:
    try:
        text = payload.decode(codec_name, errors="strict")
    except UnicodeDecodeError as exc:
        absolute = byte_base + exc.start
        raise FRMError(
            f"source is not valid {codec_name} at byte offset {absolute}"
        ) from exc
    if "\x00" in text:
        raise FRMError("NUL is not permitted in .frm text")
    if text.encode(codec_name, errors="strict") != payload:
        raise FRMError(
            f"code page {codec_name!r} does not round-trip the supplied bytes"
        )

    segments: list[tuple[str, str]] = []
    start = 0
    cursor = 0
    while cursor < len(text):
        if text[cursor] == "\r":
            newline = "\r\n" if cursor + 1 < len(text) and text[cursor + 1] == "\n" else "\r"
            segments.append((text[start:cursor], newline))
            cursor += len(newline)
            start = cursor
        elif text[cursor] == "\n":
            newline = "\n\r" if cursor + 1 < len(text) and text[cursor + 1] == "\r" else "\n"
            segments.append((text[start:cursor], newline))
            cursor += len(newline)
            start = cursor
        else:
            cursor += 1
    if start < len(text) or not segments:
        segments.append((text[start:], ""))

    lines: list[_Line] = []
    rebuilt = bytearray()
    byte_cursor = byte_base
    counts = {"crlf": 0, "lfcr": 0, "lf": 0, "cr": 0}
    for number, (content, newline) in enumerate(segments, start=1):
        content_bytes = content.encode(codec_name, errors="strict")
        newline_bytes = newline.encode(codec_name, errors="strict")
        line_start = byte_cursor
        content_end = line_start + len(content_bytes)
        line_end = content_end + len(newline_bytes)
        lines.append(
            _Line(
                number=number,
                text=content,
                newline=newline,
                span=SourceSpan(line_start, line_end, number, number),
                content_span=SourceSpan(line_start, content_end, number, number),
                codec_name=codec_name,
            )
        )
        rebuilt.extend(content_bytes)
        rebuilt.extend(newline_bytes)
        byte_cursor = line_end
        if newline == "\r\n":
            counts["crlf"] += 1
        elif newline == "\n\r":
            counts["lfcr"] += 1
        elif newline == "\n":
            counts["lf"] += 1
        elif newline == "\r":
            counts["cr"] += 1
    if bytes(rebuilt) != payload:
        raise FRMError(
            f"code page {codec_name!r} is stateful across line boundaries and "
            "cannot provide unambiguous byte spans"
        )

    used = [name for name, count in counts.items() if count]
    if not used:
        style = "none"
    elif len(used) == 1:
        style = used[0]
    else:
        style = "mixed"
    terminal = bool(segments and segments[-1][1])
    return (
        tuple(lines),
        tuple((name, counts[name]) for name in ("crlf", "lfcr", "lf", "cr")),
        style,
        terminal,
    )


def _split_comment(rhs: str, line_number: int) -> tuple[str, int | None]:
    in_string = False
    cursor = 0
    while cursor < len(rhs):
        character = rhs[cursor]
        if character == '"':
            if in_string and cursor + 1 < len(rhs) and rhs[cursor + 1] == '"':
                cursor += 2
                continue
            in_string = not in_string
        elif character == "'" and not in_string:
            return rhs[:cursor], cursor
        cursor += 1
    if in_string:
        raise FRMError(f"line {line_number}: unterminated quoted string")
    return rhs, None


def _decode_vb_string(literal: str) -> str:
    if _VB_STRING_RE.fullmatch(literal) is None:
        raise AssertionError("not a complete VB string literal")
    return literal[1:-1].replace('""', '"')


def _classify_value(value_text: str) -> tuple[str, Any]:
    resource = _RESOURCE_RE.fullmatch(value_text)
    if resource is not None:
        return (
            "external_resource_reference",
            {
                "path": _decode_vb_string(resource.group("literal")),
                "offset_text": resource.group("offset"),
                "offset": int(resource.group("offset"), 16),
            },
        )
    if _VB_STRING_RE.fullmatch(value_text) is not None:
        return "string", _decode_vb_string(value_text)
    if value_text == "True":
        return "boolean", True
    if value_text == "False":
        return "boolean", False
    if _INTEGER_RE.fullmatch(value_text) is not None:
        return "integer", int(value_text, 10)
    if _HEX_RE.fullmatch(value_text) is not None:
        digits = value_text[2:-1] if value_text.endswith("&") else value_text[2:]
        return "hex_integer", int(digits, 16)
    if _DECIMAL_RE.fullmatch(value_text) is not None:
        return "decimal", value_text
    return "expression", value_text


def _parse_property(
    line: _Line,
    *,
    order: int,
    owner_block_index: int,
) -> PropertyRow:
    match = _ASSIGNMENT_RE.fullmatch(line.text)
    if match is None:
        raise FRMError(
            f"line {line.number}: expected an indented designer property assignment"
        )
    before_comment, comment_offset = _split_comment(match.group("rhs"), line.number)
    value_text = before_comment.rstrip()
    if not value_text:
        raise FRMError(f"line {line.number}: property value is empty")
    value_kind, parsed_value = _classify_value(value_text)
    value_start = match.start("rhs")
    value_end = value_start + len(value_text)

    comment: str | None = None
    comment_text: str | None = None
    comment_span: SourceSpan | None = None
    if comment_offset is not None:
        comment_start = match.start("rhs") + comment_offset
        comment = match.group("rhs")[comment_offset:]
        comment_text = comment[1:].strip()
        comment_span = line.token_span(comment_start, len(line.text))

    return PropertyRow(
        order=order,
        owner_block_index=owner_block_index,
        name=match.group("name"),
        indentation=match.group("indent"),
        value_text=value_text,
        value_kind=value_kind,
        parsed_value=parsed_value,
        comment=comment,
        comment_text=comment_text,
        span=line.span,
        value_span=line.token_span(value_start, value_end),
        comment_span=comment_span,
    )


def _parse_attribute(line: _Line, order: int) -> AttributeRow:
    match = _ATTRIBUTE_RE.fullmatch(line.text)
    if match is None:
        raise FRMError(f"line {line.number}: malformed class-header Attribute row")
    before_comment, comment_offset = _split_comment(match.group("rhs"), line.number)
    if comment_offset is not None:
        raise FRMError(f"line {line.number}: Attribute rows cannot contain comments")
    value_text = before_comment.rstrip()
    if not value_text:
        raise FRMError(f"line {line.number}: Attribute value is empty")
    value_kind, parsed_value = _classify_value(value_text)
    value_start = match.start("rhs")
    return AttributeRow(
        order=order,
        name=match.group("name"),
        value_text=value_text,
        value_kind=value_kind,
        parsed_value=parsed_value,
        span=line.span,
        value_span=line.token_span(value_start, value_start + len(value_text)),
    )


def _unsafe_path_reasons(path: str) -> tuple[str, ...]:
    reasons: list[str] = []
    if not path:
        reasons.append("empty_path")
    if "\x00" in path:
        reasons.append("nul_character")
    if any(ord(character) < 32 or ord(character) == 127 for character in path):
        reasons.append("control_character")
    drive, _ = ntpath.splitdrive(path)
    if drive:
        reasons.append("drive_or_unc_prefix")
    if PureWindowsPath(path).is_absolute():
        reasons.append("absolute_path")
    if "/" in path or "\\" in path:
        reasons.append("path_separator")
    if any(part in (".", "..") for part in PureWindowsPath(path).parts):
        reasons.append("relative_traversal_component")
    if any(character in path for character in '<>:"|?*'):
        reasons.append("windows_invalid_character")
    if path.endswith((" ", ".")):
        reasons.append("trailing_space_or_dot")
    basename = PureWindowsPath(path).name
    try:
        path_utf16_units = len(path.encode("utf-16-le")) // 2
        basename_utf16_units = len(basename.encode("utf-16-le")) // 2
    except UnicodeEncodeError:
        reasons.append("invalid_utf16_filename")
    else:
        if path_utf16_units >= 260:
            reasons.append("path_length_not_less_than_260_utf16_code_units")
        if basename_utf16_units > 255:
            reasons.append("filename_component_exceeds_255_utf16_code_units")
    stem = basename.split(".", 1)[0].upper().translate(
        str.maketrans({"¹": "1", "²": "2", "³": "3"})
    )
    reserved = {"CON", "PRN", "AUX", "NUL", "CONIN$", "CONOUT$"}
    reserved.update(f"COM{index}" for index in range(1, 10))
    reserved.update(f"LPT{index}" for index in range(1, 10))
    if stem in reserved:
        reasons.append("windows_reserved_name")
    return tuple(dict.fromkeys(reasons))


def _reference_for_property(row: PropertyRow) -> ExternalResourceReference | None:
    if row.value_kind != "external_resource_reference":
        return None
    parsed = row.parsed_value
    if not isinstance(parsed, dict):
        raise AssertionError("resource reference has non-dict parsed value")
    path = str(parsed["path"])
    reasons = _unsafe_path_reasons(path)
    return ExternalResourceReference(
        property_order=row.order,
        owner_block_index=row.owner_block_index,
        property_name=row.name,
        path=path,
        offset_text=str(parsed["offset_text"]),
        offset=int(parsed["offset"]),
        is_safe_relative_basename=not reasons,
        unsafe_reasons=reasons,
        span=row.value_span,
    )


def _parse_attributes(
    lines: Sequence[_Line],
    start: int,
    *,
    root_name: str,
    strict_office: bool,
) -> tuple[tuple[AttributeRow, ...], int, bool]:
    attributes: list[AttributeRow] = []
    cursor = start
    while cursor < len(lines) and lines[cursor].text.startswith("Attribute"):
        attributes.append(_parse_attribute(lines[cursor], len(attributes)))
        cursor += 1
    if not attributes:
        line_number = lines[start].number if start < len(lines) else len(lines) + 1
        raise FRMError(
            f"line {line_number}: designer End must be followed immediately by "
            "contiguous class-header Attribute rows"
        )

    standard = len(attributes) == len(_STANDARD_ATTRIBUTES)
    if standard:
        for row, (expected_name, expected_kind, expected_value) in zip(
            attributes, _STANDARD_ATTRIBUTES
        ):
            wanted = root_name if expected_name == "VB_Name" else expected_value
            if (
                row.name != expected_name
                or row.value_kind != expected_kind
                or row.parsed_value != wanted
            ):
                standard = False
                break

    for row in attributes:
        if row.name not in _CLASS_ATTRIBUTE_NAMES:
            raise FRMError(f"unsupported MS-VBAL class Attribute {row.name!r}")
        if row.name in {"VB_GlobalNameSpace", "VB_Creatable"}:
            if row.value_kind != "boolean" or row.parsed_value is not False:
                raise FRMError(f"class-header {row.name} must be False")
        elif row.name != "VB_Name" and row.value_kind != "boolean":
            raise FRMError(f"class-header {row.name} must be a boolean literal")

    name_rows = [row for row in attributes if row.name == "VB_Name"]
    if not name_rows:
        raise FRMError("class header must contain at least one VB_Name Attribute")
    name_row = name_rows[-1]
    if (
        name_row.value_kind != "string"
        or not isinstance(name_row.parsed_value, str)
        or re.fullmatch(_IDENTIFIER, name_row.parsed_value) is None
    ):
        raise FRMError(
            "last class-header VB_Name must be an MS-VBAL quoted identifier"
        )
    if len(name_row.parsed_value) > 31:
        raise FRMError("class-header VB_Name exceeds the 31-character maximum")
    if name_row.parsed_value != root_name:
        raise FRMError(
            "last class-header VB_Name must equal the designer ModuleIdentifier"
        )
    return tuple(attributes), cursor, standard


def _parse_strict_designer(
    lines: Sequence[_Line],
) -> tuple[
    str,
    str,
    SourceSpan,
    SourceSpan,
    SourceSpan,
    tuple[PropertyRow, ...],
    tuple[BlockRecord, ...],
    int,
]:
    if len(lines) < 3:
        raise FRMError("truncated Office VBA UserForm designer header")
    begin = _STRICT_BEGIN_RE.fullmatch(lines[1].text)
    if begin is None:
        raise FRMError(
            "line 2: Office VBA UserForm root must be "
            "Begin {GUID} <ModuleIdentifier>"
        )
    guid = begin.group("guid").upper()
    root_name = begin.group("name")
    if not root_name:
        raise FRMError("Office UserForm root ModuleIdentifier cannot be empty")
    if len(root_name) > 31:
        raise FRMError(
            "Office UserForm root ModuleIdentifier exceeds the 31-character maximum"
        )
    properties: list[PropertyRow] = []
    names: set[str] = set()
    cursor = 2
    while cursor < len(lines) and _END_RE.fullmatch(lines[cursor].text) is None:
        text = lines[cursor].text.lstrip()
        if text.startswith("Begin") or _END_PROPERTY_RE.fullmatch(lines[cursor].text):
            raise FRMError(
                f"line {lines[cursor].number}: nested designer blocks are not "
                f"part of the {OFFICE_VBA_USERFORM_EXPORT!r} profile"
            )
        row = _parse_property(
            lines[cursor], order=len(properties), owner_block_index=0
        )
        if row.name in names:
            raise FRMError(
                f"line {lines[cursor].number}: duplicate root property {row.name!r}"
            )
        names.add(row.name)
        properties.append(row)
        cursor += 1
    if cursor >= len(lines):
        raise FRMError("Office VBA UserForm root block is missing its End row")
    end_span = lines[cursor].span
    begin_span = lines[1].span
    root_span = SourceSpan(
        begin_span.byte_start,
        end_span.byte_end,
        begin_span.line_start,
        end_span.line_end,
    )
    block = BlockRecord(
        index=0,
        kind="object",
        type_identifier="{" + guid + "}",
        name=root_name,
        arguments=None,
        depth=0,
        parent_index=None,
        path="/" + root_name,
        header_span=begin_span,
        end_span=end_span,
        span=root_span,
    )
    return (
        guid,
        root_name,
        begin_span,
        end_span,
        root_span,
        tuple(properties),
        (block,),
        cursor + 1,
    )


def _parse_legacy_designer(
    lines: Sequence[_Line],
) -> tuple[
    str,
    str | None,
    str,
    SourceSpan,
    SourceSpan,
    SourceSpan,
    tuple[PropertyRow, ...],
    tuple[BlockRecord, ...],
    int,
]:
    if len(lines) < 3:
        raise FRMError("truncated legacy/synthetic designer header")
    builders: list[_BlockBuilder] = []
    stack: list[int] = []
    properties: list[PropertyRow] = []
    owner_names: dict[int, set[str]] = {}
    cursor = 1
    root_closed = False

    while cursor < len(lines):
        line = lines[cursor]
        property_begin = _PROPERTY_BEGIN_RE.fullmatch(line.text)
        object_begin = _OBJECT_BEGIN_RE.fullmatch(line.text)
        if property_begin is not None:
            if not stack:
                raise FRMError(
                    f"line {line.number}: BeginProperty cannot be a root block"
                )
            parent = builders[stack[-1]]
            name = property_begin.group("name")
            path = parent.path + "/@" + name
            builder = _BlockBuilder(
                index=len(builders),
                kind="property",
                type_identifier=None,
                name=name,
                arguments=property_begin.group("arguments"),
                depth=len(stack),
                parent_index=parent.index,
                path=path,
                header_span=line.span,
            )
            builders.append(builder)
            stack.append(builder.index)
            owner_names[builder.index] = set()
        elif object_begin is not None:
            if not stack and builders:
                raise FRMError(f"line {line.number}: multiple root Begin blocks")
            parent_index = stack[-1] if stack else None
            name = object_begin.group("name")
            path = (
                builders[parent_index].path + "/" + name
                if parent_index is not None
                else "/" + name
            )
            builder = _BlockBuilder(
                index=len(builders),
                kind="object",
                type_identifier=object_begin.group("type"),
                name=name,
                arguments=None,
                depth=len(stack),
                parent_index=parent_index,
                path=path,
                header_span=line.span,
            )
            builders.append(builder)
            stack.append(builder.index)
            owner_names[builder.index] = set()
        elif _END_PROPERTY_RE.fullmatch(line.text) is not None:
            if not stack or builders[stack[-1]].kind != "property":
                raise FRMError(
                    f"line {line.number}: EndProperty does not match an open "
                    "BeginProperty block"
                )
            builders[stack.pop()].finish(line.span)
        elif _END_RE.fullmatch(line.text) is not None:
            if not stack or builders[stack[-1]].kind != "object":
                raise FRMError(
                    f"line {line.number}: End does not match an open Begin block"
                )
            builders[stack.pop()].finish(line.span)
            if not stack:
                root_closed = True
                cursor += 1
                break
        else:
            if not stack:
                raise FRMError(
                    f"line {line.number}: expected the legacy/synthetic root Begin"
                )
            owner = stack[-1]
            row = _parse_property(line, order=len(properties), owner_block_index=owner)
            if row.name in owner_names[owner]:
                raise FRMError(
                    f"line {line.number}: duplicate property {row.name!r} in "
                    f"block {builders[owner].path!r}"
                )
            owner_names[owner].add(row.name)
            properties.append(row)
        cursor += 1

    if not root_closed:
        if stack:
            open_paths = ", ".join(builders[index].path for index in stack)
            raise FRMError(f"unclosed designer block(s): {open_paths}")
        raise FRMError("legacy/synthetic designer has no balanced root block")
    if not builders or builders[0].kind != "object":
        raise FRMError("legacy/synthetic designer root must be a Begin object block")
    blocks = tuple(builder.freeze() for builder in builders)
    root = blocks[0]
    type_identifier = root.type_identifier
    if type_identifier is None:
        raise AssertionError("object block lacks type identifier")
    guid_match = re.fullmatch(rf"\{{(?P<guid>{_GUID_TEXT})\}}", type_identifier)
    guid = None if guid_match is None else guid_match.group("guid").upper()
    return (
        type_identifier,
        guid,
        root.name,
        root.header_span,
        root.end_span,
        root.span,
        tuple(properties),
        blocks,
        cursor,
    )


def _make_region(
    raw: bytes,
    classification: str,
    start: int,
    end: int,
    line_start: int | None,
    line_end: int | None,
) -> ByteRegion:
    if start < 0 or end < start or end > len(raw):
        raise AssertionError("invalid byte region")
    return ByteRegion(
        classification=classification,
        span=SourceSpan(start, end, line_start, line_end),
        sha256=_sha256(raw[start:end]),
    )


def _validate_regions(regions: Sequence[ByteRegion], raw_length: int) -> None:
    cursor = 0
    for region in regions:
        if region.span.length == 0:
            raise AssertionError("zero-length regions must be omitted")
        if region.span.byte_start != cursor:
            raise AssertionError(
                f"byte classification gap/overlap at {cursor}: {region.classification}"
            )
        cursor = region.span.byte_end
    if cursor != raw_length:
        raise AssertionError(f"byte classification ends at {cursor}, expected {raw_length}")


def parse_frm(
    data: bytes | bytearray | memoryview,
    code_page: str | int,
    *,
    profile: str = OFFICE_VBA_USERFORM_EXPORT,
) -> FRMInventory:
    """Parse raw ``.frm`` bytes under an explicit grammar and code page.

    ``code_page`` is intentionally mandatory.  The source bytes do not contain
    a reliable ANSI-code-page declaration, so silently selecting a locale would
    make evidence generation host-dependent.
    """

    if not isinstance(data, (bytes, bytearray, memoryview)):
        raise TypeError("data must be bytes-like")
    if profile not in _SUPPORTED_PROFILES:
        raise FRMError(
            f"unsupported .frm profile {profile!r}; expected one of "
            + ", ".join(sorted(_SUPPORTED_PROFILES))
        )
    raw = bytes(data)
    if not raw:
        raise FRMError(".frm source is empty")

    requested, canonical_codec, decode_codec = _normalise_code_page(code_page)
    bom_kind, bom_length = _detect_bom(raw, canonical_codec)
    lines, newline_counts, newline_style, terminal_newline = _split_lines(
        raw[bom_length:], byte_base=bom_length, codec_name=decode_codec
    )
    if not lines or not lines[0].text:
        raise FRMError(".frm source has no VERSION row")
    if profile == OFFICE_VBA_USERFORM_EXPORT:
        if bom_length:
            raise FRMError(
                "Office VBA UserForm VBFrame text is MBCS data and must not have a BOM"
            )
        if newline_style not in {"crlf", "lfcr"}:
            raise FRMError(
                "Office VBA UserForm VBFrame text requires one consistent normative "
                "NWLN newline style: CRLF or LFCR"
            )

    version_match = _VERSION_RE.fullmatch(lines[0].text)
    if version_match is None:
        raise FRMError("line 1: expected VERSION <major.minor>")
    version = version_match.group("version")
    if version != "5.00":
        raise FRMError(f"line 1: unsupported .frm VERSION {version!r}; expected '5.00'")

    if profile == OFFICE_VBA_USERFORM_EXPORT:
        (
            root_guid,
            root_name,
            root_begin_span,
            root_end_span,
            root_span,
            properties,
            blocks,
            after_designer,
        ) = _parse_strict_designer(lines)
        root_type_identifier = "{" + root_guid + "}"
    else:
        (
            root_type_identifier,
            root_guid,
            root_name,
            root_begin_span,
            root_end_span,
            root_span,
            properties,
            blocks,
            after_designer,
        ) = _parse_legacy_designer(lines)

    attributes, code_line_index, standard_header = _parse_attributes(
        lines,
        after_designer,
        root_name=root_name,
        strict_office=profile == OFFICE_VBA_USERFORM_EXPORT,
    )

    references = tuple(
        reference
        for property_row in properties
        for reference in [_reference_for_property(property_row)]
        if reference is not None
    )
    ole_rows = [row for row in properties if row.name == "OleObjectBlob"]
    ole_indexes = tuple(
        index
        for index, reference in enumerate(references)
        if reference.property_name == "OleObjectBlob"
    )
    if profile == OFFICE_VBA_USERFORM_EXPORT:
        if len(ole_rows) != 1 or len(ole_indexes) != 1:
            raise FRMError(
                "Office VBA UserForm root must contain exactly one OleObjectBlob "
                "external-resource reference"
            )
        if blocks[0].index != 0 or any(row.owner_block_index != 0 for row in properties):
            raise AssertionError("strict profile unexpectedly acquired nested ownership")

    designer_end = root_end_span.byte_end
    class_header_start = designer_end
    class_header_end = attributes[-1].span.byte_end
    code_start = class_header_end
    code_start_line = code_line_index + 1
    code_span = SourceSpan(
        code_start,
        len(raw),
        code_start_line if code_start < len(raw) else None,
        len(lines) if code_start < len(raw) else None,
    )

    regions: list[ByteRegion] = []
    if bom_length:
        regions.append(_make_region(raw, "bom", 0, bom_length, None, None))
    regions.append(
        _make_region(
            raw,
            "designer_text",
            bom_length,
            designer_end,
            1,
            root_end_span.line_end,
        )
    )
    regions.append(
        _make_region(
            raw,
            "class_header",
            class_header_start,
            class_header_end,
            attributes[0].span.line_start,
            attributes[-1].span.line_end,
        )
    )
    if code_start < len(raw):
        regions.append(
            _make_region(
                raw,
                "opaque_code_body",
                code_start,
                len(raw),
                code_start_line,
                len(lines),
            )
        )
    _validate_regions(regions, len(raw))

    return FRMInventory(
        profile=profile,
        profile_disposition=(
            "canonical_office_export_observation"
            if profile == OFFICE_VBA_USERFORM_EXPORT
            else "inventory_only_not_canonical_office_export"
        ),
        raw_length=len(raw),
        sha256=_sha256(raw),
        requested_code_page=requested,
        codec_name=canonical_codec,
        bom_kind=bom_kind,
        bom_length=bom_length,
        newline_style=newline_style,
        newline_counts=newline_counts,
        terminal_newline=terminal_newline,
        line_count=len(lines),
        version=version,
        version_span=lines[0].span,
        root_type_identifier=root_type_identifier,
        root_guid=root_guid,
        root_name=root_name,
        root_begin_span=root_begin_span,
        root_end_span=root_end_span,
        root_span=root_span,
        properties=properties,
        blocks=blocks,
        attributes=attributes,
        standard_office_class_header=standard_header,
        external_references=references,
        ole_object_blob_reference_indexes=ole_indexes,
        code_start_offset=code_start,
        code_start_line=code_start_line,
        code_span=code_span,
        byte_regions=tuple(regions),
        _raw=raw,
    )


def parse_frm_file(
    path: str | Path,
    code_page: str | int,
    *,
    profile: str = OFFICE_VBA_USERFORM_EXPORT,
) -> FRMInventory:
    """Read and parse a ``.frm`` file without following resource references."""

    return parse_frm(Path(path).read_bytes(), code_page, profile=profile)


def inventory_frm(
    data: bytes | bytearray | memoryview,
    code_page: str | int,
    *,
    profile: str = OFFICE_VBA_USERFORM_EXPORT,
) -> dict[str, Any]:
    """Return only the deterministic JSON-ready inventory."""

    return parse_frm(data, code_page, profile=profile).to_dict()


def inventory_frm_file(
    path: str | Path,
    code_page: str | int,
    *,
    profile: str = OFFICE_VBA_USERFORM_EXPORT,
) -> dict[str, Any]:
    """File-based convenience wrapper returning a JSON-ready inventory."""

    return parse_frm_file(path, code_page, profile=profile).to_dict()


__all__ = [
    "AttributeRow",
    "BlockRecord",
    "ByteRegion",
    "ExternalResourceReference",
    "FRMError",
    "FRMInventory",
    "LEGACY_SYNTHETIC_NESTED",
    "OFFICE_VBA_USERFORM_EXPORT",
    "PropertyRow",
    "SourceSpan",
    "inventory_frm",
    "inventory_frm_file",
    "parse_frm",
    "parse_frm_file",
]
