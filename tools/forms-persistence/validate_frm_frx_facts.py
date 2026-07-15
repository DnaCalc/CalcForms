#!/usr/bin/env python3
"""Validate the committed W010 FRM/FRX export fact pack and local fixtures."""

from __future__ import annotations

import argparse
from pathlib import Path

from frm_frx_facts import (
    FactError,
    build_fact_pack,
    canonical_json_bytes,
    load_canonical_fact_pack,
    load_json_strict,
    load_pins,
    validate_fact_pack,
    validate_local_surfaces,
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
    / "oxforms-jbjp.43"
    / "frm_frx_export_facts.v1.json"
)


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--facts", type=Path, default=DEFAULT_FACTS)
    parser.add_argument("--pins", type=Path, default=DEFAULT_PINS)
    parser.add_argument("--expected", type=Path, default=DEFAULT_EXPECTED)
    parser.add_argument(
        "--require-sources",
        action="store_true",
        help="also verify the clean pinned Foundation checkout and fresh full regeneration",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    try:
        pins = load_pins(args.pins)
        facts = load_canonical_fact_pack(args.facts)
        expected = load_json_strict(args.expected)
        validate_fact_pack(facts, pins=pins, expected=expected)
        validate_local_surfaces(facts, REPO_ROOT, pins)
        if args.require_sources:
            _, fresh = build_fact_pack(REPO_ROOT, args.pins)
            if canonical_json_bytes(fresh) != args.facts.read_bytes():
                raise FactError("fresh pinned-source regeneration differs from committed facts")
        summary = facts["summary"]
        print(
            "FRM/FRX export facts valid: "
            f"{summary['real_office_fixture_pairs']} real export pairs; "
            f"{summary['designer_properties']} DesignerProperties rows; "
            f"{summary['ms_oforms_property_mappings']} MS-OFORMS mappings; "
            f"{summary['cfb_streams']} CFB streams"
        )
        return 0
    except (FactError, OSError, ValueError) as exc:
        print(f"FRM/FRX fact validation failed: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
