#!/usr/bin/env python3
"""Generate or byte-check the canonical W010 FRM/FRX export fact pack."""

from __future__ import annotations

import argparse
import os
import tempfile
from pathlib import Path

from frm_frx_facts import FactError, build_fact_pack, canonical_json_bytes


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[1]
DEFAULT_PINS = SCRIPT_DIR / "pinned_sources.v1.json"
DEFAULT_OUTPUT = (
    REPO_ROOT
    / "docs"
    / "evidence"
    / "W010_complete_msforms_object_model_parity"
    / "beads"
    / "oxforms-jbjp.43"
    / "frm_frx_export_facts.v1.json"
)


def _replace_atomically(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        dir=path.parent, prefix=f".{path.name}.", suffix=".tmp"
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pins", type=Path, default=DEFAULT_PINS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--check",
        action="store_true",
        help="generate twice from pinned sources and byte-compare the committed pack",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    try:
        _, pack = build_fact_pack(REPO_ROOT, args.pins)
        payload = canonical_json_bytes(pack)
        if args.check:
            _, second = build_fact_pack(REPO_ROOT, args.pins)
            second_payload = canonical_json_bytes(second)
            if pack != second or payload != second_payload:
                raise FactError("two clean source reads generated different facts")
            if not args.output.is_file():
                raise FactError(f"committed fact pack is missing: {args.output}")
            if args.output.read_bytes() != payload:
                raise FactError(f"committed fact pack differs; regenerate {args.output}")
            print(
                "matched "
                f"{pack['summary']['real_office_fixture_pairs']} Office export pairs, "
                f"{pack['summary']['ms_oforms_property_mappings']} property mappings, and "
                f"{pack['summary']['cfb_streams']} CFB streams"
            )
            return 0
        _replace_atomically(args.output, payload)
        print(
            f"wrote {args.output}: {len(payload)} bytes; "
            f"digest {pack['canonical_sha256']}"
        )
        return 0
    except (FactError, OSError, ValueError) as exc:
        print(f"FRM/FRX fact export failed: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
