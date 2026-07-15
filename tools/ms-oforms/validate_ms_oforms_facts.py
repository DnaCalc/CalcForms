#!/usr/bin/env python3
"""Validate the committed MS-OFORMS persistence/default fact pack."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from ms_oforms_facts import (
    FactError,
    canonical_json_bytes,
    load_foundation_fact_pack,
    load_canonical_json,
    load_json_strict,
    load_pins,
    validate_fact_pack,
)


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[1]
DEFAULT_PINS = SCRIPT_DIR / "pinned_sources.v1.json"
DEFAULT_EXPECTED = SCRIPT_DIR / "expected_capture.v1.json"
DEFAULT_FACTS = (
    REPO_ROOT
    / "docs"
    / "evidence"
    / "W010_complete_msforms_object_model_parity"
    / "beads"
    / "oxforms-jbjp.3"
    / "ms_oforms_persistence_facts.v1.json"
)
DEFAULT_FOUNDATION_ROOT = REPO_ROOT.parent / "Foundation"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--facts", type=Path, default=DEFAULT_FACTS)
    parser.add_argument("--pins", type=Path, default=DEFAULT_PINS)
    parser.add_argument("--expected", type=Path, default=DEFAULT_EXPECTED)
    parser.add_argument("--foundation-root", type=Path, default=DEFAULT_FOUNDATION_ROOT)
    parser.add_argument(
        "--require-sources",
        action="store_true",
        help="also load all pinned Foundation inputs and compare a fresh semantic capture",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        pins = load_pins(args.pins)
        facts = load_canonical_json(args.facts)
        expected = load_json_strict(args.expected)
        pins_sha = hashlib.sha256(args.pins.read_bytes()).hexdigest()
        validate_fact_pack(
            facts,
            pins,
            expected,
            pinned_sources_sha256=pins_sha,
        )
        if args.require_sources:
            fresh = load_foundation_fact_pack(args.foundation_root, pins)
            validate_fact_pack(
                fresh,
                pins,
                expected,
                pinned_sources_sha256=pins_sha,
            )
            if canonical_json_bytes(fresh) != args.facts.read_bytes():
                raise FactError("fresh pinned-source capture differs from the committed fact pack")
        print(
            "MS-OFORMS facts valid: "
            f"{facts['summary']['source_segments']} source rows; "
            f"{facts['summary']['record_fields']} record fields; "
            f"{facts['summary']['properties']} properties; "
            f"{facts['summary']['documented_defaults']} defaults + "
            f"{facts['summary']['mandatory_persist_no_default']} mandatory; "
            f"{facts['summary']['product_behavior_rows']} product notes"
        )
        return 0
    except (FactError, OSError, ValueError) as exc:
        print(f"MS-OFORMS validation failed: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
