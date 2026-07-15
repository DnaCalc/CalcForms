#!/usr/bin/env python3
"""Validate committed FM20 facts and recompute the W005 reconciliation."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import typelib_facts


REPO_ROOT = Path(__file__).resolve().parents[2]
EVIDENCE_DIR = (
    REPO_ROOT
    / "docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.2"
)
DEFAULT_FACTS = EVIDENCE_DIR / "fm20_typelib_facts.v1.json"
DEFAULT_COMPARISON = EVIDENCE_DIR / "w005_event_reconciliation.v1.json"
DEFAULT_PINS = Path(__file__).resolve().with_name("pinned_typelibs.v1.json")
DEFAULT_W005_PIN = Path(__file__).resolve().with_name("pinned_w005_baseline.v1.json")
DEFAULT_EXPECTED_CAPTURE = Path(__file__).resolve().with_name("expected_capture.v1.json")
DEFAULT_W005 = (
    REPO_ROOT
    / "docs/evidence/W005_input_interaction_model_exploration/fm20_typelib_w005_events.json"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--facts", type=Path, default=DEFAULT_FACTS)
    parser.add_argument("--comparison", type=Path, default=DEFAULT_COMPARISON)
    parser.add_argument("--pins", type=Path, default=DEFAULT_PINS)
    parser.add_argument("--w005", type=Path, default=DEFAULT_W005)
    parser.add_argument("--w005-pin", type=Path, default=DEFAULT_W005_PIN)
    parser.add_argument(
        "--expected-capture", type=Path, default=DEFAULT_EXPECTED_CAPTURE
    )
    parser.add_argument("--require-sources", action="store_true")
    return parser.parse_args()


def collect(label: str, problems: list[str], errors: list[str]) -> None:
    errors.extend(f"{label}: {problem}" for problem in problems)


def require_canonical(path: Path, value: dict) -> str | None:
    if path.read_bytes() != typelib_facts.canonical_json_bytes(value):
        return f"{path}: JSON is not canonical UTF-8/LF/sorted-key output"
    return None


def main() -> int:
    args = parse_args()
    errors: list[str] = []
    pins = typelib_facts.load_json_strict(args.pins)
    w005_pin = typelib_facts.load_json_strict(args.w005_pin)
    expected_capture = typelib_facts.load_json_strict(args.expected_capture)
    facts = typelib_facts.load_json_strict(args.facts)
    comparison = typelib_facts.load_json_strict(args.comparison)
    w005 = typelib_facts.load_json_strict(args.w005)
    collect(
        "W005 baseline pin",
        typelib_facts.validate_w005_baseline_pin(
            w005_pin, w005, w005_path=args.w005
        ),
        errors,
    )

    collect("pins", typelib_facts.validate_pin_manifest(pins), errors)
    collect(
        "facts",
        typelib_facts.validate_fact_pack(
            facts, require_sources=args.require_sources
        ),
        errors,
    )
    collect(
        "fact pins",
        typelib_facts.validate_fact_pack_against_pins(facts, pins),
        errors,
    )
    if args.require_sources:
        collect("live pins", typelib_facts.validate_live_pins(pins), errors)

    collect(
        "comparison",
        typelib_facts.validate_w005_comparison(
            comparison,
            facts,
            w005,
            w005_pin=w005_pin,
            w005_pin_path=args.w005_pin,
        ),
        errors,
    )
    collect(
        "reviewed capture pin",
        typelib_facts.validate_expected_capture(
            expected_capture, facts, comparison
        ),
        errors,
    )
    regenerated_comparison = typelib_facts.build_w005_comparison(
        facts,
        w005,
        w005_path=args.w005,
        w005_pin=w005_pin,
        w005_pin_path=args.w005_pin,
    )
    if comparison != regenerated_comparison:
        errors.append("comparison: committed object differs from recomputed W005 result")

    for path, value in (
        (args.facts, facts),
        (args.comparison, comparison),
    ):
        canonical_error = require_canonical(path, value)
        if canonical_error:
            errors.append(canonical_error)

    generator_sources = facts.get("generator", {}).get("source_files", [])
    for source in generator_sources:
        path = REPO_ROOT / source.get("path", "")
        if not path.is_file():
            errors.append(f"generator source missing: {path}")
        elif typelib_facts.sha256_file(path) != source.get("sha256"):
            errors.append(f"generator source hash drift: {path}")

    if errors:
        print("FM20 fact validation failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print(
        "FM20 facts valid: "
        f"{facts['summary']['exported_type_view_count']} views; "
        f"{sum(len(item['functions']) for library in facts['libraries'] for item in library['types'])} functions; "
        f"{comparison['counts']['current_projection']['rows']} W005 rows; "
        f"{comparison['classification']}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, typelib_facts.FactError) as error:
        print(f"FM20 fact validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
