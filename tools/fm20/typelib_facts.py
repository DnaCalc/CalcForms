"""Deterministic COM type-library facts for the W010 MSForms parity ledger.

This module deliberately uses only public ITypeLib/ITypeInfo metadata exposed by
pywin32.  It retains capture-local HREFTYPE values as raw diagnostics while also
resolving every reference to a stable containing-library/type identity.
"""

from __future__ import annotations

import ast
import hashlib
import importlib.metadata
import json
import os
import platform
import struct
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

try:  # Live capture only; committed-artifact validation is stdlib-only.
    import pythoncom  # type: ignore[import-not-found]
    import win32api  # type: ignore[import-not-found]
except ImportError:  # pragma: no cover - exercised in pywin32-free validation.
    pythoncom = None
    win32api = None


FACT_SCHEMA = "oxforms.fm20_typelib_facts.v1"
COMPARISON_SCHEMA = "oxforms.fm20_w005_event_reconciliation.v1"
FM20_LIBID = "{0D452EE1-E08F-101A-852E-02608C4D0BB4}"
STDOLE_LIBID = "{00020430-0000-0000-C000-000000000046}"
DEFAULT_FM20_PATH = Path(
    r"C:\Program Files\Microsoft Office\root\vfs\System\FM20.DLL"
)

EXPECTED_FM20_CENSUS = {
    "TKIND_ALIAS": 4,
    "TKIND_COCLASS": 60,
    "TKIND_DISPATCH": 64,
    "TKIND_ENUM": 42,
    "TKIND_INTERFACE": 1,
}
EXPECTED_STDOLE_INDICES = [0, 1, 2, 3, 4, 11, 12, 13, 14, 19, 35, 36]
EXPECTED_EXPORT_TOTALS = {
    "views": 220,
    "functions": 2832,
    "variables": 221,
    "implementation_edges": 216,
}
EXPECTED_W005_COUNTS = {
    "attachments": 51,
    "arguments": 1206,
    "event_names": 22,
    "rows": 376,
    "source_interfaces": 26,
}


class FactError(RuntimeError):
    """Raised when public metadata cannot be represented without loss."""


def _constant_map(prefix: str) -> dict[int, str]:
    """Return non-flag pywin32 constants, preferring the shortest name."""

    pairs = [
        (value, name)
        for name, value in vars(pythoncom).items()
        if name.startswith(prefix) and isinstance(value, int)
    ]
    result: dict[int, str] = {}
    for value, name in sorted(pairs, key=lambda pair: (pair[0], len(pair[1]), pair[1])):
        result.setdefault(value, name)
    return result


TYPEKIND_NAMES = {
    0: "TKIND_ENUM",
    1: "TKIND_RECORD",
    2: "TKIND_MODULE",
    3: "TKIND_INTERFACE",
    4: "TKIND_DISPATCH",
    5: "TKIND_COCLASS",
    6: "TKIND_ALIAS",
    7: "TKIND_UNION",
    8: "TKIND_MAX",
}
FUNCKIND_NAMES = {
    0: "FUNC_VIRTUAL",
    1: "FUNC_PUREVIRTUAL",
    2: "FUNC_NONVIRTUAL",
    3: "FUNC_STATIC",
    4: "FUNC_DISPATCH",
}
INVOKEKIND_NAMES = {
    1: "INVOKE_FUNC",
    2: "INVOKE_PROPERTYGET",
    4: "INVOKE_PROPERTYPUT",
    8: "INVOKE_PROPERTYPUTREF",
}
CALLCONV_NAMES = {
    0: "CC_FASTCALL",
    1: "CC_CDECL",
    2: "CC_MSCPASCAL",
    3: "CC_MACPASCAL",
    4: "CC_STDCALL",
    5: "CC_FPFASTCALL",
    6: "CC_SYSCALL",
    7: "CC_MPWCDECL",
    8: "CC_MPWPASCAL",
    9: "CC_MAX",
}
VARKIND_NAMES = {
    0: "VAR_PERINSTANCE",
    1: "VAR_STATIC",
    2: "VAR_CONST",
    3: "VAR_DISPATCH",
}
SYSKIND_NAMES = {
    0: "SYS_WIN16",
    1: "SYS_WIN32",
    2: "SYS_MAC",
    3: "SYS_WIN64",
}
VT_NAMES = {
    0: "VT_EMPTY",
    1: "VT_NULL",
    2: "VT_I2",
    3: "VT_I4",
    4: "VT_R4",
    5: "VT_R8",
    6: "VT_CY",
    7: "VT_DATE",
    8: "VT_BSTR",
    9: "VT_DISPATCH",
    10: "VT_ERROR",
    11: "VT_BOOL",
    12: "VT_VARIANT",
    13: "VT_UNKNOWN",
    14: "VT_DECIMAL",
    16: "VT_I1",
    17: "VT_UI1",
    18: "VT_UI2",
    19: "VT_UI4",
    20: "VT_I8",
    21: "VT_UI8",
    22: "VT_INT",
    23: "VT_UINT",
    24: "VT_VOID",
    25: "VT_HRESULT",
    26: "VT_PTR",
    27: "VT_SAFEARRAY",
    28: "VT_CARRAY",
    29: "VT_USERDEFINED",
    30: "VT_LPSTR",
    31: "VT_LPWSTR",
    36: "VT_RECORD",
    37: "VT_INT_PTR",
    38: "VT_UINT_PTR",
    64: "VT_FILETIME",
    65: "VT_BLOB",
    66: "VT_STREAM",
    67: "VT_STORAGE",
    68: "VT_STREAMED_OBJECT",
    69: "VT_STORED_OBJECT",
    70: "VT_BLOB_OBJECT",
    71: "VT_CF",
    72: "VT_CLSID",
    73: "VT_VERSIONED_STREAM",
}

# Complete OLE Automation flag tables.  These are intentionally static rather
# than discovered from pywin32: released pywin32 builds omit legal constants
# that FM20 actually uses (including high FUNCFLAG values).
FLAG_TABLES: dict[str, dict[int, str]] = {
    "function": {
        0x0001: "FUNCFLAG_FRESTRICTED",
        0x0002: "FUNCFLAG_FSOURCE",
        0x0004: "FUNCFLAG_FBINDABLE",
        0x0008: "FUNCFLAG_FREQUESTEDIT",
        0x0010: "FUNCFLAG_FDISPLAYBIND",
        0x0020: "FUNCFLAG_FDEFAULTBIND",
        0x0040: "FUNCFLAG_FHIDDEN",
        0x0080: "FUNCFLAG_FUSESGETLASTERROR",
        0x0100: "FUNCFLAG_FDEFAULTCOLLELEM",
        0x0200: "FUNCFLAG_FUIDEFAULT",
        0x0400: "FUNCFLAG_FNONBROWSABLE",
        0x0800: "FUNCFLAG_FREPLACEABLE",
        0x1000: "FUNCFLAG_FIMMEDIATEBIND",
    },
    "idl": {
        0x0001: "IDLFLAG_FIN",
        0x0002: "IDLFLAG_FOUT",
        0x0004: "IDLFLAG_FLCID",
        0x0008: "IDLFLAG_FRETVAL",
    },
    "implementation": {
        0x0001: "IMPLTYPEFLAG_FDEFAULT",
        0x0002: "IMPLTYPEFLAG_FSOURCE",
        0x0004: "IMPLTYPEFLAG_FRESTRICTED",
        0x0008: "IMPLTYPEFLAG_FDEFAULTVTABLE",
    },
    "library": {
        0x0001: "LIBFLAG_FRESTRICTED",
        0x0002: "LIBFLAG_FCONTROL",
        0x0004: "LIBFLAG_FHIDDEN",
        0x0008: "LIBFLAG_FHASDISKIMAGE",
    },
    "parameter": {
        0x0001: "PARAMFLAG_FIN",
        0x0002: "PARAMFLAG_FOUT",
        0x0004: "PARAMFLAG_FLCID",
        0x0008: "PARAMFLAG_FRETVAL",
        0x0010: "PARAMFLAG_FOPT",
        0x0020: "PARAMFLAG_FHASDEFAULT",
        0x0040: "PARAMFLAG_FHASCUSTDATA",
    },
    "type": {
        0x0001: "TYPEFLAG_FAPPOBJECT",
        0x0002: "TYPEFLAG_FCANCREATE",
        0x0004: "TYPEFLAG_FLICENSED",
        0x0008: "TYPEFLAG_FPREDECLID",
        0x0010: "TYPEFLAG_FHIDDEN",
        0x0020: "TYPEFLAG_FCONTROL",
        0x0040: "TYPEFLAG_FDUAL",
        0x0080: "TYPEFLAG_FNONEXTENSIBLE",
        0x0100: "TYPEFLAG_FOLEAUTOMATION",
        0x0200: "TYPEFLAG_FRESTRICTED",
        0x0400: "TYPEFLAG_FAGGREGATABLE",
        0x0800: "TYPEFLAG_FREPLACEABLE",
        0x1000: "TYPEFLAG_FDISPATCHABLE",
        0x2000: "TYPEFLAG_FREVERSEBIND",
        0x4000: "TYPEFLAG_FPROXY",
    },
    "variable": {
        0x0001: "VARFLAG_FREADONLY",
        0x0002: "VARFLAG_FSOURCE",
        0x0004: "VARFLAG_FBINDABLE",
        0x0008: "VARFLAG_FREQUESTEDIT",
        0x0010: "VARFLAG_FDISPLAYBIND",
        0x0020: "VARFLAG_FDEFAULTBIND",
        0x0040: "VARFLAG_FHIDDEN",
        0x0080: "VARFLAG_FRESTRICTED",
        0x0100: "VARFLAG_FDEFAULTCOLLELEM",
        0x0200: "VARFLAG_FUIDEFAULT",
        0x0400: "VARFLAG_FNONBROWSABLE",
        0x0800: "VARFLAG_FREPLACEABLE",
        0x1000: "VARFLAG_FIMMEDIATEBIND",
    },
}

DISPLAY_SCALARS = {
    0: "Empty",
    1: "Null",
    2: "Integer",
    3: "Long",
    4: "Single",
    5: "Double",
    6: "Currency",
    7: "Date",
    8: "String",
    9: "Object",
    10: "Error",
    11: "Boolean",
    12: "Variant",
    13: "IUnknown",
    16: "SignedByte",
    17: "Byte",
    18: "UnsignedInteger",
    19: "UnsignedLong",
    22: "Integer32",
    23: "UnsignedInteger32",
    24: "Void",
    25: "HRESULT",
}


def canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    ).encode("utf-8")


def structural_json_bytes(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, separators=(",", ":"), sort_keys=True
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json_strict(path: Path) -> dict[str, Any]:
    def reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise FactError(f"Duplicate JSON key {key!r} in {path}")
            result[key] = value
        return result

    def reject_constant(value: str) -> None:
        raise FactError(f"Non-finite JSON number {value!r} in {path}")

    try:
        value = json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=reject_duplicates,
            parse_constant=reject_constant,
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise FactError(f"Could not read strict JSON {path}: {error}") from error
    if not isinstance(value, dict):
        raise FactError(f"Expected a JSON object in {path}")
    return value


def normalize_guid(value: Any) -> str:
    return str(value).upper()


def flag_fact(category: str, value: int) -> dict[str, Any]:
    table = FLAG_TABLES[category]
    known_mask = 0
    names = []
    for bit, name in sorted(table.items()):
        known_mask |= bit
        if value & bit:
            names.append(name)
    return {
        "value": value,
        "names": names,
        "unknown_bits": value & ~known_mask,
    }


def json_value(value: Any) -> Any:
    if isinstance(value, float):
        if value != value or value in {float("inf"), float("-inf")}:
            raise FactError("Non-finite COM numeric metadata is unsupported")
        return value
    if value is None or isinstance(value, (bool, int, str)):
        return value
    if isinstance(value, bytes):
        return {"kind": "bytes", "hex": value.hex()}
    if isinstance(value, (tuple, list)):
        return [json_value(item) for item in value]
    if hasattr(value, "isoformat"):
        return {"kind": type(value).__name__, "value": value.isoformat()}
    if type(value).__name__ in {"IID", "PyIID"}:
        return {"kind": "guid", "value": normalize_guid(value)}
    raise FactError(f"Unsupported COM metadata value {type(value)!r}: {value!r}")


def tagged_value(value: Any) -> dict[str, Any]:
    if value is None:
        return {"kind": "null", "value": None}
    if isinstance(value, bool):
        return {"kind": "boolean", "value": value}
    if isinstance(value, int):
        return {"kind": "integer", "value": value}
    if isinstance(value, float):
        if value != value or value in {float("inf"), float("-inf")}:
            raise FactError("Non-finite COM numeric metadata is unsupported")
        return {"kind": "float", "value": value}
    if isinstance(value, str):
        return {"kind": "string", "value": value}
    converted = json_value(value)
    return {"kind": type(value).__name__, "value": converted}


def default_fact(value: Any, parameter_flags: int) -> dict[str, Any]:
    if not parameter_flags & 0x0020:
        return {"state": "not_encoded"}
    return {"state": "encoded", "value": tagged_value(value)}


def raw_descriptor(value: Any) -> Any:
    if isinstance(value, int):
        return value
    if isinstance(value, tuple):
        return [raw_descriptor(item) for item in value]
    raise FactError(f"Unsupported TYPEDESC shape: {value!r}")


def file_versions(path: Path) -> dict[str, str | None]:
    try:
        info = win32api.GetFileVersionInfo(str(path), "\\")
    except Exception:
        return {"file_version": None, "product_version": None}

    def format_version(ms: int, ls: int) -> str:
        return f"{ms >> 16}.{ms & 0xFFFF}.{ls >> 16}.{ls & 0xFFFF}"

    return {
        "file_version": format_version(info["FileVersionMS"], info["FileVersionLS"]),
        "product_version": format_version(
            info["ProductVersionMS"], info["ProductVersionLS"]
        ),
    }


def documentation(owner: Any, index: int) -> dict[str, Any]:
    name, doc, help_context, help_file = owner.GetDocumentation(index)
    help_file_token = help_file
    if isinstance(help_file, str):
        for environment_name in ("ProgramFiles", "SystemRoot"):
            root = os.environ.get(environment_name)
            if root and help_file.lower().startswith(root.lower() + "\\"):
                help_file_token = f"%{environment_name}%" + help_file[len(root) :]
                break
    return {
        "name": name,
        "doc": doc,
        "help_context": help_context,
        "help_file": help_file,
        "help_file_token": help_file_token,
    }


def library_key(attributes: tuple[Any, ...]) -> str:
    guid, lcid, syskind, major, minor, _flags = attributes
    return (
        f"{normalize_guid(guid)}:{major}.{minor}:lcid={lcid}:syskind={syskind}"
    )


def _resolve_registered_path(guid: str, major: int, minor: int, lcid: int) -> Path:
    try:
        raw_path = str(pythoncom.QueryPathOfRegTypeLib(guid, major, minor, lcid))
    except pythoncom.com_error as error:
        raise FactError(
            f"Could not resolve registered typelib {guid} {major}.{minor} LCID {lcid}"
        ) from error
    candidate = raw_path.strip().strip('"')
    path = Path(candidate)
    if not path.exists():
        base, separator, suffix = candidate.rpartition("\\")
        if separator and suffix.isdigit() and Path(base).exists():
            path = Path(base)
    if not path.exists():
        raise FactError(f"Registered typelib path does not exist: {raw_path!r}")
    return path.resolve(strict=True)


def _libattr_object(attributes: tuple[Any, ...]) -> dict[str, Any]:
    guid, lcid, syskind, major, minor, flags = attributes
    return {
        "guid": normalize_guid(guid),
        "lcid": int(lcid),
        "syskind": int(syskind),
        "major_version": int(major),
        "minor_version": int(minor),
        "library_flags": int(flags),
    }


def validate_pin_manifest(pins: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if set(pins) != {"schema", "schema_version", "capture_runtime", "libraries"}:
        errors.append("typelib pin root keys are malformed")
    if pins.get("schema") != "oxforms.fm20_typelib_pins.v1" or pins.get(
        "schema_version"
    ) != 1:
        return ["unexpected typelib pin schema/version"]
    runtime = pins.get("capture_runtime", {})
    if set(runtime) != {
        "python_version",
        "pywin32_version",
        "process_bits",
        "platform",
    }:
        errors.append("typelib capture_runtime pin is malformed")
    libraries = pins.get("libraries")
    if not isinstance(libraries, list) or len(libraries) != 2:
        return ["typelib pins must contain exactly FM20 and stdole"]
    roles = [item.get("role") for item in libraries if isinstance(item, dict)]
    if roles != ["root", "referenced"]:
        errors.append("typelib pins must be ordered root, referenced")
    guids = [item.get("libattr", {}).get("guid") for item in libraries]
    if guids != [FM20_LIBID, STDOLE_LIBID]:
        errors.append("typelib pin GUIDs do not identify FM20 and stdole")
    for item in libraries:
        name = item.get("name", "unknown")
        if set(item) != {
            "role",
            "name",
            "path",
            "file_name",
            "size_bytes",
            "sha256",
            "file_version",
            "product_version",
            "libattr",
        }:
            errors.append(f"{name}: malformed pinned library keys")
        if not isinstance(item.get("path"), str) or not item.get("path"):
            errors.append(f"{name}: pinned path missing")
        if not isinstance(item.get("size_bytes"), int) or item.get("size_bytes", 0) <= 0:
            errors.append(f"{name}: pinned size invalid")
        sha = item.get("sha256")
        if not isinstance(sha, str) or len(sha) != 64 or sha.lower() != sha:
            errors.append(f"{name}: pinned SHA-256 must be 64 lowercase hex digits")
        elif any(character not in "0123456789abcdef" for character in sha):
            errors.append(f"{name}: pinned SHA-256 is not hexadecimal")
        expected_libattr_keys = {
            "guid",
            "lcid",
            "syskind",
            "major_version",
            "minor_version",
            "library_flags",
        }
        if set(item.get("libattr", {})) != expected_libattr_keys:
            errors.append(f"{name}: malformed pinned LIBATTR")
    return errors


def validate_live_pins(pins: dict[str, Any]) -> list[str]:
    errors = validate_pin_manifest(pins)
    if errors:
        return errors
    if pythoncom is None or win32api is None:
        return ["live pin validation requires pywin32 (pythoncom and win32api)"]
    runtime = pins["capture_runtime"]
    try:
        live_pywin32_version = importlib.metadata.version("pywin32")
    except importlib.metadata.PackageNotFoundError:
        live_pywin32_version = "unknown"
    live_runtime = {
        "python_version": platform.python_version(),
        "pywin32_version": live_pywin32_version,
        "process_bits": struct.calcsize("P") * 8,
        "platform": platform.platform(),
    }
    if live_runtime != runtime:
        errors.append(
            f"capture runtime mismatch ({live_runtime!r} != {runtime!r})"
        )
    for item in pins["libraries"]:
        name = item["name"]
        path = Path(item["path"])
        if not path.is_file():
            errors.append(f"{name}: pinned source missing: {path}")
            continue
        if path.stat().st_size != item["size_bytes"]:
            errors.append(f"{name}: pinned source size mismatch")
        if sha256_file(path) != item["sha256"]:
            errors.append(f"{name}: pinned source SHA-256 mismatch")
        versions = file_versions(path)
        for field in ("file_version", "product_version"):
            if versions[field] != item[field]:
                errors.append(
                    f"{name}: {field} mismatch ({versions[field]!r} != {item[field]!r})"
                )
        try:
            typelib = pythoncom.LoadTypeLib(str(path.resolve(strict=True)))
            actual_libattr = _libattr_object(tuple(typelib.GetLibAttr()))
        except pythoncom.com_error as error:
            errors.append(f"{name}: could not load pinned typelib: {error}")
            continue
        if actual_libattr != item["libattr"]:
            errors.append(f"{name}: pinned LIBATTR mismatch")
        if item["role"] == "referenced":
            libattr = item["libattr"]
            try:
                registered = _resolve_registered_path(
                    libattr["guid"],
                    libattr["major_version"],
                    libattr["minor_version"],
                    libattr["lcid"],
                )
            except FactError as error:
                errors.append(f"{name}: {error}")
            else:
                if registered != path.resolve(strict=True):
                    errors.append(
                        f"{name}: registry path {registered} differs from pinned path {path}"
                    )
    return errors


def validate_fact_pack_against_pins(
    facts: dict[str, Any], pins: dict[str, Any]
) -> list[str]:
    errors = validate_pin_manifest(pins)
    if errors:
        return errors
    generator = facts.get("generator", {})
    actual_runtime = {
        "python_version": generator.get("python_version"),
        "pywin32_version": generator.get("pywin32_version"),
        "process_bits": generator.get("process_bits"),
        "platform": generator.get("platform"),
    }
    if actual_runtime != pins["capture_runtime"]:
        errors.append("fact-pack capture runtime differs from pins")
    by_guid = {
        library.get("attributes", {}).get("guid"): library
        for library in facts.get("libraries", [])
    }
    for pin in pins["libraries"]:
        name = pin["name"]
        library = by_guid.get(pin["libattr"]["guid"])
        if library is None:
            errors.append(f"{name}: pinned library missing from fact pack")
            continue
        if library.get("role") != pin["role"]:
            errors.append(f"{name}: fact-pack library role differs from pins")
        attrs = library.get("attributes", {})
        actual_libattr = {
            "guid": attrs.get("guid"),
            "lcid": attrs.get("lcid"),
            "syskind": attrs.get("syskind"),
            "major_version": attrs.get("major_version"),
            "minor_version": attrs.get("minor_version"),
            "library_flags": attrs.get("library_flags", {}).get("value"),
        }
        if actual_libattr != pin["libattr"]:
            errors.append(f"{name}: fact-pack LIBATTR differs from pins")
        source = library.get("source", {})
        if Path(source.get("path", "")) != Path(pin["path"]):
            errors.append(f"{name}: fact-pack source path differs from pins")
        for field in (
            "file_name",
            "size_bytes",
            "sha256",
            "file_version",
            "product_version",
        ):
            if source.get(field) != pin[field]:
                errors.append(f"{name}: fact-pack source {field} differs from pins")
    return errors


def validate_w005_baseline_pin(
    pin: dict[str, Any], w005: dict[str, Any], *, w005_path: Path
) -> list[str]:
    errors: list[str] = []
    if set(pin) != {
        "schema",
        "schema_version",
        "artifact",
        "counts",
        "included_events",
        "lifecycle_events_checked_by_name",
    }:
        errors.append("W005 baseline pin root keys are malformed")
    if pin.get("schema") != "oxforms.fm20_w005_baseline_pin.v1" or pin.get(
        "schema_version"
    ) != 1:
        return ["unexpected W005 baseline pin schema/version"]
    artifact = pin.get("artifact", {})
    if set(artifact) != {
        "path",
        "size_bytes",
        "sha256",
        "schema",
        "recorded_fm20_sha256",
    }:
        errors.append("W005 baseline artifact pin keys are malformed")
    resolved = w005_path.resolve(strict=True)
    repo_root = Path(__file__).resolve().parents[2]
    try:
        displayed_path = resolved.relative_to(repo_root).as_posix()
    except ValueError:
        displayed_path = resolved.as_posix()
    observed_artifact = {
        "path": displayed_path,
        "size_bytes": resolved.stat().st_size,
        "sha256": sha256_file(resolved),
        "schema": w005.get("schema"),
        "recorded_fm20_sha256": w005.get("source", {}).get("sha256", "").lower(),
    }
    if observed_artifact != artifact:
        errors.append("W005 artifact identity differs from its independent pin")
    observed_counts = {
        "attachments": len(w005.get("source_interfaces", [])),
        "arguments": sum(len(row.get("args", [])) for row in w005.get("rows", [])),
        "event_names": len({row.get("event_name") for row in w005.get("rows", [])}),
        "rows": len(w005.get("rows", [])),
        "source_interfaces": len(
            {
                row.get("source_interface_guid", "").upper()
                for row in w005.get("source_interfaces", [])
            }
        ),
    }
    if observed_counts != pin.get("counts"):
        errors.append("W005 artifact counts differ from their independent pin")
    if w005.get("scope", {}).get("included_events") != pin.get("included_events"):
        errors.append("W005 included-event set/order differs from its independent pin")
    if w005.get("scope", {}).get("lifecycle_events_checked_by_name") != pin.get(
        "lifecycle_events_checked_by_name"
    ):
        errors.append("W005 lifecycle-event set/order differs from its independent pin")
    return errors


def validate_expected_capture(
    expected: dict[str, Any],
    facts: dict[str, Any],
    comparison: dict[str, Any],
) -> list[str]:
    errors: list[str] = []
    expected_keys = {
        "schema",
        "schema_version",
        "fact_schema",
        "fact_canonical_sha256",
        "fact_counts",
        "comparison_schema",
        "comparison_classification",
        "comparison_row_count",
        "comparison_structural_delta_count",
    }
    if set(expected) != expected_keys:
        errors.append("expected-capture pin keys are malformed")
    if expected.get("schema") != "oxforms.fm20_expected_capture.v1" or expected.get(
        "schema_version"
    ) != 1:
        return ["unexpected expected-capture pin schema/version"]
    observed_counts = {
        field: facts.get("summary", {}).get(field)
        for field in (
            "exported_type_view_count",
            "function_count",
            "variable_count",
            "implementation_edge_count",
            "parameter_count",
            "type_reference_count",
        )
    }
    observed = {
        "fact_schema": facts.get("schema"),
        "fact_canonical_sha256": facts.get("canonical_sha256"),
        "fact_counts": observed_counts,
        "comparison_schema": comparison.get("schema"),
        "comparison_classification": comparison.get("classification"),
        "comparison_row_count": len(comparison.get("row_results", [])),
        "comparison_structural_delta_count": comparison.get(
            "structural_delta_count"
        ),
    }
    pinned = {key: expected.get(key) for key in observed}
    if observed != pinned:
        errors.append(
            "generated semantic capture differs from the independently reviewed pin"
        )
    return errors


class TypeLibExporter:
    """Export every FM20 primary/dual view plus the minimal external closure."""

    VIEW_ORDER = {"primary": 0, "dual_interface": 1}
    REASON_ORDER = {
        "root_primary": 0,
        "root_dual_companion": 1,
        "direct_reference": 2,
        "transitive_reference": 3,
        "public_alias_of_reached_type": 4,
    }

    def __init__(self, root_path: Path) -> None:
        if pythoncom is None or win32api is None:
            raise FactError("live typelib export requires pywin32")
        self.root_path = root_path.resolve(strict=True)
        self.root_key = ""
        self._registered: dict[str, dict[str, Any]] = {}
        self._records: dict[tuple[str, int, str], dict[str, Any]] = {}
        self._inclusion_reasons: dict[tuple[str, int, str], set[str]] = {}
        self._pending_external: list[tuple[str, int, str]] = []
        self.type_references: list[dict[str, Any]] = []

    def _register_library(
        self, typelib: Any, *, role: str, path: Path | None = None
    ) -> str:
        attributes = tuple(typelib.GetLibAttr())
        key = library_key(attributes)
        if key in self._registered:
            if role == "root":
                self._registered[key]["role"] = "root"
            return key
        guid, lcid, _syskind, major, minor, _flags = attributes
        if path is None:
            source_path = _resolve_registered_path(
                normalize_guid(guid), major, minor, lcid
            )
            reloaded = pythoncom.LoadTypeLib(str(source_path))
            reloaded_attributes = tuple(reloaded.GetLibAttr())
            if reloaded_attributes != attributes:
                raise FactError(
                    f"Registered typelib {source_path} LIBATTR differs from the "
                    "transitively encountered library"
                )
            typelib = reloaded
        else:
            source_path = path
        self._registered[key] = {
            "typelib": typelib,
            "attributes": attributes,
            "path": source_path,
            "role": role,
        }
        return key

    def _identity_parts(self, type_info: Any) -> tuple[str, int, str]:
        containing, index = type_info.GetContainingTypeLib()
        key = self._register_library(containing, role="referenced")
        actual = type_info.GetTypeAttr()
        primary = containing.GetTypeInfo(index).GetTypeAttr()
        if actual.typekind == primary.typekind:
            view = "primary"
        elif (
            primary.typekind == pythoncom.TKIND_DISPATCH
            and actual.typekind == pythoncom.TKIND_INTERFACE
            and normalize_guid(actual.iid) == normalize_guid(primary.iid)
        ):
            view = "dual_interface"
        else:
            raise FactError(
                f"Unclassifiable type-info view at {key} index {index}: "
                f"primary kind {primary.typekind}, actual kind {actual.typekind}"
            )
        return key, index, view

    def _type_identity(self, type_info: Any) -> dict[str, Any]:
        key, index, view = self._identity_parts(type_info)
        attr = type_info.GetTypeAttr()
        doc = documentation(type_info, -1)
        return {
            "library_key": key,
            "type_index": index,
            "view": view,
            "name": doc["name"],
            "guid": normalize_guid(attr.iid),
            "typekind": attr.typekind,
            "typekind_name": TYPEKIND_NAMES.get(attr.typekind, "UNKNOWN_TYPEKIND"),
        }

    def _request_external(
        self, identity: dict[str, Any], *, reason: str
    ) -> None:
        view_key = (
            identity["library_key"],
            identity["type_index"],
            identity["view"],
        )
        if view_key[0] == self.root_key:
            return
        reasons = self._inclusion_reasons.setdefault(view_key, set())
        reasons.add(reason)
        if view_key not in self._records and view_key not in self._pending_external:
            self._pending_external.append(view_key)

    def _record_reference(
        self,
        *,
        from_library: str,
        from_type_index: int,
        from_type_view: str,
        context: str,
        href: int,
        target: dict[str, Any],
        reference_kind: str,
    ) -> None:
        self.type_references.append(
            {
                "from_library_key": from_library,
                "from_type_index": from_type_index,
                "from_type_view": from_type_view,
                "context": context,
                "reference_kind": reference_kind,
                "raw_href": href,
                "target": target,
            }
        )
        self._request_external(
            target,
            reason=(
                "direct_reference"
                if from_library == self.root_key
                else "transitive_reference"
            ),
        )

    def describe_type(
        self,
        owner: Any,
        value: Any,
        *,
        from_library: str,
        from_type_index: int,
        from_type_view: str,
        context: str,
    ) -> dict[str, Any]:
        if isinstance(value, int):
            vt = value
            tuple_value: tuple[Any, ...] | None = None
        elif isinstance(value, tuple) and value and isinstance(value[0], int):
            vt = value[0]
            tuple_value = value
        else:
            raise FactError(f"Invalid TYPEDESC at {context}: {value!r}")

        result: dict[str, Any] = {
            "raw": raw_descriptor(value),
            "vt": vt,
            "vt_name": VT_NAMES.get(vt, f"VT_UNKNOWN_{vt}"),
        }
        if vt == pythoncom.VT_PTR:
            if tuple_value is None or len(tuple_value) != 2:
                raise FactError(f"Malformed VT_PTR at {context}: {value!r}")
            target = self.describe_type(
                owner,
                tuple_value[1],
                from_library=from_library,
                from_type_index=from_type_index,
                from_type_view=from_type_view,
                context=f"{context}.target",
            )
            result.update(
                {"kind": "pointer", "target": target, "display": target["display"] + "*"}
            )
            return result
        if vt == pythoncom.VT_USERDEFINED:
            if tuple_value is None or len(tuple_value) != 2:
                raise FactError(f"Malformed VT_USERDEFINED at {context}: {value!r}")
            href = tuple_value[1]
            try:
                target_info = owner.GetRefTypeInfo(href)
            except pythoncom.com_error as error:
                raise FactError(f"Unresolved HREFTYPE {href} at {context}") from error
            target = self._type_identity(target_info)
            self._record_reference(
                from_library=from_library,
                from_type_index=from_type_index,
                from_type_view=from_type_view,
                context=context,
                href=href,
                target=target,
                reference_kind="typedesc",
            )
            result.update(
                {
                    "kind": "userdefined",
                    "raw_href": href,
                    "target": target,
                    "display": target["name"],
                }
            )
            return result
        if vt == pythoncom.VT_CARRAY:
            if tuple_value is None or len(tuple_value) != 2:
                raise FactError(f"Malformed VT_CARRAY at {context}: {value!r}")
            payload = tuple_value[1]
            if not isinstance(payload, tuple) or len(payload) != 2:
                raise FactError(f"Malformed ARRAYDESC at {context}: {payload!r}")
            element = self.describe_type(
                owner,
                payload[0],
                from_library=from_library,
                from_type_index=from_type_index,
                from_type_view=from_type_view,
                context=f"{context}.element",
            )
            raw_bounds = payload[1]
            if (
                isinstance(raw_bounds, tuple)
                and len(raw_bounds) == 2
                and all(isinstance(item, int) for item in raw_bounds)
            ):
                bounds = [
                    {"element_count": raw_bounds[0], "lower_bound": raw_bounds[1]}
                ]
            elif isinstance(raw_bounds, tuple):
                bounds = [
                    {"element_count": bound[0], "lower_bound": bound[1]}
                    for bound in raw_bounds
                ]
            else:
                raise FactError(f"Malformed array bounds at {context}: {raw_bounds!r}")
            result.update(
                {
                    "kind": "c_array",
                    "element": element,
                    "bounds": bounds,
                    "display": element["display"] + "[]",
                }
            )
            return result

        result.update(
            {
                "kind": "scalar",
                "display": DISPLAY_SCALARS.get(vt, result["vt_name"]),
            }
        )
        if tuple_value is not None and len(tuple_value) > 1:
            result["uninterpreted_payload"] = json_value(tuple_value[1:])
        return result

    def _element_description(
        self,
        owner: Any,
        value: tuple[Any, Any, Any],
        *,
        from_library: str,
        from_type_index: int,
        from_type_view: str,
        flag_category: str,
        context: str,
    ) -> dict[str, Any]:
        if not isinstance(value, tuple) or len(value) != 3:
            raise FactError(f"Malformed ELEMDESC at {context}: {value!r}")
        flags = int(value[1])
        return {
            "raw": json_value(value),
            "type": self.describe_type(
                owner,
                value[0],
                from_library=from_library,
                from_type_index=from_type_index,
                from_type_view=from_type_view,
                context=f"{context}.type",
            ),
            f"{flag_category}_flags": flag_fact(flag_category, flags),
            "default": default_fact(value[2], flags)
            if flag_category == "parameter"
            else None,
        }

    def _export_function(
        self,
        type_info: Any,
        type_index: int,
        type_view: str,
        function_index: int,
        key: str,
    ) -> dict[str, Any]:
        desc = type_info.GetFuncDesc(function_index)
        names = list(type_info.GetNames(desc.memid))
        doc = documentation(type_info, desc.memid)
        parameters = []
        for parameter_index, argument in enumerate(desc.args):
            element = self._element_description(
                type_info,
                argument,
                from_library=key,
                from_type_index=type_index,
                from_type_view=type_view,
                flag_category="parameter",
                context=f"type[{type_index}:{type_view}].function[{function_index}].parameter[{parameter_index}]",
            )
            parameters.append(
                {
                    "index": parameter_index,
                    "name": names[parameter_index + 1]
                    if parameter_index + 1 < len(names)
                    else None,
                    "name_state": "reported_by_GetNames"
                    if parameter_index + 1 < len(names)
                    else "not_reported_by_GetNames",
                    **element,
                }
            )
        def optional_adapter_metadata(method_name: str, *arguments: Any) -> dict[str, Any]:
            method = getattr(type_info, method_name, None)
            if method is None:
                return {"state": "not_exposed_by_pywin32", "value": None}
            try:
                return {"state": "reported", "value": json_value(method(*arguments))}
            except pythoncom.com_error:
                return {"state": "not_available_for_member", "value": None}

        dll_entry = optional_adapter_metadata(
            "GetDllEntry", desc.memid, desc.invkind
        )
        mops = optional_adapter_metadata("GetMops", desc.memid)
        function_flags = int(desc.wFuncFlags)
        decoded_function_flags = flag_fact("function", function_flags)
        return {
            "index": function_index,
            "memid": desc.memid,
            "names": names,
            "documentation": doc,
            "scode_array": json_value(desc.scodeArray),
            "function_kind": desc.funckind,
            "function_kind_name": FUNCKIND_NAMES.get(
                desc.funckind, "UNKNOWN_FUNCKIND"
            ),
            "invoke_kind": desc.invkind,
            "invoke_kind_name": INVOKEKIND_NAMES.get(
                desc.invkind, "UNKNOWN_INVOKEKIND"
            ),
            "call_convention": desc.callconv,
            "call_convention_name": CALLCONV_NAMES.get(
                desc.callconv, "UNKNOWN_CALLCONV"
            ),
            "parameter_count": len(desc.args),
            "optional_parameter_count": desc.cParamsOpt,
            "vtable_offset": desc.oVft,
            "return": self._element_description(
                type_info,
                desc.rettype,
                from_library=key,
                from_type_index=type_index,
                from_type_view=type_view,
                flag_category="parameter",
                context=f"type[{type_index}:{type_view}].function[{function_index}].return",
            ),
            "function_flags": decoded_function_flags,
            "parameters": parameters,
            "dll_entry": dll_entry,
            "mops": mops,
            "is_default_member": desc.memid == 0
            or "FUNCFLAG_FDEFAULTBIND" in decoded_function_flags["names"],
            "is_new_enum": desc.memid == -4,
        }

    def _export_variable(
        self,
        type_info: Any,
        type_index: int,
        type_view: str,
        variable_index: int,
        key: str,
    ) -> dict[str, Any]:
        desc = type_info.GetVarDesc(variable_index)
        union_kind = {
            0: "instance_offset",
            1: "static_value_not_exposed",
            2: "constant_value",
            3: "dispatch_member_no_value",
        }.get(desc.varkind, "unknown")
        return {
            "index": variable_index,
            "memid": desc.memid,
            "names": list(type_info.GetNames(desc.memid)),
            "documentation": documentation(type_info, desc.memid),
            "union_value": {
                "kind": union_kind,
                "value": tagged_value(desc.value),
            },
            "element": self._element_description(
                type_info,
                desc.elemdescVar,
                from_library=key,
                from_type_index=type_index,
                from_type_view=type_view,
                flag_category="idl",
                context=f"type[{type_index}:{type_view}].variable[{variable_index}]",
            ),
            "variable_flags": flag_fact("variable", int(desc.wVarFlags)),
            "variable_kind": desc.varkind,
            "variable_kind_name": VARKIND_NAMES.get(
                desc.varkind, "UNKNOWN_VARKIND"
            ),
        }

    def _get_type_info(self, key: str, type_index: int, view: str) -> Any:
        typelib = self._registered[key]["typelib"]
        primary = typelib.GetTypeInfo(type_index)
        if view == "primary":
            return primary
        if view == "dual_interface":
            href = primary.GetRefTypeOfImplType(-1)
            return primary.GetRefTypeInfo(href)
        raise FactError(f"Unsupported type-info view {view!r}")

    def _export_type_view(
        self, key: str, type_index: int, view: str
    ) -> dict[str, Any]:
        typelib = self._registered[key]["typelib"]
        type_info = self._get_type_info(key, type_index, view)
        attr = type_info.GetTypeAttr()
        functions = [
            self._export_function(type_info, type_index, view, index, key)
            for index in range(attr.cFuncs)
        ]
        variables = [
            self._export_variable(type_info, type_index, view, index, key)
            for index in range(attr.cVars)
        ]
        implemented_types = []
        for impl_index in range(attr.cImplTypes):
            href = type_info.GetRefTypeOfImplType(impl_index)
            try:
                target_info = type_info.GetRefTypeInfo(href)
            except pythoncom.com_error as error:
                raise FactError(
                    f"Unresolved implementation HREFTYPE {href} at "
                    f"type[{type_index}:{view}].impl[{impl_index}]"
                ) from error
            target = self._type_identity(target_info)
            impl_flags = int(type_info.GetImplTypeFlags(impl_index))
            self._record_reference(
                from_library=key,
                from_type_index=type_index,
                from_type_view=view,
                context=f"type[{type_index}:{view}].implementation[{impl_index}]",
                href=href,
                target=target,
                reference_kind="implementation",
            )
            implemented_types.append(
                {
                    "index": impl_index,
                    "raw_href": href,
                    "implementation_flags": flag_fact("implementation", impl_flags),
                    "roles": [
                        role
                        for bit, role in (
                            (0x0001, "default"),
                            (0x0002, "source"),
                            (0x0004, "restricted"),
                            (0x0008, "default_vtable"),
                        )
                        if impl_flags & bit
                    ],
                    "target": target,
                }
            )
        alias = None
        if attr.tdescAlias is not None:
            alias = self.describe_type(
                type_info,
                attr.tdescAlias,
                from_library=key,
                from_type_index=type_index,
                from_type_view=view,
                context=f"type[{type_index}:{view}].alias",
            )
        view_key = (key, type_index, view)
        reasons = sorted(
            self._inclusion_reasons.get(view_key, set()),
            key=lambda item: self.REASON_ORDER[item],
        )
        coclass_map = None
        if attr.typekind == pythoncom.TKIND_COCLASS:
            coclass_map = {
                "ordinary_default_indices": [
                    row["index"]
                    for row in implemented_types
                    if "default" in row["roles"] and "source" not in row["roles"]
                ],
                "source_default_indices": [
                    row["index"]
                    for row in implemented_types
                    if "default" in row["roles"] and "source" in row["roles"]
                ],
                "source_indices": [
                    row["index"]
                    for row in implemented_types
                    if "source" in row["roles"]
                ],
                "restricted_indices": [
                    row["index"]
                    for row in implemented_types
                    if "restricted" in row["roles"]
                ],
            }
        return {
            "index": type_index,
            "view": view,
            "inclusion_reasons": reasons,
            "documentation": documentation(typelib, type_index),
            "attributes": {
                "guid": normalize_guid(attr.iid),
                "lcid": attr.lcid,
                "memid_constructor": attr.memidConstructor,
                "memid_destructor": attr.memidDestructor,
                "size_instance": attr.cbSizeInstance,
                "typekind": attr.typekind,
                "typekind_name": TYPEKIND_NAMES.get(
                    attr.typekind, "UNKNOWN_TYPEKIND"
                ),
                "function_count": attr.cFuncs,
                "variable_count": attr.cVars,
                "implementation_count": attr.cImplTypes,
                "vtable_size": attr.cbSizeVft,
                "alignment": attr.cbAlignment,
                "type_flags": flag_fact("type", int(attr.wTypeFlags)),
                "major_version": attr.wMajorVerNum,
                "minor_version": attr.wMinorVerNum,
                "raw_alias": raw_descriptor(attr.tdescAlias)
                if attr.tdescAlias is not None
                else None,
                "idl_description": {
                    "reserved": attr.idldescType[0],
                    "flags": flag_fact("idl", int(attr.idldescType[1])),
                },
            },
            "alias_type": alias,
            "functions": functions,
            "variables": variables,
            "implemented_types": implemented_types,
            "coclass_map": coclass_map,
            "dual_companion": None,
            "dual_primary": None,
            "default_function_indices": [
                function["index"] for function in functions if function["is_default_member"]
            ],
            "new_enum_function_indices": [
                function["index"] for function in functions if function["is_new_enum"]
            ],
        }

    def _store_view(self, key: str, index: int, view: str) -> None:
        view_key = (key, index, view)
        if view_key not in self._records:
            self._records[view_key] = self._export_type_view(key, index, view)

    def _drain_external_queue(self) -> None:
        while self._pending_external:
            view_key = self._pending_external.pop(0)
            self._store_view(*view_key)

    def _include_public_alias_companions(self) -> bool:
        reached = set(self._records) | set(self._pending_external)
        added = False
        for key in sorted(self._registered):
            if key == self.root_key:
                continue
            typelib = self._registered[key]["typelib"]
            for index in range(typelib.GetTypeInfoCount()):
                view_key = (key, index, "primary")
                if view_key in reached:
                    continue
                type_info = typelib.GetTypeInfo(index)
                attr = type_info.GetTypeAttr()
                if attr.typekind != pythoncom.TKIND_ALIAS or attr.tdescAlias is None:
                    continue
                if int(attr.wTypeFlags) & (0x0010 | 0x0200):
                    continue
                raw = attr.tdescAlias
                if not (
                    isinstance(raw, tuple)
                    and len(raw) == 2
                    and raw[0] == pythoncom.VT_USERDEFINED
                ):
                    continue
                target_key = self._identity_parts(type_info.GetRefTypeInfo(raw[1]))
                if target_key not in reached:
                    continue
                identity = self._type_identity(type_info)
                self._request_external(
                    identity, reason="public_alias_of_reached_type"
                )
                reached.add(view_key)
                added = True
        return added

    def _export_library_record(self, key: str) -> dict[str, Any]:
        registered = self._registered[key]
        typelib = registered["typelib"]
        path: Path = registered["path"]
        guid, lcid, syskind, major, minor, flags = registered["attributes"]
        types = [
            record
            for (record_key, _index, _view), record in self._records.items()
            if record_key == key
        ]
        for record in types:
            view_key = (key, record["index"], record["view"])
            record["inclusion_reasons"] = sorted(
                self._inclusion_reasons[view_key],
                key=lambda item: self.REASON_ORDER[item],
            )
        types.sort(key=lambda item: (item["index"], self.VIEW_ORDER[item["view"]]))
        primary_census = Counter(
            item["attributes"]["typekind_name"]
            for item in types
            if item["view"] == "primary"
        )
        view_census = Counter(
            f"{item['view']}:{item['attributes']['typekind_name']}" for item in types
        )
        return {
            "key": key,
            "role": registered["role"],
            "documentation": documentation(typelib, -1),
            "attributes": {
                "guid": normalize_guid(guid),
                "lcid": lcid,
                "syskind": syskind,
                "syskind_name": SYSKIND_NAMES.get(syskind, "UNKNOWN_SYSKIND"),
                "major_version": major,
                "minor_version": minor,
                "library_flags": flag_fact("library", int(flags)),
            },
            "source": {
                "path": str(path),
                "file_name": path.name,
                "size_bytes": path.stat().st_size,
                "sha256": sha256_file(path),
                **file_versions(path),
            },
            "declared_type_info_count": typelib.GetTypeInfoCount(),
            "exported_view_count": len(types),
            "exported_primary_count": sum(
                item["view"] == "primary" for item in types
            ),
            "primary_census": dict(sorted(primary_census.items())),
            "view_census": dict(sorted(view_census.items())),
            "types": types,
        }

    def export(self, generator_paths: Iterable[Path]) -> dict[str, Any]:
        root = pythoncom.LoadTypeLib(str(self.root_path))
        self.root_key = self._register_library(
            root, role="root", path=self.root_path
        )
        for index in range(root.GetTypeInfoCount()):
            primary_key = (self.root_key, index, "primary")
            self._inclusion_reasons[primary_key] = {"root_primary"}
            self._store_view(*primary_key)
            primary = root.GetTypeInfo(index)
            attr = primary.GetTypeAttr()
            if (
                attr.typekind == pythoncom.TKIND_DISPATCH
                and int(attr.wTypeFlags) & 0x0040
            ):
                dual_key = (self.root_key, index, "dual_interface")
                self._inclusion_reasons[dual_key] = {"root_dual_companion"}
                self._store_view(*dual_key)
                raw_dual_href = primary.GetRefTypeOfImplType(-1)
                dual_info = primary.GetRefTypeInfo(raw_dual_href)
                self._records[primary_key]["dual_companion"] = {
                    "raw_href": raw_dual_href,
                    "target": self._type_identity(dual_info),
                }
                self._records[dual_key]["dual_primary"] = self._type_identity(primary)

        self._drain_external_queue()
        while self._include_public_alias_companions():
            self._drain_external_queue()

        libraries = [self._export_library_record(self.root_key)] + [
            self._export_library_record(key)
            for key in sorted(self._registered)
            if key != self.root_key
        ]
        references = sorted(
            self.type_references,
            key=lambda row: (
                row["from_library_key"],
                row["from_type_index"],
                self.VIEW_ORDER[row["from_type_view"]],
                row["context"],
                row["reference_kind"],
                row["raw_href"],
                row["target"]["library_key"],
                row["target"]["type_index"],
                self.VIEW_ORDER[row["target"]["view"]],
            ),
        )
        edge_counts: Counter[tuple[str, str]] = Counter(
            (row["from_library_key"], row["target"]["library_key"])
            for row in references
            if row["from_library_key"] != row["target"]["library_key"]
        )
        edges = [
            {
                "from_library_key": source,
                "to_library_key": target,
                "reference_count": count,
            }
            for (source, target), count in sorted(edge_counts.items())
        ]
        flag_definitions = {
            category: [
                {"bit": bit, "name": name} for bit, name in sorted(table.items())
            ]
            for category, table in sorted(FLAG_TABLES.items())
        }
        canonical = {
            "root_library_key": self.root_key,
            "flag_definitions": flag_definitions,
            "libraries": libraries,
            "type_references": references,
            "library_reference_edges": edges,
        }
        repo_root = Path(__file__).resolve().parents[2]
        generator_sources = []
        for path in generator_paths:
            resolved = path.resolve(strict=True)
            generator_sources.append(
                {
                    "path": resolved.relative_to(repo_root).as_posix(),
                    "sha256": sha256_file(resolved),
                }
            )
        try:
            pywin32_version = importlib.metadata.version("pywin32")
        except importlib.metadata.PackageNotFoundError:
            pywin32_version = "unknown"
        all_types = [item for library in libraries for item in library["types"]]
        all_functions = [
            function for item in all_types for function in item["functions"]
        ]
        all_variables = [
            variable for item in all_types for variable in item["variables"]
        ]
        all_implementations = [
            implementation
            for item in all_types
            for implementation in item["implemented_types"]
        ]
        all_parameters = [
            parameter
            for function in all_functions
            for parameter in function["parameters"]
        ]
        return {
            "schema": FACT_SCHEMA,
            "schema_version": 1,
            "generator": {
                "implementation": "pywin32 public ITypeLib/ITypeInfo metadata",
                "source_files": sorted(
                    generator_sources, key=lambda item: item["path"]
                ),
                "python_version": platform.python_version(),
                "pywin32_version": pywin32_version,
                "process_bits": struct.calcsize("P") * 8,
                "platform": platform.platform(),
            },
            **canonical,
            "summary": {
                "library_count": len(libraries),
                "external_library_count": len(libraries) - 1,
                "declared_type_info_count": sum(
                    library["declared_type_info_count"] for library in libraries
                ),
                "exported_type_view_count": sum(
                    library["exported_view_count"] for library in libraries
                ),
                "exported_primary_count": sum(
                    library["exported_primary_count"] for library in libraries
                ),
                "dual_interface_count": sum(
                    item["view"] == "dual_interface" for item in all_types
                ),
                "function_count": len(all_functions),
                "variable_count": len(all_variables),
                "implementation_edge_count": len(all_implementations),
                "parameter_count": len(all_parameters),
                "parameter_name_not_reported_count": sum(
                    parameter["name_state"] == "not_reported_by_GetNames"
                    for parameter in all_parameters
                ),
                "encoded_parameter_default_count": sum(
                    parameter["default"]["state"] == "encoded"
                    for parameter in all_parameters
                ),
                "type_reference_count": len(references),
            },
            "canonical_sha256": sha256_bytes(structural_json_bytes(canonical)),
        }


def _walk_descriptors(value: Any) -> Iterable[dict[str, Any]]:
    if isinstance(value, dict) and "vt" in value and "kind" in value:
        yield value
        for key in ("target", "element"):
            child = value.get(key)
            if isinstance(child, dict) and "vt" in child:
                yield from _walk_descriptors(child)


def _library_type_lookup(
    facts: dict[str, Any],
) -> dict[tuple[str, int, str], dict[str, Any]]:
    return {
        (library["key"], item["index"], item["view"]): item
        for library in facts["libraries"]
        for item in library["types"]
    }


def _flag_error(value: Any, category: str, location: str) -> str | None:
    if not isinstance(value, dict) or set(value) != {"value", "names", "unknown_bits"}:
        return f"{location}: malformed {category} flag fact"
    if not isinstance(value["value"], int) or not isinstance(value["unknown_bits"], int):
        return f"{location}: non-integer {category} flag value"
    if value != flag_fact(category, value["value"]):
        return f"{location}: incorrect {category} flag decoding"
    if value["unknown_bits"] != 0:
        return f"{location}: unexplained {category} flag bits {value['unknown_bits']}"
    return None


def _identity_key(identity: dict[str, Any]) -> tuple[Any, Any, Any]:
    return (
        identity.get("library_key"),
        identity.get("type_index"),
        identity.get("view"),
    )


def _exact_keys(
    value: Any, expected: set[str], location: str, errors: list[str]
) -> bool:
    if not isinstance(value, dict):
        errors.append(f"{location}: expected object")
        return False
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        errors.append(f"{location}: key mismatch (missing={missing}, extra={extra})")
        return False
    return True


def _validate_documentation(value: Any, location: str, errors: list[str]) -> None:
    _exact_keys(
        value,
        {"name", "doc", "help_context", "help_file", "help_file_token"},
        location,
        errors,
    )


def _validate_identity(
    identity: Any,
    lookup: dict[tuple[str, int, str], dict[str, Any]],
    location: str,
    errors: list[str],
) -> None:
    if not _exact_keys(
        identity,
        {
            "library_key",
            "type_index",
            "view",
            "name",
            "guid",
            "typekind",
            "typekind_name",
        },
        location,
        errors,
    ):
        return
    target = lookup.get(_identity_key(identity))
    if target is None:
        errors.append(f"{location}: stable identity does not resolve")
        return
    attributes = target.get("attributes", {})
    expected = {
        "name": target.get("documentation", {}).get("name"),
        "guid": attributes.get("guid"),
        "typekind": attributes.get("typekind"),
        "typekind_name": attributes.get("typekind_name"),
    }
    for field, expected_value in expected.items():
        if identity.get(field) != expected_value:
            errors.append(f"{location}: stale identity attribute {field}")


def _validate_tagged_value(value: Any, location: str, errors: list[str]) -> None:
    if not _exact_keys(value, {"kind", "value"}, location, errors):
        return
    kind = value.get("kind")
    payload = value.get("value")
    valid = (
        (kind == "null" and payload is None)
        or (kind == "boolean" and isinstance(payload, bool))
        or (kind == "integer" and isinstance(payload, int) and not isinstance(payload, bool))
        or (kind == "float" and isinstance(payload, float))
        or (kind == "string" and isinstance(payload, str))
        or kind not in {"null", "boolean", "integer", "float", "string"}
    )
    if not valid:
        errors.append(f"{location}: tagged value kind/payload mismatch")


def _validate_default(value: Any, location: str, errors: list[str]) -> None:
    if not isinstance(value, dict) or value.get("state") not in {
        "not_encoded",
        "encoded",
    }:
        errors.append(f"{location}: malformed default fact")
        return
    if value["state"] == "not_encoded":
        _exact_keys(value, {"state"}, location, errors)
    elif _exact_keys(value, {"state", "value"}, location, errors):
        _validate_tagged_value(value["value"], f"{location}.value", errors)


def _validate_element_raw(
    element: dict[str, Any], flag_field: str, location: str, errors: list[str]
) -> None:
    raw = element.get("raw")
    if not isinstance(raw, list) or len(raw) != 3:
        errors.append(f"{location}: raw ELEMDESC must have three slots")
        return
    if raw[0] != element.get("type", {}).get("raw"):
        errors.append(f"{location}: raw ELEMDESC type mismatch")
    if raw[1] != element.get(flag_field, {}).get("value"):
        errors.append(f"{location}: raw ELEMDESC flags mismatch")
    default = element.get("default")
    if isinstance(default, dict) and default.get("state") == "not_encoded" and raw[2] is not None:
        errors.append(f"{location}: unencoded default has a raw value")


def _validate_optional_adapter_metadata(
    value: Any, location: str, errors: list[str]
) -> None:
    if not _exact_keys(value, {"state", "value"}, location, errors):
        return
    if value.get("state") not in {
        "not_exposed_by_pywin32",
        "reported",
        "not_available_for_member",
    }:
        errors.append(f"{location}: unknown adapter metadata state")
    if value.get("state") != "reported" and value.get("value") is not None:
        errors.append(f"{location}: unavailable adapter metadata has a value")


def _validate_descriptor(
    node: Any,
    lookup: dict[tuple[str, int, str], dict[str, Any]],
    location: str,
    errors: list[str],
) -> None:
    if not isinstance(node, dict):
        errors.append(f"{location}: descriptor is not an object")
        return
    kind = node.get("kind")
    common = {"raw", "vt", "vt_name", "kind", "display"}
    expected_by_kind = {
        "scalar": common,
        "pointer": common | {"target"},
        "userdefined": common | {"raw_href", "target"},
        "c_array": common | {"element", "bounds"},
    }
    expected = expected_by_kind.get(kind)
    if expected is None:
        errors.append(f"{location}: unknown descriptor kind {kind!r}")
        return
    if kind == "scalar" and "uninterpreted_payload" in node:
        expected = expected | {"uninterpreted_payload"}
    _exact_keys(node, expected, location, errors)
    vt = node.get("vt")
    if node.get("vt_name") != VT_NAMES.get(vt, f"VT_UNKNOWN_{vt}"):
        errors.append(f"{location}: VT name mismatch")
    expected_kind = {26: "pointer", 28: "c_array", 29: "userdefined"}.get(
        vt, "scalar"
    )
    if kind != expected_kind:
        errors.append(f"{location}: descriptor kind does not match VT")
    raw = node.get("raw")
    if kind == "pointer":
        _validate_descriptor(node.get("target"), lookup, f"{location}.target", errors)
        target = node.get("target", {})
        if raw != [vt, target.get("raw")]:
            errors.append(f"{location}: pointer raw descriptor mismatch")
        if node.get("display") != f"{target.get('display')}*":
            errors.append(f"{location}: pointer display mismatch")
    elif kind == "userdefined":
        _validate_identity(node.get("target"), lookup, f"{location}.target", errors)
        if raw != [vt, node.get("raw_href")]:
            errors.append(f"{location}: userdefined raw descriptor mismatch")
        if node.get("display") != node.get("target", {}).get("name"):
            errors.append(f"{location}: userdefined display mismatch")
    elif kind == "c_array":
        _validate_descriptor(node.get("element"), lookup, f"{location}.element", errors)
        bounds = node.get("bounds")
        if not isinstance(bounds, list) or not bounds:
            errors.append(f"{location}: C-array bounds missing")
            bounds = []
        for index, bound in enumerate(bounds):
            if not _exact_keys(
                bound, {"element_count", "lower_bound"}, f"{location}.bounds[{index}]", errors
            ):
                continue
            if not isinstance(bound["element_count"], int) or bound["element_count"] <= 0:
                errors.append(f"{location}.bounds[{index}]: invalid element count")
            if not isinstance(bound["lower_bound"], int):
                errors.append(f"{location}.bounds[{index}]: invalid lower bound")
        expected_raw = [
            vt,
            [node.get("element", {}).get("raw")]
            + [[bound.get("element_count"), bound.get("lower_bound")] for bound in bounds],
        ]
        if raw != expected_raw:
            errors.append(f"{location}: C-array raw descriptor mismatch")
        if node.get("display") != f"{node.get('element', {}).get('display')}[]":
            errors.append(f"{location}: C-array display mismatch")
    else:
        raw_vt = raw[0] if isinstance(raw, list) and raw else raw
        if raw_vt != vt:
            errors.append(f"{location}: scalar raw descriptor mismatch")
        if isinstance(raw, list) and node.get("uninterpreted_payload") != raw[1:]:
            errors.append(f"{location}: scalar payload mismatch")
        if node.get("display") != DISPLAY_SCALARS.get(vt, node.get("vt_name")):
            errors.append(f"{location}: scalar display mismatch")


def _descriptor_references(
    node: Any,
    *,
    from_library: str,
    from_type_index: int,
    from_type_view: str,
    context: str,
) -> Iterable[dict[str, Any]]:
    if not isinstance(node, dict):
        return
    kind = node.get("kind")
    if kind == "userdefined":
        yield {
            "from_library_key": from_library,
            "from_type_index": from_type_index,
            "from_type_view": from_type_view,
            "context": context,
            "reference_kind": "typedesc",
            "raw_href": node.get("raw_href"),
            "target": node.get("target"),
        }
    elif kind == "pointer":
        yield from _descriptor_references(
            node.get("target"),
            from_library=from_library,
            from_type_index=from_type_index,
            from_type_view=from_type_view,
            context=f"{context}.target",
        )
    elif kind == "c_array":
        yield from _descriptor_references(
            node.get("element"),
            from_library=from_library,
            from_type_index=from_type_index,
            from_type_view=from_type_view,
            context=f"{context}.element",
        )


def validate_fact_pack(facts: dict[str, Any], *, require_sources: bool) -> list[str]:
    errors: list[str] = []
    _exact_keys(
        facts,
        {
            "schema",
            "schema_version",
            "generator",
            "root_library_key",
            "flag_definitions",
            "libraries",
            "type_references",
            "library_reference_edges",
            "summary",
            "canonical_sha256",
        },
        "root",
        errors,
    )
    if facts.get("schema") != FACT_SCHEMA or facts.get("schema_version") != 1:
        errors.append("unexpected fact schema/version")
        return errors
    libraries = facts.get("libraries")
    if not isinstance(libraries, list) or len(libraries) != 2:
        errors.append("libraries must contain exactly root FM20 and referenced stdole")
        return errors
    expected_flag_definitions = {
        category: [
            {"bit": bit, "name": name} for bit, name in sorted(table.items())
        ]
        for category, table in sorted(FLAG_TABLES.items())
    }
    if facts.get("flag_definitions") != expected_flag_definitions:
        errors.append("flag_definitions do not match the complete pinned OLE tables")
    generator = facts.get("generator", {})
    _exact_keys(
        generator,
        {
            "implementation",
            "source_files",
            "python_version",
            "pywin32_version",
            "process_bits",
            "platform",
        },
        "generator",
        errors,
    )
    if generator.get("implementation") != "pywin32 public ITypeLib/ITypeInfo metadata":
        errors.append("generator.implementation mismatch")
    expected_generator_paths = [
        "tools/fm20/export_typelib_facts.py",
        "tools/fm20/pinned_typelibs.v1.json",
        "tools/fm20/typelib_facts.py",
    ]
    actual_generator_paths = [
        source.get("path") for source in generator.get("source_files", [])
    ]
    if actual_generator_paths != expected_generator_paths:
        errors.append("generator.source_files paths/order mismatch")
    for index, source in enumerate(generator.get("source_files", [])):
        _exact_keys(source, {"path", "sha256"}, f"generator.source_files[{index}]", errors)
        sha = source.get("sha256")
        if (
            not isinstance(sha, str)
            or len(sha) != 64
            or sha.lower() != sha
            or any(character not in "0123456789abcdef" for character in sha)
        ):
            errors.append(f"generator.source_files[{index}]: invalid SHA-256")
    _exact_keys(
        facts.get("summary", {}),
        {
            "library_count",
            "external_library_count",
            "declared_type_info_count",
            "exported_type_view_count",
            "exported_primary_count",
            "dual_interface_count",
            "function_count",
            "variable_count",
            "implementation_edge_count",
            "parameter_count",
            "parameter_name_not_reported_count",
            "encoded_parameter_default_count",
            "type_reference_count",
        },
        "summary",
        errors,
    )
    keys = [library.get("key") for library in libraries]
    if len(keys) != len(set(keys)):
        errors.append("duplicate library key")
    if facts.get("root_library_key") not in keys:
        errors.append("root_library_key does not resolve")
    if [library.get("role") for library in libraries] != ["root", "referenced"]:
        errors.append("libraries must be ordered root FM20, referenced stdole")
    if facts.get("root_library_key") != libraries[0].get("key"):
        errors.append("root_library_key must identify the first library")
    try:
        lookup = _library_type_lookup(facts)
    except (KeyError, TypeError) as error:
        errors.append(f"malformed type identity: {error}")
        return errors
    total_records = sum(len(library.get("types", [])) for library in libraries)
    if len(lookup) != total_records:
        errors.append("duplicate stable type identity (library, index, view)")
    root = next(
        (library for library in libraries if library["key"] == facts["root_library_key"]),
        None,
    )
    if root is None:
        return errors
    attrs = root.get("attributes", {})
    if attrs.get("guid") != FM20_LIBID or (
        attrs.get("major_version"), attrs.get("minor_version")
    ) != (2, 0):
        errors.append("root FM20 identity/version mismatch")
    if root.get("declared_type_info_count") != 171:
        errors.append("FM20 declared_type_info_count must be 171")
    if root.get("exported_view_count") != 208 or root.get(
        "exported_primary_count"
    ) != 171:
        errors.append("FM20 exported primary/view counts must be 171/208")
    if root.get("primary_census") != EXPECTED_FM20_CENSUS:
        errors.append(f"FM20 primary census mismatch: {root.get('primary_census')!r}")
    root_primary = [item for item in root.get("types", []) if item.get("view") == "primary"]
    root_dual = [
        item for item in root.get("types", []) if item.get("view") == "dual_interface"
    ]
    if [item.get("index") for item in root_primary] != list(range(171)):
        errors.append("FM20 primary type indexes are not exactly 0..170")
    if len(root_dual) != 37:
        errors.append(f"FM20 must contain 37 dual companions, found {len(root_dual)}")
    root_primary_totals = (
        sum(len(item.get("functions", [])) for item in root_primary),
        sum(len(item.get("variables", [])) for item in root_primary),
        sum(len(item.get("implemented_types", [])) for item in root_primary),
    )
    if root_primary_totals != (1757, 199, 177):
        errors.append(f"FM20 primary descriptor totals mismatch: {root_primary_totals!r}")
    root_dual_totals = (
        sum(len(item.get("functions", [])) for item in root_dual),
        sum(len(item.get("variables", [])) for item in root_dual),
        sum(len(item.get("implemented_types", [])) for item in root_dual),
    )
    if root_dual_totals != (1067, 0, 37):
        errors.append(f"FM20 dual descriptor totals mismatch: {root_dual_totals!r}")
    for dual in root_dual:
        primary = lookup.get((root["key"], dual.get("index"), "primary"))
        if primary is None:
            errors.append(f"FM20 dual type[{dual.get('index')}] lacks its primary")
            continue
        if dual.get("attributes", {}).get("typekind_name") != "TKIND_INTERFACE":
            errors.append(f"FM20 dual type[{dual.get('index')}] is not TKIND_INTERFACE")
        for field in ("guid",):
            if dual.get("attributes", {}).get(field) != primary.get("attributes", {}).get(field):
                errors.append(f"FM20 dual type[{dual.get('index')}] {field} mismatch")
        if dual.get("documentation", {}).get("name") != primary.get("documentation", {}).get("name"):
            errors.append(f"FM20 dual type[{dual.get('index')}] name mismatch")
        companion = primary.get("dual_companion", {})
        _exact_keys(
            companion,
            {"raw_href", "target"},
            f"FM20 primary type[{dual.get('index')}].dual_companion",
            errors,
        )
        _validate_identity(
            companion.get("target"),
            lookup,
            f"FM20 primary type[{dual.get('index')}].dual_companion.target",
            errors,
        )
        if companion.get("raw_href") != -2 or _identity_key(
            companion.get("target", {})
        ) != (root["key"], dual.get("index"), "dual_interface"):
            errors.append(f"FM20 dual type[{dual.get('index')}] companion link mismatch")
        if _identity_key(dual.get("dual_primary", {})) != (
            root["key"],
            dual.get("index"),
            "primary",
        ):
            errors.append(f"FM20 dual type[{dual.get('index')}] primary link mismatch")
        _validate_identity(
            dual.get("dual_primary"),
            lookup,
            f"FM20 dual type[{dual.get('index')}].dual_primary",
            errors,
        )
    for library in libraries:
        library_location = f"library[{library.get('key')}]"
        _exact_keys(
            library,
            {
                "key",
                "role",
                "documentation",
                "attributes",
                "source",
                "declared_type_info_count",
                "exported_view_count",
                "exported_primary_count",
                "primary_census",
                "view_census",
                "types",
            },
            library_location,
            errors,
        )
        _validate_documentation(
            library.get("documentation"), f"{library_location}.documentation", errors
        )
        _exact_keys(
            library.get("attributes", {}),
            {
                "guid",
                "lcid",
                "syskind",
                "syskind_name",
                "major_version",
                "minor_version",
                "library_flags",
            },
            f"{library_location}.attributes",
            errors,
        )
        if library.get("attributes", {}).get("syskind_name") != SYSKIND_NAMES.get(
            library.get("attributes", {}).get("syskind"), "UNKNOWN_SYSKIND"
        ):
            errors.append(f"{library_location}: SYSKIND name mismatch")
        library_attrs = library.get("attributes", {})
        expected_library_key = library_key(
            (
                library_attrs.get("guid"),
                library_attrs.get("lcid"),
                library_attrs.get("syskind"),
                library_attrs.get("major_version"),
                library_attrs.get("minor_version"),
                library_attrs.get("library_flags", {}).get("value"),
            )
        )
        if library.get("key") != expected_library_key:
            errors.append(f"{library_location}: key does not match LIBATTR")
        _exact_keys(
            library.get("source", {}),
            {
                "path",
                "file_name",
                "size_bytes",
                "sha256",
                "file_version",
                "product_version",
            },
            f"{library_location}.source",
            errors,
        )
        types = library.get("types")
        if not isinstance(types, list):
            errors.append(f"{library.get('key')}: types missing")
            continue
        if library.get("exported_view_count") != len(types):
            errors.append(f"{library['key']}: exported_view_count mismatch")
        if library.get("exported_primary_count") != sum(
            item.get("view") == "primary" for item in types
        ):
            errors.append(f"{library['key']}: exported_primary_count mismatch")
        recomputed_primary_census = dict(
            sorted(
                Counter(
                    item.get("attributes", {}).get("typekind_name")
                    for item in types
                    if item.get("view") == "primary"
                ).items()
            )
        )
        if library.get("primary_census") != recomputed_primary_census:
            errors.append(f"{library['key']}: primary_census mismatch")
        recomputed_view_census = dict(
            sorted(
                Counter(
                    f"{item.get('view')}:{item.get('attributes', {}).get('typekind_name')}"
                    for item in types
                ).items()
            )
        )
        if library.get("view_census") != recomputed_view_census:
            errors.append(f"{library['key']}: view_census mismatch")
        expected_order = sorted(
            ((item.get("index"), TypeLibExporter.VIEW_ORDER.get(item.get("view"), 99)) for item in types)
        )
        actual_order = [
            (item.get("index"), TypeLibExporter.VIEW_ORDER.get(item.get("view"), 99))
            for item in types
        ]
        if actual_order != expected_order:
            errors.append(f"{library['key']}: type views are not canonically ordered")
        flag_error = _flag_error(
            library.get("attributes", {}).get("library_flags"),
            "library",
            f"{library['key']}",
        )
        if flag_error:
            errors.append(flag_error)
        if require_sources:
            source = library.get("source", {})
            path = Path(source.get("path", ""))
            if not path.is_file():
                errors.append(f"{library['key']}: source file missing: {path}")
            elif sha256_file(path) != source.get("sha256"):
                errors.append(f"{library['key']}: source hash mismatch")
        for item in types:
            location = f"{library['key']} type[{item.get('index')}:{item.get('view')}]"
            _exact_keys(
                item,
                {
                    "index",
                    "view",
                    "inclusion_reasons",
                    "documentation",
                    "attributes",
                    "alias_type",
                    "functions",
                    "variables",
                    "implemented_types",
                    "coclass_map",
                    "dual_companion",
                    "dual_primary",
                    "default_function_indices",
                    "new_enum_function_indices",
                },
                location,
                errors,
            )
            _validate_documentation(
                item.get("documentation"), f"{location}.documentation", errors
            )
            if not item.get("inclusion_reasons"):
                errors.append(f"{location}: inclusion reason missing")
            has_dual = (library["key"], item.get("index"), "dual_interface") in lookup
            if item.get("view") == "primary":
                if item.get("dual_primary") is not None:
                    errors.append(f"{location}: primary view has dual_primary")
                if has_dual != (item.get("dual_companion") is not None):
                    errors.append(f"{location}: dual companion presence mismatch")
            elif item.get("view") == "dual_interface":
                if item.get("dual_companion") is not None:
                    errors.append(f"{location}: dual view has dual_companion")
                if item.get("dual_primary") is None:
                    errors.append(f"{location}: dual view lacks dual_primary")
            type_attrs = item.get("attributes", {})
            _exact_keys(
                type_attrs,
                {
                    "guid",
                    "lcid",
                    "memid_constructor",
                    "memid_destructor",
                    "size_instance",
                    "typekind",
                    "typekind_name",
                    "function_count",
                    "variable_count",
                    "implementation_count",
                    "vtable_size",
                    "alignment",
                    "type_flags",
                    "major_version",
                    "minor_version",
                    "raw_alias",
                    "idl_description",
                },
                f"{location}.attributes",
                errors,
            )
            if type_attrs.get("typekind_name") != TYPEKIND_NAMES.get(
                type_attrs.get("typekind"), "UNKNOWN_TYPEKIND"
            ):
                errors.append(f"{location}: TYPEKIND name mismatch")
            _exact_keys(
                type_attrs.get("idl_description", {}),
                {"reserved", "flags"},
                f"{location}.attributes.idl_description",
                errors,
            )
            flag_error = _flag_error(type_attrs.get("type_flags"), "type", location)
            if flag_error:
                errors.append(flag_error)
            flag_error = _flag_error(
                type_attrs.get("idl_description", {}).get("flags"), "idl", location
            )
            if flag_error:
                errors.append(flag_error)
            if type_attrs.get("function_count") != len(item.get("functions", [])):
                errors.append(f"{location}: function truncation")
            if type_attrs.get("variable_count") != len(item.get("variables", [])):
                errors.append(f"{location}: variable truncation")
            if type_attrs.get("implementation_count") != len(
                item.get("implemented_types", [])
            ):
                errors.append(f"{location}: implementation truncation")
            if [row.get("index") for row in item.get("functions", [])] != list(
                range(len(item.get("functions", [])))
            ):
                errors.append(f"{location}: function ordinals are not contiguous")
            if [row.get("index") for row in item.get("variables", [])] != list(
                range(len(item.get("variables", [])))
            ):
                errors.append(f"{location}: variable ordinals are not contiguous")
            if [row.get("index") for row in item.get("implemented_types", [])] != list(
                range(len(item.get("implemented_types", [])))
            ):
                errors.append(f"{location}: implementation ordinals are not contiguous")
            if type_attrs.get("typekind_name") == "TKIND_ALIAS" and not item.get(
                "alias_type"
            ):
                errors.append(f"{location}: alias missing")
            if item.get("alias_type") is not None:
                _validate_descriptor(
                    item["alias_type"], lookup, f"{location}.alias_type", errors
                )
                if type_attrs.get("raw_alias") != item["alias_type"].get("raw"):
                    errors.append(f"{location}: TYPEATTR raw alias mismatch")
            elif type_attrs.get("raw_alias") is not None:
                errors.append(f"{location}: raw alias exists without resolved alias")
            if type_attrs.get("typekind_name") == "TKIND_ENUM":
                names = [
                    variable.get("documentation", {}).get("name")
                    for variable in item.get("variables", [])
                ]
                if not names or len(names) != len(set(names)):
                    errors.append(
                        f"{location}: enum constants invalid"
                    )
                if any(
                    variable.get("variable_kind_name") != "VAR_CONST"
                    or variable.get("union_value", {}).get("kind")
                    != "constant_value"
                    or variable.get("union_value", {}).get("value", {}).get("kind")
                    != "integer"
                    for variable in item.get("variables", [])
                ):
                    errors.append(f"{location}: enum storage/value encoding invalid")
            expected_coclass_map = None
            if type_attrs.get("typekind_name") == "TKIND_COCLASS":
                implemented = item.get("implemented_types", [])
                expected_coclass_map = {
                    "ordinary_default_indices": [
                        row.get("index")
                        for row in implemented
                        if "default" in row.get("roles", [])
                        and "source" not in row.get("roles", [])
                    ],
                    "source_default_indices": [
                        row.get("index")
                        for row in implemented
                        if "default" in row.get("roles", [])
                        and "source" in row.get("roles", [])
                    ],
                    "source_indices": [
                        row.get("index")
                        for row in implemented
                        if "source" in row.get("roles", [])
                    ],
                    "restricted_indices": [
                        row.get("index")
                        for row in implemented
                        if "restricted" in row.get("roles", [])
                    ],
                }
            if item.get("coclass_map") != expected_coclass_map:
                errors.append(f"{location}: coclass map mismatch")
            descriptors: list[dict[str, Any]] = []
            if item.get("alias_type"):
                descriptors.extend(_walk_descriptors(item["alias_type"]))
            for function in item.get("functions", []):
                function_location = f"{location} function[{function.get('index')}]"
                _exact_keys(
                    function,
                    {
                        "index",
                        "memid",
                        "names",
                        "documentation",
                        "scode_array",
                        "function_kind",
                        "function_kind_name",
                        "invoke_kind",
                        "invoke_kind_name",
                        "call_convention",
                        "call_convention_name",
                        "parameter_count",
                        "optional_parameter_count",
                        "vtable_offset",
                        "return",
                        "function_flags",
                        "parameters",
                        "dll_entry",
                        "mops",
                        "is_default_member",
                        "is_new_enum",
                    },
                    function_location,
                    errors,
                )
                _validate_documentation(
                    function.get("documentation"),
                    f"{function_location}.documentation",
                    errors,
                )
                _validate_optional_adapter_metadata(
                    function.get("dll_entry"),
                    f"{function_location}.dll_entry",
                    errors,
                )
                _validate_optional_adapter_metadata(
                    function.get("mops"),
                    f"{function_location}.mops",
                    errors,
                )
                for numeric_field, name_field, table in (
                    ("function_kind", "function_kind_name", FUNCKIND_NAMES),
                    ("invoke_kind", "invoke_kind_name", INVOKEKIND_NAMES),
                    ("call_convention", "call_convention_name", CALLCONV_NAMES),
                ):
                    if function.get(name_field) != table.get(
                        function.get(numeric_field), f"UNKNOWN_{name_field.upper()}"
                    ):
                        # The generator uses stable explicit UNKNOWN_* spellings.
                        expected_name = {
                            "function_kind": "UNKNOWN_FUNCKIND",
                            "invoke_kind": "UNKNOWN_INVOKEKIND",
                            "call_convention": "UNKNOWN_CALLCONV",
                        }[numeric_field]
                        if function.get(name_field) != table.get(
                            function.get(numeric_field), expected_name
                        ):
                            errors.append(
                                f"{function_location}: {numeric_field} name mismatch"
                            )
                _exact_keys(
                    function.get("return", {}),
                    {"raw", "type", "parameter_flags", "default"},
                    f"{function_location}.return",
                    errors,
                )
                _validate_descriptor(
                    function.get("return", {}).get("type"),
                    lookup,
                    f"{function_location}.return.type",
                    errors,
                )
                _validate_element_raw(
                    function.get("return", {}),
                    "parameter_flags",
                    f"{function_location}.return",
                    errors,
                )
                if function.get("parameter_count") != len(
                    function.get("parameters", [])
                ):
                    errors.append(f"{function_location}: parameter truncation")
                optional_count = sum(
                    bool(parameter.get("parameter_flags", {}).get("value", 0) & 0x0010)
                    for parameter in function.get("parameters", [])
                )
                if function.get("optional_parameter_count") != optional_count:
                    errors.append(f"{function_location}: optional-parameter count mismatch")
                if not function.get("names") or function.get("names", [None])[0] != function.get(
                    "documentation", {}
                ).get("name"):
                    errors.append(f"{function_location}: GetNames/member-name mismatch")
                if [row.get("index") for row in function.get("parameters", [])] != list(
                    range(len(function.get("parameters", [])))
                ):
                    errors.append(f"{function_location}: parameter ordinals are not contiguous")
                if function.get("is_default_member") != (
                    function.get("memid") == 0
                    or "FUNCFLAG_FDEFAULTBIND"
                    in function.get("function_flags", {}).get("names", [])
                ):
                    errors.append(f"{function_location}: default-member marker mismatch")
                if function.get("is_new_enum") != (function.get("memid") == -4):
                    errors.append(f"{function_location}: new-enum marker mismatch")
                flag_error = _flag_error(
                    function.get("function_flags"), "function", function_location
                )
                if flag_error:
                    errors.append(flag_error)
                flag_error = _flag_error(
                    function.get("return", {}).get("parameter_flags"),
                    "parameter",
                    f"{function_location} return",
                )
                if flag_error:
                    errors.append(flag_error)
                return_default = function.get("return", {}).get("default", {})
                _validate_default(
                    return_default, f"{function_location}.return.default", errors
                )
                return_flags = function.get("return", {}).get(
                    "parameter_flags", {}
                ).get("value", 0)
                if return_default.get("state") != (
                    "encoded" if return_flags & 0x0020 else "not_encoded"
                ):
                    errors.append(f"{function_location} return: default state mismatch")
                descriptors.extend(
                    _walk_descriptors(function.get("return", {}).get("type", {}))
                )
                for parameter in function.get("parameters", []):
                    parameter_location = (
                        f"{function_location} parameter[{parameter.get('index')}]"
                    )
                    _exact_keys(
                        parameter,
                        {
                            "index",
                            "name",
                            "name_state",
                            "raw",
                            "type",
                            "parameter_flags",
                            "default",
                        },
                        parameter_location,
                        errors,
                    )
                    _validate_descriptor(
                        parameter.get("type"),
                        lookup,
                        f"{parameter_location}.type",
                        errors,
                    )
                    _validate_element_raw(
                        parameter,
                        "parameter_flags",
                        parameter_location,
                        errors,
                    )
                    flag_error = _flag_error(
                        parameter.get("parameter_flags"),
                        "parameter",
                        f"{function_location} parameter[{parameter.get('index')}]",
                    )
                    if flag_error:
                        errors.append(flag_error)
                    name_present = parameter.get("name") is not None
                    if parameter.get("name_state") != (
                        "reported_by_GetNames"
                        if name_present
                        else "not_reported_by_GetNames"
                    ):
                        errors.append(
                            f"{function_location} parameter[{parameter.get('index')}]: name state mismatch"
                        )
                    parameter_default = parameter.get("default", {})
                    _validate_default(
                        parameter_default, f"{parameter_location}.default", errors
                    )
                    parameter_flag_value = parameter.get("parameter_flags", {}).get(
                        "value", 0
                    )
                    if parameter_default.get("state") != (
                        "encoded"
                        if parameter_flag_value & 0x0020
                        else "not_encoded"
                    ):
                        errors.append(
                            f"{function_location} parameter[{parameter.get('index')}]: default state mismatch"
                        )
                    descriptors.extend(_walk_descriptors(parameter.get("type", {})))
            expected_default_indices = [
                function.get("index")
                for function in item.get("functions", [])
                if function.get("is_default_member")
            ]
            if item.get("default_function_indices") != expected_default_indices:
                errors.append(f"{location}: default function index map mismatch")
            expected_new_enum_indices = [
                function.get("index")
                for function in item.get("functions", [])
                if function.get("is_new_enum")
            ]
            if item.get("new_enum_function_indices") != expected_new_enum_indices:
                errors.append(f"{location}: new-enum function index map mismatch")
            for variable in item.get("variables", []):
                variable_location = f"{location} variable[{variable.get('index')}]"
                _exact_keys(
                    variable,
                    {
                        "index",
                        "memid",
                        "names",
                        "documentation",
                        "union_value",
                        "element",
                        "variable_flags",
                        "variable_kind",
                        "variable_kind_name",
                    },
                    variable_location,
                    errors,
                )
                _validate_documentation(
                    variable.get("documentation"),
                    f"{variable_location}.documentation",
                    errors,
                )
                if variable.get("variable_kind_name") != VARKIND_NAMES.get(
                    variable.get("variable_kind"), "UNKNOWN_VARKIND"
                ):
                    errors.append(f"{variable_location}: VARKIND name mismatch")
                _exact_keys(
                    variable.get("union_value", {}),
                    {"kind", "value"},
                    f"{variable_location}.union_value",
                    errors,
                )
                _validate_tagged_value(
                    variable.get("union_value", {}).get("value"),
                    f"{variable_location}.union_value.value",
                    errors,
                )
                _exact_keys(
                    variable.get("element", {}),
                    {"raw", "type", "idl_flags", "default"},
                    f"{variable_location}.element",
                    errors,
                )
                _validate_descriptor(
                    variable.get("element", {}).get("type"),
                    lookup,
                    f"{variable_location}.element.type",
                    errors,
                )
                _validate_element_raw(
                    variable.get("element", {}),
                    "idl_flags",
                    f"{variable_location}.element",
                    errors,
                )
                flag_error = _flag_error(
                    variable.get("variable_flags"),
                    "variable",
                    f"{location} variable[{variable.get('index')}]",
                )
                if flag_error:
                    errors.append(flag_error)
                flag_error = _flag_error(
                    variable.get("element", {}).get("idl_flags"),
                    "idl",
                    f"{location} variable[{variable.get('index')}]",
                )
                if flag_error:
                    errors.append(flag_error)
                expected_union_kind = {
                    0: "instance_offset",
                    1: "static_value_not_exposed",
                    2: "constant_value",
                    3: "dispatch_member_no_value",
                }.get(variable.get("variable_kind"), "unknown")
                if variable.get("union_value", {}).get("kind") != expected_union_kind:
                    errors.append(
                        f"{location} variable[{variable.get('index')}]: VARDESC union kind mismatch"
                    )
                descriptors.extend(
                    _walk_descriptors(variable.get("element", {}).get("type", {}))
                )
            for descriptor in descriptors:
                if descriptor.get("kind") == "userdefined":
                    target = descriptor.get("target", {})
                    if _identity_key(target) not in lookup:
                        errors.append(
                            f"{location}: unresolved userdefined target"
                        )
            for impl in item.get("implemented_types", []):
                implementation_location = (
                    f"{location} implementation[{impl.get('index')}]"
                )
                _exact_keys(
                    impl,
                    {
                        "index",
                        "raw_href",
                        "implementation_flags",
                        "roles",
                        "target",
                    },
                    implementation_location,
                    errors,
                )
                _validate_identity(
                    impl.get("target"),
                    lookup,
                    f"{implementation_location}.target",
                    errors,
                )
                flag_error = _flag_error(
                    impl.get("implementation_flags"),
                    "implementation",
                    f"{location} implementation[{impl.get('index')}]",
                )
                if flag_error:
                    errors.append(flag_error)
                expected_roles = [
                    role
                    for bit, role in (
                        (0x0001, "default"),
                        (0x0002, "source"),
                        (0x0004, "restricted"),
                        (0x0008, "default_vtable"),
                    )
                    if impl.get("implementation_flags", {}).get("value", 0) & bit
                ]
                if impl.get("roles") != expected_roles:
                    errors.append(
                        f"{location} implementation[{impl.get('index')}]: role decoding mismatch"
                    )
                target = impl.get("target", {})
                if _identity_key(target) not in lookup:
                    errors.append(f"{location}: unresolved implementation target")
    stdole = next(
        (
            library
            for library in libraries
            if library.get("attributes", {}).get("guid") == STDOLE_LIBID
        ),
        None,
    )
    if stdole is None:
        errors.append("stdole referenced library is missing")
    else:
        if stdole.get("declared_type_info_count") != 42:
            errors.append("stdole declared_type_info_count must be 42")
        if stdole.get("exported_view_count") != 12 or stdole.get(
            "exported_primary_count"
        ) != 12:
            errors.append("stdole exported primary/view counts must be 12/12")
        stdole_indices = [item.get("index") for item in stdole["types"]]
        if stdole_indices != EXPECTED_STDOLE_INDICES:
            errors.append(f"stdole closure indexes mismatch: {stdole_indices!r}")
        stdole_names = {item["documentation"]["name"] for item in stdole["types"]}
        for required in {"IPictureDisp", "Picture"}:
            if required not in stdole_names:
                errors.append(f"stdole type {required} is missing")
        alias = next(
            (item for item in stdole["types"] if item["documentation"]["name"] == "IPictureDisp"),
            None,
        )
        if alias is None or alias.get("inclusion_reasons") != [
            "public_alias_of_reached_type"
        ]:
            errors.append("stdole IPictureDisp reverse-alias inclusion is not explicit")
        elif _identity_key(alias.get("alias_type", {}).get("target", {})) != (
            stdole["key"],
            35,
            "primary",
        ):
            errors.append("stdole IPictureDisp does not alias stdole.Picture index 35")
        stdole_totals = (
            sum(len(item.get("functions", [])) for item in stdole["types"]),
            sum(len(item.get("variables", [])) for item in stdole["types"]),
            sum(len(item.get("implemented_types", [])) for item in stdole["types"]),
        )
        if stdole_totals != (8, 22, 2):
            errors.append(f"stdole closure descriptor totals mismatch: {stdole_totals!r}")
    picture_refs = [
        row
        for row in facts.get("type_references", [])
        if row.get("from_library_key") == facts.get("root_library_key")
        and row.get("target", {}).get("library_key")
        == (stdole.get("key") if stdole else None)
        and row.get("target", {}).get("name") == "Picture"
    ]
    if not picture_refs:
        errors.append("FM20 has no resolved reference to stdole.Picture/IPictureDisp")
    canonical = {
        "root_library_key": facts.get("root_library_key"),
        "flag_definitions": facts.get("flag_definitions"),
        "libraries": facts.get("libraries"),
        "type_references": facts.get("type_references"),
        "library_reference_edges": facts.get("library_reference_edges"),
    }
    if facts.get("canonical_sha256") != sha256_bytes(
        structural_json_bytes(canonical)
    ):
        errors.append("canonical_sha256 mismatch")
    summary = facts.get("summary", {})
    if summary.get("library_count") != len(libraries):
        errors.append("summary.library_count mismatch")
    if summary.get("external_library_count") != len(libraries) - 1:
        errors.append("summary.external_library_count mismatch")
    if summary.get("declared_type_info_count") != sum(
        library.get("declared_type_info_count", 0) for library in libraries
    ):
        errors.append("summary.declared_type_info_count mismatch")
    if summary.get("exported_type_view_count") != total_records:
        errors.append("summary.exported_type_view_count mismatch")
    if summary.get("type_reference_count") != len(
        facts.get("type_references", [])
    ):
        errors.append("summary.type_reference_count mismatch")
    totals = {
        "views": total_records,
        "functions": sum(
            len(item.get("functions", []))
            for library in libraries
            for item in library.get("types", [])
        ),
        "variables": sum(
            len(item.get("variables", []))
            for library in libraries
            for item in library.get("types", [])
        ),
        "implementation_edges": sum(
            len(item.get("implemented_types", []))
            for library in libraries
            for item in library.get("types", [])
        ),
    }
    if totals != EXPECTED_EXPORT_TOTALS:
        errors.append(f"exported descriptor totals mismatch: {totals!r}")
    all_types = [item for library in libraries for item in library.get("types", [])]
    all_functions = [
        function for item in all_types for function in item.get("functions", [])
    ]
    all_parameters = [
        parameter
        for function in all_functions
        for parameter in function.get("parameters", [])
    ]
    recomputed_summary_fields = {
        "exported_primary_count": sum(
            item.get("view") == "primary" for item in all_types
        ),
        "dual_interface_count": sum(
            item.get("view") == "dual_interface" for item in all_types
        ),
        "function_count": totals["functions"],
        "variable_count": totals["variables"],
        "implementation_edge_count": totals["implementation_edges"],
        "parameter_count": len(all_parameters),
        "parameter_name_not_reported_count": sum(
            parameter.get("name_state") == "not_reported_by_GetNames"
            for parameter in all_parameters
        ),
        "encoded_parameter_default_count": sum(
            parameter.get("default", {}).get("state") == "encoded"
            for parameter in all_parameters
        ),
    }
    for field, expected in recomputed_summary_fields.items():
        if summary.get(field) != expected:
            errors.append(f"summary.{field} mismatch")

    expected_reference_rows: list[dict[str, Any]] = []
    for library in libraries:
        for item in library.get("types", []):
            source = {
                "from_library": library["key"],
                "from_type_index": item["index"],
                "from_type_view": item["view"],
            }
            base = f"type[{item['index']}:{item['view']}]"
            if item.get("alias_type") is not None:
                expected_reference_rows.extend(
                    _descriptor_references(
                        item["alias_type"], context=f"{base}.alias", **source
                    )
                )
            for function in item.get("functions", []):
                function_base = f"{base}.function[{function['index']}]"
                expected_reference_rows.extend(
                    _descriptor_references(
                        function.get("return", {}).get("type"),
                        context=f"{function_base}.return.type",
                        **source,
                    )
                )
                for parameter in function.get("parameters", []):
                    expected_reference_rows.extend(
                        _descriptor_references(
                            parameter.get("type"),
                            context=f"{function_base}.parameter[{parameter['index']}].type",
                            **source,
                        )
                    )
            for variable in item.get("variables", []):
                expected_reference_rows.extend(
                    _descriptor_references(
                        variable.get("element", {}).get("type"),
                        context=f"{base}.variable[{variable['index']}].type",
                        **source,
                    )
                )
            for implementation in item.get("implemented_types", []):
                expected_reference_rows.append(
                    {
                        "from_library_key": library["key"],
                        "from_type_index": item["index"],
                        "from_type_view": item["view"],
                        "context": f"{base}.implementation[{implementation['index']}]",
                        "reference_kind": "implementation",
                        "raw_href": implementation.get("raw_href"),
                        "target": implementation.get("target"),
                    }
                )

    reference_rows = facts.get("type_references", [])
    for index, reference in enumerate(reference_rows):
        _exact_keys(
            reference,
            {
                "from_library_key",
                "from_type_index",
                "from_type_view",
                "context",
                "reference_kind",
                "raw_href",
                "target",
            },
            f"type_references[{index}]",
            errors,
        )
        source_key = (
            reference.get("from_library_key"),
            reference.get("from_type_index"),
            reference.get("from_type_view"),
        )
        if source_key not in lookup:
            errors.append(f"type_references[{index}]: unresolved source")
        if _identity_key(reference.get("target", {})) not in lookup:
            errors.append(f"type_references[{index}]: unresolved target")
        _validate_identity(
            reference.get("target"),
            lookup,
            f"type_references[{index}].target",
            errors,
        )
    expected_reference_multiset = Counter(
        structural_json_bytes(row) for row in expected_reference_rows
    )
    actual_reference_multiset = Counter(
        structural_json_bytes(row) for row in reference_rows
    )
    if actual_reference_multiset != expected_reference_multiset:
        missing_count = sum((expected_reference_multiset - actual_reference_multiset).values())
        extra_count = sum((actual_reference_multiset - expected_reference_multiset).values())
        errors.append(
            "type_references do not exactly mirror descriptor/implementation rows "
            f"(missing={missing_count}, extra={extra_count})"
        )
    expected_reasons: dict[tuple[str, int, str], set[str]] = {}
    for identity, item in lookup.items():
        if identity[0] == facts.get("root_library_key"):
            expected_reasons[identity] = {
                "root_dual_companion"
                if identity[2] == "dual_interface"
                else "root_primary"
            }
        else:
            expected_reasons[identity] = set()
    for reference in expected_reference_rows:
        target_key = _identity_key(reference.get("target", {}))
        if target_key[0] == facts.get("root_library_key"):
            continue
        expected_reasons.setdefault(target_key, set()).add(
            "direct_reference"
            if reference.get("from_library_key") == facts.get("root_library_key")
            else "transitive_reference"
        )
    if stdole is not None:
        expected_reasons[(stdole["key"], 36, "primary")].add(
            "public_alias_of_reached_type"
        )
    for identity, item in lookup.items():
        expected = sorted(
            expected_reasons.get(identity, set()),
            key=lambda reason: TypeLibExporter.REASON_ORDER[reason],
        )
        if item.get("inclusion_reasons") != expected:
            errors.append(
                f"{identity}: inclusion reasons mismatch "
                f"({item.get('inclusion_reasons')!r} != {expected!r})"
            )
    edge_counts: Counter[tuple[str, str]] = Counter(
        (row.get("from_library_key"), row.get("target", {}).get("library_key"))
        for row in reference_rows
        if row.get("from_library_key")
        != row.get("target", {}).get("library_key")
    )
    recomputed_edges = [
        {
            "from_library_key": source,
            "to_library_key": target,
            "reference_count": count,
        }
        for (source, target), count in sorted(edge_counts.items())
    ]
    for index, edge in enumerate(facts.get("library_reference_edges", [])):
        _exact_keys(
            edge,
            {"from_library_key", "to_library_key", "reference_count"},
            f"library_reference_edges[{index}]",
            errors,
        )
    if facts.get("library_reference_edges") != recomputed_edges:
        errors.append("library_reference_edges mismatch")
    return errors


def _stable_descriptor_from_new(node: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {"kind": node["kind"], "vt": node["vt"]}
    if node["kind"] == "pointer":
        result["target"] = _stable_descriptor_from_new(node["target"])
    elif node["kind"] == "userdefined":
        target = node["target"]
        result["target"] = {
            "name": target["name"],
            "guid": target["guid"],
            "typekind": target["typekind"],
        }
    elif node["kind"] == "c_array":
        result["element"] = _stable_descriptor_from_new(node["element"])
        result["bounds"] = node["bounds"]
    return result


def _stable_descriptor_from_w005(node: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {"kind": node["kind"], "vt": node["vt"]}
    if node["kind"] == "pointer":
        result["target"] = _stable_descriptor_from_w005(node["to"])
    elif node["kind"] == "userdefined":
        result["target"] = {
            "name": node["name"],
            "guid": node["guid"].upper(),
            "typekind": node["typekind"],
        }
    return result


def _new_signature(function: dict[str, Any]) -> dict[str, Any]:
    return {
        "names": function["names"],
        "function_kind": function["function_kind"],
        "invoke_kind": function["invoke_kind"],
        "call_convention": function["call_convention"],
        "function_flags": function["function_flags"]["value"],
        "return_type": _stable_descriptor_from_new(function["return"]["type"]),
        "parameters": [
            {
                "name": parameter["name"],
                "type": _stable_descriptor_from_new(parameter["type"]),
                "parameter_flags": parameter["parameter_flags"]["value"],
                "default": parameter["default"],
            }
            for parameter in function["parameters"]
        ],
    }


def _w005_signature(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "names": row["names"],
        "function_kind": row["funckind"],
        "invoke_kind": row["invkind"],
        "call_convention": row["callconv"],
        "function_flags": row["wFuncFlags"],
        "return_type": _stable_descriptor_from_w005(row["return_type"]),
        "parameters": [
            {
                "name": argument["name"],
                "type": _stable_descriptor_from_w005(argument["resolved_type"]),
                "parameter_flags": argument["param_flags"],
                "default": default_fact(argument["default"], argument["param_flags"]),
            }
            for argument in row["args"]
        ],
    }


def _row_key(row: dict[str, Any]) -> tuple[Any, ...]:
    return (
        row["coclass"],
        row["source_interface"],
        row["source_interface_guid"].upper(),
        row["dispid"],
        row["invkind"],
        row["event_name"],
    )


def _key_object(key: tuple[Any, ...]) -> dict[str, Any]:
    return {
        "coclass": key[0],
        "source_interface": key[1],
        "source_interface_guid": key[2],
        "dispid": key[3],
        "invoke_kind": key[4],
        "event_name": key[5],
    }


def project_w005_events(
    facts: dict[str, Any], included_events: set[str]
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], set[str]]:
    root = next(
        library
        for library in facts["libraries"]
        if library["key"] == facts["root_library_key"]
    )
    lookup = _library_type_lookup(facts)
    attachments: list[dict[str, Any]] = []
    rows: list[dict[str, Any]] = []
    all_source_event_names: set[str] = set()
    for coclass in root["types"]:
        if coclass["attributes"]["typekind_name"] != "TKIND_COCLASS":
            continue
        for impl in coclass["implemented_types"]:
            if not (impl["implementation_flags"]["value"] & 0x0002):
                continue
            target_identity = impl["target"]
            target = lookup[(
                target_identity["library_key"],
                target_identity["type_index"],
                target_identity["view"],
            )]
            attachment = {
                "coclass": coclass["documentation"]["name"],
                "source_interface": target["documentation"]["name"],
                "source_interface_guid": target["attributes"]["guid"],
                "implementation_flags": impl["implementation_flags"]["value"],
                "implementation_index": impl["index"],
            }
            attachments.append(attachment)
            for function in target["functions"]:
                event_name = function["documentation"]["name"]
                all_source_event_names.add(event_name)
                if event_name not in included_events:
                    continue
                rows.append(
                    {
                        **attachment,
                        "event_name": event_name,
                        "dispid": function["memid"],
                        "invkind": function["invoke_kind"],
                        "signature": _new_signature(function),
                    }
                )
    attachments.sort(
        key=lambda row: (
            row["coclass"],
            row["source_interface_guid"],
            row["implementation_flags"],
        )
    )
    rows.sort(key=_row_key)
    return attachments, rows, all_source_event_names


def build_w005_comparison(
    facts: dict[str, Any],
    w005: dict[str, Any],
    *,
    w005_path: Path,
    w005_pin: dict[str, Any],
    w005_pin_path: Path,
) -> dict[str, Any]:
    resolved_w005_path = w005_path.resolve(strict=True)
    repo_root = Path(__file__).resolve().parents[2]
    try:
        displayed_w005_path = resolved_w005_path.relative_to(repo_root).as_posix()
    except ValueError:
        displayed_w005_path = resolved_w005_path.as_posix()
    resolved_pin_path = w005_pin_path.resolve(strict=True)
    try:
        displayed_pin_path = resolved_pin_path.relative_to(repo_root).as_posix()
    except ValueError:
        displayed_pin_path = resolved_pin_path.as_posix()
    included_events = set(w005["scope"]["included_events"])
    attachments, current_rows, all_source_names = project_w005_events(
        facts, included_events
    )
    old_rows = [
        {
            "coclass": row["coclass"],
            "source_interface": row["source_interface"],
            "source_interface_guid": row["source_interface_guid"].upper(),
            "event_name": row["event_name"],
            "dispid": row["dispid"],
            "invkind": row["invkind"],
            "signature": _w005_signature(row),
        }
        for row in w005["rows"]
    ]
    old_rows.sort(key=_row_key)
    old_by_key = {_row_key(row): row for row in old_rows}
    new_by_key = {_row_key(row): row for row in current_rows}
    if len(old_by_key) != len(old_rows) or len(new_by_key) != len(current_rows):
        raise FactError("W005 comparison contains duplicate stable row keys")
    row_results = []
    structural_deltas = []
    for key in sorted(set(old_by_key) | set(new_by_key)):
        old = old_by_key.get(key)
        current = new_by_key.get(key)
        if old is None:
            status = "current_added"
        elif current is None:
            status = "current_removed"
        elif old["signature"] != current["signature"]:
            status = "signature_changed"
        else:
            status = "exact_match"
        result = {
            "key": _key_object(key),
            "status": status,
            "w005_signature_sha256": sha256_bytes(
                structural_json_bytes(old["signature"])
            )
            if old
            else None,
            "current_signature_sha256": sha256_bytes(
                structural_json_bytes(current["signature"])
            )
            if current
            else None,
        }
        row_results.append(result)
        if status != "exact_match":
            structural_deltas.append(result)

    old_attachment_keys = {
        (
            row["coclass"],
            row["source_interface"],
            row["source_interface_guid"].upper(),
            row["impl_flags"],
        )
        for row in w005["source_interfaces"]
    }
    new_attachment_keys = {
        (
            row["coclass"],
            row["source_interface"],
            row["source_interface_guid"].upper(),
            row["implementation_flags"],
        )
        for row in attachments
    }
    attachment_deltas = [
        {
            "coclass": key[0],
            "source_interface": key[1],
            "source_interface_guid": key[2],
            "implementation_flags": key[3],
            "status": "current_added"
            if key not in old_attachment_keys
            else "current_removed",
        }
        for key in sorted(old_attachment_keys ^ new_attachment_keys)
    ]
    old_hash = w005["source"]["sha256"].lower()
    root = next(
        library
        for library in facts["libraries"]
        if library["key"] == facts["root_library_key"]
    )
    current_hash = root["source"]["sha256"]
    unexplained = attachment_deltas + structural_deltas
    if unexplained:
        classification = "unexplained_structural_deltas"
    elif old_hash == current_hash:
        classification = "exact_match"
    else:
        classification = "source_binary_changed_structure_same"
    lifecycle_checked = set(
        w005["scope"]["lifecycle_events_checked_by_name"]
    )
    old_counts = {
        "attachments": len(w005["source_interfaces"]),
        "arguments": sum(len(row["args"]) for row in w005["rows"]),
        "event_names": len(set(row["event_name"] for row in w005["rows"])),
        "rows": len(w005["rows"]),
        "source_interfaces": len(
            set(row["source_interface_guid"].upper() for row in w005["source_interfaces"])
        ),
    }
    current_counts = {
        "attachments": len(attachments),
        "arguments": sum(
            len(row["signature"]["parameters"]) for row in current_rows
        ),
        "event_names": len(set(row["event_name"] for row in current_rows)),
        "rows": len(current_rows),
        "source_interfaces": len(
            set(row["source_interface_guid"] for row in attachments)
        ),
    }
    return {
        "schema": COMPARISON_SCHEMA,
        "schema_version": 1,
        "classification": classification,
        "comparison_rules": {
            "stable_attachment_key": [
                "coclass name",
                "source-interface name",
                "source-interface GUID",
                "implementation flags",
            ],
            "stable_row_key": [
                "coclass name",
                "source-interface name",
                "source-interface GUID",
                "DISPID",
                "invoke kind",
                "event name",
            ],
            "signature_fields": [
                "names",
                "function kind",
                "invoke kind",
                "call convention",
                "function flags",
                "resolved return type",
                "ordered parameter names/types/flags/defaults",
            ],
            "ignored_capture_local_fields": [
                "HREFTYPE integers",
                "implementation indexes",
                "raw tuple string formatting",
                "generated timestamps",
                "absolute help-file path casing",
            ],
        },
        "w005_artifact": {
            "path": displayed_w005_path,
            "sha256": sha256_file(resolved_w005_path),
            "schema": w005["schema"],
            "recorded_fm20_sha256": old_hash,
        },
        "w005_baseline_pin": {
            "path": displayed_pin_path,
            "sha256": sha256_file(resolved_pin_path),
            "schema": w005_pin["schema"],
        },
        "current_fact_pack": {
            "schema": facts["schema"],
            "canonical_sha256": facts["canonical_sha256"],
            "fm20_sha256": current_hash,
        },
        "source_binary_delta": {
            "changed": old_hash != current_hash,
            "explanation": "The installed public FM20 binary changed after W005; stable public type-library structure is compared independently of the file hash."
            if old_hash != current_hash
            else "The W005 and current fact packs use the same FM20 binary hash.",
        },
        "counts": {"w005": old_counts, "current_projection": current_counts},
        "included_event_names": sorted(included_events),
        "lifecycle_name_check": {
            "checked": sorted(lifecycle_checked),
            "found_in_current_fm20_source_interfaces": sorted(
                lifecycle_checked & all_source_names
            ),
            "not_found_in_current_fm20_source_interfaces": sorted(
                lifecycle_checked - all_source_names
            ),
            "interpretation": "Absence from FM20 source interfaces does not exclude the public UserForm host lifecycle overlay.",
        },
        "attachment_deltas": attachment_deltas,
        "row_results": row_results,
        "structural_delta_count": len(unexplained),
        "unexplained_structural_deltas": unexplained,
    }


def validate_w005_comparison(
    comparison: dict[str, Any],
    facts: dict[str, Any],
    w005: dict[str, Any],
    *,
    w005_pin: dict[str, Any],
    w005_pin_path: Path,
) -> list[str]:
    errors: list[str] = []
    if comparison.get("schema") != COMPARISON_SCHEMA or comparison.get(
        "schema_version"
    ) != 1:
        errors.append("unexpected W005 comparison schema/version")
        return errors
    if comparison.get("counts", {}).get("w005") != EXPECTED_W005_COUNTS:
        errors.append("W005 source artifact census is truncated or changed")
    if comparison.get("counts", {}).get("current_projection") != EXPECTED_W005_COUNTS:
        errors.append("current W005 projection census does not match the legacy set")
    if comparison.get("structural_delta_count") != 0 or comparison.get(
        "unexplained_structural_deltas"
    ):
        errors.append("W005 comparison contains unexplained structural deltas")
    if comparison.get("classification") not in {
        "exact_match",
        "source_binary_changed_structure_same",
    }:
        errors.append(f"unexpected W005 classification {comparison.get('classification')!r}")
    row_results = comparison.get("row_results", [])
    if len(row_results) != EXPECTED_W005_COUNTS["rows"] or any(
        row.get("status") != "exact_match" for row in row_results
    ):
        errors.append("not every W005 row has an exact stable structural match")
    if comparison.get("current_fact_pack", {}).get(
        "canonical_sha256"
    ) != facts.get("canonical_sha256"):
        errors.append("comparison points at the wrong fact-pack digest")
    if comparison.get("w005_artifact", {}).get("schema") != w005.get("schema"):
        errors.append("comparison points at the wrong W005 schema")
    resolved_pin = w005_pin_path.resolve(strict=True)
    repo_root = Path(__file__).resolve().parents[2]
    try:
        displayed_pin = resolved_pin.relative_to(repo_root).as_posix()
    except ValueError:
        displayed_pin = resolved_pin.as_posix()
    expected_pin = {
        "path": displayed_pin,
        "sha256": sha256_file(resolved_pin),
        "schema": w005_pin.get("schema"),
    }
    if comparison.get("w005_baseline_pin") != expected_pin:
        errors.append("comparison points at the wrong W005 baseline pin")
    return errors


def parse_legacy_raw_type(value: str) -> Any:
    """Parse a W005 raw tuple without executing it (used only in diagnostics)."""

    return raw_descriptor(ast.literal_eval(value))
