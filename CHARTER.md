# CalcForms Charter

## 1. Mission
CalcForms is the VBA-first, MSForms-compatible forms runtime for the DNA Calc
family: `UserForm`, intrinsic controls, form persistence, rendering, input,
event dispatch, and host extension controls, implemented primarily as VBA that
runs on CalcVBA and backed by a small Rust primitive kernel.

CalcForms exists for two reasons:

1. To give CalcVBA and DNA Calc a full-fidelity forms library that can run real
   VBA form code without depending on Microsoft Forms at runtime.
2. To become a large, realistic optimization and correctness workload for the
   CalcVBA compiler, VM, object model, host event path, and future Cranelift JIT.

The central bet is deliberate: build the high-level forms runtime in VBA first,
measure it, improve CalcVBA because of it, and migrate only proven hot paths behind
stable contracts.

The eventual compatibility target is unchanged existing VBA projects using
forms and Microsoft-supplied controls, without depending on the original
control binaries. This includes Microsoft controls beyond MSForms, such as
RefEdit and the Common Controls libraries; third-party controls are excluded.
CalcVBA, OxDoc and the host must supply their respective language, import and
application services. W010 establishes MSForms parity; additional Microsoft
libraries require their own inventories and implementation work.

## 2. Place In The DNA Calc Program
CalcForms is a sibling repository under the DNA Calc umbrella.

It consumes and collaborates with:

- `CalcVBA` for parsing, binding, execution, event dispatch, project loading, and
  integration with the VBA runtime.
- `calcvba-office` in CalcVBA for Office containers, `vbaProject.bin` and
  source-folder read/write; CalcForms decodes the MS-OFORMS control graph.
- `Foundation` for clean-room doctrine, public specifications, and provenance
  discipline.
- future DNA Calc hosts that need VBA forms, especially Excel-like hosts and
  host-specific controls such as Excel `RefEdit`.

CalcForms owns:

- the forms object model and controls;
- `.frm` / `.frx` canonical form persistence;
- the VBA-first forms runtime library;
- the Rust primitive PAL and the control-agnostic retained primitive-tree (Scene) renderer contracts;
- forms-specific trace/replay, facts, conformance matrices, and evidence;
- host-extension control seams, with Excel `RefEdit` as the first expected
  extension target.

## 3. Values Ordering
When values conflict, prefer them in this order:

1. Compatibility with MSForms and observed VBA behavior.
2. Robustness and deterministic replayability.
3. Clean-room evidence and provenance.
4. CalcVBA compiler/runtime learning.
5. Performance.
6. Portability.
7. Runtime size and implementation convenience.

Performance matters, but it does not justify guessing. First make behavior
correct and measurable; then optimize or migrate hot paths with evidence.

## 3.1 Development Architecture Doctrine
CalcForms is in initial development. Internal CalcForms draft APIs, smoke APIs,
bridge APIs, temporary projections, scaffolds, and experimental integration
paths have no backward-compatibility protection. The compatibility target is
Microsoft Forms / FM20 observed behavior and output, plus supported VBA
semantics, not earlier CalcForms implementation shapes.

Do not preserve a temporary shape merely because later work has seen it. If a
scaffold is useful to prove a slice, later work must either replace it with the
intended architecture, delete it, or explicitly quarantine it as non-pattern
test infrastructure before it can influence implementation work.

When implementation speed conflicts with architecture quality, choose the
long-term architecture: canonical contracts, clean layering, deterministic
evidence, future extreme optimization, cross-platform robustness, and code
maintainability. Alternate host bindings are allowed only when they are
first-class implementations of the same canonical contract and remain the best
long-term architecture. They must not exist as legacy fallbacks, compatibility
shims, or bridges kept alive for development convenience.

## 4. Clean-room Rule
CalcForms development uses only:

- public specifications and documentation;
- published research;
- reproducible black-box observation of Office/VBA/MSForms behavior;
- source code owned by DNA Calc repositories or explicitly allowed third-party
  dependencies.

Excluded:

- proprietary or restricted sources;
- decompilation or disassembly of Office internals;
- copying implementation details from Microsoft binaries.

Type libraries, public COM metadata, public protocol documents, and black-box
observation are valid evidence when captured reproducibly.

## 5. Scope
Initial scope:

- MSForms runtime compatibility for `UserForm` and intrinsic FM20 controls.
- VBA-first control implementations with a small Rust primitive kernel.
- `.frm` / `.frx` load/save as CalcForms' canonical project representation.
- Reducer-driven form state, retained-Scene primitive rendering, trace/replay, and golden
  artifacts.
- Windows backend first, with Linux, Web/WASM, and macOS behind the same PAL
  contract.
- Generated fact packs from FM20 type-library data and MS-OFORMS sources.
- Excel-hosted `RefEdit` readiness as an early host-extension control.

In scope later:

- Forms designer.
- More host-specific extension controls.
- Microsoft-supplied control libraries beyond FM20 (`calcforms-tst7` inventory).
- Broader live Office differential harnesses.

Out of scope:

- VBA language/runtime implementation: owned by `CalcVBA`.
- Office document containers and `vbaProject.bin`: owned by CalcVBA (`calcvba-office`).
- Office application object models: host-provided or owned by the relevant host
  repo.
- Spreadsheet/calculation engine behavior: owned by `OxCalc`, `OxFml`,
  `OxFunc`, and DNA Calc hosts.
- Reimplementing arbitrary third-party ActiveX/OCX internals.

## 6. Document Model
Top-level guidance precedence for CalcForms:

1. `CHARTER.md`
2. `docs/SPEC.md` and the spec documents it indexes
3. `OPERATIONS.md`
4. `docs/WORKSET_REGISTER.md`
5. `.beads/` execution state through `br`
6. Evidence artifacts and handovers

This charter defines mission, values, and scope boundaries. The spec owns design
truth. Worksets and beads own execution shape.

## 7. Success Criteria
CalcForms succeeds when:

1. Realistic VBA forms can run on CalcVBA with MSForms-compatible behavior.
2. Compatibility claims are backed by generated facts, tests, and differential
   evidence.
3. Forms traces become useful benchmark workloads for the CalcVBA VM and JIT.
4. Host extensions such as Excel `RefEdit` fit cleanly without polluting the
   FM20 parity claim.
5. The runtime remains portable because platform-specific behavior stays behind
   explicit PAL and host-capability seams.
