"""Strictly validate the committed W010 MSForms parity ledger."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from cli_trust import validation_paths
from parity_ledger import (
    LedgerError,
    build_expected_ledger_manifest,
    canonical_json_bytes,
    load_json_strict,
    validate_committed_ledger,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
    )
    parser.add_argument(
        "--additional-ledger",
        "--ledger",
        dest="additional_ledger",
        type=Path,
        help=(
            "validate this additional in-repository copy after the mandatory "
            "reviewed committed artifact"
        ),
    )
    args = parser.parse_args()
    repo_root = args.repo_root.resolve()
    try:
        expected_path = repo_root / "tools/msforms-parity/expected_ledger.v1.json"
        expected = load_json_strict(expected_path)
        ledger_paths = validation_paths(
            repo_root, expected.get("artifact_path"), args.additional_ledger
        )
        for index, ledger_path in enumerate(ledger_paths):
            ledger = load_json_strict(ledger_path)
            if ledger_path.read_bytes() != canonical_json_bytes(ledger):
                role = "reviewed committed" if index == 0 else "additional"
                raise LedgerError(
                    f"{role} ledger is not in canonical UTF-8/LF JSON form"
                )
            errors = validate_committed_ledger(repo_root, ledger)
            if errors:
                raise LedgerError("; ".join(errors))
            if build_expected_ledger_manifest(ledger) != expected:
                raise LedgerError(
                    "ledger differs from the reviewed expected-ledger manifest"
                )
            role = "reviewed" if index == 0 else "additional"
            print(
                f"OK {role} {ledger_path.relative_to(repo_root).as_posix()} "
                f"rows={ledger['summary']['rows']} "
                f"sha256={ledger['canonical_sha256']} "
                f"green={str(ledger['summary']['green']).lower()}"
            )
        return 0
    except (KeyError, LedgerError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
