"""Derive member-level test and native-measurement evidence from the repository.

The parity ledger used to fix the ``oracle`` and ``tests`` dimensions of every public
member row to ``missing``, so no evidence could ever attach.  This module reads the
committed repository instead, with no hand-maintained list:

* a *test file* is a Rust file under ``crates/*/tests`` that contains at least one
  ``#[test]`` function not marked ``#[ignore]``;
* the VBA text a test file drives is its own string literals, plus every VBA module
  (``.bas``/``.cls``/``.frm``) in a ``fixtures/`` path it names (a directory names all of
  its modules), plus every ``.bas`` under an evidence bead directory it names;
* a *member is exercised* when that VBA text declares a variable ``As [MSForms.]Type`` (or
  binds one with ``Controls.Add("Forms.Type.1", "Name")``) and then references
  ``Variable.Member`` (including inside ``With Variable``), or defines an event handler
  ``Variable_Event`` for a ``WithEvents`` variable;
* a *native measurement agrees* when such a test file also names a committed evidence bead
  directory whose native-measurement text files (path contains ``native``, or an
  ``observations.json``/``excel-observations.json``, or JSON recording an Excel pid or launch)
  mention the member name as a whole word.

Limits, stated so no row over-claims: attribution is per test file, not per assertion; a
test that is committed and not ignored is not proof that it passed (the repository's
``cargo test`` check is that proof); controls reached only through designer-created names
whose types are stored in binary ``.frx`` data are not seen; the match of a native file is a
whole-word search for the member name, not a structural comparison.
"""

from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path

TEST_GLOB = "crates/*/tests/*.rs"
VBA_SUFFIXES = {".bas", ".cls", ".frm"}
NATIVE_TEXT_SUFFIXES = {".json", ".csv", ".txt", ".bas", ".vba"}
DEFAULT_MEMBER = "<default>"
BEAD_ROOT = "docs/evidence/W010_complete_msforms_object_model_parity/beads"

_FIXTURE_RE = re.compile(r"fixtures/[A-Za-z0-9_./-]+")
_CAPTURE_RE = re.compile(r"tools/office-oracle/[A-Za-z0-9_.-]+\.py")
_BEAD_RE =re.compile(r"oxforms-jbjp\.[0-9]+(?:\.[0-9]+)?")
_DECL_RE = re.compile(
    r"(?im)\b(?:Dim|Private|Public|Static|ByVal|ByRef)\s+(?:WithEvents\s+)?(\w+)\s+As\s+(?:New\s+)?"
    r"(?:(?:MSForms|Forms)\.)?(\w+)"
)
_PARAM_RE = re.compile(
    r"(?i)(?:\(|,)\s*(?:ByVal\s+|ByRef\s+|Optional\s+)?(\w+)\s+As\s+(?:(?:MSForms|Forms)\.)?(\w+)"
)
_ADD_RE = re.compile(
    r"(?i)(?:Set\s+(\w+)\s*=\s*)?[\w.]*Controls\.Add\(\s*\"Forms\.(\w+)\.1\"\s*,\s*\"(\w+)\""
)
_WITHEVENTS_RE = re.compile(
    r"(?im)\bWithEvents\s+(\w+)\s+As\s+(?:(?:MSForms|Forms)\.)?(\w+)"
)
_SUB_RE = re.compile(r"(?im)^\s*(?:Private\s+|Public\s+)?Sub\s+(\w+)_(\w+)\s*\(")
_MEMBER_RE = re.compile(r"(?<![\w.])(\w+)\.(\w+)")
_WITH_RE = re.compile(r"(?i)^\s*With\s+(\w+)\s*$")
_END_WITH_RE = re.compile(r"(?i)^\s*End\s+With\b")
_DOT_RE = re.compile(r"(?<![\w)\"])\.(\w+)")
_LOCAL_CLASS_RE = re.compile(
    r"(?:module_name:\s*\"(\w+)\"|class\(\s*\"(\w+)\")"
)
_TEST_RE = re.compile(r"#\[test\]((?:\s*#\[[^\]]*\])*)\s*fn\s+(\w+)")


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeDecodeError):
        return ""


def _is_native_text(path: Path, text: str) -> bool:
    name = path.name.lower()
    if path.suffix.lower() not in NATIVE_TEXT_SUFFIXES:
        return False
    parts = [part.lower() for part in path.parts]
    if any("native" in part for part in parts) or name in {
        "observations.json",
        "excel-observations.json",
    }:
        return True
    return path.suffix.lower() == ".json" and (
        '"excel_pid"' in text or '"excel_launches"' in text or '"excel_build"' in text
    )


_PROC_RE = re.compile(
    r"(?is)\b(?:Sub|Function|Property\s+(?:Get|Let|Set))\s+\w+.*?\bEnd\s+(?:Sub|Function|Property)\b"
)


def _vba_variables(text: str) -> tuple[dict[str, set[str]], dict[str, str], set[str]]:
    """Variable types (a name may hold several), Controls.Add name types, WithEvents names."""

    variable_types: dict[str, set[str]] = defaultdict(set)
    for regex in (_DECL_RE, _PARAM_RE):
        for name, type_name in regex.findall(text):
            variable_types[name.casefold()].add(type_name.casefold())
    add_names: dict[str, str] = {}
    for variable, type_name, name in _ADD_RE.findall(text):
        add_names[name.casefold()] = type_name.casefold()
        if variable:
            variable_types[variable.casefold()].add(type_name.casefold())
    with_events = {name.casefold() for name, _ in _WITHEVENTS_RE.findall(text)}
    return variable_types, add_names, with_events


def _resolve(types: dict[str, set[str]], extra: dict[str, str]) -> dict[str, str]:
    """Names with exactly one type; a name declared with two types here is ambiguous."""

    resolved = dict(extra)
    for name, found in types.items():
        if len(found) == 1:
            resolved[name] = next(iter(found))
        else:
            resolved.pop(name, None)
    return resolved


_ASSIGN_RE = re.compile(r"(?is)^\s*(?:Set\s+|Let\s+)?(\w*)\.(\w+)\s*(?:\([^=]*\))?\s*=(?!=)")
_BARE_ASSIGN_RE = re.compile(r"(?is)^\s*(?:Let\s+)?(\w+)\s*=(?!=)\s*(.*)$")
_STRING_RE = re.compile(r'"[^"]*"')


def _statements(text: str) -> list[str]:
    """Split on newlines and on colons outside string literals."""

    result: list[str] = []
    for line in text.splitlines():
        current: list[str] = []
        in_string = False
        for char in line:
            if char == '"':
                in_string = not in_string
            if char == ":" and not in_string:
                result.append("".join(current))
                current = []
            else:
                current.append(char)
        result.append("".join(current))
    return result


def _scan_block(
    text: str, typed: dict[str, str]
) -> set[tuple[str, str, str]]:
    """(type, member, 'read'|'write') references in one declaration scope."""

    found: set[tuple[str, str, str]] = set()
    stack: list[str] = []
    for statement in _statements(text):
        code = _STRING_RE.sub('""', statement)
        code = code.split("'", 1)[0]
        with_match = _WITH_RE.match(code)
        if with_match:
            stack.append(with_match.group(1).casefold())
            continue
        if _END_WITH_RE.match(code):
            if stack:
                stack.pop()
            continue
        bare = _BARE_ASSIGN_RE.match(code)
        if bare:
            # A Let on a bare object variable goes to its default member, and a bare
            # variable alone on the right-hand side reads it.
            target = typed.get(bare.group(1).casefold())
            if target is not None:
                found.add((target, DEFAULT_MEMBER, "write"))
            rhs = bare.group(2).strip()
            right = typed.get(rhs.casefold()) if re.fullmatch(r"\w+", rhs) else None
            if right is not None:
                found.add((right, DEFAULT_MEMBER, "read"))
        assign = _ASSIGN_RE.match(code)
        written: tuple[str, str] | None = None
        if assign:
            holder = assign.group(1).casefold() or (stack[-1] if stack else "")
            written = (holder, assign.group(2).casefold())
        for variable, member in _MEMBER_RE.findall(code):
            owner = typed.get(variable.casefold())
            if owner is None:
                continue
            kind = "write" if written == (variable.casefold(), member.casefold()) else "read"
            found.add((owner, member.casefold(), kind))
        if stack:
            owner = typed.get(stack[-1])
            if owner is not None:
                for member in _DOT_RE.findall(code):
                    kind = (
                        "write"
                        if written == (stack[-1], member.casefold())
                        else "read"
                    )
                    found.add((owner, member.casefold(), kind))
    return found


def _scan_vba(
    text: str,
) -> tuple[set[tuple[str, str, str]], set[tuple[str, str]]]:
    """Return (member references with access kind, event handlers), casefolded.

    Declarations are scoped: module-level ones apply everywhere, procedure-level ones only
    inside their procedure, and a name that holds two different types in one scope is
    treated as unknown rather than guessed.
    """

    procedures = [match.group(0) for match in _PROC_RE.finditer(text)]
    module_text = _PROC_RE.sub(" ", text)
    module_types, module_adds, with_events = _vba_variables(module_text)
    module_typed = _resolve(module_types, module_adds)
    members = _scan_block(module_text, module_typed)
    events: set[tuple[str, str]] = set()
    for procedure in procedures:
        local_types, local_adds, _ = _vba_variables(procedure)
        typed = dict(module_typed)
        typed.update(_resolve(local_types, local_adds))
        for name in local_types:
            if len(local_types[name]) != 1:
                typed.pop(name, None)
        members |= _scan_block(procedure, typed)
    for variable, event in _SUB_RE.findall(text):
        key = variable.casefold()
        if key in with_events and key in module_typed:
            events.add((module_typed[key], event.casefold()))
    return members, events


def _strip_rust_comments(text: str) -> str:
    return "\n".join(
        line for line in text.splitlines() if not line.lstrip().startswith("//")
    )


def _fixture_modules(repo_root: Path, text: str) -> list[Path]:
    found: set[Path] = set()
    for relative in _FIXTURE_RE.findall(text):
        relative = relative.rstrip("/.")
        target = repo_root / relative
        if target.is_dir():
            candidates = [
                item
                for item in target.rglob("*")
                if item.is_file() and item.suffix.lower() in VBA_SUFFIXES
            ]
        elif target.is_file() and target.suffix.lower() in VBA_SUFFIXES:
            candidates = [target]
        elif target.parent.is_dir() and target.suffix:
            candidates = []
        else:
            candidates = []
        found.update(candidates)
    return sorted(found)


def _bead_directories(repo_root: Path, text: str) -> list[Path]:
    beads = repo_root / BEAD_ROOT
    return sorted(
        {
            beads / bead
            for bead in _BEAD_RE.findall(text)
            if (beads / bead).is_dir()
        }
    )


def build_member_evidence(repo_root: Path) -> dict:
    """Scan the repository and return the member evidence index.

    ``tests``/``events``: ``(type, name) -> sorted test file paths``.
    ``oracle``/``oracle_events``: ``(type, name) -> sorted ((test path, native path), ...)``.
    ``inputs``: every file whose bytes influenced the result (for pinning).
    """

    repo_root = repo_root.resolve()
    tests: dict[tuple[str, str, str], set[str]] = defaultdict(set)
    events: dict[tuple[str, str], set[str]] = defaultdict(set)
    oracle: dict[tuple[str, str, str], set[tuple[str, str]]] = defaultdict(set)
    oracle_events: dict[tuple[str, str], set[tuple[str, str]]] = defaultdict(set)
    inputs: set[str] = set()
    test_functions: dict[str, list[str]] = {}

    def rel(path: Path) -> str:
        return path.relative_to(repo_root).as_posix()

    for test_file in sorted(repo_root.glob(TEST_GLOB)):
        text = _read(test_file)
        inputs.add(rel(test_file))
        runnable = [
            name
            for attributes, name in _TEST_RE.findall(text)
            if "ignore" not in attributes
        ]
        if not runnable:
            continue
        test_functions[rel(test_file)] = runnable
        code = _strip_rust_comments(text)
        sources = [code]
        for module in _fixture_modules(repo_root, code):
            inputs.add(rel(module))
            sources.append(_read(module))
        beads = _bead_directories(repo_root, code)
        native_files: list[tuple[str, str]] = []
        # VBA that ran natively: observer .bas files in the named beads and the capture
        # scripts the test file names (their string literals are the macro text Excel ran).
        native_sources: list[str] = []
        for script in sorted(set(_CAPTURE_RE.findall(code))):
            script_path = repo_root / script
            if script_path.is_file():
                inputs.add(rel(script_path))
                native_sources.append(_read(script_path))
        for bead in beads:
            for item in sorted(bead.rglob("*")):
                if not item.is_file():
                    continue
                suffix = item.suffix.lower()
                if suffix == ".bas":
                    inputs.add(rel(item))
                    sources.append(_read(item))
                    native_sources.append(_read(item))
                if suffix in NATIVE_TEXT_SUFFIXES:
                    body = _read(item)
                    if _is_native_text(item, body):
                        inputs.add(rel(item))
                        native_files.append((rel(item), body.casefold()))
        # A class the test file defines itself (a synthetic probe class) is not the
        # shipped library class of that name, so it is not evidence for that type.
        local_types = {
            (first or second).casefold()
            for first, second in _LOCAL_CLASS_RE.findall(code)
        }
        members: set[tuple[str, str, str]] = set()
        handlers: set[tuple[str, str]] = set()
        for source in sources:
            source = source.replace("\\n", "\n").replace('\\"', '"')
            found_members, found_events = _scan_vba(source)
            members |= {key for key in found_members if key[0] not in local_types}
            handlers |= {key for key in found_events if key[0] not in local_types}
        native_members: set[tuple[str, str, str]] = set()
        native_handlers: set[tuple[str, str]] = set()
        for source in native_sources:
            source = source.replace("\\n", "\n").replace('\\"', '"')
            found_members, found_events = _scan_vba(source)
            native_members |= found_members
            native_handlers |= found_events
        for key in members:
            tests[key].add(rel(test_file))
            for native_path, body in native_files:
                if key in native_members or re.search(
                    rf"\b{re.escape(key[1])}\b", body
                ):
                    oracle[key].add((rel(test_file), native_path))
        for key in handlers:
            events[key].add(rel(test_file))
            for native_path, body in native_files:
                if key in native_handlers or re.search(
                    rf"\b{re.escape(key[1])}\b", body
                ):
                    oracle_events[key].add((rel(test_file), native_path))

    return {
        "tests": {key: sorted(value) for key, value in tests.items()},
        "events": {key: sorted(value) for key, value in events.items()},
        "oracle": {key: sorted(value) for key, value in oracle.items()},
        "oracle_events": {key: sorted(value) for key, value in oracle_events.items()},
        "inputs": sorted(inputs),
        "test_functions": test_functions,
    }


def lookup(
    index: dict, kind: str, owners: list[str], name: str, access: str | None = None
) -> list:
    """Merge evidence over every owner spelling (canonical name and source alias).

    ``access`` is ``read`` (get, method call) or ``write`` (put, putref) for the member
    kinds, and is omitted for events.
    """

    merged: set = set()
    for owner in owners:
        key = (owner.casefold(), name.casefold())
        if access is not None:
            key += (access,)
        value = index[kind].get(key)
        if value:
            merged.update(value)
    return sorted(merged)
