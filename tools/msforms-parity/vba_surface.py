"""Deterministic extraction of the declared public OxForms VBA surface.

The extractor deliberately reads the project manifest rather than globbing the
directory.  A file on disk is not part of the library until OxForms.basproj
includes it, and every included module is retained even when its public
declarations are later classified as an internal leak.
"""

from __future__ import annotations

import hashlib
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any, Iterable


SURFACE_SCHEMA = "oxforms.vba_public_surface.v1"


class SurfaceError(RuntimeError):
    """Raised when VBA source cannot be represented without guessing."""


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def normalized_utf8_text(raw: bytes) -> tuple[str, bytes]:
    """Decode UTF-8 text and canonicalize BOM/newlines for cross-OS identity."""

    text = raw.decode("utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
    return text, text.encode("utf-8")


def structural_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
        + "\n"
    ).encode("utf-8")


def _strip_comment(line: str) -> str:
    """Remove a VBA apostrophe comment while respecting doubled string quotes."""

    result: list[str] = []
    in_string = False
    index = 0
    while index < len(line):
        char = line[index]
        if char == '"':
            result.append(char)
            if in_string and index + 1 < len(line) and line[index + 1] == '"':
                result.append('"')
                index += 2
                continue
            in_string = not in_string
        elif char == "'" and not in_string:
            break
        else:
            result.append(char)
        index += 1
    return "".join(result)


def logical_lines(text: str, line_offset: int = 0) -> list[dict[str, Any]]:
    """Join VBA continuation lines and retain their exact physical span."""

    rows: list[dict[str, Any]] = []
    parts: list[str] = []
    start_line = 0
    for line_number, physical in enumerate(
        text.splitlines(), start=1 + line_offset
    ):
        without_comment = _strip_comment(physical)
        if without_comment != physical and re.search(
            r"\s_\s*$", without_comment
        ):
            raise SurfaceError(
                f"comment after VBA line-continuation underscore at line {line_number}"
            )
        code = without_comment.rstrip()
        if not parts and (not code.strip() or code.lstrip().lower().startswith("rem ")):
            continue
        if not parts:
            start_line = line_number
        continuation = bool(re.search(r"\s_$", code))
        if continuation:
            parts.append(re.sub(r"\s_$", "", code).strip())
            continue
        parts.append(code.strip())
        joined = " ".join(part for part in parts if part)
        if joined:
            rows.append(
                {
                    "text": joined,
                    "start_line": start_line,
                    "end_line": line_number,
                }
            )
        parts = []
    if parts:
        raise SurfaceError(f"unterminated VBA line continuation at line {start_line}")
    return rows


def _split_top_level(value: str, delimiter: str = ",") -> list[str]:
    pieces: list[str] = []
    current: list[str] = []
    depth = 0
    in_string = False
    index = 0
    while index < len(value):
        char = value[index]
        if char == '"':
            current.append(char)
            if in_string and index + 1 < len(value) and value[index + 1] == '"':
                current.append('"')
                index += 2
                continue
            in_string = not in_string
        elif not in_string and char == "(":
            depth += 1
            current.append(char)
        elif not in_string and char == ")":
            depth -= 1
            if depth < 0:
                raise SurfaceError(f"unbalanced parentheses in {value!r}")
            current.append(char)
        elif not in_string and depth == 0 and char == delimiter:
            pieces.append("".join(current).strip())
            current = []
        else:
            current.append(char)
        index += 1
    if in_string or depth != 0:
        raise SurfaceError(f"unbalanced parameter expression {value!r}")
    pieces.append("".join(current).strip())
    return pieces


def _split_default(value: str) -> tuple[str, str | None]:
    depth = 0
    in_string = False
    index = 0
    while index < len(value):
        char = value[index]
        if char == '"':
            if in_string and index + 1 < len(value) and value[index + 1] == '"':
                index += 2
                continue
            in_string = not in_string
        elif not in_string and char == "(":
            depth += 1
        elif not in_string and char == ")":
            depth -= 1
        elif not in_string and depth == 0 and char == "=":
            return value[:index].strip(), value[index + 1 :].strip()
        index += 1
    return value.strip(), None


_PARAMETER_RE = re.compile(
    r"^(?P<prefix>(?:(?:Optional|ByVal|ByRef|ParamArray)\s+)*)"
    r"(?P<name>\[[^\]]+\]|[A-Za-z_][A-Za-z0-9_]*)(?P<array>\(\))?"
    r"(?:\s+As\s+(?P<type>[A-Za-z_][A-Za-z0-9_.]*(?:\(\))?))?$",
    re.IGNORECASE,
)


def parse_parameters(value: str | None) -> list[dict[str, Any]]:
    if value is None or not value.strip():
        return []
    parameters: list[dict[str, Any]] = []
    for index, raw_piece in enumerate(_split_top_level(value)):
        if not raw_piece:
            raise SurfaceError(f"empty parameter in {value!r}")
        declaration, default = _split_default(raw_piece)
        match = _PARAMETER_RE.fullmatch(declaration)
        if not match:
            raise SurfaceError(f"unsupported VBA parameter declaration {raw_piece!r}")
        prefix = match.group("prefix") or ""
        tokens = [item.lower() for item in prefix.split()]
        if "byval" in tokens and "byref" in tokens:
            raise SurfaceError(f"parameter cannot be both ByVal and ByRef: {raw_piece!r}")
        passing = "byval" if "byval" in tokens else "byref"
        name = match.group("name")
        parameters.append(
            {
                "index": index,
                "name": name[1:-1] if name.startswith("[") else name,
                "passing": passing,
                "optional": "optional" in tokens,
                "param_array": "paramarray" in tokens,
                "array": bool(match.group("array"))
                or bool((match.group("type") or "").endswith("()")),
                "type": (match.group("type") or "Variant").removesuffix("()"),
                "default": default,
                "raw": raw_piece,
            }
        )
    return parameters


_PROCEDURE_RE = re.compile(
    r"^(?:(?P<visibility>Public|Private|Friend)\s+)?"
    r"(?:(?P<static>Static)\s+)?"
    r"(?:Property\s+(?P<accessor>Get|Let|Set)|(?P<procedure>Sub|Function|Event))\s+"
    r"(?P<name>\[[^\]]+\]|[A-Za-z_][A-Za-z0-9_]*)\s*"
    r"(?:\((?P<parameters>.*)\))?\s*"
    r"(?:As\s+(?P<return_type>[A-Za-z_][A-Za-z0-9_.]*(?:\(\))?))?\s*$",
    re.IGNORECASE,
)

_BLOCK_RE = re.compile(
    r"^(?:(?P<visibility>Public|Private|Friend)\s+)?(?P<kind>Enum|Type)\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*$",
    re.IGNORECASE,
)

_CONST_RE = re.compile(
    r"^(?:(?P<visibility>Public|Private|Friend)\s+)?Const\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
    r"(?:\s+As\s+(?P<type>[A-Za-z_][A-Za-z0-9_.]*))?\s*=\s*(?P<value>.+)$",
    re.IGNORECASE,
)

_VARIABLE_RE = re.compile(
    r"^(?P<visibility>Public|Private|Friend|Global)\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)(?P<array>\(\))?"
    r"(?:\s+As\s+(?:(?P<as_new>New)\s+)?(?P<type>[A-Za-z_][A-Za-z0-9_.]*))?\s*$",
    re.IGNORECASE,
)

_FIELD_RE = re.compile(
    r"^(?P<name>[A-Za-z_][A-Za-z0-9_]*)(?P<array>\(\))?"
    r"(?:\s+As\s+(?P<type>[A-Za-z_][A-Za-z0-9_.]*))?\s*$",
    re.IGNORECASE,
)

_ENUM_VALUE_RE = re.compile(
    r"^(?P<name>[A-Za-z_][A-Za-z0-9_]*)(?:\s*=\s*(?P<value>.+))?$",
    re.IGNORECASE,
)

_INSTANCING_VALUES = {
    "Private",
    "PublicNotCreatable",
    "MultiUse",
    "GlobalMultiUse",
    "SingleUse",
    "GlobalSingleUse",
}
_CREATABLE_INSTANCING = {
    "MultiUse",
    "GlobalMultiUse",
    "SingleUse",
    "GlobalSingleUse",
}
_GLOBAL_INSTANCING = {"GlobalMultiUse", "GlobalSingleUse"}
_HEADER_INSTANCING_NUMBERS = {
    "1": "Private",
    "2": "PublicNotCreatable",
    "3": "SingleUse",
    "4": "GlobalSingleUse",
    "5": "MultiUse",
    "6": "GlobalMultiUse",
}

_BOOLEAN_MODULE_ATTRIBUTES = {
    "vb_predeclaredid",
    "vb_exposed",
    "vb_globalnamespace",
    "vb_creatable",
}


def _validate_module_attribute_value(
    key: str, value: Any, raw_value: str, repo_path: str
) -> None:
    """Reject attribute spellings whose parsed type changes their meaning.

    VBA export attributes are typed metadata.  In particular, a quoted
    ``"False"`` string is truthy in Python and must never be laundered into a
    true exposure/creatability flag by downstream boolean coercion.
    """

    folded = key.casefold()
    if folded in _BOOLEAN_MODULE_ATTRIBUTES and type(value) is not bool:
        raise SurfaceError(
            f"module Attribute {key} in {repo_path} must be an unquoted Boolean"
        )
    if folded == "vb_name" and not (
        len(raw_value) >= 2 and raw_value[0] == raw_value[-1] == '"'
    ):
        raise SurfaceError(
            f"module Attribute {key} in {repo_path} must be a quoted string"
        )
    if folded == "vb_name" and (
        not isinstance(value, str)
        or re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", value) is None
    ):
        raise SurfaceError(
            f"module Attribute {key} in {repo_path} must be a valid VBA identifier"
        )


def _source_span(path: str, row: dict[str, Any]) -> dict[str, Any]:
    return {
        "path": path,
        "start_line": row["start_line"],
        "end_line": row["end_line"],
        "text": row["text"],
    }


def _implementation_target(
    procedure_name: str, implements: list[str]
) -> tuple[str, str] | None:
    """Resolve `Interface_Member` using the longest declared interface prefix."""

    candidates: list[tuple[str, str]] = []
    folded_name = procedure_name.casefold()
    for interface in implements:
        prefixes = {interface, interface.rsplit(".", 1)[-1]}
        for prefix in prefixes:
            marker = prefix + "_"
            if folded_name.startswith(marker.casefold()) and len(procedure_name) > len(marker):
                candidates.append((interface, prefix))
    if not candidates:
        return None
    candidates.sort(key=lambda item: len(item[1]), reverse=True)
    longest = len(candidates[0][1])
    winners = {item for item in candidates if len(item[1]) == longest}
    if len(winners) != 1:
        raise SurfaceError(
            f"ambiguous Implements prefix for private member {procedure_name!r}"
        )
    interface, prefix = winners.pop()
    return interface, procedure_name[len(prefix) + 1 :]


def _parse_class_header_instancing(
    text: str, module_kind: str, repo_path: str
) -> tuple[str | None, int]:
    """Mirror OxVba's exported-class-header instancing projection."""

    if module_kind != "class_module":
        return None, 0
    lines = text.splitlines()
    if not lines:
        return None, 0
    first = lines[0].strip()
    if not (
        first.casefold().startswith("version ")
        and first.casefold().endswith(" class")
    ):
        return None, 0
    if len(lines) < 2 or lines[1].strip().casefold() != "begin":
        raise SurfaceError(f"malformed exported class header in {repo_path}")

    recognized: list[str] = []
    ended = False
    folded_names = {name.casefold(): name for name in _INSTANCING_VALUES}
    header_line_count = 0
    for line_index, physical in enumerate(lines[2:], start=2):
        if physical.strip().casefold() == "end":
            ended = True
            header_line_count = line_index + 1
            break
        line = _strip_comment(physical).strip()
        if "=" not in line:
            continue
        key, raw_value = (piece.strip() for piece in line.split("=", 1))
        folded_key = key.casefold()
        value = raw_value.strip().strip('"')
        candidate: str | None = None
        if folded_key == "instancing":
            candidate = _HEADER_INSTANCING_NUMBERS.get(value)
            if candidate is None and value in _INSTANCING_VALUES:
                candidate = value
            if candidate is None:
                raise SurfaceError(
                    f"unsupported exported class-header Instancing in {repo_path}: {value!r}"
                )
        elif folded_key in folded_names:
            if value.casefold() in {"-1", "1", "true", "yes"}:
                candidate = folded_names[folded_key]
            elif value.casefold() not in {"0", "false", "no"}:
                raise SurfaceError(
                    f"unsupported exported class-header {key} value in {repo_path}: {value!r}"
                )
        if candidate is not None:
            recognized.append(candidate)
    if not ended:
        raise SurfaceError(f"unterminated exported class header in {repo_path}")
    if len(recognized) > 1:
        raise SurfaceError(
            f"ambiguous exported class-header Instancing in {repo_path}: {recognized!r}"
        )
    return (recognized[0] if recognized else None), header_line_count


def _parse_module(
    repo_root: Path,
    source_path: Path,
    module_kind: str,
    manifest_metadata: dict[str, Any],
) -> dict[str, Any]:
    raw = source_path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raise SurfaceError(
            f"UTF-8 BOM is unsupported in VBA module source {source_path}"
        )
    if re.search(rb"\r(?!\n)", raw):
        raise SurfaceError(
            f"lone CR line endings are unsupported in VBA module source {source_path}"
        )
    try:
        text, normalized = normalized_utf8_text(raw)
    except UnicodeDecodeError as exc:
        raise SurfaceError(f"{source_path} is not UTF-8 text") from exc
    repo_path = source_path.relative_to(repo_root).as_posix()
    source_header_instancing, header_line_count = _parse_class_header_instancing(
        text, module_kind, repo_path
    )
    body_text = "\n".join(text.splitlines()[header_line_count:])
    rows = logical_lines(body_text, line_offset=header_line_count)
    physical_source_lines = text.splitlines()
    attributes: dict[str, Any] = {}
    member_attributes: dict[str, dict[str, Any]] = {}
    implements: list[str] = []
    declarations: list[dict[str, Any]] = []
    interface_implementations: list[dict[str, Any]] = []
    known_member_names: set[str] = set()
    block: dict[str, Any] | None = None
    inside_procedure: str | None = None
    option_private_module = False

    for row in rows:
        line = row["text"]
        if re.match(
            r"^#(?:Const|If|ElseIf|Else|End\s+If)\b", line, re.IGNORECASE
        ):
            raise SurfaceError(
                "conditional compilation is unsupported at "
                f"{repo_path}:{row['start_line']}: {line}"
            )
        if re.match(
            r"^Def(?:Bool|Byte|Cur|Date|Dbl|Dec|Int|LngLng|LngPtr|Lng|Obj|Sng|Str|Var)\b",
            line,
            re.IGNORECASE,
        ):
            raise SurfaceError(
                "module default-type statements are unsupported at "
                f"{repo_path}:{row['start_line']}: {line}"
            )
        attribute = re.fullmatch(
            r"Attribute\s+([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?)\s*=\s*(.+)",
            line,
            re.IGNORECASE,
        )
        if attribute:
            key = attribute.group(1)
            if "." not in key and (inside_procedure is not None or block is not None):
                raise SurfaceError(
                    "module Attribute is only valid at module scope at "
                    f"{repo_path}:{row['start_line']}: {line}"
                )
            if row["start_line"] != row["end_line"]:
                scope = "member" if "." in key else "module"
                raise SurfaceError(
                    f"{scope} Attribute must occupy one physical source line at "
                    f"{repo_path}:{row['start_line']}"
                )
            if "." not in key:
                physical_attribute = physical_source_lines[row["start_line"] - 1]
                if _strip_comment(physical_attribute) != physical_attribute:
                    raise SurfaceError(
                        "commented module Attribute differs from pinned OxVba at "
                        f"{repo_path}:{row['start_line']}"
                    )
            value = attribute.group(2).strip()
            if value.lower() in {"true", "false"}:
                parsed_value: Any = value.lower() == "true"
            elif len(value) >= 2 and value[0] == value[-1] == '"':
                parsed_value = value[1:-1].replace('""', '"')
            elif re.fullmatch(r"-?[0-9]+", value):
                parsed_value = int(value)
            else:
                parsed_value = value
            if "." in key:
                member_name, attribute_name = key.split(".", 1)
                if attribute_name.casefold() == "vb_usermemid" and type(
                    parsed_value
                ) is not int:
                    raise SurfaceError(
                        f"member Attribute {key} in {repo_path} must be an unquoted integer"
                    )
                if (
                    attribute_name.casefold() == "vb_usermemid"
                    and re.fullmatch(r"-0+", value) is not None
                ):
                    raise SurfaceError(
                        f"member Attribute {key} in {repo_path} uses signed zero not recognized by pinned OxVba"
                    )
                target = member_attributes.setdefault(member_name.casefold(), {})
                if attribute_name.casefold() in {
                    item.casefold() for item in target
                }:
                    raise SurfaceError(f"duplicate {key} in {repo_path}")
                target[attribute_name] = parsed_value
            else:
                if key.casefold() in {item.casefold() for item in attributes}:
                    raise SurfaceError(f"duplicate {key} in {repo_path}")
                _validate_module_attribute_value(
                    key, parsed_value, value, repo_path
                )
                attributes[key] = parsed_value
            continue

        if re.match(r"^Option\s+Private\b", line, re.IGNORECASE):
            if re.fullmatch(
                r"Option\s+Private\s+Module", line, re.IGNORECASE
            ) is None:
                raise SurfaceError(
                    "unsupported Option Private spelling at "
                    f"{repo_path}:{row['start_line']}: {line}"
                )
            if inside_procedure is not None or block is not None:
                raise SurfaceError(
                    "Option Private Module is only valid at module scope at "
                    f"{repo_path}:{row['start_line']}"
                )
            option_private_module = True
            continue

        if inside_procedure is not None:
            if re.fullmatch(rf"End\s+{inside_procedure}", line, re.IGNORECASE):
                inside_procedure = None
            continue

        if block is not None:
            if re.fullmatch(rf"End\s+{block['kind']}", line, re.IGNORECASE):
                block["source"]["end_line"] = row["end_line"]
                declarations.append(block)
                block = None
                continue
            if block["visibility"] != "public":
                continue
            if block["kind"] == "enum":
                member_match = _ENUM_VALUE_RE.fullmatch(line)
                if not member_match:
                    raise SurfaceError(f"unsupported enum member at {repo_path}:{row['start_line']}: {line}")
                block["members"].append(
                    {
                        "kind": "enum_constant",
                        "name": member_match.group("name"),
                        "value": member_match.group("value"),
                        "source": _source_span(repo_path, row),
                    }
                )
            else:
                field_match = _FIELD_RE.fullmatch(line)
                if not field_match:
                    raise SurfaceError(f"unsupported type field at {repo_path}:{row['start_line']}: {line}")
                block["members"].append(
                    {
                        "kind": "type_field",
                        "name": field_match.group("name"),
                        "type": field_match.group("type") or "Variant",
                        "array": bool(field_match.group("array")),
                        "source": _source_span(repo_path, row),
                    }
                )
            continue

        implements_match = re.fullmatch(
            r"Implements\s+([A-Za-z_][A-Za-z0-9_.]*)", line, re.IGNORECASE
        )
        if implements_match:
            implements.append(implements_match.group(1))
            continue

        block_match = _BLOCK_RE.fullmatch(line)
        if block_match:
            visibility = (block_match.group("visibility") or "Public").lower()
            block = {
                "kind": block_match.group("kind").lower(),
                "visibility": visibility,
                "explicit_visibility": block_match.group("visibility") is not None,
                "name": block_match.group("name"),
                "members": [],
                "source": _source_span(repo_path, row),
            }
            continue

        procedure_match = _PROCEDURE_RE.fullmatch(line)
        if procedure_match:
            visibility = (procedure_match.group("visibility") or "Public").lower()
            accessor = procedure_match.group("accessor")
            procedure = procedure_match.group("procedure")
            if accessor:
                kind = f"property_{accessor.lower()}"
            else:
                kind = procedure.lower()
            name = procedure_match.group("name")
            unescaped_name = name[1:-1] if name.startswith("[") else name
            known_member_names.add(unescaped_name.casefold())
            return_type = procedure_match.group("return_type")
            procedure_row = {
                "kind": kind,
                "visibility": visibility,
                "explicit_visibility": procedure_match.group("visibility") is not None,
                "name": unescaped_name,
                "bracketed_name": name.startswith("["),
                "default_member": False,
                "static": bool(procedure_match.group("static")),
                "parameters": parse_parameters(procedure_match.group("parameters")),
                "return_type": (
                    return_type
                    or ("Variant" if kind in {"function", "property_get"} else None)
                ),
                "source": _source_span(repo_path, row),
            }
            if visibility == "public":
                declarations.append(procedure_row)
            elif visibility == "private" and "_" in unescaped_name:
                target = _implementation_target(unescaped_name, implements)
                if target is not None:
                    interface_name, member_name = target
                    procedure_row["interface"] = interface_name
                    procedure_row["interface_member"] = member_name
                    interface_implementations.append(procedure_row)
            if kind != "event":
                inside_procedure = "Property" if kind.startswith("property_") else procedure
            continue

        const_match = _CONST_RE.fullmatch(line)
        if const_match:
            # An unqualified module-level Const is private in VBA.
            visibility = (const_match.group("visibility") or "Private").lower()
            if visibility == "public":
                declarations.append(
                    {
                        "kind": "constant",
                        "visibility": visibility,
                        "explicit_visibility": const_match.group("visibility") is not None,
                        "name": const_match.group("name"),
                        "type": const_match.group("type") or "Variant",
                        "value": const_match.group("value").strip(),
                        "source": _source_span(repo_path, row),
                    }
                )
            continue

        variable_match = _VARIABLE_RE.fullmatch(line)
        if variable_match:
            visibility = variable_match.group("visibility").lower()
            if visibility in {"public", "global"}:
                declarations.append(
                    {
                        "kind": "variable",
                        "visibility": "public",
                        "explicit_visibility": True,
                        "visibility_keyword": visibility,
                        "name": variable_match.group("name"),
                        "type": variable_match.group("type") or "Variant",
                        "as_new": bool(variable_match.group("as_new")),
                        "array": bool(variable_match.group("array")),
                        "source": _source_span(repo_path, row),
                    }
                )
            continue

        # A module-level Declare without an access modifier is Public by
        # default.  The public-surface extractor does not model native Declare
        # signatures yet, so fail closed instead of silently dropping one.
        if re.match(r"^(?:Public\s+)?Declare\b", line, re.IGNORECASE):
            raise SurfaceError(
                f"unparsed externally visible declaration at {repo_path}:"
                f"{row['start_line']}: {line}"
            )

        if re.match(r"^(?:Public|Friend|Global)\b", line, re.IGNORECASE):
            raise SurfaceError(
                f"unparsed externally visible declaration at {repo_path}:{row['start_line']}: {line}"
            )

    if block is not None:
        raise SurfaceError(
            f"unterminated Public {block['kind']} {block['name']} in {repo_path}"
        )
    if inside_procedure is not None:
        raise SurfaceError(f"unterminated {inside_procedure} in {repo_path}")

    known_member_names.update(item["name"].casefold() for item in declarations)
    orphan_attributes = sorted(set(member_attributes) - known_member_names)
    if orphan_attributes:
        raise SurfaceError(
            f"orphan member Attribute targets in {repo_path}: {', '.join(orphan_attributes)}"
        )
    for declaration in declarations + interface_implementations:
        declaration["member_attributes"] = dict(
            sorted(
                member_attributes.get(declaration["name"].casefold(), {}).items(),
                key=lambda item: item[0].casefold(),
            )
        )

    attribute_by_folded_name = {
        key.casefold(): value for key, value in attributes.items()
    }
    def source_attribute_or_manifest(
        source_name: str, manifest_name: str
    ) -> bool:
        # OxVba uses source_attrs.<field>.unwrap_or(manifest_attrs.<field>): an
        # explicit False in exported VBA metadata overrides basproj True.
        if source_name in attribute_by_folded_name:
            return attribute_by_folded_name[source_name]
        return manifest_metadata.get(manifest_name, False)

    effective_booleans = {
        "VB_PredeclaredId": source_attribute_or_manifest(
            "vb_predeclaredid", "VBPredeclaredId"
        ),
        "VB_Exposed": source_attribute_or_manifest("vb_exposed", "VBExposed"),
        "VB_GlobalNameSpace": source_attribute_or_manifest(
            "vb_globalnamespace", "VBGlobalNamespace"
        ),
        "VB_Creatable": source_attribute_or_manifest(
            "vb_creatable", "VBCreatable"
        ),
    }
    effective_instancing = manifest_metadata.get(
        "Instancing", source_header_instancing
    )
    module_name = attribute_by_folded_name.get("vb_name", source_path.stem)
    return {
        "name": module_name,
        "file_stem": source_path.stem,
        "kind": module_kind,
        "path": repo_path,
        "normalized_text_sha256": sha256_bytes(normalized),
        "attributes": dict(sorted(attributes.items(), key=lambda item: item[0].lower())),
        "manifest_metadata": copy_manifest_metadata(manifest_metadata),
        "effective_attributes": effective_booleans,
        "source_header_instancing": source_header_instancing,
        "source_header_line_count": header_line_count,
        "effective_instancing": effective_instancing,
        "option_private_module": option_private_module,
        "project_declared_exposed": (
            not option_private_module
            and (
                module_kind == "standard_module"
                or effective_booleans["VB_Exposed"]
            )
        ),
        "project_declared_creatable": (
            effective_booleans["VB_Creatable"]
            or effective_instancing in _CREATABLE_INSTANCING
        ),
        "project_declared_predeclared_id": effective_booleans["VB_PredeclaredId"],
        "project_declared_global_namespace": (
            module_kind == "standard_module"
            or effective_booleans["VB_GlobalNameSpace"]
            or effective_instancing in _GLOBAL_INSTANCING
        ),
        "implements": implements,
        "declarations": declarations,
        "interface_implementations": interface_implementations,
}


_BASPROJ_BOOLEAN_METADATA = {
    "VBPredeclaredId",
    "VBExposed",
    "VBGlobalNamespace",
    "VBCreatable",
}
_BASPROJ_STRING_METADATA = {"Instancing", "ProgId", "Description"}


def copy_manifest_metadata(value: dict[str, Any]) -> dict[str, Any]:
    return {key: value[key] for key in sorted(value)}


def _manifest_metadata(element: ET.Element, tag: str, include: str) -> dict[str, Any]:
    metadata: dict[str, Any] = {}
    for child in element:
        name = child.tag.rsplit("}", 1)[-1]
        if name in metadata:
            raise SurfaceError(f"duplicate {name} metadata on {tag} {include!r}")
        if list(child):
            raise SurfaceError(f"nested metadata is unsupported on {tag} {include!r}")
        text = (child.text or "").strip()
        if name in _BASPROJ_BOOLEAN_METADATA:
            if text.casefold() not in {"true", "false"}:
                raise SurfaceError(
                    f"{name} on {tag} {include!r} must be True or False"
                )
            metadata[name] = text.casefold() == "true"
        elif name in _BASPROJ_STRING_METADATA:
            if not text:
                raise SurfaceError(f"{name} on {tag} {include!r} must not be empty")
            if name == "Instancing" and text not in _INSTANCING_VALUES:
                raise SurfaceError(
                    f"Instancing on {tag} {include!r} must be one of the six recognized values"
                )
            metadata[name] = text
        else:
            raise SurfaceError(f"unsupported metadata {name!r} on {tag} {include!r}")
    if tag != "ClassModule" and metadata:
        raise SurfaceError(f"{tag} {include!r} cannot carry class metadata")
    return metadata


def _xml_local_name(value: str) -> str:
    return value.rsplit("}", 1)[-1]


_XML_ENTITY_OR_CHARACTER_REFERENCE_RE = re.compile(
    r"&(?:#[xX][0-9A-Fa-f]+|#[0-9]+|[A-Za-z_][A-Za-z0-9_.:-]*);"
)


def _reject_unsupported_basproj_lexical_forms(
    basproj_text: str, basproj_path: Path
) -> None:
    """Reject XML spellings that the pinned OxVba loader does not normalize.

    ElementTree expands these forms before shape validation, while the pinned
    quick_xml loader compares raw attribute values and accepts ordinary text
    events only.  The parity extractor must not grant a clean-loader profile to
    a project spelling that the real loader interprets differently.
    """

    if "<!DOCTYPE" in basproj_text or "<![CDATA[" in basproj_text:
        raise SurfaceError(
            f"DOCTYPE and CDATA are unsupported in exact basproj {basproj_path}"
        )
    if _XML_ENTITY_OR_CHARACTER_REFERENCE_RE.search(basproj_text):
        raise SurfaceError(
            f"XML entity and character references are unsupported in exact basproj {basproj_path}"
        )


def _validate_basproj_shape(root: ET.Element, basproj_path: Path) -> None:
    """Accept only the unconditional project shape this extractor understands.

    Evaluating arbitrary MSBuild conditions/imports is outside this tool.  A
    conditional or item-shaping construct must therefore fail rather than be
    walked as though every XML descendant were live in the clean profile.
    """

    if root.tag != "Project":
        raise SurfaceError(f"basproj root in {basproj_path} must be exact Project")
    if any(element.tag != _xml_local_name(element.tag) for element in root.iter()):
        raise SurfaceError(
            f"XML namespaces are unsupported in exact basproj {basproj_path}"
        )
    container_tags = {
        "Project",
        "PropertyGroup",
        "ItemGroup",
        "Module",
        "ClassModule",
    }
    for element in root.iter():
        if element.tag in container_tags and (element.text or "").strip():
            raise SurfaceError(
                f"non-whitespace container text is unsupported in exact basproj {basproj_path}"
            )
        if (element.tail or "").strip():
            raise SurfaceError(
                f"non-whitespace element tail is unsupported in exact basproj {basproj_path}"
            )
    for element in root.iter():
        if any(name.casefold() == "condition" for name in element.attrib):
            raise SurfaceError(
                f"conditional basproj elements are unsupported in {basproj_path}"
            )
    if root.attrib != {"Sdk": "OxVba.Sdk/0.1.0"}:
        raise SurfaceError(
            f"Project identity in {basproj_path} must use OxVba.Sdk/0.1.0"
        )

    property_groups = [
        child for child in root if _xml_local_name(child.tag) == "PropertyGroup"
    ]
    if len(property_groups) != 1 or root[0] is not property_groups[0]:
        raise SurfaceError(
            f"basproj {basproj_path} must begin with exactly one PropertyGroup"
        )
    property_group = property_groups[0]
    exact_properties = [
        (_xml_local_name(element.tag), (element.text or "").strip())
        for element in property_group
    ]
    if exact_properties != [("OutputType", "Library"), ("ProjectName", "OxForms")]:
        raise SurfaceError(
            f"basproj {basproj_path} must declare OutputType=Library and ProjectName=OxForms exactly"
        )

    for container in root:
        tag = _xml_local_name(container.tag)
        if tag == "PropertyGroup":
            if container.attrib:
                raise SurfaceError(
                    f"unsupported PropertyGroup attributes in {basproj_path}"
                )
            for property_element in container:
                if property_element.attrib or list(property_element):
                    raise SurfaceError(
                        f"unsupported property shape in {basproj_path}"
                    )
            continue
        if tag != "ItemGroup":
            raise SurfaceError(
                f"unsupported basproj child {tag!r} in {basproj_path}"
            )
        if set(container.attrib) - {"Label"}:
            raise SurfaceError(
                f"unsupported ItemGroup attributes in {basproj_path}"
            )
        for item in container:
            item_tag = _xml_local_name(item.tag)
            if item_tag not in {"Module", "ClassModule"}:
                raise SurfaceError(
                    f"unsupported basproj item {item_tag!r} in {basproj_path}"
                )
            if set(item.attrib) != {"Include"}:
                raise SurfaceError(
                    f"unsupported attributes on {item_tag} in {basproj_path}"
                )
            for metadata in item:
                if metadata.attrib:
                    raise SurfaceError(
                        f"unsupported metadata attributes on {item_tag} in {basproj_path}"
                    )


def extract_surface(repo_root: Path, basproj_path: Path) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    basproj_path = basproj_path.resolve()
    if repo_root not in basproj_path.parents:
        raise SurfaceError("basproj must be inside the repository")
    try:
        basproj_text, basproj_normalized = normalized_utf8_text(
            basproj_path.read_bytes()
        )
        _reject_unsupported_basproj_lexical_forms(basproj_text, basproj_path)
        root = ET.fromstring(basproj_text)
    except (OSError, ET.ParseError, UnicodeDecodeError) as exc:
        raise SurfaceError(f"cannot parse {basproj_path}") from exc
    _validate_basproj_shape(root, basproj_path)

    modules: list[dict[str, Any]] = []
    seen_paths: set[str] = set()
    for element in root.iter():
        tag = _xml_local_name(element.tag)
        if tag not in {"Module", "ClassModule"}:
            continue
        include = element.attrib.get("Include")
        if not include:
            raise SurfaceError(f"{tag} in {basproj_path} has no Include")
        normalized = include.replace("\\", "/")
        if (
            normalized.startswith("/")
            or ":" in normalized
            or "$" in normalized
            or ".." in normalized.split("/")
        ):
            raise SurfaceError(f"unsafe basproj Include {include!r}")
        if normalized.casefold() in seen_paths:
            raise SurfaceError(f"duplicate basproj Include {include!r}")
        seen_paths.add(normalized.casefold())
        source_path = (basproj_path.parent / Path(*normalized.split("/"))).resolve()
        if repo_root not in source_path.parents or not source_path.is_file():
            raise SurfaceError(f"missing or out-of-repo basproj Include {include!r}")
        expected_suffix = ".bas" if tag == "Module" else ".cls"
        if source_path.suffix.lower() != expected_suffix:
            raise SurfaceError(f"{tag} Include must have {expected_suffix} suffix: {include!r}")
        manifest_metadata = _manifest_metadata(element, tag, include)
        modules.append(
            _parse_module(
                repo_root,
                source_path,
                "standard_module" if tag == "Module" else "class_module",
                manifest_metadata,
            )
        )

    if not modules:
        raise SurfaceError("basproj contains no Module or ClassModule items")
    on_disk_sources = {
        path.relative_to(basproj_path.parent).as_posix().casefold()
        for suffix in ("*.bas", "*.cls")
        for path in basproj_path.parent.rglob(suffix)
        if path.is_file()
    }
    if on_disk_sources != seen_paths:
        missing = sorted(seen_paths - on_disk_sources)
        unlisted = sorted(on_disk_sources - seen_paths)
        raise SurfaceError(
            "basproj/source inventory mismatch; "
            f"missing={missing!r}, unlisted={unlisted!r}"
        )
    names: set[str] = set()
    for module in modules:
        key = module["name"].casefold()
        if key in names:
            raise SurfaceError(f"duplicate VBA module name {module['name']!r}")
        names.add(key)

    canonical = {
        "basproj": basproj_path.relative_to(repo_root).as_posix(),
        "basproj_normalized_text_sha256": sha256_bytes(basproj_normalized),
        "modules": modules,
    }
    declarations = [item for module in modules for item in module["declarations"]]
    interface_implementations = [
        item for module in modules for item in module["interface_implementations"]
    ]
    return {
        "schema": SURFACE_SCHEMA,
        "schema_version": 1,
        **canonical,
        "summary": {
            "modules": len(modules),
            "class_modules": sum(item["kind"] == "class_module" for item in modules),
            "standard_modules": sum(item["kind"] == "standard_module" for item in modules),
            "project_declared_exposed_modules": sum(
                bool(item["project_declared_exposed"]) for item in modules
            ),
            "public_declarations": len(declarations),
            "public_events": sum(item["kind"] == "event" for item in declarations),
            "public_enum_constants": sum(
                len(item["members"])
                for item in declarations
                if item["kind"] == "enum"
            ),
            "public_type_fields": sum(
                len(item["members"])
                for item in declarations
                if item["kind"] == "type"
            ),
            "multiline_public_signatures": sum(
                item["kind"]
                in {
                    "sub",
                    "function",
                    "event",
                    "property_get",
                    "property_let",
                    "property_set",
                }
                and item["source"]["start_line"] != item["source"]["end_line"]
                for item in declarations
            ),
            "bracketed_public_names": sum(
                bool(item.get("bracketed_name")) for item in declarations
            ),
            "optional_parameters": sum(
                bool(parameter["optional"])
                for item in declarations
                for parameter in item.get("parameters", [])
            ),
            "param_arrays": sum(
                bool(parameter["param_array"])
                for item in declarations
                for parameter in item.get("parameters", [])
            ),
            "module_attributes": sum(
                len(item["attributes"]) for item in modules
            ),
            "implements_clauses": sum(len(item["implements"]) for item in modules),
            "private_interface_implementations": len(interface_implementations),
            "member_attributes": sum(
                len(item["member_attributes"]) for item in declarations
            ),
        },
        "canonical_sha256": sha256_bytes(structural_json_bytes(canonical)),
    }


def declaration_key(module: dict[str, Any], declaration: dict[str, Any]) -> tuple[str, str, str]:
    return (
        module["name"].casefold(),
        declaration["name"].casefold(),
        declaration["kind"].casefold(),
    )


def iter_public_declarations(surface: dict[str, Any]) -> Iterable[tuple[dict[str, Any], dict[str, Any]]]:
    for module in surface["modules"]:
        for declaration in module["declarations"]:
            yield module, declaration
