"""Regenerate the parity ledger and every pin that depends on repository bytes.

The ledger reads tests, fixtures and native measurements straight from the repository
(``member_evidence.py``), so its pins move whenever those files do.  This command is the
one step that makes them agree again: it rebuilds the ledger, rewrites the pinned hashes
and the expected-ledger manifest, writes the reviewed artifact and updates its checksum
line.  Run it after any change to a test, fixture, native measurement or VBA module, then
run ``export_parity_ledger.py --check`` and the unit tests.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from cli_trust import write_reviewed_artifact
from parity_ledger import (
    EXPECTED_LEDGER_PATH,
    PIN_PATH,
    LedgerError,
    _file_sha256,
    build_expected_ledger_manifest,
    build_ledger,
    canonical_json_bytes,
    load_json_strict,
)
from vba_surface import extract_surface, sha256_bytes

CHECKSUM_PATH = (
    "docs/evidence/W010_complete_msforms_object_model_parity/beads/"
    "oxforms-jbjp.73/checksums.sha256"
)


def _dump(value: dict) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--repo-root", type=Path, default=Path(__file__).resolve().parents[2]
    )
    args = parser.parse_args()
    repo_root = args.repo_root.resolve()
    try:
        ledger = build_ledger(repo_root)
        manifest = build_expected_ledger_manifest(ledger)
        (repo_root / EXPECTED_LEDGER_PATH).write_bytes(_dump(manifest))
        pins = load_json_strict(repo_root / PIN_PATH)
        modes = {item["path"]: item["hash_mode"] for item in pins["files"]}
        for item in ledger["inputs"]:
            modes[item["path"]] = item["hash_mode"]
        surface = extract_surface(repo_root, repo_root / "vba/calcforms/CalcForms.basproj")
        for module in surface["modules"]:
            modes.setdefault(module["path"], "utf8_lf")
        modes.setdefault("tools/msforms-parity/member_evidence.py", "utf8_lf")
        files = []
        for path in sorted(modes):
            full = repo_root / path
            if not full.is_file():
                continue
            files.append(
                {
                    "path": path,
                    "hash_mode": modes[path],
                    "sha256": _file_sha256(full, modes[path]),
                }
            )
        pins["files"] = files
        pins["ledger_inputs"] = ledger["inputs"]
        (repo_root / PIN_PATH).write_bytes(_dump(pins))
        canonical = canonical_json_bytes(ledger)
        output = write_reviewed_artifact(repo_root, manifest["artifact_path"], canonical)
        checksum_file = repo_root / CHECKSUM_PATH
        lines = []
        for line in checksum_file.read_text(encoding="utf-8").splitlines():
            digest, _, name = line.partition("  ")
            if name == output.name:
                digest = sha256_bytes(canonical)
            elif (checksum_file.parent / name).is_file():
                digest = sha256_bytes((checksum_file.parent / name).read_bytes())
            lines.append(f"{digest}  {name}")
        checksum_file.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
        summary = ledger["summary"]
        print(
            f"wrote {len(files)} pins, manifest and ledger; rows={summary['rows']} "
            f"statuses={summary['row_statuses']}"
        )
        return 0
    except (LedgerError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
