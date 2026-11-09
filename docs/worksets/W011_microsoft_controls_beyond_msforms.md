# W011 — Microsoft-Supplied Controls Beyond MSForms

Status: `OPEN` (Planning established by `oxforms-tst7`)

Parent Spec: [`docs/specs/MICROSOFT_CONTROLS_BEYOND_MSFORMS.md`](../specs/MICROSOFT_CONTROLS_BEYOND_MSFORMS.md)<br>
Charter Ref: Section 1 & Section 5<br>
Bead: `oxforms-tst7`<br>
Depends on: `W010_complete_msforms_object_model_parity` (for foundation runtime, Scene renderer, and VBA object dispatch architecture)

---

## 1. Purpose & Scope

The charter and user direction establish that existing VBA projects using forms
and Microsoft-supplied controls must compile, bind, and execute unchanged under
CalcVBA and CalcForms, with third-party controls excluded.

While `W010` focuses exclusively on Microsoft Forms 2.0 (`FM20`), this workset
(`W011`) plans and implements support for Microsoft-supplied controls that shipped
outside FM20. The primary families in scope are:

1. **Excel RefEdit Control** (`RefEdit.Ctrl`, `REFEDIT.DLL`):
   Range-selection-aware edit control tightly integrated with Excel host sheets.
2. **Microsoft Windows Common Controls 6.0** (`MSCOMCTL.OCX`):
   `ListView`, `TreeView`, `ProgressBar`, `Slider`, `StatusBar`, `TabStrip`,
   `Toolbar`, `ImageList`, `ImageCombo`.
3. **Microsoft Windows Common Controls-2 6.0** (`MSCOMCT2.OCX`):
   `DTPicker` (DateTimePicker), `MonthView`, `UpDown`, `Animation`, `FlatScrollBar`.
4. **Microsoft Rich Textbox Control 6.0** (`RICHTX32.OCX`):
   `RichTextBox`.
5. **Legacy 5.0 Equivalence Mapping**:
   Aliases and compatibility bindings for `COMCTL32.OCX` / `COMCT232.OCX`.

---

## 2. Core Architectural Principles

- **Zero OCX Binary Dependency**: Clean-room, pure-runtime implementation within
  CalcForms/CalcVBA and the retained Scene PAL. Does not load or require original
  Win32 32-bit OCX binaries, solving the classic 64-bit Office incompatibility.
- **Strict Clean-Room Provenance**: Built solely from public type libraries,
  official Microsoft documentation, [MS-OFORMS] persistence specifications, and
  black-box behavioral observation.
- **Distinct from FM20 Parity**: W010 MSForms parity claims cannot be cited to
  satisfy W011 requirements. W011 maintains its own metadata ledger, persistence
  fact packs, and behavior verification matrices.
- **Seam-Isolated Host Extensions**: Host-dependent controls like `RefEdit`
  interact with host spreadsheet capabilities strictly through explicit service
  contracts (`IRefEditHostProvider`), ensuring runtime portability across
  non-Excel contexts.

---

## 3. Workset Lanes and Phased Plan

### Lane 1: Typelib Fact Extraction & Symbol Facade
- Extract complete COM metadata from `RefEdit.dll`, `MSCOMCTL.OCX`, and `MSCOMCT2.OCX`.
- Produce deterministic JSON fact packs containing all coclasses, interfaces,
  DISPIDs, methods, properties, and event signatures.
- Register public type names and ProgIDs in the CalcVBA reference resolver.

### Lane 2: Persistence & Stream Decoders
- Decode [MS-OFORMS] 3.3.1 `RefEdit` embedded records in `calcvba-office`.
- Implement clean-room property-stream parsers for `MSCOMCTL` and `MSCOMCT2`
  ActiveX persistence streams without calling OLE `IPersistStreamInit`.
- Support round-trip persistence in `.frm` / `.frx` form source definitions.

### Lane 3: RefEdit Excel Host Integration
- Implement `RefEdit` control UI, text selection, and expand/collapse behavior.
- Define `IRefEditHostProvider` interface for worksheet range coordination.
- Build headless mock provider and interactive test harness.

### Lane 4: Common Controls Suite Implementation
- **4.1 Simple Controls**: `ProgressBar`, `Slider`, `StatusBar`.
- **4.2 Date & Numeric Controls**: `DTPicker`, `MonthView`, `UpDown`.
- **4.3 Collection & Item Controls**: `ListView`, `ImageList`, `ImageCombo`.
- **4.4 Hierarchical Controls**: `TreeView`.
- **4.5 Rich Formatting**: `RichTextBox`.

### Lane 5: Conformance Corpus & Oracle Replay
- Construct corpus of real-world workbooks utilizing Microsoft-supplied controls.
- Differential testing against 32-bit Excel / VBA with registered OCXs.
- Verify unchanged compilation, execution, and event handling.

---

## 4. Verification & Closure Conditions

`W011` closes when:
1. All in-scope Microsoft-supplied controls can be instantiated on a UserForm
   from VBA code and from persisted `.frm`/`.frx` files without original OCX binaries.
2. Public member calls, property assignments, default members, and event dispatches
   conform to documented COM signatures.
3. Excel `RefEdit` range selection operates correctly within host spreadsheet sessions.
4. Conformance test suite passes cleanly across 32-bit and 64-bit execution profiles.
