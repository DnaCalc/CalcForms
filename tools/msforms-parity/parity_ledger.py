"""Generate and validate the W010 MSForms row-level parity ledger.

The ledger has two deliberately separate layers:

* exact declaration contracts preserve every captured typelib record/view; and
* coclass/event projections carry implementation and behavioral obligations.

This separation prevents an ABI dual companion or one shared interface from
silently satisfying a distinct public coclass/versioned surface.
"""

from __future__ import annotations

import copy
import hashlib
import json
import os
import re
import tomllib
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable

from vba_surface import (
    SurfaceError,
    extract_surface,
    normalized_utf8_text,
    sha256_bytes,
    structural_json_bytes,
)


LEDGER_SCHEMA = "oxforms.msforms_parity_ledger.v1"
FM20_SCHEMA = "oxforms.fm20_typelib_facts.v1"
W005_SCHEMA = "oxforms.fm20_w005_event_reconciliation.v1"
MSOFORMS_SCHEMA = "oxforms.ms-oforms.persistence-facts.v1"
FRM_FRX_SCHEMA = "oxforms.forms-persistence.export-facts.v1"
OVERLAY_SCHEMA = "oxforms.msforms_public_overlay.v1"
POLICY_SCHEMA = "oxforms.msforms_surface_policy.v1"

DIMENSION_NAMES = (
    "type_or_declaration",
    "bind",
    "method",
    "get",
    "put",
    "putref",
    "default_binding",
    "error_coercion",
    "event",
    "render",
    "persistence",
    "oracle",
    "tests",
)
DIMENSION_STATUSES = {
    "not_applicable",
    "missing",
    "partial",
    "implemented_unverified",
    "verified",
    "excluded_authoritative",
    "blocked",
}
GATING_STATUSES = {"missing", "partial", "implemented_unverified", "blocked"}

EXPECTED_COUNTS = {
    "type_contract": 220,
    "declaration_member": 1849,
    "enum_value": 191,
    "declaration_variable": 30,
    "surface_member": 1794,
    "abi_adapter_member": 14,
    "event_projection": 380,
    "host_event_attachment": 10,
    "overlay_type": 1,
    "overlay_global_binding": 1,
    "overlay_capability": 1,
    "overlay_member": 21,
    "overlay_event": 6,
    "persistence_property": 98,
    "persistence_family_property": 245,
    "persistence_ms_oforms_fact": 1431,
    "persistence_frm_frx_fact": 823,
    "persistence_aggregate": 19,
    "unexpected_public_type": 12,
    "unexpected_public_member": 584,
    "unexpected_public_nested_member": 26,
}

ALLOWED_ROW_KINDS = set(EXPECTED_COUNTS)

EXPECTED_SOURCE_SUMMARY = {
    "modules": 37,
    "class_modules": 33,
    "standard_modules": 4,
    "project_declared_exposed_modules": 5,
    "public_declarations": 842,
    "public_events": 115,
    "public_enum_constants": 25,
    "public_type_fields": 11,
    "multiline_public_signatures": 36,
    "bracketed_public_names": 11,
    "optional_parameters": 4,
    "param_arrays": 1,
    "module_attributes": 5,
    "implements_clauses": 23,
    "private_interface_implementations": 545,
    "member_attributes": 0,
}

EXPECTED_MS_PERSISTENCE_CATEGORIES = {
    "default_matrix": 107,
    "enumerations": 26,
    "enumerations.values": 132,
    "record_sections": 90,
    "record_fields": 431,
    "bitfields": 28,
    "bitfields.entries": 320,
    "property_types": 18,
    "resource_formats": 10,
    "value_maps": 3,
    "value_maps.values": 8,
    "algorithms": 4,
    "cached_control_ids": 16,
    "control_families": 11,
    "product_behavior": 20,
    "documented_unknowns": 179,
    "external_references": 22,
    "worked_examples": 6,
}

EXPECTED_FRM_PERSISTENCE_CATEGORIES = {
    "binary_persistence_contract.binary_length_forms.record_fields": 43,
    "binary_persistence_contract.binary_length_forms.resource_format_codecs": 4,
    "binary_persistence_contract.binary_length_forms.selection_boundary": 1,
    "binary_persistence_contract.nonclaim_or_census_cell": 23,
    "binary_persistence_contract.object_valued_encodings.presence_flags": 14,
    "binary_persistence_contract.object_valued_encodings.properties": 3,
    "binary_persistence_contract.object_valued_encodings.resource_formats": 5,
    "binary_persistence_contract.object_valued_encodings.stream_data_slots": 8,
    "binary_persistence_contract.object_valued_encodings.type_layouts": 5,
    "binary_persistence_contract.omission_and_defaults.control_specific_default_matrix": 107,
    "binary_persistence_contract.omission_and_defaults.property_defaults": 98,
    "binary_persistence_contract.omission_and_defaults.property_masks": 15,
    "binary_persistence_contract.omission_and_defaults.storage_requirements": 192,
    "boundaries": 9,
    "cfb_inventories": 3,
    "cfb_source_rules.selected_sections": 5,
    "cfb_source_rules.strict_inventory_policy": 3,
    "code_boundaries": 3,
    "component_headers.boundary_policy": 1,
    "component_headers.fixtures": 3,
    "component_headers.observed_attribute_order": 1,
    "control_identifiers.designer_add_probes": 10,
    "control_identifiers.fm20_control_universe.hidden_fcontrol_coclasses_not_covered_by_forward_progids": 25,
    "control_identifiers.fm20_control_universe.page_coclass": 1,
    "control_identifiers.fm20_control_universe.primary_html_fcontrol_coclasses": 10,
    "control_identifiers.fm20_control_universe.primary_intrinsic_fcontrol_coclasses": 15,
    "control_identifiers.fm20_control_universe.primary_nonhidden_fcontrol_coclasses": 25,
    "control_identifiers.fm20_control_universe.typelib": 1,
    "control_identifiers.forward_progid_fm20_coclass_joins": 24,
    "control_identifiers.html_probe_boundary": 1,
    "control_identifiers.live_progid_registrations": 24,
    "control_identifiers.ms_oforms_cached_control_ids": 16,
    "control_identifiers.observed_instances": 21,
    "control_identifiers.observed_intrinsic_families": 16,
    "coverage": 5,
    "designer_properties.controlled_omission_pairs": 8,
    "designer_properties.normative_ordered_universe": 15,
    "fixtures": 3,
    "grammar.class_header_and_body.authority": 1,
    "grammar.class_header_and_body.body": 1,
    "grammar.class_header_and_body.body_interpretation": 1,
    "grammar.class_header_and_body.class_attribute_cardinality": 1,
    "grammar.class_header_and_body.class_module_rule": 1,
    "grammar.class_header_and_body.customizable_attribute_rule": 1,
    "grammar.class_header_and_body.duplicate_attribute_rule": 1,
    "grammar.class_header_and_body.header": 1,
    "grammar.class_header_and_body.module_name_length_rule": 1,
    "grammar.class_header_and_body.module_two_part_rule": 1,
    "grammar.class_header_and_body.source_project_false_rule": 1,
    "grammar.normative_vbframe.authority": 1,
    "grammar.normative_vbframe.designer_clsid": 1,
    "grammar.normative_vbframe.designer_name": 1,
    "grammar.normative_vbframe.designer_properties_first": 1,
    "grammar.normative_vbframe.designer_properties_last": 1,
    "grammar.normative_vbframe.module_identifier_heading": 1,
    "grammar.normative_vbframe.module_identifier_rules": 1,
    "grammar.normative_vbframe.newline": 1,
    "grammar.normative_vbframe.property_order": 1,
    "grammar.normative_vbframe.vbframe_text": 1,
    "grammar.observed_office_extension.authority": 1,
    "grammar.observed_office_extension.location": 1,
    "grammar.observed_office_extension.normative_status": 1,
    "grammar.observed_office_extension.observed_property_orders": 1,
    "grammar.observed_office_extension.ole_object_blob_lexeme": 1,
    "grammar.observed_office_extension.parser_acceptance_policy": 1,
    "grammar.profile_separation.cross_profile_promotion": 1,
    "grammar.profile_separation.legacy_nested_text_controls": 1,
    "grammar.profile_separation.office_nested_text_controls": 1,
    "legacy_synthetic_corpus": 6,
    "profiles": 3,
    "resource_references": 3,
    "unknown_preservation": 15,
}

EXPECTED_MS_AGGREGATE_CATEGORIES = {
    "boundaries",
    "capture",
    "sections",
    "source_rows",
    "sources",
    "summary",
    "table_rows",
}
EXPECTED_FRM_AGGREGATE_CATEGORIES = {
    "binary_persistence_contract",
    "boundaries",
    "cfb_source_rules",
    "component_headers",
    "control_identifiers",
    "coverage",
    "designer_properties",
    "generator",
    "grammar",
    "source_rows",
    "sources",
    "summary",
}

PIN_SCHEMA = "oxforms.msforms_parity_input_pins.v1"
EXPECTED_LEDGER_SCHEMA = "oxforms.msforms_parity_expected_ledger.v1"
PIN_PATH = "tools/msforms-parity/pinned_inputs.v1.json"
EXPECTED_LEDGER_PATH = "tools/msforms-parity/expected_ledger.v1.json"

DEFAULT_PATHS = {
    "fm20": "docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.2/fm20_typelib_facts.v1.json",
    "w005": "docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.2/w005_event_reconciliation.v1.json",
    "ms_oforms": "docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.3/ms_oforms_persistence_facts.v1.json",
    "frm_frx": "docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.43/frm_frx_export_facts.v1.json",
    "overlay": "tools/msforms-parity/public_overlay.v1.json",
    "policy": "tools/msforms-parity/surface_policy.v1.json",
    "basproj": "vba/calcforms/CalcForms.basproj",
}


class LedgerError(RuntimeError):
    """Raised when canonical facts cannot be projected without guessing."""


def _reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise LedgerError(f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def _reject_nonfinite_json(value: str) -> Any:
    raise LedgerError(f"non-finite JSON number {value!r} is forbidden")


def _is_schema_version_one(value: Any) -> bool:
    """Require JSON number 1, excluding Python's bool-as-int equivalence."""

    return type(value) is int and value == 1


def _type_strict_json_equal(left: Any, right: Any) -> bool:
    """Compare JSON values without treating ``true`` as numeric ``1``."""

    return structural_json_bytes(left) == structural_json_bytes(right)


def load_json_strict(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=_reject_duplicate_pairs,
            parse_constant=_reject_nonfinite_json,
        )
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise LedgerError(f"cannot load JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise LedgerError(f"expected JSON object at {path}")
    return value


def _validate_input_schemas(inputs: dict[str, dict[str, Any]]) -> None:
    exact_schemas = {
        "fm20": ("schema", FM20_SCHEMA),
        "w005": ("schema", W005_SCHEMA),
        # The MS-OFORMS fact pack predates the other inputs and uses its
        # versioned schema identifier directly in `schema_version`.
        "ms_oforms": ("schema_version", MSOFORMS_SCHEMA),
        "frm_frx": ("schema", FRM_FRX_SCHEMA),
        "overlay": ("schema", OVERLAY_SCHEMA),
        "policy": ("schema", POLICY_SCHEMA),
    }
    labels = {
        "fm20": "FM20 fact",
        "w005": "W005 reconciliation",
        "ms_oforms": "MS-OFORMS fact",
        "frm_frx": "FRM/FRX fact",
        "overlay": "public overlay",
        "policy": "surface policy",
    }
    for name, (field, expected) in exact_schemas.items():
        if inputs[name].get(field) != expected:
            raise LedgerError(f"wrong {labels[name]} schema")
    for name in ("fm20", "w005", "frm_frx", "overlay", "policy"):
        version = inputs[name].get("schema_version")
        if not isinstance(version, int) or isinstance(version, bool) or version != 1:
            raise LedgerError(f"wrong {labels[name]} schema version")


def _rust_tokens(source: str, source_path: str) -> list[tuple[str, str]]:
    """Tokenize enough Rust to validate the two reviewed loader functions.

    This deliberately ignores comments and keeps strings/chars atomic.  The
    loader check depends on delimiter structure and direct expression shape;
    scanning the raw file would let comments, strings, or dead sibling blocks
    impersonate executable inventory and attribute assignments.
    """

    tokens: list[tuple[str, str]] = []
    index = 0
    length = len(source)
    while index < length:
        character = source[index]
        if character.isspace():
            index += 1
            continue
        if source.startswith("//", index):
            newline = source.find("\n", index + 2)
            index = length if newline < 0 else newline + 1
            continue
        if source.startswith("/*", index):
            depth = 1
            cursor = index + 2
            while cursor < length and depth:
                if source.startswith("/*", cursor):
                    depth += 1
                    cursor += 2
                elif source.startswith("*/", cursor):
                    depth -= 1
                    cursor += 2
                else:
                    cursor += 1
            if depth:
                raise LedgerError(f"unterminated Rust block comment in {source_path}")
            index = cursor
            continue

        raw_string = None
        for prefix in ("br", "cr", "r"):
            if not source.startswith(prefix, index):
                continue
            cursor = index + len(prefix)
            while cursor < length and source[cursor] == "#":
                cursor += 1
            if cursor < length and source[cursor] == '"':
                raw_string = (cursor, cursor - index - len(prefix))
                break
        if raw_string is not None:
            quote, hash_count = raw_string
            terminator = '"' + ("#" * hash_count)
            end = source.find(terminator, quote + 1)
            if end < 0:
                raise LedgerError(f"unterminated Rust raw string in {source_path}")
            tokens.append(("string", source[quote + 1 : end]))
            index = end + len(terminator)
            continue

        quote = None
        if character == '"':
            quote = index
        elif character in {"b", "c"} and index + 1 < length and source[index + 1] == '"':
            quote = index + 1
        if quote is not None:
            cursor = quote + 1
            while cursor < length:
                if source[cursor] == "\\":
                    cursor += 2
                    continue
                if source[cursor] == '"':
                    break
                cursor += 1
            if cursor >= length:
                raise LedgerError(f"unterminated Rust string in {source_path}")
            tokens.append(("string", source[quote + 1 : cursor]))
            index = cursor + 1
            continue

        if character == "'":
            cursor = index + 1
            if cursor < length and source[cursor] == "\\":
                cursor += 1
                if cursor < length and source[cursor] == "x":
                    cursor += 3
                elif cursor < length and source[cursor] == "u" and source.startswith("u{", cursor):
                    close = source.find("}", cursor + 2)
                    cursor = length if close < 0 else close + 1
                else:
                    cursor += 1
            else:
                cursor += 1
            if cursor < length and source[cursor] == "'":
                tokens.append(("char", source[index + 1 : cursor]))
                index = cursor + 1
                continue
            # A Rust lifetime (for example, 'static) is punctuation plus an
            # identifier, not a character literal.
            tokens.append(("punct", character))
            index += 1
            continue

        if character.isalpha() or character == "_":
            cursor = index + 1
            while cursor < length and (source[cursor].isalnum() or source[cursor] == "_"):
                cursor += 1
            tokens.append(("ident", source[index:cursor]))
            index = cursor
            continue
        if character.isdigit():
            cursor = index + 1
            while cursor < length and (source[cursor].isalnum() or source[cursor] in {"_", "."}):
                cursor += 1
            tokens.append(("number", source[index:cursor]))
            index = cursor
            continue
        tokens.append(("punct", character))
        index += 1
    return tokens


def _rust_matching_delimiter(
    tokens: list[tuple[str, str]], start: int, source_path: str
) -> int:
    pairs = {"(": ")", "[": "]", "{": "}"}
    opener = tokens[start][1]
    if opener not in pairs:
        raise LedgerError(f"expected Rust delimiter in {source_path}")
    stack = [opener]
    for index in range(start + 1, len(tokens)):
        value = tokens[index][1]
        if value in pairs:
            stack.append(value)
        elif value in pairs.values():
            if not stack or pairs[stack[-1]] != value:
                raise LedgerError(f"unbalanced Rust delimiters in {source_path}")
            stack.pop()
            if not stack:
                return index
    raise LedgerError(f"unterminated Rust delimiter in {source_path}")


def _rust_function_body(
    tokens: list[tuple[str, str]], function_name: str, source_path: str
) -> list[tuple[str, str]]:
    starts: list[int] = []
    brace_depth = 0
    for index, token in enumerate(tokens):
        value = token[1]
        if (
            brace_depth == 0
            and index + 1 < len(tokens)
            and token == ("ident", "fn")
            and tokens[index + 1] == ("ident", function_name)
        ):
            starts.append(index)
        if value == "{":
            brace_depth += 1
        elif value == "}":
            brace_depth -= 1
            if brace_depth < 0:
                raise LedgerError(f"unbalanced top-level Rust braces in {source_path}")
    if brace_depth:
        raise LedgerError(f"unterminated top-level Rust brace in {source_path}")
    if len(starts) != 1:
        raise LedgerError(
            f"loader source {source_path} must define exactly one {function_name} function"
        )
    if starts[0] > 0 and tokens[starts[0] - 1][1] != "}":
        raise LedgerError(
            f"loader source {source_path} {function_name} must be an unconditional private top-level function"
        )
    try:
        body_start = next(
            index for index in range(starts[0] + 2, len(tokens)) if tokens[index][1] == "{"
        )
    except StopIteration as exc:
        raise LedgerError(
            f"loader source {source_path} has no body for {function_name}"
        ) from exc
    body_end = _rust_matching_delimiter(tokens, body_start, source_path)
    return tokens[body_start + 1 : body_end]


def _rust_split_top_level(
    tokens: list[tuple[str, str]], delimiter: str, source_path: str
) -> list[list[tuple[str, str]]]:
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack: list[str] = []
    result: list[list[tuple[str, str]]] = []
    current: list[tuple[str, str]] = []
    for token in tokens:
        value = token[1]
        if value == delimiter and not stack:
            result.append(current)
            current = []
            continue
        if value in pairs:
            stack.append(value)
        elif value in pairs.values():
            if not stack or pairs[stack[-1]] != value:
                raise LedgerError(f"unbalanced Rust expression in {source_path}")
            stack.pop()
        current.append(token)
    if stack:
        raise LedgerError(f"unterminated Rust expression in {source_path}")
    result.append(current)
    return result


def _rust_statements_and_tail(
    body: list[tuple[str, str]], source_path: str
) -> tuple[list[list[tuple[str, str]]], list[tuple[str, str]]]:
    parts = _rust_split_top_level(body, ";", source_path)
    return parts[:-1], parts[-1]


def _rust_values(tokens: list[tuple[str, str]]) -> list[str]:
    return [value for _, value in tokens]


def _rust_unwrap(
    tokens: list[tuple[str, str]], opener: str, closer: str, source_path: str
) -> list[tuple[str, str]]:
    if not tokens or tokens[0][1] != opener:
        raise LedgerError(f"expected direct {opener}{closer} Rust expression in {source_path}")
    end = _rust_matching_delimiter(tokens, 0, source_path)
    if end != len(tokens) - 1 or tokens[end][1] != closer:
        raise LedgerError(f"expected direct {opener}{closer} Rust expression in {source_path}")
    return tokens[1:end]


def _parse_headless_loader_inventory(
    tokens: list[tuple[str, str]], source_path: str
) -> list[dict[str, str]]:
    body = _rust_function_body(tokens, "calcforms_modules", source_path)
    statements, tail = _rust_statements_and_tail(body, source_path)
    expected_use = ["use", "ModuleKind", ":", ":", "{", "Class", ",", "Procedural", "}"]
    if len(statements) != 2 or _rust_values(statements[0]) != expected_use:
        raise LedgerError(
            f"loader source {source_path} calcforms_modules no longer has the reviewed direct array shape"
        )
    declaration = statements[1]
    if _rust_values(declaration[:3]) != ["let", "modules", "="]:
        raise LedgerError(
            f"loader source {source_path} calcforms_modules inventory is not its live modules binding"
        )
    entries = _rust_split_top_level(
        _rust_unwrap(declaration[3:], "[", "]", source_path), ",", source_path
    )
    inventory: list[dict[str, str]] = []
    for entry in (item for item in entries if item):
        fields = [
            field
            for field in _rust_split_top_level(
                _rust_unwrap(entry, "(", ")", source_path), ",", source_path
            )
            if field
        ]
        if (
            len(fields) != 3
            or len(fields[0]) != 1
            or fields[0][0][0] != "string"
            or len(fields[1]) != 1
            or fields[1][0] not in {("ident", "Class"), ("ident", "Procedural")}
            or len(fields[2]) != 1
            or fields[2][0][0] != "string"
        ):
            raise LedgerError(f"loader source {source_path} has a malformed live module tuple")
        inventory.append(
            {"name": fields[0][0][1], "kind": fields[1][0][1], "path": fields[2][0][1]}
        )
    expected_tail = [
        "modules", ".", "into_iter", "(", ")", ".", "map", "(", "|", "(",
        "name", ",", "kind", ",", "path", ")", "|", "module_unit", "(",
        "repo_root", ",", "name", ",", "kind", ",", "Path", ":", ":", "new",
        "(", "path", ")", ")", ")", ".", "collect", "(", ")",
    ]
    if _rust_values(tail) != expected_tail:
        raise LedgerError(
            f"loader source {source_path} does not directly map its live modules binding through module_unit"
        )
    return inventory


def _parse_bootstrap_loader_inventory(
    tokens: list[tuple[str, str]], source_path: str, repo_root: Path
) -> list[dict[str, str]]:
    body = _rust_function_body(tokens, "calcforms_modules", source_path)
    statements, tail = _rust_statements_and_tail(body, source_path)
    expected_use = ["use", "ModuleKind", ":", ":", "{", "Class", ",", "Procedural", "}"]
    if len(statements) != 1 or _rust_values(statements[0]) != expected_use:
        raise LedgerError(
            f"loader source {source_path} calcforms_modules no longer has the reviewed direct vector shape"
        )
    if _rust_values(tail[:3]) != ["vec", "!", "["]:
        raise LedgerError(
            f"loader source {source_path} calcforms_modules does not directly return its vector"
        )
    elements = _rust_split_top_level(
        _rust_unwrap(tail[2:], "[", "]", source_path), ",", source_path
    )
    inventory: list[dict[str, str]] = []
    for element in (item for item in elements if item):
        if len(element) < 3 or element[:2] != [("ident", "unit"), ("punct", "(")]:
            raise LedgerError(
                f"loader source {source_path} has a vector element not directly constructed by unit"
            )
        fields = [
            field
            for field in _rust_split_top_level(
                _rust_unwrap(element[1:], "(", ")", source_path), ",", source_path
            )
            if field
        ]
        if (
            len(fields) != 3
            or len(fields[0]) != 1
            or fields[0][0][0] != "string"
            or len(fields[1]) != 1
            or fields[1][0] not in {("ident", "Class"), ("ident", "Procedural")}
            or _rust_values(fields[2][:3]) != ["include_str", "!", "("]
        ):
            raise LedgerError(f"loader source {source_path} has a malformed direct unit call")
        embedded = _rust_unwrap(fields[2][2:], "(", ")", source_path)
        if len(embedded) != 1 or embedded[0][0] != "string":
            raise LedgerError(f"loader source {source_path} has a malformed include_str path")
        embedded_path = embedded[0][1]
        if "\\" in embedded_path:
            raise LedgerError(
                f"loader source {source_path} has a noncanonical include_str path"
            )
        if not embedded_path.startswith("../../../"):
            raise LedgerError(f"loader source {source_path} has an unreviewed include_str path")
        source_file = (repo_root / source_path).resolve()
        candidate = (source_file.parent / embedded_path).resolve()
        resolved_repo = repo_root.resolve()
        candidate_parts = tuple(part.casefold() for part in candidate.parts)
        repo_parts = tuple(part.casefold() for part in resolved_repo.parts)
        oxforms_parts = tuple(
            part.casefold() for part in (resolved_repo / "vba" / "calcforms").parts
        )
        if candidate_parts[: len(repo_parts)] != repo_parts:
            raise LedgerError(f"loader source {source_path} include_str escapes the repository")
        if candidate_parts[: len(oxforms_parts)] == oxforms_parts:
            match = re.fullmatch(
                r"\.\./\.\./\.\./(?P<path>vba/calcforms/[A-Za-z_][A-Za-z0-9_]*\.(?:bas|cls))",
                embedded_path,
            )
            if match is None:
                raise LedgerError(
                    f"loader source {source_path} has a noncanonical CalcForms include_str path"
                )
            repo_path = match.group("path")
            canonical_candidate = (resolved_repo / repo_path).resolve()
            if candidate != canonical_candidate or not canonical_candidate.is_file():
                raise LedgerError(
                    f"loader source {source_path} CalcForms include_str identity differs"
                )
            inventory.append(
                {"name": fields[0][0][1], "kind": fields[1][0][1], "path": repo_path}
            )
    return inventory


def _validate_loader_helper(
    tokens: list[tuple[str, str]], helper: str, source_path: str
) -> None:
    body = _rust_function_body(tokens, helper, source_path)
    statements, tail = _rust_statements_and_tail(body, source_path)
    attribute_declaration = [
        "let", "mut", "attributes", "=", "ModuleAttributes", ":", ":", "named", "(", "name", ")"
    ]
    exposed_assignment = ["attributes", ".", "vb_exposed", "=", "true"]
    creatable_assignment = ["attributes", ".", "vb_creatable", "=", "true"]
    if helper == "module_unit":
        expected_prefixes = [
            ["let", "path", "=", "repo_root", ".", "join", "(", "relative_path", ")"],
            [
                "let", "source", "=", "std", ":", ":", "fs", ":", ":",
                "read_to_string", "(", "&", "path", ")", ".", "map_err", "(",
                "|", "err", "|", "format", "!", "(", "read {}: {err}", ",",
                "path", ".", "display", "(", ")", ")", ")", "?",
            ],
        ]
        expected_statements = expected_prefixes + [
            attribute_declaration,
            exposed_assignment,
            creatable_assignment,
        ]
        wrapped = True
    else:
        expected_statements = [attribute_declaration, exposed_assignment, creatable_assignment]
        wrapped = False
    if [_rust_values(statement) for statement in statements] != expected_statements:
        raise LedgerError(
            f"loader source {source_path} helper {helper} does not directly force exposed+creatable on its live attributes binding"
        )

    struct_tokens = tail
    if wrapped:
        if _rust_values(tail[:2]) != ["Ok", "("]:
            raise LedgerError(f"loader source {source_path} helper {helper} has no direct Ok result")
        struct_tokens = _rust_unwrap(tail[1:], "(", ")", source_path)
    if len(struct_tokens) < 3 or _rust_values(struct_tokens[:2]) != ["ModuleUnit", "{"]:
        raise LedgerError(
            f"loader source {source_path} helper {helper} does not directly return ModuleUnit"
        )
    fields = _rust_split_top_level(
        _rust_unwrap(struct_tokens[1:], "{", "}", source_path), ",", source_path
    )
    field_values = [_rust_values(field) for field in fields if field]
    expected_fields = [
        ["module_name", ":", "name", ".", "to_string", "(", ")"],
        ["module_kind", ":", "kind"],
        ["attributes"],
        ["source"] if helper == "module_unit" else ["source", ":", "source", ".", "to_string", "(", ")"],
    ]
    if field_values != expected_fields:
        raise LedgerError(
            f"loader source {source_path} helper {helper} does not bind its forced attributes into the direct ModuleUnit result"
        )


_LOADER_BUILD_SESSION_PREFIXES = {
    "headless_runner_forced": '''
let mut modules = calcforms_modules(repo_root)?;
for fixture in &spec.fixtures {
    modules.push(module_unit(
        repo_root,
        &fixture.name,
        fixture.kind,
        &fixture.relative_path,
    )?);
}
let manifest = SymbolProjectManifest {
    project_name: options.project_name.clone(),
    project_kind: ProjectKind::Library,
    modules,
    references: Vec::new(),
    reference_projects: Vec::new(),
    conditional_constants: Default::default(),
    conditional_compilation_target: Default::default(),
};
let program = calcvba_bind::bind_program(&manifest, &calcvba_symbol::CatalogTypeLibResolver)
    .map_err(|err| format!("bind headless project: {err:?}"))?;
''',
    "bootstrap_forced": '''
let manifest = SymbolProjectManifest {
    project_name: "CalcFormsBootstrap".to_string(),
    project_kind: ProjectKind::Library,
    modules: calcforms_modules(),
    references: Vec::new(),
    reference_projects: Vec::new(),
    conditional_constants: Default::default(),
    conditional_compilation_target: Default::default(),
};
let program = calcvba_bind::bind_program(&manifest, &calcvba_symbol::CatalogTypeLibResolver)
    .map_err(|err| BootstrapError::Project(format!("bind: {err:?}")))?;
''',
}

_LOADER_LIVE_CALLERS = {
    "headless_runner_forced": {
        "kind": "method",
        "name": "attach_with_options",
        "full_body": True,
        "source": '''
let (session, surface) = build_session(repo_root, spec, &options)?;
let rt = OxRuntime::attach_with_host_services(
    session,
    &spec.form_class,
    &spec.build_member,
    HostServices::headless(),
)?;
Ok(Self {
    rt,
    surface,
    options,
    clock_ms: 0,
    seq: 0,
    trace: Vec::new(),
})
''',
    },
    "bootstrap_forced": {
        "kind": "function",
        "name": "run",
        "full_body": False,
        "source": '''
let demo = selected_demo().map_err(BootstrapError::Project)?;
let (session, surface, fonts) = build_session()?;
let build_args = demo
    .build_arg
    .map(|arg| vec![Variant::from_string(arg)])
    .unwrap_or_default();
let mut rt = OxRuntime::attach_with_host_services_and_args(
    session,
    demo.form_class,
    demo.build_member,
    build_args,
    HostServices::windows(calcforms_pal_win::read_clipboard_text),
)
.map_err(BootstrapError::Runtime)?;
''',
    },
}

# Full token identities close dead-code, shadowing, enclosing cfg/impl-owner,
# and entrypoint redirection gaps around the semantically reviewed snippets.
# Comments/whitespace may move without changing these identities; executable
# token changes require a deliberate generator + evidence review.
_LOADER_REVIEWED_TOKEN_SHA256 = {
    "headless_runner_forced": "8ff5772ebea6bf6e0b36a0eb0e5753ed17f85ff511098c2c74ee2114f4890c42",
    "bootstrap_forced": "258489c671b4953b5a40f5e04d889512c3003ffc87aa94344a68ad5c9e4ae19a",
}

_ADAPTER_REVIEWED_TOKEN_SHA256 = {
    "crates/calcforms-calcvba-adapter/src/lib.rs": (
        "af626522943592079806fb08bb4d802ccc48dfd8dce0feb241a8f332cf59d319"
    ),
    "crates/calcforms-calcvba-adapter/src/runtime.rs": (
        "c6b0b0fbcf9aef4b39f4f381435af938dd8788eea00be48c3b54df592738fac0"
    ),
}

_LOADER_CARGO_TARGETS = {
    "headless_runner_forced": {
        "crate": "crates/calcforms-headless-runner",
        "package": "calcforms-headless-runner",
        "default_source": "src/lib.rs",
        "target_table": "lib",
    },
    "bootstrap_forced": {
        "crate": "crates/calcforms-bootstrap",
        "package": "calcforms-bootstrap",
        "default_source": "src/main.rs",
        "target_table": "bin",
    },
}

_REVIEWED_OXVBA_REPO = "https://github.com/DnaCalc/CalcVBA.git"
_REVIEWED_OXVBA_REV = "8840f391676d0796870e9c486ba2ca6586c5b8c7"
_REVIEWED_LOADER_OXVBA_DEPENDENCIES = (
    "calcvba-bind",
    "calcvba-bundle",
    "calcvba-com",
    "calcvba-hal",
    "calcvba-engine",
    "calcvba-oxir",
    "calcvba-runtime",
    "calcvba-symbol",
)
_REVIEWED_ADAPTER_CRATE = "crates/calcforms-calcvba-adapter"
_REVIEWED_ADAPTER_OXVBA_DEPENDENCIES = (
    "calcvba-bind",
    "calcvba-bundle",
    "calcvba-com",
    "calcvba-engine",
    "calcvba-hal",
    "calcvba-office",
    "calcvba-oxir",
    "calcvba-runtime",
    "calcvba-symbol",
)


def _targets_calcvba_dependency(name: Any, specification: Any) -> bool:
    return (
        isinstance(name, str)
        and name.startswith("calcvba-")
    ) or (
        isinstance(specification, dict)
        and isinstance(specification.get("package"), str)
        and specification["package"].startswith("calcvba-")
    )


def _load_toml(path: Path) -> dict[str, Any]:
    try:
        return tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError) as exc:
        raise LedgerError(f"cannot load reviewed Cargo manifest {path}: {exc}") from exc


def _validate_loader_cargo_targets(repo_root: Path) -> None:
    """Prove reviewed Rust files and their CalcVBA baseline remain live."""

    ignored_walk_directories = {
        ".git",
        ".venv",
        "__pycache__",
        "node_modules",
        "target",
    }
    for directory, child_directories, _files in os.walk(repo_root):
        cargo_directories = [
            Path(directory) / name
            for name in child_directories
            if name.casefold() == ".cargo"
        ]
        for cargo_directory in cargo_directories:
            try:
                has_content = next(cargo_directory.iterdir(), None) is not None
            except OSError as exc:
                raise LedgerError(
                    "cannot inspect repo-local Cargo config directory"
                ) from exc
            if has_content:
                raise LedgerError(
                    "repo-local Cargo config directory is unsupported by the reviewed CalcVBA baseline"
                )
        child_directories[:] = [
            name
            for name in child_directories
            if name.casefold() not in ignored_walk_directories
            and name.casefold() != ".cargo"
        ]

    root_manifest_path = repo_root / "Cargo.toml"
    root_manifest = _load_toml(root_manifest_path)
    workspace = root_manifest.get("workspace")
    members = workspace.get("members") if isinstance(workspace, dict) else None
    exclude = workspace.get("exclude", []) if isinstance(workspace, dict) else None
    if (
        not isinstance(members, list)
        or not all(isinstance(member, str) and member for member in members)
        or len(members) != len(set(members))
        or not isinstance(exclude, list)
        or not all(isinstance(item, str) and item for item in exclude)
        or exclude
        or workspace.get("resolver") != "2"
    ):
        raise LedgerError("root Cargo workspace members are missing or ambiguous")
    metadata = workspace.get("metadata") if isinstance(workspace, dict) else None
    oxforms_metadata = (
        metadata.get("calcforms") if isinstance(metadata, dict) else None
    )
    baseline = (
        oxforms_metadata.get("calcvba_baseline")
        if isinstance(oxforms_metadata, dict)
        else None
    )
    if (
        not isinstance(baseline, dict)
        or baseline.get("repo") != _REVIEWED_OXVBA_REPO
        or baseline.get("rev") != _REVIEWED_OXVBA_REV
    ):
        raise LedgerError(
            "root Cargo reviewed CalcVBA baseline repository/revision differs"
        )
    if "patch" in root_manifest or "replace" in root_manifest:
        raise LedgerError(
            "root Cargo patch/replace overrides are unsupported by the reviewed CalcVBA baseline"
        )
    for target in _LOADER_CARGO_TARGETS.values():
        crate_path = target["crate"]
        if crate_path not in members:
            raise LedgerError(
                f"root Cargo workspace omits reviewed loader crate {crate_path}"
            )
        manifest_path = repo_root / crate_path / "Cargo.toml"
        manifest = _load_toml(manifest_path)
        package = manifest.get("package")
        if (
            not isinstance(package, dict)
            or package.get("name") != target["package"]
            or "workspace" in package
            or "autolib" in package
            or "autobins" in package
            or ("default-run" in package and package["default-run"] != target["package"])
            or "build" in package
            or "workspace" in manifest
            or target["target_table"] in manifest
            or "features" in manifest
            or "target" in manifest
        ):
            raise LedgerError(
                f"reviewed loader crate {crate_path} no longer uses its exact default Cargo target identity"
            )
        for extra_dependency_table in (
            "build-dependencies",
            "dev-dependencies",
        ):
            extra_dependencies = manifest.get(extra_dependency_table, {})
            if not isinstance(extra_dependencies, dict) or any(
                _targets_calcvba_dependency(name, specification)
                for name, specification in extra_dependencies.items()
            ):
                raise LedgerError(
                    f"reviewed loader crate {crate_path} has an alternate CalcVBA dependency/feature path"
                )
        dependencies = manifest.get("dependencies")
        calcvba_dependencies = (
            {
                name: specification
                for name, specification in dependencies.items()
                if _targets_calcvba_dependency(name, specification)
            }
            if isinstance(dependencies, dict)
            else {}
        )
        if set(calcvba_dependencies) != set(
            _REVIEWED_LOADER_OXVBA_DEPENDENCIES
        ) or any(
            specification
            != {"git": _REVIEWED_OXVBA_REPO, "rev": _REVIEWED_OXVBA_REV}
            for specification in calcvba_dependencies.values()
        ):
            raise LedgerError(
                f"reviewed loader crate {crate_path} CalcVBA dependency repository/revision set differs"
            )
        if dependencies.get("calcforms-calcvba-adapter") != {
            "path": "../calcforms-calcvba-adapter"
        }:
            raise LedgerError(
                f"reviewed loader crate {crate_path} no longer uses the exact production adapter path dependency"
            )
        source_path = repo_root / crate_path / target["default_source"]
        if not source_path.is_file():
            raise LedgerError(
                f"reviewed loader crate {crate_path} is missing {target['default_source']}"
            )
        if (repo_root / crate_path / "build.rs").exists():
            raise LedgerError(
                f"reviewed loader crate {crate_path} must not use a Cargo build script"
            )

    if _REVIEWED_ADAPTER_CRATE not in members:
        raise LedgerError("root Cargo workspace omits reviewed production adapter crate")
    adapter_manifest_path = repo_root / _REVIEWED_ADAPTER_CRATE / "Cargo.toml"
    adapter_manifest = _load_toml(adapter_manifest_path)
    adapter_package = adapter_manifest.get("package")
    adapter_build_dependencies = adapter_manifest.get("build-dependencies", {})
    if (
        not isinstance(adapter_package, dict)
        or adapter_package.get("name") != "calcforms-calcvba-adapter"
        or "workspace" in adapter_package
        or "autolib" in adapter_package
        or "build" in adapter_package
        or "workspace" in adapter_manifest
        or "lib" in adapter_manifest
        or "features" in adapter_manifest
        or "target" in adapter_manifest
        or not isinstance(adapter_build_dependencies, dict)
        or any(
            _targets_calcvba_dependency(name, specification)
            for name, specification in adapter_build_dependencies.items()
        )
    ):
        raise LedgerError(
            "reviewed production adapter Cargo target/dependency shape differs"
        )
    adapter_dependencies = adapter_manifest.get("dependencies")
    adapter_calcvba_dependencies = (
        {
            name: specification
            for name, specification in adapter_dependencies.items()
            if _targets_calcvba_dependency(name, specification)
        }
        if isinstance(adapter_dependencies, dict)
        else {}
    )
    if set(adapter_calcvba_dependencies) != set(
        _REVIEWED_ADAPTER_OXVBA_DEPENDENCIES
    ) or any(
        specification
        != {"git": _REVIEWED_OXVBA_REPO, "rev": _REVIEWED_OXVBA_REV}
        for specification in adapter_calcvba_dependencies.values()
    ):
        raise LedgerError(
            "reviewed production adapter CalcVBA dependency repository/revision set differs"
        )
    if not (repo_root / _REVIEWED_ADAPTER_CRATE / "src/lib.rs").is_file():
        raise LedgerError("reviewed production adapter is missing its default src/lib.rs")
    if (repo_root / _REVIEWED_ADAPTER_CRATE / "build.rs").exists():
        raise LedgerError("reviewed production adapter must not use a Cargo build script")


def _validate_loader_adapter_runtime(repo_root: Path) -> None:
    """Pin the adapter handoff that consumes each reviewed host session."""

    for relative_path, reviewed_sha256 in _ADAPTER_REVIEWED_TOKEN_SHA256.items():
        source_path = repo_root / relative_path
        try:
            source = source_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            raise LedgerError(
                f"cannot load reviewed production adapter source {relative_path}"
            ) from exc
        tokens = _rust_tokens(source, relative_path)
        actual_sha256 = sha256_bytes(structural_json_bytes(tokens))
        if actual_sha256 != reviewed_sha256:
            raise LedgerError(
                "production adapter reviewed full-source token identity differs"
            )


def _rust_public_method_body(
    tokens: list[tuple[str, str]], method_name: str, source_path: str
) -> list[tuple[str, str]]:
    """Extract one reviewed unconditional public impl method body."""

    starts = [
        index
        for index in range(2, len(tokens) - 1)
        if tokens[index] == ("ident", "fn")
        and tokens[index + 1] == ("ident", method_name)
    ]
    if len(starts) != 1:
        raise LedgerError(
            f"loader source {source_path} must define exactly one {method_name} method"
        )
    start = starts[0]
    if tokens[start - 1] != ("ident", "pub") or tokens[start - 2][1] != "}":
        raise LedgerError(
            f"loader source {source_path} {method_name} must be an unconditional public reviewed method"
        )
    try:
        body_start = next(
            index for index in range(start + 2, len(tokens)) if tokens[index][1] == "{"
        )
    except StopIteration as exc:
        raise LedgerError(
            f"loader source {source_path} has no body for {method_name}"
        ) from exc
    body_end = _rust_matching_delimiter(tokens, body_start, source_path)
    return tokens[body_start + 1 : body_end]


def _validate_loader_host_binding(
    tokens: list[tuple[str, str]], profile_id: str, source_path: str
) -> None:
    """Prove the reviewed inventory reaches the bound host project."""

    expected_source = _LOADER_BUILD_SESSION_PREFIXES.get(profile_id)
    caller = _LOADER_LIVE_CALLERS.get(profile_id)
    if expected_source is None or caller is None:
        raise LedgerError(f"unsupported loader host binding {profile_id!r}")
    values = _rust_values(tokens)
    if any(
        values[index : index + 4] in (
            ["#", "!", "[", "cfg"],
            ["#", "!", "[", "cfg_attr"],
        )
        for index in range(len(values) - 3)
    ):
        raise LedgerError(
            f"loader source {source_path} must not crate-gate the reviewed host with cfg/cfg_attr"
        )
    body = _rust_function_body(tokens, "build_session", source_path)
    expected_prefix = _rust_tokens(expected_source, f"{profile_id} reviewed prefix")
    if body[: len(expected_prefix)] != expected_prefix:
        raise LedgerError(
            f"loader source {source_path} build_session does not preserve the reviewed calcforms_modules-to-bind_program path"
        )
    caller_body = (
        _rust_public_method_body(tokens, caller["name"], source_path)
        if caller["kind"] == "method"
        else _rust_function_body(tokens, caller["name"], source_path)
    )
    expected_caller = _rust_tokens(
        caller["source"], f"{profile_id} reviewed live caller"
    )
    caller_matches = (
        caller_body == expected_caller
        if caller["full_body"]
        else caller_body[: len(expected_caller)] == expected_caller
    )
    if not caller_matches:
        raise LedgerError(
            f"loader source {source_path} does not preserve the reviewed live build_session caller and downstream session use"
        )
    reviewed_token_sha256 = _LOADER_REVIEWED_TOKEN_SHA256.get(profile_id)
    actual_token_sha256 = sha256_bytes(structural_json_bytes(tokens))
    if actual_token_sha256 != reviewed_token_sha256:
        raise LedgerError(
            f"loader source {source_path} reviewed full-source token identity differs"
        )


def _validate_loader_surface_identity(
    surface: dict[str, Any], inventories: dict[str, list[dict[str, str]]]
) -> None:
    """Reconcile loader tuple identity with parsed VBA module identity."""

    modules_by_path = {module["path"]: module for module in surface["modules"]}
    kind_names = {"Class": "class_module", "Procedural": "standard_module"}
    for profile_id, inventory in inventories.items():
        for item in inventory:
            module = modules_by_path.get(item["path"])
            expected_kind = kind_names.get(item["kind"])
            if (
                module is None
                or module.get("name") != item["name"]
                or module.get("kind") != expected_kind
                or module.get("file_stem") != item["name"]
                or module.get("source_header_line_count", 0) != 0
            ):
                raise LedgerError(
                    f"loader profile {profile_id!r} tuple identity differs from parsed VBA module {item!r}"
                )


def _validate_loader_profiles(
    repo_root: Path, policy: dict[str, Any]
) -> dict[str, list[dict[str, str]]]:
    _validate_loader_cargo_targets(repo_root)
    _validate_loader_adapter_runtime(repo_root)
    expected_profiles = [
        ("clean_basproj", "project_manifest", "vba/calcforms/CalcForms.basproj"),
        (
            "headless_runner_forced",
            "manual_calcvba_loader",
            "crates/calcforms-headless-runner/src/lib.rs",
        ),
        (
            "bootstrap_forced",
            "manual_calcvba_loader",
            "crates/calcforms-bootstrap/src/main.rs",
        ),
    ]
    profiles = policy.get("effective_loader_profiles")
    if not isinstance(profiles, list) or any(
        not isinstance(profile, dict) for profile in profiles
    ):
        raise LedgerError("loader policy profiles must be a list of objects")
    actual_profiles = [
        (profile.get("id"), profile.get("kind"), profile.get("source_path"))
        for profile in profiles
    ]
    profile_ids = [profile[0] for profile in actual_profiles]
    if len(profile_ids) != len(set(profile_ids)):
        raise LedgerError("duplicate loader profile id")
    if actual_profiles != expected_profiles:
        raise LedgerError("loader policy identity/kind/source-path set differs")
    clean_path = (repo_root / expected_profiles[0][2]).resolve()
    if repo_root.resolve() not in clean_path.parents or not clean_path.is_file():
        raise LedgerError("clean basproj loader profile has unsafe/missing source")

    expected_helpers = {
        "headless_runner_forced": "module_unit",
        "bootstrap_forced": "unit",
    }
    inventories: dict[str, list[dict[str, str]]] = {}
    for profile in profiles:
        if profile.get("kind") != "manual_calcvba_loader":
            continue
        profile_id = profile.get("id")
        helper = expected_helpers.get(str(profile_id))
        if helper is None:
            raise LedgerError(f"unsupported manual loader profile {profile_id!r}")
        source_path = profile.get("source_path")
        if not isinstance(source_path, str):
            raise LedgerError(f"loader profile {profile_id!r} has no source_path")
        full_path = (repo_root / source_path).resolve()
        if repo_root not in full_path.parents or not full_path.is_file():
            raise LedgerError(f"loader profile {profile_id!r} has unsafe/missing source")
        try:
            source = full_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            raise LedgerError(f"cannot read loader source {source_path}: {exc}") from exc
        tokens = _rust_tokens(source, source_path)
        tuples = (
            _parse_headless_loader_inventory(tokens, source_path)
            if profile_id == "headless_runner_forced"
            else _parse_bootstrap_loader_inventory(tokens, source_path, repo_root)
        )
        actual_names = [item["name"] for item in tuples]
        expected_names = profile.get("modules")
        if actual_names != expected_names:
            raise LedgerError(
                f"loader profile {profile_id!r} module inventory differs from {source_path}"
            )
        if len({name.casefold() for name in actual_names}) != len(actual_names):
            raise LedgerError(f"loader profile {profile_id!r} has duplicate modules")
        for item in tuples:
            suffix = ".cls" if item["kind"] == "Class" else ".bas"
            if (
                re.fullmatch(
                    r"vba/calcforms/[A-Za-z_][A-Za-z0-9_]*\.(?:bas|cls)",
                    item["path"],
                )
                is None
                or Path(item["path"]).stem != item["name"]
                or not item["path"].endswith(suffix)
            ):
                raise LedgerError(
                    f"loader profile {profile_id!r} tuple identity differs: {item!r}"
                )
        _validate_loader_helper(tokens, helper, source_path)
        _validate_loader_host_binding(tokens, str(profile_id), source_path)
        inventories[str(profile_id)] = tuples
    return inventories


def semantic_sha256(value: Any) -> str:
    return sha256_bytes(structural_json_bytes(value))


def _dim(
    status: str,
    basis: str,
    evidence: Iterable[str] = (),
    rule: str | None = None,
) -> dict[str, Any]:
    if status not in DIMENSION_STATUSES:
        raise LedgerError(f"unknown dimension status {status!r}")
    result: dict[str, Any] = {
        "status": status,
        "basis": basis,
        "evidence": list(evidence),
    }
    if rule is not None:
        result["rule"] = rule
    return result


def _dimensions_not_applicable(basis: str) -> dict[str, dict[str, Any]]:
    return {name: _dim("not_applicable", basis) for name in DIMENSION_NAMES}


def _type_id(library_key: str, type_fact: dict[str, Any]) -> str:
    return f"{library_key}|{type_fact['index']}|{type_fact['view']}"


def _type_key_from_target(target: dict[str, Any]) -> tuple[str, int, str]:
    return (target["library_key"], int(target["type_index"]), target["view"])


def _function_contract_id(type_id: str, memid: int) -> str:
    return f"contract:function:{type_id}|memid={memid}"


def _source_ref(path: str, fragment: str) -> str:
    return f"{path}#{fragment}"


def _flag_names(value: dict[str, Any] | None) -> list[str]:
    return list((value or {}).get("names", []))


def _visibility(type_fact: dict[str, Any], functions: list[dict[str, Any]] = []) -> dict[str, Any]:
    type_flags = _flag_names(type_fact["attributes"].get("type_flags"))
    member_flags = sorted(
        {name for function in functions for name in _flag_names(function.get("function_flags"))}
    )
    return {
        "type_flags": type_flags,
        "member_flags": member_flags,
        "hidden": "TYPEFLAG_FHIDDEN" in type_flags or "FUNCFLAG_FHIDDEN" in member_flags,
        "nonbrowsable": "FUNCFLAG_FNONBROWSABLE" in member_flags,
        "restricted": "TYPEFLAG_FRESTRICTED" in type_flags
        or "FUNCFLAG_FRESTRICTED" in member_flags,
    }


def _variable_visibility(
    type_fact: dict[str, Any], variable: dict[str, Any]
) -> dict[str, Any]:
    result = _visibility(type_fact)
    member_flags = _flag_names(variable.get("variable_flags"))
    result["member_flags"] = member_flags
    result["hidden"] = result["hidden"] or "VARFLAG_FHIDDEN" in member_flags
    result["nonbrowsable"] = (
        result["nonbrowsable"] or "VARFLAG_FNONBROWSABLE" in member_flags
    )
    result["restricted"] = (
        result["restricted"] or "VARFLAG_FRESTRICTED" in member_flags
    )
    return result


def _semantic_type(type_fact: dict[str, Any]) -> dict[str, Any]:
    """Retain semantic VT/target identity while excluding presentation/raw HREFs."""

    result: dict[str, Any] = {"kind": type_fact.get("kind")}
    for key in ("vt", "vt_name"):
        if key in type_fact:
            result[key] = type_fact[key]
    target = type_fact.get("target")
    if isinstance(target, dict):
        if "library_key" in target:
            result["target"] = {
                key: target.get(key)
                for key in (
                    "library_key",
                    "type_index",
                    "view",
                    "guid",
                    "name",
                    "typekind",
                    "typekind_name",
                )
            }
        else:
            result["target"] = _semantic_type(target)
    if "element" in type_fact and isinstance(type_fact["element"], dict):
        result["element"] = _semantic_type(type_fact["element"])
    if "bounds" in type_fact:
        result["bounds"] = copy.deepcopy(type_fact["bounds"])
    return result


def _semantic_parameter(parameter: dict[str, Any]) -> dict[str, Any]:
    return {
        "index": parameter["index"],
        "name": parameter.get("name"),
        "name_state": parameter.get("name_state"),
        "flags": copy.deepcopy(parameter.get("parameter_flags")),
        "default": copy.deepcopy(parameter.get("default")),
        "type": _semantic_type(parameter["type"]),
    }


def _semantic_signature(function: dict[str, Any]) -> dict[str, Any]:
    signature = {
        "source_index": function["index"],
        "vtable_offset": function["vtable_offset"],
        "memid": function["memid"],
        "name": function["documentation"]["name"],
        "names": copy.deepcopy(function["names"]),
        "invoke_kind": function["invoke_kind_name"],
        "function_kind": function["function_kind_name"],
        "call_convention": function["call_convention_name"],
        "function_flags": copy.deepcopy(function["function_flags"]),
        "optional_parameter_count": function["optional_parameter_count"],
        "parameters": [_semantic_parameter(item) for item in function["parameters"]],
        "return": {
            "flags": copy.deepcopy(function["return"].get("parameter_flags")),
            "default": copy.deepcopy(function["return"].get("default")),
            "type": _semantic_type(function["return"]["type"]),
        },
        "scode_array": copy.deepcopy(function["scode_array"]),
        "is_default_member": bool(function["is_default_member"]),
        "is_new_enum": bool(function["is_new_enum"]),
    }
    signature["signature_sha256"] = semantic_sha256(signature)
    return signature


def _vardesc_accessors(variable: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Derive the VBA property shape encoded by a VAR_DISPATCH VARDESC.

    A VARDESC has one element type rather than separate property FUNCDESCs.  It
    nevertheless distinguishes read-only properties and supplies the property
    value type.  Retain that derivation explicitly instead of accepting an
    arbitrary same-name Property declaration.
    """

    name = variable["documentation"]["name"]
    memid = int(variable["memid"])
    value_type = _semantic_type(variable["element"]["type"])
    empty_flags = {"names": [], "unknown_bits": 0, "value": 0}
    not_encoded = {"state": "not_encoded"}

    def finish(signature: dict[str, Any]) -> dict[str, Any]:
        signature["signature_sha256"] = semantic_sha256(signature)
        return signature

    accessors = {
        "get": finish(
            {
                "memid": memid,
                "name": name,
                "names": [name],
                "invoke_kind": "VARDESC_PROPERTYGET",
                "function_kind": "VAR_DISPATCH",
                "call_convention": "VARDESC",
                "function_flags": copy.deepcopy(empty_flags),
                "optional_parameter_count": 0,
                "parameters": [],
                "return": {
                    "flags": copy.deepcopy(empty_flags),
                    "default": copy.deepcopy(not_encoded),
                    "type": copy.deepcopy(value_type),
                },
                "scode_array": [],
                "is_default_member": memid == 0
                or "VARFLAG_FDEFAULTBIND" in _flag_names(variable.get("variable_flags")),
                "is_new_enum": memid == -4,
                "derivation": "VAR_DISPATCH element type",
            }
        )
    }
    if "VARFLAG_FREADONLY" not in _flag_names(variable.get("variable_flags")):
        object_like = value_type.get("vt_name") in {"VT_DISPATCH", "VT_UNKNOWN"}
        target = value_type.get("target")
        if isinstance(target, dict) and target.get("typekind_name") in {
            "TKIND_COCLASS",
            "TKIND_DISPATCH",
            "TKIND_INTERFACE",
        }:
            object_like = True
        accessor = "putref" if object_like else "put"
        accessors[accessor] = finish(
            {
                "memid": memid,
                "name": name,
                "names": [name],
                "invoke_kind": (
                    "VARDESC_PROPERTYPUTREF" if object_like else "VARDESC_PROPERTYPUT"
                ),
                "function_kind": "VAR_DISPATCH",
                "call_convention": "VARDESC",
                "function_flags": copy.deepcopy(empty_flags),
                "optional_parameter_count": 0,
                "parameters": [
                    {
                        "index": 0,
                        "name": "Value",
                        "name_state": "not_reported_by_VARDESC",
                        "flags": {
                            "names": ["PARAMFLAG_FIN"],
                            "unknown_bits": 0,
                            "value": 1,
                        },
                        "default": copy.deepcopy(not_encoded),
                        "type": copy.deepcopy(value_type),
                    }
                ],
                "return": {
                    "flags": copy.deepcopy(empty_flags),
                    "default": copy.deepcopy(not_encoded),
                    "type": {"kind": "scalar", "vt": 24, "vt_name": "VT_VOID"},
                },
                "scode_array": [],
                "is_default_member": memid == 0
                or "VARFLAG_FDEFAULTBIND" in _flag_names(variable.get("variable_flags")),
                "is_new_enum": memid == -4,
                "derivation": "Writable VAR_DISPATCH element type and VARFLAG_FREADONLY absence",
            }
        )
    return accessors


ACCESSOR_NAMES = {
    "INVOKE_FUNC": "func",
    "INVOKE_PROPERTYGET": "get",
    "INVOKE_PROPERTYPUT": "put",
    "INVOKE_PROPERTYPUTREF": "putref",
}


def _group_functions(
    library_key: str, type_fact: dict[str, Any]
) -> list[dict[str, Any]]:
    grouped: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for function in type_fact["functions"]:
        grouped[int(function["memid"])].append(function)
    result: list[dict[str, Any]] = []
    for memid, functions in sorted(
        grouped.items(), key=lambda item: min(row["index"] for row in item[1])
    ):
        exact_names = {
            (row["documentation"]["name"], row["names"][0]) for row in functions
        }
        if len(exact_names) != 1:
            raise LedgerError(
                f"function group name disagreement at {_type_id(library_key, type_fact)} memid {memid}"
            )
        documented_name, names_zero = next(iter(exact_names))
        if documented_name != names_zero:
            raise LedgerError(
                f"documentation/GetNames disagreement at {_type_id(library_key, type_fact)} memid {memid}"
            )
        accessors: dict[str, dict[str, Any]] = {}
        source_indices: list[int] = []
        for function in sorted(functions, key=lambda item: item["index"]):
            accessor = ACCESSOR_NAMES.get(function["invoke_kind_name"])
            if accessor is None:
                raise LedgerError(f"unknown invoke kind {function['invoke_kind_name']!r}")
            if accessor in accessors:
                raise LedgerError(
                    f"duplicate {accessor} at {_type_id(library_key, type_fact)} memid {memid}"
                )
            accessors[accessor] = _semantic_signature(function)
            source_indices.append(function["index"])
        result.append(
            {
                "memid": memid,
                "name": documented_name,
                "functions": functions,
                "source_indices": source_indices,
                "accessors": accessors,
                "default_member": any(bool(row["is_default_member"]) for row in functions),
                "new_enum": any(bool(row["is_new_enum"]) for row in functions),
            }
        )
    return result


def _source_type_name(
    display: str, canonical_aliases: dict[str, str] | None = None
) -> str:
    result = display.rstrip("*")
    scalar_aliases = {
        "void": "",
        "integer32": "Long",
        "unsignedinteger32": "Long",
        "unsignedlong": "Long",
        "iunknown": "Object",
        "idispatch": "Object",
    }
    aliases = canonical_aliases or {}
    seen: set[str] = set()
    while result:
        folded = result.casefold()
        if folded in seen:
            raise LedgerError(f"canonical type-alias cycle at {result!r}")
        seen.add(folded)
        if folded in scalar_aliases:
            result = scalar_aliases[folded]
            continue
        replacement = aliases.get(folded)
        if replacement is None:
            break
        result = replacement.rstrip("*")
    return result


def _source_parameter_type(
    display: str, canonical_aliases: dict[str, str] | None = None
) -> tuple[str, bool]:
    """Lower a canonical type while retaining the VBA array dimension."""

    lowered = _source_type_name(display, canonical_aliases)
    is_array = lowered.endswith("()")
    return lowered.removesuffix("()"), is_array


def _parameter_passing_from_flags(
    parameter: dict[str, Any], *, is_array: bool, is_param_array: bool
) -> str | None:
    """Return the VBA passing mode encoded by COM parameter metadata.

    VBA arrays cannot be passed ByVal, and a COM [out] parameter requires a
    reference.  A plain [in] parameter lowers to ByVal.  Anything else is kept
    unresolved so a weak metadata inference can never make a row compatible.
    """

    if is_array or is_param_array:
        return "byref"
    names = set(_flag_names(parameter.get("flags")))
    if "PARAMFLAG_FOUT" in names and "PARAMFLAG_FRETVAL" not in names:
        return "byref"
    if "PARAMFLAG_FIN" in names and "PARAMFLAG_FOUT" not in names:
        return "byval"
    return None


def _normalize_default_literal(
    value: Any, *, encoded_string_value: bool = False
) -> str | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return "true" if value else "false"
    text = str(value)
    if encoded_string_value:
        return "string:" + text
    stripped = text.strip()
    if len(stripped) >= 2 and stripped[0] == stripped[-1] == '"':
        return "string:" + stripped[1:-1].replace('""', '"')
    return re.sub(r"\s+", " ", stripped).casefold()


def _documented_default_literals(
    value: Any, *, encoded_string_value: bool = False
) -> set[str | None]:
    """Return exact documented spellings plus an explicitly shown value.

    Microsoft documentation commonly renders a symbolic default as
    ``vbModal (1)``.  The VBA declaration can spell that same documented value
    as either ``vbModal`` or ``1``; no broader expression evaluation is done.
    """

    normalized = _normalize_default_literal(
        value, encoded_string_value=encoded_string_value
    )
    if normalized is None:
        return {None}
    alternatives: set[str | None] = {normalized}
    if normalized.startswith("string:"):
        return alternatives
    match = re.fullmatch(r"(.+?)\s*\(([+-]?(?:&h[0-9a-f]+|&o[0-7]+|[0-9]+))\)", normalized)
    if match:
        alternatives.update({match.group(1).strip(), match.group(2)})
    return alternatives


def _compare_parameter_default(
    actual: Any, expected: dict[str, Any] | None
) -> tuple[bool | None, str]:
    """Compare an extracted default; ``None`` means canonical metadata is weak."""

    expected = expected or {"state": "not_encoded"}
    state = expected.get("state")
    actual_literal = _normalize_default_literal(actual)
    if state == "not_encoded":
        return actual_literal is None, "no encoded default"
    if state == "documented":
        values = _documented_default_literals(expected.get("value"))
        return actual_literal in values, "documented default"
    if "value" in expected:
        encoded_string = expected.get("variant_type") in {"VT_BSTR", 8}
        return (
            actual_literal
            in _documented_default_literals(
                expected.get("value"), encoded_string_value=encoded_string
            ),
            f"{state or 'encoded'} default",
        )
    return None, f"unsupported canonical default state {state!r}"


def _canonical_source_aliases(
    type_lookup: dict[tuple[str, int, str], dict[str, Any]]
) -> dict[str, str]:
    aliases: dict[str, str] = {}
    for type_fact in type_lookup.values():
        if type_fact["attributes"]["typekind_name"] != "TKIND_ALIAS":
            continue
        name = type_fact["documentation"]["name"]
        lowered = _display_from_semantic_type(_semantic_type(type_fact["alias_type"]))
        key = name.casefold()
        previous = aliases.get(key)
        if previous is not None and _source_type_name(previous) != _source_type_name(
            lowered
        ):
            raise LedgerError(
                f"conflicting canonical source lowering for alias {name!r}: "
                f"{previous!r} versus {lowered!r}"
            )
        aliases[key] = lowered
    # Resolve every entry now so cycles/conflicts fail at generation time and
    # callers do not need to know whether an alias points at another alias.
    return {key: _source_type_name(value, aliases) for key, value in aliases.items()}


def _signature_comparison(
    declaration: dict[str, Any],
    signature: dict[str, Any],
    expected_kind: str,
    canonical_aliases: dict[str, str] | None = None,
) -> dict[str, Any]:
    mismatches: list[str] = []
    unresolved: list[str] = []
    if declaration["kind"] != expected_kind:
        mismatches.append(f"kind {declaration['kind']} != {expected_kind}")
    expected_parameters = signature["parameters"]
    actual_parameters = declaration.get("parameters", [])
    if len(actual_parameters) != len(expected_parameters):
        mismatches.append(
            f"parameter count {len(actual_parameters)} != {len(expected_parameters)}"
        )
    else:
        for actual, expected in zip(actual_parameters, expected_parameters):
            expected_type, expected_array = _source_parameter_type(
                _display_from_semantic_type(expected["type"]), canonical_aliases
            )
            if actual["type"].casefold() != expected_type.casefold():
                mismatches.append(
                    f"parameter {expected['index']} type {actual['type']} != {expected_type}"
                )
            if bool(actual.get("array")) != expected_array:
                mismatches.append(
                    f"parameter {expected['index']} array {actual.get('array')} != {expected_array}"
                )
            expected_param_array = (
                signature.get("optional_parameter_count") == -1
                and expected["index"] == len(expected_parameters) - 1
            )
            if bool(actual.get("param_array")) != expected_param_array:
                mismatches.append(
                    f"parameter {expected['index']} ParamArray {actual.get('param_array')} != {expected_param_array}"
                )
            expected_optional = "PARAMFLAG_FOPT" in _flag_names(expected.get("flags"))
            if bool(actual["optional"]) != expected_optional:
                mismatches.append(
                    f"parameter {expected['index']} optional {actual['optional']} != {expected_optional}"
                )
            expected_name = expected.get("name")
            if (
                expected.get("name_state") != "reported_by_GetNames"
                or not expected_name
            ):
                unresolved.append(
                    f"parameter {expected['index']} name is not reported by canonical metadata"
                )
            elif actual["name"].casefold() != str(expected_name).casefold():
                mismatches.append(
                    f"parameter {expected['index']} name {actual['name']} != {expected_name}"
                )
            expected_passing = _parameter_passing_from_flags(
                expected,
                is_array=expected_array,
                is_param_array=expected_param_array,
            )
            if expected_passing is None:
                unresolved.append(
                    f"parameter {expected['index']} passing mode is not encoded unambiguously"
                )
            elif actual.get("passing") != expected_passing:
                mismatches.append(
                    f"parameter {expected['index']} passing {actual.get('passing')} != {expected_passing}"
                )
            default_matches, default_basis = _compare_parameter_default(
                actual.get("default"), expected.get("default")
            )
            if default_matches is None:
                unresolved.append(f"parameter {expected['index']} {default_basis}")
            elif not default_matches:
                mismatches.append(
                    f"parameter {expected['index']} default {actual.get('default')!r} != {default_basis}"
                )
    expected_return = _source_type_name(
        _display_from_semantic_type(signature["return"]["type"]), canonical_aliases
    )
    actual_return = declaration.get("return_type") or ""
    if expected_kind in {"function", "property_get"}:
        if actual_return.casefold() != expected_return.casefold():
            mismatches.append(f"return {actual_return} != {expected_return}")
    status = (
        "mismatch"
        if mismatches
        else "unresolved_source_lowering"
        if unresolved
        else "compatible_source_shape"
    )
    return {
        "status": status,
        "mismatches": mismatches,
        "unresolved": unresolved,
        "non_claim": "Only unambiguous COM parameter flags and array metadata are lowered; weak cases remain unresolved.",
    }


def _display_from_semantic_type(type_fact: dict[str, Any]) -> str:
    kind = type_fact.get("kind")
    if kind == "userdefined":
        target = type_fact.get("target", {})
        return str(target.get("name", "Variant"))
    if kind == "pointer":
        return _display_from_semantic_type(type_fact["target"]) + "*"
    if kind in {"safearray", "carray", "c_array"}:
        return _display_from_semantic_type(type_fact["element"]) + "()"
    vt_name = type_fact.get("vt_name")
    scalar_names = {
        "VT_VOID": "Void",
        "VT_I2": "Integer",
        "VT_I4": "Long",
        "VT_INT": "Integer32",
        "VT_UINT": "UnsignedInteger32",
        "VT_UI4": "UnsignedLong",
        "VT_R4": "Single",
        "VT_R8": "Double",
        "VT_CY": "Currency",
        "VT_BSTR": "String",
        "VT_BOOL": "Boolean",
        "VT_VARIANT": "Variant",
        "VT_DISPATCH": "Object",
        "VT_UNKNOWN": "Object",
    }
    return scalar_names.get(str(vt_name), str(vt_name or "Variant"))


def _contains_native_void_pointer(type_fact: dict[str, Any]) -> bool:
    if type_fact.get("kind") == "pointer":
        target = type_fact.get("target")
        return isinstance(target, dict) and (
            target.get("vt_name") == "VT_VOID"
            or _contains_native_void_pointer(target)
        )
    for key in ("target", "element"):
        nested = type_fact.get(key)
        if isinstance(nested, dict) and _contains_native_void_pointer(nested):
            return True
    return False


def _group_has_native_void_pointer(group: dict[str, Any]) -> bool:
    return any(
        _contains_native_void_pointer(parameter["type"])
        for signature in group["accessors"].values()
        for parameter in signature["parameters"]
    )


def _source_declaration_id(module_index: int, declaration_index: int) -> str:
    return f"source:{module_index:03d}:{declaration_index:04d}"


def _source_member_id(
    module_index: int, declaration_index: int, member_index: int
) -> str:
    return f"source:{module_index:03d}:{declaration_index:04d}:member:{member_index:04d}"


def _parse_vba_integer(value: str | None) -> int | None:
    if value is None:
        return None
    token = value.strip()
    sign = 1
    if token.startswith("-"):
        sign = -1
        token = token[1:].strip()
    elif token.startswith("+"):
        token = token[1:].strip()
    token = token.rstrip("&%^").strip()
    try:
        if token.lower().startswith("&h"):
            parsed = int(token[2:], 16)
            if sign == 1 and parsed > 0x7FFFFFFF and parsed <= 0xFFFFFFFF:
                parsed -= 0x100000000
            return sign * parsed
        if token.lower().startswith("&o"):
            return sign * int(token[2:], 8)
        return sign * int(token, 10)
    except ValueError:
        return None


def _index_source(
    surface: dict[str, Any], policy: dict[str, Any]
) -> dict[str, Any]:
    policy_profiles = policy["effective_loader_profiles"]
    manual_profiles: dict[str, dict[str, Any]] = {
        profile["id"]: {
            "module_names": {
                name.casefold() for name in profile.get("modules", [])
            },
            "source_path": profile["source_path"],
        }
        for profile in policy_profiles
        if profile["kind"] == "manual_calcvba_loader"
    }
    clean_source_path = next(
        (
            profile["source_path"]
            for profile in policy_profiles
            if profile["id"] == "clean_basproj"
        ),
        "vba/calcforms/CalcForms.basproj",
    )
    modules: dict[str, dict[str, Any]] = {}
    declarations_by_owner_name: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    declaration_by_id: dict[str, dict[str, Any]] = {}
    nested_member_by_id: dict[str, dict[str, Any]] = {}
    for module_index, module in enumerate(surface["modules"]):
        module_copy = copy.deepcopy(module)
        source_attributes = {
            name.casefold(): value
            for name, value in module.get("attributes", {}).items()
        }
        manual_profile_evaluations = {
            profile_id: {
                "listed": True,
                "effective_exposed": (
                    not module.get("option_private_module", False)
                    and (
                        module.get("kind") == "standard_module"
                        or source_attributes.get("vb_exposed", True)
                    )
                ),
                "effective_creatable": source_attributes.get(
                    "vb_creatable", True
                ),
                "source_path": profile["source_path"],
                "basis": (
                    "explicit source Attribute overrides forced ModuleUnit attributes; "
                    "Option Private Module prevents cross-project exposure"
                ),
            }
            for profile_id, profile in manual_profiles.items()
            if module["name"].casefold() in profile["module_names"]
        }
        profiles = ["clean_basproj"] if module["project_declared_exposed"] else []
        profiles.extend(
            profile_id
            for profile_id, evaluation in manual_profile_evaluations.items()
            if evaluation["effective_exposed"]
        )
        module_copy["effective_loader_profiles"] = profiles
        module_copy["manual_loader_profile_evaluations"] = (
            manual_profile_evaluations
        )
        module_copy["effective_creatable_by_profile"] = {
            profile_id: (
                bool(module.get("project_declared_creatable"))
                if profile_id == "clean_basproj"
                else manual_profile_evaluations[profile_id][
                    "effective_creatable"
                ]
            )
            for profile_id in profiles
        }
        module_copy["effective_loader_profile_evidence"] = {
            profile_id: (
                f"{clean_source_path}#effective-loader-profile={profile_id}"
                if profile_id == "clean_basproj"
                else (
                    f"{manual_profiles[profile_id]['source_path']}"
                    f"#effective-loader-profile={profile_id}"
                )
            )
            for profile_id in profiles
        }
        module_copy["module_index"] = module_index
        modules[module["name"].casefold()] = module_copy
        for declaration_index, declaration in enumerate(module["declarations"]):
            declaration_copy = copy.deepcopy(declaration)
            declaration_id = _source_declaration_id(module_index, declaration_index)
            declaration_copy["source_declaration_id"] = declaration_id
            declaration_copy["owner"] = module["name"]
            declaration_copy["owner_profiles"] = profiles
            declarations_by_owner_name[
                (module["name"].casefold(), declaration["name"].casefold())
            ].append(declaration_copy)
            declaration_by_id[declaration_id] = declaration_copy
            previous_enum_value: int | None = -1
            for member_index, member in enumerate(declaration.get("members", [])):
                member_copy = copy.deepcopy(member)
                member_id = _source_member_id(
                    module_index, declaration_index, member_index
                )
                member_copy.update(
                    {
                        "source_member_id": member_id,
                        "source_declaration_id": declaration_id,
                        "container": declaration["name"],
                        "owner": module["name"],
                    }
                )
                if declaration["kind"] == "enum":
                    explicit_value = _parse_vba_integer(member.get("value"))
                    if explicit_value is None and member.get("value") is None:
                        explicit_value = (
                            previous_enum_value + 1
                            if previous_enum_value is not None
                            else None
                        )
                    member_copy["resolved_value"] = explicit_value
                    # An unresolved explicit expression breaks the implicit
                    # sequence until a later explicit numeric value restores it.
                    previous_enum_value = explicit_value
                nested_member_by_id[member_id] = member_copy
    return {
        "modules": modules,
        "declarations_by_owner_name": declarations_by_owner_name,
        "declaration_by_id": declaration_by_id,
        "nested_member_by_id": nested_member_by_id,
    }


def _actual_owner(
    expected_owner: str, source_index: dict[str, Any], policy: dict[str, Any]
) -> tuple[dict[str, Any] | None, bool]:
    module = source_index["modules"].get(expected_owner.casefold())
    if module is not None:
        return module, False
    alias_name = policy["canonical_module_aliases"].get(expected_owner)
    if alias_name is not None:
        return source_index["modules"].get(alias_name.casefold()), True
    return None, False


def _class_type_identity_comparison(
    type_fact: dict[str, Any], module: dict[str, Any] | None
) -> dict[str, Any]:
    type_kind = type_fact["attributes"]["typekind_name"]
    expected_creatable = (
        type_kind == "TKIND_COCLASS"
        and "TYPEFLAG_FCANCREATE"
        in _flag_names(type_fact["attributes"].get("type_flags"))
    )
    mismatches: list[str] = []
    actual_creatable_by_profile: dict[str, bool] = {}
    creatability_mismatch_profiles: list[str] = []
    profile_evidence: dict[str, str] = {}
    mismatch_evidence: list[str] = []
    if module is not None and module.get("kind") != "class_module":
        mismatches.append(
            f"source module kind {module.get('kind')!r} != 'class_module'"
        )
    if module is not None and module.get("kind") == "class_module":
        profiles = module.get("effective_loader_profiles")
        source_creatable = module.get("effective_creatable_by_profile")
        source_evidence = module.get("effective_loader_profile_evidence")
        if (
            not isinstance(profiles, list)
            or not isinstance(source_creatable, dict)
            or list(source_creatable) != profiles
            or any(type(value) is not bool for value in source_creatable.values())
            or not isinstance(source_evidence, dict)
            or list(source_evidence) != profiles
            or not all(
                isinstance(value, str) and value
                for value in source_evidence.values()
            )
        ):
            mismatches.append(
                "effective loader-profile creatability evidence is missing or malformed"
            )
        else:
            actual_creatable_by_profile = copy.deepcopy(source_creatable)
            profile_evidence = copy.deepcopy(source_evidence)
            creatability_mismatch_profiles = [
                profile_id
                for profile_id in profiles
                if source_creatable[profile_id] != expected_creatable
            ]
            mismatch_evidence = [
                source_evidence[profile_id]
                for profile_id in creatability_mismatch_profiles
            ]
            if creatability_mismatch_profiles:
                mismatches.append(
                    "effective VB_Creatable differs from canonical "
                    "TYPEFLAG_FCANCREATE in loader profiles: "
                    + ", ".join(creatability_mismatch_profiles)
                )
    return {
        "expected_source_kind": "class_module",
        "expected_creatable": expected_creatable,
        "actual_creatable_by_profile": actual_creatable_by_profile,
        "creatability_mismatch_profiles": creatability_mismatch_profiles,
        "profile_evidence": profile_evidence,
        "mismatch_evidence": mismatch_evidence,
        "mismatches": mismatches,
    }


def _global_binding_match(
    binding_name: str, source_index: dict[str, Any]
) -> tuple[list[dict[str, Any]], dict[str, Any] | None]:
    candidates = [
        declaration
        for declaration in source_index["declaration_by_id"].values()
        if declaration.get("kind") == "variable"
        and declaration.get("name", "").casefold() == binding_name.casefold()
        and source_index["modules"]
        .get(declaration.get("owner", "").casefold(), {})
        .get("kind")
        == "standard_module"
    ]
    compatible = [
        declaration
        for declaration in candidates
        if declaration.get("type", "").casefold() == binding_name.casefold()
        and not declaration.get("as_new")
        and not declaration.get("array")
    ]
    matched = compatible[0] if len(candidates) == 1 and len(compatible) == 1 else None
    return candidates, matched


def _member_expected_kind(accessor: str, signature: dict[str, Any]) -> str:
    if accessor == "get":
        return "property_get"
    if accessor == "put":
        return "property_let"
    if accessor == "putref":
        return "property_set"
    return (
        "sub"
        if _source_type_name(_display_from_semantic_type(signature["return"]["type"]))
        == ""
        else "function"
    )


def _match_accessors(
    owner_name: str,
    member_name: str,
    accessors: dict[str, dict[str, Any]],
    source_index: dict[str, Any],
    policy: dict[str, Any],
    used_declarations: set[str],
    canonical_aliases: dict[str, str] | None = None,
    event: bool = False,
) -> dict[str, Any]:
    module, alias = _actual_owner(owner_name, source_index, policy)
    result: dict[str, Any] = {
        "expected_owner": owner_name,
        "actual_owner": module["name"] if module else None,
        "owner_alias": alias,
        "expected_owner_kind": "class_module",
        "actual_owner_kind": module.get("kind") if module else None,
        "owner_kind_compatible": module is None or module.get("kind") == "class_module",
        "owner_profiles": module["effective_loader_profiles"] if module else [],
        "accessors": {},
    }
    if module is None:
        for accessor in accessors:
            result["accessors"][accessor] = {
                "status": "missing",
                "expected_kind": (
                    "event"
                    if event and accessor == "func"
                    else _member_expected_kind(accessor, accessors[accessor])
                ),
                "source_declaration": None,
            }
        return result

    candidates = source_index["declarations_by_owner_name"].get(
        (module["name"].casefold(), member_name.casefold()), []
    )
    for accessor, signature in accessors.items():
        expected_kind = "event" if event and accessor == "func" else _member_expected_kind(accessor, signature)
        kind_candidates = [
            item
            for item in candidates
            if item["kind"] == expected_kind
            and item["source_declaration_id"] not in used_declarations
        ]
        candidate = kind_candidates[0] if kind_candidates else None
        if candidate is None:
            result["accessors"][accessor] = {
                "status": "missing",
                "expected_kind": expected_kind,
                "source_declaration": None,
                "same_name_wrong_kinds": sorted(
                    {
                        item["kind"]
                        for item in candidates
                        if item["source_declaration_id"] not in used_declarations
                    }
                ),
            }
            continue
        used_declarations.add(candidate["source_declaration_id"])
        comparison = _signature_comparison(
            candidate, signature, expected_kind, canonical_aliases
        )
        result["accessors"][accessor] = {
            "status": comparison["status"],
            "expected_kind": expected_kind,
            "source_declaration": candidate,
            "signature_comparison": comparison,
        }
    return result


def _skipped_accessor_match(
    owner_name: str,
    accessors: dict[str, dict[str, Any]],
    source_index: dict[str, Any],
    policy: dict[str, Any],
    reason: str,
) -> dict[str, Any]:
    module, alias = _actual_owner(owner_name, source_index, policy)
    return {
        "expected_owner": owner_name,
        "actual_owner": module["name"] if module else None,
        "owner_alias": alias,
        "expected_owner_kind": "class_module",
        "actual_owner_kind": module.get("kind") if module else None,
        "owner_kind_compatible": module is None or module.get("kind") == "class_module",
        "owner_profiles": module["effective_loader_profiles"] if module else [],
        "accessors": {},
        "comparison_skipped": reason,
        "canonical_accessors": sorted(accessors),
        "non_claim": "No source declaration was consumed by a non-facade obligation.",
    }


def _accessor_dimension(
    accessor: str, match: dict[str, Any], restricted: bool
) -> dict[str, Any]:
    if restricted:
        return _dim(
            "excluded_authoritative",
            "The exact FUNCDESC is FUNCFLAG_FRESTRICTED and remains in the contract layer.",
            rule="restricted",
        )
    if accessor not in match["accessors"]:
        return _dim("not_applicable", f"The canonical contract has no {accessor} accessor.")
    actual = match["accessors"][accessor]
    if actual["status"] == "missing":
        return _dim("missing", f"No public CalcForms {actual['expected_kind']} declaration was found.")
    source_id = actual["source_declaration"]["source_declaration_id"]
    if actual["status"] != "compatible_source_shape":
        basis = (
            "A same-name public declaration exists but its extracted signature is incompatible."
            if actual["status"] == "mismatch"
            else "A same-name public declaration exists, but canonical metadata cannot lower its complete VBA signature unambiguously."
        )
        return _dim(
            "partial",
            basis,
            [source_id],
        )
    if match["owner_alias"]:
        return _dim(
            "partial",
            "The declaration shape is compatible only through an explicit wrong-name module alias.",
            [source_id],
        )
    if not match.get("owner_kind_compatible", True):
        return _dim(
            "partial",
            f"A same-name {match.get('actual_owner_kind')} owns the declaration, but the canonical object/interface facade requires a class module.",
            [source_id],
        )
    if "clean_basproj" not in match["owner_profiles"]:
        manual_profiles = [
            profile
            for profile in match["owner_profiles"]
            if profile != "clean_basproj"
        ]
        return _dim(
            "partial",
            (
                "The declaration is compatible but its class is not exposed by the clean basproj path; validated manual-loader profiles expose it."
                if manual_profiles
                else "The declaration is compatible but its class is not exposed by any effective loader profile."
            ),
            [source_id],
        )
    return _dim(
        "implemented_unverified",
        "A compatible source declaration is exposed, but exhaustive compile/bind and runtime behavior are not yet proven.",
        [source_id],
    )


def _member_attribute(
    declaration: dict[str, Any], attribute_name: str
) -> tuple[bool, Any]:
    for name, value in declaration.get("member_attributes", {}).items():
        if name.casefold() == attribute_name.casefold():
            return True, value
    return False, None


def _matched_declarations(match: dict[str, Any]) -> list[dict[str, Any]]:
    declarations: dict[str, dict[str, Any]] = {}
    for value in match.get("accessors", {}).values():
        declaration = value.get("source_declaration")
        if declaration is not None:
            declarations[declaration["source_declaration_id"]] = declaration
    return [declarations[key] for key in sorted(declarations)]


def _default_binding_dimension(
    group: dict[str, Any], match: dict[str, Any]
) -> dict[str, Any]:
    declarations = _matched_declarations(match)
    attributes = [
        (declaration, value)
        for declaration in declarations
        for found, value in [_member_attribute(declaration, "VB_UserMemId")]
        if found
    ]
    required = bool(group.get("new_enum") or group.get("default_member"))
    canonical_memid = group.get("memid")
    expected_memid: int | None = (
        -4
        if group.get("new_enum")
        else 0
        if group.get("default_member")
        else int(canonical_memid)
        if canonical_memid is not None
        else None
    )
    evidence = [declaration["source_declaration_id"] for declaration, _ in attributes]

    extra_inline_defaults = [
        declaration["source_declaration_id"]
        for declaration in declarations
        if declaration.get("default_member") and not group.get("default_member")
    ]
    if extra_inline_defaults:
        return _dim(
            "partial",
            "Source declares an inline Default member that conflicts with the canonical nondefault identity.",
            extra_inline_defaults,
        )

    if not attributes:
        if required:
            return _dim(
                "missing",
                f"Canonical identity requires VB_UserMemId={expected_memid}, but no source attribute exists.",
            )
        return _dim(
            "not_applicable",
            "The ordinary canonical member has no explicit source VB_UserMemId identity to compare.",
        )
    if expected_memid is None:
        return _dim(
            "partial",
            "Source metadata declares VB_UserMemId, but this documentation-only contract has no authoritative numeric member identity.",
            evidence,
        )

    wrong_values = [
        value
        for _, value in attributes
        if type(value) is not int or value != expected_memid
    ]
    if wrong_values:
        return _dim(
            "partial",
            f"Source VB_UserMemId value(s) {wrong_values!r} conflict with canonical memid {expected_memid}.",
            evidence,
        )
    if (
        group.get("new_enum")
        or not group.get("default_member")
        or expected_memid != 0
    ):
        return _dim(
            "partial",
            (
                f"Source metadata equals canonical VB_UserMemId={expected_memid}, "
                f"but pinned CalcVBA {_REVIEWED_OXVBA_REV} recognizes only "
                "VB_UserMemId=0 as a default-member marker and does not preserve "
                "arbitrary DISPIDs or _NewEnum=-4."
            ),
            evidence
            + [
                "Cargo.toml#workspace.metadata.calcforms.calcvba_baseline",
            ],
        )
    return _dim(
        "implemented_unverified",
        (
            "Every explicit source member identity is VB_UserMemId=0, the "
            f"default-member marker recognized by pinned CalcVBA {_REVIEWED_OXVBA_REV}; "
            "bind-corpus proof remains pending."
        ),
        evidence
        + [
            "Cargo.toml#workspace.metadata.calcforms.calcvba_baseline",
        ],
    )


def _surface_dimensions(
    group: dict[str, Any],
    match: dict[str, Any],
    restricted: bool,
    persistence_ref: str | None,
) -> dict[str, Any]:
    dimensions = _dimensions_not_applicable("This dimension does not apply to this row kind/accessor.")
    dimensions["type_or_declaration"] = _dim(
        "verified",
        "The exact declaration contract is present in the pinned FM20 fact pack.",
        [group["contract_row_id"]],
    )
    if restricted:
        for name in ("bind", "method", "get", "put", "putref", "default_binding"):
            dimensions[name] = _dim(
                "excluded_authoritative",
                "The exact member is FUNCFLAG_FRESTRICTED; it remains visible as metadata but is excluded from the public facade.",
                [group["contract_row_id"]],
                rule="restricted",
            )
        return dimensions

    for accessor, dimension_name in (
        ("func", "method"),
        ("get", "get"),
        ("put", "put"),
        ("putref", "putref"),
    ):
        dimensions[dimension_name] = _accessor_dimension(accessor, match, False)
    applicable = [
        dimensions[name]
        for name in ("method", "get", "put", "putref")
        if dimensions[name]["status"] != "not_applicable"
    ]
    statuses = {item["status"] for item in applicable}
    if not applicable or statuses == {"missing"}:
        dimensions["bind"] = _dim("missing", "No required accessor has a public CalcForms declaration.")
    elif statuses <= {"implemented_unverified"}:
        dimensions["bind"] = _dim(
            "implemented_unverified",
            "Every required accessor has a compatible exposed declaration; exhaustive bind tests remain absent.",
            [
                item
                for value in match["accessors"].values()
                if value.get("source_declaration")
                for item in [value["source_declaration"]["source_declaration_id"]]
            ],
        )
    else:
        dimensions["bind"] = _dim(
            "partial",
            "At least one required accessor is missing, mismatched, alias-only, or not clean-path exposed.",
        )

    dimensions["default_binding"] = _default_binding_dimension(group, match)

    dimensions["error_coercion"] = _dim(
        "missing",
        "No row-specific error/coercion oracle and semantic corpus are attached yet.",
    )
    dimensions["render"] = _dim(
        "partial",
        "Rendering applicability/effect is not yet classified and verified for this callable row.",
    )
    dimensions["persistence"] = (
        _dim(
            "missing",
            "An exact file-format property/family contract exists, but no CalcForms round-trip implementation proof is attached.",
            [persistence_ref],
        )
        if persistence_ref
        else _dim(
            "partial",
            "Persistence applicability has not yet been authoritatively classified for this callable row.",
        )
    )
    dimensions["oracle"] = _dim("missing", "No decisive row-level runtime oracle evidence is attached.")
    dimensions["tests"] = _dim("missing", "No decisive row-level conformance test is attached.")
    return dimensions


def _abi_adapter_dimensions(group: dict[str, Any]) -> dict[str, Any]:
    dimensions = _dimensions_not_applicable(
        "This dimension does not apply to the exact non-dispatch ABI adapter row."
    )
    dimensions["type_or_declaration"] = _dim(
        "verified",
        "The exact non-dispatch FUNCDESC group is retained from the pinned typelib.",
        [group["contract_row_id"]],
    )
    dimensions["bind"] = _dim(
        "missing",
        "No explicit CalcForms non-dispatch ABI adapter and bind evidence is attached.",
    )
    for accessor, dimension_name in (
        ("func", "method"),
        ("get", "get"),
        ("put", "put"),
        ("putref", "putref"),
    ):
        if accessor in group["accessors"]:
            dimensions[dimension_name] = _dim(
                "missing",
                "The raw HRESULT/out-parameter FUNCDESC requires an explicit ABI adapter; no VBA-source-shape equivalence is inferred.",
            )
    if group["new_enum"] or group["default_member"]:
        expected = -4 if group["new_enum"] else 0
        dimensions["default_binding"] = _dim(
            "missing",
            f"The ABI adapter has no proof for canonical default binding memid {expected}.",
        )
    dimensions["error_coercion"] = _dim(
        "missing",
        "HRESULT success/failure and special result semantics have no decisive adapter proof.",
    )
    dimensions["oracle"] = _dim(
        "missing", "No decisive native ABI oracle is attached for this adapter row."
    )
    dimensions["tests"] = _dim(
        "missing", "No decisive ABI adapter conformance test is attached."
    )
    return dimensions


def _native_pointer_adapter_dimensions(group: dict[str, Any]) -> dict[str, Any]:
    dimensions = _dimensions_not_applicable(
        "This dimension does not apply until the native pointer is explicitly lowered."
    )
    dimensions["type_or_declaration"] = _dim(
        "verified",
        "The exact dispatch FUNCDESC, including its native pointer parameter, is retained.",
        [group["contract_row_id"]],
    )
    dimensions["bind"] = _dim(
        "missing",
        "No source-backed VBA/CalcVBA lowering or native adapter is specified for pointer(Void).",
    )
    for accessor, dimension_name in (
        ("func", "method"),
        ("get", "get"),
        ("put", "put"),
        ("putref", "putref"),
    ):
        if accessor in group["accessors"]:
            dimensions[dimension_name] = _dim(
                "missing",
                "The callable requires an explicit native-pointer adapter and cannot be matched to an invented VBA source type.",
            )
    dimensions["error_coercion"] = _dim(
        "missing", "Native pointer validation and error behavior are unproven."
    )
    dimensions["render"] = _dim(
        "missing", "No decisive rendering proof covers this native-pointer callable."
    )
    dimensions["oracle"] = _dim(
        "missing", "No decisive native adapter oracle is attached."
    )
    dimensions["tests"] = _dim(
        "missing", "No decisive native-pointer adapter test is attached."
    )
    return dimensions


def _event_dimensions(
    contract_ref: str, match: dict[str, Any], canonical_memid: int | None
) -> dict[str, Any]:
    dimensions = _dimensions_not_applicable("This dimension does not apply to an event row.")
    dimensions["type_or_declaration"] = _dim(
        "verified", "The exact source-interface event contract is pinned.", [contract_ref]
    )
    event_match = match["accessors"].get("func")
    if event_match is None or event_match["status"] == "missing":
        event_dim = _dim("missing", "No same-name public Event declaration was found on the coclass facade.")
    elif event_match["status"] != "compatible_source_shape":
        event_dim = _dim(
            "partial",
            "A same-name declaration exists but is incompatible or cannot be lowered to the complete source-interface event signature.",
            [event_match["source_declaration"]["source_declaration_id"]],
        )
    elif match["owner_alias"] or "clean_basproj" not in match["owner_profiles"]:
        event_dim = _dim(
            "partial",
            "The event declaration is alias-only or unavailable through the clean basproj exposure path.",
            [event_match["source_declaration"]["source_declaration_id"]],
        )
    elif not match.get("owner_kind_compatible", True):
        event_dim = _dim(
            "partial",
            "The same-name Event is owned by a standard module rather than the required class-module facade.",
            [event_match["source_declaration"]["source_declaration_id"]],
        )
    else:
        event_dim = _dim(
            "implemented_unverified",
            "A compatible public Event declaration exists; native WithEvents bind, mutation, ordering, and reentrancy proof remain pending.",
            [event_match["source_declaration"]["source_declaration_id"]],
        )
    dimensions["bind"] = copy.deepcopy(event_dim)
    dimensions["event"] = event_dim
    dimensions["default_binding"] = _default_binding_dimension(
        {
            "memid": canonical_memid,
            "default_member": canonical_memid == 0,
            "new_enum": canonical_memid == -4,
        },
        match,
    )
    dimensions["error_coercion"] = _dim(
        "partial", "Mutable argument/error applicability is not yet classified and verified."
    )
    dimensions["oracle"] = _dim("missing", "No decisive full-row event oracle is attached.")
    dimensions["tests"] = _dim("missing", "No decisive full-row native WithEvents test is attached.")
    return dimensions


def _row_status(row: dict[str, Any]) -> str:
    if row["row_kind"].startswith("unexpected_public"):
        return "unexpected_public"
    statuses = {item["status"] for item in row["dimensions"].values()}
    if statuses & GATING_STATUSES:
        return "gap"
    if statuses <= {"not_applicable", "excluded_authoritative"}:
        return "excluded"
    return "verified"


def _finalize_row(row: dict[str, Any]) -> dict[str, Any]:
    row["row_status"] = _row_status(row)
    return row


def _row_counts(rows: list[dict[str, Any]]) -> dict[str, Any]:
    row_kinds = Counter(row["row_kind"] for row in rows)
    row_statuses = Counter(row["row_status"] for row in rows)
    dimension_statuses: dict[str, dict[str, int]] = {}
    for dimension in DIMENSION_NAMES:
        dimension_statuses[dimension] = dict(
            sorted(Counter(row["dimensions"][dimension]["status"] for row in rows).items())
        )
    gating_dimension_cells = sum(
        item["status"] in GATING_STATUSES
        for row in rows
        for item in row["dimensions"].values()
    )
    unexpected = sum(row["row_kind"].startswith("unexpected_public") for row in rows)
    return {
        "rows": len(rows),
        "row_kinds": dict(sorted(row_kinds.items())),
        "row_statuses": dict(sorted(row_statuses.items())),
        "dimension_statuses": dimension_statuses,
        "gating_dimension_cells": gating_dimension_cells,
        "unexpected_public_rows": unexpected,
        "green": gating_dimension_cells == 0 and unexpected == 0,
    }


def _logical_family_key(
    row: dict[str, Any], type_names_by_id: dict[str, str]
) -> str:
    owner = row.get("facade_owner_type_id")
    if isinstance(owner, str) and owner in type_names_by_id:
        return type_names_by_id[owner]
    if isinstance(owner, str) and owner.startswith("overlay:global:"):
        return owner.removeprefix("overlay:global:")
    if isinstance(owner, str) and owner.startswith("overlay:"):
        return owner.removeprefix("overlay:")
    if isinstance(owner, str) and owner.startswith("family:"):
        name = owner.removeprefix("family:")
        return {"form": "UserForm"}.get(name.casefold(), name)
    if isinstance(owner, str) and owner.startswith("persistence:ms-oforms:"):
        return "Persistence / MS-OFORMS"
    if isinstance(owner, str) and owner.startswith("persistence:frm-frx:"):
        return "Persistence / FRM-FRX"
    if row.get("row_kind") == "persistence_property":
        return "Persistence / Properties"
    if row.get("row_kind", "").startswith("unexpected_public"):
        return "Unexpected public surface"
    if isinstance(owner, str) and owner:
        return owner
    return "Unassigned contract surface"


def _summary(rows: list[dict[str, Any]], source_summary: dict[str, Any]) -> dict[str, Any]:
    """Build actionable logical and exact-owner summaries solely from rows."""

    summary = _row_counts(rows)
    owner_families: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        owner = row.get("facade_owner_type_id")
        family_key = owner if isinstance(owner, str) and owner else "<no-facade-owner>"
        owner_families[family_key].append(row)
    summary["owner_families"] = {
        family: {
            "facade_owner_type_id": (
                None if family == "<no-facade-owner>" else family
            ),
            **_row_counts(owner_families[family]),
        }
        for family in sorted(owner_families)
    }

    type_names_by_id = {
        row["facade_owner_type_id"]: row["exact_name"]
        for row in rows
        if row.get("row_kind") == "type_contract"
        and isinstance(row.get("facade_owner_type_id"), str)
    }
    logical_families: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        logical_families[_logical_family_key(row, type_names_by_id)].append(row)
    summary["families"] = {
        family: {
            "family_key": family,
            "facade_owner_type_ids": sorted(
                {
                    row["facade_owner_type_id"]
                    for row in logical_families[family]
                    if isinstance(row.get("facade_owner_type_id"), str)
                }
            ),
            **_row_counts(logical_families[family]),
        }
        for family in sorted(logical_families)
    }
    summary["source_surface"] = copy.deepcopy(source_summary)
    return summary


def _overlay_signature(member: dict[str, Any], accessor: str) -> dict[str, Any]:
    parameters = []
    for index, parameter in enumerate(member.get("parameters", [])):
        parameters.append(
            {
                "index": index,
                "name": parameter["name"],
                "name_state": parameter.get("name_state", "documented"),
                "passing": parameter.get("passing"),
                "passing_state": parameter.get("passing_state", "not_documented"),
                "param_array": bool(parameter.get("param_array")),
                "flags": {
                    "names": ["PARAMFLAG_FOPT"] if parameter.get("optional") else [],
                    "unknown_bits": 0,
                    "value": 16 if parameter.get("optional") else 0,
                },
                "default": {
                    "state": "documented" if parameter.get("default") is not None else "not_encoded",
                    "value": parameter.get("default"),
                },
                "type": {
                    "kind": "documentation",
                    "name": parameter["type"],
                    "precision": parameter.get("type_state", "documented"),
                },
            }
        )
    return_type = member.get("return_type") or "Void"
    signature = {
        "memid": None,
        "name": member["name"],
        "names": [member["name"]] + [item["name"] for item in parameters],
        "invoke_kind": accessor,
        "function_kind": "documentation",
        "call_convention": "documentation",
        "function_flags": {"names": [], "unknown_bits": 0, "value": 0},
        "optional_parameter_count": sum(
            bool(parameter.get("optional")) for parameter in member.get("parameters", [])
        ),
        "parameters": parameters,
        "return": {
            "flags": {"names": [], "unknown_bits": 0, "value": 0},
            "default": {"state": "not_encoded"},
            "type": {
                "kind": "documentation",
                "name": return_type,
                "precision": member.get("return_type_state", "documented"),
            },
        },
        "scode_array": [],
        "is_default_member": bool(member.get("default_member")),
        "is_new_enum": False,
    }
    signature["signature_sha256"] = semantic_sha256(signature)
    return signature


def _overlay_source_type(value: dict[str, Any]) -> str:
    if value.get("kind") == "documentation":
        return value["name"]
    return _source_type_name(_display_from_semantic_type(value))


def _signature_comparison_overlay(
    declaration: dict[str, Any], signature: dict[str, Any], expected_kind: str
) -> dict[str, Any]:
    mismatches: list[str] = []
    unresolved: list[str] = []
    if declaration["kind"] != expected_kind:
        mismatches.append(f"kind {declaration['kind']} != {expected_kind}")
    expected_parameters = signature["parameters"]
    actual_parameters = declaration.get("parameters", [])
    if len(expected_parameters) != len(actual_parameters):
        mismatches.append(
            f"parameter count {len(actual_parameters)} != {len(expected_parameters)}"
        )
    else:
        for actual, expected in zip(actual_parameters, expected_parameters):
            expected_type, expected_array = _source_parameter_type(
                _overlay_source_type(expected["type"])
            )
            if expected["type"].get("precision") != "documented":
                unresolved.append(
                    f"parameter {expected['index']} exact VBA type is not documented"
                )
            elif actual["type"].casefold() != expected_type.casefold():
                mismatches.append(
                    f"parameter {expected['index']} type {actual['type']} != {expected_type}"
                )
            if bool(actual.get("array")) != expected_array:
                mismatches.append(
                    f"parameter {expected['index']} array {actual.get('array')} != {expected_array}"
                )
            if bool(actual.get("param_array")) != bool(expected.get("param_array")):
                mismatches.append(
                    f"parameter {expected['index']} ParamArray {actual.get('param_array')} != {expected.get('param_array')}"
                )
            expected_optional = "PARAMFLAG_FOPT" in _flag_names(expected["flags"])
            if actual["optional"] != expected_optional:
                mismatches.append(
                    f"parameter {expected['index']} optional {actual['optional']} != {expected_optional}"
                )
            if (
                expected.get("name_state") == "documented"
                and actual["name"].casefold() != str(expected.get("name", "")).casefold()
            ):
                mismatches.append(
                    f"parameter {expected['index']} name {actual['name']} != {expected.get('name')}"
                )
            elif expected.get("name_state") != "documented":
                unresolved.append(
                    f"parameter {expected['index']} exact name is not documented"
                )
            if expected.get("passing_state") == "documented":
                if actual.get("passing") != expected.get("passing"):
                    mismatches.append(
                        f"parameter {expected['index']} passing {actual.get('passing')} != {expected.get('passing')}"
                    )
            else:
                unresolved.append(
                    f"parameter {expected['index']} passing mode is not documented"
                )
            default_matches, default_basis = _compare_parameter_default(
                actual.get("default"), expected.get("default")
            )
            if default_matches is None:
                unresolved.append(f"parameter {expected['index']} {default_basis}")
            elif not default_matches:
                mismatches.append(
                    f"parameter {expected['index']} default {actual.get('default')!r} != {default_basis}"
                )
    if expected_kind in {"function", "property_get"}:
        expected_return = _overlay_source_type(signature["return"]["type"])
        actual_return = declaration.get("return_type") or ""
        if signature["return"]["type"].get("precision") != "documented":
            unresolved.append("exact VBA return type is not documented")
        elif actual_return.casefold() != expected_return.casefold():
            mismatches.append(f"return {actual_return} != {expected_return}")
    status = (
        "mismatch"
        if mismatches
        else "unresolved_source_lowering"
        if unresolved
        else "compatible_source_shape"
    )
    return {
        "status": status,
        "mismatches": mismatches,
        "unresolved": unresolved,
        "non_claim": "Documentation-shape comparison is not a typelib-exact signature claim.",
    }


def _match_overlay_accessors(
    member: dict[str, Any],
    accessors: dict[str, dict[str, Any]],
    source_index: dict[str, Any],
    policy: dict[str, Any],
    used_declarations: set[str],
    event: bool = False,
) -> dict[str, Any]:
    module, alias = _actual_owner(member["owner"], source_index, policy)
    result = {
        "expected_owner": member["owner"],
        "actual_owner": module["name"] if module else None,
        "owner_alias": alias,
        "expected_owner_kind": "class_module",
        "actual_owner_kind": module.get("kind") if module else None,
        "owner_kind_compatible": module is None or module.get("kind") == "class_module",
        "owner_profiles": module["effective_loader_profiles"] if module else [],
        "accessors": {},
    }
    candidates = [] if module is None else source_index["declarations_by_owner_name"].get(
        (module["name"].casefold(), member["name"].casefold()), []
    )
    for accessor, signature in accessors.items():
        if event:
            expected_kind = "event"
        elif accessor == "get":
            expected_kind = "property_get"
        elif accessor == "put":
            expected_kind = "property_let"
        elif accessor == "putref":
            expected_kind = "property_set"
        elif member.get("kind") == "sub":
            expected_kind = "sub"
        else:
            expected_kind = "function"
        candidate = next(
            (
                item
                for item in candidates
                if item["kind"] == expected_kind
                and item["source_declaration_id"] not in used_declarations
            ),
            None,
        )
        if candidate is None:
            result["accessors"][accessor] = {
                "status": "missing",
                "expected_kind": expected_kind,
                "source_declaration": None,
            }
            continue
        used_declarations.add(candidate["source_declaration_id"])
        comparison = _signature_comparison_overlay(candidate, signature, expected_kind)
        result["accessors"][accessor] = {
            "status": comparison["status"],
            "expected_kind": expected_kind,
            "source_declaration": candidate,
            "signature_comparison": comparison,
        }
    return result


def _overlay_refs(overlay: dict[str, Any], fact: dict[str, Any]) -> list[str]:
    refs: list[str] = []
    sources = overlay.get("sources")
    if not isinstance(sources, dict):
        raise LedgerError("public overlay sources must be an object")
    for key in fact.get("authority", []):
        value = sources.get(key)
        if not isinstance(value, str) or not value.startswith("https://learn.microsoft.com/"):
            raise LedgerError(f"unknown or non-official public overlay authority {key!r}")
        refs.append(value)
    for path in fact.get("evidence", []):
        if not isinstance(path, str) or not path:
            raise LedgerError("public overlay evidence paths must be nonempty strings")
        refs.append(path)
    if not refs:
        raise LedgerError(f"public overlay fact {fact.get('name')!r} has no authority")
    return refs


def _w005_stable_descriptor(node: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {"kind": node["kind"], "vt": node["vt"]}
    if node["kind"] == "pointer":
        result["target"] = _w005_stable_descriptor(node["target"])
    elif node["kind"] == "userdefined":
        target = node["target"]
        result["target"] = {
            "name": target["name"],
            "guid": target["guid"],
            "typekind": target["typekind"],
        }
    elif node["kind"] == "c_array":
        result["element"] = _w005_stable_descriptor(node["element"])
        result["bounds"] = node["bounds"]
    return result


def _w005_current_signature_sha256(function: dict[str, Any]) -> str:
    signature = {
        "names": function["names"],
        "function_kind": function["function_kind"],
        "invoke_kind": function["invoke_kind"],
        "call_convention": function["call_convention"],
        "function_flags": function["function_flags"]["value"],
        "return_type": _w005_stable_descriptor(function["return"]["type"]),
        "parameters": [
            {
                "name": parameter["name"],
                "type": _w005_stable_descriptor(parameter["type"]),
                "parameter_flags": parameter["parameter_flags"]["value"],
                "default": parameter["default"],
            }
            for parameter in function["parameters"]
        ],
    }
    # The bead-.2 W005 reconciliation deliberately uses the FM20 extractor's
    # compact structural JSON bytes without a trailing newline.  Reproduce that
    # historical hash contract exactly instead of using this ledger's semantic
    # digest helper (which includes a newline).
    return sha256_bytes(
        json.dumps(
            signature,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    )


def build_ledger(repo_root: Path, paths: dict[str, str] | None = None) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    resolved_paths = dict(DEFAULT_PATHS)
    if paths:
        resolved_paths.update(paths)
    inputs = {
        name: load_json_strict(repo_root / resolved_paths[name])
        for name in ("fm20", "w005", "ms_oforms", "frm_frx", "overlay", "policy")
    }
    _validate_input_schemas(inputs)
    loader_inventories = _validate_loader_profiles(repo_root, inputs["policy"])

    surface = extract_surface(repo_root, repo_root / resolved_paths["basproj"])
    _validate_loader_surface_identity(surface, loader_inventories)
    source_index = _index_source(surface, inputs["policy"])
    used_declarations: set[str] = set()
    used_nested_members: set[str] = set()

    fm20 = inputs["fm20"]
    type_lookup: dict[tuple[str, int, str], dict[str, Any]] = {}
    library_lookup: dict[str, dict[str, Any]] = {}
    group_lookup: dict[tuple[str, int, str], list[dict[str, Any]]] = {}
    for library in fm20["libraries"]:
        library_lookup[library["key"]] = library
        for type_fact in library["types"]:
            key = (library["key"], int(type_fact["index"]), type_fact["view"])
            if key in type_lookup:
                raise LedgerError(f"duplicate canonical type key {key!r}")
            type_lookup[key] = type_fact
            group_lookup[key] = _group_functions(library["key"], type_fact)
    canonical_source_aliases = _canonical_source_aliases(type_lookup)

    root_library = library_lookup[fm20["root_library_key"]]
    root_primary_coclasses = [
        item
        for item in root_library["types"]
        if item["view"] == "primary"
        and item["attributes"]["typekind_name"] == "TKIND_COCLASS"
    ]

    projection_specs: list[dict[str, Any]] = []
    event_specs: list[dict[str, Any]] = []
    projection_refs_by_contract: dict[str, list[str]] = defaultdict(list)
    for coclass in root_primary_coclasses:
        ordinary_indices = coclass["coclass_map"]["ordinary_default_indices"]
        if len(ordinary_indices) != 1:
            raise LedgerError(f"{coclass['documentation']['name']} lacks one ordinary default")
        ordinary_index = ordinary_indices[0]
        ordinary_impl = next(
            item for item in coclass["implemented_types"] if item["index"] == ordinary_index
        )
        target_key = _type_key_from_target(ordinary_impl["target"])
        declaration_type = type_lookup.get(target_key)
        if declaration_type is None:
            raise LedgerError(f"unresolved ordinary default target {target_key!r}")
        coclass_id = _type_id(root_library["key"], coclass)
        declaration_id = _type_id(target_key[0], declaration_type)
        for group in group_lookup[target_key]:
            contract_row_id = _function_contract_id(declaration_id, group["memid"])
            row_id = (
                f"surface:{coclass_id}|impl={ordinary_index}|decl={declaration_id}|memid={group['memid']}"
            )
            projection_specs.append(
                {
                    "row_id": row_id,
                    "coclass": coclass,
                    "coclass_id": coclass_id,
                    "implementation": ordinary_impl,
                    "declaration_type": declaration_type,
                    "declaration_id": declaration_id,
                    "group": group,
                    "contract_row_id": contract_row_id,
                }
            )
            projection_refs_by_contract[contract_row_id].append(row_id)
        for variable in declaration_type["variables"]:
            if variable["variable_kind_name"] != "VAR_DISPATCH":
                continue
            row_id = (
                f"surface:{coclass_id}|impl={ordinary_index}|decl={declaration_id}|var={variable['index']}"
            )
            projection_specs.append(
                {
                    "row_id": row_id,
                    "coclass": coclass,
                    "coclass_id": coclass_id,
                    "implementation": ordinary_impl,
                    "declaration_type": declaration_type,
                    "declaration_id": declaration_id,
                    "variable": variable,
                    "contract_row_id": f"contract:variable:{declaration_id}|index={variable['index']}",
                }
            )
            projection_refs_by_contract[
                f"contract:variable:{declaration_id}|index={variable['index']}"
            ].append(row_id)

        for source_impl in sorted(
            (item for item in coclass["implemented_types"] if "source" in item["roles"]),
            key=lambda item: item["index"],
        ):
            source_key = _type_key_from_target(source_impl["target"])
            source_type = type_lookup.get(source_key)
            if source_type is None:
                raise LedgerError(f"unresolved source target {source_key!r}")
            source_id = _type_id(source_key[0], source_type)
            for function in sorted(source_type["functions"], key=lambda item: item["index"]):
                contract_row_id = _function_contract_id(source_id, function["memid"])
                row_id = (
                    f"event:{coclass_id}|impl={source_impl['index']}|source={source_id}|function={function['index']}"
                )
                event_specs.append(
                    {
                        "row_id": row_id,
                        "coclass": coclass,
                        "coclass_id": coclass_id,
                        "implementation": source_impl,
                        "source_type": source_type,
                        "source_id": source_id,
                        "function": function,
                        "contract_row_id": contract_row_id,
                    }
                )
                projection_refs_by_contract[contract_row_id].append(row_id)

    abi_adapter_keys: set[tuple[str, int, str]] = set()
    for adapter in inputs["policy"].get("abi_adapter_types", []):
        key = (
            adapter["library_key"],
            int(adapter["type_index"]),
            adapter["view"],
        )
        if key in abi_adapter_keys:
            raise LedgerError(f"duplicate ABI adapter type {key!r}")
        abi_adapter_keys.add(key)
        declaration_type = type_lookup.get(key)
        if declaration_type is None:
            raise LedgerError(f"unresolved ABI adapter type {key!r}")
        if declaration_type["documentation"]["name"] != adapter["name"]:
            raise LedgerError(
                f"ABI adapter name {adapter['name']!r} does not match exact type {key!r}"
            )
        if (
            adapter["view"] != "primary"
            or declaration_type["attributes"]["typekind_name"] != "TKIND_INTERFACE"
        ):
            raise LedgerError(
                f"ABI adapter must be one primary non-dispatch interface: {key!r}"
            )
        declaration_id = _type_id(key[0], declaration_type)
        for group in group_lookup[key]:
            contract_row_id = _function_contract_id(declaration_id, group["memid"])
            row_id = f"abi-adapter:{declaration_id}|memid={group['memid']}"
            projection_specs.append(
                {
                    "row_id": row_id,
                    "projection_kind": "abi_adapter",
                    "facade_name": adapter["name"],
                    "facade_id": declaration_id,
                    "abi_adapter": copy.deepcopy(adapter),
                    "declaration_type": declaration_type,
                    "declaration_id": declaration_id,
                    "group": group,
                    "contract_row_id": contract_row_id,
                }
            )
            projection_refs_by_contract[contract_row_id].append(row_id)

    direct_facade_keys: set[tuple[str, int, str]] = set()
    for direct in inputs["policy"].get("direct_facade_types", []):
        key = (
            direct["library_key"],
            int(direct["type_index"]),
            direct["view"],
        )
        if key in direct_facade_keys:
            raise LedgerError(f"duplicate direct facade type {key!r}")
        if key in abi_adapter_keys:
            raise LedgerError(f"type cannot be both direct facade and ABI adapter: {key!r}")
        direct_facade_keys.add(key)
        declaration_type = type_lookup.get(key)
        if declaration_type is None:
            raise LedgerError(f"unresolved direct facade type {key!r}")
        if declaration_type["documentation"]["name"] != direct["name"]:
            raise LedgerError(
                f"direct facade name {direct['name']!r} does not match exact type {key!r}"
            )
        if (
            direct["view"] != "primary"
            or declaration_type["attributes"]["typekind_name"]
            not in {"TKIND_DISPATCH", "TKIND_INTERFACE"}
        ):
            raise LedgerError(
                f"direct facade type must be a primary dispatch/interface type: {key!r}"
            )
        declaration_id = _type_id(key[0], declaration_type)
        override_by_memid: dict[int, dict[str, Any]] = {}
        for override in direct.get("member_projection_overrides", []):
            memid = int(override["memid"])
            if memid in override_by_memid:
                raise LedgerError(
                    f"duplicate direct-facade projection override at {key!r} memid {memid}"
                )
            if override.get("mode") != "native_pointer_adapter":
                raise LedgerError(
                    f"unknown direct-facade projection override mode at {key!r} memid {memid}"
                )
            override_by_memid[memid] = override
        resolved_override_memids: set[int] = set()
        for group in group_lookup[key]:
            override = override_by_memid.get(int(group["memid"]))
            has_native_pointer = _group_has_native_void_pointer(group)
            restricted = _visibility(declaration_type, group["functions"])["restricted"]
            requires_override = has_native_pointer and not restricted
            if requires_override != (override is not None):
                raise LedgerError(
                    f"direct-facade native-pointer override mismatch at {key!r} memid {group['memid']}"
                )
            if override is not None:
                if override.get("name") != group["name"]:
                    raise LedgerError(
                        f"direct-facade override name mismatch at {key!r} memid {group['memid']}"
                    )
                resolved_override_memids.add(int(group["memid"]))
            contract_row_id = _function_contract_id(declaration_id, group["memid"])
            row_id = f"surface:direct:{declaration_id}|memid={group['memid']}"
            projection_specs.append(
                {
                    "row_id": row_id,
                    "projection_kind": "direct_facade",
                    "facade_name": direct["name"],
                    "facade_id": declaration_id,
                    "direct_facade": copy.deepcopy(direct),
                    "member_projection_override": copy.deepcopy(override),
                    "declaration_type": declaration_type,
                    "declaration_id": declaration_id,
                    "group": group,
                    "contract_row_id": contract_row_id,
                }
            )
            projection_refs_by_contract[contract_row_id].append(row_id)
        if resolved_override_memids != set(override_by_memid):
            raise LedgerError(
                f"unresolved direct-facade projection overrides at {key!r}: "
                f"{sorted(set(override_by_memid) - resolved_override_memids)!r}"
            )
        for variable in declaration_type["variables"]:
            if variable["variable_kind_name"] != "VAR_DISPATCH":
                continue
            contract_row_id = (
                f"contract:variable:{declaration_id}|index={variable['index']}"
            )
            row_id = (
                f"surface:direct:{declaration_id}|var={variable['index']}"
            )
            projection_specs.append(
                {
                    "row_id": row_id,
                    "projection_kind": "direct_facade",
                    "facade_name": direct["name"],
                    "facade_id": declaration_id,
                    "direct_facade": copy.deepcopy(direct),
                    "declaration_type": declaration_type,
                    "declaration_id": declaration_id,
                    "variable": variable,
                    "contract_row_id": contract_row_id,
                }
            )
            projection_refs_by_contract[contract_row_id].append(row_id)

    w005_by_key: dict[tuple[Any, ...], tuple[int, dict[str, Any]]] = {}
    for index, reconciliation in enumerate(inputs["w005"]["row_results"]):
        if reconciliation.get("status") != "exact_match":
            raise LedgerError(f"W005 reconciliation row {index} is not exact_match")
        key_fact = reconciliation["key"]
        key = (
            key_fact["coclass"],
            key_fact["source_interface"],
            key_fact["source_interface_guid"],
            key_fact["event_name"],
            int(key_fact["dispid"]),
            int(key_fact["invoke_kind"]),
        )
        if key in w005_by_key:
            raise LedgerError(f"duplicate W005 reconciliation key {key!r}")
        w005_by_key[key] = (index, reconciliation)
    matched_w005_keys: set[tuple[Any, ...]] = set()
    for spec in event_specs:
        function = spec["function"]
        key = (
            spec["coclass"]["documentation"]["name"],
            spec["source_type"]["documentation"]["name"],
            spec["source_type"]["attributes"]["guid"],
            function["documentation"]["name"],
            int(function["memid"]),
            int(function["invoke_kind"]),
        )
        match = w005_by_key.get(key)
        if match is not None:
            recomputed_signature_sha256 = _w005_current_signature_sha256(function)
            reconciliation = match[1]
            if (
                reconciliation["current_signature_sha256"]
                != recomputed_signature_sha256
                or reconciliation["w005_signature_sha256"]
                != recomputed_signature_sha256
            ):
                raise LedgerError(
                    f"W005 reconciliation signature drift for {key!r}"
                )
            matched_w005_keys.add(key)
            spec["w005_reconciliation_index"] = match[0]
            spec["w005_reconciliation"] = reconciliation
    if len(w005_by_key) != 376 or matched_w005_keys != set(w005_by_key):
        raise LedgerError(
            "W005 reconciliation must match exactly 376 of the 380 full-library event rows"
        )
    unmatched_events = {
        (
            spec["coclass"]["documentation"]["name"],
            spec["source_type"]["documentation"]["name"],
            spec["function"]["documentation"]["name"],
            int(spec["function"]["memid"]),
        )
        for spec in event_specs
        if "w005_reconciliation_index" not in spec
    }
    expected_unmatched_events = {
        ("SpinButton", "SpinbuttonEvents", "SpinUp", 5),
        ("SpinButton", "SpinbuttonEvents", "SpinDown", 6),
        ("SpinButton2", "SpinbuttonEvents", "SpinUp", 5),
        ("SpinButton2", "SpinbuttonEvents", "SpinDown", 6),
    }
    if unmatched_events != expected_unmatched_events:
        raise LedgerError(
            "the four non-W005 event rows must be exactly SpinButton/SpinButton2 SpinUp/SpinDown"
        )

    persistence_pairs: dict[tuple[str, str], str] = {}
    persistence_pair_specs: list[tuple[dict[str, Any], dict[str, Any]]] = []
    persistence_mapping_names: set[str] = set()
    for mapping in inputs["frm_frx"]["property_mappings"]:
        mapping_name = mapping["name"].casefold()
        if mapping_name in persistence_mapping_names:
            raise LedgerError(
                f"duplicate FRM/FRX property mapping {mapping['name']!r}"
            )
        persistence_mapping_names.add(mapping_name)
        if mapping.get("runtime_api_claim") is not False:
            raise LedgerError(f"property mapping {mapping['name']} must retain runtime_api_claim=false")
        if mapping.get("binary_value_decoded") is not False:
            raise LedgerError(
                f"property mapping {mapping['name']} must retain binary_value_decoded=false"
            )
        for coverage in mapping["family_coverage"]:
            key = (mapping["name"].casefold(), coverage["family"].casefold())
            row_id = f"persistence-family:{mapping['name']}|{coverage['family']}"
            if key in persistence_pairs:
                raise LedgerError(f"duplicate persistence family pair {key!r}")
            persistence_pairs[key] = row_id
            persistence_pair_specs.append((mapping, coverage))

    rows: list[dict[str, Any]] = []
    type_rows_by_id: dict[str, dict[str, Any]] = {}
    for library in fm20["libraries"]:
        for type_fact in library["types"]:
            type_id = _type_id(library["key"], type_fact)
            type_kind = type_fact["attributes"]["typekind_name"]
            type_name = type_fact["documentation"]["name"]
            dual = type_fact["view"] != "primary"
            external = library["key"] != fm20["root_library_key"]
            supporting_stdole = external and type_name in {"Picture", "IPictureDisp"}
            dimensions = _dimensions_not_applicable("No implementation obligation applies to this exact metadata cell.")
            dimensions["type_or_declaration"] = _dim(
                "verified",
                "The exact type view is retained from the pinned typelib fact pack.",
                [_source_ref(resolved_paths["fm20"], f"type:{type_id}")],
            )
            disposition = "accepted_primary"
            disposition_basis = "root primary type; hidden/nonbrowsable does not exclude"
            actual: dict[str, Any] | None = None
            alias = False
            identity_mismatches: list[str] = []
            expected_source_kind: str | None = None
            expected_creatable: bool | None = None
            actual_creatable_by_profile: dict[str, bool] = {}
            creatability_mismatch_profiles: list[str] = []
            identity_profile_evidence: dict[str, str] = {}
            identity_mismatch_evidence: list[str] = []
            if dual:
                disposition = "abi_companion"
                disposition_basis = "view=dual_interface; retained but not a second VBA facade identity"
                dimensions["bind"] = _dim(
                    "excluded_authoritative",
                    disposition_basis,
                    [_source_ref(resolved_paths["fm20"], f"type:{type_id}")],
                    rule="dual_companion",
                )
            elif type_kind == "TKIND_ALIAS":
                disposition = "alias_typedef"
                disposition_basis = (
                    "Exact named alias identity lowers recursively for source-signature "
                    "comparison and is never treated as a class module."
                )
                if external and not supporting_stdole:
                    dimensions["bind"] = _dim(
                        "excluded_authoritative",
                        "External stdole alias is retained for signature closure; CalcForms does not reimplement stdole's binder.",
                        [_source_ref(resolved_paths["fm20"], f"type:{type_id}")],
                        rule="external_abi",
                    )
                else:
                    dimensions["bind"] = _dim(
                        "missing",
                        "No decisive CalcVBA/CalcForms binder-registry evidence proves this exact named alias identity.",
                    )
            elif external and not supporting_stdole:
                disposition = "external_abi"
                disposition_basis = "referenced stdole signature-closure type"
                dimensions["bind"] = _dim(
                    "excluded_authoritative",
                    disposition_basis,
                    [_source_ref(resolved_paths["fm20"], f"type:{type_id}")],
                    rule="external_abi",
                )
            else:
                if type_kind == "TKIND_ENUM":
                    expected_source_kind = "standard_module_enum"
                    candidates = [
                        item
                        for item in source_index["declaration_by_id"].values()
                        if item["kind"] == "enum"
                        and item["name"].casefold() == type_name.casefold()
                        and source_index["modules"]
                        .get(item.get("owner", "").casefold(), {})
                        .get("kind")
                        == "standard_module"
                    ]
                    actual = candidates[0] if candidates else None
                    if len(candidates) > 1:
                        identity_mismatches.append(
                            f"{len(candidates)} same-name public Enum declarations are ambiguous"
                        )
                    elif actual:
                        used_declarations.add(actual["source_declaration_id"])
                elif type_kind == "TKIND_RECORD":
                    expected_source_kind = "standard_module_type"
                    candidates = [
                        item
                        for item in source_index["declaration_by_id"].values()
                        if item["kind"] == "type"
                        and item["name"].casefold() == type_name.casefold()
                        and source_index["modules"]
                        .get(item.get("owner", "").casefold(), {})
                        .get("kind")
                        == "standard_module"
                    ]
                    actual = candidates[0] if candidates else None
                    if len(candidates) > 1:
                        identity_mismatches.append(
                            f"{len(candidates)} same-name public Type declarations are ambiguous"
                        )
                    elif actual:
                        used_declarations.add(actual["source_declaration_id"])
                else:
                    module, alias = _actual_owner(type_name, source_index, inputs["policy"])
                    actual = module
                    identity = _class_type_identity_comparison(type_fact, actual)
                    expected_source_kind = identity["expected_source_kind"]
                    expected_creatable = identity["expected_creatable"]
                    actual_creatable_by_profile = identity[
                        "actual_creatable_by_profile"
                    ]
                    creatability_mismatch_profiles = identity[
                        "creatability_mismatch_profiles"
                    ]
                    identity_profile_evidence = identity["profile_evidence"]
                    identity_mismatch_evidence = identity["mismatch_evidence"]
                    identity_mismatches.extend(identity["mismatches"])
                if actual is None:
                    dimensions["bind"] = _dim("missing", "No canonical CalcForms public type declaration exists.")
                elif alias:
                    dimensions["bind"] = _dim(
                        "partial",
                        "Only an explicit wrong-name source module alias exists; canonical type identity is absent."
                        + (
                            " The aliased module also has incompatible effective loader-profile identity: "
                            + "; ".join(identity_mismatches)
                            if identity_mismatches
                            else ""
                        ),
                        identity_mismatch_evidence,
                    )
                elif identity_mismatches:
                    dimensions["bind"] = _dim(
                        "partial",
                        "A same-name source declaration exists, but its type identity is incompatible: "
                        + "; ".join(identity_mismatches),
                        identity_mismatch_evidence,
                    )
                elif actual.get("kind") in {"enum", "type"} and (
                    "clean_basproj" not in actual.get("owner_profiles", [])
                ):
                    dimensions["bind"] = _dim(
                        "partial",
                        "A same-name public VBA declaration exists only in a module hidden from the clean basproj exposure path.",
                        [actual["source_declaration_id"]],
                    )
                elif actual.get("kind") in {"enum", "type"}:
                    dimensions["bind"] = _dim(
                        "implemented_unverified",
                        "A same-name public VBA declaration exists; exhaustive bind/value proof remains pending.",
                        [actual["source_declaration_id"]],
                    )
                elif "clean_basproj" not in actual["effective_loader_profiles"]:
                    manual_effective_profiles = [
                        profile
                        for profile in actual["effective_loader_profiles"]
                        if profile != "clean_basproj"
                    ]
                    dimensions["bind"] = _dim(
                        "partial",
                        (
                            "A same-name class exists but is not exposed by the clean basproj path; validated manual-loader profiles expose it and their effective creatability is recorded separately here."
                            if manual_effective_profiles
                            else "A same-name class exists but is not exposed by any effective loader profile."
                        ),
                        list(identity_profile_evidence.values()),
                    )
                else:
                    dimensions["bind"] = _dim(
                        "implemented_unverified",
                        "A same-name clean-path public type exists; exhaustive identity/bind proof remains pending.",
                    )
            row = _finalize_row(
                {
                    "row_id": f"contract:type:{type_id}",
                    "row_kind": "type_contract",
                    "source_authority": "fm20_typelib" if not external else "stdole_typelib",
                    "facade_owner_type_id": type_id,
                    "declaration_owner_type_id": type_id,
                    "source_refs": [_source_ref(resolved_paths["fm20"], f"type:{type_id}")],
                    "exact_name": type_name,
                    "memid": None,
                    "visibility": _visibility(type_fact),
                    "disposition": disposition,
                    "disposition_basis": disposition_basis,
                    "contract": {
                        "library_key": library["key"],
                        "type_index": type_fact["index"],
                        "view": type_fact["view"],
                        "typekind": type_kind,
                        "guid": type_fact["attributes"]["guid"],
                        "abi_layout": {
                            "alignment": type_fact["attributes"]["alignment"],
                            "size_instance": type_fact["attributes"]["size_instance"],
                            "vtable_size": type_fact["attributes"]["vtable_size"],
                            "function_count": type_fact["attributes"]["function_count"],
                            "variable_count": type_fact["attributes"]["variable_count"],
                            "implementation_count": type_fact["attributes"][
                                "implementation_count"
                            ],
                        },
                        "alias": copy.deepcopy(type_fact["alias_type"]),
                        "implemented_types": copy.deepcopy(type_fact["implemented_types"]),
                        "dual_primary": copy.deepcopy(type_fact["dual_primary"]),
                        "dual_companion": copy.deepcopy(type_fact["dual_companion"]),
                    },
                    "actual": {
                        "source": actual,
                        "wrong_name_alias": alias,
                        "identity_comparison": {
                            "expected_source_kind": expected_source_kind,
                            "expected_creatable": expected_creatable,
                            "actual_creatable_by_profile": actual_creatable_by_profile,
                            "creatability_mismatch_profiles": creatability_mismatch_profiles,
                            "profile_evidence": identity_profile_evidence,
                            "mismatches": identity_mismatches,
                        },
                    },
                    "dimensions": dimensions,
                }
            )
            type_rows_by_id[type_id] = row
            rows.append(row)

    for library in fm20["libraries"]:
        external = library["key"] != fm20["root_library_key"]
        for type_fact in library["types"]:
            type_id = _type_id(library["key"], type_fact)
            dual = type_fact["view"] != "primary"
            for group in group_lookup[(library["key"], type_fact["index"], type_fact["view"])]:
                contract_row_id = _function_contract_id(type_id, group["memid"])
                visibility = _visibility(type_fact, group["functions"])
                projections = projection_refs_by_contract.get(contract_row_id, [])
                dimensions = _dimensions_not_applicable(
                    "Behavioral obligations live on coclass/event projection rows."
                )
                dimensions["type_or_declaration"] = _dim(
                    "verified",
                    "All FUNCDESC occurrences for this type-view/memid group are retained.",
                    [
                        _source_ref(
                            resolved_paths["fm20"],
                            f"type:{type_id}:functions:{index}",
                        )
                        for index in group["source_indices"]
                    ],
                )
                disposition = "canonical_declaration"
                if dual:
                    disposition = "abi_companion"
                    dimensions["bind"] = _dim(
                        "excluded_authoritative",
                        "Dual-interface view retained as ABI metadata, not a second VBA facade member.",
                        [contract_row_id],
                        rule="dual_companion",
                    )
                elif visibility["restricted"]:
                    disposition = "restricted_facade"
                    dimensions["bind"] = _dim(
                        "excluded_authoritative",
                        "Exact FUNCFLAG_FRESTRICTED metadata excludes this public facade obligation.",
                        [contract_row_id],
                        rule="restricted",
                    )
                elif projections:
                    dimensions["bind"] = _dim(
                        "not_applicable",
                        "Bind/behavior is assessed independently on every coclass/event projection.",
                        projections,
                    )
                elif external:
                    disposition = "external_abi"
                    dimensions["bind"] = _dim(
                        "excluded_authoritative",
                        "Referenced stdole declaration retained for signature closure.",
                        [contract_row_id],
                        rule="external_abi",
                    )
                else:
                    disposition = "needs_projection_classification"
                    dimensions["bind"] = _dim(
                        "partial",
                        "Callable root-library declaration has no coclass/event projection or authoritative exclusion.",
                        [contract_row_id],
                    )
                rows.append(
                    _finalize_row(
                        {
                            "row_id": contract_row_id,
                            "row_kind": "declaration_member",
                            "source_authority": "fm20_typelib" if not external else "stdole_typelib",
                            "facade_owner_type_id": None,
                            "declaration_owner_type_id": type_id,
                            "source_refs": [
                                _source_ref(
                                    resolved_paths["fm20"],
                                    f"type:{type_id}:functions:{index}",
                                )
                                for index in group["source_indices"]
                            ],
                            "exact_name": group["name"],
                            "memid": group["memid"],
                            "visibility": visibility,
                            "disposition": disposition,
                            "disposition_basis": "Exact type-view declaration contract; projections are separate.",
                            "projection_refs": projections,
                            "contract": {
                                "accessors": copy.deepcopy(group["accessors"]),
                                "source_function_indices": group["source_indices"],
                                "default_member": group["default_member"],
                                "new_enum": group["new_enum"],
                            },
                            "actual": None,
                            "dimensions": dimensions,
                        }
                    )
                )

            for variable in type_fact["variables"]:
                enum_value = type_fact["attributes"]["typekind_name"] == "TKIND_ENUM"
                row_kind = "enum_value" if enum_value else "declaration_variable"
                row_id = f"contract:variable:{type_id}|index={variable['index']}"
                dimensions = _dimensions_not_applicable(
                    "Behavioral obligations live on a projection or the enclosing type row."
                )
                dimensions["type_or_declaration"] = _dim(
                    "verified",
                    "The exact VARDESC occurrence is retained from the pinned typelib.",
                    [_source_ref(resolved_paths["fm20"], f"type:{type_id}:variables:{variable['index']}")],
                )
                actual_member = None
                if enum_value and type_fact["view"] == "primary":
                    enum_declaration = next(
                        (
                            item
                            for item in source_index["declaration_by_id"].values()
                            if item["kind"] == "enum"
                            and item["name"].casefold() == type_fact["documentation"]["name"].casefold()
                        ),
                        None,
                    )
                    if enum_declaration:
                        for member_id, member in source_index["nested_member_by_id"].items():
                            if (
                                member["source_declaration_id"] == enum_declaration["source_declaration_id"]
                                and member["name"].casefold()
                                == variable["documentation"]["name"].casefold()
                            ):
                                actual_member = member
                                used_nested_members.add(member_id)
                                break
                projections = projection_refs_by_contract.get(row_id, [])
                if type_fact["view"] != "primary":
                    dimensions["bind"] = _dim(
                        "excluded_authoritative",
                        "Dual-interface VARDESC retained as ABI metadata.",
                        [row_id],
                        rule="dual_companion",
                    )
                elif enum_value:
                    if actual_member is None:
                        dimensions["bind"] = _dim(
                            "missing", "No same-name CalcForms enum constant exists."
                        )
                    else:
                        expected_value = variable.get("union_value", {}).get(
                            "value", {}
                        ).get("value")
                        if actual_member.get("resolved_value") != expected_value:
                            dimensions["bind"] = _dim(
                                "partial",
                                "A same-name enum constant exists but its extracted integer value differs or cannot be resolved.",
                                [actual_member["source_member_id"]],
                            )
                        else:
                            dimensions["bind"] = _dim(
                                "implemented_unverified",
                                "A same-name, same-integer enum constant exists; compiled bind proof remains pending.",
                                [actual_member["source_member_id"]],
                            )
                elif projections:
                    dimensions["bind"] = _dim(
                        "not_applicable", "Bind is assessed on the coclass variable projection.", projections
                    )
                elif external:
                    dimensions["bind"] = _dim(
                        "excluded_authoritative",
                        "Referenced stdole field retained for external signature closure.",
                        [row_id],
                        rule="external_abi",
                    )
                else:
                    dimensions["bind"] = _dim(
                        "partial", "Non-enum root-library VARDESC needs projection/classification."
                    )
                is_default = int(variable["memid"]) == 0 or "VARFLAG_FDEFAULTBIND" in _flag_names(
                    variable.get("variable_flags")
                )
                rows.append(
                    _finalize_row(
                        {
                            "row_id": row_id,
                            "row_kind": row_kind,
                            "source_authority": "fm20_typelib" if not external else "stdole_typelib",
                            "facade_owner_type_id": None,
                            "declaration_owner_type_id": type_id,
                            "source_refs": [
                                _source_ref(
                                    resolved_paths["fm20"],
                                    f"type:{type_id}:variables:{variable['index']}",
                                )
                            ],
                            "exact_name": variable["documentation"]["name"],
                            "memid": variable["memid"],
                            "visibility": _variable_visibility(type_fact, variable),
                            "disposition": "exact_variable_contract",
                            "disposition_basis": "Exact VARDESC retained; facade projection is separate.",
                            "projection_refs": projections,
                            "contract": {
                                "variable": copy.deepcopy(variable),
                                "default_member": is_default,
                                "new_enum": int(variable["memid"]) == -4,
                            },
                            "actual": actual_member,
                            "dimensions": dimensions,
                        }
                    )
                )

    for spec in projection_specs:
        abi_projection = spec.get("projection_kind") == "abi_adapter"
        if abi_projection:
            group = dict(spec["group"])
            group["contract_row_id"] = spec["contract_row_id"]
            dimensions = _abi_adapter_dimensions(group)
            rows.append(
                _finalize_row(
                    {
                        "row_id": spec["row_id"],
                        "row_kind": "abi_adapter_member",
                        "source_authority": "fm20_typelib",
                        "facade_owner_type_id": spec["facade_id"],
                        "declaration_owner_type_id": spec["declaration_id"],
                        "source_refs": [spec["contract_row_id"]],
                        "exact_name": group["name"],
                        "memid": group["memid"],
                        "visibility": _visibility(
                            spec["declaration_type"], group["functions"]
                        ),
                        "disposition": "accepted_abi_adapter_obligation",
                        "disposition_basis": (
                            "Exact non-dispatch ABI contract retained without "
                            "misrepresenting HRESULT/out parameters as VBA source syntax."
                        ),
                        "contract": {
                            "accessors": copy.deepcopy(group["accessors"]),
                            "default_member": group["default_member"],
                            "new_enum": group["new_enum"],
                            "abi_adapter": copy.deepcopy(spec["abi_adapter"]),
                            "interface_layout": copy.deepcopy(
                                type_rows_by_id[spec["declaration_id"]]["contract"][
                                    "abi_layout"
                                ]
                            ),
                            "type_contract_ref": (
                                f"contract:type:{spec['declaration_id']}"
                            ),
                            "projection_semantics": "non_dispatch_abi_adapter_required",
                        },
                        "actual": None,
                        "dimensions": dimensions,
                    }
                )
            )
            continue
        direct_projection = spec.get("projection_kind") == "direct_facade"
        if "group" in spec:
            group = dict(spec["group"])
            group["contract_row_id"] = spec["contract_row_id"]
            owner_name = (
                spec["facade_name"]
                if direct_projection
                else spec["coclass"]["documentation"]["name"]
            )
            restricted = _visibility(spec["declaration_type"], group["functions"])["restricted"]
            projection_override = spec.get("member_projection_override")
            match = (
                _skipped_accessor_match(
                    owner_name,
                    group["accessors"],
                    source_index,
                    inputs["policy"],
                    (
                        "explicit native-pointer adapter obligation"
                        if projection_override is not None
                        else "authoritative FUNCFLAG_FRESTRICTED exclusion"
                    ),
                )
                if restricted or projection_override is not None
                else _match_accessors(
                    owner_name,
                    group["name"],
                    group["accessors"],
                    source_index,
                    inputs["policy"],
                    used_declarations,
                    canonical_source_aliases,
                )
            )
            persistence_ref = persistence_pairs.get(
                (group["name"].casefold(), owner_name.casefold())
            )
            dimensions = (
                _native_pointer_adapter_dimensions(group)
                if projection_override is not None
                else _surface_dimensions(
                    group, match, restricted, persistence_ref
                )
            )
            contract = {
                "accessors": copy.deepcopy(group["accessors"]),
                "default_member": group["default_member"],
                "new_enum": group["new_enum"],
            }
            if projection_override is not None:
                contract["member_projection_override"] = copy.deepcopy(
                    projection_override
                )
                contract["projection_semantics"] = "native_pointer_adapter_required"
            exact_name = group["name"]
            memid = group["memid"]
            visibility = _visibility(spec["declaration_type"], group["functions"])
        else:
            variable = spec["variable"]
            owner_name = (
                spec["facade_name"]
                if direct_projection
                else spec["coclass"]["documentation"]["name"]
            )
            accessors = _vardesc_accessors(variable)
            default_member = int(variable["memid"]) == 0 or (
                "VARFLAG_FDEFAULTBIND"
                in _flag_names(variable.get("variable_flags"))
            )
            group = {
                "name": variable["documentation"]["name"],
                "memid": variable["memid"],
                "accessors": accessors,
                "default_member": default_member,
                "new_enum": int(variable["memid"]) == -4,
                "contract_row_id": spec["contract_row_id"],
            }
            persistence_ref = persistence_pairs.get(
                (group["name"].casefold(), owner_name.casefold())
            )
            visibility = _variable_visibility(spec["declaration_type"], variable)
            match = (
                _skipped_accessor_match(
                    owner_name,
                    accessors,
                    source_index,
                    inputs["policy"],
                    "authoritative VARFLAG_FRESTRICTED exclusion",
                )
                if visibility["restricted"]
                else _match_accessors(
                    owner_name,
                    group["name"],
                    accessors,
                    source_index,
                    inputs["policy"],
                    used_declarations,
                    canonical_source_aliases,
                )
            )
            dimensions = _surface_dimensions(
                group, match, visibility["restricted"], persistence_ref
            )
            contract = {
                "variable": copy.deepcopy(variable),
                "accessors": copy.deepcopy(accessors),
                "accessor_derivation": (
                    "VAR_DISPATCH always supplies Property Get; writable scalar values "
                    "supply Property Let and writable object values Property Set."
                ),
                "default_member": default_member,
                "new_enum": group["new_enum"],
            }
            exact_name = variable["documentation"]["name"]
            memid = variable["memid"]
            visibility = _variable_visibility(spec["declaration_type"], variable)
        if direct_projection:
            contract["direct_facade"] = copy.deepcopy(spec["direct_facade"])
        else:
            contract["implementation_edge"] = {
                "index": spec["implementation"]["index"],
                "roles": copy.deepcopy(spec["implementation"]["roles"]),
                "target": copy.deepcopy(spec["implementation"]["target"]),
            }
        declaration_library_key = spec["declaration_id"].split("|", 1)[0]
        source_authority = (
            "fm20_typelib"
            if declaration_library_key == fm20["root_library_key"]
            else "stdole_typelib"
        )
        rows.append(
            _finalize_row(
                {
                    "row_id": spec["row_id"],
                    "row_kind": "surface_member",
                    "source_authority": source_authority,
                    "facade_owner_type_id": (
                        spec["facade_id"] if direct_projection else spec["coclass_id"]
                    ),
                    "declaration_owner_type_id": spec["declaration_id"],
                    "source_refs": [spec["contract_row_id"]],
                    "exact_name": exact_name,
                    "memid": memid,
                    "visibility": visibility,
                    "disposition": "restricted_facade" if visibility["restricted"] else "accepted_callable",
                    "disposition_basis": (
                        "Exact FUNCFLAG_FRESTRICTED"
                        if visibility["restricted"]
                        else (
                            "explicit native-pointer adapter obligation; no source signature is invented"
                            if spec.get("member_projection_override") is not None
                            else "explicit direct-facade projection for a public returned/supporting object"
                            if direct_projection
                            else "ordinary default-interface projection; hidden/nonbrowsable does not exclude"
                        )
                    ),
                    "contract": contract,
                    "actual": match,
                    "dimensions": dimensions,
                }
            )
        )
    for spec in event_specs:
        function = spec["function"]
        signature = _semantic_signature(function)
        match = _match_accessors(
            spec["coclass"]["documentation"]["name"],
            function["documentation"]["name"],
            {"func": signature},
            source_index,
            inputs["policy"],
            used_declarations,
            canonical_source_aliases,
            event=True,
        )
        dimensions = _event_dimensions(
            spec["contract_row_id"], match, int(function["memid"])
        )
        reconciliation_ref = (
            _source_ref(
                resolved_paths["w005"],
                f"row_results:{spec['w005_reconciliation_index']}",
            )
            if "w005_reconciliation_index" in spec
            else None
        )
        rows.append(
            _finalize_row(
                {
                    "row_id": spec["row_id"],
                    "row_kind": "event_projection",
                    "source_authority": "fm20_typelib",
                    "facade_owner_type_id": spec["coclass_id"],
                    "declaration_owner_type_id": spec["source_id"],
                    "source_refs": [spec["contract_row_id"]]
                    + ([reconciliation_ref] if reconciliation_ref else []),
                    "exact_name": function["documentation"]["name"],
                    "memid": function["memid"],
                    "visibility": _visibility(spec["source_type"], [function]),
                    "disposition": "accepted_event",
                    "disposition_basis": "exact source-role implementation edge; no W005 name filter",
                    "contract": {
                        "event_signature": signature,
                        "source_function_index": function["index"],
                        "implementation_edge": {
                            "index": spec["implementation"]["index"],
                            "roles": copy.deepcopy(spec["implementation"]["roles"]),
                            "target": copy.deepcopy(spec["implementation"]["target"]),
                        },
                        "w005_metadata_reconciliation": copy.deepcopy(
                            spec.get("w005_reconciliation")
                        ),
                        "w005_non_claim": "Exact W005 signature reconciliation is a metadata anchor, not runtime event-behavior proof.",
                    },
                    "actual": match,
                    "dimensions": dimensions,
                }
            )
        )

    for overlay_type in inputs["overlay"]["types"]:
        module, alias = _actual_owner(overlay_type["name"], source_index, inputs["policy"])
        overlay_type_refs = _overlay_refs(inputs["overlay"], overlay_type)
        dimensions = _dimensions_not_applicable("No member-level obligation applies to this type row.")
        dimensions["type_or_declaration"] = _dim(
            "verified",
            "The host-only type is explicitly retained from the pinned public documentation overlay.",
            overlay_type_refs,
        )
        dimensions["bind"] = (
            _dim("missing", "No CalcForms public type implements this host-only identity.")
            if module is None
            else _dim(
                (
                    "partial"
                    if alias
                    or module.get("kind") != "class_module"
                    or "clean_basproj" not in module["effective_loader_profiles"]
                    else "implemented_unverified"
                ),
                "A source type exists, but exact class-module identity and full host bind remain unverified.",
            )
        )
        rows.append(
            _finalize_row(
                {
                    "row_id": f"overlay:type:{overlay_type['name']}",
                    "row_kind": "overlay_type",
                    "source_authority": "microsoft_public_documentation",
                    "facade_owner_type_id": f"overlay:{overlay_type['name']}",
                    "declaration_owner_type_id": None,
                    "source_refs": overlay_type_refs,
                    "exact_name": overlay_type["name"],
                    "memid": None,
                    "visibility": {"hidden": False, "nonbrowsable": False, "restricted": False, "type_flags": [], "member_flags": []},
                    "disposition": "accepted_host_overlay",
                    "disposition_basis": "Typelib omission filled only by explicit public documentation.",
                    "contract": copy.deepcopy(overlay_type),
                    "actual": module,
                    "dimensions": dimensions,
                }
            )
        )

        if overlay_type.get("kind") == "intrinsic_global_collection":
            binding_name = overlay_type["name"]
            candidates, matched_binding = _global_binding_match(
                binding_name, source_index
            )
            if matched_binding is not None:
                used_declarations.add(matched_binding["source_declaration_id"])
            if not candidates:
                binding_status = "missing"
                binding_basis = (
                    "No public standard-module variable supplies the documented intrinsic global UserForms binding."
                )
                binding_evidence: list[str] = []
            elif matched_binding is None:
                binding_status = "partial"
                binding_basis = (
                    "Same-name global declaration candidates exist, but they are ambiguous or do not have the documented collection identity."
                )
                binding_evidence = [
                    declaration["source_declaration_id"] for declaration in candidates
                ]
            elif "clean_basproj" not in matched_binding.get("owner_profiles", []):
                binding_status = "partial"
                binding_basis = (
                    "The exact global collection declaration exists only through a manual loader profile."
                )
                binding_evidence = [matched_binding["source_declaration_id"]]
            else:
                binding_status = "implemented_unverified"
                binding_basis = (
                    "An exact public standard-module UserForms variable is exposed, but intrinsic global bind/runtime proof remains pending."
                )
                binding_evidence = [matched_binding["source_declaration_id"]]
            binding_dimensions = _dimensions_not_applicable(
                "This dimension does not apply to a documented intrinsic global variable binding."
            )
            binding_dimensions["type_or_declaration"] = _dim(
                "verified",
                "The pinned public documentation explicitly requires an intrinsic global variable named UserForms.",
                overlay_type_refs,
            )
            binding_dimensions["bind"] = _dim(
                binding_status, binding_basis, binding_evidence
            )
            binding_dimensions["get"] = _dim(
                binding_status, binding_basis, binding_evidence
            )
            binding_dimensions["tests"] = _dim(
                "missing",
                "No clean-project compile/bind and live collection-access test proves the intrinsic global binding.",
            )
            rows.append(
                _finalize_row(
                    {
                        "row_id": f"overlay:global-binding:{binding_name}",
                        "row_kind": "overlay_global_binding",
                        "source_authority": "microsoft_public_documentation",
                        "facade_owner_type_id": f"overlay:global:{binding_name}",
                        "declaration_owner_type_id": None,
                        "source_refs": overlay_type_refs,
                        "exact_name": binding_name,
                        "memid": None,
                        "visibility": {"hidden": False, "nonbrowsable": False, "restricted": False, "type_flags": [], "member_flags": []},
                        "disposition": "accepted_host_overlay_global_binding",
                        "disposition_basis": "The documented intrinsic global variable is a separate obligation from the collection class identity.",
                        "contract": {
                            "binding_kind": "public_standard_module_variable",
                            "binding_name": binding_name,
                            "declared_type": binding_name,
                            "documentation": copy.deepcopy(overlay_type),
                        },
                        "actual": {
                            "candidates": copy.deepcopy(candidates),
                            "matched": copy.deepcopy(matched_binding),
                        },
                        "dimensions": binding_dimensions,
                    }
                )
            )

    for capability_index, capability in enumerate(
        inputs["overlay"].get("capabilities", [])
    ):
        capability_refs = _overlay_refs(inputs["overlay"], capability)
        module, alias = _actual_owner(
            capability["owner"], source_index, inputs["policy"]
        )
        dimensions = _dimensions_not_applicable(
            "This prose-only host capability has no invented member signature."
        )
        dimensions["type_or_declaration"] = _dim(
            "verified",
            "The public host capability is explicitly documented.",
            capability_refs,
        )
        dimensions["bind"] = _dim(
            "missing"
            if module is None
            else "partial",
            "No compatible host collection/capability bind is proven."
            if module is None
            else "A same-name source owner exists, but the prose-only capability has no decisive bind proof.",
        )
        dimensions["default_binding"] = _dim(
            "missing",
            "Enumeration/For Each capability is documented, but no exact bind proof is attached and no hidden member identity is inferred.",
        )
        dimensions["tests"] = _dim(
            "missing", "No decisive host enumeration conformance test is attached."
        )
        rows.append(
            _finalize_row(
                {
                    "row_id": (
                        f"overlay:capability:{capability_index:03d}:"
                        f"{capability['owner']}.{capability['name']}"
                    ),
                    "row_kind": "overlay_capability",
                    "source_authority": "microsoft_public_documentation",
                    "facade_owner_type_id": f"overlay:{capability['owner']}",
                    "declaration_owner_type_id": None,
                    "source_refs": capability_refs,
                    "exact_name": capability["name"],
                    "memid": None,
                    "visibility": {"hidden": False, "nonbrowsable": False, "restricted": False, "type_flags": [], "member_flags": []},
                    "disposition": "accepted_host_overlay",
                    "disposition_basis": "Documented host capability retained without inventing a callable member identity.",
                    "contract": copy.deepcopy(capability),
                    "actual": {"source": module, "wrong_name_alias": alias},
                    "dimensions": dimensions,
                }
            )
        )

    for member_index, member in enumerate(inputs["overlay"]["members"]):
        kind = member["kind"]
        if kind == "property_get_put":
            accessors = {
                "get": _overlay_signature(member, "get"),
                "put": _overlay_signature(
                    {
                        **member,
                        "return_type": None,
                        "parameters": member.get("parameters", [])
                        + [
                            {
                                "name": "Value",
                                "type": member["return_type"],
                                "passing": "byref",
                                "passing_state": "undocumented_synthetic",
                                "name_state": "undocumented_synthetic",
                                "optional": False,
                                "default": None,
                            }
                        ],
                    },
                    "put",
                ),
            }
        else:
            accessor = {
                "property_get": "get",
                "function": "func",
                "sub": "func",
            }[kind]
            accessors = {accessor: _overlay_signature(member, accessor)}
        match = _match_overlay_accessors(
            member,
            accessors,
            source_index,
            inputs["policy"],
            used_declarations,
        )
        overlay_member_refs = _overlay_refs(inputs["overlay"], member)
        group = {
            "contract_row_id": f"overlay:member:{member_index:03d}:{member['owner']}.{member['name']}",
            "memid": None,
            "accessors": accessors,
            "default_member": bool(member.get("default_member")),
            "new_enum": False,
        }
        dimensions = _surface_dimensions(group, match, False, None)
        dimensions["type_or_declaration"] = _dim(
            "verified",
            "The documentation-shape member obligation is retained from pinned official Microsoft pages; no typelib-exact identity is inferred.",
            overlay_member_refs,
        )
        rows.append(
            _finalize_row(
                {
                    "row_id": group["contract_row_id"],
                    "row_kind": "overlay_member",
                    "source_authority": "microsoft_public_documentation",
                    "facade_owner_type_id": f"overlay:{member['owner']}",
                    "declaration_owner_type_id": None,
                    "source_refs": overlay_member_refs,
                    "exact_name": member["name"],
                    "memid": None,
                    "visibility": {"hidden": False, "nonbrowsable": False, "restricted": False, "type_flags": [], "member_flags": []},
                    "disposition": "accepted_host_overlay",
                    "disposition_basis": member["signature_precision"],
                    "contract": {"accessors": accessors, "documentation": copy.deepcopy(member)},
                    "actual": match,
                    "dimensions": dimensions,
                }
            )
        )

    for event_index, event in enumerate(inputs["overlay"]["events"]):
        event_member = {
            **event,
            "kind": "event",
            "return_type": None,
        }
        signature = _overlay_signature(event_member, "func")
        match = _match_overlay_accessors(
            event_member,
            {"func": signature},
            source_index,
            inputs["policy"],
            used_declarations,
            event=True,
        )
        overlay_event_refs = _overlay_refs(inputs["overlay"], event)
        dimensions = _event_dimensions(
            f"overlay:event:{event_index:03d}:{event['owner']}.{event['name']}",
            match,
            None,
        )
        dimensions["type_or_declaration"] = _dim(
            "verified",
            "The lifecycle-event obligation is retained from pinned official Microsoft documentation; no FM20 source-interface identity is inferred.",
            overlay_event_refs,
        )
        rows.append(
            _finalize_row(
                {
                    "row_id": f"overlay:event:{event_index:03d}:{event['owner']}.{event['name']}",
                    "row_kind": "overlay_event",
                    "source_authority": "microsoft_public_documentation",
                    "facade_owner_type_id": f"overlay:{event['owner']}",
                    "declaration_owner_type_id": None,
                    "source_refs": overlay_event_refs,
                    "exact_name": event["name"],
                    "memid": None,
                    "visibility": {"hidden": False, "nonbrowsable": False, "restricted": False, "type_flags": [], "member_flags": []},
                    "disposition": "accepted_host_overlay",
                    "disposition_basis": "Public lifecycle event absent from captured FM20 source interfaces.",
                    "contract": {"event_signature": signature, "documentation": copy.deepcopy(event)},
                    "actual": match,
                    "dimensions": dimensions,
                }
            )
        )

    root_coclass_by_name: dict[str, dict[str, Any]] = {}
    for coclass in root_primary_coclasses:
        name_key = coclass["documentation"]["name"].casefold()
        if name_key in root_coclass_by_name:
            raise LedgerError(f"duplicate root coclass name {name_key!r}")
        root_coclass_by_name[name_key] = coclass
    for attachment_index, attachment in enumerate(
        inputs["overlay"].get("host_event_attachments", [])
    ):
        facade = root_coclass_by_name.get(attachment["owner"].casefold())
        if facade is None:
            raise LedgerError(
                f"host event attachment owner is not one exact root coclass: {attachment['owner']!r}"
            )
        source_fact = attachment["canonical_source"]
        source_key = (
            source_fact["library_key"],
            int(source_fact["type_index"]),
            source_fact["view"],
        )
        source_type = type_lookup.get(source_key)
        if source_type is None:
            raise LedgerError(
                f"host event attachment has unresolved canonical source {source_key!r}"
            )
        matching_groups = [
            group
            for group in group_lookup[source_key]
            if int(group["memid"]) == int(source_fact["memid"])
            and group["name"] == attachment["name"]
        ]
        if len(matching_groups) != 1 or set(matching_groups[0]["accessors"]) != {"func"}:
            raise LedgerError(
                f"host event attachment does not resolve one exact event contract: {attachment!r}"
            )
        group = matching_groups[0]
        signature = group["accessors"]["func"]
        facade_id = _type_id(root_library["key"], facade)
        source_id = _type_id(source_key[0], source_type)
        contract_ref = _function_contract_id(source_id, group["memid"])
        match = _match_accessors(
            attachment["owner"],
            attachment["name"],
            {"func": signature},
            source_index,
            inputs["policy"],
            used_declarations,
            canonical_source_aliases,
            event=True,
        )
        dimensions = _event_dimensions(contract_ref, match, int(group["memid"]))
        attachment_refs = _overlay_refs(inputs["overlay"], attachment)
        dimensions["oracle"] = _dim(
            "partial",
            "Committed black-box evidence proves this concrete host attachment, but not every ordering, mutation, reentrancy, and error behavior for the row.",
            attachment["evidence"],
        )
        row_id = (
            f"host-event:{facade_id}|source={source_id}|memid={group['memid']}"
        )
        rows.append(
            _finalize_row(
                {
                    "row_id": row_id,
                    "row_kind": "host_event_attachment",
                    "source_authority": "fm20_typelib_plus_public_docs_and_oracle",
                    "facade_owner_type_id": facade_id,
                    "declaration_owner_type_id": source_id,
                    "source_refs": [contract_ref] + attachment_refs,
                    "exact_name": attachment["name"],
                    "memid": group["memid"],
                    "visibility": _visibility(source_type, group["functions"]),
                    "disposition": "accepted_host_event_attachment",
                    "disposition_basis": "Concrete host attachment is oracle-observed; it is not inferred from the FM20 coclass graph.",
                    "contract": {
                        "event_signature": copy.deepcopy(signature),
                        "canonical_source": copy.deepcopy(source_fact),
                        "host_attachment": copy.deepcopy(attachment),
                    },
                    "actual": match,
                    "dimensions": dimensions,
                }
            )
        )
        projection_contract = next(
            (
                row
                for row in rows
                if row["row_kind"] == "declaration_member"
                and row["row_id"] == contract_ref
            ),
            None,
        )
        if projection_contract is None:
            raise LedgerError(
                f"host event attachment contract row is absent: {contract_ref}"
            )
        projection_contract["projection_refs"].append(row_id)

    property_facts_by_name: dict[str, dict[str, Any]] = {}
    for property_fact in inputs["ms_oforms"]["properties"]:
        key = property_fact["name"].casefold()
        if key in property_facts_by_name:
            raise LedgerError(f"duplicate MS-OFORMS property {property_fact['name']!r}")
        property_facts_by_name[key] = property_fact

    defaults_by_property: dict[str, list[dict[str, Any]]] = defaultdict(list)
    default_row_ids: set[str] = set()
    for default in inputs["ms_oforms"]["default_matrix"]:
        row_id = default["row_id"]
        if row_id in default_row_ids:
            raise LedgerError(f"duplicate MS-OFORMS default row_id {row_id!r}")
        default_row_ids.add(row_id)
        key = default["property"].casefold()
        if key not in property_facts_by_name:
            raise LedgerError(
                f"orphan MS-OFORMS default for unknown property {default['property']!r}"
            )
        property_fact = property_facts_by_name[key]
        if default["property_section"] != property_fact["section"]:
            raise LedgerError(
                f"default {row_id!r} points at the wrong property section"
            )
        if not set(default["applies_to"]).issubset(set(property_fact["applies_to"])):
            raise LedgerError(
                f"default {row_id!r} has applicability outside its property"
            )
        defaults_by_property[key].append(default)

    mappings_by_property: dict[str, dict[str, Any]] = {}
    for mapping in inputs["frm_frx"]["property_mappings"]:
        key = mapping["name"].casefold()
        if key in mappings_by_property:
            raise LedgerError(f"duplicate FRM/FRX property mapping {mapping['name']!r}")
        mappings_by_property[key] = mapping
    if set(mappings_by_property) != set(property_facts_by_name):
        missing = sorted(set(property_facts_by_name) - set(mappings_by_property))
        extra = sorted(set(mappings_by_property) - set(property_facts_by_name))
        raise LedgerError(
            f"FRM/FRX property mapping set differs from MS-OFORMS properties; missing={missing!r}, extra={extra!r}"
        )
    for key, mapping in mappings_by_property.items():
        property_fact = property_facts_by_name[key]
        family_names = [coverage["family"] for coverage in mapping["family_coverage"]]
        if (
            mapping["name"] != property_fact["name"]
            or mapping["section"] != property_fact["section"]
            or mapping["applies_to"] != property_fact["applies_to"]
            or family_names != property_fact["applies_to"]
            or len(set(name.casefold() for name in family_names)) != len(family_names)
        ):
            raise LedgerError(
                f"FRM/FRX mapping identity/applicability differs for {mapping['name']!r}"
            )

    def add_persistence_fact_row(
        *,
        row_id: str,
        row_kind: str,
        authority: str,
        owner: str,
        name: str,
        source_ref: str,
        contract: dict[str, Any],
        implementation_bearing: bool,
        basis: str,
    ) -> None:
        dimensions = _dimensions_not_applicable(
            "This persistence fact is not a runtime API declaration."
        )
        dimensions["type_or_declaration"] = _dim(
            "verified", "The canonical persistence fact is retained exactly.", [source_ref]
        )
        if implementation_bearing:
            dimensions["persistence"] = _dim(
                "missing",
                "No decisive CalcForms parser/serializer/round-trip implementation proof is attached for this exact fact.",
            )
            dimensions["tests"] = _dim(
                "missing", "No decisive fact-level persistence conformance test is attached."
            )
        rows.append(
            _finalize_row(
                {
                    "row_id": row_id,
                    "row_kind": row_kind,
                    "source_authority": authority,
                    "facade_owner_type_id": owner,
                    "declaration_owner_type_id": None,
                    "source_refs": [source_ref],
                    "exact_name": name,
                    "memid": None,
                    "visibility": {"hidden": False, "nonbrowsable": False, "restricted": False, "type_flags": [], "member_flags": []},
                    "disposition": (
                        "accepted_persistence_fact"
                        if implementation_bearing
                        else "accepted_persistence_provenance_aggregate"
                    ),
                    "disposition_basis": basis,
                    "contract": contract,
                    "actual": None,
                    "dimensions": dimensions,
                }
            )
        )

    ms_fact_categories = (
        "default_matrix",
        "enumerations",
        "record_sections",
        "record_fields",
        "bitfields",
        "property_types",
        "resource_formats",
        "value_maps",
        "algorithms",
        "cached_control_ids",
        "control_families",
        "product_behavior",
        "documented_unknowns",
        "external_references",
        "worked_examples",
    )
    for category in ms_fact_categories:
        for fact_index, fact in enumerate(inputs["ms_oforms"][category]):
            display_name = str(
                fact.get("name")
                or fact.get("property")
                or fact.get("cached_id")
                or fact.get("family_id")
                or fact.get("map_id")
                or fact.get("reference")
                or fact.get("heading")
                or f"{category}[{fact_index}]"
            )
            source_ref = _source_ref(
                resolved_paths["ms_oforms"], f"{category}:{fact_index}"
            )
            add_persistence_fact_row(
                row_id=f"persistence:ms-oforms:{category}:{fact_index:04d}",
                row_kind="persistence_ms_oforms_fact",
                authority="ms_oforms",
                owner=f"persistence:ms-oforms:{category}",
                name=display_name,
                source_ref=source_ref,
                contract={"category": category, "fact": copy.deepcopy(fact)},
                implementation_bearing=True,
                basis="Canonical semantic MS-OFORMS fact at declared row granularity.",
            )
            child_key = (
                "values"
                if category in {"enumerations", "value_maps"}
                else "entries" if category == "bitfields" else None
            )
            if child_key is not None:
                for child_index, child in enumerate(fact[child_key]):
                    child_name = str(
                        child.get("name")
                        or child.get("field_name")
                        or child.get("symbol")
                        or child.get("value_text")
                        or f"{child_key}[{child_index}]"
                    )
                    child_ref = _source_ref(
                        resolved_paths["ms_oforms"],
                        f"{category}:{fact_index}:{child_key}:{child_index}",
                    )
                    add_persistence_fact_row(
                        row_id=(
                            f"persistence:ms-oforms:{category}:{fact_index:04d}:"
                            f"{child_key}:{child_index:04d}"
                        ),
                        row_kind="persistence_ms_oforms_fact",
                        authority="ms_oforms",
                        owner=f"persistence:ms-oforms:{category}:{display_name}",
                        name=child_name,
                        source_ref=child_ref,
                        contract={
                            "category": f"{category}.{child_key}",
                            "parent_index": fact_index,
                            "parent_name": display_name,
                            "fact": copy.deepcopy(child),
                        },
                        implementation_bearing=True,
                        basis="Canonical nested MS-OFORMS value/bit entry retained as its own gating fact.",
                    )

    ms_aggregate_categories = (
        "boundaries",
        "capture",
        "sections",
        "source_rows",
        "sources",
        "summary",
        "table_rows",
    )
    for category in ms_aggregate_categories:
        value = inputs["ms_oforms"][category]
        count = len(value) if isinstance(value, (list, dict)) else None
        source_ref = _source_ref(resolved_paths["ms_oforms"], category)
        add_persistence_fact_row(
            row_id=f"persistence:aggregate:ms-oforms:{category}",
            row_kind="persistence_aggregate",
            authority="ms_oforms",
            owner="persistence:ms-oforms:coverage",
            name=category,
            source_ref=source_ref,
            contract={
                "category": category,
                "granularity": "aggregate_provenance_or_index_coverage",
                "count": count,
                "semantic_sha256": semantic_sha256(value),
                "non_claim": "Aggregate coverage pins extraction provenance/index material; it is not a substitute for semantic implementation rows.",
            },
            implementation_bearing=False,
            basis="Exact aggregate digest/count coverage for provenance or source-index material.",
        )

    frm_fact_categories = (
        "cfb_inventories",
        "code_boundaries",
        "fixtures",
        "legacy_synthetic_corpus",
        "profiles",
        "resource_references",
        "unknown_preservation",
    )
    for category in frm_fact_categories:
        for fact_index, fact in enumerate(inputs["frm_frx"][category]):
            display_name = str(
                fact.get("fixture_id")
                or fact.get("id")
                or fact.get("profile")
                or fact.get("surface")
                or f"{category}[{fact_index}]"
            )
            source_ref = _source_ref(
                resolved_paths["frm_frx"], f"{category}:{fact_index}"
            )
            add_persistence_fact_row(
                row_id=f"persistence:frm-frx:{category}:{fact_index:04d}",
                row_kind="persistence_frm_frx_fact",
                authority="frm_frx",
                owner=f"persistence:frm-frx:{category}",
                name=display_name,
                source_ref=source_ref,
                contract={"category": category, "fact": copy.deepcopy(fact)},
                implementation_bearing=True,
                basis="Canonical semantic FRM/FRX fact retained at declared row granularity.",
            )

    def add_frm_contract_rows(
        category: str,
        values: list[Any],
        *,
        implementation_bearing: bool,
        source_fragment: str,
        basis: str,
    ) -> None:
        for fact_index, fact in enumerate(values):
            if isinstance(fact, dict):
                display_name = str(
                    fact.get("name")
                    or fact.get("property")
                    or fact.get("family")
                    or fact.get("progid")
                    or fact.get("section")
                    or fact.get("fixture_id")
                    or fact.get("collection")
                    or f"{category}[{fact_index}]"
                )
            else:
                display_name = str(fact)
            add_persistence_fact_row(
                row_id=f"persistence:frm-frx:{category}:{fact_index:04d}",
                row_kind="persistence_frm_frx_fact",
                authority="frm_frx",
                owner=f"persistence:frm-frx:{category}",
                name=display_name,
                source_ref=_source_ref(
                    resolved_paths["frm_frx"],
                    f"{source_fragment}:{fact_index}",
                ),
                contract={"category": category, "fact": copy.deepcopy(fact)},
                implementation_bearing=implementation_bearing,
                basis=basis,
            )

    binary_contract = inputs["frm_frx"]["binary_persistence_contract"]
    binary_semantic_lists = {
        "binary_persistence_contract.binary_length_forms.record_fields": binary_contract[
            "binary_length_forms"
        ]["record_fields"],
        "binary_persistence_contract.binary_length_forms.resource_format_codecs": binary_contract[
            "binary_length_forms"
        ]["resource_format_codecs"],
        "binary_persistence_contract.object_valued_encodings.presence_flags": binary_contract[
            "object_valued_encodings"
        ]["presence_flags"],
        "binary_persistence_contract.object_valued_encodings.properties": binary_contract[
            "object_valued_encodings"
        ]["properties"],
        "binary_persistence_contract.object_valued_encodings.resource_formats": binary_contract[
            "object_valued_encodings"
        ]["resource_formats"],
        "binary_persistence_contract.object_valued_encodings.stream_data_slots": binary_contract[
            "object_valued_encodings"
        ]["stream_data_slots"],
        "binary_persistence_contract.object_valued_encodings.type_layouts": binary_contract[
            "object_valued_encodings"
        ]["type_layouts"],
        "binary_persistence_contract.omission_and_defaults.control_specific_default_matrix": binary_contract[
            "omission_and_defaults"
        ]["control_specific_default_matrix"],
        "binary_persistence_contract.omission_and_defaults.property_defaults": binary_contract[
            "omission_and_defaults"
        ]["property_defaults"],
        "binary_persistence_contract.omission_and_defaults.property_masks": binary_contract[
            "omission_and_defaults"
        ]["property_masks"],
        "binary_persistence_contract.omission_and_defaults.storage_requirements": binary_contract[
            "omission_and_defaults"
        ]["storage_requirements"],
    }
    for category, values in binary_semantic_lists.items():
        add_frm_contract_rows(
            category,
            values,
            implementation_bearing=True,
            source_fragment=category,
            basis=(
                "Stable leaf obligation extracted from the canonical binary persistence "
                "contract; aggregate hashes cannot close this row."
            ),
        )

    binary_nonclaim_cells: list[tuple[str, Any]] = [
        ("authority", binary_contract["authority"]),
        (
            "binary_length_forms.nonzero_textual_offset_claims",
            binary_contract["binary_length_forms"]["nonzero_textual_offset_claims"],
        ),
        (
            "binary_length_forms.textual_length_claims",
            binary_contract["binary_length_forms"]["textual_length_claims"],
        ),
        (
            "binary_length_forms.textual_ole_object_blob_observation",
            binary_contract["binary_length_forms"][
                "textual_ole_object_blob_observation"
            ],
        ),
        (
            "object_valued_encodings.decoded_live_values",
            binary_contract["object_valued_encodings"]["decoded_live_values"],
        ),
        (
            "object_valued_encodings.live_nondefault_object_probes",
            binary_contract["object_valued_encodings"][
                "live_nondefault_object_probes"
            ],
        ),
    ]
    binary_nonclaim_cells.extend(
        (
            f"binary_length_forms.record_field_group_counts.{name}",
            value,
        )
        for name, value in binary_contract["binary_length_forms"][
            "record_field_group_counts"
        ].items()
    )
    binary_nonclaim_cells.extend(
        (f"omission_and_defaults.property_default_status_counts.{name}", value)
        for name, value in binary_contract["omission_and_defaults"][
            "property_default_status_counts"
        ].items()
    )
    binary_nonclaim_cells.extend(
        (f"source_universe_counts.{name}", value)
        for name, value in binary_contract["source_universe_counts"].items()
    )
    add_frm_contract_rows(
        "binary_persistence_contract.nonclaim_or_census_cell",
        [
            {"field": field, "value": copy.deepcopy(value)}
            for field, value in binary_nonclaim_cells
        ],
        implementation_bearing=False,
        source_fragment="binary_persistence_contract",
        basis=(
            "Exact boundary/census cell retained as a verified nonclaim; it is not "
            "an implementation obligation."
        ),
    )
    add_frm_contract_rows(
        "binary_persistence_contract.binary_length_forms.selection_boundary",
        [binary_contract["binary_length_forms"]["selection_boundary"]],
        implementation_bearing=True,
        source_fragment="binary_persistence_contract:binary_length_forms:selection_boundary",
        basis="Exact binary-field selection boundary retained as its own implementation obligation.",
    )

    add_frm_contract_rows(
        "boundaries",
        [
            {"field": field, "value": copy.deepcopy(value)}
            for field, value in inputs["frm_frx"]["boundaries"].items()
        ],
        implementation_bearing=False,
        source_fragment="boundaries",
        basis="Authority limit/nonclaim retained exactly and deliberately non-gating.",
    )

    cfb_rules = inputs["frm_frx"]["cfb_source_rules"]
    add_frm_contract_rows(
        "cfb_source_rules.selected_sections",
        cfb_rules["selected_sections"],
        implementation_bearing=True,
        source_fragment="cfb_source_rules:selected_sections",
        basis="Selected authoritative CFB rule group retained as a separate parser/serializer obligation.",
    )
    add_frm_contract_rows(
        "cfb_source_rules.strict_inventory_policy",
        cfb_rules["strict_inventory_policy"],
        implementation_bearing=True,
        source_fragment="cfb_source_rules:strict_inventory_policy",
        basis="Strict CFB inventory rule retained as a separate implementation obligation.",
    )

    component_headers = inputs["frm_frx"]["component_headers"]
    add_frm_contract_rows(
        "component_headers.boundary_policy",
        [component_headers["boundary_policy"]],
        implementation_bearing=True,
        source_fragment="component_headers:boundary_policy",
        basis="Component-header boundary rule retained as a separate parser obligation.",
    )
    add_frm_contract_rows(
        "component_headers.fixtures",
        component_headers["fixtures"],
        implementation_bearing=True,
        source_fragment="component_headers:fixtures",
        basis="Exact component-header fixture retained as a separate conformance obligation.",
    )
    add_frm_contract_rows(
        "component_headers.observed_attribute_order",
        [component_headers["observed_attribute_order"]],
        implementation_bearing=True,
        source_fragment="component_headers:observed_attribute_order",
        basis="Observed canonical component-attribute order retained as a separate obligation.",
    )

    identifiers = inputs["frm_frx"]["control_identifiers"]
    control_identifier_lists = {
        "designer_add_probes": (identifiers["designer_add_probes"], True),
        "forward_progid_fm20_coclass_joins": (
            identifiers["forward_progid_fm20_coclass_joins"],
            True,
        ),
        "live_progid_registrations": (
            identifiers["live_progid_registrations"],
            False,
        ),
        "ms_oforms_cached_control_ids": (
            identifiers["ms_oforms_cached_control_ids"],
            True,
        ),
        "observed_instances": (identifiers["observed_instances"], True),
        "observed_intrinsic_families": (
            identifiers["observed_intrinsic_families"],
            True,
        ),
    }
    for name, (values, implementation_bearing) in control_identifier_lists.items():
        add_frm_contract_rows(
            f"control_identifiers.{name}",
            values,
            implementation_bearing=implementation_bearing,
            source_fragment=f"control_identifiers:{name}",
            basis=(
                "Control-identity leaf retained as a separate implementation obligation."
                if implementation_bearing
                else "Environment registration observation retained as verified provenance."
            ),
        )
    for name, value in identifiers["fm20_control_universe"].items():
        values = value if isinstance(value, list) else [value]
        add_frm_contract_rows(
            f"control_identifiers.fm20_control_universe.{name}",
            values,
            implementation_bearing=True,
            source_fragment=f"control_identifiers:fm20_control_universe:{name}",
            basis="Exact FM20 control-identity leaf retained as a separate bind/persistence obligation.",
        )
    add_frm_contract_rows(
        "control_identifiers.html_probe_boundary",
        [identifiers["html_probe_boundary"]],
        implementation_bearing=False,
        source_fragment="control_identifiers:html_probe_boundary",
        basis="HTML probe authority boundary retained as a verified nonclaim.",
    )

    add_frm_contract_rows(
        "coverage",
        [
            {"field": field, "value": value}
            for field, value in inputs["frm_frx"]["coverage"].items()
        ],
        implementation_bearing=False,
        source_fragment="coverage",
        basis="Coverage statement retained as verified provenance, never as implementation proof.",
    )

    designer_properties = inputs["frm_frx"]["designer_properties"]
    for name in ("controlled_omission_pairs", "normative_ordered_universe"):
        add_frm_contract_rows(
            f"designer_properties.{name}",
            designer_properties[name],
            implementation_bearing=True,
            source_fragment=f"designer_properties:{name}",
            basis="Designer-property leaf retained as a separate grammar/serialization obligation.",
        )

    grammar = inputs["frm_frx"]["grammar"]
    for group_name, group in grammar.items():
        for field_name, value in group.items():
            implementation_bearing = field_name not in {
                "authority",
                "normative_status",
            }
            add_frm_contract_rows(
                f"grammar.{group_name}.{field_name}",
                [value],
                implementation_bearing=implementation_bearing,
                source_fragment=f"grammar:{group_name}:{field_name}",
                basis=(
                    "Grammar/profile rule retained as a separate parser/serializer obligation."
                    if implementation_bearing
                    else "Grammar authority/classification metadata retained as verified provenance."
                ),
            )

    frm_aggregate_categories = {
        "binary_persistence_contract": False,
        "boundaries": False,
        "cfb_source_rules": False,
        "component_headers": False,
        "control_identifiers": False,
        "coverage": False,
        "designer_properties": False,
        "generator": False,
        "grammar": False,
        "source_rows": False,
        "sources": False,
        "summary": False,
    }
    for category, implementation_bearing in frm_aggregate_categories.items():
        value = inputs["frm_frx"][category]
        count = len(value) if isinstance(value, (list, dict)) else None
        source_ref = _source_ref(resolved_paths["frm_frx"], category)
        add_persistence_fact_row(
            row_id=f"persistence:aggregate:frm-frx:{category}",
            row_kind="persistence_aggregate",
            authority="frm_frx",
            owner="persistence:frm-frx:coverage",
            name=category,
            source_ref=source_ref,
            contract={
                "category": category,
                "granularity": "aggregate_semantic_or_provenance_coverage",
                "count": count,
                "semantic_sha256": semantic_sha256(value),
                "implementation_bearing": implementation_bearing,
            },
            implementation_bearing=implementation_bearing,
            basis="Exact aggregate digest/count coverage for a canonical FRM/FRX category.",
        )

    for property_fact in inputs["ms_oforms"]["properties"]:
        mapping = mappings_by_property.get(property_fact["name"].casefold())
        if mapping is None:
            raise LedgerError(f"missing FRM/FRX property mapping for {property_fact['name']}")
        dimensions = _dimensions_not_applicable("This is a persistence contract, not an API declaration.")
        dimensions["type_or_declaration"] = _dim(
            "verified",
            "The MS-OFORMS property/default contract and FRM/FRX mapping are pinned.",
            [f"persistence-property:{property_fact['name']}"],
        )
        dimensions["persistence"] = _dim(
            "missing",
            "Canonical file-format facts exist, but CalcForms round-trip implementation/evidence is not complete.",
        )
        dimensions["tests"] = _dim(
            "missing", "No decisive CalcForms property/family round-trip test is attached."
        )
        rows.append(
            _finalize_row(
                {
                    "row_id": f"persistence-property:{property_fact['name']}",
                    "row_kind": "persistence_property",
                    "source_authority": "ms_oforms_and_frm_frx",
                    "facade_owner_type_id": None,
                    "declaration_owner_type_id": None,
                    "source_refs": [
                        _source_ref(resolved_paths["ms_oforms"], f"property:{property_fact['name']}"),
                        _source_ref(resolved_paths["frm_frx"], f"property_mapping:{property_fact['name']}"),
                    ],
                    "exact_name": property_fact["name"],
                    "memid": None,
                    "visibility": {"hidden": False, "nonbrowsable": False, "restricted": False, "type_flags": [], "member_flags": []},
                    "disposition": "accepted_persistence_contract",
                    "disposition_basis": "Internal/context-only properties remain rows and are not converted into API members.",
                    "contract": {
                        "property": copy.deepcopy(property_fact),
                        "default_matrix": copy.deepcopy(defaults_by_property[property_fact["name"].casefold()]),
                        "frm_frx_mapping": copy.deepcopy(mapping),
                    },
                    "actual": None,
                    "dimensions": dimensions,
                }
            )
        )

    for mapping, coverage in persistence_pair_specs:
        dimensions = _dimensions_not_applicable("This is a family-specific persistence projection.")
        dimensions["type_or_declaration"] = _dim(
            "verified",
            "The exact property/family applicability row is retained.",
            [f"persistence-family:{mapping['name']}|{coverage['family']}"],
        )
        dimensions["persistence"] = _dim(
            "missing",
            "The live export observation is not an CalcForms parser/serializer/round-trip implementation claim.",
        )
        dimensions["tests"] = _dim(
            "missing", "No decisive CalcForms family-specific round-trip test is attached."
        )
        rows.append(
            _finalize_row(
                {
                    "row_id": f"persistence-family:{mapping['name']}|{coverage['family']}",
                    "row_kind": "persistence_family_property",
                    "source_authority": "ms_oforms_and_frm_frx",
                    "facade_owner_type_id": f"family:{coverage['family']}",
                    "declaration_owner_type_id": None,
                    "source_refs": [f"persistence-property:{mapping['name']}"],
                    "exact_name": mapping["name"],
                    "memid": None,
                    "visibility": {"hidden": False, "nonbrowsable": False, "restricted": False, "type_flags": [], "member_flags": []},
                    "disposition": "accepted_persistence_projection",
                    "disposition_basis": mapping["classification"],
                    "contract": {
                        "family": coverage["family"],
                        "coverage": copy.deepcopy(coverage),
                        "observed_as": mapping["observed_as"],
                        "runtime_api_claim": mapping["runtime_api_claim"],
                        "binary_value_decoded": mapping["binary_value_decoded"],
                    },
                    "actual": None,
                    "dimensions": dimensions,
                }
            )
        )

    canonical_type_names = {
        row["exact_name"].casefold()
        for row in rows
        if row["row_kind"] in {"type_contract", "overlay_type"}
        and row["contract"].get("view", "primary") == "primary"
    }
    alias_actual_names = {
        value.casefold() for value in inputs["policy"]["canonical_module_aliases"].values()
    }
    for module in surface["modules"]:
        if module["kind"] != "class_module":
            continue
        name_key = module["name"].casefold()
        if name_key in canonical_type_names and name_key not in alias_actual_names:
            continue
        dimensions = _dimensions_not_applicable("Unexpected public type has no canonical contract dimensions.")
        dimensions["type_or_declaration"] = _dim(
            "partial",
            "A public/forced-public CalcForms class has no exact canonical MSForms type identity.",
            [module["path"]],
        )
        dimensions["bind"] = _dim(
            "partial", "The type is exposed in at least one current loader profile outside the canonical facade."
        )
        dimensions["tests"] = _dim("missing", "No boundary test proves this type is hidden from consumers.")
        rows.append(
            _finalize_row(
                {
                    "row_id": f"unexpected-public-type:{module['name']}",
                    "row_kind": "unexpected_public_type",
                    "source_authority": "oxforms_vba_surface",
                    "facade_owner_type_id": None,
                    "declaration_owner_type_id": None,
                    "source_refs": [module["path"]],
                    "exact_name": module["name"],
                    "memid": None,
                    "visibility": {"hidden": False, "nonbrowsable": False, "restricted": False, "type_flags": [], "member_flags": []},
                    "disposition": "unexpected_public",
                    "disposition_basis": "No fuzzy/type-name alias can make a noncanonical public class green.",
                    "contract": None,
                    "actual": module,
                    "dimensions": dimensions,
                }
            )
        )

    for declaration_id, declaration in source_index["declaration_by_id"].items():
        if declaration_id in used_declarations:
            continue
        dimensions = _dimensions_not_applicable("Unexpected public member has no canonical contract dimensions.")
        dimensions["type_or_declaration"] = _dim(
            "partial", "Declared-public CalcForms member is not mapped to any accepted canonical row.", [declaration_id]
        )
        dimensions["bind"] = _dim(
            "partial", "The unexpected member is reachable in one or more current exposure profiles."
        )
        dimensions["tests"] = _dim("missing", "No boundary test proves the unexpected member is inaccessible.")
        rows.append(
            _finalize_row(
                {
                    "row_id": f"unexpected-public-member:{declaration_id}",
                    "row_kind": "unexpected_public_member",
                    "source_authority": "oxforms_vba_surface",
                    "facade_owner_type_id": None,
                    "declaration_owner_type_id": None,
                    "source_refs": [declaration_id],
                    "exact_name": declaration["name"],
                    "memid": None,
                    "visibility": {"hidden": False, "nonbrowsable": False, "restricted": False, "type_flags": [], "member_flags": []},
                    "disposition": "unexpected_public",
                    "disposition_basis": "Every unmapped public declaration remains a failing row.",
                    "contract": None,
                    "actual": declaration,
                    "dimensions": dimensions,
                }
            )
        )

    for member_id, member in source_index["nested_member_by_id"].items():
        if member_id in used_nested_members:
            continue
        dimensions = _dimensions_not_applicable("Unexpected nested public member has no canonical contract dimensions.")
        dimensions["type_or_declaration"] = _dim(
            "partial", "Public enum/UDT member is not mapped to an exact canonical variable/field row.", [member_id]
        )
        dimensions["bind"] = _dim("partial", "Unexpected nested public declaration remains exposed with its container.")
        dimensions["tests"] = _dim("missing", "No boundary/value test covers this unexpected nested member.")
        rows.append(
            _finalize_row(
                {
                    "row_id": f"unexpected-public-nested:{member_id}",
                    "row_kind": "unexpected_public_nested_member",
                    "source_authority": "oxforms_vba_surface",
                    "facade_owner_type_id": None,
                    "declaration_owner_type_id": None,
                    "source_refs": [member_id],
                    "exact_name": member["name"],
                    "memid": None,
                    "visibility": {"hidden": False, "nonbrowsable": False, "restricted": False, "type_flags": [], "member_flags": []},
                    "disposition": "unexpected_public",
                    "disposition_basis": "Every unused public enum constant or UDT field remains explicit, whether or not its container was mapped.",
                    "contract": None,
                    "actual": member,
                    "dimensions": dimensions,
                }
            )
        )

    provenance_paths = sorted(
        set(resolved_paths.values())
        | {
            "Cargo.toml",
            f"{_REVIEWED_ADAPTER_CRATE}/Cargo.toml",
            *_ADAPTER_REVIEWED_TOKEN_SHA256,
            *(
                f"{target['crate']}/Cargo.toml"
                for target in _LOADER_CARGO_TARGETS.values()
            ),
        }
        | {
            profile["source_path"]
            for profile in inputs["policy"]["effective_loader_profiles"]
        }
        | {
            path
            for attachment in inputs["overlay"].get("host_event_attachments", [])
            for path in attachment.get("evidence", [])
        }
    )
    provenance = []
    for path in provenance_paths:
        full_path = repo_root / path
        if not full_path.is_file():
            raise LedgerError(f"missing provenance input {path}")
        raw = full_path.read_bytes()
        try:
            _, normalized = normalized_utf8_text(raw)
        except UnicodeDecodeError:
            provenance.append(
                {
                    "path": path,
                    "hash_mode": "raw",
                    "sha256": sha256_bytes(raw),
                }
            )
        else:
            provenance.append(
                {
                    "path": path,
                    "hash_mode": "utf8_lf",
                    "sha256": sha256_bytes(normalized),
                }
            )

    summary = _summary(rows, surface["summary"])
    canonical = {
        "inputs": provenance,
        "source_surface_sha256": surface["canonical_sha256"],
        "rows": rows,
        "summary": summary,
    }
    ledger = {
        "schema": LEDGER_SCHEMA,
        "schema_version": 1,
        "generator": {
            "name": "tools/msforms-parity/parity_ledger.py",
            "non_claim": "A present source declaration proves neither runtime semantics nor parity; every behavior/evidence dimension remains independent.",
        },
        **canonical,
        "canonical_sha256": semantic_sha256(canonical),
    }
    errors = validate_ledger_structure(ledger)
    if errors:
        raise LedgerError("generated ledger is invalid: " + "; ".join(errors))
    return ledger


def validate_ledger_structure(ledger: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if ledger.get("schema") != LEDGER_SCHEMA:
        errors.append(f"schema must be {LEDGER_SCHEMA}")
        return errors
    if not _is_schema_version_one(ledger.get("schema_version")):
        errors.append("schema_version must be 1")
    generator = ledger.get("generator")
    if not isinstance(generator, dict) or generator.get("name") != (
        "tools/msforms-parity/parity_ledger.py"
    ):
        errors.append("generator identity is missing or incorrect")

    inputs = ledger.get("inputs")
    if not isinstance(inputs, list):
        errors.append("inputs must be a list")
    else:
        input_paths: list[str] = []
        for index, item in enumerate(inputs):
            if not isinstance(item, dict) or set(item) != {
                "path",
                "hash_mode",
                "sha256",
            }:
                errors.append(f"inputs[{index}] has the wrong fields")
                continue
            path = item["path"]
            digest = item["sha256"]
            if not isinstance(path, str) or not path or "\\" in path:
                errors.append(f"inputs[{index}] has an invalid path")
            else:
                input_paths.append(path)
            if item["hash_mode"] not in {"raw", "utf8_lf"}:
                errors.append(f"inputs[{index}] has invalid hash_mode")
            if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
                errors.append(f"inputs[{index}] has an invalid sha256")
        if input_paths != sorted(input_paths) or len(set(input_paths)) != len(input_paths):
            errors.append("input paths must be unique and sorted")

    rows = ledger.get("rows")
    if not isinstance(rows, list):
        errors.append("rows must be a list")
        return errors
    common_row_fields = {
        "row_id",
        "row_kind",
        "source_authority",
        "facade_owner_type_id",
        "declaration_owner_type_id",
        "source_refs",
        "exact_name",
        "memid",
        "visibility",
        "disposition",
        "disposition_basis",
        "contract",
        "actual",
        "dimensions",
        "row_status",
    }
    projection_contract_kinds = {
        "declaration_member",
        "declaration_variable",
        "enum_value",
    }
    seen: set[str] = set()
    row_by_id: dict[str, dict[str, Any]] = {}
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            errors.append(f"rows[{index}] must be an object")
            continue
        row_id = row.get("row_id")
        if not isinstance(row_id, str) or not row_id:
            errors.append(f"rows[{index}] has no row_id")
            continue
        if row_id in seen:
            errors.append(f"duplicate row_id {row_id}")
        seen.add(row_id)
        row_by_id[row_id] = row
        row_kind = row.get("row_kind")
        if row_kind not in ALLOWED_ROW_KINDS:
            errors.append(f"{row_id}: invalid row_kind {row_kind!r}")
        expected_fields = set(common_row_fields)
        if row_kind in projection_contract_kinds:
            expected_fields.add("projection_refs")
        if set(row) != expected_fields:
            errors.append(f"{row_id}: row fields differ from the row-kind schema")
        if not isinstance(row.get("source_refs"), list) or not row.get(
            "source_refs"
        ) or not all(
            isinstance(item, str) and item for item in row.get("source_refs", [])
        ):
            errors.append(f"{row_id}: source_refs must be nonempty strings")
        if not isinstance(row.get("exact_name"), str) or not row["exact_name"]:
            errors.append(f"{row_id}: exact_name must be nonempty")
        if not isinstance(row.get("source_authority"), str) or not row[
            "source_authority"
        ]:
            errors.append(f"{row_id}: source_authority must be nonempty")
        if not isinstance(row.get("disposition_basis"), str) or not row[
            "disposition_basis"
        ].strip():
            errors.append(f"{row_id}: disposition_basis must be nonempty")
        visibility = row.get("visibility")
        if not isinstance(visibility, dict) or set(visibility) != {
            "type_flags",
            "member_flags",
            "hidden",
            "nonbrowsable",
            "restricted",
        }:
            errors.append(f"{row_id}: visibility fields differ from schema")
        dimensions = row.get("dimensions")
        if not isinstance(dimensions, dict) or tuple(dimensions.keys()) != DIMENSION_NAMES:
            errors.append(f"{row_id}: dimension keys/order differ from schema")
            continue
        for name, dimension in dimensions.items():
            if not isinstance(dimension, dict) or not set(dimension) <= {
                "status",
                "basis",
                "evidence",
                "rule",
            } or not {"status", "basis", "evidence"} <= set(dimension):
                errors.append(f"{row_id}.{name}: dimension fields differ from schema")
                continue
            status = dimension.get("status")
            if status not in DIMENSION_STATUSES:
                errors.append(f"{row_id}.{name}: invalid status {status!r}")
            if not isinstance(dimension.get("basis"), str) or not dimension["basis"].strip():
                errors.append(f"{row_id}.{name}: empty basis")
            if not isinstance(dimension.get("evidence"), list):
                errors.append(f"{row_id}.{name}: evidence must be a list")
            if status == "verified" and not dimension.get("evidence"):
                errors.append(f"{row_id}.{name}: verified requires evidence")
            if status == "excluded_authoritative" and (
                not dimension.get("rule") or not dimension.get("evidence")
            ):
                errors.append(
                    f"{row_id}.{name}: excluded_authoritative requires rule and evidence"
                )
            if "rule" in dimension and status != "excluded_authoritative":
                errors.append(
                    f"{row_id}.{name}: rule is allowed only for excluded_authoritative"
                )
            if not all(
                isinstance(item, str) and item for item in dimension.get("evidence", [])
            ):
                errors.append(f"{row_id}.{name}: evidence entries must be nonempty strings")
        unexpected = str(row_kind).startswith("unexpected_public")
        if unexpected:
            if row.get("disposition") != "unexpected_public":
                errors.append(f"{row_id}: unexpected row has wrong disposition")
            if dimensions["type_or_declaration"].get("status") != "partial":
                errors.append(f"{row_id}: unexpected row must have partial declaration status")
            if row.get("row_status") != "unexpected_public":
                errors.append(f"{row_id}: unexpected row must remain unexpected_public")
        elif dimensions["type_or_declaration"].get("status") != "verified":
            errors.append(f"{row_id}: accepted row must verify type_or_declaration")
        if row.get("disposition") == "needs_projection_classification":
            errors.append(f"{row_id}: unresolved projection classification is forbidden")
        expected_status = _row_status(row)
        if row.get("row_status") != expected_status:
            errors.append(
                f"{row_id}: row_status {row.get('row_status')!r} != {expected_status!r}"
            )

    counts = Counter(row.get("row_kind") for row in rows)
    if set(counts) != ALLOWED_ROW_KINDS:
        errors.append("row-kind set differs from the complete schema")
    for kind, expected in EXPECTED_COUNTS.items():
        if counts.get(kind, 0) != expected:
            errors.append(f"{kind} count {counts.get(kind, 0)} != {expected}")

    if ledger.get("summary", {}).get("source_surface") != EXPECTED_SOURCE_SUMMARY:
        errors.append("source_surface census differs from the reviewed baseline")

    function_occurrences: set[tuple[str, int]] = set()
    for row in rows:
        if row.get("row_kind") != "declaration_member":
            continue
        contract = row["contract"]
        source_indices = contract["source_function_indices"]
        accessor_indices = [
            signature.get("source_index")
            for signature in contract["accessors"].values()
        ]
        if not all(type(source_index) is int for source_index in source_indices):
            errors.append(f"{row['row_id']}: source function index is not integral")
            continue
        if accessor_indices != source_indices:
            errors.append(
                f"{row['row_id']}: accessor/source-function index binding differs"
            )
        for source_index in source_indices:
            key = (row["declaration_owner_type_id"], source_index)
            if key in function_occurrences:
                errors.append(f"duplicate FUNCDESC coverage {key!r}")
            function_occurrences.add(key)
    if len(function_occurrences) != 2832:
        errors.append(f"FUNCDESC coverage {len(function_occurrences)} != 2832")

    variable_occurrences: set[tuple[str, int]] = set()
    for row in rows:
        if row.get("row_kind") not in {"enum_value", "declaration_variable"}:
            continue
        variable_index = row.get("contract", {}).get("variable", {}).get(
            "index"
        )
        if type(variable_index) is not int:
            errors.append(f"{row.get('row_id')}: VARDESC index is not integral")
            continue
        key = (str(row.get("declaration_owner_type_id")), variable_index)
        if key in variable_occurrences:
            errors.append(f"duplicate VARDESC coverage {key!r}")
        variable_occurrences.add(key)
    if len(variable_occurrences) != 221:
        errors.append(f"VARDESC coverage {len(variable_occurrences)} != 221")

    type_rows = [row for row in rows if row.get("row_kind") == "type_contract"]
    type_by_id = {
        row.get("declaration_owner_type_id"): row
        for row in type_rows
        if isinstance(row.get("declaration_owner_type_id"), str)
    }
    if len(type_by_id) != 220:
        errors.append(f"unique type contract ids {len(type_by_id)} != 220")
    if Counter(row.get("contract", {}).get("view") for row in type_rows) != {
        "primary": 183,
        "dual_interface": 37,
    }:
        errors.append("primary/dual type-view census differs from 183/37")
    if Counter(row.get("source_authority") for row in type_rows) != {
        "fm20_typelib": 208,
        "stdole_typelib": 12,
    }:
        errors.append("root/stdole type census differs from 208/12")
    if sum(
        row.get("contract", {}).get("typekind") == "TKIND_COCLASS"
        for row in type_rows
    ) != 60:
        errors.append("coclass type census differs from 60")
    abi_layout_keys = {
        "alignment",
        "size_instance",
        "vtable_size",
        "function_count",
        "variable_count",
        "implementation_count",
    }
    for row in type_rows:
        layout = row.get("contract", {}).get("abi_layout")
        if not isinstance(layout, dict) or set(layout) != abi_layout_keys:
            errors.append(f"{row.get('row_id')}: exact ABI layout schema differs")
            continue
        if any(
            not isinstance(value, int) or isinstance(value, bool) or value < 0
            for value in layout.values()
        ):
            errors.append(f"{row.get('row_id')}: exact ABI layout values differ")

        actual = row.get("actual")
        source = actual.get("source") if isinstance(actual, dict) else None
        if not isinstance(source, dict) or source.get("kind") != "class_module":
            continue
        profiles = source.get("effective_loader_profiles")
        source_creatable = source.get("effective_creatable_by_profile")
        source_evidence = source.get("effective_loader_profile_evidence")
        manual_evaluations = source.get("manual_loader_profile_evaluations")
        identity = actual.get("identity_comparison")
        if (
            not isinstance(profiles, list)
            or not all(isinstance(profile, str) and profile for profile in profiles)
            or not isinstance(source_creatable, dict)
            or list(source_creatable) != profiles
            or any(type(value) is not bool for value in source_creatable.values())
            or not isinstance(source_evidence, dict)
            or list(source_evidence) != profiles
            or not all(
                isinstance(value, str) and value
                for value in source_evidence.values()
            )
            or not isinstance(manual_evaluations, dict)
            or not isinstance(identity, dict)
        ):
            errors.append(
                f"{row.get('row_id')}: loader-profile creatability schema differs"
            )
            continue
        source_attributes = {
            name.casefold(): value
            for name, value in source.get("attributes", {}).items()
        }
        expected_manual_profiles: list[str] = []
        manual_schema_valid = True
        for profile_id, evaluation in manual_evaluations.items():
            expected_exposed = (
                not source.get("option_private_module", False)
                and (
                    source.get("kind") == "standard_module"
                    or source_attributes.get("vb_exposed", True)
                )
            )
            expected_manual_creatable = source_attributes.get(
                "vb_creatable", True
            )
            if (
                not isinstance(evaluation, dict)
                or evaluation.get("listed") is not True
                or evaluation.get("effective_exposed") is not expected_exposed
                or evaluation.get("effective_creatable")
                is not expected_manual_creatable
                or not isinstance(evaluation.get("source_path"), str)
                or not evaluation.get("source_path")
                or not isinstance(evaluation.get("basis"), str)
                or not evaluation.get("basis")
            ):
                manual_schema_valid = False
            if expected_exposed:
                expected_manual_profiles.append(profile_id)
        expected_profiles = (
            ["clean_basproj"]
            if source.get("project_declared_exposed") is True
            else []
        ) + expected_manual_profiles
        expected_creatable_by_profile = {
            profile: (
                source.get("project_declared_creatable")
                if profile == "clean_basproj"
                else manual_evaluations[profile].get("effective_creatable")
            )
            for profile in expected_profiles
        }
        if (
            not manual_schema_valid
            or profiles != expected_profiles
            or not _type_strict_json_equal(
                source_creatable, expected_creatable_by_profile
            )
        ):
            errors.append(
                f"{row.get('row_id')}: effective loader profile derivation differs"
            )
        if not _type_strict_json_equal(
            identity.get("actual_creatable_by_profile"), source_creatable
        ) or not _type_strict_json_equal(
            identity.get("profile_evidence"), source_evidence
        ):
            errors.append(
                f"{row.get('row_id')}: loader-profile creatability crosslink differs"
            )
        expected_creatable = identity.get("expected_creatable")
        if type(expected_creatable) is not bool:
            errors.append(
                f"{row.get('row_id')}: canonical creatability identity is not Boolean"
            )
            continue
        expected_mismatches = [
            profile
            for profile in profiles
            if source_creatable[profile] != expected_creatable
        ]
        if identity.get("creatability_mismatch_profiles") != expected_mismatches:
            errors.append(
                f"{row.get('row_id')}: loader-profile creatability mismatch set differs"
            )
        expected_evidence = [source_evidence[profile] for profile in expected_mismatches]
        if expected_evidence and not set(expected_evidence).issubset(
            set(row.get("dimensions", {}).get("bind", {}).get("evidence", []))
        ):
            errors.append(
                f"{row.get('row_id')}: loader-profile mismatch evidence is absent"
            )

    implemented_role_counts: Counter[tuple[str, ...]] = Counter()
    implemented_edge_count = 0
    for row in type_rows:
        contract = row.get("contract", {})
        type_id = row.get("declaration_owner_type_id")
        for edge in contract.get("implemented_types", []):
            implemented_edge_count += 1
            roles = tuple(edge.get("roles", []))
            implemented_role_counts[roles] += 1
            target = edge.get("target", {})
            target_id = (
                f"{target.get('library_key')}|{target.get('type_index')}|{target.get('view')}"
            )
            if target_id not in type_by_id:
                errors.append(f"{type_id}: unresolved implemented target {target_id}")
    if implemented_edge_count != 216 or implemented_role_counts != {
        (): 105,
        ("default",): 60,
        ("default", "source"): 51,
    }:
        errors.append(
            f"implemented-type census differs: {implemented_edge_count}, {dict(implemented_role_counts)!r}"
        )

    dual_pairs: set[tuple[str, str]] = set()
    for row in type_rows:
        contract = row.get("contract", {})
        type_id = str(row.get("declaration_owner_type_id"))
        if contract.get("view") == "dual_interface":
            primary = contract.get("dual_primary") or {}
            primary_id = (
                f"{primary.get('library_key')}|{primary.get('type_index')}|{primary.get('view')}"
            )
            primary_row = type_by_id.get(primary_id)
            companion = (
                (primary_row or {}).get("contract", {}).get("dual_companion") or {}
            ).get("target", {})
            reciprocal_id = (
                f"{companion.get('library_key')}|{companion.get('type_index')}|{companion.get('view')}"
            )
            if primary_row is None or reciprocal_id != type_id:
                errors.append(f"{type_id}: dual crosslink is not reciprocal")
            else:
                dual_pairs.add((primary_id, type_id))
    if len(dual_pairs) != 37:
        errors.append(f"reciprocal dual pair census {len(dual_pairs)} != 37")

    contract_kinds = projection_contract_kinds
    contract_rows = {
        row["row_id"]: row
        for row in rows
        if row.get("row_kind") in contract_kinds
    }
    expected_projection_refs: dict[str, set[str]] = defaultdict(set)
    projection_kinds = {
        "surface_member",
        "event_projection",
        "host_event_attachment",
        "abi_adapter_member",
    }
    for row in rows:
        if row.get("row_kind") not in projection_kinds:
            continue
        source_refs = row.get("source_refs", [])
        contract_ref = source_refs[0] if source_refs else None
        if contract_ref not in contract_rows:
            errors.append(f"{row.get('row_id')}: first source_ref is not a declaration contract")
            continue
        expected_projection_refs[str(contract_ref)].add(row["row_id"])
        contract_row = contract_rows[str(contract_ref)]
        if row.get("declaration_owner_type_id") != contract_row.get(
            "declaration_owner_type_id"
        ):
            errors.append(f"{row['row_id']}: projection declaration owner differs")
        if row.get("exact_name") != contract_row.get("exact_name") or row.get(
            "memid"
        ) != contract_row.get("memid"):
            errors.append(f"{row['row_id']}: projection name/memid differs from contract")
        if row.get("row_kind") in {
            "event_projection",
            "host_event_attachment",
        }:
            event_signature = row.get("contract", {}).get("event_signature")
            declaration_signature = contract_row.get("contract", {}).get(
                "accessors", {}
            ).get("func")
            if event_signature != declaration_signature:
                errors.append(
                    f"{row['row_id']}: projected event signature differs from declaration contract"
                )
            if (
                row.get("row_kind") == "event_projection"
                and row.get("contract", {}).get("source_function_index")
                != (event_signature or {}).get("source_index")
            ):
                errors.append(
                    f"{row['row_id']}: event source-function index differs from signature"
                )
    for contract_id, row in contract_rows.items():
        refs = row.get("projection_refs")
        if not isinstance(refs, list) or len(refs) != len(set(refs)):
            errors.append(f"{contract_id}: projection_refs must be a unique list")
        elif set(refs) != expected_projection_refs.get(contract_id, set()):
            errors.append(f"{contract_id}: projection_refs reverse crosslink differs")

    surface_rows = [row for row in rows if row.get("row_kind") == "surface_member"]
    surface_modes: Counter[str] = Counter()
    for row in surface_rows:
        contract = row.get("contract", {})
        contract_ref = row.get("source_refs", [None])[0]
        contract_row = contract_rows.get(contract_ref, {})
        if "direct_facade" in contract:
            surface_modes["direct"] += 1
            if row.get("facade_owner_type_id") != row.get("declaration_owner_type_id"):
                errors.append(f"{row['row_id']}: direct facade owner must equal declaration owner")
        else:
            surface_modes["ordinary"] += 1
            edge = contract.get("implementation_edge") or {}
            target = edge.get("target", {})
            target_id = (
                f"{target.get('library_key')}|{target.get('type_index')}|{target.get('view')}"
            )
            if target_id != row.get("declaration_owner_type_id"):
                errors.append(f"{row['row_id']}: ordinary implementation target differs")
            facade = type_by_id.get(row.get("facade_owner_type_id"))
            if facade is None or not any(
                candidate.get("index") == edge.get("index")
                and candidate.get("roles") == edge.get("roles")
                and candidate.get("target") == edge.get("target")
                for candidate in facade.get("contract", {}).get(
                    "implemented_types", []
                )
            ):
                errors.append(f"{row['row_id']}: ordinary implementation edge is absent")
            if edge.get("roles") != ["default"]:
                errors.append(f"{row['row_id']}: ordinary edge is not the default interface")
        if (
            contract_row.get("row_kind") == "declaration_member"
            and contract.get("accessors")
            != contract_row.get("contract", {}).get("accessors")
        ):
            errors.append(f"{row['row_id']}: projected accessor contract differs")
        if "variable" in contract and contract.get("variable") != contract_row.get(
            "contract", {}
        ).get("variable"):
            errors.append(f"{row['row_id']}: projected VARDESC contract differs")
    if surface_modes != {"ordinary": 1709, "direct": 85}:
        errors.append(f"surface projection modes differ: {dict(surface_modes)!r}")

    event_rows = [row for row in rows if row.get("row_kind") == "event_projection"]
    event_edges: set[tuple[Any, ...]] = set()
    w005_count = 0
    for row in event_rows:
        contract = row.get("contract", {})
        edge = contract.get("implementation_edge") or {}
        if edge.get("roles") != ["default", "source"]:
            errors.append(f"{row['row_id']}: event edge lacks default+source roles")
        target = edge.get("target", {})
        target_id = (
            f"{target.get('library_key')}|{target.get('type_index')}|{target.get('view')}"
        )
        if target_id != row.get("declaration_owner_type_id"):
            errors.append(f"{row['row_id']}: event source target differs")
        facade = type_by_id.get(row.get("facade_owner_type_id"))
        if facade is None or not any(
            candidate.get("index") == edge.get("index")
            and candidate.get("roles") == edge.get("roles")
            and candidate.get("target") == edge.get("target")
            for candidate in facade.get("contract", {}).get(
                "implemented_types", []
            )
        ):
            errors.append(f"{row['row_id']}: event implementation edge is absent")
        event_edges.add(
            (
                row.get("facade_owner_type_id"),
                edge.get("index"),
                row.get("declaration_owner_type_id"),
            )
        )
        reconciliation = contract.get("w005_metadata_reconciliation")
        if reconciliation is not None:
            w005_count += 1
            if (
                reconciliation.get("status") != "exact_match"
                or reconciliation.get("current_signature_sha256")
                != reconciliation.get("w005_signature_sha256")
            ):
                errors.append(f"{row['row_id']}: W005 reconciliation is not exact")
            key = reconciliation.get("key", {})
            facade_name = (facade or {}).get("exact_name")
            declaration = type_by_id.get(row.get("declaration_owner_type_id"), {})
            if (
                key.get("coclass") != facade_name
                or key.get("source_interface") != declaration.get("exact_name")
                or key.get("source_interface_guid")
                != declaration.get("contract", {}).get("guid")
                or key.get("event_name") != row.get("exact_name")
                or key.get("dispid") != row.get("memid")
                or key.get("invoke_kind") != 1
            ):
                errors.append(f"{row['row_id']}: W005 key differs from event row")
    if len(event_edges) != 51:
        errors.append(f"event source-edge census {len(event_edges)} != 51")
    if len({row.get("source_refs", [None])[0] for row in event_rows}) != 192:
        errors.append("unique event declaration contract census differs from 192")
    if w005_count != 376:
        errors.append(f"W005 reconciliation row census {w005_count} != 376")

    event_names = Counter(
        (row["exact_name"], row["facade_owner_type_id"])
        for row in rows
        if row.get("row_kind") == "event_projection"
        and row["exact_name"] in {"SpinUp", "SpinDown"}
    )
    spin_rows = sum(event_names.values())
    if spin_rows != 4:
        errors.append(f"SpinUp/SpinDown full-library projection count {spin_rows} != 4")

    for row in rows:
        if row.get("row_kind") != "host_event_attachment":
            continue
        source = row.get("contract", {}).get("canonical_source", {})
        source_id = (
            f"{source.get('library_key')}|{source.get('type_index')}|{source.get('view')}"
        )
        facade = type_by_id.get(row.get("facade_owner_type_id"), {})
        attachment = row.get("contract", {}).get("host_attachment", {})
        if (
            source_id != row.get("declaration_owner_type_id")
            or source.get("memid") != row.get("memid")
            or facade.get("exact_name") != attachment.get("owner")
            or attachment.get("name") != row.get("exact_name")
        ):
            errors.append(f"{row['row_id']}: host attachment crosslink differs")

    abi_slots_by_type: dict[str, list[tuple[int, int, str, str]]] = defaultdict(list)
    for row in rows:
        if row.get("row_kind") != "abi_adapter_member":
            continue
        type_id = row.get("declaration_owner_type_id")
        contract = row.get("contract", {})
        type_row = type_by_id.get(type_id, {})
        declaration_row = contract_rows.get(row.get("source_refs", [None])[0], {})
        if (
            row.get("facade_owner_type_id") != type_id
            or contract.get("projection_semantics")
            != "non_dispatch_abi_adapter_required"
        ):
            errors.append(f"{row['row_id']}: ABI adapter classification differs")
        if contract.get("accessors") != declaration_row.get("contract", {}).get(
            "accessors"
        ):
            errors.append(f"{row['row_id']}: ABI adapter accessor contract differs")
        if (
            contract.get("type_contract_ref") != type_row.get("row_id")
            or contract.get("interface_layout")
            != type_row.get("contract", {}).get("abi_layout")
        ):
            errors.append(f"{row['row_id']}: ABI adapter interface layout differs")
        adapter = contract.get("abi_adapter", {})
        type_contract = type_row.get("contract", {})
        if (
            adapter.get("library_key") != type_contract.get("library_key")
            or adapter.get("type_index") != type_contract.get("type_index")
            or adapter.get("view") != type_contract.get("view")
            or adapter.get("name") != type_row.get("exact_name")
        ):
            errors.append(f"{row['row_id']}: ABI adapter type identity differs")
        for accessor, signature in contract.get("accessors", {}).items():
            source_index = signature.get("source_index")
            vtable_offset = signature.get("vtable_offset")
            if (
                not isinstance(source_index, int)
                or isinstance(source_index, bool)
                or not isinstance(vtable_offset, int)
                or isinstance(vtable_offset, bool)
            ):
                errors.append(f"{row['row_id']}: ABI accessor slot is not integral")
                continue
            abi_slots_by_type[str(type_id)].append(
                (source_index, vtable_offset, row["row_id"], str(accessor))
            )

    for type_id, slots in abi_slots_by_type.items():
        layout = type_by_id.get(type_id, {}).get("contract", {}).get(
            "abi_layout", {}
        )
        function_count = layout.get("function_count")
        vtable_size = layout.get("vtable_size")
        alignment = layout.get("alignment")
        ordered = sorted(slots)
        indices = [slot[0] for slot in ordered]
        offsets = [slot[1] for slot in ordered]
        if (
            type(function_count) is not int
            or indices != list(range(function_count))
        ):
            errors.append(f"{type_id}: ABI source-index coverage differs")
            continue
        if (
            type(alignment) is not int
            or alignment <= 0
            or type(vtable_size) is not int
            or vtable_size < 0
        ):
            errors.append(f"{type_id}: ABI layout extent/alignment differs")
            continue
        inherited_prefix = vtable_size - function_count * alignment
        if inherited_prefix < 0 or inherited_prefix % alignment != 0:
            errors.append(f"{type_id}: ABI inherited vtable prefix differs")
            continue
        expected_offsets = [
            inherited_prefix + source_index * alignment
            for source_index in range(function_count)
        ]
        if offsets != expected_offsets:
            errors.append(
                f"{type_id}: ABI vtable offsets differ from authoritative alignment/layout"
            )

    def check_signature_hashes(value: Any, path: str) -> None:
        if isinstance(value, dict):
            if "signature_sha256" in value:
                expected = semantic_sha256(
                    {key: item for key, item in value.items() if key != "signature_sha256"}
                )
                if value.get("signature_sha256") != expected:
                    errors.append(f"{path}: signature_sha256 mismatch")
            for key, item in value.items():
                check_signature_hashes(item, f"{path}.{key}")
        elif isinstance(value, list):
            for index, item in enumerate(value):
                check_signature_hashes(item, f"{path}[{index}]")

    check_signature_hashes(rows, "rows")

    mapped_declarations: set[str] = set()
    mapped_nested: set[str] = set()
    for row in rows:
        actual = row.get("actual")
        if row.get("row_kind") == "type_contract" and isinstance(actual, dict):
            source = actual.get("source")
            if isinstance(source, dict) and isinstance(
                source.get("source_declaration_id"), str
            ):
                mapped_declarations.add(source["source_declaration_id"])
        if isinstance(actual, dict):
            accessors = actual.get("accessors")
            if isinstance(accessors, dict):
                for accessor in accessors.values():
                    declaration = (
                        accessor.get("source_declaration")
                        if isinstance(accessor, dict)
                        else None
                    )
                    if isinstance(declaration, dict) and isinstance(
                        declaration.get("source_declaration_id"), str
                    ):
                        mapped_declarations.add(declaration["source_declaration_id"])
        if row.get("row_kind") == "enum_value" and isinstance(actual, dict):
            if isinstance(actual.get("source_member_id"), str):
                mapped_nested.add(actual["source_member_id"])
    unexpected_declarations = {
        row.get("actual", {}).get("source_declaration_id")
        for row in rows
        if row.get("row_kind") == "unexpected_public_member"
        and isinstance(row.get("actual"), dict)
    }
    unexpected_nested = {
        row.get("actual", {}).get("source_member_id")
        for row in rows
        if row.get("row_kind") == "unexpected_public_nested_member"
        and isinstance(row.get("actual"), dict)
    }
    if (
        len(mapped_declarations) != 258
        or len(unexpected_declarations) != 584
        or mapped_declarations & unexpected_declarations
        or len(mapped_declarations | unexpected_declarations) != 842
    ):
        errors.append("public source declaration partition differs from 258+584=842")
    if (
        len(mapped_nested) != 10
        or len(unexpected_nested) != 26
        or mapped_nested & unexpected_nested
        or len(mapped_nested | unexpected_nested) != 36
    ):
        errors.append("public nested-member partition differs from 10+26=36")

    ms_categories = Counter(
        row.get("contract", {}).get("category")
        for row in rows
        if row.get("row_kind") == "persistence_ms_oforms_fact"
    )
    if ms_categories != EXPECTED_MS_PERSISTENCE_CATEGORIES:
        errors.append("MS-OFORMS persistence category census differs")
    frm_categories = Counter(
        row.get("contract", {}).get("category")
        for row in rows
        if row.get("row_kind") == "persistence_frm_frx_fact"
    )
    if frm_categories != EXPECTED_FRM_PERSISTENCE_CATEGORIES:
        errors.append("FRM/FRX persistence category census differs")
    aggregate_categories: dict[str, set[str]] = defaultdict(set)
    for row in rows:
        if row.get("row_kind") == "persistence_aggregate":
            aggregate_categories[str(row.get("source_authority"))].add(
                str(row.get("contract", {}).get("category"))
            )
            if row.get("row_status") != "verified":
                errors.append(f"{row['row_id']}: aggregate provenance must be non-gating")
    if aggregate_categories.get("ms_oforms") != EXPECTED_MS_AGGREGATE_CATEGORIES:
        errors.append("MS-OFORMS aggregate category set differs")
    if aggregate_categories.get("frm_frx") != EXPECTED_FRM_AGGREGATE_CATEGORIES:
        errors.append("FRM/FRX aggregate category set differs")
    for row in rows:
        if row.get("row_kind") == "persistence_family_property":
            contract = row.get("contract", {})
            if contract.get("runtime_api_claim") is not False or contract.get(
                "binary_value_decoded"
            ) is not False:
                errors.append(f"{row['row_id']}: forbidden mapping claim was promoted")

    reconstructed = _summary(rows, ledger.get("summary", {}).get("source_surface", {}))
    if ledger.get("summary") != reconstructed:
        errors.append("summary is not exactly reconstructed from rows")
    if ledger.get("summary", {}).get("green"):
        if any(
            dimension["status"] in GATING_STATUSES
            for row in rows
            for dimension in row["dimensions"].values()
        ) or any(row["row_kind"].startswith("unexpected_public") for row in rows):
            errors.append("green summary cannot coexist with a gating/unexpected row")

    canonical = {
        "inputs": ledger.get("inputs"),
        "source_surface_sha256": ledger.get("source_surface_sha256"),
        "rows": rows,
        "summary": ledger.get("summary"),
    }
    if ledger.get("canonical_sha256") != semantic_sha256(canonical):
        errors.append("canonical_sha256 mismatch")
    return errors


def _safe_repo_file(repo_root: Path, relative_path: str) -> Path:
    if (
        not relative_path
        or "\\" in relative_path
        or relative_path.startswith("/")
        or ":" in relative_path
        or ".." in relative_path.split("/")
    ):
        raise LedgerError(f"unsafe pinned path {relative_path!r}")
    candidate = (repo_root / Path(*relative_path.split("/"))).resolve()
    if repo_root not in candidate.parents or not candidate.is_file():
        raise LedgerError(f"missing or out-of-repo pinned file {relative_path!r}")
    return candidate


def _file_sha256(path: Path, hash_mode: str) -> str:
    raw = path.read_bytes()
    if hash_mode == "raw":
        return sha256_bytes(raw)
    if hash_mode == "utf8_lf":
        try:
            _, normalized = normalized_utf8_text(raw)
        except UnicodeDecodeError as exc:
            raise LedgerError(f"pinned utf8_lf file is not UTF-8: {path}") from exc
        return sha256_bytes(normalized)
    raise LedgerError(f"unknown pin hash_mode {hash_mode!r}")


def build_expected_ledger_manifest(ledger: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema": EXPECTED_LEDGER_SCHEMA,
        "schema_version": 1,
        "ledger_schema": LEDGER_SCHEMA,
        "artifact_path": (
            "docs/evidence/W010_complete_msforms_object_model_parity/beads/"
            "oxforms-jbjp.73/msforms_parity_ledger.v1.json"
        ),
        "canonical_sha256": ledger["canonical_sha256"],
        "canonical_file_sha256": sha256_bytes(canonical_json_bytes(ledger)),
        "source_surface_sha256": ledger["source_surface_sha256"],
        "inputs_sha256": semantic_sha256(ledger["inputs"]),
        "row_count": ledger["summary"]["rows"],
        "row_kinds": copy.deepcopy(ledger["summary"]["row_kinds"]),
        "row_statuses": copy.deepcopy(ledger["summary"]["row_statuses"]),
        "gating_dimension_cells": ledger["summary"]["gating_dimension_cells"],
        "unexpected_public_rows": ledger["summary"]["unexpected_public_rows"],
        "green": ledger["summary"]["green"],
    }


_STRICT_BASELINE_CACHE: dict[
    tuple[Any, ...], tuple[dict[str, Any] | None, list[str]]
] = {}


def _strict_baseline(
    repo_root: Path,
) -> tuple[dict[str, Any] | None, list[str]]:
    errors: list[str] = []
    try:
        pin_path = _safe_repo_file(repo_root, PIN_PATH)
        expected_path = _safe_repo_file(repo_root, EXPECTED_LEDGER_PATH)
        pins = load_json_strict(pin_path)
        expected_manifest = load_json_strict(expected_path)
    except LedgerError as exc:
        return None, [str(exc)]
    if set(pins) != {
        "schema",
        "schema_version",
        "hash_contract",
        "files",
        "ledger_inputs",
    }:
        errors.append("pin manifest fields differ from schema")
    if pins.get("schema") != PIN_SCHEMA or not _is_schema_version_one(
        pins.get("schema_version")
    ):
        errors.append("pin manifest schema/version differs")
    if pins.get("hash_contract") != (
        "utf8_lf removes an optional UTF-8 BOM and canonicalizes CRLF/CR to LF; "
        "raw hashes exact bytes"
    ):
        errors.append("pin manifest hash contract differs")
    files = pins.get("files")
    if not isinstance(files, list):
        return None, errors + ["pin manifest files must be a list"]
    pinned_paths: list[str] = []
    verified_content_key: list[tuple[str, str, str]] = []
    for index, pin in enumerate(files):
        if not isinstance(pin, dict) or set(pin) != {"path", "hash_mode", "sha256"}:
            errors.append(f"pin files[{index}] fields differ from schema")
            continue
        path = pin.get("path")
        if not isinstance(path, str):
            errors.append(f"pin files[{index}] path must be a string")
            continue
        pinned_paths.append(path)
        try:
            full_path = _safe_repo_file(repo_root, path)
        except LedgerError as exc:
            errors.append(str(exc))
            continue
        try:
            hash_mode = str(pin.get("hash_mode"))
            actual_sha = _file_sha256(full_path, hash_mode)
        except (OSError, LedgerError) as exc:
            errors.append(str(exc))
            continue
        verified_content_key.append((path, hash_mode, actual_sha))
        if pin.get("sha256") != actual_sha:
            errors.append(f"pinned hash mismatch for {path}")
    if pinned_paths != sorted(pinned_paths) or len(set(pinned_paths)) != len(
        pinned_paths
    ):
        errors.append("pinned file paths must be unique and sorted")

    try:
        current_surface = extract_surface(
            repo_root, repo_root / DEFAULT_PATHS["basproj"]
        )
    except (OSError, SurfaceError) as exc:
        errors.append(f"source-surface dependency discovery failed: {exc}")
        current_surface = None
    required_dependencies = {
        EXPECTED_LEDGER_PATH,
        "Cargo.toml",
        f"{_REVIEWED_ADAPTER_CRATE}/Cargo.toml",
        *_ADAPTER_REVIEWED_TOKEN_SHA256,
        *(
            f"{target['crate']}/Cargo.toml"
            for target in _LOADER_CARGO_TARGETS.values()
        ),
        "tools/msforms-parity/parity_ledger.py",
        "tools/msforms-parity/vba_surface.py",
    }
    if current_surface is not None:
        required_dependencies.update(
            module["path"] for module in current_surface["modules"]
        )
    missing_dependencies = sorted(required_dependencies - set(pinned_paths))
    if missing_dependencies:
        errors.append(
            "pin manifest omits strict dependency closure: "
            + ", ".join(missing_dependencies)
        )

    cache_key = (
        str(repo_root),
        sha256_bytes(pin_path.read_bytes()),
        sha256_bytes(expected_path.read_bytes()),
        current_surface.get("canonical_sha256") if current_surface else None,
        tuple(verified_content_key),
    )
    cached = _STRICT_BASELINE_CACHE.get(cache_key)
    if cached is not None and not errors:
        return cached

    ledger_inputs = pins.get("ledger_inputs")
    if not isinstance(ledger_inputs, list):
        errors.append("pin manifest ledger_inputs must be a list")
    elif any(
        not isinstance(item, dict)
        or set(item) != {"path", "hash_mode", "sha256"}
        for item in ledger_inputs
    ):
        errors.append("pin manifest ledger_inputs fields differ from schema")
    elif not all(item in files for item in ledger_inputs):
        errors.append("every ledger input must also be an independently pinned file")

    expected_fields = set(
        build_expected_ledger_manifest(
            {
                "canonical_sha256": "",
                "source_surface_sha256": "",
                "inputs": [],
                "summary": {
                    "rows": 0,
                    "row_kinds": {},
                    "row_statuses": {},
                    "gating_dimension_cells": 0,
                    "unexpected_public_rows": 0,
                    "green": False,
                },
            }
        )
    )
    if set(expected_manifest) != expected_fields:
        errors.append("expected-ledger manifest fields differ from schema")
    if (
        expected_manifest.get("schema") != EXPECTED_LEDGER_SCHEMA
        or not _is_schema_version_one(expected_manifest.get("schema_version"))
        or expected_manifest.get("ledger_schema") != LEDGER_SCHEMA
    ):
        errors.append("expected-ledger manifest schema/version differs")
    if errors:
        return None, errors

    try:
        expected_ledger = build_ledger(repo_root)
    except LedgerError as exc:
        return None, [f"deterministic regeneration failed: {exc}"]
    if not _type_strict_json_equal(expected_ledger.get("inputs"), ledger_inputs):
        errors.append("regenerated ledger inputs differ from reviewed ledger_inputs pins")
    regenerated_manifest = build_expected_ledger_manifest(expected_ledger)
    if not _type_strict_json_equal(expected_manifest, regenerated_manifest):
        errors.append("regenerated ledger differs from reviewed expected-ledger manifest")
    result = (expected_ledger if not errors else None, errors)
    if not errors:
        _STRICT_BASELINE_CACHE.clear()
        _STRICT_BASELINE_CACHE[cache_key] = result
    return result


def validate_committed_ledger(
    repo_root: Path, ledger: dict[str, Any]
) -> list[str]:
    """Validate a ledger against reviewed pins and deterministic regeneration."""

    repo_root = repo_root.resolve()
    structure_errors = validate_ledger_structure(ledger)
    if structure_errors:
        return [f"structure: {error}" for error in structure_errors]
    expected_ledger, errors = _strict_baseline(repo_root)
    if errors or expected_ledger is None:
        return errors or ["strict baseline is unavailable"]
    if canonical_json_bytes(ledger) != canonical_json_bytes(expected_ledger):
        return ["ledger bytes differ from deterministic regeneration of reviewed pins"]
    return []


def canonical_json_bytes(value: dict[str, Any]) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
    ).encode("utf-8")
