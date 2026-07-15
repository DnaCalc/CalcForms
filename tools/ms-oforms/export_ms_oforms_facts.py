#!/usr/bin/env python3
"""Generate or deterministically check the pinned MS-OFORMS fact pack."""

from __future__ import annotations

import argparse
import hashlib
import os
import tempfile
from pathlib import Path

from ms_oforms_facts import (
    FactError,
    canonical_json_bytes,
    load_foundation_fact_pack,
    load_json_strict,
    load_pins,
    validate_fact_pack,
)


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[1]
DEFAULT_PINS = SCRIPT_DIR / "pinned_sources.v1.json"
DEFAULT_EXPECTED = SCRIPT_DIR / "expected_capture.v1.json"
DEFAULT_OUTPUT = (
    REPO_ROOT
    / "docs"
    / "evidence"
    / "W010_complete_msforms_object_model_parity"
    / "beads"
    / "oxforms-jbjp.3"
    / "ms_oforms_persistence_facts.v1.json"
)
DEFAULT_FOUNDATION_ROOT = REPO_ROOT.parent / "Foundation"


def replace_atomically(path: Path, payload: bytes) -> None:
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pins", type=Path, default=DEFAULT_PINS)
    parser.add_argument("--expected", type=Path, default=DEFAULT_EXPECTED)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--foundation-root", type=Path, default=DEFAULT_FOUNDATION_ROOT)
    parser.add_argument(
        "--check",
        action="store_true",
        help="regenerate twice, validate, and byte-compare with the committed fact pack",
    )
    return parser.parse_args()


def generate_bytes(foundation_root: Path, pins_path: Path) -> tuple[dict, dict, bytes]:
    pins = load_pins(pins_path)
    pack = load_foundation_fact_pack(foundation_root, pins)
    validate_fact_pack(pack, pins)
    return pins, pack, canonical_json_bytes(pack)


def main() -> int:
    args = parse_args()
    try:
        pins, pack, generated = generate_bytes(args.foundation_root, args.pins)
        if args.check:
            _, second_pack, second = generate_bytes(args.foundation_root, args.pins)
            if generated != second or pack != second_pack:
                raise FactError("two clean source reads produced different fact-pack bytes")
            if not args.output.is_file():
                raise FactError(f"committed fact pack is missing: {args.output}")
            committed = args.output.read_bytes()
            if committed != generated:
                raise FactError(
                    f"committed fact pack is not byte-stable; regenerate {args.output}"
                )
            expected = load_json_strict(args.expected)
            validate_fact_pack(
                pack,
                pins,
                expected,
                pinned_sources_sha256=hashlib.sha256(args.pins.read_bytes()).hexdigest(),
            )
            print(
                "matched "
                f"{pack['summary']['source_segments']} source rows, "
                f"{pack['summary']['properties']} properties, "
                f"{pack['summary']['record_fields']} record fields, and "
                f"{pack['summary']['product_behavior_rows']} product-behavior rows"
            )
            return 0

        replace_atomically(args.output, generated)
        print(
            f"wrote {args.output}: {pack['summary']['source_segments']} source rows, "
            f"{pack['summary']['properties']} properties"
        )
        return 0
    except (FactError, OSError, ValueError) as exc:
        print(f"MS-OFORMS export failed: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
