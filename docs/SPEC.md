# OxForms Spec Index

This index is the reading order for OxForms requirements, architecture, and
planning truth.

## Core Spec

1. [`FORMS_LIBRARY_SPEC_AND_PLAN.md`](FORMS_LIBRARY_SPEC_AND_PLAN.md) - current
   top-level spec, architecture, and work plan for the VBA-first MSForms-compatible
   forms library.

## Source References

1. [`SOURCE_REFERENCES.md`](SOURCE_REFERENCES.md) - current Foundation MS-OFORMS
   pointer, adjacent MS-OVBA pointer, and the pinned OxVba development baseline
   policy.

## Planned Splits
As work grows, split the top-level document into focused specs and keep them
listed here:

- object model and generated fact pack;
- `.frm` / `.frx` persistence;
- reducer state model and event/effect semantics;
- display-list rendering and PAL contract;
- trace/replay and evidence artifacts;
- Excel-host extension controls, starting with `RefEdit`;
- designer.

The top-level spec remains authoritative until a split document exists and is
linked here.
