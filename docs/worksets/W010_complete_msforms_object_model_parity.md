# W010 — Complete MSForms Object-Model Parity

Status: `IN PROGRESS`

Epic: `oxforms-jbjp`

Depends on:

- `W008_native_event_breadth` (`CLOSED` — representative native event and
  mutable-argument path);
- `W009_intrinsic_control_breadth` (`CLOSED` — all intrinsic categories have a
  representative factory/runtime lane, explicitly only at subset depth).

## Purpose

W010 turns the broad W009 runtime into a mechanically checked implementation of
the complete Microsoft Forms 2.0 public object model. Completion is no longer a
control-category claim. It is a generated row-level claim covering types,
properties, property setters, methods, default members, events, enums, errors,
coercions, rendering effects, and `.frm`/`.frx` persistence.

The installed public `FM20.dll` type library is the API ground truth. The pinned
public MS-OFORMS specification is the persistence/default ground truth. Public
Microsoft documentation supplies the UserForm/host overlay that the typelib does
not encode, and reproducible black-box Office/MSForms observations settle
behavior that metadata cannot express.

W010 does not allow a precise blocker to count as completed parity. A blocker is
useful evidence, but an accepted row remains open or blocked until it is
implemented and verified.

## Why W010 Exists

W009 intentionally stopped at representative subset depth. A fresh mechanical
audit found that the current public classes are still missing roughly 29–82
unique FM20 member names per control even before exact signatures, default
members, and events are considered. The current implementation also exposes
OxForms internals such as `Core`, `Perform*`, `Diagnostics`, and `Notify*` as
public members; implements only three of the 42 FM20 enum types; implements two
of the five mutable `Return*` objects; and has no compatible `Font`, `Picture`,
or `DataObject` object.

The full installed type library contains:

| Kind | Count |
|---|---:|
| Type infos | 171 |
| Coclasses | 60 |
| Dispatch interfaces | 64 |
| Enums | 42 |
| Aliases | 4 |
| Non-dispatch interfaces | 1 (`IFont`) |

The W005 generated typelib artifact is an event-only subset. W010 first creates
the complete fact pack and generated parity ledger, so later work cannot lose a
member between prose plans or dashboard summaries.

## Current Execution Baseline

`oxforms-jbjp.1` ratified the 72-bead strict graph. `oxforms-jbjp.2` established
the API-shape baseline consumed by the remaining work:

- independently pinned FM20, stdole, capture-runtime, legacy W005, and reviewed
  semantic-capture identities;
- all 171 FM20 primary entries and 37 separate dual-interface companions;
- the exact 12-node referenced stdole closure, including distinct `Picture` and
  reverse public alias `IPictureDisp` records;
- 2,832 functions, 221 variables, 216 implementation edges, 3,153 parameters,
  and 1,446 resolved type-reference occurrences; and
- 376/376 stable W005 event-row matches with zero unexplained structural deltas
  despite the explicitly recorded FM20 source-binary hash change.

The API schema and non-claims are in
[`../specs/FM20_TYPELIB_FACT_SCHEMA.md`](../specs/FM20_TYPELIB_FACT_SCHEMA.md).

`oxforms-jbjp.3` then established the independent MS-OFORMS binary-persistence
and file-format-default baseline:

- exact Foundation commit plus raw document/figure and canonical-LF
  index/manifest/segment pins, retaining the original dirty-capture caveat;
- 8,024 lossless selected rows across context, normative structures/defaults
  and algorithms, examples, security, and all twenty Appendix A notes;
- 431 non-bitfield record fields (including both ordinary fields in the mixed
  `FormObjectDepthTypeCount` section), ninety record sections/37 aggregate
  requirements, 71 record tables, 18 property types, ten expanded resource
  formats, sixteen cached control ids, and all sixteen persisted visible
  controls including Page, with explicit composite dependencies;
- 98 properties: 95 documented defaults plus mandatory-persist `DrawBuffer`,
  `PageCount`, and `Size`, expanded to 107 typed default rows plus three typed
  value-domain tables/eight rows;
- 28 bitfields/320 semantically classified entries including all fifteen exact
  property masks, 26 enum/constant definitions/132 values, and three typed
  discriminator/value maps/eight values;
- one shared algorithm context and three procedures, with all twenty Appendix
  notes linked to their exact referenced rows; and
- 179 normative/example-separated reserved, unused, undefined, or ignored rows
  plus explicit 22-standard/103-occurrence, runtime/API, oracle, example, and
  product-behavior boundaries.

The persistence schema and non-claims are in
[`../specs/MSFORMS_PERSISTENCE_MODEL.md`](../specs/MSFORMS_PERSISTENCE_MODEL.md).
Neither metadata fact pack implements a callable member or persistence codec.

Strict successor `oxforms-jbjp.43` is closed with an independently verified
`.frm`/`.frx` export-fact surface. It preserves three genuine Excel
`16.0.20131.20112`/VBE `7.01` `VBComponent.Export` pairs and pins the adjacent
MS-OVBA `VBFrameText`/fifteen-`DesignerProperties` grammar plus the MS-VBAL
class-header/body boundary. The closed artifact records:

- three non-promotable authority profiles: captured Office VBA export,
  uncaptured VB6, and OxForms/legacy synthetic nested compatibility input;
- sixteen `Controls.Add` instances spanning all fourteen intrinsic families,
  plus structural UserForm and Page observations for sixteen observed families;
- an `OleObjectBlob` Office/VBIDE extension outside the selected normative
  MS-OVBA property grammar, with a 24-byte opaque FRX prefix and embedded CFB;
- a strict v2 capture binding the actual Excel process and the uniquely loaded
  `VBE7.DLL` (including Click-to-Run reported/backing-path provenance), exact
  requested/list readback, and the sole pinned ListBox height normalization;
- complete FRX source-length accounting with strict CFB allocation/ownership
  validation across three roots, four storages, 22 streams, 32 physical regions,
  and 62 mini-stream physical regions;
- applicability-specific coverage for all 98 MS-OFORMS properties and 245
  property/family pairs: 100 exact-name, 28 contextual-only, 33 internal-only,
  and 84 unprobed pairs; and
- fifteen explicit unknown preserve-or-reject classes.

The source-linked binary contract separately pins 43 selected length/count
fields in reviewed 15/14/7/5/2 groups, four codecs, object-valued layouts,
all 98 property default/status records (95 documented defaults plus three
mandatory-persist/no-default statuses), the 107-row matrix, fifteen masks with
221 entries, and 192 storage requirements. These are normative MS-OFORMS
projections, not decoded claims about the live opaque FRX streams.

The ten registered HTML ProgIDs' same-build designer-add `E_INVALIDARG` result
is limited to that observation and does not establish runtime non-callability.
No FRX property decoding, parser/serializer/codec, runtime API, VB6, or broader
HTML claim is made. Full verification and the exact fresh-eyes review passed;
the implementation landed in `9572f7a`, and `.43` is closed.

`oxforms-jbjp.4` then established the deterministic
raw-contract/current-overlay ledger from those immutable inputs plus the
explicit official-documentation overlay and current 37-module VBA surface:

- 7,753 addressable rows: 2,452 verified baseline rows, 4,682 gap rows, and
  619 unexpected-public rows, with 20,046 gating dimension cells and root
  `green = false`;
- exact retention/cross-links for all 220 type views, 2,832 FUNCDESC
  occurrences, 221 VARDESCs, 380 full-library event projections, every
  persistence leaf and property/family join, and every extracted public source
  declaration;
- symmetric array/ParamArray/optional/passing/name/default checks, exact
  default-member and enum-value rules, module-kind/creatability checks, and a
  scalar non-`As New` intrinsic global-binding rule;
- explicit source-index/vtable-offset signatures and the exact 200-byte IFont
  non-dispatch layout rather than a fabricated VBA source projection;
- 387 exact-owner and 191 logical-family rollups derived only from rows; and
- independent content pins and expected digest, dynamic module dependency
  closure, comment/dead-code-resistant Rust loader validation through the
  exact production-adapter attach/session handoff, exact pinned OxVba/Cargo
  resolution, canonical-only CLI validation/export, and adversarial mutation
  coverage.

The focused contract is in
[`../specs/MSFORMS_OBJECT_MODEL_PARITY.md`](../specs/MSFORMS_OBJECT_MODEL_PARITY.md),
with the census and nonclaims in the `.4` evidence README. This is an
infrastructure baseline, not final host-composed parity. `.5` owns generalized
live oracle capture. `.6` owns container-provided `Control`/`IControl` site
composition for every verified concrete family, generic
Enter/Exit/BeforeUpdate/AfterUpdate applicability, and the final
UserForm/host overlay expansion.

## Compatibility Perimeter

The primary runtime set is `UserForm`, the intrinsic global `UserForms`
collection, `Control`/`Controls`, the fourteen creatable
`Forms.<Control>.1` controls, `Page`/`Pages`, `Tab`/`Tabs`, and the supporting
objects and enums.

The type library also contains the ten HTML families `HTMLSubmit`, `HTMLImage`,
`HTMLReset`, `HTMLCheckbox`, `HTMLOption`, `HTMLText`, `HTMLHidden`,
`HTMLPassword`, `HTMLSelect`, and `HTMLTextArea`, plus hidden/versioned `*2`
coclasses, aliases, and hidden/restricted members. Because the owner requested a
full library sweep, W010 includes explicit capture and implementation lanes for
callable HTML surfaces and versioned identities. Rows proven non-callable,
restricted, or implementation-only may be classified out of the callable
facade, but no public type-library row may disappear silently. Hidden or
non-browsable is not itself an exclusion: the facade and UserForm/Frame lanes
explicitly probe `DesignMode`, `ShowToolbox`, `ShowGridDots`, `SnapToGrid`,
`GridX`, `GridY`, and `DrawBuffer`, and implement every callable row. The HTML
host seam must stay outside the intrinsic owner-drawn control core.

Out of scope remains arbitrary third-party ActiveX internals, Excel `RefEdit`,
the interactive designer UI (not its callable object-model rows), and
OxDoc-owned binary MS-OFORMS container conversion.

## Execution Rule

The graph is deliberately serial in the order below: `oxforms-jbjp.2` depends
on `.1`, every later bead depends on the preceding table row, and `.42` is the
independent closure audit at order 72. Numeric bead suffixes do not encode order
after the planning review split broad rollups into atomic outcomes. This makes
the reviewed commit from one bead the baseline for the next.

Every executable bead contains this exact pre-closure condition:

> After completing the bead work, check over everything again with fresh eyes,
> looking for any blunders, mistakes, errors, oversights, omissions, logical
> issues, problems, misconceptions, confusion, bugs, etc. and rework
> accordingly. After there are no more issues raised by such a review, do a
> commit of the work. Then proceed with the next bead in the list.

Each bead names its exact planned truth surfaces and evidence directory in its
`design` field, declares that temporary production scaffolding is forbidden,
quarantines durable probes/generators/fixtures outside production paths, states
residual/blocker behavior, and requires relevant targeted checks plus the full
repository floor with a sufficient timeout. An accepted callable row remains
open or precisely blocked; newly discovered out-of-scope work gets a bead before
closure.

## Structured Work List

The `Depends on` column names the strict predecessor. The full description,
decisive acceptance criteria, exact truth surfaces, scaffolding policy, and
residual behavior live in `br show <id> --json`.

| Order | Bead | Outcome | Depends on |
|---:|---|---|---|
| 1 | `oxforms-jbjp.1` | Ratify scope, baseline, atomic work list, and strict graph. | epic |
| 2 | `oxforms-jbjp.2` | Generate exhaustive FM20 and referenced-typelib facts, including stdole. | `.1` |
| 3 | `oxforms-jbjp.3` | Generate the MS-OFORMS default/binary-persistence fact pack. | `.2` |
| 4 | `oxforms-jbjp.43` | Generate the independent canonical `.frm`/`.frx` export fact manifest. | `.3` |
| 5 | `oxforms-jbjp.4` | Extract the public surface and generate the row-level parity ledger. | `.43` |
| 6 | `oxforms-jbjp.5` | Generalize the live property/method/error/event oracle harness. | `.4` |
| 7 | `oxforms-jbjp.6` | Define the full-library facade/internal boundary, including per-control `Control`/`IControl` site composition, generic host-event applicability, final UserForm/host projection, and hidden rows. | `.5` |
| 8 | `oxforms-jbjp.44` | Publish the precise OxVba FormModule integration handover. | `.6` |
| 9 | `oxforms-jbjp.7` | Replace public runtime hooks with one internal dispatch bridge. | `.44` |
| 10 | `oxforms-jbjp.8` | Implement all FM20 enums and public aliases. | `.7` |
| 11 | `oxforms-jbjp.45` | Implement all mutable `Return*` helper objects. | `.8` |
| 12 | `oxforms-jbjp.46` | Map public and versioned coclass identities. | `.45` |
| 13 | `oxforms-jbjp.9` | Implement `Font`/`NewFont` semantics. | `.46` |
| 14 | `oxforms-jbjp.47` | Implement `Picture`/`IPictureDisp` semantics. | `.9` |
| 15 | `oxforms-jbjp.10` | Implement `DataObject` formats, text, and clipboard behavior. | `.47` |
| 16 | `oxforms-jbjp.48` | Implement `DataObject.StartDrag` and OLE effect behavior. | `.10` |
| 17 | `oxforms-jbjp.11` | Implement common `Control` identity, hierarchy, and data binding. | `.48` |
| 18 | `oxforms-jbjp.49` | Implement common `Control` geometry, state, and tab behavior. | `.11` |
| 19 | `oxforms-jbjp.50` | Implement common `Control` actions, focus, and z-order. | `.49` |
| 20 | `oxforms-jbjp.12` | Implement `Controls` default lookup, count, and enumeration. | `.50` |
| 21 | `oxforms-jbjp.51` | Implement `Controls` mutation and dynamic-control events. | `.12` |
| 22 | `oxforms-jbjp.52` | Implement `Controls` editing, selection, reparenting, and z-order. | `.51` |
| 23 | `oxforms-jbjp.13` | Implement the canonical `.frm` parser and nested model. | `.52` |
| 24 | `oxforms-jbjp.53` | Implement `.frm` serialization and unknown preservation. | `.13` |
| 25 | `oxforms-jbjp.14` | Implement `.frx` reading, decoding, and resource ownership. | `.53` |
| 26 | `oxforms-jbjp.54` | Implement `.frx` writing, corruption handling, and lifetime. | `.14` |
| 27 | `oxforms-jbjp.15` | Capture full `Label`/`CommandButton` behavior. | `.54` |
| 28 | `oxforms-jbjp.16` | Implement full `Label`/`CommandButton` parity. | `.15` |
| 29 | `oxforms-jbjp.17` | Capture the full `TextBox` object/editing surface. | `.16` |
| 30 | `oxforms-jbjp.18` | Implement platform-neutral `TextBox` object/editing parity. | `.17` |
| 31 | `oxforms-jbjp.19` | Complete native IME/dead-key and multiline-layout parity. | `.18` |
| 32 | `oxforms-jbjp.20` | Capture full Boolean-morph behavior. | `.19` |
| 33 | `oxforms-jbjp.21` | Implement full Boolean-morph parity. | `.20` |
| 34 | `oxforms-jbjp.22` | Capture complete `ListBox` semantics. | `.21` |
| 35 | `oxforms-jbjp.23` | Implement complete `ListBox` parity. | `.22` |
| 36 | `oxforms-jbjp.24` | Capture complete `ComboBox` semantics. | `.23` |
| 37 | `oxforms-jbjp.25` | Implement complete `ComboBox` parity. | `.24` |
| 38 | `oxforms-jbjp.26` | Capture complete `Image`/`Picture` behavior. | `.25` |
| 39 | `oxforms-jbjp.27` | Implement decoded-pixel `Image` parity. | `.26` |
| 40 | `oxforms-jbjp.28` | Capture full `SpinButton`/`ScrollBar` behavior. | `.27` |
| 41 | `oxforms-jbjp.29` | Implement full `SpinButton`/`ScrollBar` parity. | `.28` |
| 42 | `oxforms-jbjp.30` | Capture `UserForm`/`Frame`, including callable hidden rows. | `.29` |
| 43 | `oxforms-jbjp.55` | Implement complete `Frame` parity. | `.30` |
| 44 | `oxforms-jbjp.56` | Implement the complete `UserForm` public object/layout surface. | `.55` |
| 45 | `oxforms-jbjp.31` | Implement `UserForm` lifecycle, modal, and container behavior. | `.56` |
| 46 | `oxforms-jbjp.71` | Implement global `UserForms` and the loaded-form registry. | `.31` |
| 47 | `oxforms-jbjp.32` | Capture full `TabStrip`/`Tabs`/`Tab` semantics. | `.71` |
| 48 | `oxforms-jbjp.33` | Implement full `TabStrip`/`Tabs`/`Tab` parity. | `.32` |
| 49 | `oxforms-jbjp.34` | Capture full `MultiPage`/`Pages`/`Page` semantics. | `.33` |
| 50 | `oxforms-jbjp.35` | Implement full `MultiPage`/`Pages`/`Page` parity. | `.34` |
| 51 | `oxforms-jbjp.36` | Classify and capture all ten actual FM20 HTML families. | `.35` |
| 52 | `oxforms-jbjp.37` | Implement HTML submit/reset families. | `.36` |
| 53 | `oxforms-jbjp.58` | Implement HTML checkbox/option families. | `.37` |
| 54 | `oxforms-jbjp.59` | Implement HTML text/password/hidden/textarea families. | `.58` |
| 55 | `oxforms-jbjp.60` | Implement HTML select/image families. | `.59` |
| 56 | `oxforms-jbjp.72` | Close shared `Control`/`Controls` parity across HTML families. | `.60` |
| 57 | `oxforms-jbjp.38` | Complete common pointer/keyboard/focus events. | `.72` |
| 58 | `oxforms-jbjp.61` | Complete value/edit/list/morph events. | `.38` |
| 59 | `oxforms-jbjp.63` | Complete FM20 drag/error/scroll/spin/zoom events. | `.61` |
| 60 | `oxforms-jbjp.39` | Run the visual-property and interaction-state render matrix. | `.63` |
| 61 | `oxforms-jbjp.65` | Run font/text/picture/color rendering differentials. | `.39` |
| 62 | `oxforms-jbjp.66` | Run DPI/layout/clipping/scroll/invalidation differentials. | `.65` |
| 63 | `oxforms-jbjp.40` | Run the exhaustive public bind/signature corpus. | `.66` |
| 64 | `oxforms-jbjp.41` | Benchmark large forms/lists and incremental repaint. | `.40` |
| 65 | `oxforms-jbjp.57` | Integrate production OxVba FormModule loading/default instances. | `.41` |
| 66 | `oxforms-jbjp.62` | Complete container/form/page/tab events. | `.57` |
| 67 | `oxforms-jbjp.64` | Validate all event mutation, ordering, and reentrancy. | `.62` |
| 68 | `oxforms-jbjp.67` | Run the exhaustive runtime get/set/method/error corpus. | `.64` |
| 69 | `oxforms-jbjp.68` | Run the exhaustive generated/real persistence corpus. | `.67` |
| 70 | `oxforms-jbjp.69` | Stress modal reentrancy and dynamic tree mutation. | `.68` |
| 71 | `oxforms-jbjp.70` | Stress long-run resource and object lifetime. | `.69` |
| 72 | `oxforms-jbjp.42` | Independently regenerate, audit, verify, and close W010. | `.70` |

## Truth Surfaces

- `docs/FORMS_LIBRARY_SPEC_AND_PLAN.md` and focused object-model specs created by
  later beads;
- `docs/SOURCE_REFERENCES.md`;
- this workset and `docs/WORKSET_REGISTER.md`;
- full generated FM20/referenced-typelib, MS-OFORMS, `.frm`/`.frx` export,
  facade, and implementation facts;
- `docs/evidence/W010_complete_msforms_object_model_parity/`;
- `docs/handovers/HANDOVER_OxVba_w010_form_module_integration.md` and the
  production integration gate that consumes its eventual delivery;
- `vba/oxforms/`, the OxVba adapter/runtime, PAL services/renderers, fixtures,
  tests, and oracle tooling;
- `.beads/` through `br` only.

## Verification Floor

| Surface | Check |
|---|---|
| Generated facts/ledger | deterministic regeneration plus schema and coverage validators |
| VBA binding | generated fixture names every public type/member/default/event/enum |
| Semantics | targeted value, error/coercion, event/order, focus, lifecycle, and collection tests |
| Persistence | generated and real `.frm/.frx` load-save-load corpus |
| Rendering | Scene/reference/Windows goldens and live MSForms differentials |
| Rust | `cargo fmt --check`; clippy with warnings denied; workspace tests with sufficient timeout |
| Evidence | `pwsh -File tools/Run-EvidenceChecks.ps1` |
| Hygiene | `git diff --check`; path/link/read-through scan; no unrelated `.gitignore` inclusion |
| Graph | `br dep cycles`; `br ready --json`; `br list --json`; `br sync --flush-only` |

## Baseline Recorded by `.1`

Before W010 implementation changes:

- `cargo fmt --check`: passed;
- `cargo clippy --workspace --all-targets -- -D warnings`: passed;
- `pwsh -File tools/Run-EvidenceChecks.ps1`: 31/31 passed;
- `git diff --check`: no content errors; only the pre-existing `.gitignore`
  line-ending warning appeared;
- `br dep cycles`: no cycles;
- `cargo test --workspace`: produced no failing assertion but exceeded the
  initial 300-second command budget while running the large
  `oxvba_reducer_cmdbutton` integration binary. This is not recorded as a pass;
  later beads must use targeted tests and a sufficient full-floor timeout.

The working tree already contained an unrelated `.gitignore` edit adding `.bv/`.
It is preserved and excluded from W010 commits unless separately authorized.

## Closure Conditions

W010 closes only when:

1. clean regeneration produces a complete accepted full-library ledger,
   including callable HTML, versioned, supporting-object, source-event, and
   hidden/non-browsable rows;
2. no row is missing, partial, unknown, prose-only, unexpectedly public, or
   treated as complete merely because it has a blocker;
3. signatures, default members, type identities, property/method behavior,
   errors/coercions, source events, rendering effects, and persistence are green
   wherever applicable;
4. all 72 child beads completed their exact fresh-eyes review and committed
   after a no-new-issues pass;
5. the generated all-member/persistence/render corpora and full verification
   floor pass from a clean checkout; and
6. spec, source references, workset, register, evidence, and beads agree.
