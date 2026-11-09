# Microsoft-Supplied Controls Beyond MSForms: Inventory, Architecture, and Work Plan

Status: `spec_and_plan`<br>
Date: 2026-11-09<br>
Workset: `W011_microsoft_controls_beyond_msforms` (planned)<br>
Bead: `oxforms-tst7`<br>
Precedence: follows `CHARTER.md`, `docs/SPEC.md`, `OPERATIONS.md`, and `docs/specs/MSFORMS_FACADE_CONTRACT.md`.

---

## 1. Executive Summary & Objective

The user-confirmed compatibility target requires that existing VBA projects using
forms and Microsoft-supplied controls compile, bind, and execute unchanged under
CalcVBA and CalcForms. Third-party controls remain strictly excluded.

Workset `W010` is dedicated to full-fidelity `MSForms` (FM20) compatibility.
Non-FM20 Microsoft-supplied controls—most notably Excel `RefEdit` and the
Microsoft Windows Common Controls suites (`MSCOMCTL.OCX`, `MSCOMCT2.OCX`,
`RICHTX32.OCX`)—must not be silently dismissed as third-party, nor may their
features be claimed from W010 MSForms evidence.

Instead, CalcForms provides clean-room, OCX-binary-independent implementations
of these Microsoft-supplied controls. This document defines the exhaustive
inventory, exact COM metadata identities, 32-bit and 64-bit architecture
realities, host capability seams, persistence models, and an execution roadmap
for a dedicated workset (`W011`).

---

## 2. Architecture & Clean-Room Doctrine

### 2.1 Independent of Original OCX Binaries
Historical VBA UserForms relied on 32-bit ActiveX OCX binaries registered in the
Windows registry. When Office introduced 64-bit editions, many legacy 32-bit OCXs
(such as `MSCOMCTL.OCX` and `MSCOMCT2.OCX`) were never recompiled for 64-bit,
causing widespread failure in enterprise workbooks.

CalcForms resolves this architectural friction:
1. **Zero Binary Dependency**: CalcForms does not require `REFEDIT.DLL`,
   `MSCOMCTL.OCX`, or other OCX binaries to be installed, registered, or
   executed at runtime.
2. **VBA-First with PAL Retention**: Controls are implemented as first-class
   VBA classes or internal CalcForms components that project the exact public COM
   interfaces, properties, methods, and event signatures. Retained rendering
   is submitted across `CalcForms.Surface` to the platform-independent Scene
   graph.
3. **Cross-Bitness & Cross-Platform**: By avoiding native 32-bit COM OCX binaries,
   projects run seamlessly in 32-bit and 64-bit environments, as well as on
   non-Windows platforms supported by CalcForms PAL.

### 2.2 Host-Specific Controls vs Intrinsic Controls
- **Excel `RefEdit`**: Depends on an Excel-capable host provider to manage range
  selection, sheet navigation, and form collapse/restore behavior. Outside an
  Excel host, `RefEdit` functions as a specialized text input box with graceful
  diagnostics.
- **Common Controls**: Self-contained visual and interaction controls (`ListView`,
  `TreeView`, `ProgressBar`, `DTPicker`, etc.) that execute entirely within
  the CalcForms runtime.

---

## 3. Control Inventory & Exact Identity Metadata

### 3.1 Excel RefEdit Control

| Attribute | Specification |
|---|---|
| **Primary Library** | `RefEdit.dll` / `RefEdit.tlb` |
| **Typelib Name** | `RefEdit` |
| **Typelib GUID** | `{00024510-0000-0000-C000-000000000046}` |
| **Version** | 1.0, 1.1, 1.2 |
| **Control Class** | `RefEdit.Ctrl` / `RefEdit.Ctrl.1` |
| **CLSID** | `{00024512-0000-0000-C000-000000000046}` |
| **Primary Interface** | `_RefEdit` (`{00024511-0000-0000-C000-000000000046}`) |
| **Event Interface** | `DIForControlEvents` (`{00024513-0000-0000-C000-000000000046}`) |
| **Key Properties** | `Value` (default), `Text`, `SelStart`, `SelLength`, `SelText`, `Address`, `MultiLine`, `Locked` |
| **Key Events** | `BeforeDragOver`, `BeforeDropOrPaste`, `Change`, `DblClick`, `DropButtonClick`, `KeyDown`, `KeyPress`, `KeyUp`, `MouseDown`, `MouseMove`, `MouseUp` |
| **Host Requirement** | Excel application host (`Excel.Application`), active sheet selection hook, workbook coordinate translation |
| **Bitness** | 32-bit and 64-bit DLLs distributed with Microsoft Excel |
| **Provenance** | Microsoft Excel Type Library; [MS-OFORMS] section 3.3.1 (embedded RefEdit persistence) |

### 3.2 Microsoft Windows Common Controls 6.0 (`MSCOMCTL.OCX`)

| Attribute | Specification |
|---|---|
| **Primary Library** | `MSCOMCTL.OCX` |
| **Typelib Name** | `MSComctlLib` |
| **Typelib GUID** | `{831FDD16-0C5C-11D2-A9FC-0000F8754DA1}` |
| **Version** | 2.0 / 2.1 / 2.2 |
| **Bitness** | Historically 32-bit only |
| **Provenance** | Visual Basic 6.0 / Office Developer documentation; COM typelib inspection |

#### Controls in `MSComctlLib`:

1. **ListView (`MSComctlLib.ListViewCtrl.2`)**
   - CLSID: `{BDD1F04B-858B-11D1-B16A-00C0F0283628}`
   - Primary Interface: `IListView` (`{BDD1F04A-858B-11D1-B16A-00C0F0283628}`)
   - Events: `IListViewEvents` (`{BDD1F04C-858B-11D1-B16A-00C0F0283628}`)
   - Core Features: `ListItems`, `ColumnHeaders`, `View` (lvwIcon, lvwSmallIcon, lvwList, lvwReport), `MultiSelect`, `SelectedItem`, `SortKey`, `SortOrder`.
2. **TreeView (`MSComctlLib.TreeCtrl.2`)**
   - CLSID: `{C74190B6-8589-11D1-B16A-00C0F0283628}`
   - Primary Interface: `ITreeView` (`{C74190B5-8589-11D1-B16A-00C0F0283628}`)
   - Events: `ITreeViewEvents` (`{C74190B7-8589-11D1-B16A-00C0F0283628}`)
   - Core Features: `Nodes` (hierarchy, `Add`, `Text`, `Key`, `Image`, `Expanded`), `SelectedItem`, `Style`, `Indentation`, `Checkboxes`.
3. **ProgressBar (`MSComctlLib.ProgBar.2`)**
   - CLSID: `{35053A22-8589-11D1-B16A-00C0F0283628}`
   - Primary Interface: `IProgressBar` (`{35053A21-8589-11D1-B16A-00C0F0283628}`)
   - Events: `IProgressBarEvents` (`{35053A23-8589-11D1-B16A-00C0F0283628}`)
   - Core Features: `Value`, `Min`, `Max`, `Orientation`, `Scrolling`.
4. **Slider (`MSComctlLib.Slider.2`)**
   - CLSID: `{F08DF954-858E-11D1-B16A-00C0F0283628}`
   - Primary Interface: `ISlider` (`{F08DF953-858E-11D1-B16A-00C0F0283628}`)
   - Events: `ISliderEvents` (`{F08DF955-858E-11D1-B16A-00C0F0283628}`)
   - Core Features: `Value`, `Min`, `Max`, `SmallChange`, `LargeChange`, `TickStyle`, `Orientation`.
5. **StatusBar (`MSComctlLib.StatBar.2`)**
   - CLSID: `{8E3867A3-8586-11D1-B16A-00C0F0283628}`
   - Primary Interface: `IStatusBar` (`{8E3867A2-8586-11D1-B16A-00C0F0283628}`)
   - Events: `IStatusBarEvents` (`{8E3867A4-8586-11D1-B16A-00C0F0283628}`)
   - Core Features: `Panels`, `SimpleText`, `Style`.
6. **TabStrip (`MSComctlLib.TabStrip.2`)**
   - CLSID: `{1EFB6596-857C-11D1-B16A-00C0F0283628}`
   - Primary Interface: `ITabStrip` (`{1EFB6595-857C-11D1-B16A-00C0F0283628}`)
   - Events: `ITabStripEvents` (`{1EFB6597-857C-11D1-B16A-00C0F0283628}`)
   - Core Features: `Tabs`, `SelectedItem`, `MultiRow`, `Style`. (Distinct from FM20 TabStrip).
7. **Toolbar (`MSComctlLib.Toolbar.2`)**
   - CLSID: `{66833FE8-8583-11D1-B16A-00C0F0283628}`
   - Primary Interface: `IToolbar` (`{66833FE7-8583-11D1-B16A-00C0F0283628}`)
   - Events: `IToolbarEvents` (`{66833FE9-8583-11D1-B16A-00C0F0283628}`)
   - Core Features: `Buttons`, `ButtonMenus`, `ImageList`, `ShowTips`.
8. **ImageList (`MSComctlLib.ImageListCtrl.2`)**
   - CLSID: `{2C247F23-8591-11D1-B16A-00C0F0283628}`
   - Primary Interface: `IImageList` (`{2C247F22-8591-11D1-B16A-00C0F0283628}`)
   - Events: `IImageListEvents` (`{2C247F24-8591-11D1-B16A-00C0F0283628}`)
   - Core Features: `ListImages`, `ImageWidth`, `ImageHeight`, `Overlay`.
9. **ImageCombo (`MSComctlLib.ImageComboCtrl.2`)**
   - CLSID: `{A98A40C0-85C3-11D1-B16A-00C0F0283628}`
   - Primary Interface: `IImageCombo` (`{A98A40BF-85C3-11D1-B16A-00C0F0283628}`)
   - Events: `IImageComboEvents` (`{A98A40C1-85C3-11D1-B16A-00C0F0283628}`)
   - Core Features: `ComboItems`, `ImageList`, `SelectedItem`.

### 3.3 Microsoft Windows Common Controls-2 6.0 (`MSCOMCT2.OCX`)

| Attribute | Specification |
|---|---|
| **Primary Library** | `MSCOMCT2.OCX` |
| **Typelib Name** | `MSComCt2` |
| **Typelib GUID** | `{86CF1D34-0C5F-11D2-A9FC-0000F8754DA1}` |
| **Version** | 2.0 |
| **Bitness** | Historically 32-bit only |
| **Provenance** | Visual Basic 6.0 documentation; COM typelib metadata |

#### Controls in `MSComCt2`:

1. **DTPicker (DateTimePicker) (`MSComCt2.DTPicker.2`)**
   - CLSID: `{20DD94A8-A630-11D1-988F-00C04F687667}`
   - Primary Interface: `IDTPicker` (`{20DD94A7-A630-11D1-988F-00C04F687667}`)
   - Events: `IDTPickerEvents` (`{20DD94A9-A630-11D1-988F-00C04F687667}`)
   - Core Features: `Value`, `Format`, `CustomFormat`, `UpDown`, `CheckBox`, `MinDate`, `MaxDate`.
2. **MonthView (`MSComCt2.MonthView.2`)**
   - CLSID: `{232E456A-87C3-11D1-8BE3-0000F8754DA1}`
   - Primary Interface: `IMonthView` (`{232E4569-87C3-11D1-8BE3-0000F8754DA1}`)
   - Events: `IMonthViewEvents` (`{232E456B-87C3-11D1-8BE3-0000F8754DA1}`)
   - Core Features: `Value`, `SelStart`, `SelEnd`, `MultiSelect`, `ShowToday`, `ShowWeekNumbers`.
3. **UpDown (`MSComCt2.UpDown.2`)**
   - CLSID: `{603C7E80-87C2-11D1-8BE3-0000F8754DA1}`
   - Primary Interface: `IUpDown` (`{603C7E7F-87C2-11D1-8BE3-0000F8754DA1}`)
   - Events: `IUpDownEvents` (`{603C7E81-87C2-11D1-8BE3-0000F8754DA1}`)
   - Core Features: `BuddyControl`, `BuddyProperty`, `Value`, `Min`, `Max`, `Increment`, `SyncBuddy`.
4. **Animation (`MSComCt2.Animation.2`)**
   - CLSID: `{B09DE715-87C1-11D1-8BE3-0000F8754DA1}`
   - Primary Interface: `IAnimation` (`{B09DE714-87C1-11D1-8BE3-0000F8754DA1}`)
   - Events: `IAnimationEvents` (`{B09DE716-87C1-11D1-8BE3-0000F8754DA1}`)
   - Core Features: `Open`, `Play`, `Stop`, `Close`.
5. **FlatScrollBar (`MSComCt2.FlatScrollBar.2`)**
   - CLSID: `{38EE5CE1-4B62-11D1-AB2F-00C0F0283628}`
   - Primary Interface: `IFlatScrollBar` (`{38EE5CE0-4B62-11D1-AB2F-00C0F0283628}`)
   - Events: `IFlatScrollBarEvents` (`{38EE5CE2-4B62-11D1-AB2F-00C0F0283628}`)

### 3.4 Microsoft Rich Textbox Control 6.0 (`RICHTX32.OCX`)

| Attribute | Specification |
|---|---|
| **Primary Library** | `RICHTX32.OCX` |
| **Typelib Name** | `RichTextLib` |
| **Typelib GUID** | `{3B7C8863-D78F-101B-B9B5-04021C009402}` |
| **Version** | 1.2 |
| **Control Class** | `RICHTX32.RichTextBox.1` |
| **CLSID** | `{3B7C8860-D78F-101B-B9B5-04021C009402}` |
| **Primary Interface** | `IRichText` (`{3B7C8861-D78F-101B-B9B5-04021C009402}`) |
| **Event Interface** | `DIForControlEvents` (`{3B7C8862-D78F-101B-B9B5-04021C009402}`) |
| **Core Features** | `TextRTF`, `SelColor`, `SelFontName`, `SelFontSize`, `SelBold`, `SelItalic`, `SelUnderline`, `LoadFile`, `SaveFile` |

### 3.5 Microsoft Windows Common Controls 5.0 (`COMCTL32.OCX` / `COMCT232.OCX`)
Legacy 5.0 libraries share identical object-model semantics with their 6.0
successors, with minor differences in CLSIDs and typelib GUIDs
(`{6B7E6386-850A-101B-AFC0-4210102A8DA7}`). A host reference resolution mapping
allows projects referencing the 5.0 variants to bind to the same unified control
engine.

### 3.6 Other Microsoft Controls: Scoping & Classification

1. **Microsoft Office Web Components (OWC9 / OWC10 / OWC11)**
   - Includes Spreadsheet, Chart, and PivotTable ActiveX controls.
   - Classification: **Specialized Host Extension**. These are complex full-document
     components rather than standard form controls. They require their own dedicated
     DNA Calc integration worksets and are excluded from the general forms control scope.
2. **Microsoft Chart Control 6.0 (`MSCHART.OCX`)**
   - Typelib GUID: `{65E121D4-0C60-11D2-A9FC-0000F8754DA1}`.
   - Classification: Tracked for post-Common-Controls phase.
3. **Third-Party ActiveX Controls**
   - Strictly excluded from CalcForms scope.

---

## 4. Persistence Model & `.frm` / `.frx` Representation

Under [MS-OFORMS], controls embedded on a UserForm are serialized within the
compound file stream structure of the form.

1. **MorphDataControl Persistence**:
   - Section 3.3.1 of [MS-OFORMS] explicitly specifies the embedded `RefEdit`
     record in the `o` stream:
     - `ClassInfo.ExtraDataBlock.ClsID`:
       `{00024512-0000-0000-C000-000000000046}` (`RefEdit1`).
     - Properties (such as `Name`, `Position`, `Size`, `TabIndex`) follow standard
       MS-OFORMS descriptor rules.
2. **ActiveX Object Streams**:
   - Controls such as `ListView`, `TreeView`, and `DTPicker` persist their custom
     configuration (e.g. column headers, node lists, initial formats) into
     opaque binary streams (traditionally via `IPersistStreamInit` / `IPersistPropertyBag`).
   - CalcForms specifies a deterministic, clean-room binary parser/serializer for
     these streams in `calcvba-office` and `calcforms`, decoding structured
     properties directly into control state without invoking original OCX code.

---

## 5. Host Seams & Interaction Contracts

### 5.1 Excel RefEdit Host Seam
`RefEdit` requires bidirectional communication with the host spreadsheet engine:

```text
[User clicks RefEdit collapse button]
  -> CalcForms signals Host RefEdit Provider
  -> UserForm window transitions to collapsed floating bar
  -> Host enters interactive range-selection mode
  -> Mouse drag across spreadsheet cells generates range update events
  -> RefEdit.Text updates live with address string (e.g. "$A$1:$C$10")
[User presses Enter or clicks restore button]
  -> Host exits range-selection mode
  -> UserForm restores original window bounds and focus
  -> RefEdit raises Change and AfterUpdate events
```

Seam Contract:
- `IRefEditHostProvider`: Injected by the DNA Calc / Excel-compatible host.
- Headless test harness provides a mock provider capable of simulating cell
  selection and coordinate updates without running a live Excel application.

### 5.2 Common Controls Interaction Model
- Built on top of `calcforms-pal` and `UiEvent` pump.
- Keyboard navigation (e.g. arrow keys in `TreeView` and `ListView`, PgUp/PgDn,
  spacebar toggle in checkboxes) integrates into the standard CalcForms reducer.
- Rendered using retain-mode Scene primitives (rectangles, text runs, icons,
  lines) with no native Win32 `HWND` requirement for child controls.

---

## 6. Workset Roadmap: `W011_microsoft_controls_beyond_msforms`

The implementation of Microsoft-supplied controls beyond MSForms is organized
as a standalone workset (`W011`), staged in five sequential phases:

### Phase 1: COM Typelib Fact Extraction & Metadata Ledger
- Establish `W011` fact generator for `RefEdit`, `MSComctlLib`, and `MSComCt2`.
- Record full method, property, DISPID, and event signatures into deterministic
  JSON fact packs (parallel to `FM20_TYPELIB_FACT_SCHEMA.md`).
- Define exact facade symbol mappings in CalcVBA binder.

### Phase 2: Persistence & Export Fact Models
- Extend `.frm` / `.frx` parser to support non-FM20 control records.
- Implement [MS-OFORMS] 3.3.1 `RefEdit` stream parsing and test with real Excel
  export artifacts.
- Implement structured property stream decoders for `MSCOMCTL` and `MSCOMCT2`.

### Phase 3: RefEdit Seam & Mock Host Harness
- Implement `RefEdit` control facade and interaction logic in `calcforms`.
- Implement `IRefEditHostProvider` interface and mock test harness.
- Differential verification of range string formatting, relative/absolute
  syntax, and event ordering against Excel.

### Phase 4: Common Controls Implementation
- **Slice 4A**: `ProgressBar`, `Slider`, `StatusBar`. (Simple visual/interaction controls).
- **Slice 4B**: `DTPicker`, `MonthView`, `UpDown`. (Date selection and buddy controls).
- **Slice 4C**: `ListView`, `ImageList`, `ImageCombo`. (Complex multi-view item collections).
- **Slice 4D**: `TreeView`. (Hierarchical node collection and traversal).
- **Slice 4E**: `RichTextBox`. (RTF formatting and document stream load/save).

### Phase 5: Verification & Corpus Conformance
- Author a representative corpus of real-world VBA workbooks utilizing these
  controls.
- Validate compilation, binding, execution, and round-trip persistence under
  CalcVBA without original OCX binaries.
- Measure layout, geometry, and event dispatch parity against live or recorded
  oracles.

---

## 7. Acceptance Criteria

`oxforms-tst7` and the ensuing `W011` planning milestone are satisfied when:
1. Every Microsoft-supplied control commonly used in VBA UserForms is inventoried
   with exact typelib GUID, version, CLSID, ProgID, and interface IDs.
2. 32-bit and 64-bit architecture considerations and host dependencies are
   explicitly documented.
3. The clean-room implementation architecture ensures zero dependency on original
   OCX binaries.
4. A concrete workset and phased implementation roadmap (`W011`) is formally
   indexed in `docs/SPEC.md` and `docs/WORKSET_REGISTER.md`.
5. No implementation code or temporary scaffolding is introduced prematurely.
