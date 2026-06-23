# OxForms — VBA-Compatible Forms Library: Spec, Architecture & Work Plan

Status: draft v2 · Owner: OxForms · Last updated: 2026-06-21

A from-scratch, cross-platform reimplementation of the Microsoft Forms 2.0 object
library (`FM20.dll`, "MSForms") — the `UserForm` and its controls — with the main
runtime and control implementation written in VBA, run by OxVba, and backed by a
small Rust primitive kernel for windows, input, timers, clipboard, image decode, text
measurement, and raster drawing. Windows is the first target; the architecture is
cross-platform from day one (Linux desktop, web/WASM, macOS). The **runtime** is the
first deliverable; a **designer** is in scope and the architecture is shaped to support
it.

The VBA-first shape is intentional. OxForms is both a compatibility library and a
large, realistic compiler/runtime proving ground: object-heavy, event-driven,
layout-heavy, and render-loop-sensitive. If profiling later proves a subsystem must
move to Rust, the plan is to port that already-working subsystem behind stable
state/reducer/render contracts, not to abandon the VBA implementation strategy.

This document is the first top-level spec, architecture, and work plan for the
standalone OxForms repo. It records current grounding and will split into smaller
spec documents as implementation work begins.

---

## 1. Established facts we build on

These are settled and are treated as load-bearing assumptions, not open questions:

1. **MSForms controls are windowless and owner-drawn.** A `UserForm` is a single
   container window (Win32 class `ThunderDFrame`); the controls have no per-control
   `HWND` and are painted by MSForms onto the form surface. (Verified live: a form
   with 7 controls produced 0 control windows.) **Consequence:** we never wrap native
   OS widgets; we own one window + one canvas and draw the entire control tree
   ourselves. This is both the only route to fidelity and what makes the library
   portable — control logic is identical on every platform; only a thin canvas differs.

2. **MSForms owns its entire appearance vocabulary**, serialized in **[MS-OFORMS]**
   (Office Forms Binary File Format): `SpecialEffect` (flat/raised/sunken/etched/bump),
   `BorderStyle`, `BorderColor` as `OLE_COLOR` (incl. system-palette indices), with
   per-control defaults. MSForms interprets and paints these itself; nothing is
   delegated to an OS theme engine. Our renderer consumes exactly this vocabulary.

3. **The API surface is large but bounded and mechanically enumerable** from the
   `FM20.dll` type library and [MS-OFORMS].

---

## 2. Scope

### 2.1 In scope
- The MSForms object model: `UserForm`, `Controls`/`Control`, every intrinsic control,
  `Font`, `Picture`, `DataObject`, the event-argument objects, and the `fm*` enums.
- Loading/saving the **`.frm` / `.frx`** form format (VB6-compatible text + binary
  resources) — the canonical OxForms project representation.
- Runtime: layout, owner-draw rendering, hit-testing, focus/tab, keyboard routing,
  drag-drop, event dispatch into VBA code-behind, `Show` (modal/modeless).
- A platform abstraction layer (PAL) with a Windows backend first; Linux/web/macOS
  backends behind the same contract.
- (Later, same architecture) a **designer**: design surface, property grid, toolbox,
  code-behind stub generation.

### 2.2 Out of scope (explicitly)
- Wrapping native OS widgets or OS theming for control look.
- Hosting arbitrary third-party windowed ActiveX/OCX controls as first-class
  citizens. (We may *host* a windowed OCX as an opaque child later; we do not clone
  its internals. Not a v1 concern.)
- The Office document container (`.xlsx`/`.xlsm`, OPC, `vbaProject.bin`, the binary
  MS-OFORMS form storage). **That belongs to OxDoc** — see §7.
- `RefEdit` as an FM20 intrinsic. It lives in Excel-host territory rather than the
  Microsoft Forms 2.0 object library, so it is not part of the core MSForms parity
  claim. However, DNA Calc expects Excel-hosted `RefEdit` to be an early extension, so
  the architecture must keep a first-class extension-control seam ready for it (§4.7).

---

## 3. Decisions (locked)

| # | Decision | Rationale |
|---|---|---|
| D1 | **Single window + single canvas; owner-draw the whole control tree.** | Forced by fact §1.1; also the portability win. |
| D2 | **PAL = one canonical flat value-typed contract; OxVba binds it through injected host objects.** | Injected host objects are the current best OxVba integration: no `Declare` marshalling on the hot path, explicit host ownership, and clean runtime injection. Any future native-body or C-ABI binding must be a first-class adapter generated from the same contract, not a legacy or convenience-maintained alternate path. |
| D3 | **Purpose-built PAL — *not* a mirror of `IOleInPlaceSiteWindowless`, *not* GDI.** Take *inspiration* from both. | See §6.1. We own all controls, so we don't need the COM windowless-negotiation protocol; and GDI is Windows-only. We adopt the *concepts* (container lends a surface; GDI+/Canvas2D primitive vocabulary) without the baggage. |
| D4 | **`.frm`/`.frx` (VB6-compatible) is the canonical OxForms form format**, sitting beside `.bas`/`.cls` in OxForms projects and OxVba integration surfaces. | Human-readable, diffable, git-friendly; matches how OxVba already treats VBA source while letting OxForms own form-specific persistence. |
| D5 | **The binary MS-OFORMS form storage and the `.xlsm` container live in OxDoc**, which converts MS-OFORMS ⇄ `.frm`/`.frx`. The two repos meet at the `.frm`/`.frx` file. | OxDoc owns Office file formats; OxVba owns VBA source formats. Clean decoupling at the interchange file. |
| D6 | **Low-level binary processing is Rust:** image decode (`.frx`/Picture blobs) in the PAL; MS-OFORMS bit-mask parsing + MS-OVBA (de)compression in OxDoc. VBA never bit-twiddles binary. | Performance and correctness; keeps the VBA library platform-independent and simple. |
| D7 | **Reducer-driven state + display-list rendering with dirty-rect invalidation.** The VBA control tree emits a platform-neutral display list over an immediate-mode primitive vocabulary; retained scene caching is deferred until profiling demands it. | Keeps behavior deterministic and replayable, batches VBA→Rust rendering traffic, preserves a GDI-like authoring model, and creates a clean VM/JIT benchmark surface. |
| D8 | **One canonical reference renderer plus platform backends.** Prefer shared window/input and raster code where practical (`winit`, `tiny-skia`/`femtovg`/similar), but define backend tolerance profiles for text, DPI, antialiasing, and image differences. | Gives one fidelity target for tests without pretending every platform must use the identical production renderer. |
| D9 | **OxForms is a separate repo/library** (its own VBA bundle + native crates), integrated with OxVba as a sibling dependency rather than embedded inside the OxVba workspace. | Keeps forms ownership clear while preserving tight integration with the OxVba compiler/runtime. |
| D10 | **VBA-first implementation, Rust primitive kernel.** Controls, object model, layout, interaction, theme logic, and most rendering decisions live in VBA; Rust owns only primitive platform services and proven hot-path migrations. | This maximizes OxVba compiler/runtime learning while preserving an escape hatch for measured bottlenecks. |
| D11 | **Trace/replay is a first-class architecture constraint.** Normalized input events, reducer effects, invalidation decisions, display lists, and fired VBA events must be serializable enough for golden tests and differential comparison. | Makes compatibility bugs reproducible, turns OxForms into a benchmark corpus, and gives future JIT work realistic traces. |
| D12 | **Host extension controls are supported without polluting FM20 parity.** `RefEdit` is the motivating early extension: Excel-hosted, range-selection-aware, and outside the FM20 intrinsic set. | DNA Calc will need it early, but core OxForms must still keep a clean distinction between MSForms compatibility and host-specific controls. |

Everything below follows from D1–D12.

---

## 4. Architecture overview

```
┌───────────────────────────────────────────────────────────────────────┐
│  DESIGNER  (separate library, later)                                   │
│   design surface · property grid (typelib-driven) · toolbox · undo ·   │
│   code-behind stub gen      — reuses model + renderer + persistence     │
├───────────────────────────────────────────────────────────────────────┤
│  RUNTIME  (VBA, platform-independent)            crate/bundle: OxForms  │
│   L5 Persistence    .frm / .frx  ⇄  object model                       │
│   L4 Object model   UserForm, Controls, every control, Font/Picture,   │
│                     events, fm* enums                                   │
│   L3 Layout         positioning · AutoSize · Frame/MultiPage/TabStrip   │
│   L2 Render         FormState → LayoutTree → DisplayList + theme        │
│   L1 Interaction    hit-test · focus/tab · capture · drag-drop ·        │
│                     keyboard routing → reducer effects + VBA events     │
├───────────────────────────────────────────────────────────────────────┤
│  PAL CONTRACT  (canonical, flat, value-typed; adapter-bound)           │
│   window · display-list renderer · text metrics · input · timers ·     │
│   clipboard · system colors/metrics · image decode                     │
├───────────────────────────────────────────────────────────────────────┤
│  PAL BACKENDS  (Rust)             crate: oxforms-pal (+ per-platform)   │
│   Windows: winit + tiny-skia (opt. Direct2D)   Linux: winit + skia     │
│   Web/WASM: canvas2d / WebGPU                  macOS: winit + skia/CG   │
└───────────────────────────────────────────────────────────────────────┘

Interchange with the Office world (separate repo):
   OxForms  ⇄  .frm/.frx  ⇄  OxDoc  ⇄  vbaProject.bin (MS-OFORMS)  ⇄  .xlsm
```

L1-L5 are the OxForms VBA library, written once and intended to run everywhere.
The PAL contract is small, primitive, and canonical (§6). Runtime-specific
adapters expose that one contract to their host environment; they are not
retained alternate routes.

### 4.1 Proposed workspace layout (provisional names)
- **`OxForms` VBA bundle** — the runtime library (L1–L5) as VBA source (`.cls`/`.bas`),
  packaged as an internal referenced library like `oxvba-lib`. It obtains primitive
  PAL services through host-injected objects supplied by runtime-specific adapter
  crates. Those PAL members stay flat and value-typed because that makes them
  testable, replayable, optimizable, and suitable for first-class alternate adapters
  if a future host needs one. No alternate binding exists by default or remains for
  convenience; if it is not the best long-term architecture, it must not stay in the
  implementation path. Everything else is VBA unless profiling and evidence justify
  a later Rust migration.
- **`oxforms-core`** (Rust) — host-neutral reducer/model reference and test-spine
  contracts used by W005 and future replay/golden checks. This crate may consume
  `oxforms-pal` value types such as normalized input and coordinates, but it is not
  the primary VBA runtime implementation and does not make the PAL responsible for
  control behavior. Any future Rust hot-path migration must still satisfy the
  VBA-first migration rule in section 4.6.
- **`oxforms-pal`** (Rust) — the host/runtime-independent PAL core: contract types,
  display-list renderer, reference/headless renderer, shared backend traits, and any
  future first-class native surface derived from the same canonical contract. It must
  not depend on OxVba or any host runtime, and it does not own reducer/control
  behavior.
- **`oxforms-oxvba-adapter`** (Rust) — the OxVba-specific injected-object adapter. It
  owns `PortableDispatch`/`Variant` marshalling, `CreateObject`/projection registration,
  and maps OxForms VBA calls onto the typed `oxforms-pal` core contract.
- **`oxforms-pal-*`** (Rust, feature-gated or per-crate) — platform backends (win, x11/
  wayland, wasm, mac).
- `.frm`/`.frx` parsing is owned by OxForms and exposed to OxVba project loading through
  an explicit integration seam (beside `.vbp`/`.bas`/`.cls`).

Designer components are added later as a parallel VBA bundle + (if needed) a designer
PAL extension; no runtime decision blocks them.

### 4.2 VBA-first implementation contract
The main implementation layers are deliberately VBA:

- controls and supporting objects (`UserForm`, `Control`, `Controls`, `Font`,
  `Picture`, `DataObject`, event-argument objects);
- property storage, coercion, default-member behavior, and collection semantics;
- layout, z-order, hit-testing, focus, keyboard routing, validation, capture, and
  drag/drop policy;
- theme selection and the generation of render commands.

Rust is the primitive kernel:

- window creation/lifetime, platform input, timers, clipboard, cursor, DPI, system
  colors/metrics, image decode, and text measurement;
- display-list execution against the active raster backend;
- optional headless/reference rendering for tests;
- later hot-path replacements only when the migration rule in §4.6 is satisfied.

This is a strategic risk, and the plan treats it as such. The payoff is that OxForms
becomes a large and realistic workload for OxVba: many classes, default members,
events, collections, `WithEvents`-style routing, modal loops, string-heavy property
logic, and render-loop-sensitive code. That workload should improve the compiler, VM,
runtime object model, profiler, and future Cranelift JIT.

### 4.3 Reducer state model
Internally, the runtime should be shaped as a deterministic state machine:

```
FormState + UiEvent -> FormState + Effects + RenderInvalidation
```

- `FormState` is the complete logical state of the form and controls: control tree,
  z-order, focus, capture, values, selection, scroll state, validation state, layout
  cache keys, and visual state.
- `UiEvent` is a normalized platform-independent event: mouse, keyboard, character
  input, timer, clipboard, drag/drop, close request, DPI change, focus change.
- `Effects` are explicit side effects requested by the reducer: fire a VBA event, set
  clipboard, start/stop a timer, capture/release mouse, close/hide/unload a form,
  request repaint, or ask the PAL for a service result.
- `RenderInvalidation` is a precise dirty region or dirty subtree set.

The reducer does not paint directly and does not call platform APIs directly. It
computes state transitions and effect requests. The host/PAL adapter performs effects,
then feeds resulting events or service results back into the reducer. This gives
deterministic replay, minimizes hidden reentrancy, and leaves a clean seam for future
Rust ports of proven hot reducers.

### 4.4 Rendering architecture: display lists
The render path should be:

```
FormState -> LayoutTree -> DisplayList -> PAL renderer
```

The display list is platform-neutral and serializable enough for tests. It should
contain commands such as:

- push/pop clip;
- fill/stroke rect, line, ellipse, polygon;
- draw MSForms edge/effect primitives;
- draw text with resolved font, alignment, clipping, accelerator underline, disabled
  state, and measured/cached metrics;
- draw image with source/destination rectangles and picture-position mode;
- optional debug overlay commands for layout, focus, hit-test, invalidation, and
  event routing diagnostics.

Controls may be authored with an immediate-mode mental model, but the boundary to Rust
is a batched display list rather than a long stream of fine-grained VBA-to-Rust calls.
Benefits:

- fewer host calls during paint;
- stable golden artifacts for render tests;
- headless screenshot generation without a real window;
- easier backend optimization and caching;
- a realistic benchmark stream for VM/JIT work.

### 4.5 Trace, replay, and evidence architecture
OxForms should treat trace/replay as a product feature for developers and as evidence
infrastructure for compatibility work. A test run should be able to record:

- normalized input events;
- reducer state transition summaries;
- effects requested and effects completed;
- fired VBA event names, order, and arguments;
- invalidated rectangles/subtrees;
- emitted display-list commands;
- optional rendered image hashes or screenshots.

The same event script should be runnable against real MSForms on Windows and against
OxForms. Differences become structured artifacts: event-order diffs, property
round-trip diffs, render/pixel/SSIM diffs, and state/log diffs. This turns the forms
runtime into a durable compatibility corpus and a performance corpus.

### 4.6 Hot-path migration rule
All runtime behavior starts in VBA unless it is impossible or clearly unsuitable there.
A subsystem may move to Rust only after:

1. it has a passing VBA implementation;
2. it has conformance tests or differential evidence;
3. profiling identifies it as a material bottleneck or correctness risk;
4. the Rust replacement preserves the same reducer/display-list/effects contract.

Migration is therefore a controlled optimization, not a planning shortcut.

### 4.7 Host extension controls and Excel `RefEdit`
OxForms must support extension controls that are not FM20 intrinsics while keeping the
core parity claim clean. The first expected extension is Excel-hosted `RefEdit`.

RefEdit readiness means the architecture must provide:

- **Extension registration.** A host or referenced library can register a control class
  with name, ProgID/GUID/type identity where applicable, public members, events,
  persistence identity, default property behavior, and a factory that creates the
  control's reducer state.
- **Shared control substrate.** Extension controls participate in the same control tree,
  layout, z-order, tab/focus, event, invalidation, display-list, trace/replay, and
  designer-property-grid mechanisms as intrinsic controls.
- **Host capability binding.** Host-specific behavior is expressed as explicit
  capability services, not as ad hoc calls hidden inside the control. For Excel RefEdit,
  the expected capability is an Excel range-selection service that can begin selection
  mode, observe selection changes, format/parse references, commit/cancel selection, and
  return either a reference string or a host `Range` object when the host supports it.
- **Graceful non-Excel behavior.** Outside an Excel-capable host, RefEdit must fail
  deterministically with a capability diagnostic or degrade to a documented text-entry
  subset. It must not pretend to provide Excel range-picking semantics.
- **Persistence preservation.** `.frm`/`.frx` loading must preserve unknown or
  host-specific control identities and properties, even before the extension is
  implemented. Once the Excel extension is registered, those preserved identities should
  instantiate the RefEdit control rather than being flattened into a generic control.
- **No core dependency on Excel.** Core OxForms may know that extension controls exist,
  but the Excel object model, `Range` identity, workbook/window activation, selection
  semantics, and host-specific validation live in an Excel extension layer.

RefEdit should be implemented as an `OxForms.ExcelControls`-style extension bundle plus
host services, not as an FM20 intrinsic. Its visible surface can reuse TextBox-like
editing, border/theme drawing, focus, validation, and display-list commands from core
OxForms; the hard part is the host range-selection lifecycle. That lifecycle should be
replayable in tests through synthetic host-selection events, and differentially checked
against real Excel where automation is available.

---

## 5. Object model (L4) — scope & capture

### 5.1 Control taxonomy
Intrinsic controls to implement (the `FM20.dll` set):

- **Containers / parents:** `UserForm` (the form), `Frame`, `MultiPage` (+ `Page`,
  `Pages`), `TabStrip` (+ `Tab`, `Tabs`).
- **Data / morph controls:** `TextBox`, `ComboBox`, `ListBox`, `CheckBox`,
  `OptionButton`, `ToggleButton`. (In [MS-OFORMS] these six share one serialization,
  **MorphData**, discriminated by a morph type — one persistence codec covers all six;
  see §7.3.)
- **Simple controls:** `Label`, `CommandButton`, `Image`, `ScrollBar`, `SpinButton`.

Supporting objects: `Controls` collection + `Control`, `Font`/`IFontDisp`,
`Picture`/`IPictureDisp`, `DataObject` (clipboard / drag payload), and the by-ref
event-arg objects (`ReturnBoolean`, `ReturnInteger`, `ReturnSingle`, `ReturnString`,
`ReturnEffect`).

### 5.2 Shared property bands (most controls)
`Name`, `Value`/`Caption`/`Text`, `Left`/`Top`/`Width`/`Height`, `Visible`, `Enabled`,
`Locked`, `TabIndex`, `TabStop`, `ControlTipText`, `Tag`, `BackColor`, `ForeColor`,
`BorderColor`, `BorderStyle`, `SpecialEffect`, `Font`, `MousePointer`/`MouseIcon`,
`Picture`/`PicturePosition`. Plus control-specific bands (list `Column*`/`BoundColumn`/
`ColumnHeads`/`ListStyle`/`MultiSelect`, text `MaxLength`/`PasswordChar`/`MultiLine`/
`AutoSize`/`WordWrap`, etc.).

### 5.3 Event bands
Control: `Click`, `DblClick`, `Change`, `Enter`, `Exit`, `KeyDown`/`KeyUp`/`KeyPress`,
`MouseDown`/`MouseUp`/`MouseMove`, `BeforeUpdate`, `AfterUpdate`, `Error`, `DropButtonClick`,
`SpinUp`/`SpinDown`, etc. Form adds: `Initialize`, `Activate`/`Deactivate`, `Resize`,
`QueryClose`, `Terminate`, `Layout`, `Scroll`, `Zoom`, `AddControl`/`RemoveControl`,
`BeforeDragOver`, `BeforeDropOrPaste`.

### 5.4 Capture method (the "full scope into docs" deliverable)
Do not hand-transcribe. Two mechanical sources:
1. **`FM20.dll` type-library dump** (OxVba already has deep typelib introspection):
   emit every coclass/interface/dispid/property/method/event with exact signatures.
   This file *is* the API reference and doubles as a conformance checklist.
2. **[MS-OFORMS]** (now mirrored in Foundation, §11): the exact serialized properties,
   per-control defaults, and enum values.

Behaviors the typelib does not capture must be documented from observation/spec:
focus→validate→exit ordering (`Enter` → … → `BeforeUpdate` → `AfterUpdate` → `Exit`),
`Value` coercion per control, default-member semantics (`TextBox1` ≡ `.Value`/`.Text`),
`AutoSize`/`WordWrap`, list column/bound-column semantics, `MultiSelect` rules.

### 5.5 Generated fact pack
The capture deliverable is a generated **OxForms fact pack**, not only narrative
documentation. It should include:

- FM20 typelib surface: coclasses, interfaces, DISPIDs, properties, methods, events,
  signatures, enum values, default members, source interfaces, and documentation strings
  where available.
- MS-OFORMS persistence surface: per-control serialized fields, defaults, enum mappings,
  bit flags, MorphData common fields, picture/resource references, and unsupported or
  unknown fields.
- Behavior observation matrix: event order, focus/validation transitions, default-member
  behavior, value coercions, list/multi-select semantics, text-editing semantics, modal
  lifecycle, and close/unload behavior.
- Generated implementation scaffolds: VBA interface/facade declarations, Rust PAL enum
  and command definitions, conformance checklist rows, and baseline test fixture names.
- Extension-control seed rows: non-FM20 control identity preservation, extension
  registration shape, and the Excel `RefEdit` host-capability requirements that must not
  contaminate the core FM20 parity matrix.
- Evidence manifest: source document paths, hashes, tool versions, generation commands,
  and output paths.

The fact pack is the source for planning breadth and tracking parity. Hand-written docs
may summarize it, but completion claims should point to generated rows and test/evidence
anchors rather than broad prose.

### 5.6 Grounded appearance data (from [MS-OFORMS], for L2)
`fmSpecialEffect`: Flat `0x00`, Raised `0x01`, Sunken `0x02`, Etched `0x03`, Bump `0x06`.
`fmBorderStyle`: None `0x00`, Single `0x01`.
`SpecialEffect` defaults: morph controls (CheckBox/ComboBox/ListBox/OptionButton/
TextBox/ToggleButton) = `0x02` Sunken (ToggleButton MUST be `0x02`); Form/Label/Image =
`0x00` Flat. `BorderStyle` defaults: ComboBox/Form/Label/ListBox/TextBox = None; Image =
Single. `BorderColor`: `OLE_COLOR`; default `0x80000006` (COLOR_WINDOWFRAME) for most,
`0x80000012` (COLOR_BTNTEXT) for Form. The `0x80000000` high bit = system-color index —
**the PAL must resolve these per platform** (§6.3).

---

## 6. The PAL (Platform Abstraction Layer)

### 6.1 Backend philosophy — the explicit answer

**Q: How closely should the backend follow `IOleInPlaceSiteWindowless`, or GDI, or be
purpose-built?** → **Purpose-built, taking inspiration from both, binding to neither.**

- **Not `IOleInPlaceSiteWindowless`.** That interface is a COM *container-negotiation
  protocol* whose entire reason for existing is to host *arbitrary third-party*
  windowless ActiveX controls (capture/focus/DC arbitration, `AdjustRect`,
  `CanWindowlessActivate`, message marshalling, HRESULT/IDispatch). We author every
  control ourselves, so there is no third party to negotiate with — adopting that
  surface would import COM and Windows-isms that do not translate to Linux/web/macOS,
  for zero benefit. We keep only its *concept*: the container owns the window and lends
  the controls a surface, input, capture, and focus.
- **Not GDI (as the API).** GDI is Windows-only and awkwardly stateful (selected
  objects, DC ownership). We will not bind the contract to it.
- **What we take from GDI/GDI+.** The *primitive vocabulary* and the *coordinate/color
  model*, because the data we must render is already expressed in those terms:
  `.frm`/[MS-OFORMS] use `OLE_COLOR`, point/twips geometry, pen/brush fills, and 3D edge
  effects (`SpecialEffect` raised/sunken/etched/bump map almost 1:1 onto GDI
  `DrawEdge`/`BDR_*`). A GDI+/Canvas2D-flavored immediate-mode API maps cleanly onto
  what we must draw **and** onto every real backend (Direct2D, Skia, Cairo, Canvas2D,
  CoreGraphics all implement that same model). It is the portable lowest common
  denominator.

Net: a small, flat, GDI+/Canvas2D-shaped primitive vocabulary. Because the surface
is value types rather than host-object internals, runtime-specific adapters can
project the same canonical contract without inventing separate drawing APIs. The
normal paint path batches those primitives into a display list; the contract remains
immediate-mode-shaped so VBA control authors can reason about drawing simply.

### 6.2 Contract surface
- **Window:** create/destroy; set caption/icon/size/position; show/hide; modal-run /
  modeless; min/max/close; DPI/scale query; `invalidate(rect)`; close-requested signal.
- **Display-list renderer:** submit one or more serialized render command batches;
  render batches into a window surface or headless target; return optional render
  diagnostics/hash metadata for tests.
- **Drawing primitives:** clip push/pop; fill/stroke rect, round-rect, ellipse, line,
  polygon; gradient/pattern fills; `draw_text(font, align, wrap, clip)`;
  `draw_image(handle, src, dst, mode)`; a `draw_edge(rect, effect, border)` helper for
  the MSForms 3D looks (composed from primitives).
- **Text metrics:** measure string; font ascent/descent/line-height; caret hit-testing
  (offset↔x); font enumeration; DPI-aware metric cache keys.
- **Input (pushed to L1):** mouse move/down/up/dblclick/wheel; key down/up/char; focus
  in/out; resize; DPI-changed. The backend normalizes platform messages before passing
  them to the VBA reducer.
- **Services:** timers (caret blink, auto-repeat); clipboard get/set incl. `DataObject`
  formats; cursor shapes; **system colors & metrics**; **image decode** (BMP/GIF/PNG/ICO
  from `.frx`/Picture blobs → opaque image handle).
- **Host extension services:** capability-discovered services that are not part of the
  portable PAL. Excel RefEdit uses this for range-selection mode, selection updates,
  reference formatting/parsing, and optional host `Range` object return. These services
  are injected by the host/extension layer, not by core OxForms.
- **Trace support:** optional capture of input events, effect completions, render command
  batches, timing counters, and image hashes for replay and differential tests.

### 6.3 Notes
- System-color resolution (`0x80000000`-flagged `OLE_COLOR`) is a PAL service: each
  backend maps the indices to its platform palette (Windows system colors; sensible
  fixed/derived equivalents elsewhere). The "classic MSForms look" ships as the default
  theme; alternate themes are possible later without touching L1/L4/L5.
- Image *handles* are opaque PAL tokens; the VBA side never sees pixels. Decode is Rust
  (D6).

---

## 7. File formats & the OxForms ⇄ OxDoc split

### 7.1 Canonical: `.frm` / `.frx` (OxForms)
`.frm` is text: a `VERSION` header, a `Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F}
FormName … End` block of form + nested-control properties, then `Attribute VB_Name`,
then code-behind. Binary blobs (`Picture`, `MouseIcon`, list data) are offset references
into the companion binary **`.frx`** (`"Form.frx":0000`). Parsing/serialization extends
OxForms first, then plugs into OxVba project loading beside `.vbp`/`.bas`/`.cls`.
The `.frx` *structure* (offsets/records) is parsed in VBA/Rust per D6; the *image
bytes* are handed to the PAL to decode.

### 7.2 In-document binary: MS-OFORMS (OxDoc)
Inside `.xlsm`, forms live in `vbaProject.bin` (a CFBF compound file, **[MS-OVBA]**) as
designer storages using the **[MS-OFORMS]** binary format (the `f`/Form stream =
form + control "sites"; the `o`/Object stream = per-control property blobs in site
order; `\x03VBFrame` = textual designer attrs; `\x01CompObj`). **This is OxDoc's
domain.** OxDoc converts MS-OFORMS ⇄ `.frm`/`.frx`. OxForms and OxVba integration
consume `.frm`/`.frx`, exactly as OxVba consumes `.bas`/`.cls` today.

OxDoc currently implements `.xlsx` (no macros). MS-OFORMS + `vbaProject.bin` are
**future OxDoc scope**; until then OxForms develops against `.frm`/`.frx` directly,
which is the right canonical starting point regardless.

### 7.3 The interchange contract
The boundary file is `.frm`/`.frx`. Neither repo depends on the other's internals.
- One implementation insight worth banking now: the six **morph** controls share a
  single MS-OFORMS structure (MorphData) — so OxDoc needs *one* morph codec, not six.
- **Round-trip caveat:** `.frm`/`.frx` is the VB6 text export and may not capture every
  byte of an Office-authored MS-OFORMS stream. For byte-exact `.xlsm` round-trips, OxDoc
  keeps a provenance sidecar of any unmapped bytes (consistent with its existing
  "round-trip preservation of unmodeled OOXML parts" policy). OxForms is unaffected.

---

## 8. Rendering & input model (L2/L1)
- **Reducer + dirty-rect (D7).** A normalized input event enters the reducer, which
  updates `FormState`, emits explicit effects, and marks dirty rects/subtrees. Rendering
  consumes the resulting state snapshot; platform calls happen only through effects and
  PAL services.
- **Display-list rendering.** L2 emits a platform-neutral display list for the dirty
  region. The PAL renderer executes the batch on the active backend or a headless test
  target. Controls may be authored in a simple immediate-mode style, but the cross-boundary
  artifact is batched and replayable.
- **Theme as data.** Each control's look (the BackColor/ForeColor × SpecialEffect ×
  BorderStyle states, focus rect, pressed/disabled) is a small set of draw routines
  parameterized by a theme table built on PAL primitives + `draw_edge`. "Classic
  MSForms" is the default theme.
- **Input router (L1)** owns the hard logic: hit-test the tree, mouse capture during
  drags, Tab/Shift-Tab order, accelerator keys (`&Caption`), default/cancel buttons, the
  focus→validate→exit event chain, and drag-drop (`BeforeDragOver`/`BeforeDropOrPaste` +
  `DataObject`).
- **Replay discipline.** Every input script should be replayable against the same
  reducer/display-list path without a live desktop. This is required for golden tests,
  performance work, and cross-platform confidence.
- **Host-extension input.** Host-specific controls such as Excel RefEdit receive
  host-originated events through the same reducer/effects queue. For RefEdit, workbook
  selection updates, commit, cancel, and focus-restoration events must be modeled as
  normalized host-selection events so they can be replayed without live Excel.

---

## 9. Runtime integration with the OxVba VM
This is what turns the library into "a `UserForm` you can `.Show`":
- **A `UserForm` is a class module** whose implicit base is the OxForms `UserForm` type;
  designer-declared controls become **auto-instantiated typed members** (`Me.CommandButton1`),
  and `Sub CommandButton1_Click()` is wired as an event handler. The binder /
  `oxvba-symbol` must surface these control members and event-proc signatures — the main
  integration touchpoint, analogous to existing `WithEvents` sink wiring.
- **Form modules must be first-class project modules.** `.frm` ingestion must materialize
  `ModuleKind::Form`, preserve the code-behind module identity, and expose the form's
  default instance (`UserForm1`) through the same predeclared-instance machinery used for
  document/class modules.
- **`Show` modal vs modeless** cooperates with the VM event model: modal runs a nested
  pump (PAL `modal-run`) that still services `DoEvents` and dispatches events back into
  VBA; modeless returns immediately and integrates with the host idle loop. The VM's
  existing event-delivery/agile-sink spine is reused.
- **Event maturity assumption.** OxForms should reuse the existing project/runtime event
  spine as the expected path. If a forms slice exposes a missing event-runtime behavior,
  that is a runtime closure task to fix in OxVba, not a reason to fork a separate event
  mechanism for forms.
- **Extension controls resolve through the same symbol path.** Excel RefEdit should appear
  to VBA as a registered control type/member surface supplied by an Excel controls
  extension reference or host catalog. The binder should not need hardcoded RefEdit
  syntax; it should consume generated/registered metadata just as it does for intrinsic
  controls and host-provided object-model surfaces.
- **Packaging:** OxForms is delivered as an internal referenced VBA library bundle (the
  `oxvba-lib` model), so `MSForms`/`UserForm` resolve like any reference.

---

## 10. Cross-platform & testing

### 10.1 Platforms
Because L1–L5 are platform-independent VBA, porting = writing a PAL backend, not
porting the library: **Windows** (first, the fidelity oracle) → **Linux** →
**Web/WASM** (canvas2d/WebGPU; dovetails with existing web-host work) → **macOS**.
The architecture should prefer one canonical headless/reference renderer plus backend
tolerance profiles, especially for text metrics, DPI rounding, antialiasing, and image
decode differences.

### 10.2 Fidelity strategy (reuse OxVba's differential culture)
- **Typelib conformance:** the §5.4 dump is a checklist — assert every member/signature.
- **Differential vs real MSForms (Windows):** OxVba can drive Office over COM —
  instantiate the real `UserForm` and ours from the same `.frm`, then diff (a)
  screenshots (pixel/SSIM), (b) event logs under identical input scripts (order + args),
  (c) property round-trips.
- **Format round-trip:** `.frm`/`.frx` (and later MS-OFORMS in OxDoc) load→save→load
  byte-stable (golden artifacts).
- **Corpus:** harvest real `.frm` files (and forms inside `.xlsm`) as a load-and-render
  corpus.
- **Trace/replay:** record normalized input scripts, reducer effects, fired VBA events,
  invalidations, display lists, and image hashes. These traces become both regression
  artifacts and VM/JIT benchmark inputs.
- **Performance gates:** every broad phase should record at least one benchmark trace:
  cold form load, first paint, common input path, text editing, list scrolling, and
  modal/modeless event dispatch. Performance data guides JIT work and any hot-path Rust
  migrations.
- **Host extension coverage:** keep a separate matrix for extension controls. Excel
  RefEdit coverage should include deterministic non-Excel capability-diagnostic tests,
  synthetic range-selection replay tests, and optional live Excel differential tests.

---

## 11. Work plan

Phased; each phase names the artifact it produces. A vertical slice precedes breadth,
but the vertical slice must include form-module materialization and evidence capture
rather than only a visual smoke test.

- **W002 bootstrap slice — Initial Windows PAL rectangle smoke.** Before claiming P1
  breadth, land a tiny executable proof that VBA-authored drawing can cross the PAL seam
  in the intended ownership direction: a VBA app project references the OxForms VBA
  library, creates a smoke-only OxForms form-like object, and the library creates the
  host-injected `OxForms.SmokeCanvas`, calls `FillRect` and `Flush`. Rust records/renders
  the display-list command headlessly with stable diagnostics, and a Windows visible smoke
  path paints the same command. This is intentionally smoke-only: it does not claim
  `.frm`, `UserForm.Show`, intrinsic controls, input, or MSForms parity. *Artifact:
  rectangle display-list smoke with headless evidence and Windows plumbing notes; see
  [`worksets/W002_initial_windows_rectangle.md`](worksets/W002_initial_windows_rectangle.md).*

- **P0 — Fact pack + evidence scaffold.** Generate the FM20 typelib reference, the
  MS-OFORMS property/enum/default matrix, event signature matrix, persistence matrix,
  behavior-observation backlog, and evidence manifest (§5.5). Add the first Office/MSForms
  oracle harness shape for properties, event order, and screenshots. *Artifact: generated
  OxForms fact pack + oracle harness skeleton.*
- **P1 — PAL primitive kernel + Windows backend.** Define `oxforms-pal`; blank
  `UserForm` window (`winit` + `tiny-skia`/chosen rasterizer), normalized input events,
  timers, clipboard, text metrics, image decode handles, display-list renderer, headless
  reference renderer, modal loop, close. *Artifact: PAL primitive kernel + "hello form"
  smoke + headless render smoke.*
- **P1.5 — Form-module integration.** Accept `.frm` as `ModuleKind::Form`; parse the minimal
  designer block; preserve code-behind identity; materialize the form default instance;
  generate designer-declared typed control members; wire handler names such as
  `CommandButton1_Click`. *Artifact: a form module compiles and exposes its default
  instance and control members before full rendering breadth.*
- **P2 — Reducer vertical slice.** `Label` + `CommandButton` + `TextBox` end-to-end in
  VBA: properties → reducer state → layout → display list → owner-draw → effects →
  events → `.Show`. Include modal/modeless basics, focus, click, change, keyboard input,
  trace/replay, and golden display-list tests. *Artifact: working 3-control form from
  a `.frm`, with replayable event/render evidence.*
- **P2.5 — Extension-control seam + RefEdit readiness.** Add extension-control
  registration, unknown-control preservation, host-capability diagnostics, synthetic
  host-selection events, and a non-Excel capability-diagnostic fixture. Add an Excel
  RefEdit design spike that proves the core architecture can host a TextBox-like control
  with external range-selection effects without hardcoding Excel into FM20 OxForms. *Artifact:
  extension-control harness + RefEdit readiness notes/tests.*
- **P3 — Persistence.** Full `.frm`/`.frx` load/save into the model; resource offsets;
  image handles; unknown-field preservation strategy; corpus load/render tests.
  *Artifact: OxForms `.frm`/`.frx` codec + OxVba integration seam +
  byte-stability/golden corpus checks.*
- **P4 — Control breadth.** All remaining controls, with morph group first because one
  codec covers six controls. Each group lands with property/default rows, event rows,
  reducer tests, display-list goldens, and at least one differential trace where possible.
- **P5 — Fidelity hardening.** Differential tests (§10.2), event ordering, focus and
  validation edge cases, text editing, list semantics, DPI/text metrics, image fidelity,
  modal lifecycle, and close/unload behavior.
- **P6 — Performance and VM/JIT pressure.** Record benchmark traces for load, layout,
  first paint, text editing, list scrolling, event dispatch, and repaint. Use them to
  improve the VM and future JIT; migrate only proven hot paths under §4.6.
- **P7 — Other platforms.** Linux → web → macOS PAL backends, using the same reducer,
  display-list, trace/replay, and headless reference-renderer evidence.
- **P8 — Designer.** Design surface, property grid (typelib-driven), toolbox,
  code-behind stub gen — on top of the existing model/renderer/persistence.
- **(parallel) OxDoc MS-OFORMS.** When OxDoc adds `.xlsm`/`vbaProject.bin`, implement the
  MS-OFORMS ⇄ `.frm`/`.frx` codec there (D5); unblocks round-tripping Office documents.

---

## 12. Open questions / deferred
- Exact MS-OFORMS representation of `MultiPage`/`Page`/`Pages` vs `TabStrip` (confirm
  from the DOCX during P0).
- How much of the `.frx`/`.frm` record parsing is VBA vs a Rust helper in `oxforms-pal`
  (D6 says image *decode* is Rust; the record/offset framing could go either way —
  decide in P3 by complexity).
- Exact serialized shape for trace/replay artifacts: likely `.jsonl` for event/effect
  logs plus binary/PNG artifacts for render outputs.
- Display-list binary/text representation and versioning: must be stable enough for
  golden tests while still easy to evolve during early implementation.
- Exact text stack: rasterizer-native text, DirectWrite/CoreText/platform text, or a
  cross-platform text shaping crate if basic metrics are not enough for fidelity.
- Which event-runtime gaps, if any, the first form slices expose; expected resolution is
  to close the shared OxVba event path, not to introduce a forms-only event model.
- Exact Excel RefEdit return/value semantics to support first: reference string only,
  host `Range` object, or both, and how that varies by property/member and host context.
- Excel RefEdit selection lifecycle details: interaction with modal forms, Excel window
  activation, workbook/sheet switching, cancel/escape behavior, and focus restoration.
- How `.frm`/`.frx` exports identify RefEdit and other host/third-party controls, and
  which unknown fields must be preserved before an extension implementation exists.
- Whether the designer warrants its own PAL extension (extra surface for rubber-band
  selection, snapping overlays) or composes from existing primitives (lean: compose).
- Future extraction of OxForms into its own sibling repo (when the boundary stabilizes).

---

## 13. References
- **OxForms source-reference map:** [`SOURCE_REFERENCES.md`](SOURCE_REFERENCES.md)
  records the current Foundation mirror paths/hashes and the OxVba pinned baseline
  policy.
- **[MS-OFORMS]** Office Forms Binary File Formats (rev 9.1, 2025-08-19) — mirrored in
  Foundation. Paths below are relative to the OxForms repo root:
  - `../Foundation/reference/downloads/officeprotocoldocs-f5hpbjgea6b8gneq.b02.azurefd.net/files/MS-OFORMS/[MS-OFORMS]-250819.docx`
  - `../Foundation/reference/downloads/officeprotocoldocs-f5hpbjgea6b8gneq.b02.azurefd.net/files/MS-OFORMS/[MS-OFORMS].pdf`
  - Online TOC: https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-oforms/
- **[MS-OVBA]** Office VBA File Format Structure (VBA project / `vbaProject.bin`) — see
  `SOURCE_REFERENCES.md`; OxDoc owns in-document binary storage and OxForms meets it
  at `.frm` / `.frx`.
- **`FM20.dll`** — Microsoft Forms 2.0 Object Library (the type-library ground truth for
  the object model).
- Existing OxVba evidence seeds:
  - `../OxVba/docs/evidence/language/MS_VBAL_MODULE_PROJECT_REQUIREMENTS.csv` row
    `MODPROJ-030` tracks form-module/userform integration as planned forms scope.
  - `../OxVba/docs/evidence/typelib_audit/registered_typelib_safearray_elements_20260620T152846/typelib_audit.csv`
    includes a live Microsoft Forms 2.0 Object Library audit summary.
- Windowless ActiveX background (concept only; we do not implement it):
  `IOleInPlaceSiteWindowless` / `IOleInPlaceObjectWindowless` / `IPointerInactive`.
- Sibling repos: **OxDoc** (`../OxDoc`) owns `.xlsx`/`.xlsm`; OxForms ⇄ OxDoc meet at
  `.frm`/`.frx`.
